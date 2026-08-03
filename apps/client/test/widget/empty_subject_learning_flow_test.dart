import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_subject.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('empty subject home prioritizes adding the first learning item', (
    tester,
  ) async {
    await _pumpEmptySubjectApp(tester);

    expect(find.text('첫 단어나 문장을 추가해 보세요'), findsOneWidget);
    expect(find.text('단어·문장 추가'), findsOneWidget);
    expect(find.text('오늘 목표를 마쳤어요'), findsNothing);
    expect(find.text('다음 레슨'), findsNothing);

    await tester.tap(find.byKey(const Key('home-primary-study-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('item-editor-scroll')), findsOneWidget);
    expect(find.text('새 표현 추가'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty subject learning hub explains disabled activities and links add flow',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final container = await _pumpEmptySubjectApp(tester);
        container.read(appRouterProvider).go('/learn');
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('learning-hub-missing-material-notice')),
          findsOneWidget,
        );
        expect(find.text('학습할 자료가 없어요'), findsOneWidget);
        expect(find.text('이 주제에 학습 자료가 없어요.'), findsWidgets);

        await tester.tap(find.text('전체 게임'));
        await tester.pumpAndSettle();
        expect(_activityInkWell(tester, '혼합 퀴즈').onTap, isNull);
        expect(
          tester
              .getSemantics(find.byKey(const Key('practice-activity-혼합 퀴즈')))
              .label,
          contains('혼합 퀴즈. 사용 불가. 이 주제에 학습 자료가 없어요.'),
        );

        await tester.tap(find.text('추천'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('learning-hub-add-content')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('item-editor-scroll')), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('learning hub disables only unsupported material capabilities', (
    tester,
  ) async {
    final store = _emptySubjectStore();
    await store.saveCustomItems(const [
      LearningItem(
        id: 'recognition-only-item',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        subjectId: 'general:empty-learning-flow',
        text: 'starter',
        translations: ['시작'],
        acceptedAnswers: ['시작'],
        capabilities: {ExerciseCapability.recognition},
      ),
    ]);
    final container = await _pumpEmptySubjectApp(tester, store: store);
    container.read(appRouterProvider).go('/learn');
    await tester.pumpAndSettle();
    await tester.tap(find.text('전체 게임'));
    await tester.pumpAndSettle();

    expect(_activityInkWell(tester, '혼합 퀴즈').onTap, isNotNull);
    expect(_activityInkWell(tester, '뜻 고르기').onTap, isNotNull);
    expect(_activityInkWell(tester, '직접 쓰기').onTap, isNull);
    expect(_activityInkWell(tester, '발음 따라하기').onTap, isNull);
    expect(find.text('직접 쓰기를 지원하는 자료가 없어요.'), findsOneWidget);
    expect(find.text('듣기를 지원하는 발음 자료가 없어요.'), findsOneWidget);
    expect(find.text('일부 게임을 시작할 자료가 부족해요'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '지원 자료 추가'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty flashcard and pronunciation screens offer material CTA', (
    tester,
  ) async {
    final container = await _pumpEmptySubjectApp(tester);

    container.read(appRouterProvider).go('/cards?kind=words');
    await tester.pumpAndSettle();
    expect(find.text('학습할 카드가 없어요'), findsOneWidget);
    expect(
      find.byKey(const Key('empty-flashcard-add-content')),
      findsOneWidget,
    );

    container.read(appRouterProvider).go('/pronunciation');
    await tester.pumpAndSettle();
    expect(find.text('발음 연습에 사용할 표현이 없어요'), findsOneWidget);
    expect(
      find.byKey(const Key('empty-pronunciation-add-content')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('empty-pronunciation-add-content')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('item-editor-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _pumpEmptySubjectApp(
  WidgetTester tester, {
  MemoryStudyStore? store,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studyStoreProvider.overrideWithValue(store ?? _emptySubjectStore()),
      ],
      child: const SpracheApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(SpracheApp)));
}

MemoryStudyStore _emptySubjectStore() {
  return MemoryStudyStore(preferences: _emptySubjectPreferences);
}

InkWell _activityInkWell(WidgetTester tester, String title) {
  final card = find.byKey(Key('practice-activity-$title'));
  expect(card, findsOneWidget);
  final material = tester.widget<Material>(card);
  expect(material.child, isA<InkWell>());
  return material.child! as InkWell;
}

const _emptySubject = StudySubject(
  id: 'general:empty-learning-flow',
  kind: StudySubjectKind.general,
  name: '새 주제',
  description: '',
  symbol: '＋',
  contentLanguage: LanguageTag.english,
);

const _emptySubjectPreferences = StudyPreferences(
  onboardingCompleted: true,
  activeSubjectId: 'general:empty-learning-flow',
  customSubjects: [_emptySubject],
);
