import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/study_screen.dart';
import 'package:sprache/src/services/app_feedback_service.dart';
import 'package:sprache/src/services/tts_service.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets(
    'answer direction, list layout, and fixed choice order reach the quiz',
    (tester) async {
      const preferences = StudyPreferences(
        interaction: StudyInteractionPreferences(
          answerDirection: StudyAnswerDirection.meaningToLearning,
          choiceLayout: StudyChoiceLayout.list,
          shuffleChoices: false,
        ),
      );

      await _pumpStudy(
        tester,
        preferences: preferences,
        screen: const StudyScreen(mode: StudyMode.mixed, itemLimit: 5),
      );

      expect(find.text('알맞은 학습어를 고르세요'), findsOneWidget);
      expect(
        find.byKey(const Key('study-choice-single-column')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('study-choice-grid')), findsNothing);
      final prompt = tester.widget<Text>(
        find.byKey(const Key('study-question-prompt')),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(StudyScreen)),
      );
      final item = container
          .read(appControllerProvider.notifier)
          .selectedItems
          .firstWhere(
            (candidate) => candidate.primaryTranslation == prompt.data,
          );
      final firstChoice = find.descendant(
        of: find.byKey(const Key('study-choice-0')),
        matching: find.byType(Text),
      );
      final choiceLabels = tester
          .widgetList<Text>(firstChoice)
          .map((widget) => widget.data)
          .whereType<String>()
          .toList();

      expect(prompt.data, isNotEmpty);
      expect(choiceLabels, contains(item.text));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('explicit grid layout stays selected on a narrow large-text UI', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 900);
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() {
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.reset();
    });
    const preferences = StudyPreferences(
      interaction: StudyInteractionPreferences(
        answerDirection: StudyAnswerDirection.learningToMeaning,
        choiceLayout: StudyChoiceLayout.grid,
      ),
    );

    await _pumpStudy(
      tester,
      preferences: preferences,
      screen: const StudyScreen(mode: StudyMode.mixed, itemLimit: 5),
    );

    expect(find.text('알맞은 뜻을 고르세요'), findsOneWidget);
    expect(find.byKey(const Key('study-choice-grid')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('correct answers advance after the configured delay only', (
    tester,
  ) async {
    const preferences = StudyPreferences(
      interaction: StudyInteractionPreferences(
        choiceLayout: StudyChoiceLayout.list,
        shuffleChoices: false,
        autoAdvanceCorrect: true,
        autoAdvanceDelayMs: 300,
      ),
    );

    await _pumpStudy(
      tester,
      preferences: preferences,
      screen: const StudyScreen(mode: StudyMode.meaning, itemLimit: 2),
    );
    final firstPrompt = tester
        .widget<Text>(find.byKey(const Key('study-question-prompt')))
        .data;

    await tester.tap(find.byKey(const Key('study-choice-0')));
    await tester.tap(find.byKey(const Key('submit-study-answer')));
    await tester.pump();
    expect(find.byKey(const Key('study-feedback-popup')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 299));
    expect(
      tester.widget<Text>(find.byKey(const Key('study-question-prompt'))).data,
      firstPrompt,
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byKey(const Key('study-feedback-popup')), findsNothing);
    expect(
      tester.widget<Text>(find.byKey(const Key('study-question-prompt'))).data,
      isNot(firstPrompt),
    );
  });

  testWidgets(
    'question and answer audio use repeat count and network-quality preference',
    (tester) async {
      final platform = _FakeTtsPlatform([
        {
          'name': 'Local English',
          'locale': 'en-US',
          'network_required': false,
          'quality': 100,
        },
        {
          'name': 'Cloud English',
          'locale': 'en-US',
          'network_required': true,
          'quality': 500,
        },
      ]);
      final tts = TtsService(platform: platform);
      const preferences = StudyPreferences(
        interaction: StudyInteractionPreferences(
          autoPlayQuestionAudio: true,
          autoPlayAnswerAudio: true,
          preferOfflineVoice: false,
          audioRepeatCount: 2,
          choiceLayout: StudyChoiceLayout.list,
          shuffleChoices: false,
        ),
      );

      await _pumpStudy(
        tester,
        preferences: preferences,
        tts: tts,
        screen: const StudyScreen(mode: StudyMode.meaning, itemLimit: 2),
      );

      expect(platform.spoken, hasLength(2));
      expect(platform.spoken.toSet(), hasLength(1));
      expect(platform.voices.last['name'], 'Cloud English');

      await tester.tap(find.byKey(const Key('study-choice-0')));
      await tester.tap(find.byKey(const Key('submit-study-answer')));
      await tester.pumpAndSettle();

      expect(platform.spoken, hasLength(4));
      expect(platform.spoken.toSet(), hasLength(1));
      expect(find.text('재생 4회'), findsOneWidget);
    },
  );

  testWidgets('selection and answer result emit configured feedback cues', (
    tester,
  ) async {
    final cues = <AppFeedbackCue>[];
    const experience = AppExperiencePreferences(hapticsEnabled: true);
    final feedback = AppFeedbackService(
      readPreferences: () => experience,
      emitHaptic: (cue) async => cues.add(cue),
      emitSound: (_) async {},
    );
    const preferences = StudyPreferences(
      experience: experience,
      interaction: StudyInteractionPreferences(
        choiceLayout: StudyChoiceLayout.list,
        shuffleChoices: false,
      ),
    );

    await _pumpStudy(
      tester,
      preferences: preferences,
      feedback: feedback,
      screen: const StudyScreen(mode: StudyMode.meaning, itemLimit: 2),
    );

    await tester.tap(find.byKey(const Key('study-choice-1')));
    await tester.tap(find.byKey(const Key('submit-study-answer')));
    await tester.pump();
    expect(cues, [AppFeedbackCue.selection, AppFeedbackCue.error]);

    await tester.tap(find.byKey(const Key('next-question-from-feedback')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('study-choice-0')));
    await tester.tap(find.byKey(const Key('submit-study-answer')));
    await tester.pump();
    expect(cues, [
      AppFeedbackCue.selection,
      AppFeedbackCue.error,
      AppFeedbackCue.selection,
      AppFeedbackCue.success,
    ]);
  });

  testWidgets('Korean and native reading aids stay independently visible', (
    tester,
  ) async {
    final item = sampleContent.firstWhere(
      (candidate) =>
          candidate.learningLanguage == LanguageTag.japanese &&
          candidate.koreanPronunciation != null &&
          candidate.readings.any(
            (reading) => reading.scheme != ReadingScheme.hangul,
          ),
    );
    final koreanOnly = item.readingAidsLabelFor(
      showKoreanReading: true,
      showNativeReading: false,
    );
    final nativeOnly = item.readingAidsLabelFor(
      showKoreanReading: false,
      showNativeReading: true,
    );

    await _pumpStudy(
      tester,
      language: LanguageTag.japanese,
      preferences: StudyPreferences(
        activeSubjectId: 'language:ja',
        favoriteItemIds: {item.id},
        interaction: const StudyInteractionPreferences(
          showKoreanReading: true,
          showNativeReading: false,
        ),
      ),
      screen: const StudyScreen(mode: StudyMode.favorites, itemLimit: 1),
    );

    expect(
      tester
          .widget<Text>(find.byKey(const Key('study-question-reading-aids')))
          .data,
      koreanOnly,
    );
    expect(find.text(nativeOnly), findsNothing);
    await tester.tap(find.byKey(const Key('show-study-hint')));
    await tester.pump();
    final koreanHint = _textWithin(
      tester,
      find.byKey(const Key('study-hint-card')),
    );
    expect(koreanHint, contains(koreanOnly));
    for (final nativeLabel in nativeOnly.split('\n')) {
      expect(koreanHint, isNot(contains(nativeLabel)));
    }
    final correctChoice = find.text(item.primaryTranslation);
    await tester.ensureVisible(correctChoice);
    await tester.pump();
    await tester.tap(correctChoice);
    await tester.tap(find.byKey(const Key('submit-study-answer')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('study-feedback-popup')),
        matching: find.text(koreanOnly),
      ),
      findsOneWidget,
    );

    await _pumpStudy(
      tester,
      language: LanguageTag.japanese,
      preferences: StudyPreferences(
        activeSubjectId: 'language:ja',
        favoriteItemIds: {item.id},
        interaction: const StudyInteractionPreferences(
          showKoreanReading: false,
          showNativeReading: true,
        ),
      ),
      screen: const StudyScreen(mode: StudyMode.favorites, itemLimit: 1),
    );

    expect(
      tester
          .widget<Text>(find.byKey(const Key('study-question-reading-aids')))
          .data,
      nativeOnly,
    );
    expect(find.text(koreanOnly), findsNothing);
    await tester.tap(find.byKey(const Key('show-study-hint')));
    await tester.pump();
    final nativeHint = _textWithin(
      tester,
      find.byKey(const Key('study-hint-card')),
    );
    for (final nativeLabel in nativeOnly.split('\n')) {
      expect(nativeHint, contains(nativeLabel));
    }
    expect(nativeHint, isNot(contains(koreanOnly)));
  });
}

