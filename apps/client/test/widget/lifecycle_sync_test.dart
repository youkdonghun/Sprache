import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart';

void main() {
  testWidgets('backgrounding a connected app flushes a sync snapshot', (
    tester,
  ) async {
    final service = _CountingGoogleService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studyStoreProvider.overrideWithValue(MemoryStudyStore()),
          googleConnectionServiceProvider.overrideWithValue(service),
        ],
        child: const SpracheApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpracheApp)),
    );

    await container.read(connectionControllerProvider.notifier).connect();
    expect(service.pullCount, 1);
    expect(service.pushCount, 1);
    expect(
      container.read(connectionControllerProvider).userInitiatedOperation,
      isFalse,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await tester.pump();

    expect(service.pullCount, 2);
    expect(service.pushCount, 2);
    expect(
      container.read(connectionControllerProvider).userInitiatedOperation,
      isFalse,
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  });

  testWidgets('a saved Drive link restores and syncs after cold start', (
    tester,
  ) async {
    final store = MemoryStudyStore();
    final empty = StoredProfile.empty(replicaId: 'replica-android');
    await store.saveProfile(
      StoredProfile(
        selectedLanguage: empty.selectedLanguage,
        totalXp: empty.totalXp,
        streakDays: empty.streakDays,
        dailyXp: empty.dailyXp,
        badges: empty.badges,
        driveConnected: true,
        progress: empty.progress,
        dailyXpByCourse: empty.dailyXpByCourse,
        dailyXpByCourseAndReplica: empty.dailyXpByCourseAndReplica,
        replicaId: empty.replicaId,
        xpByReplica: empty.xpByReplica,
        lastStudyDate: empty.lastStudyDate,
      ),
    );
    final service = _CountingGoogleService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studyStoreProvider.overrideWithValue(store),
          googleConnectionServiceProvider.overrideWithValue(service),
        ],
        child: const SpracheApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpracheApp)),
    );

    expect(service.restoreCount, 1);
    expect(service.connectCount, 0);
    expect(service.pullCount, 1);
    expect(service.pushCount, 1);
    expect(
      container.read(connectionControllerProvider).phase,
      ConnectionPhase.connected,
    );
    expect(container.read(connectionControllerProvider).runtimeReady, isTrue);
    expect(
      container.read(connectionControllerProvider).userInitiatedOperation,
      isFalse,
    );
  });
}

class _CountingGoogleService
    implements GoogleConnectionService, RestorableGoogleConnectionService {
  Map<String, Object?>? snapshot;
  int connectCount = 0;
  int restoreCount = 0;
  int pullCount = 0;
  int pushCount = 0;

  @override
  Future<GoogleConnectionResult> connect({
    GoogleConnectionStageCallback? onStage,
  }) async {
    connectCount++;
    return const GoogleConnectionResult(
      folderId: 'lifecycle-folder',
      folderName: 'Lifecycle Drive',
      mock: true,
    );
  }

  @override
  Future<GoogleConnectionResult?> restoreConnection({
    GoogleConnectionStageCallback? onStage,
  }) async {
    restoreCount++;
    onStage?.call(GoogleConnectionStage.checkingConnection);
    onStage?.call(GoogleConnectionStage.preparingDrive);
    return const GoogleConnectionResult(
      folderId: 'lifecycle-folder',
      folderName: 'Lifecycle Drive',
      mock: true,
    );
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<Map<String, Object?>?> pullSnapshot() async {
    pullCount++;
    return snapshot;
  }

  @override
  Future<void> pushSnapshot(Map<String, Object?> snapshot) async {
    pushCount++;
    this.snapshot = snapshot;
  }
}
