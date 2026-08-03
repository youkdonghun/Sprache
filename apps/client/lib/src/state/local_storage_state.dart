import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Named public constructor parameters stay readable at provider/test call sites.
// ignore_for_file: prefer_initializing_formals

import '../backup/backup_archive.dart';
import '../data/study_store.dart';
import '../domain/accessibility_input_profile.dart';
import '../domain/local_storage.dart';
import '../services/local_storage_service.dart';
import 'app_state.dart';

enum ActiveStorageTarget { appOnly, localFolder, googleDrive }

class LocalStorageState {
  const LocalStorageState({
    required this.initialized,
    required this.driveConnected,
    required this.settings,
    this.busy = false,
    this.existingArchiveAvailable = false,
    this.pendingImportCount = 0,
    this.errorMessage,
  });

  const LocalStorageState.initial()
    : initialized = false,
      driveConnected = false,
      settings = const LocalStorageSettings(),
      busy = false,
      existingArchiveAvailable = false,
      pendingImportCount = 0,
      errorMessage = null;

  final bool initialized;
  final bool driveConnected;
  final LocalStorageSettings settings;
  final bool busy;
  final bool existingArchiveAvailable;
  final int pendingImportCount;
  final String? errorMessage;

  bool get configured => settings.configured;

  bool get requiresSetup => initialized && !driveConnected && !configured;

  bool get localMirrorActive =>
      initialized && !driveConnected && configured && errorMessage == null;

  ActiveStorageTarget get activeTarget => driveConnected
      ? ActiveStorageTarget.googleDrive
      : configured
      ? ActiveStorageTarget.localFolder
      : ActiveStorageTarget.appOnly;

