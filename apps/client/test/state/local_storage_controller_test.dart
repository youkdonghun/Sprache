import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/local_storage.dart';
import 'package:sprache/src/services/local_storage_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/local_storage_state.dart';

void main() {
  test(
    'a disconnected hydrated app automatically mirrors local changes',
    () async {
      final store = MemoryStudyStore(localStorageSettings: _configuredSettings);
      final backend = _FakeLocalStorageBackend();
      final app = AppController(store);
      final controller = _buildController(
        store: store,
        backend: backend,
        app: app,
      );

      await _initialize(app, controller);
      await _waitFor(() => backend.writes.isNotEmpty);
      final initialWrites = backend.writes.length;

      app.updatePreferences(app.state.preferences.copyWith(newItemLimit: 17));
      controller.observeAppState(app.state);
      await _waitFor(() => backend.writes.length > initialWrites);

      expect(controller.state.localMirrorActive, isTrue);
      expect(controller.state.settings.lastArchiveSha256, isNotNull);
      expect(controller.state.settings.lastArchiveBytes, greaterThan(0));
      expect(
        (await store.loadLocalStorageSettings()).lastArchiveSha256,
        controller.state.settings.lastArchiveSha256,
      );

      controller.dispose();
      app.dispose();
    },
  );

  test('Drive pauses local writes and disconnecting resumes them', () async {
    final store = MemoryStudyStore(localStorageSettings: _configuredSettings);
    final backend = _FakeLocalStorageBackend();
    final app = AppController(store);
    final controller = _buildController(
      store: store,
      backend: backend,
      app: app,
    );

    await _initialize(app, controller);
    await _waitFor(() => backend.writes.isNotEmpty);

    app.setDriveConnected(true);
    controller.observeAppState(app.state);
    final writesBeforeDriveChange = backend.writes.length;
    app.updatePreferences(app.state.preferences.copyWith(newItemLimit: 19));
    controller.observeAppState(app.state);
    await controller.saveNow();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(controller.state.activeTarget, ActiveStorageTarget.googleDrive);
    expect(backend.writes.length, writesBeforeDriveChange);

    app.setDriveConnected(false);
    controller.observeAppState(app.state);
    await _waitFor(() => backend.writes.length > writesBeforeDriveChange);

    expect(controller.state.activeTarget, ActiveStorageTarget.localFolder);
    controller.dispose();
    app.dispose();
  });

  test(
    'legacy staged import originals are discarded without another copy',
    () async {
      final store = MemoryStudyStore(localStorageSettings: _configuredSettings);
      final backend = _FakeLocalStorageBackend();
      final staging = _MemoryImportStagingService();
      await staging.stage(
        originalFileName: 'vocabulary.xlsx',
        bytes: Uint8List.fromList(const [1, 2, 3]),
        sha256Hex:
            '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81',
        distributionKey: 'work',
      );
      final app = AppController(store);
      final controller = _buildController(
        store: store,
        backend: backend,
        app: app,
        importStaging: staging,
      );

      await _initialize(app, controller);

      expect(controller.state.pendingImportCount, 0);
      expect(backend.archivedImports, isEmpty);
      expect(await staging.list(), isEmpty);

      controller.dispose();
      app.dispose();
    },
  );

  test(
    'selecting a folder with an archive waits for an explicit decision',
    () async {
      final store = MemoryStudyStore();
      final backend = _FakeLocalStorageBackend(hasExistingArchive: true);
      final app = AppController(store);
      final controller = _buildController(
        store: store,
        backend: backend,
        app: app,
      );

      await _initialize(app, controller);
      final selection = await controller.chooseFolder();
      controller.observeAppState(app.state);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(selection.cancelled, isFalse);
      expect(selection.existingArchiveAvailable, isTrue);
      expect(controller.state.existingArchiveAvailable, isTrue);
      expect(backend.writes, isEmpty);

      await controller.keepCurrentDataInSelectedFolder();
      expect(backend.writes, hasLength(1));
      expect(controller.state.existingArchiveAvailable, isFalse);

      controller.dispose();
      app.dispose();
    },
  );

  test('an existing archive decision survives controller recreation', () async {
    final store = MemoryStudyStore();
    final backend = _FakeLocalStorageBackend(hasExistingArchive: true);
    final app = AppController(store);
    var controller = _buildController(store: store, backend: backend, app: app);

    await _initialize(app, controller);
    await controller.chooseFolder();
    expect(
      (await store.loadLocalStorageSettings()).awaitingExistingArchiveDecision,
      isTrue,
    );
    expect(backend.writes, isEmpty);

    controller.dispose();
    backend.hasExistingArchive = false;
    controller = _buildController(store: store, backend: backend, app: app);
    await _initialize(app, controller);
    app.updatePreferences(app.state.preferences.copyWith(newItemLimit: 23));
    controller.observeAppState(app.state);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(controller.state.existingArchiveAvailable, isTrue);
    expect(controller.state.settings.awaitingExistingArchiveDecision, isTrue);
    expect(backend.writes, isEmpty);
    expect(
      backend.hasLatestArchiveChecks,
      1,
      reason: 'restart must trust the persisted pending decision',
    );

    controller.dispose();
    app.dispose();
  });

  test(
    'archive probe failures cannot clear a persisted existing archive decision',
    () async {
      const pendingSettings = LocalStorageSettings(
        locationId: 'configured-local-folder',
        displayName: 'Sprache',
        locationKind: LocalStorageLocationKind.fileSystemPath,
        awaitingExistingArchiveDecision: true,
      );
      final store = MemoryStudyStore(localStorageSettings: pendingSettings);
      final backend = _FakeLocalStorageBackend(
        hasLatestArchiveError: StateError('temporary provider failure'),
      );
      final app = AppController(store);
      await _waitFor(() => app.state.isHydrated);
      final controller = _buildController(
        store: store,
        backend: backend,
        app: app,
      );
      controller.observeAppState(app.state);

      await _waitFor(() => controller.state.initialized);
      await _waitFor(() => backend.verifiedLocations.isNotEmpty);
      app.updatePreferences(app.state.preferences.copyWith(newItemLimit: 29));
      controller.observeAppState(app.state);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(controller.state.existingArchiveAvailable, isTrue);
      expect(controller.state.settings.awaitingExistingArchiveDecision, isTrue);
      expect(controller.state.errorMessage, isNull);
      expect(backend.hasLatestArchiveChecks, 0);
      expect(backend.writes, isEmpty);
      expect(
        (await store.loadLocalStorageSettings())
            .awaitingExistingArchiveDecision,
        isTrue,
      );

      controller.dispose();
      app.dispose();
    },
  );

  test(
    'folder settings are device-local and survive controller recreation',
    () async {
      final store = MemoryStudyStore();
      final backend = _FakeLocalStorageBackend(
        selectedLocation: const LocalStorageLocation(
          locationId: 'device-only-folder-id',
          displayName: 'My Sprache',
          kind: LocalStorageLocationKind.fileSystemPath,
        ),
      );
      final app = AppController(store);
      var controller = _buildController(
        store: store,
        backend: backend,
        app: app,
      );

      await _initialize(app, controller);
      await controller.chooseFolder();
      await _waitFor(() => backend.writes.isNotEmpty);
      final stored = await store.loadLocalStorageSettings();

      expect(stored.locationId, 'device-only-folder-id');
      expect(stored.displayName, 'My Sprache');
      expect(
        jsonEncode(app.exportArchive()),
        isNot(contains('device-only-folder-id')),
        reason: 'the device path must never enter a Drive/backup snapshot',
      );

      controller.dispose();
      controller = _buildController(store: store, backend: backend, app: app);
      await _waitFor(() => controller.state.initialized);
      controller.observeAppState(app.state);
      await _waitFor(() => controller.state.settings.configured);

      expect(controller.state.settings.locationId, stored.locationId);
      expect(controller.state.settings.displayName, stored.displayName);

      controller.dispose();
      app.dispose();
    },
  );
}

