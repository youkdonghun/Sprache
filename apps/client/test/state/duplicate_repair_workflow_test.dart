import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/duplicate_repair.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test(
    'selective merge consolidates progress and session IDs and undo restores all',
    () async {
      final now = DateTime.utc(2026, 7, 31, 10);
      const canonicalId = 'draft-a';
      const duplicateId = 'draft-b';
      const canonical = LearningItem(
        id: canonicalId,
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.japanese,
        subjectId: 'language:ja',
        text: 'Draft',
        translations: ['초안'],
        acceptedAnswers: ['초안'],
        readings: [Reading(scheme: ReadingScheme.hangul, value: '드래프트')],
        example: 'This is the canonical example.',
        exampleTranslation: '대표 예문입니다.',
        partOfSpeech: PartOfSpeech.noun,
        tags: ['office'],
      );
      const duplicate = LearningItem(
        id: duplicateId,
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.japanese,
        subjectId: 'language:ja',
        text: ' draft ',
        translations: ['작성하다'],
        acceptedAnswers: ['작성하다'],
        readings: [Reading(scheme: ReadingScheme.romaji, value: 'draft')],
        example: 'This example must not replace the selected canonical one.',
        exampleTranslation: '대체되면 안 됩니다.',
        partOfSpeech: PartOfSpeech.verb,
        tags: ['writing'],
      );
      final progressA = ProgressRecord(
        itemId: canonical.id,
        status: LearningStatus.learning,
        correctCount: 2,
        wrongCount: 1,
        currentIntervalDays: 3,
        nextReviewAt: now.add(const Duration(days: 3)),
        lastStudiedAt: now.subtract(const Duration(days: 1)),
        lastResult: ReviewRating.good,
      );
      final progressB = ProgressRecord(
        itemId: duplicate.id,
        status: LearningStatus.mastered,
        correctCount: 4,
        wrongCount: 2,
        lapseCount: 1,
        currentIntervalDays: 30,
        nextReviewAt: now.add(const Duration(days: 30)),
        lastStudiedAt: now,
        lastResult: ReviewRating.easy,
      );
      final preferences = StudyPreferences(
        activeSubjectId: 'language:ja',
        favoriteItemIds: const {duplicateId},
        favoriteItemChangedAtById: {duplicateId: now},
        excludedItemIds: const {duplicateId},
        excludedItemChangedAtById: {duplicateId: now},
        sessionPlan: const StudySessionPlan(
          subjectId: 'language:ja',
          deck: StudyDeckScope.selected,
          selectedItemIds: {canonicalId, duplicateId, 'other'},
        ),
      );
      final profile = StoredProfile(
        selectedLanguage: LanguageTag.japanese,
        totalXp: 100,
        streakDays: 2,
        dailyXp: 20,
        badges: const {},
        driveConnected: false,
        progress: {canonical.id: progressA, duplicate.id: progressB},
      );
      final active = ActiveStudySession.started(
        sessionId: 'active',
        courseId: 'ko-ja',
        mode: StudyMode.mixed,
        unitIndex: null,
        itemIds: const [duplicateId, canonicalId, 'other'],
        startedAt: now,
      );
      final summary = StudySessionSummary(
        sessionId: 'recent',
        courseId: 'ko-ja',
        startedAt: now.subtract(const Duration(minutes: 5)),
        endedAt: now,
        correctCount: 1,
        wrongCount: 1,
        earnedXp: 15,
        itemIds: const [duplicateId, canonicalId, 'other'],
        wrongItemIds: const {duplicateId},
        finalCorrectItemIds: const {canonicalId},
      );
      final store = MemoryStudyStore(
        profile: profile,
        preferences: preferences,
        activeStudySession: active,
      );
      await store.saveCustomItems(const [canonical, duplicate]);
      await store.saveStudySession(summary);
      final controller = AppController(store);
      await _waitForHydration(controller);

      final result = await controller.mergeDuplicateCustomItems(
        const DuplicateMergeRequest(
          canonicalItemId: canonicalId,
          duplicateItemIds: {duplicateId},
          fields: {
            DuplicateMergeField.meanings,
            DuplicateMergeField.readings,
            DuplicateMergeField.tags,
          },
        ),
      );

      final merged = controller.customItemById(canonical.id)!;
      expect(controller.customItemById(duplicate.id), isNull);
      expect(merged.translations, containsAll(['초안', '작성하다']));
      expect(merged.readings, hasLength(2));
      expect(merged.tags, containsAll(['office', 'writing']));
      expect(merged.example, canonical.example);
      expect(controller.state.progress.keys, contains(canonical.id));
      expect(controller.state.progress.keys, isNot(contains(duplicate.id)));
      expect(
        controller.state.progress[canonical.id]?.status,
        LearningStatus.mastered,
      );
      expect(controller.state.progress[canonical.id]?.correctCount, 6);
      expect(controller.state.progress[canonical.id]?.wrongCount, 3);
      expect(controller.state.preferences.favoriteItemIds, {canonical.id});
      expect(controller.state.preferences.excludedItemIds, {canonical.id});
      expect(
        controller.state.preferences.contentItemAliases[duplicate.id],
        canonical.id,
      );
      expect(controller.state.preferences.sessionPlan.selectedItemIds, {
        canonical.id,
        'other',
      });
      expect(controller.state.recentSessions.single.itemIds, [
        canonical.id,
        'other',
      ]);
      expect(controller.state.activeStudySession?.itemIds, [
        canonical.id,
        'other',
      ]);

      final staleStore = MemoryStudyStore(
        profile: StoredProfile(
          selectedLanguage: LanguageTag.japanese,
          totalXp: 0,
          streakDays: 0,
          dailyXp: 0,
          badges: const {},
          driveConnected: true,
          progress: {
            duplicate.id: ProgressRecord(
              itemId: duplicate.id,
              status: LearningStatus.review,
              correctCount: 1,
            ),
          },
        ),
        preferences: const StudyPreferences(activeSubjectId: 'language:ja'),
      );
      await staleStore.saveCustomItems(const [duplicate]);
      await staleStore.saveStudySession(
        StudySessionSummary(
          sessionId: 'stale-session',
          courseId: 'ko-ja',
          startedAt: now,
          endedAt: now.add(const Duration(minutes: 1)),
          correctCount: 1,
          wrongCount: 0,
          earnedXp: 10,
          itemIds: const [duplicateId],
          finalCorrectItemIds: const {duplicateId},
        ),
      );
      final staleController = AppController(staleStore);
      await _waitForHydration(staleController);
      await staleController.mergeRemoteSnapshot(
        controller.exportSyncSnapshot(),
      );
      expect(staleController.state.progress, isNot(contains(duplicate.id)));
      expect(staleController.state.progress, contains(canonical.id));
      expect(
        staleController.state.recentSessions
            .firstWhere((session) => session.sessionId == 'stale-session')
            .itemIds,
        [canonical.id],
      );
      staleController.dispose();

      final undo = await controller.undoDuplicateRepair(result.undoToken);
      expect(undo.status, DuplicateRepairUndoStatus.restored);
      expect(controller.customItemById(canonical.id), isNotNull);
      expect(controller.customItemById(duplicate.id), isNotNull);
      expect(controller.state.progress[canonical.id]?.correctCount, 2);
      expect(controller.state.progress[duplicate.id]?.correctCount, 4);
      expect(controller.state.preferences.sessionPlan.selectedItemIds, {
        canonical.id,
        duplicate.id,
        'other',
      });
      expect(controller.state.preferences.contentItemAliases, isEmpty);
      expect(controller.state.recentSessions.single.itemIds, summary.itemIds);
      expect(controller.state.activeStudySession?.itemIds, active.itemIds);
      expect(
        (await controller.undoDuplicateRepair(result.undoToken)).status,
        DuplicateRepairUndoStatus.alreadyUndone,
      );
      controller.dispose();
    },
  );

  test('similar and cross-subject content cannot merge implicitly', () async {
    const correctId = 'correct';
    const typoId = 'typo';
    const otherSubjectId = 'other-subject';
    const correct = LearningItem(
      id: correctId,
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      subjectId: 'language:en',
      text: 'accommodate',
      translations: ['수용하다'],
      acceptedAnswers: ['수용하다'],
    );
    const typo = LearningItem(
      id: typoId,
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      subjectId: 'language:en',
      text: 'acommodate',
      translations: ['수용하다'],
      acceptedAnswers: ['수용하다'],
    );
    const otherSubject = LearningItem(
      id: otherSubjectId,
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      subjectId: 'custom:office',
      text: 'accommodate',
      translations: ['수용하다'],
      acceptedAnswers: ['수용하다'],
    );
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(activeSubjectId: 'language:en'),
    );
    await store.saveCustomItems(const [correct, typo, otherSubject]);
    final controller = AppController(store);
    await _waitForHydration(controller);

    await expectLater(
      controller.mergeDuplicateCustomItems(
        const DuplicateMergeRequest(
          canonicalItemId: correctId,
          duplicateItemIds: {typoId},
        ),
      ),
      throwsStateError,
    );
    await expectLater(
      controller.mergeDuplicateCustomItems(
        const DuplicateMergeRequest(
          canonicalItemId: correctId,
          duplicateItemIds: {otherSubjectId},
          confirmedSimilarSuggestion: true,
        ),
      ),
      throwsStateError,
    );
    expect(controller.customItemById(typo.id), isNotNull);
    expect(controller.customItemById(otherSubject.id), isNotNull);
    controller.dispose();
  });

  test(
    'reuses duplicate analysis until custom content actually changes',
    () async {
      final store = MemoryStudyStore(
        preferences: const StudyPreferences(activeSubjectId: 'language:en'),
      );
      await store.saveCustomItems(const [
        LearningItem(
          id: 'cache-a',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          text: 'cache',
          translations: ['캐시'],
          acceptedAnswers: ['캐시'],
        ),
        LearningItem(
          id: 'cache-b',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          text: ' cache ',
          translations: ['저장소'],
          acceptedAnswers: ['저장소'],
        ),
      ]);
      final controller = AppController(store);
      await _waitForHydration(controller);

      final first = controller.duplicateRepairCatalog(subjectId: 'language:en');
      final second = controller.duplicateRepairCatalog(
        subjectId: 'language:en',
      );
      expect(identical(first, second), isTrue);

      await controller.upsertCustomItem(
        controller.state.customItems.first.copyWith(tags: const ['changed']),
      );
      final afterEdit = controller.duplicateRepairCatalog(
        subjectId: 'language:en',
      );
      expect(identical(first, afterEdit), isFalse);
      controller.dispose();
    },
  );
}

Future<void> _waitForHydration(AppController controller) async {
  for (
    var attempt = 0;
    attempt < 100 && !controller.state.isHydrated;
    attempt++
  ) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(controller.state.isHydrated, isTrue);
}
