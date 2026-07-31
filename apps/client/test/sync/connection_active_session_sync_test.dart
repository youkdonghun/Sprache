import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/import_distribution.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_subject.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart';
import 'package:sprache/src/sync/sync_merge_report.dart';

void main() {
  test(
    'Excel-style import, merged groups, study result, and schedule continue on a second device',
    () async {
      final service = _SharedSnapshotService();
      final windowsStore = MemoryStudyStore();
      final androidStore = MemoryStudyStore();
      final windowsApp = AppController(windowsStore);
      final androidApp = AppController(androidStore);
      await Future<void>.delayed(Duration.zero);
      final windowsConnection = ConnectionController(service, windowsApp);
      final androidConnection = ConnectionController(service, androidApp);
      const subjectId = 'general:baseball';
      final startedAt = DateTime.utc(2026, 7, 28, 9);

      await windowsApp.upsertStudySubject(
        StudySubject(
          id: subjectId,
          kind: StudySubjectKind.general,
          name: '야구 기록 공부',
          description: '직접 만든 야구 지표와 예문',
          symbol: '⚾',
          contentLanguage: LanguageTag.korean,
          createdAt: startedAt,
          updatedAt: startedAt,
        ),
      );
      final templateBytes = File(
        'assets/templates/Sprache-easy-import-template.xlsx',
      ).readAsBytesSync();
      final preview = const ContentImportParser().parseExcel(
        templateBytes,
        defaultLanguage: LanguageTag.korean,
      );
      expect(preview.issues, isEmpty);
      expect(preview.duplicates, isEmpty);
      expect(preview.items, hasLength(15));

      final review = windowsApp.reviewImport(preview);
      final imported = await windowsApp.importResolvedItems(
        [
          for (final entry in review.entries)
            entry.resolve(entry.defaultAction),
        ],
        fileName: 'Sprache-easy-import-template.xlsx',
        sha256: 'cross-device-easy-template-import',
        rejectedRows: 0,
      );
      expect(imported.added, greaterThanOrEqualTo(3));
      final importedCustomCount = windowsApp.state.customItems.length;
      expect(importedCustomCount, imported.added);
      final itemIds = windowsApp.state.customItems
          .where((item) => item.effectiveSubjectId == subjectId)
          .map((item) => item.id)
          .toList(growable: false);
      expect(itemIds, hasLength(2));
      await windowsApp.organizeItemsInLearningGroup(
        itemIds,
        'Android에서 복습',
        copy: true,
      );

      final word = windowsApp.state.customItems.singleWhere(
        (item) =>
            item.effectiveSubjectId == subjectId &&
            item.kind == LearningItemKind.word,
      );
      final sentence = windowsApp.state.customItems.singleWhere(
        (item) =>
            item.effectiveSubjectId == subjectId &&
            item.kind == LearningItemKind.sentence,
      );
      expect(
        word.translations,
        containsAll(['출루율과 장타율의 합', '타자의 공격력을 나타내는 지표']),
      );
      expect(
        learningGroupsOf(word),
        containsAll(['타격 지표', '이번 주 암기', 'Android에서 복습']),
      );
      expect(sentence.text, 'OPS가 0.900을 넘었다.');

      final savedPlan = windowsApp.saveSessionPlan(
        StudySessionPlan(
          mode: StudyMode.mixed,
          deck: StudyDeckScope.selected,
          includeWords: true,
          includeSentences: true,
          sentenceRatio: 0.5,
          itemLimit: 5,
          title: '퇴근 후 야구 복습',
          scheduledAt: DateTime.utc(2026, 7, 28, 19),
          selectedItemIds: itemIds.toSet(),
        ),
      );
      final selected = windowsApp.previewSessionPlan(
        savedPlan,
        DateTime(2026, 7, 28),
      );
      expect(selected.items.map((item) => item.id).toSet(), itemIds.toSet());

      windowsApp.recordAnswer(
        item: word,
        correct: true,
        studiedAt: startedAt,
        exerciseType: 'recognition',
      );
      windowsApp.recordAnswer(
        item: sentence,
        correct: false,
        studiedAt: startedAt.add(const Duration(minutes: 1)),
        exerciseType: 'cloze',
      );
      await windowsApp.finishSession(
        StudySessionSummary(
          sessionId: 'baseball-cross-device-session',
          courseId: 'subject:$subjectId',
          startedAt: startedAt,
          endedAt: startedAt.add(const Duration(minutes: 5)),
          correctCount: 1,
          wrongCount: 1,
          earnedXp: 15,
          itemIds: itemIds,
          wrongItemIds: {sentence.id},
        ),
      );

      await windowsConnection.connect();
      expect(windowsConnection.state.phase, ConnectionPhase.connected);
      await androidConnection.connect();
      expect(androidConnection.state.phase, ConnectionPhase.connected);

      expect(androidApp.state.activeSubjectId, subjectId);
      expect(
        androidApp.state.preferences.customSubjects.single.name,
        '야구 기록 공부',
      );
      expect(androidApp.state.customItems, hasLength(importedCustomCount));
      final restoredWord = androidApp.state.customItems.singleWhere(
        (item) =>
            item.effectiveSubjectId == subjectId &&
            item.kind == LearningItemKind.word,
      );
      expect(restoredWord.translations, word.translations);
      expect(learningGroupsOf(restoredWord), contains('Android에서 복습'));
      expect(androidApp.state.progress[word.id]?.correctCount, 1);
      expect(androidApp.state.progress[sentence.id]?.wrongCount, 1);
      expect(androidApp.state.totalXp, 15);
      expect(
        androidApp.state.recentSessions.single.sessionId,
        'baseball-cross-device-session',
      );
      expect(androidApp.state.recentSessions.single.wrongItemIds, {
        sentence.id,
      });
      expect(
        androidApp.state.preferences.savedSessionPlans.single.title,
        '퇴근 후 야구 복습',
      );
      expect(
        androidApp.state.preferences.savedSessionPlans.single.subjectId,
        subjectId,
      );
      final androidPlan = androidApp.previewSessionPlan(
        androidApp.state.preferences.savedSessionPlans.single,
        DateTime(2026, 7, 28),
      );
      expect(androidPlan.items.map((item) => item.id).toSet(), itemIds.toSet());
      expect(
        androidConnection.state.lastMergeReport?.changes.any(
          (change) =>
              change.section == SyncChangeSection.recentSessions &&
              change.recordId == 'baseball-cross-device-session',
        ),
        isTrue,
      );

      windowsConnection.dispose();
      androidConnection.dispose();
      windowsApp.dispose();
      androidApp.dispose();
    },
  );

  test('two devices exchange active session and its tombstone', () async {
    final service = _SharedSnapshotService();
    final firstApp = AppController(MemoryStudyStore());
    final secondApp = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    final firstConnection = ConnectionController(service, firstApp);
    final secondConnection = ConnectionController(service, secondApp);
    final startedAt = DateTime.utc(2026, 7, 27, 10);
    final itemIds = firstApp.selectedItems
        .take(5)
        .map((item) => item.id)
        .toList();

    await firstConnection.connect();
    final root = firstApp.beginActiveStudySession(
      sessionId: 'cross-device-session',
      mode: StudyMode.meaning,
      unitIndex: null,
      itemIds: itemIds,
      startedAt: startedAt,
    );
    firstApp.updateActiveStudySession(
      itemIds: itemIds,
      currentIndex: 2,
      correctCount: 2,
      wrongCount: 0,
      earnedXp: 20,
      updatedAt: startedAt.add(const Duration(minutes: 2)),
    );
    firstApp.pauseActiveStudySession(startedAt.add(const Duration(minutes: 3)));
    firstApp.resumeActiveStudySession(
      startedAt.add(const Duration(minutes: 4)),
    );
    firstApp.deriveActiveStudySession(
      source: firstApp.state.activeStudySession ?? root,
      sessionId: 'cross-device-branch',
      origin: StudySessionOrigin.remaining,
      itemIds: itemIds.skip(2).toList(),
      startedAt: startedAt.add(const Duration(minutes: 5)),
    );
    await firstConnection.syncNow();

    await secondConnection.connect();

    expect(
      secondApp.state.activeStudySession?.sessionId,
      'cross-device-branch',
    );
    expect(
      secondApp.state.activeStudySession?.origin,
      StudySessionOrigin.remaining,
    );
    expect(secondApp.state.activeStudySession?.rootSessionId, root.sessionId);
    expect(secondApp.state.activeStudySession?.parentSessionId, root.sessionId);
    expect(secondApp.state.activeStudySession?.pauseCount, 1);
    expect(secondApp.state.activeStudySession?.resumeCount, 1);
    expect(secondApp.state.activeStudySession?.journey, hasLength(4));

    final clearedAt = startedAt.add(const Duration(minutes: 8));
    secondApp.clearActiveStudySession(clearedAt: clearedAt);
    await secondConnection.syncNow();
    await firstConnection.syncNow();

    expect(firstApp.state.activeStudySession, isNull);
    expect(firstApp.state.activeSessionChangedAt, clearedAt);
    expect(((service.snapshot!['activeStudy']! as Map)['session']), isNull);

    firstConnection.dispose();
    secondConnection.dispose();
    firstApp.dispose();
    secondApp.dispose();
  });

  test(
    'a custom item deletion cannot be resurrected by the other device',
    () async {
      final service = _SharedSnapshotService();
      final firstStore = MemoryStudyStore();
      final secondStore = MemoryStudyStore();
      final firstApp = AppController(firstStore);
      final secondApp = AppController(secondStore);
      await Future<void>.delayed(Duration.zero);
      final firstConnection = ConnectionController(service, firstApp);
      final secondConnection = ConnectionController(service, secondApp);
      const item = LearningItem(
        id: 'shared-custom-water',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'water',
        translations: ['물'],
        acceptedAnswers: ['물'],
      );

      await firstConnection.connect();
      await firstApp.upsertCustomItem(item);
      await firstConnection.syncNow();
      await secondConnection.connect();

      expect(secondApp.state.customItems.single.id, item.id);

      await secondApp.deleteCustomItem(item.id);
      await secondConnection.syncNow();
      await firstConnection.syncNow();

      expect(firstApp.state.customItems, isEmpty);
      expect(firstApp.state.customItemTombstones, contains(item.id));
      expect(firstStore.savedItems, isEmpty);
      expect(
        (service.snapshot!['customItemTombstones']! as List)
            .cast<Map>()
            .single['id'],
        item.id,
      );

      firstConnection.dispose();
      secondConnection.dispose();
      firstApp.dispose();
      secondApp.dispose();
    },
  );

  test('failed upload remains queued and clears after manual retry', () async {
    final service = _FailOnceSnapshotService();
    final store = MemoryStudyStore();
    final app = AppController(store);
    await Future<void>.delayed(Duration.zero);
    final connection = ConnectionController(service, app);

    await connection.connect();

    expect(connection.state.phase, ConnectionPhase.failed);
    expect(app.state.driveConnected, isFalse);
    expect(app.state.pendingSync?.attempts, 1);
    expect(store.pendingSnapshotSync?.attempts, 1);

    await connection.syncNow();

    expect(connection.state.phase, ConnectionPhase.connected);
    expect(app.state.driveConnected, isTrue);
    expect(app.state.pendingSync, isNull);
    expect(store.pendingSnapshotSync, isNull);
    expect(service.pushAttempts, 2);

    connection.dispose();
    app.dispose();
  });

  test(
    'same distribution key appends meanings to one Drive item and appears on Android',
    () async {
      final service = _SharedSnapshotService();
      final windowsApp = AppController(MemoryStudyStore());
      final androidApp = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      final windowsConnection = ConnectionController(service, windowsApp);
      final androidConnection = ConnectionController(service, androidApp);
      final now = DateTime.utc(2026, 7, 30, 9);
      final subject = StudySubject(
        id: 'general:office-english',
        kind: StudySubjectKind.general,
        name: '업무 영어',
        description: '업무에서 쓰는 영단어',
        symbol: '💼',
        contentLanguage: LanguageTag.english,
        createdAt: now,
        updatedAt: now,
      );
      await windowsConnection.connect();
      await windowsApp.upsertStudySubject(subject);
      await windowsApp.upsertImportDistributionRule(
        key: 'office-core',
        subjectId: subject.id,
        groupName: '이번 주 업무',
      );

      const parser = ContentImportParser();
      Future<void> importCsv(String meaning, String sha) async {
        final preview = parser.parseCsv(
          'language,type,term,meaning,part_of_speech\n'
          'en,word,brief,$meaning,noun',
          defaultLanguage: LanguageTag.english,
          defaultSubjectId: subject.id,
          distributionKey: 'office-core',
          distributionGroup: '이번 주 업무',
          routeSubjectId: subject.id,
        );
        final review = windowsApp.reviewImport(preview);
        final result = await windowsApp.importResolvedItems(
          [
            for (final entry in review.entries)
              entry.resolve(entry.defaultAction),
          ],
          fileName: 'office-core.xlsx',
          sha256: sha,
          rejectedRows: 0,
        );
        expect(result.added + result.replaced, 1);
        await windowsConnection.syncNow();
      }

      await importCsv('요약', 'office-core-first');
      await importCsv('업무 지시', 'office-core-second');
      expect(windowsApp.state.customItems, hasLength(1));
      expect(
        windowsApp.state.customItems.single.translations,
        containsAll(['요약', '업무 지시']),
      );
      // The raw workbook is never uploaded, while its small import receipt is
      // account data so Undo and audit history continue on another device.
      expect(service.snapshot.toString(), contains('office-core.xlsx'));

      await androidConnection.connect();

      final restored = androidApp.state.customItems.single;
      expect(restored.effectiveSubjectId, subject.id);
      expect(importDistributionKeyOf(restored), 'office-core');
      expect(learningGroupsOf(restored), contains('이번 주 업무'));
      expect(restored.translations, containsAll(['요약', '업무 지시']));
      final restoredRule = androidApp.importDistributionRuleFor('office-core');
      expect(restoredRule?.subjectId, subject.id);
      expect(restoredRule?.groupName, '이번 주 업무');

      windowsConnection.dispose();
      androidConnection.dispose();
      windowsApp.dispose();
      androidApp.dispose();
    },
  );

  test('explicit account binding deletion returns to local mode', () async {
    final service = _DeletableSnapshotService();
    final app = AppController(MemoryStudyStore());
    await Future<void>.delayed(Duration.zero);
    app.setDriveConnected(true);
    final connection = ConnectionController(service, app);

    await connection.deleteAccountBinding();

    expect(service.deleted, isTrue);
    expect(app.state.driveConnected, isFalse);
    expect(connection.state.phase, ConnectionPhase.disconnected);

    connection.dispose();
    app.dispose();
  });
}

class _SharedSnapshotService implements GoogleConnectionService {
  Map<String, Object?>? snapshot;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    return const GoogleConnectionResult(
      folderId: 'shared-folder',
      folderName: 'Sprache Shared',
      mock: true,
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async => snapshot;

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {
    this.snapshot = snapshot;
  }
}

class _FailOnceSnapshotService implements GoogleConnectionService {
  int pushAttempts = 0;
  Map<String, Object?>? snapshot;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    return const GoogleConnectionResult(
      folderId: 'retry-folder',
      folderName: 'Sprache Retry',
      mock: true,
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async => snapshot;

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {
    pushAttempts += 1;
    if (pushAttempts == 1) {
      throw StateError('temporary network failure');
    }
    this.snapshot = snapshot;
  }
}

class _DeletableSnapshotService
    implements GoogleConnectionService, AccountBindingDeletionService {
  bool deleted = false;

  @override
  Future<void> deleteAccountBinding() async {
    deleted = true;
  }

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async => null;

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {}
}
