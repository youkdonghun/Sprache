import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test('answer events, sessions, and preferences reach the store', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final item = sampleContent.first;
    final studiedAt = DateTime.utc(2026, 7, 27, 10);

    controller.recordAnswer(
      item: item,
      correct: true,
      studiedAt: studiedAt,
      exerciseType: 'recognition',
    );
    controller.updatePreferences(
      controller.state.preferences.copyWith(
        newItemLimit: 14,
        preferredMode: StudyMode.review,
      ),
    );
    controller.toggleFavorite(item.id);
    controller.completeMission(0);
    await Future<void>.delayed(Duration.zero);

    expect(store.savedEvents, hasLength(1));
    expect(store.savedEvents.single.itemId, item.id);
    expect(store.savedEvents.single.result, 'correct');
    expect(store.savedEvents.single.exerciseType, 'recognition');
    expect(store.savedPreferences.newItemLimit, 14);
    expect(store.savedPreferences.preferredMode, StudyMode.review);
    expect(store.savedPreferences.favoriteItemIds, contains(item.id));
    expect(store.savedPreferences.hasCompletedMission('ko-en', 0), isTrue);
    expect(controller.completedMissionCount, 1);
    expect(
      controller.queue(studiedAt, mode: StudyMode.favorites),
      contains(item),
    );

    final session = StudySessionSummary(
      sessionId: 'session-test',
      courseId: item.learningLanguage.courseId,
      startedAt: studiedAt,
      endedAt: studiedAt.add(const Duration(minutes: 4)),
      correctCount: 8,
      wrongCount: 2,
      earnedXp: 90,
    );
    await controller.finishSession(session);

    expect(store.savedSessions, [session]);
    expect(controller.state.recentSessions.first.sessionId, 'session-test');
    final archive = controller.exportArchive();
    expect(archive['settings'], isA<Map<String, Object?>>());
    expect(archive['sessions'], hasLength(1));
  });

  test('active quiz state is persisted, updated, and cleared', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final items = controller.selectedItems.take(5).toList();
    final startedAt = DateTime.utc(2026, 7, 27, 11);

    controller.updatePreferences(
      controller.state.preferences.copyWith(sessionItemLimit: 5),
    );
    expect(controller.queue(startedAt), hasLength(5));

    controller.beginActiveStudySession(
      sessionId: 'active-1',
      mode: StudyMode.meaning,
      unitIndex: null,
      itemIds: items.map((item) => item.id).toList(),
      startedAt: startedAt,
    );
    controller.updateActiveStudySession(
      itemIds: items.map((item) => item.id).toList(),
      currentIndex: 2,
      correctCount: 1,
      wrongCount: 1,
      earnedXp: 15,
      updatedAt: startedAt.add(const Duration(minutes: 1)),
    );
    await Future<void>.delayed(Duration.zero);

    expect(store.savedActiveStudySession?.currentIndex, 2);
    expect(controller.state.activeStudySession?.remainingCount, 3);
    expect(controller.state.activeStudySession?.earnedXp, 15);

    controller.clearActiveStudySession();
    await Future<void>.delayed(Duration.zero);

    expect(store.savedActiveStudySession, isNull);
    expect(controller.state.activeStudySession, isNull);
  });

  test('custom item tombstones survive controller hydration', () async {
    final store = MemoryStudyStore();
    final first = AppController(store);
    await Future<void>.delayed(Duration.zero);
    const item = LearningItem(
      id: 'persistent-deletion',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'temporary',
      translations: ['임시'],
      acceptedAnswers: ['임시'],
    );
    await first.upsertCustomItem(item);
    await first.deleteCustomItem(item.id);
    first.dispose();

    final restored = AppController(store);
    await Future<void>.delayed(Duration.zero);

    expect(restored.state.customItems, isEmpty);
    expect(restored.state.customItemTombstones, contains(item.id));
    expect(store.savedItemTombstones, contains(item.id));
    restored.dispose();
  });

  test('four-level flashcard rating controls interval and XP', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final item = controller.selectedItems.first;
    final studiedAt = DateTime.utc(2026, 7, 27, 12);

    controller.recordAnswer(
      item: item,
      correct: true,
      studiedAt: studiedAt,
      exerciseType: 'flashcard_hard',
      rating: ReviewRating.hard,
    );
    await Future<void>.delayed(Duration.zero);

    final progress = controller.state.progress[item.id]!;
    expect(progress.lastResult, ReviewRating.hard);
    expect(progress.currentIntervalDays, 1);
    expect(progress.nextReviewAt, studiedAt.add(const Duration(days: 1)));
    expect(controller.state.totalXp, 8);
    expect(store.savedEvents.single.result, 'correct');
  });

  test('pending snapshot survives controller recreation', () async {
    final store = MemoryStudyStore();
    final first = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final item = first.selectedItems.first;

    first.recordAnswer(
      item: item,
      correct: true,
      studiedAt: DateTime.utc(2026, 7, 28, 10),
      exerciseType: 'recognition',
    );
    await Future<void>.delayed(Duration.zero);
    final queued = store.pendingSnapshotSync;

    expect(queued, isNotNull);
    expect(first.state.pendingSync?.operationId, queued?.operationId);
    first.dispose();

    final restored = AppController(store);
    await Future<void>.delayed(Duration.zero);

    expect(restored.state.pendingSync?.operationId, queued?.operationId);
    final queuedProfile =
        restored.state.pendingSync?.payload['profile'] as Map<String, Object?>?;
    expect(queuedProfile?['totalXp'], greaterThan(0));
    restored.dispose();
  });

  test(
    'completing an older upload never deletes a newer queued snapshot',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);
      final first = await controller.queueSyncSnapshot(
        now: DateTime.utc(2026, 7, 28, 10),
      );
      final second = await controller.queueSyncSnapshot(
        now: DateTime.utc(2026, 7, 28, 10, 1),
      );

      await controller.completePendingSync(first.operationId);

      expect(controller.state.pendingSync?.operationId, second.operationId);
      expect(store.pendingSnapshotSync?.operationId, second.operationId);

      final failed = await controller.markPendingSyncFailed(
        second.operationId,
        now: DateTime.utc(2026, 7, 28, 10, 2),
      );
      expect(failed?.attempts, 1);
      expect(failed?.nextAttemptAt, DateTime.utc(2026, 7, 28, 10, 2, 5));
      controller.dispose();
    },
  );

  test('session builder plan persists and is queued for Drive sync', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);
    const plan = StudySessionPlan(
      mode: StudyMode.listening,
      deck: StudyDeckScope.unit,
      unitIndex: 4,
      difficulty: StudyDifficulty.review,
      tags: {'여행'},
      levels: {'입문'},
      includeWords: false,
      sentenceRatio: 0.8,
      itemLimit: 15,
    );

    controller.updateSessionPlan(plan);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(store.savedPreferences.sessionPlan.deck, StudyDeckScope.unit);
    expect(store.savedPreferences.sessionPlan.unitIndex, 4);
    expect(store.savedPreferences.sessionPlan.tags, {'여행'});
    expect(store.savedPreferences.sessionPlan.updatedAt, isNotNull);
    final settings =
        store.pendingSnapshotSync?.payload['settings'] as Map<String, Object?>?;
    final queuedPlan = settings?['sessionPlan'] as Map<String, Object?>?;
    expect(queuedPlan?['mode'], 'listening');
    expect(queuedPlan?['itemLimit'], 15);
    expect(queuedPlan?['updatedAt'], isNotNull);
    controller.dispose();

    final restored = AppController(store);
    await Future<void>.delayed(Duration.zero);
    expect(restored.state.preferences.sessionPlan.mode, StudyMode.listening);
    expect(
      restored.state.preferences.sessionPlan.difficulty,
      StudyDifficulty.review,
    );
    restored.dispose();
  });

  test('editing custom content increments its content version', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);
    const first = LearningItem(
      id: 'versioned-item',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'draft',
      translations: ['초안'],
      acceptedAnswers: ['초안'],
      partOfSpeech: PartOfSpeech.noun,
    );
    const edited = LearningItem(
      id: 'versioned-item',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'revision',
      translations: ['수정본'],
      acceptedAnswers: ['수정본'],
      partOfSpeech: PartOfSpeech.noun,
    );

    await controller.upsertCustomItem(first);
    await controller.upsertCustomItem(edited);

    expect(controller.state.customItems.single.source.contentVersion, 2);
    expect(store.savedItems.single.source.contentVersion, 2);
    controller.dispose();
  });

  test('semantic import replacement preserves the existing item ID', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);
    const existing = LearningItem(
      id: 'existing-record',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'record',
      translations: ['기록'],
      acceptedAnswers: ['기록'],
      partOfSpeech: PartOfSpeech.noun,
    );
    const imported = LearningItem(
      id: 'foreign-record-id',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'record',
      translations: ['기록'],
      acceptedAnswers: ['기록', '기록물'],
      partOfSpeech: PartOfSpeech.noun,
      source: ContentSource(
        name: 'Imported notebook',
        license: 'private',
        sourceVersion: '2',
        contentVersion: 1,
      ),
    );
    await controller.upsertCustomItem(existing);

    final kept = await controller.importItems([imported]);
    final replaced = await controller.importItems([
      imported,
    ], conflictPolicy: ImportConflictPolicy.replaceExisting);

    expect(kept.skipped, 1);
    expect(replaced.replaced, 1);
    expect(controller.state.customItems, hasLength(1));
    expect(controller.state.customItems.single.id, existing.id);
    expect(
      controller.state.customItems.single.source.name,
      'Imported notebook',
    );
    expect(controller.state.customItems.single.source.contentVersion, 2);
    controller.dispose();
  });
}
