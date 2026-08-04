import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test(
    'advanced settings persist locally and enter the sync snapshot',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);

      controller.updateExperiencePreferences(
        const AppExperiencePreferences(
          colorMode: AppColorMode.dark,
          accentPalette: AppAccentPalette.violet,
          density: AppDensity.compact,
          reduceMotion: true,
        ),
      );
      controller.updateInteractionPreferences(
        const StudyInteractionPreferences(
          autoPlayQuestionAudio: true,
          showKoreanReading: false,
          choiceLayout: StudyChoiceLayout.grid,
          autoAdvanceCorrect: true,
        ),
      );
      controller.updateTtsRate(0.65);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final saved = store.savedPreferences;
      expect(saved.experience.colorMode, AppColorMode.dark);
      expect(saved.experience.accentPalette, AppAccentPalette.violet);
      expect(saved.experience.density, AppDensity.compact);
      expect(saved.experience.reduceMotion, isTrue);
      expect(saved.experience.updatedAt, isNotNull);
      expect(saved.interaction.autoPlayQuestionAudio, isTrue);
      expect(saved.interaction.showKoreanReading, isFalse);
      expect(saved.interaction.choiceLayout, StudyChoiceLayout.grid);
      expect(saved.interaction.autoAdvanceCorrect, isTrue);
      expect(saved.interaction.updatedAt, isNotNull);
      expect(saved.ttsRate, 0.65);
      expect(saved.settingsUpdatedAt, isNotNull);

      final settings = Map<String, Object?>.from(
        controller.exportSyncSnapshot()['settings']! as Map,
      );
      expect(settings['experience'], saved.experience.toJson());
      expect(settings['interaction'], saved.interaction.toJson());
      expect(settings['ttsRate'], 0.65);
      controller.dispose();
    },
  );

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

  test('custom session limit is not cut again by the global default', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final startedAt = DateTime.utc(2026, 7, 27, 11, 30);

    controller.updatePreferences(
      controller.state.preferences.copyWith(sessionItemLimit: 10),
    );
    final queue = controller.queue(
      startedAt,
      sessionPlan: const StudySessionPlan(itemLimit: 37),
    );

    expect(controller.selectedItems.length, greaterThanOrEqualTo(37));
    expect(queue, hasLength(37));
    controller.dispose();
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

  test('daily goals and earned XP stay separate by course', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final english = sampleContent.firstWhere(
      (item) => item.learningLanguage == LanguageTag.english,
    );
    final japanese = sampleContent.firstWhere(
      (item) => item.learningLanguage == LanguageTag.japanese,
    );
    final firstDay = DateTime(2026, 7, 28, 10);

    controller.recordAnswer(
      item: english,
      correct: true,
      studiedAt: firstDay,
      exerciseType: 'recognition',
    );
    controller.recordAnswer(
      item: japanese,
      correct: true,
      studiedAt: firstDay.add(const Duration(minutes: 1)),
      exerciseType: 'flashcard_easy',
      rating: ReviewRating.easy,
    );
    controller.selectLanguage(LanguageTag.japanese);
    controller.updateActiveDailyGoal(200);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.state.dailyXp, 25);
    expect(controller.state.dailyXpByCourse['ko-en'], 10);
    expect(controller.state.dailyXpByCourse['ko-ja'], 15);
    expect(controller.state.activeCourseDailyXp, 15);
    expect(controller.state.dailyGoal, 200);
    expect(
      controller.state.preferences.dailyGoalFor('language:en'),
      controller.state.preferences.dailyGoal,
    );

    controller.recordAnswer(
      item: english,
      correct: true,
      studiedAt: firstDay.add(const Duration(days: 1)),
      exerciseType: 'flashcard_hard',
      rating: ReviewRating.hard,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.state.dailyXp, 8);
    expect(controller.state.dailyXpByCourse, {'ko-en': 8});
    expect(controller.state.activeCourseDailyXp, 0);
    expect(
      controller.state.dailyXpByCourseAndReplica['ko-en']?.values.single,
      8,
    );

    final currentStreak = controller.state.streakDays;
    controller.recordAnswer(
      item: japanese,
      correct: true,
      studiedAt: firstDay.subtract(const Duration(days: 1)),
      exerciseType: 'backdated',
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(controller.state.dailyXp, 8);
    expect(controller.state.dailyXpByCourse, {'ko-en': 8});
    expect(controller.state.lastStudyDate, DateTime(2026, 7, 29));
    expect(controller.state.streakDays, currentStreak);

    controller.dispose();
    final restored = AppController(store);
    await Future<void>.delayed(Duration.zero);
    expect(restored.state.dailyXpByCourse, {'ko-en': 8});
    expect(restored.state.preferences.dailyGoalFor('language:ja'), 200);
    restored.dispose();
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
    'rapid profile writes keep the newest state in storage and pending sync',
    () async {
      final store = _DelayedFirstProfileStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);
      final item = controller.selectedItems.first;
      final firstAnswerAt = DateTime.utc(2026, 7, 31, 9);

      controller.recordAnswer(
        item: item,
        correct: true,
        studiedAt: firstAnswerAt,
        exerciseType: 'recognition',
      );
      await store.firstProfileWriteStarted.future;

      controller.recordAnswer(
        item: item,
        correct: true,
        studiedAt: firstAnswerAt.add(const Duration(minutes: 1)),
        exerciseType: 'recognition',
      );
      store.releaseFirstProfileWrite.complete();
      await controller.flushPendingWrites();

      final savedProfile = await store.loadProfile();
      final pendingProfile =
          store.pendingSnapshotSync?.payload['profile']
              as Map<String, Object?>?;
      expect(store.profileWriteCount, 2);
      expect(savedProfile.totalXp, controller.state.totalXp);
      expect(savedProfile.progress[item.id]?.attempts, 2);
      expect(pendingProfile?['totalXp'], controller.state.totalXp);
      expect(
        (store.pendingSnapshotSync?.payload['progress'] as List<Object?>?)
            ?.single,
        containsPair('correctCount', 2),
      );
      controller.dispose();
    },
  );

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

      final serverDelayed = await controller.markPendingSyncFailed(
        second.operationId,
        now: DateTime.utc(2026, 7, 28, 10, 3),
        minimumDelay: const Duration(seconds: 45),
      );
      expect(serverDelayed?.attempts, 2);
      expect(
        serverDelayed?.nextAttemptAt,
        DateTime.utc(2026, 7, 28, 10, 3, 45),
      );
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

  test(
    'editing bundled content stores an override and uses it everywhere',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);
      final bundled = sampleContent.firstWhere(
        (item) => item.id == 'en-starter-word-1',
      );
      final edited = bundled.copyWith(
        translations: const ['사용자가 고친 뜻'],
        acceptedAnswers: const ['사용자가 고친 뜻'],
      );

      await controller.upsertCustomItem(edited);

      final visible = controller.allContentItems
          .where((item) => item.id == bundled.id)
          .toList(growable: false);
      expect(visible, hasLength(1));
      expect(visible.single.primaryTranslation, '사용자가 고친 뜻');
      expect(controller.courseItems, contains(visible.single));
      expect(store.savedItems.single.id, bundled.id);
      expect(store.savedItems.single.primaryTranslation, '사용자가 고친 뜻');
      controller.dispose();

      final restored = AppController(store);
      await Future<void>.delayed(Duration.zero);
      final restoredVisible = restored.allContentItems.singleWhere(
        (item) => item.id == bundled.id,
      );
      expect(restoredVisible.primaryTranslation, '사용자가 고친 뜻');
      expect(
        restored.allContentItems.where((item) => item.id == bundled.id),
        hasLength(1),
      );
      restored.dispose();
    },
  );

  test(
    'restoring a bundled override brings the protected catalog item back',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);
      final original = sampleContent.firstWhere(
        (item) => item.id == 'en-starter-word-1',
      );
      await controller.upsertCustomItem(
        original.copyWith(
          translations: const ['임시 편집 뜻'],
          acceptedAnswers: const ['임시 편집 뜻'],
        ),
      );

      expect(controller.isBundledOverride(original.id), isTrue);
      expect(await controller.restoreBundledItem(original.id), isTrue);
      expect(controller.customItemById(original.id), isNull);
      expect(controller.isBundledOverride(original.id), isFalse);
      expect(controller.state.customItemTombstones, contains(original.id));
      expect(
        controller.allContentItems.singleWhere(
          (item) => item.id == original.id,
        ),
        original,
      );
      expect(await controller.restoreBundledItem(original.id), isFalse);
      controller.dispose();

      final restored = AppController(store);
      await Future<void>.delayed(Duration.zero);
      expect(restored.customItemById(original.id), isNull);
      expect(
        restored.allContentItems.singleWhere((item) => item.id == original.id),
        original,
      );
      restored.dispose();
    },
  );

  test(
    'bulk content edit validates first and writes one store batch',
    () async {
      final store = _CountingContentStore();
      const first = LearningItem(
        id: 'bulk-first',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'first',
        translations: ['첫째'],
        acceptedAnswers: ['첫째'],
        partOfSpeech: PartOfSpeech.noun,
      );
      const second = LearningItem(
        id: 'bulk-second',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'second',
        translations: ['둘째'],
        acceptedAnswers: ['둘째'],
        partOfSpeech: PartOfSpeech.noun,
      );
      await store.saveCustomItems(const [first, second]);
      store.resetWrites();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);

      final saved = await controller.upsertCustomItems([
        first.copyWith(translations: const ['첫 번째']),
        second.copyWith(translations: const ['두 번째']),
      ]);

      expect(saved, 2);
      expect(store.contentWriteCount, 1);
      expect(store.lastBatchSize, 2);
      expect(
        controller.state.customItems
            .map((item) => item.primaryTranslation)
            .toSet(),
        {'첫 번째', '두 번째'},
      );
      expect(
        controller.state.customItems
            .map((item) => item.source.contentVersion)
            .toSet(),
        {2},
      );

      await expectLater(
        controller.upsertCustomItems([
          first.copyWith(text: ''),
          second.copyWith(translations: const ['저장되면 안 됨']),
        ]),
        throwsA(isA<Exception>()),
      );
      expect(store.contentWriteCount, 1);
      controller.dispose();
    },
  );

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

class _DelayedFirstProfileStore extends MemoryStudyStore {
  final firstProfileWriteStarted = Completer<void>();
  final releaseFirstProfileWrite = Completer<void>();
  int profileWriteCount = 0;

  @override
  Future<void> saveProfile(StoredProfile profile) async {
    profileWriteCount += 1;
    if (profileWriteCount == 1) {
      firstProfileWriteStarted.complete();
      await releaseFirstProfileWrite.future;
    }
    await super.saveProfile(profile);
  }
}

class _CountingContentStore extends MemoryStudyStore {
  int contentWriteCount = 0;
  int lastBatchSize = 0;

  void resetWrites() {
    contentWriteCount = 0;
    lastBatchSize = 0;
  }

  @override
  Future<void> commitCustomItemImport({
    required Iterable<LearningItem> items,
    required Map<String, DateTime> tombstones,
    ImportCommitRecord? record,
  }) async {
    final batch = items.toList(growable: false);
    contentWriteCount += 1;
    lastBatchSize = batch.length;
    await super.commitCustomItemImport(
      items: batch,
      tombstones: tombstones,
      record: record,
    );
  }
}
