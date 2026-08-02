import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/study_completion_receipt.dart';

void main() {
  test('receipt separates local save, pending sync, and offline lock', () {
    final local = StudyCompletionReceipt.fromState(
      savedAt: DateTime.utc(2026, 8, 2, 5, 6, 7),
      earnedXp: 15,
      streakDays: 4,
      driveConnected: false,
      pendingSyncCount: 0,
      offlineLocked: false,
    );
    final pending = StudyCompletionReceipt.fromState(
      savedAt: DateTime.utc(2026, 8, 2, 5, 6, 7),
      earnedXp: 15,
      streakDays: 4,
      driveConnected: true,
      pendingSyncCount: 2,
      offlineLocked: false,
    );
    final locked = StudyCompletionReceipt.fromState(
      savedAt: DateTime.utc(2026, 8, 2, 5, 6, 7),
      earnedXp: 15,
      streakDays: 4,
      driveConnected: true,
      pendingSyncCount: 3,
      offlineLocked: true,
    );

    expect(local.syncStatus, StudyCompletionSyncStatus.localOnly);
    expect(pending.syncStatus, StudyCompletionSyncStatus.pending);
    expect(pending.syncLabel, contains('2건'));
    expect(locked.syncStatus, StudyCompletionSyncStatus.offlineLocked);
    expect(locked.syncLabel, contains('3건'));
    expect(local.semanticsLabel, contains('획득 15 XP'));
    expect(local.semanticsLabel, contains('연속 학습 4일'));
  });

  test('receipt clamps counters and exposes saving state', () {
    final receipt = StudyCompletionReceipt.fromState(
      savedAt: null,
      earnedXp: -4,
      streakDays: -2,
      driveConnected: true,
      pendingSyncCount: -1,
      offlineLocked: false,
    );

    expect(receipt.saved, isFalse);
    expect(receipt.savedTimeLabel, '저장 중');
    expect(receipt.earnedXp, 0);
    expect(receipt.streakDays, 0);
    expect(receipt.syncStatus, StudyCompletionSyncStatus.synced);
  });
}
