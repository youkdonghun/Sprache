import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/import_distribution.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/learning_item_codec.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_subject.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/sync/snapshot_validator.dart';

void main() {
  test('newer local advanced settings beat a stale remote snapshot', () async {
    final localUpdatedAt = DateTime.utc(2026, 7, 31, 10);
    final remoteUpdatedAt = DateTime.utc(2026, 7, 31, 9);
    final local = StudyPreferences(
      sessionItemLimit: 37,
      ttsRate: 0.7,
      settingsUpdatedAt: localUpdatedAt,
      experience: AppExperiencePreferences(
        colorMode: AppColorMode.dark,
        accentPalette: AppAccentPalette.ocean,
        updatedAt: localUpdatedAt,
      ),
      interaction: StudyInteractionPreferences(
        autoPlayQuestionAudio: true,
        choiceLayout: StudyChoiceLayout.grid,
        updatedAt: localUpdatedAt,
      ),
    );
    final remote = StudyPreferences(
      sessionItemLimit: 99,
      ttsRate: 0.2,
      settingsUpdatedAt: remoteUpdatedAt,
      experience: AppExperiencePreferences(
        colorMode: AppColorMode.light,
        accentPalette: AppAccentPalette.coral,
        updatedAt: remoteUpdatedAt,
      ),
      interaction: StudyInteractionPreferences(
        autoPlayQuestionAudio: false,
        choiceLayout: StudyChoiceLayout.list,
        updatedAt: remoteUpdatedAt,
      ),
    );
    final controller = AppController(MemoryStudyStore(preferences: local));
    await Future<void>.delayed(Duration.zero);

    await controller.mergeRemoteSnapshot({
      'schemaVersion': 1,
      'settings': remote.toJson(),
    });

    final merged = controller.state.preferences;
    expect(merged.sessionItemLimit, 37);
    expect(merged.ttsRate, 0.7);
    expect(merged.experience.colorMode, AppColorMode.dark);
    expect(merged.experience.accentPalette, AppAccentPalette.ocean);
    expect(merged.interaction.autoPlayQuestionAudio, isTrue);
    expect(merged.interaction.choiceLayout, StudyChoiceLayout.grid);
    controller.dispose();
  });

  test('newer remote advanced settings replace stale local values', () async {
    final localUpdatedAt = DateTime.utc(2026, 7, 31, 9);
    final remoteUpdatedAt = DateTime.utc(2026, 7, 31, 10);
    final local = StudyPreferences(
      sessionItemLimit: 12,
      ttsRate: 0.4,
      settingsUpdatedAt: localUpdatedAt,
      experience: AppExperiencePreferences(
        accentPalette: AppAccentPalette.forest,
        updatedAt: localUpdatedAt,
      ),
      interaction: StudyInteractionPreferences(
        autoAdvanceCorrect: false,
        updatedAt: localUpdatedAt,
      ),
    );
    final remote = StudyPreferences(
      sessionItemLimit: 64,
      ttsRate: 0.6,
      settingsUpdatedAt: remoteUpdatedAt,
      experience: AppExperiencePreferences(
        accentPalette: AppAccentPalette.violet,
        updatedAt: remoteUpdatedAt,
      ),
      interaction: StudyInteractionPreferences(
        autoAdvanceCorrect: true,
        autoAdvanceDelayMs: 1500,
        updatedAt: remoteUpdatedAt,
      ),
    );
    final controller = AppController(MemoryStudyStore(preferences: local));
    await Future<void>.delayed(Duration.zero);

    await controller.mergeRemoteSnapshot({
      'schemaVersion': 1,
      'settings': remote.toJson(),
    });

    final merged = controller.state.preferences;
    expect(merged.sessionItemLimit, 64);
    expect(merged.ttsRate, 0.6);
    expect(merged.experience.accentPalette, AppAccentPalette.violet);
    expect(merged.interaction.autoAdvanceCorrect, isTrue);
    expect(merged.interaction.autoAdvanceDelayMs, 1500);
    controller.dispose();
  });

  test(
    'remote snapshot merges newer progress and account-wide totals',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      controller.toggleFavorite('en-starter-word-1');
      controller.completeMission(0);
      final remoteTime = DateTime.utc(2026, 7, 27, 8);

      final merged = await controller.mergeRemoteSnapshot({
        'schemaVersion': 1,
        'profile': {
          'totalXp': 900,
          'streakDays': 7,
          'dailyXp': 80,
          'dailyXpByCourse': {'ko-en': 50, 'ko-ja': 30},
          'badges': ['Drive 동기화'],
          'lastStudyDate': '2026-07-28T00:00:00.000Z',
        },
        'settings': {
          'favoriteItemIds': ['en-starter-word-2'],
          'completedMissionIds': ['ko-en:1'],
          'dailyGoalsBySubject': {'language:en': 150},
        },
        'progress': [
          {
            'itemId': 'en-starter-word-1',
            'status': LearningStatus.review.name,
            'correctCount': 4,
            'wrongCount': 1,
            'lapseCount': 1,
            'currentIntervalDays': 3,
            'lastStudiedAt': remoteTime.toIso8601String(),
            'lastResult': ReviewRating.good.name,
          },
        ],
        'customItems': <Object?>[],
      });

      expect(controller.state.totalXp, 900);
      expect(controller.state.streakDays, 7);
      expect(controller.state.dailyXpByCourse, {'ko-en': 50, 'ko-ja': 30});
      expect(controller.state.preferences.dailyGoalFor('language:en'), 150);
      expect(controller.state.badges, contains('Drive 동기화'));
      expect(
        controller.state.progress['en-starter-word-1']?.lastStudiedAt,
        remoteTime,
      );
      expect(
        controller.state.preferences.favoriteItemIds,
        containsAll(['en-starter-word-1', 'en-starter-word-2']),
      );
      expect(
        controller.state.preferences.completedMissionIds,
        containsAll(['ko-en:0', 'ko-en:1']),
      );
      expect(merged['schemaVersion'], 2);
    },
  );

  test(
    'newer favorite and exclusion removals beat stale memberships',
    () async {
      const favoriteId = 'en-starter-word-1';
      const excludedId = 'en-starter-word-2';
      final baseChangedAt = DateTime.utc(2020);
      final basePreferences = StudyPreferences(
        favoriteItemIds: const {favoriteId},
        favoriteItemChangedAtById: {favoriteId: baseChangedAt},
        excludedItemIds: const {excludedId},
        excludedItemChangedAtById: {excludedId: baseChangedAt},
      );
      final staleSnapshot = {
        'schemaVersion': 1,
        'settings': basePreferences.toJson(),
      };
      final first = AppController(
        MemoryStudyStore(preferences: basePreferences),
      );
      await Future<void>.delayed(Duration.zero);
      first.toggleFavorite(favoriteId);
      first.toggleItemSelection(excludedId);
      final removalSnapshot = first.exportSyncSnapshot();

      await first.mergeRemoteSnapshot(staleSnapshot);
      expect(
        first.state.preferences.favoriteItemIds,
        isNot(contains(favoriteId)),
      );
      expect(
        first.state.preferences.excludedItemIds,
        isNot(contains(excludedId)),
      );

      final second = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      await second.mergeRemoteSnapshot(staleSnapshot);
      await second.mergeRemoteSnapshot(removalSnapshot);
      expect(
        second.state.preferences.favoriteItemIds,
        isNot(contains(favoriteId)),
      );
      expect(
        second.state.preferences.excludedItemIds,
        isNot(contains(excludedId)),
      );
      first.dispose();
      second.dispose();
    },
  );

  test(
    'a deleted saved schedule is not resurrected by a stale device',
    () async {
      final oldPlan = StudySessionPlan(
        planId: 'offline-plan',
        title: '오래된 일정',
        updatedAt: DateTime.utc(2020),
      );
      final basePreferences = StudyPreferences(
        sessionPlan: oldPlan,
        savedSessionPlans: [oldPlan],
      );
      final staleSnapshot = {
        'schemaVersion': 1,
        'settings': basePreferences.toJson(),
      };
      final first = AppController(
        MemoryStudyStore(preferences: basePreferences),
      );
      await Future<void>.delayed(Duration.zero);
      first.deleteSavedSessionPlan(oldPlan.planId);
      final removalSnapshot = first.exportSyncSnapshot();

      await first.mergeRemoteSnapshot(staleSnapshot);
      expect(first.state.preferences.savedSessionPlans, isEmpty);
      expect(
        first.state.preferences.savedSessionPlanTombstones,
        contains(oldPlan.planId),
      );

      final second = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      await second.mergeRemoteSnapshot(staleSnapshot);
      await second.mergeRemoteSnapshot(removalSnapshot);
      expect(second.state.preferences.savedSessionPlans, isEmpty);
      expect(second.state.preferences.sessionPlan.planId, isEmpty);
      first.dispose();
      second.dispose();
    },
  );

  test('newer unsupported remote schema is rejected', () async {
    final controller = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);

    expect(
      () => controller.mergeRemoteSnapshot({'schemaVersion': 3}),
      throwsA(isA<StateError>()),
    );
  });

  test('newer remote active session can continue on this device', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final localTime = DateTime.utc(2026, 7, 27, 10);
    final remoteTime = localTime.add(const Duration(minutes: 5));
    final itemIds = controller.selectedItems
        .take(5)
        .map((item) => item.id)
        .toList();

    controller.beginActiveStudySession(
      sessionId: 'local-session',
      mode: StudyMode.mixed,
      unitIndex: null,
      itemIds: itemIds,
      startedAt: localTime,
    );
    final remoteSession = ActiveStudySession(
      sessionId: 'remote-session',
      courseId: 'ko-en',
      mode: StudyMode.meaning,
      itemIds: itemIds,
      currentIndex: 2,
      correctCount: 2,
      wrongCount: 0,
      earnedXp: 20,
      startedAt: localTime,
      updatedAt: remoteTime,
    );

    final merged = await controller.mergeRemoteSnapshot({
      'schemaVersion': 1,
      'activeStudy': {
        'changedAt': remoteTime.toIso8601String(),
        'session': remoteSession.toJson(),
      },
    });

    expect(controller.state.activeStudySession?.sessionId, 'remote-session');
    expect(controller.state.activeStudySession?.currentIndex, 2);
    expect(controller.state.activeSessionChangedAt, remoteTime);
    expect(store.savedActiveStudySession?.sessionId, 'remote-session');
    expect(
      ((merged['activeStudy']! as Map)['session']! as Map)['sessionId'],
      'remote-session',
    );
  });

  test('newer remote tombstone clears an older local session', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final localTime = DateTime.utc(2026, 7, 27, 10);
    final clearedAt = localTime.add(const Duration(minutes: 6));

    controller.beginActiveStudySession(
      sessionId: 'local-session',
      mode: StudyMode.mixed,
      unitIndex: null,
      itemIds: controller.selectedItems.take(5).map((item) => item.id).toList(),
      startedAt: localTime,
    );

    final merged = await controller.mergeRemoteSnapshot({
      'schemaVersion': 1,
      'activeStudy': {
        'changedAt': clearedAt.toIso8601String(),
        'session': null,
      },
    });

    expect(controller.state.activeStudySession, isNull);
    expect(controller.state.activeSessionChangedAt, clearedAt);
    expect(store.savedActiveStudySession, isNull);
    expect(store.activeStudySessionChangedAt, clearedAt);
    expect((merged['activeStudy']! as Map)['session'], isNull);
  });

  test(
    'newer local tombstone prevents an old remote session resurrection',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);
      final remoteTime = DateTime.utc(2026, 7, 27, 10);
      final clearedAt = remoteTime.add(const Duration(minutes: 8));
      final itemIds = controller.selectedItems
          .take(5)
          .map((item) => item.id)
          .toList();
      final remoteSession = ActiveStudySession(
        sessionId: 'old-remote-session',
        courseId: 'ko-en',
        mode: StudyMode.meaning,
        itemIds: itemIds,
        currentIndex: 1,
        correctCount: 1,
        wrongCount: 0,
        earnedXp: 10,
        startedAt: remoteTime,
        updatedAt: remoteTime,
      );
      controller.clearActiveStudySession(clearedAt: clearedAt);

      final merged = await controller.mergeRemoteSnapshot({
        'schemaVersion': 1,
        'activeStudy': {
          'changedAt': remoteTime.toIso8601String(),
          'session': remoteSession.toJson(),
        },
      });

      expect(controller.state.activeStudySession, isNull);
      expect(controller.state.activeSessionChangedAt, clearedAt);
      expect((merged['activeStudy']! as Map)['session'], isNull);
    },
  );

  test(
    'corrupt remote snapshot leaves all healthy local data unchanged',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);
      const localItem = LearningItem(
        id: 'local-safe-item',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'safe',
        translations: ['안전한'],
        acceptedAnswers: ['안전한'],
      );
      await controller.upsertCustomItem(localItem);
      final before = controller.state;

      expect(
        () => controller.mergeRemoteSnapshot({
          'schemaVersion': 1,
          'profile': {'totalXp': 999999},
          'customItems': [
            {
              'id': 'remote-broken-item',
              'kind': 'word',
              'language': 'en',
              'text': 'broken',
              'translations': <String>[],
            },
          ],
        }),
        throwsA(isA<RemoteSnapshotValidationException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.totalXp, before.totalXp);
      expect(controller.state.customItems, hasLength(1));
      expect(controller.state.customItems.single.id, localItem.id);
      expect(store.savedItems.single.id, localItem.id);
    },
  );

  test(
    'same-timestamp custom content prefers the higher content version',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      const localItem = LearningItem(
        id: 'version-tie-item',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'consistency',
        translations: ['정합성'],
        acceptedAnswers: ['정합성'],
        partOfSpeech: PartOfSpeech.noun,
        source: ContentSource(
          name: 'Local notebook',
          license: 'private',
          sourceVersion: '1',
          contentVersion: 1,
        ),
      );
      await controller.upsertCustomItem(localItem);

      final remote = Map<String, Object?>.from(controller.exportSyncSnapshot());
      final remoteItem = Map<String, Object?>.from(
        (remote['customItems']! as List<Object?>).single! as Map,
      );
      remoteItem['acceptedAnswers'] = ['정합성', '일관성'];
      remoteItem['source'] = {
        ...Map<String, Object?>.from(remoteItem['source']! as Map),
        'name': 'Remote notebook',
        'sourceVersion': '2',
        'contentVersion': 2,
      };
      remote['customItems'] = [remoteItem];

      await controller.mergeRemoteSnapshot(remote);

      final merged = controller.state.customItems.single;
      expect(merged.source.name, 'Remote notebook');
      expect(merged.source.contentVersion, 2);
      expect(merged.acceptedAnswers, contains('일관성'));
    },
  );

  test(
    'same-ID offline enhancements preserve meanings answers readings and routing tags',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      const codec = LearningItemCodec();
      final localItem = LearningItem(
        id: 'shared-bank',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'bank',
        translations: const ['은행'],
        acceptedAnswers: const ['은행', '금융 기관'],
        readings: const [Reading(scheme: ReadingScheme.hangul, value: '뱅크')],
        partOfSpeech: PartOfSpeech.noun,
        tags: const ['group:금융', 'import-key:office-sheet'],
        updatedAt: DateTime.utc(2026, 7, 29, 8),
      );
      final remoteItem = LearningItem(
        id: 'shared-bank',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'bank',
        translations: const ['강둑'],
        acceptedAnswers: const ['강둑', '제방'],
        readings: const [Reading(scheme: ReadingScheme.hangul, value: '배앵크')],
        partOfSpeech: PartOfSpeech.noun,
        tags: const ['group:지형', 'import-key:travel-sheet'],
        source: const ContentSource(
          name: 'Remote notebook',
          license: 'private',
          sourceVersion: '2',
          contentVersion: 2,
        ),
        updatedAt: DateTime.utc(2026, 7, 29, 9),
      );

      await controller.mergeRemoteSnapshot({
        'schemaVersion': 1,
        'customItems': [codec.toJson(localItem)],
      });
      await controller.mergeRemoteSnapshot({
        'schemaVersion': 1,
        'customItems': [codec.toJson(remoteItem)],
      });

      final merged = controller.state.customItems.single;
      expect(merged.id, 'shared-bank');
      expect(merged.source.name, 'Remote notebook');
      expect(merged.translations, containsAll(<String>['은행', '강둑']));
      expect(
        merged.acceptedAnswers,
        containsAll(<String>['은행', '금융 기관', '강둑', '제방']),
      );
      expect(
        merged.readings.map((reading) => reading.value),
        containsAll(<String>['뱅크', '배앵크']),
      );
      expect(
        merged.tags,
        containsAll(<String>[
          'group:금융',
          'group:지형',
          'import-key:travel-sheet',
        ]),
      );
      expect(merged.tags, isNot(contains('import-key:office-sheet')));
      controller.dispose();
    },
  );

  test(
    'semantic duplicate IDs converge and carry progress without resurrection',
    () async {
      const codec = LearningItemCodec();
      final localItem = LearningItem(
        id: 'local-cafe',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'Ｃａｆｅ',
        translations: const ['카페'],
        acceptedAnswers: const ['카페'],
        readings: const [Reading(scheme: ReadingScheme.hangul, value: '카페이')],
        partOfSpeech: PartOfSpeech.noun,
        tags: const ['group:일상', 'import-key:local-sheet'],
        updatedAt: DateTime.utc(2026, 7, 29, 8),
      );
      final remoteItem = LearningItem(
        id: 'remote-cafe',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: ' cafe ',
        translations: const ['커피숍'],
        acceptedAnswers: const ['커피숍'],
        readings: const [Reading(scheme: ReadingScheme.hangul, value: '캐페이')],
        partOfSpeech: PartOfSpeech.noun,
        tags: const ['group:여행', 'import-key:remote-sheet'],
        updatedAt: DateTime.utc(2026, 7, 29, 9),
      );
      final studiedAt = DateTime.utc(2026, 7, 29, 8, 30);
      final localSnapshot = <String, Object?>{
        'schemaVersion': 1,
        'customItems': [codec.toJson(localItem)],
        'progress': [
          {
            'itemId': localItem.id,
            'status': LearningStatus.review.name,
            'correctCount': 3,
            'wrongCount': 1,
            'lapseCount': 1,
            'currentIntervalDays': 4,
            'lastStudiedAt': studiedAt.toIso8601String(),
            'lastResult': ReviewRating.good.name,
          },
        ],
      };
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      await controller.mergeRemoteSnapshot(localSnapshot);

      final convergedSnapshot = await controller.mergeRemoteSnapshot({
        'schemaVersion': 1,
        'customItems': [codec.toJson(remoteItem)],
      });

      expect(controller.state.customItems, hasLength(1));
      final merged = controller.state.customItems.single;
      expect(merged.id, remoteItem.id);
      expect(merged.translations, containsAll(<String>['카페', '커피숍']));
      expect(
        merged.tags,
        containsAll(<String>[
          'group:일상',
          'group:여행',
          'import-key:remote-sheet',
        ]),
      );
      expect(merged.tags, isNot(contains('import-key:local-sheet')));
      expect(controller.state.customItemTombstones, contains(localItem.id));
      expect(controller.state.progress, isNot(contains(localItem.id)));
      expect(controller.state.progress[remoteItem.id]?.correctCount, 3);
      expect(
        controller.state.progress[remoteItem.id]?.lastStudiedAt,
        studiedAt,
      );

      final second = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      await second.mergeRemoteSnapshot(localSnapshot);
      await second.mergeRemoteSnapshot(convergedSnapshot);
      expect(second.state.customItems, hasLength(1));
      expect(second.state.customItems.single.id, remoteItem.id);
      expect(second.state.progress, isNot(contains(localItem.id)));
      expect(second.state.progress[remoteItem.id]?.correctCount, 3);

      await controller.mergeRemoteSnapshot(localSnapshot);
      expect(controller.state.customItems, hasLength(1));
      expect(controller.state.customItems.single.id, remoteItem.id);
      expect(controller.state.customItemTombstones, contains(localItem.id));
      controller.dispose();
      second.dispose();
    },
  );

  test(
    'semantic convergence keeps identical expressions isolated by subject',
    () async {
      const codec = LearningItemCodec();
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      final baseball = LearningItem(
        id: 'baseball-fan',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.korean,
        subjectId: 'general:baseball',
        text: '팬',
        translations: const ['응원하는 사람'],
        acceptedAnswers: const ['응원하는 사람'],
        updatedAt: DateTime.utc(2026, 7, 29, 8),
      );
      final idol = baseball.copyWith(
        id: 'idol-fan',
        subjectId: 'general:idol',
        updatedAt: DateTime.utc(2026, 7, 29, 9),
      );

      await controller.mergeRemoteSnapshot({
        'schemaVersion': 1,
        'customItems': [codec.toJson(baseball)],
      });
      await controller.mergeRemoteSnapshot({
        'schemaVersion': 1,
        'customItems': [codec.toJson(idol)],
      });

      expect(controller.state.customItems, hasLength(2));
      expect(
        controller.state.customItems
            .map((item) => item.effectiveSubjectId)
            .toSet(),
        {'general:baseball', 'general:idol'},
      );
      expect(controller.state.customItemTombstones, isEmpty);
      controller.dispose();
    },
  );

  test('remote snapshot restores the saved session builder plan', () async {
    final controller = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    final remote = Map<String, Object?>.from(controller.exportSyncSnapshot());
    remote['settings'] = {
      ...Map<String, Object?>.from(remote['settings']! as Map),
      'sessionPlan': const StudySessionPlan(
        mode: StudyMode.production,
        deck: StudyDeckScope.favorites,
        difficulty: StudyDifficulty.weak,
        tags: {'업무'},
        includeSentences: false,
        itemLimit: 20,
      ).toJson(),
    };

    await controller.mergeRemoteSnapshot(remote);

    final restored = controller.state.preferences.sessionPlan;
    expect(restored.mode, StudyMode.production);
    expect(restored.deck, StudyDeckScope.favorites);
    expect(restored.difficulty, StudyDifficulty.weak);
    expect(restored.tags, {'업무'});
    expect(restored.includeSentences, isFalse);
    expect(restored.itemLimit, 20);
  });

  test('the later completed session wins for the same session ID', () async {
    final controller = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    final startedAt = DateTime.utc(2026, 7, 28, 10);
    await controller.finishSession(
      StudySessionSummary(
        sessionId: 'shared-completed-session',
        courseId: 'ko-en',
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 4)),
        correctCount: 1,
        wrongCount: 1,
        earnedXp: 15,
        itemIds: const ['item-a', 'item-b'],
        wrongItemIds: const {'item-b'},
      ),
    );
    final remote = Map<String, Object?>.from(controller.exportSyncSnapshot());
    remote['recentSessions'] = [
      StudySessionSummary(
        sessionId: 'shared-completed-session',
        courseId: 'ko-en',
        startedAt: startedAt,
        endedAt: startedAt.add(const Duration(minutes: 5)),
        correctCount: 2,
        wrongCount: 0,
        earnedXp: 20,
        itemIds: const ['item-a', 'item-b'],
      ).toJson(),
    ];

    await controller.mergeRemoteSnapshot(remote);

    final restored = controller.state.recentSessions.single;
    expect(restored.endedAt, startedAt.add(const Duration(minutes: 5)));
    expect(restored.correctCount, 2);
    expect(restored.wrongItemIds, isEmpty);
  });

  test(
    'a stale remote session plan cannot overwrite a newer local edit',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      controller.updateSessionPlan(
        const StudySessionPlan(
          mode: StudyMode.listening,
          deck: StudyDeckScope.personal,
          itemLimit: 15,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final localUpdatedAt = controller.state.preferences.sessionPlan.updatedAt;
      final remote = Map<String, Object?>.from(controller.exportSyncSnapshot());
      remote['settings'] = {
        ...Map<String, Object?>.from(remote['settings']! as Map),
        'sessionPlan': StudySessionPlan(
          mode: StudyMode.meaning,
          deck: StudyDeckScope.course,
          itemLimit: 5,
          updatedAt: DateTime.utc(2025),
        ).toJson(),
      };

      await controller.mergeRemoteSnapshot(remote);

      final merged = controller.state.preferences.sessionPlan;
      expect(merged.mode, StudyMode.listening);
      expect(merged.deck, StudyDeckScope.personal);
      expect(merged.itemLimit, 15);
      expect(merged.updatedAt, localUpdatedAt);
    },
  );

  test(
    'import conflict policy can preserve or intentionally replace an item',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      const first = LearningItem(
        id: 'shared-id',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'first',
        translations: ['첫 번째'],
        acceptedAnswers: ['첫 번째'],
      );
      const replacement = LearningItem(
        id: 'shared-id',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'replacement',
        translations: ['교체'],
        acceptedAnswers: ['교체'],
      );
      await controller.importItems([first]);

      final kept = await controller.importItems([replacement]);
      final replaced = await controller.importItems([
        replacement,
      ], conflictPolicy: ImportConflictPolicy.replaceExisting);

      expect(kept.skipped, 1);
      expect(replaced.replaced, 1);
      expect(controller.state.customItems.single.text, 'replacement');
    },
  );

  test(
    'Drive merge preserves subjects from both devices and newer metadata',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      await controller.upsertStudySubject(
        StudySubject(
          id: 'general:baseball',
          kind: StudySubjectKind.general,
          name: '내 야구 노트',
          description: '로컬 최신 설명',
          symbol: '⚾',
          contentLanguage: LanguageTag.korean,
          updatedAt: DateTime.utc(2026, 7, 28),
        ),
      );
      final remote = Map<String, Object?>.from(controller.exportSyncSnapshot());
      remote['settings'] = {
        ...Map<String, Object?>.from(remote['settings']! as Map),
        'activeSubjectId': 'general:idol',
        'activeSubjectChangedAt': '2027-01-01T00:00:00.000Z',
        'customSubjects': [
          const StudySubject(
            id: 'general:baseball',
            kind: StudySubjectKind.general,
            name: '오래된 야구',
            description: '원격 구버전',
            symbol: 'B',
            contentLanguage: LanguageTag.korean,
          ).copyWith(updatedAt: DateTime.utc(2025)).toJson(),
          const StudySubject(
            id: 'general:idol',
            kind: StudySubjectKind.general,
            name: '아이돌 상식',
            description: '다른 기기에서 추가',
            symbol: '🎤',
            contentLanguage: LanguageTag.korean,
          ).copyWith(updatedAt: DateTime.utc(2026, 7, 27)).toJson(),
        ],
      };

      await controller.mergeRemoteSnapshot(remote);

      final subjects = {
        for (final subject in controller.state.preferences.customSubjects)
          subject.id: subject,
      };
      expect(subjects.keys, {'general:baseball', 'general:idol'});
      expect(subjects['general:baseball']!.name, '내 야구 노트');
      expect(subjects['general:idol']!.name, '아이돌 상식');
      expect(controller.state.activeSubjectId, 'general:idol');
    },
  );

  test(
    'Drive merge applies newer built-in visibility and distribution routes',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      await controller.upsertImportDistributionRule(
        key: 'travel-core',
        subjectId: 'language:en',
        groupName: '로컬 그룹',
      );
      final remote = Map<String, Object?>.from(controller.exportSyncSnapshot());
      remote['settings'] = {
        ...Map<String, Object?>.from(remote['settings']! as Map),
        'customSubjects': [
          StudySubject.language(LanguageTag.english)
              .copyWith(
                name: '업무 영어',
                description: '다른 기기의 표시 설정',
                symbol: '💼',
                updatedAt: DateTime.utc(2027),
              )
              .toJson(),
        ],
        'hiddenSubjectIds': ['language:fr'],
        'subjectVisibilityChangedAtById': {
          'language:fr': '2027-01-01T00:00:00.000Z',
        },
        'importDistributionRules': [
          ImportDistributionRule(
            key: 'travel-core',
            subjectId: 'language:ja',
            groupName: '원격 여행',
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2027),
          ).toJson(),
        ],
      };

      await controller.mergeRemoteSnapshot(remote);

      expect(
        controller.allSubjects
            .singleWhere((subject) => subject.id == 'language:en')
            .name,
        '업무 영어',
      );
      expect(
        controller.availableSubjects.map((subject) => subject.id),
        isNot(contains('language:fr')),
      );
      expect(
        controller.importDistributionRuleFor('travel-core'),
        isA<ImportDistributionRule>()
            .having((rule) => rule.subjectId, 'subjectId', 'language:ja')
            .having((rule) => rule.groupName, 'groupName', '원격 여행'),
      );
    },
  );

  test(
    'Drive merge keeps newer group metadata and applies remote tombstones',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      final subjectId = controller.state.activeSubjectId;
      await controller.createLearningGroup(
        name: 'Shared group',
        description: 'Local metadata',
        colorKey: 'blue',
      );
      await controller.createLearningGroup(name: 'Deleted remotely');

      final remote = Map<String, Object?>.from(controller.exportSyncSnapshot());
      remote['settings'] = {
        ...Map<String, Object?>.from(remote['settings']! as Map),
        'learningGroups': [
          LearningGroupDefinition(
            subjectId: subjectId,
            name: 'Shared group',
            description: 'Remote metadata',
            colorKey: 'purple',
            pinned: true,
            sortOrder: 1,
            createdAt: DateTime.utc(2026, 7, 29),
            updatedAt: DateTime.utc(2027),
          ).toJson(),
          LearningGroupDefinition(
            subjectId: subjectId,
            name: 'Remote only',
            description: 'Added on another device',
            colorKey: 'orange',
            sortOrder: 2,
            createdAt: DateTime.utc(2027),
            updatedAt: DateTime.utc(2027),
          ).toJson(),
        ],
        'learningGroupTombstones': {
          learningGroupDefinitionId(subjectId, 'Deleted remotely'):
              DateTime.utc(2027).toIso8601String(),
        },
      };

      await controller.mergeRemoteSnapshot(remote);

      final definitions = {
        for (final group in controller.state.preferences.learningGroups)
          group.name: group,
      };
      expect(
        definitions.keys,
        containsAll(<String>['Shared group', 'Remote only']),
      );
      expect(definitions.keys, isNot(contains('Deleted remotely')));
      expect(definitions['Shared group']!.description, 'Remote metadata');
      expect(definitions['Shared group']!.colorKey, 'purple');
      expect(definitions['Shared group']!.pinned, isTrue);
      expect(
        controller.state.preferences.learningGroupTombstones,
        contains(learningGroupDefinitionId(subjectId, 'Deleted remotely')),
      );
    },
  );
}
