import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/local_storage.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/screens/settings_screen.dart';
import 'package:sprache/src/services/local_storage_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart';
import 'package:sprache/src/state/local_storage_state.dart';

void main() {
  testWidgets('storage deep link opens the Drive and local location category', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        studyStoreProvider.overrideWithValue(
          MemoryStudyStore(
            preferences: const StudyPreferences(onboardingCompleted: true),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SettingsScreen(initialFocus: 'storage')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final storageChoice = tester.widget<ChoiceChip>(
      find.byKey(const Key('settings-category-storage')),
    );
    expect(storageChoice.selected, isTrue);
    expect(find.byKey(const Key('connection-card')), findsOneWidget);
    expect(find.byKey(const Key('local-folder-status')), findsOneWidget);
    expect(find.byKey(const Key('advanced-preferences-panel')), findsNothing);
  });

  testWidgets('connected storage shows an exact Drive folder target', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        studyStoreProvider.overrideWithValue(
          MemoryStudyStore(
            preferences: const StudyPreferences(onboardingCompleted: true),
          ),
        ),
        googleConnectionServiceProvider.overrideWithValue(
          MockGoogleConnectionService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: SettingsScreen(initialFocus: 'storage')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final connection = container
        .read(connectionControllerProvider.notifier)
        .connect();
    await tester.pump(const Duration(milliseconds: 600));
    await connection;
    await tester.pump();

    expect(find.byKey(const Key('drive-folder-location')), findsOneWidget);
    expect(find.byKey(const Key('drive-folder-identifier')), findsOneWidget);
    expect(find.textContaining('mock_word_study_data'), findsOneWidget);
    expect(find.byKey(const Key('open-drive-folder')), findsOneWidget);
    expect(find.byKey(const Key('copy-drive-folder-id')), findsOneWidget);
  });

  testWidgets('configured local path supports open copy and change actions', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    const launcherChannel = MethodChannel('plugins.flutter.io/url_launcher');
    String? launchedUrl;
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      launcherChannel,
      (call) async {
        if (call.method == 'launch' || call.method == 'launchUrl') {
          final arguments = call.arguments;
          launchedUrl = arguments is Map
              ? arguments['url'] as String?
              : arguments as String?;
          return true;
        }
        return true;
      },
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(onboardingCompleted: true),
      localStorageSettings: const LocalStorageSettings(
        locationId: r'C:\Study',
        displayName: 'Study',
        locationKind: LocalStorageLocationKind.fileSystemPath,
      ),
    );
    final backend = _SettingsLocalStorageBackend(
      selectedLocation: const LocalStorageLocation(
        locationId: r'C:\Next',
        displayName: 'Next',
        kind: LocalStorageLocationKind.fileSystemPath,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        studyStoreProvider.overrideWithValue(store),
        localStorageBackendProvider.overrideWithValue(backend),
        importArchiveStagingProvider.overrideWithValue(
          const _EmptyImportStaging(),
        ),
      ],
    );
    final initialLocation = path.join(r'C:\Study', 'Sprache');
    final changedLocation = path.join(r'C:\Next', 'Sprache');
    addTearDown(container.dispose);
    try {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: SettingsScreen(initialFocus: 'storage')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        container.read(localStorageControllerProvider).settings.locationId,
        r'C:\Study',
      );
      final open = find.byKey(const Key('open-local-folder'));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pump();
      expect(launchedUrl, contains('C:/Study/Sprache'));

      final copy = find.byKey(const Key('copy-local-folder-path'));
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pump();
      expect(clipboardText, initialLocation);

      final change = find.byKey(const Key('change-local-folder'));
      await tester.ensureVisible(change);
      await tester.tap(change);
      await tester.pumpAndSettle();
      expect(
        container.read(localStorageControllerProvider).settings.locationId,
        r'C:\Next',
      );
      expect(find.text(changedLocation), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        launcherChannel,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('settings search filters sections and exposes a clear action', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final container = ProviderContainer(
        overrides: [
          studyStoreProvider.overrideWithValue(
            MemoryStudyStore(
              preferences: const StudyPreferences(onboardingCompleted: true),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-category-picker')), findsOneWidget);
      expect(find.byKey(const Key('connection-card')), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-category-display')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('connection-card')), findsNothing);
      expect(
        find.byKey(const Key('advanced-preferences-panel')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('settings-category-all')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('connection-card')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('settings-search-field')),
        '테마',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('advanced-preferences-panel')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('connection-card')), findsNothing);
      expect(
        find.byKey(const Key('appearance-color-mode-system')),
        findsOneWidget,
      );
      final displayFocus = tester.widget<Focus>(
        find.byKey(const Key('settings-section-focus-display')),
      );
      expect(displayFocus.focusNode?.hasFocus, isTrue);

      final clearSearch = find.byKey(const Key('clear-settings-search'));
      await tester.ensureVisible(clearSearch);
      await tester.pumpAndSettle();
      await tester.tap(clearSearch);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('connection-card')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('settings-search-field')),
        '키보드 도움말',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('advanced-preferences-panel')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('connection-card')), findsNothing);
      expect(
        find.byKey(const Key('accessibility-shortcut-global-keyboardHelp')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('display reset previews changes and preserves study data', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        studyStoreProvider.overrideWithValue(
          MemoryStudyStore(
            preferences: const StudyPreferences(
              onboardingCompleted: true,
              experience: AppExperiencePreferences(
                colorMode: AppColorMode.dark,
                reduceMotion: true,
              ),
              interaction: StudyInteractionPreferences(
                autoPlayQuestionAudio: true,
              ),
              ttsRate: 0.8,
              favoriteItemIds: {'keep-favorite'},
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pumpAndSettle();
    final favoritesBefore = container
        .read(appControllerProvider)
        .preferences
        .favoriteItemIds;

    final resetButton = find.byKey(const Key('reset-display-settings'));
    await tester.scrollUntilVisible(
      resetButton,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(resetButton);
    await tester.pumpAndSettle();
    await tester.tap(resetButton);
    await tester.pumpAndSettle();
    expect(find.text('화면·학습 편의를 초기화할까요?'), findsOneWidget);
    expect(find.textContaining('학습 자료, 진도, 저장 위치'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-settings-reset')));
    await tester.pumpAndSettle();
    final preferences = container.read(appControllerProvider).preferences;
    expect(preferences.experience.colorMode, AppColorMode.system);
    expect(preferences.experience.reduceMotion, isFalse);
    expect(preferences.interaction.autoPlayQuestionAudio, isFalse);
    expect(preferences.interaction.preferOfflineVoice, isTrue);
    expect(preferences.ttsRate, 0.45);
    expect(preferences.favoriteItemIds, favoritesBefore);
    expect(tester.takeException(), isNull);
  });
}

class _SettingsLocalStorageBackend implements LocalStorageBackend {
  const _SettingsLocalStorageBackend({required this.selectedLocation});

  final LocalStorageLocation selectedLocation;

  @override
  Future<LocalStorageLocation?> pickLocation({
    LocalStorageSettings? current,
  }) async => selectedLocation;

  @override
  Future<LocalStorageLocation> verifyLocation(
    LocalStorageLocation location,
  ) async => location;

  @override
  Future<bool> hasLatestArchive(LocalStorageLocation location) async => false;

  @override
  Future<LocalStorageWriteResult> writeBundle({
    required LocalStorageLocation location,
    required LocalStorageBundle bundle,
  }) async => LocalStorageWriteResult(
    savedAt: DateTime.utc(2026, 8, 3, 12),
    sha256Hex: bundle.archiveSha256,
    byteLength: bundle.archiveBytes,
  );

  @override
  Future<Uint8List?> readLatestArchive(LocalStorageLocation location) async =>
      null;

  @override
  Future<LocalImportArchiveResult> archiveImport({
    required LocalStorageLocation location,
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
  }) async => const LocalImportArchiveResult(
    created: true,
    relativePath: 'imports/test.bin',
  );

  @override
  Future<void> releaseLocation(LocalStorageLocation location) async {}
}

class _EmptyImportStaging implements ImportArchiveStagingService {
  const _EmptyImportStaging();

  @override
  Future<List<StagedImportArchive>> list() async => const [];

  @override
  Future<void> remove(String id) async {}

  @override
  Future<StagedImportArchive> stage({
    required String originalFileName,
    required Uint8List bytes,
    required String sha256Hex,
    String? distributionKey,
  }) {
    throw UnimplementedError();
  }
}
