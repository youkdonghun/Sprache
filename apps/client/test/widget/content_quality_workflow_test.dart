import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('quality queue filters issues and only edits user content', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(onboardingCompleted: true),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [studyStoreProvider.overrideWithValue(store)],
        child: const SpracheApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpracheApp)),
    );
    await container
        .read(appControllerProvider.notifier)
        .saveQuickContent(
          const LearningItem(
            id: 'quality-user-item',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.english,
            subjectId: 'language:en',
            text: 'quality draft',
            translations: ['품질 초안'],
            acceptedAnswers: ['품질 초안'],
            capabilities: {ExerciseCapability.recognition},
            source: ContentSource.userCreated,
          ),
        );
    await tester.pumpAndSettle();

    container.read(appRouterProvider).go('/settings');
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('open-content-quality'));
    expect(entry, findsOneWidget);
    container.read(appRouterProvider).go('/library/quality');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('content-quality-screen')), findsOneWidget);
    expect(find.byKey(const Key('content-quality-filters')), findsOneWidget);
    expect(find.byKey(const Key('next-quality-item')), findsOneWidget);
    expect(
      find.byKey(const Key('edit-quality-quality-user-item')),
      findsOneWidget,
    );
    expect(find.text('내용 보기'), findsWidgets);

    await tester.tap(find.byKey(const Key('quality-filter-exerciseNotReady')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('quality-item-quality-user-item')),
      findsOneWidget,
    );
    expect(find.textContaining('사용할 수 있는 연습 방식'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