const _configuredSettings = LocalStorageSettings(
  locationId: 'configured-local-folder',
  displayName: 'Sprache',
  locationKind: LocalStorageLocationKind.fileSystemPath,
);

LocalStorageController _buildController({
  required MemoryStudyStore store,
  required _FakeLocalStorageBackend backend,
  required AppController app,
  ImportArchiveStagingService? importStaging,
}) => LocalStorageController(
  store: store,
  backend: backend,
  importStaging: importStaging ?? _MemoryImportStagingService(),
  archiveBuilder: app.exportArchive,
  debounce: const Duration(milliseconds: 5),
);

Future<void> _initialize(
  AppController app,
  LocalStorageController controller,
) async {
  await _waitFor(() => app.state.isHydrated);
  controller.observeAppState(app.state);
  await _waitFor(() => controller.state.initialized);
  controller.observeAppState(app.state);
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 400; attempt += 1) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition was not reached before the test timeout.');
}

class _FakeLocalStorageBackend implements LocalStorageBackend {
  _FakeLocalStorageBackend({
    this.hasExistingArchive = false,
    this.hasLatestArchiveError,
    this.selectedLocation = const LocalStorageLocation(
      locationId: 'picked-local-folder',
      displayName: 'Sprache',
      kind: LocalStorageLocationKind.fileSystemPath,
    ),
  });