  LocalStorageState copyWith({
    bool? initialized,
    bool? driveConnected,
    LocalStorageSettings? settings,
    bool? busy,
    bool? existingArchiveAvailable,
    int? pendingImportCount,
    Object? errorMessage = _keepError,
  }) {
    return LocalStorageState(
      initialized: initialized ?? this.initialized,
      driveConnected: driveConnected ?? this.driveConnected,
      settings: settings ?? this.settings,
      busy: busy ?? this.busy,
      existingArchiveAvailable:
          existingArchiveAvailable ?? this.existingArchiveAvailable,
      pendingImportCount: pendingImportCount ?? this.pendingImportCount,
      errorMessage: identical(errorMessage, _keepError)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class LocalFolderSelectionResult {
  const LocalFolderSelectionResult({
    required this.cancelled,
    required this.existingArchiveAvailable,
    this.location,
  });

  const LocalFolderSelectionResult.cancelled()
    : cancelled = true,
      existingArchiveAvailable = false,
      location = null;

  final bool cancelled;
  final bool existingArchiveAvailable;
  final LocalStorageLocation? location;
}

class LocalStorageController extends StateNotifier<LocalStorageState> {
  LocalStorageController({
    required StudyStore store,
    required LocalStorageBackend backend,
    required ImportArchiveStagingService importStaging,
    required Map<String, Object?> Function() archiveBuilder,
    LocalStorageBundleBuilder bundleBuilder = const LocalStorageBundleBuilder(),
    BackupArchiveCodec archiveCodec = const BackupArchiveCodec(),
    Duration debounce = const Duration(milliseconds: 700),
  }) : _store = store,
       _backend = backend,
       _importStaging = importStaging,
       _archiveBuilder = archiveBuilder,
       _bundleBuilder = bundleBuilder,
       _archiveCodec = archiveCodec,
       _debounce = debounce,
       super(const LocalStorageState.initial()) {
    unawaited(_initialize());
  }

  final StudyStore _store;
  final LocalStorageBackend _backend;
  final ImportArchiveStagingService _importStaging;
  final Map<String, Object?> Function() _archiveBuilder;
  final LocalStorageBundleBuilder _bundleBuilder;
  final BackupArchiveCodec _archiveCodec;
  final Duration _debounce;
  Timer? _saveTimer;
  AppState? _appState;
  bool _writing = false;
  bool _writeAgain = false;
  bool _awaitingExistingDecision = false;
  Completer<void>? _activeWrite;

  void observeAppState(AppState appState) {
    _appState = appState;
    final driveChanged = state.driveConnected != appState.driveConnected;
    if (driveChanged) {
      if (appState.driveConnected) {
        _saveTimer?.cancel();
      }
      state = state.copyWith(
        driveConnected: appState.driveConnected,
        errorMessage: appState.driveConnected ? null : state.errorMessage,
      );
    }
    if (!appState.isHydrated ||
        !state.initialized ||
        appState.driveConnected ||
        !state.configured ||
        _awaitingExistingDecision) {
      return;
    }
    _scheduleSave();
  }

  Future<LocalFolderSelectionResult> chooseFolder() async {
    if (state.busy) return const LocalFolderSelectionResult.cancelled();
    var activateSelectedFolder = false;
    state = state.copyWith(busy: true, errorMessage: null);
    try {
      final selected = await _backend.pickLocation(current: state.settings);
      if (selected == null) {
        return const LocalFolderSelectionResult.cancelled();
      }
      final verified = await _backend.verifyLocation(selected);
      final sameLocation =
          state.settings.configured &&
          state.settings.locationId == verified.locationId &&
          state.settings.locationKind == verified.kind;
      final hasExisting = await _backend.hasLatestArchive(verified);
      final requiresExistingDecision =
          hasExisting &&
          (!sameLocation || state.settings.awaitingExistingArchiveDecision);
      final nextSettings = LocalStorageSettings(
        locationId: verified.locationId,
        displayName: verified.displayName,
        locationKind: verified.kind,
        lastSavedAt: sameLocation ? state.settings.lastSavedAt : null,
        lastArchiveSha256: sameLocation
            ? state.settings.lastArchiveSha256
            : null,
        lastArchiveBytes: sameLocation ? state.settings.lastArchiveBytes : null,
        awaitingExistingArchiveDecision: requiresExistingDecision,
        accessibilityInputProfile: state.settings.accessibilityInputProfile,
      );
      await _store.saveLocalStorageSettings(nextSettings);
      final previous = _locationFromSettings(state.settings);
      if (previous != null &&
          (previous.locationId != verified.locationId ||
              previous.kind != verified.kind)) {
        unawaited(_backend.releaseLocation(previous));
      }
      _awaitingExistingDecision = requiresExistingDecision;
      state = state.copyWith(
        settings: nextSettings,
        existingArchiveAvailable: _awaitingExistingDecision,
        errorMessage: null,
      );
      if (!_awaitingExistingDecision && !state.driveConnected) {
        activateSelectedFolder = true;
      }
      return LocalFolderSelectionResult(
        cancelled: false,
        existingArchiveAvailable: _awaitingExistingDecision,
        location: verified,
      );
    } catch (error) {
      state = state.copyWith(errorMessage: _friendlyMessage(error));
      rethrow;
    } finally {
      if (mounted) {
        state = state.copyWith(busy: false);
        if (activateSelectedFolder) {
          unawaited(saveNow());
        }
      }
    }
  }

  Future<void> keepCurrentDataInSelectedFolder() async {
    _awaitingExistingDecision = false;
    final settings = state.settings.copyWith(
      awaitingExistingArchiveDecision: false,
    );
    await _store.saveLocalStorageSettings(settings);
    state = state.copyWith(settings: settings, existingArchiveAvailable: false);
    await saveNow();
  }

  Future<BackupArchive?> loadExistingBackup() async {
    final location = _locationFromSettings(state.settings);
    if (location == null) return null;
    final bytes = await _backend.readLatestArchive(location);
    if (bytes == null) return null;
    if (bytes.length > BackupArchiveCodec.maxArchiveBytes) {
      throw const LocalStorageException(
        'local_archive_too_large',
        '선택한 로컬 보관본이 10MB 제한을 넘었습니다.',
      );
    }
    return _archiveCodec.decode(utf8.decode(bytes, allowMalformed: false));
  }

  Future<void> markExistingBackupMerged() async {
    _awaitingExistingDecision = false;
    final settings = state.settings.copyWith(
      awaitingExistingArchiveDecision: false,
    );
    await _store.saveLocalStorageSettings(settings);
    state = state.copyWith(settings: settings, existingArchiveAvailable: false);
    await saveNow();
  }

  Future<void> saveNow() async {
    if (!state.initialized ||
        state.driveConnected ||
        !state.configured ||
        _awaitingExistingDecision ||
        !(_appState?.isHydrated ?? false)) {
      return;
    }
    if (_writing) {
      _writeAgain = true;
      await _activeWrite?.future;
      return;
    }
    _saveTimer?.cancel();
    _writing = true;
    _activeWrite = Completer<void>();
    state = state.copyWith(busy: true, errorMessage: null);
    try {
      do {
        _writeAgain = false;
        final location = _locationFromSettings(state.settings);
        if (location == null || state.driveConnected) break;
        final bundle = _bundleBuilder.build(_archiveBuilder());
        final result = await _backend.writeBundle(
          location: location,
          bundle: bundle,
        );
        final nextSettings = state.settings.copyWith(
          lastSavedAt: result.savedAt,
          lastArchiveSha256: result.sha256Hex,
          lastArchiveBytes: result.byteLength,
        );
        await _store.saveLocalStorageSettings(nextSettings);
        if (mounted) {
          state = state.copyWith(
            settings: nextSettings,
            existingArchiveAvailable: false,
            errorMessage: null,
          );
        }
      } while (_writeAgain && !state.driveConnected && state.configured);
      _activeWrite?.complete();
    } catch (error) {
      if (!(_activeWrite?.isCompleted ?? true)) {
        _activeWrite?.complete();
      }
      if (mounted) {
        state = state.copyWith(errorMessage: _friendlyMessage(error));
      }
      rethrow;
    } finally {
      _writing = false;
      _activeWrite = null;
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    if (_writing) {
      _writeAgain = true;
      try {
        await _activeWrite?.future;
      } catch (_) {
        // The state already exposes the write error for recovery.
      }
      return;
    }
    try {
      await saveNow();
    } catch (_) {
      // Lifecycle flushes must never block app shutdown.
    }
  }

  Future<void> updateAccessibilityInputProfile(
    AccessibilityInputProfile profile,
  ) async {
    final nextSettings = state.settings.copyWith(
      accessibilityInputProfile: profile,
    );
    await _store.saveLocalStorageSettings(nextSettings);
    if (mounted) {
      state = state.copyWith(settings: nextSettings, errorMessage: null);
    }
  }

  Future<void> clearFolder() async {
    final current = _locationFromSettings(state.settings);
    _saveTimer?.cancel();
    _awaitingExistingDecision = false;
    final empty = LocalStorageSettings(
      accessibilityInputProfile: state.settings.accessibilityInputProfile,
    );
    await _store.saveLocalStorageSettings(empty);
    state = state.copyWith(
      settings: empty,
      existingArchiveAvailable: false,
      errorMessage: null,
    );
    if (current != null) unawaited(_backend.releaseLocation(current));
  }

  Future<void> _initialize() async {
    try {
      final settings = await _store.loadLocalStorageSettings();
      final legacyPendingImports = await _importStaging.list();
      var pendingImports = legacyPendingImports;
      if (legacyPendingImports.isNotEmpty) {
        for (final staged in legacyPendingImports) {
          try {
            await _importStaging.remove(staged.id);
          } catch (_) {
            // A failed cleanup is reported as a remaining legacy item, but is
            // never uploaded to Drive or copied into the active local mirror.
          }
        }
        pendingImports = await _importStaging.list();
      }
      if (!mounted) return;
      _awaitingExistingDecision = settings.awaitingExistingArchiveDecision;
      state = state.copyWith(
        initialized: true,
        settings: settings,
        existingArchiveAvailable: _awaitingExistingDecision,
        pendingImportCount: pendingImports.length,
      );
      final appState = _appState;
      if (settings.configured &&
          appState != null &&
          appState.isHydrated &&
          !appState.driveConnected) {
        final location = _locationFromSettings(settings)!;
        try {
          final verified = await _backend.verifyLocation(location);
          final verifiedSettings = LocalStorageSettings(
            locationId: verified.locationId,
            displayName: verified.displayName,
            locationKind: verified.kind,
            lastSavedAt: settings.lastSavedAt,
            lastArchiveSha256: settings.lastArchiveSha256,
            lastArchiveBytes: settings.lastArchiveBytes,
            awaitingExistingArchiveDecision:
                settings.awaitingExistingArchiveDecision,
            accessibilityInputProfile: settings.accessibilityInputProfile,
          );
          if (verifiedSettings.displayName != settings.displayName ||
              verifiedSettings.awaitingExistingArchiveDecision !=
                  settings.awaitingExistingArchiveDecision) {
            await _store.saveLocalStorageSettings(verifiedSettings);
          }
          if (mounted) {
            state = state.copyWith(
              settings: verifiedSettings,
              existingArchiveAvailable: _awaitingExistingDecision,
              errorMessage: null,
            );
          }
          if (!_awaitingExistingDecision) {
            _scheduleSave();
          }
        } catch (error) {
          if (mounted) {
            state = state.copyWith(errorMessage: _friendlyMessage(error));
          }
        }
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(
          initialized: true,
          errorMessage: '로컬 저장 설정을 불러오지 못했습니다. 앱 데이터는 그대로 유지됩니다.',
        );
      }
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_debounce, () {
      unawaited(saveNow().catchError((_) {}));
    });
  }

  LocalStorageLocation? _locationFromSettings(LocalStorageSettings settings) {
    if (!settings.configured) return null;
    return LocalStorageLocation(
      locationId: settings.locationId!,
      displayName: settings.displayName!,
      kind: settings.locationKind,
    );
  }

  String _friendlyMessage(Object error) {
    if (error is LocalStorageException) return error.message;
    return '로컬 보관 폴더에 접근하지 못했습니다. 폴더를 다시 연결해 주세요.';
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}

final localStorageBackendProvider = Provider<LocalStorageBackend>(
  (ref) => createPlatformLocalStorageBackend(),
);

final importArchiveStagingProvider = Provider<ImportArchiveStagingService>(
  (ref) => kIsWeb
      ? MemoryImportArchiveStagingService()
      : FileImportArchiveStagingService(),
);

final localStorageControllerProvider =
    StateNotifierProvider<LocalStorageController, LocalStorageState>((ref) {
      final controller = LocalStorageController(
        store: ref.watch(studyStoreProvider),
        backend: ref.watch(localStorageBackendProvider),
        importStaging: ref.watch(importArchiveStagingProvider),
        archiveBuilder: () =>
            ref.read(appControllerProvider.notifier).exportArchive(),
      );
      ref.listen<AppState>(
        appControllerProvider,
        (previous, next) => controller.observeAppState(next),
        fireImmediately: true,
      );
      return controller;
    });

final accessibilityInputProfileProvider = Provider<AccessibilityInputProfile>((
  ref,
) {
  return ref.watch(
    localStorageControllerProvider.select(
      (state) => state.settings.accessibilityInputProfile,
    ),
  );
});

const _keepError = Object();
