import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart';

void main() {
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
    expect(app.state.driveConnected, isTrue);
    expect(app.state.pendingSync?.attempts, 1);
    expect(store.pendingSnapshotSync?.attempts, 1);

    await connection.syncNow();

    expect(connection.state.phase, ConnectionPhase.connected);
    expect(app.state.pendingSync, isNull);
    expect(store.pendingSnapshotSync, isNull);
    expect(service.pushAttempts, 2);

    connection.dispose();
    app.dispose();
  });
}

class _SharedSnapshotService implements GoogleConnectionService {
  Map<String, Object?>? snapshot;

  @override
  Future<GoogleConnectionResult> connect() async {
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
  Future<GoogleConnectionResult> connect() async {
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
