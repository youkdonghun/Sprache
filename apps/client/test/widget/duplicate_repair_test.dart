import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets(
    'duplicate repair lets the user choose canonical content and merge fields',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      const first = LearningItem(
        id: 'duplicate-ui-first',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        subjectId: 'language:en',
        text: 'Draft',
        translations: ['초안'],
        acceptedAnswers: ['초안'],
        example: 'Keep this example.',
        exampleTranslation: '이 예문을 유지합니다.',
        tags: ['office'],
      );
      const second = LearningItem(
        id: 'duplicate-ui-second',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        subjectId: 'language:en',
        text: ' draft ',
        translations: ['작성하다'],
        acceptedAnswers: ['작성하다'],
        example: 'Do not copy this example.',
        exampleTranslation: '이 예문은 복사하지 않습니다.',
        tags: ['writing'],
      );
      final store = MemoryStudyStore(
        profile: const StoredProfile(
          selectedLanguage: LanguageTag.english,
          totalXp: 0,
          streakDays: 0,
          dailyXp: 0,
          badges: {},
          driveConnected: false,
          progress: {
            'duplicate-ui-second': ProgressRecord(
              itemId: 'duplicate-ui-second',
              status: LearningStatus.review,
              correctCount: 4,
            ),
          },
        ),
        preferences: const StudyPreferences(activeSubjectId: 'language:en'),
      );
      await store.saveCustomItems(const [first, second]);

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [studyStoreProvider.overrideWithValue(store)],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('자료실').last);
        await tester.pumpAndSettle();

        final open = find.byKey(const Key('open-duplicate-repair'));
        await tester.ensureVisible(open);
        await tester.tap(open);
        await tester.pumpAndSettle();
        expect(find.text('중복 자료 수선'), findsOneWidget);
        expect(find.text('같은 표현·언어·주제로 묶였습니다.'), findsOneWidget);

        await tester.tap(
          find.byKey(const Key('duplicate-canonical-duplicate-ui-first')),
        );
        await tester.tap(find.byKey(const Key('duplicate-field-examples')));
        final merge = find.text('이 묶음 합치기');
        await tester.ensureVisible(merge);
        await tester.tap(merge);
        await tester.pumpAndSettle();

        expect(store.savedItems, hasLength(1));
        final merged = store.savedItems.single;
        expect(merged.id, first.id);
        expect(merged.translations, containsAll(['초안', '작성하다']));
        expect(merged.tags, containsAll(['office', 'writing']));
        expect(merged.example, first.example);
        final mergedProfile = await store.loadProfile();
        expect(mergedProfile.progress, contains(first.id));
        expect(mergedProfile.progress, isNot(contains(second.id)));

        await tester.tap(find.text('되돌리기'));
        await tester.pumpAndSettle();
        expect(store.savedItems, hasLength(2));
        expect((await store.loadProfile()).progress, contains(second.id));
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );
}
