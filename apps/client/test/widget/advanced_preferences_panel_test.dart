import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/widgets/advanced_preferences_panel.dart';

void main() {
  late AppExperiencePreferences experiencePreferences;
  late StudyInteractionPreferences interactionPreferences;
  late double ttsRate;

  Future<void> pumpPanel(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: AdvancedPreferencesPanel(
                experiencePreferences: experiencePreferences,
                interactionPreferences: interactionPreferences,
                ttsRate: ttsRate,
                onExperiencePreferencesChanged: (value) {
                  setState(() => experiencePreferences = value);
                },
                onInteractionPreferencesChanged: (value) {
                  setState(() => interactionPreferences = value);
                },
                onTtsRateChanged: (value) {
                  setState(() => ttsRate = value);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSection(WidgetTester tester, String keyName) async {
    final finder = find.byKey(Key(keyName));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapControl(WidgetTester tester, String keyName) async {
    final finder = find.byKey(Key(keyName));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pump();
  }

  setUp(() {
    experiencePreferences = const AppExperiencePreferences();
    interactionPreferences = const StudyInteractionPreferences();
    ttsRate = 0.45;
  });

  testWidgets('three compact groups fit a narrow mobile layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpPanel(tester);

    expect(find.byKey(const Key('advanced-preferences-panel')), findsOneWidget);
    for (final keyName in [
      'advanced-preferences-appearance',
      'advanced-preferences-reading-audio',
      'advanced-preferences-quiz',
    ]) {
      final finder = find.byKey(Key(keyName));
      expect(finder, findsOneWidget);
      expect(tester.getSize(finder).height, lessThanOrEqualTo(64));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('appearance group exposes every option and updates preferences', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPanel(tester);
    await openSection(tester, 'advanced-preferences-appearance');

    for (final keyName in [
      'appearance-color-mode-system',
      'appearance-color-mode-light',
      'appearance-color-mode-dark',
      'appearance-color-mode-oled',
      for (final palette in AppAccentPalette.values)
        'appearance-palette-${palette.name}',
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
    ]) {
      expect(find.byKey(Key(keyName)), findsOneWidget);
    }
    expect(
      tester
          .getSemantics(find.byKey(const Key('appearance-color-mode-dark')))
          .label,
      '화면 모드: 다크',
    );

    await tapControl(tester, 'appearance-color-mode-dark');
    await tapControl(tester, 'appearance-palette-coral');
    await tapControl(tester, 'appearance-density-compact');
    await tapControl(tester, 'appearance-text-scale-large');
    await tapControl(tester, 'appearance-reduce-motion');
    await tapControl(tester, 'appearance-haptics');
    await tapControl(tester, 'appearance-sound');

    expect(experiencePreferences.colorMode, AppColorMode.dark);
    expect(experiencePreferences.accentPalette, AppAccentPalette.coral);
    expect(experiencePreferences.density, AppDensity.compact);
    expect(experiencePreferences.textScale, AppTextScale.large);
    expect(experiencePreferences.motionLevel, AppMotionLevel.reduced);
    expect(experiencePreferences.reduceMotion, isFalse);
    expect(experiencePreferences.hapticsEnabled, isTrue);
    expect(experiencePreferences.soundEffectsEnabled, isTrue);
    semantics.dispose();
  });

  testWidgets('reading and audio group controls playback, readings, and rate', (
    tester,
  ) async {
    await pumpPanel(tester);
    await openSection(tester, 'advanced-preferences-reading-audio');

    for (final keyName in [
      'audio-autoplay-question',
      'audio-autoplay-answer',
      'audio-offline-voice',
      'audio-repeat-1',
      'audio-repeat-2',
      'audio-repeat-3',
      'reading-korean',
      'reading-native',
      'audio-tts-rate',
    ]) {
      expect(find.byKey(Key(keyName)), findsOneWidget);
    }

    await tapControl(tester, 'audio-autoplay-question');
    await tapControl(tester, 'audio-autoplay-answer');
    await tapControl(tester, 'audio-offline-voice');
    await tapControl(tester, 'audio-repeat-3');
    await tapControl(tester, 'reading-korean');
    await tapControl(tester, 'reading-native');
    final rateSlider = tester.widget<Slider>(
      find.descendant(
        of: find.byKey(const Key('audio-tts-rate')),
        matching: find.byType(Slider),
      ),
    );
    rateSlider.onChanged!(0.7);
    await tester.pump();

    expect(interactionPreferences.autoPlayQuestionAudio, isTrue);
    expect(interactionPreferences.autoPlayAnswerAudio, isTrue);
    expect(interactionPreferences.preferOfflineVoice, isFalse);
    expect(interactionPreferences.audioRepeatCount, 3);
    expect(interactionPreferences.showKoreanReading, isFalse);
    expect(interactionPreferences.showNativeReading, isFalse);
    expect(ttsRate, 0.7);
  });

  testWidgets('quiz group controls direction, layout, shuffle, and auto-next', (
    tester,
  ) async {
    await pumpPanel(tester);
    await openSection(tester, 'advanced-preferences-quiz');

    for (final keyName in [
      'quiz-answer-direction-learning-to-meaning',
      'quiz-answer-direction-meaning-to-learning',
      'quiz-answer-direction-mixed',
      'quiz-choice-layout-automatic',
      'quiz-choice-layout-list',
      'quiz-choice-layout-grid',
      'quiz-shuffle-choices',
      'quiz-auto-next',
      'quiz-auto-next-delay',
    ]) {
      expect(find.byKey(Key(keyName)), findsOneWidget);
    }

    await tapControl(tester, 'quiz-answer-direction-meaning-to-learning');
    await tapControl(tester, 'quiz-choice-layout-grid');
    await tapControl(tester, 'quiz-shuffle-choices');
    await tapControl(tester, 'quiz-auto-next');
    final delaySlider = tester.widget<Slider>(
      find.descendant(
        of: find.byKey(const Key('quiz-auto-next-delay')),
        matching: find.byType(Slider),
      ),
    );
    delaySlider.onChanged!(1500);
    await tester.pump();

    expect(
      interactionPreferences.answerDirection,
      StudyAnswerDirection.meaningToLearning,
    );
    expect(interactionPreferences.choiceLayout, StudyChoiceLayout.grid);
    expect(interactionPreferences.shuffleChoices, isFalse);
    expect(interactionPreferences.autoAdvanceCorrect, isTrue);
    expect(interactionPreferences.autoAdvanceDelayMs, 1500);
  });
}