String _textWithin(WidgetTester tester, Finder finder) => tester
    .widgetList<Text>(find.descendant(of: finder, matching: find.byType(Text)))
    .map((text) => text.data ?? '')
    .join('\n');

Future<void> _pumpStudy(
  WidgetTester tester, {
  required StudyPreferences preferences,
  required Widget screen,
  LanguageTag language = LanguageTag.english,
  TtsService? tts,
  AppFeedbackService? feedback,
}) async {
  final store = MemoryStudyStore(
    profile: _profileFor(language),
    preferences: preferences,
  );
  final controller = AppController(store);
  for (var attempt = 0; attempt < 20; attempt++) {
    if (controller.state.isHydrated) break;
    await tester.pump();
  }
  expect(controller.state.isHydrated, isTrue);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        studyStoreProvider.overrideWithValue(store),
        appControllerProvider.overrideWith((ref) => controller),
        if (tts != null) studyTtsServiceProvider.overrideWithValue(tts),
        if (feedback != null)
          studyFeedbackServiceProvider.overrideWithValue(feedback),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

StoredProfile _profileFor(LanguageTag language) => StoredProfile(
  selectedLanguage: language,
  totalXp: 0,
  streakDays: 0,
  dailyXp: 0,
  badges: const {},
  driveConnected: false,
  progress: const {},
);

class _FakeTtsPlatform implements TtsPlatformAdapter {
  _FakeTtsPlatform(this.rawVoices);

  final List<Object?> rawVoices;
  final List<Map<String, String>> voices = [];
  final List<String> spoken = [];

  @override
  Future<List<Object?>> loadVoices() async => rawVoices;

  @override
  Future<void> setLanguage(String locale) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    voices.add(voice);
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}
