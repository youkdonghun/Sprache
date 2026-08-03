import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/local_storage.dart';
import 'package:sprache/src/services/data_health_report.dart';
import 'package:sprache/src/services/recovery_backup_catalog.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart';
import 'package:sprache/src/state/local_storage_state.dart';
import 'package:sprache/src/sync/pending_sync.dart';
import 'package:sprache/src/sync/sync_policy.dart';

void main() {
  test('summarizes local, Drive, queue, and last verified backup', () {
    final now = DateTime.utc(2026, 8, 2, 10);
    final report = const DataHealthReportBuilder().build(
      app: AppState.initial().copyWith(isHydrated: true),
      connection: ConnectionState(
        phase: ConnectionPhase.connected,
        folderName: 'Sprache',
        runtimeReady: true,
        lastSyncedAt: now,
      ),
      localStorage: LocalStorageState(
        initialized: true,
        driveConnected: true,
        settings: LocalStorageSettings(
          locationId: 'local-folder',
          displayName: 'Documents',
          lastSavedAt: now,
          lastArchiveSha256: 'a' * 64,
          lastArchiveBytes: 2048,
        ),
      ),
      recovery: LocalRecoveryInventory(
        items: [
          LocalRecoveryBackup(
            id: 'checkpoint',
            path: 'checkpoint',
            byteLength: 4096,
            modifiedAt: now.add(const Duration(minutes: 1)),
            fileCount: 2,
            eligibleForCleanup: false,
            reason: 'bulkImport',
            sha256Hex: 'b' * 64,
            itemCount: 12,
            verified: true,
          ),
          LocalRecoveryBackup(
            id: 'newer-but-invalid',
            path: 'newer-but-invalid',
            byteLength: 8192,
            modifiedAt: now.add(const Duration(minutes: 2)),
            fileCount: 2,
            eligibleForCleanup: false,
            reason: 'restore',
            sha256Hex: 'c' * 64,
            itemCount: 99,
            verified: false,
          ),
        ],
        minimumAge: const Duration(days: 30),
        inspectedAt: now,
      ),
      generatedAt: now,
    );

    expect(report.attentionCount, 0);
    expect(
      report.sections.singleWhere((value) => value.id == 'sqlite').level,
      DataHealthLevel.healthy,
    );
    expect(report.lastBackup?.verified, isTrue);
    expect(report.lastBackup?.itemCount, 12);
    expect(report.lastBackup?.clipboardText, contains('SHA-256'));
  });

  test(
    'groups queued snapshot sections and respects complete offline lock',
    () {
      final now = DateTime.utc(2026, 8, 2, 10);
      final pending = PendingSyncOperation(
        operationId: 'operation-1',
        entityType: PendingSyncEntityType.snapshot,
        entityId: 'snapshot',
        payload: const {
          'profile': {'totalXp': 10},
          'settings': {'dailyGoal': 20},
          'progress': [
            {'itemId': 'a'},
            {'itemId': 'b'},
          ],
          'customItems': <Object?>[],
          'customItemTombstones': <Object?>[],
          'recentSessions': <Object?>[],
          'activeStudy': null,
        },
        attempts: 2,
        nextAttemptAt: now.add(const Duration(minutes: 1)),
        createdAt: now,
      );
      final report = const DataHealthReportBuilder().build(
        app: AppState.initial().copyWith(
          isHydrated: true,
          pendingSync: pending,
        ),
        connection: const ConnectionState(
          phase: ConnectionPhase.connected,
          runtimeReady: true,
          pendingChanges: true,
          policy: SyncPolicy(offlineLock: true),
        ),
        localStorage: const LocalStorageState(
          initialized: true,
          driveConnected: true,
          settings: LocalStorageSettings(),
        ),
        recovery: LocalRecoveryInventory(
          items: const [],
          minimumAge: const Duration(days: 30),
          inspectedAt: now,
        ),
        generatedAt: now,
      );

      expect(report.pendingSections, hasLength(7));
      expect(
        report.pendingSections
            .singleWhere((value) => value.id == 'progress')
            .itemCount,
        2,
      );
      expect(
        report.sections.singleWhere((value) => value.id == 'drive').summary,
        'Drive 동기화 일시 중지',
      );
      expect(
        report.sections.singleWhere((value) => value.id == 'pending').retryable,
        isFalse,
      );
    },
  );
}
