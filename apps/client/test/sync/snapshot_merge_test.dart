import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/sync/snapshot_validator.dart';

void main() {
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
          'badges': ['Drive 동기화'],
        },
        'settings': {
          'favoriteItemIds': ['en-starter-word-2'],
          'completedMissionIds': ['ko-en:1'],
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
      expect(merged['schemaVersion'], 1);
    },
  );

  test('newer unsupported remote schema is rejected', () async {
    final controller = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);

    expect(
      () => controller.mergeRemoteSnapshot({'schemaVersion': 2}),
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
}
