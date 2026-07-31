import 'dart:ui' show SemanticsAction;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_subject.dart';
import 'package:sprache/src/screens/flashcard_screen.dart';
import 'package:sprache/src/screens/pronunciation_screen.dart';
import 'package:sprache/src/screens/study_screen.dart';
import 'package:sprache/src/services/tts_service.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets(
    'Windows flashcard announces answers and moves focus through keyboard flow',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final semantics = tester.ensureSemantics();
      final store = MemoryStudyStore(
        profile: _japaneseProfile,
        preferences: _pronunciationPreferences,
      );
      await store.saveCustomItems(_pronunciationItems);

      try {
        await _pumpHydratedScreen(
          tester,
          store: store,
          screen: FlashcardScreen(
            kind: FlashcardKind.words,
            ttsService: TtsService(platform: _NoopTtsPlatform()),
          ),
        );

        final revealButton = tester.widget<FilledButton>(
          find.byKey(const Key('reveal-flashcard')),
        );
        expect(revealButton.focusNode?.hasFocus, isTrue);
        expect(
          tester
              .getSemantics(
                find.bySemanticsLabel(
                  '뜻과 설명 보기. 카드를 뒤집고 평가 버튼으로 이동합니다. 단축키 Enter.',
                ),
              )
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        var status = tester.widget<Semantics>(
          find.byKey(const Key('flashcard-status-live-region')),
        );
        expect(status.properties.liveRegion, isTrue);
        expect(status.properties.label, contains('카드 1/2 앞면'));

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        final rememberedButton = tester.widget<FilledButton>(
          find.descendant(
            of: find.byKey(const Key('flashcard-remembered')),
            matching: find.byType(FilledButton),
          ),
        );
        expect(rememberedButton.focusNode?.hasFocus, isTrue);
        status = tester.widget<Semantics>(
          find.byKey(const Key('flashcard-status-live-region')),
        );
        expect(status.properties.label, contains('답 공개. 練習一.'));
        expect(status.properties.label, contains('뜻 연습 하나.'));
        expect(status.properties.label, contains('단축키 1부터 4.'));
        expect(
          find.bySemanticsLabel(RegExp(r'기억남으로 평가\. 단축키 3\. 다음 복습 .+ 후\.')),
          findsOneWidget,
        );
        expect(
          tester
              .getSemantics(
                find.bySemanticsLabel(
                  RegExp(r'기억남으로 평가\. 단축키 3\. 다음 복습 .+ 후\.'),
                ),
              )
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(store.savedEvents, hasLength(1));
        expect(store.savedEvents.single.exerciseType, 'flashcard_good');
        expect(find.text('練習二'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('reveal-flashcard')))
              .focusNode
              ?.hasFocus,
          isTrue,
        );
        status = tester.widget<Semantics>(
          find.byKey(const Key('flashcard-status-live-region')),
        );
        expect(status.properties.label, contains('기억남으로 평가했습니다. 다음 카드 2/2 앞면'));

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(find.text('카드 학습을 마쳤어요'), findsOneWidget);
        status = tester.widget<Semantics>(
          find.byKey(const Key('flashcard-status-live-region')),
        );
        expect(status.properties.liveRegion, isTrue);
        expect(status.properties.label, contains('기억남으로 평가했습니다. 카드 학습 완료'));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'unavailable speech recognition offers explicit accessible self ratings',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final semantics = tester.ensureSemantics();
      final store = MemoryStudyStore(
        profile: _japaneseProfile,
        preferences: _pronunciationPreferences,
      );
      await store.saveCustomItems(_pronunciationItems);

      try {
        final controller = await _pumpHydratedScreen(
          tester,
          store: store,
          screen: PronunciationScreen(
            ttsService: TtsService(platform: _NoopTtsPlatform()),
          ),
        );

        expect(find.text('練習一'), findsOneWidget);
        await tester.tap(find.byKey(const Key('pronunciation-mic')));
        await tester.pumpAndSettle();

        expect(find.text('음성 인식 없이 스스로 평가'), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            '음성 인식 없이 스스로 평가. '
            '목표 발음을 듣고 따라 읽은 뒤 결과를 직접 선택하세요.',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('연습 필요로 평가하고 다음 표현으로 이동. 단축키 1'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('잘 읽었음으로 평가하고 다음 표현으로 이동. 단축키 2'),
          findsOneWidget,
        );

        final shortcuts = tester.widget<CallbackShortcuts>(
          find.byKey(const Key('pronunciation-self-assessment-shortcuts')),
        );
        expect(
          shortcuts.bindings,
          contains(const SingleActivator(LogicalKeyboardKey.digit1)),
        );
        expect(
          shortcuts.bindings,
          contains(const SingleActivator(LogicalKeyboardKey.digit2)),
        );

        final liveRegion = tester.widget<Semantics>(
          find.byKey(const Key('pronunciation-status-live-region')),
        );
        expect(liveRegion.properties.liveRegion, isTrue);
        expect(liveRegion.properties.label, contains('발음 인식 오류'));

        expect(
          find.byKey(const Key('pronunciation-self-needs-practice')),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        await tester.pumpAndSettle();

        expect(store.savedEvents, hasLength(1));
        expect(store.savedEvents.single.result, 'wrong');
        expect(
          controller.state.progress['pronunciation-fallback-1']?.wrongCount,
          1,
        );
        expect(find.text('練習二'), findsOneWidget);

        await tester.tap(find.byKey(const Key('pronunciation-mic')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('pronunciation-self-passed')));
        await tester.pumpAndSettle();

        expect(store.savedEvents.map((event) => event.result).toList(), [
          'wrong',
          'correct',
        ]);
        expect(
          controller.state.progress['pronunciation-fallback-2']?.correctCount,
          1,
        );
        expect(find.text('발음 연습을 마쳤어요'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('choice layout announces the actual number of choices', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final store = MemoryStudyStore(preferences: _choicePreferences);
    await store.saveCustomItems(_choiceItems);

    try {
      await _pumpHydratedScreen(
        tester,
        store: store,
        screen: const StudyScreen(mode: StudyMode.meaning, itemLimit: 1),
      );

      expect(find.byKey(const Key('study-choice-0')), findsOneWidget);
      expect(find.byKey(const Key('study-choice-1')), findsOneWidget);
      expect(find.byKey(const Key('study-choice-2')), findsNothing);
      expect(find.bySemanticsLabel('선택지 2개, 한 열 배치'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('선택지 4개')), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}

Future<AppController> _pumpHydratedScreen(
  WidgetTester tester, {
  required MemoryStudyStore store,
  required Widget screen,
}) async {
  final controller = AppController(store);
  for (var attempt = 0; attempt < 20; attempt++) {
    if (controller.state.isHydrated) break;
    await tester.pump();
  }
  expect(controller.state.isHydrated, isTrue);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studyStoreProvider.overrideWithValue(store),
        appControllerProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

const _pronunciationSubject = StudySubject(
  id: 'general:pronunciation-fallback',
  kind: StudySubjectKind.general,
  name: '발음 폴백',
  description: '',
  symbol: '声',
  contentLanguage: LanguageTag.japanese,
);

const _pronunciationPreferences = StudyPreferences(
  activeSubjectId: 'general:pronunciation-fallback',
  customSubjects: [_pronunciationSubject],
);

const _japaneseProfile = StoredProfile(
  selectedLanguage: LanguageTag.japanese,
  totalXp: 0,
  streakDays: 0,
  dailyXp: 0,
  badges: {},
  driveConnected: false,
  progress: {},
);

const _pronunciationItems = [
  LearningItem(
    id: 'pronunciation-fallback-1',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.japanese,
    subjectId: 'general:pronunciation-fallback',
    text: '練習一',
    translations: ['연습 하나'],
    acceptedAnswers: ['연습 하나'],
    capabilities: {ExerciseCapability.listening},
    priority: 10,
  ),
  LearningItem(
    id: 'pronunciation-fallback-2',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.japanese,
    subjectId: 'general:pronunciation-fallback',
    text: '練習二',
    translations: ['연습 둘'],
    acceptedAnswers: ['연습 둘'],
    capabilities: {ExerciseCapability.listening},
    priority: 9,
  ),
];

const _choiceSubject = StudySubject(
  id: 'general:choice-semantics',
  kind: StudySubjectKind.general,
  name: '선택지 의미',
  description: '',
  symbol: '2',
  contentLanguage: LanguageTag.english,
);

const _choicePreferences = StudyPreferences(
  activeSubjectId: 'general:choice-semantics',
  customSubjects: [_choiceSubject],
  interaction: StudyInteractionPreferences(
    choiceLayout: StudyChoiceLayout.list,
  ),
);

const _choiceItems = [
  LearningItem(
    id: 'choice-semantics-a',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    subjectId: 'general:choice-semantics',
    text: 'alpha',
    translations: ['알파'],
    acceptedAnswers: ['알파'],
    capabilities: {ExerciseCapability.recognition},
    priority: 10,
  ),
  LearningItem(
    id: 'choice-semantics-b',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    subjectId: 'general:choice-semantics',
    text: 'beta',
    translations: ['베타'],
    acceptedAnswers: ['베타'],
    capabilities: {ExerciseCapability.recognition},
    priority: 9,
  ),
];

class _NoopTtsPlatform implements TtsPlatformAdapter {
  @override
  Future<List<Object?>> loadVoices() async => const [];

  @override
  Future<void> setLanguage(String locale) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> setVoice(Map<String, String> voice) async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
