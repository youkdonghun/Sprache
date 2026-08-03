import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/settings_screen.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
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
