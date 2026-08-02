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
import 'package:sprache/src/theme/app_theme.dart';
import 'package:sprache/src/widgets/advanced_preferences_panel.dart';

void main() {
  const sectionControls = <String, List<String>>{
    'advanced-preferences-appearance': [
      'appearance-color-mode-system',
      'appearance-color-mode-light',
      'appearance-color-mode-dark',
      'appearance-color-mode-oled',
      'appearance-palette-sprache',
      'appearance-palette-forest',
      'appearance-palette-ocean',
      'appearance-palette-violet',
      'appearance-palette-coral',
      'appearance-palette-slate',
      'appearance-density-platform',
      'appearance-density-comfortable',
      'appearance-density-compact',
      'appearance-text-scale-system',
      'appearance-text-scale-small',
      'appearance-text-scale-medium',
      'appearance-text-scale-large',
      'appearance-text-scale-extra-large',
      'appearance-reduce-motion',
      'appearance-haptics',
      'appearance-sound',
    ],
    'advanced-preferences-reading-audio': [
      'audio-autoplay-question',
      'audio-autoplay-answer',
      'audio-offline-voice',
      'audio-repeat-1',
      'audio-repeat-2',
      'audio-repeat-3',
      'reading-korean',
      'reading-native',
      'audio-tts-rate',
    ],
    'advanced-preferences-quiz': [
      'quiz-answer-direction-learning-to-meaning',
      'quiz-answer-direction-meaning-to-learning',
      'quiz-answer-direction-mixed',
      'quiz-choice-layout-automatic',
      'quiz-choice-layout-list',
      'quiz-choice-layout-grid',
      'quiz-shuffle-choices',
      'quiz-auto-next',
      'quiz-auto-next-delay',
    ],
  };

  for (final width in const [320.0, 360.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'settings fit ${width.toInt()}px at 2.0x in ${brightness.name}',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
          final semantics = tester.ensureSemantics();
          final theme = AppTheme.mobileFor(
            const AppExperiencePreferences(),
            brightness: brightness,
          );

          try {
            await tester.pumpWidget(
              MaterialApp(
                theme: theme,
                home: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: AdvancedPreferencesPanel(
                      experiencePreferences: const AppExperiencePreferences(),
                      interactionPreferences:
                          const StudyInteractionPreferences(),
                      ttsRate: 0.45,
                      onExperiencePreferencesChanged: (_) {},
                      onInteractionPreferencesChanged: (_) {},
                      onTtsRateChanged: (_) {},
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(
              Theme.of(tester.element(find.byType(Scaffold))).brightness,
              brightness,
            );

            for (final entry in sectionControls.entries) {
              final section = find.byKey(Key(entry.key));
              expect(section, findsOneWidget);
              _expectMinimumTouchTarget(tester, section, reason: entry.key);
              await tester.ensureVisible(section);
              await tester.tap(section);
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '${entry.key} overflowed at ${width.toInt()}px',
              );

              for (final keyName in entry.value) {
                final control = find.byKey(Key(keyName));
                expect(control, findsOneWidget);
                _expectMinimumTouchTarget(tester, control, reason: keyName);
                expect(
                  tester.getSemantics(control).label.trim(),
                  isNotEmpty,
                  reason: '$keyName needs an accessibility label',
                );
              }

              await tester.ensureVisible(section);
              await tester.tap(section);
              await tester.pumpAndSettle();
            }

            final layoutErrors = <FlutterErrorDetails>[];
            final previousErrorHandler = FlutterError.onError;
            FlutterError.onError = layoutErrors.add;
            try {
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    studyStoreProvider.overrideWithValue(
                      MemoryStudyStore(
                        preferences: StudyPreferences(
                          onboardingCompleted: true,
                          experience: AppExperiencePreferences(
                            colorMode: brightness == Brightness.dark
                                ? AppColorMode.dark
                                : AppColorMode.light,
                          ),
                        ),
                      ),
                    ),
                  ],
                  child: MaterialApp(
                    theme: theme,
                    home: const SettingsScreen(),
                  ),
                ),
              );
              await tester.pumpAndSettle();
            } finally {
              FlutterError.onError = previousErrorHandler;
            }
            expect(
              layoutErrors,
              isEmpty,
              reason:
                  'SettingsScreen overflowed at ${width.toInt()}px in '
                  '${brightness.name}:\n'
                  '${layoutErrors.map((error) => error.toString()).join('\n')}',
            );

            final panel = find.byKey(const Key('advanced-preferences-panel'));
            await tester.scrollUntilVisible(
              panel,
              240,
              scrollable: find.byType(Scrollable).first,
            );
            expect(panel, findsOneWidget);
            expect(Theme.of(tester.element(panel)).brightness, brightness);
            for (final keyName in [
              'session-item-limit-decrease',
              'session-item-limit-increase',
            ]) {
              final button = find.byKey(Key(keyName));
              expect(button, findsOneWidget);
              _expectMinimumTouchTarget(tester, button, reason: keyName);
              expect(
                tester.getSemantics(button).label.trim(),
                isNotEmpty,
                reason: '$keyName needs an accessibility label',
              );
            }
            expect(
              tester.takeException(),
              isNull,
              reason: 'SettingsScreen failed while revealing preferences',
            );
          } finally {
            semantics.dispose();
            tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
            debugDefaultTargetPlatformOverride = null;
            tester.view.reset();
          }
        },
      );
    }
  }
}

void _expectMinimumTouchTarget(
  WidgetTester tester,
  Finder finder, {
  required String reason,
}) {
  final size = tester.getSize(finder);
  expect(size.width, greaterThanOrEqualTo(48), reason: '$reason width');
  expect(size.height, greaterThanOrEqualTo(48), reason: '$reason height');
}