  bool hasExistingArchive;
  final Object? hasLatestArchiveError;
  final LocalStorageLocation selectedLocation;
  final List<LocalStorageLocation> verifiedLocations = [];
  final List<LocalStorageBundle> writes = [];
  final List<LocalStorageLocation> releasedLocations = [];
  final List<String> archivedImports = [];
  int hasLatestArchiveChecks = 0;

  @override
  Future<LocalStorageLocation?> pickLocation({
    LocalStorageSettings? current,
  }) async => selectedLocation;

  @override
  Future<LocalStorageLocation> verifyLocation(
    LocalStorageLocation location,
  ) async {
    verifiedLocations.add(location);
    return location;
  }

  @override
  Future<LocalStorageWriteResult> writeBundle({
    required LocalStorageLocation location,
    required LocalStorageBundle bundle,
  }) async {
    writes.add(bundle);
    return LocalStorageWriteResult(
      savedAt: DateTime.utc(2026, 7, 30, 12, 0, writes.length),
      sha256Hex: bundle.archiveSha256,
      byteLength: bundle.archiveBytes,
    );
  }

  @override
  Future<Uint8List?> readLatestArchive(LocalStorageLocation location) async =>
      null;

  @override
  Future<bool> hasLatestArchive(LocalStorageLocation location) async {
    hasLatestArchiveChecks += 1;
    if (hasLatestArchiveError != null) throw hasLatestArchiveError!;
    return hasExistingArchive;
  }

  @override
  Future<LocalImportArchiveResult> archiveImport({
    required LocalStorageLocation location,
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
  }) async {
    archivedImports.add(originalFileName);
    return const LocalImportArchiveResult(
      created: true,
      relativePath: 'imports/fake.xlsx',
    );
  }

  @override
  Future<void> releaseLocation(LocalStorageLocation location) async {
    releasedLocations.add(location);
  }
}

class _MemoryImportStagingService implements ImportArchiveStagingService {
  final Map<String, StagedImportArchive> _entries = {};

  @override
  Future<StagedImportArchive> stage({
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
    String? distributionKey,
  }) async {
    final staged = StagedImportArchive(
      id: sha256Hex,
      originalFileName: originalFileName,
      sha256Hex: sha256Hex,
      bytes: bytes,
      createdAt: DateTime.utc(2026, 7, 30),
      distributionKey: distributionKey,
    );
    _entries[staged.id] = staged;
    return staged;
  }

  @override
  Future<List<StagedImportArchive>> list() async =>
      List.unmodifiable(_entries.values);

  @override
  Future<void> remove(String id) async {
    _entries.remove(id);
  }
}
