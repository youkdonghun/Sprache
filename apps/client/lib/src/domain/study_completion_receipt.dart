enum StudyCompletionSyncStatus { localOnly, pending, synced, offlineLocked }

class StudyCompletionReceipt {
  const StudyCompletionReceipt({
    required this.savedAt,
    required this.earnedXp,
    required this.streakDays,
    required this.pendingSyncCount,
    required this.syncStatus,
  });

  factory StudyCompletionReceipt.fromState({
    required DateTime? savedAt,
    required int earnedXp,
    required int streakDays,
    required bool driveConnected,
    required int pendingSyncCount,
    required bool offlineLocked,
  }) {
    final safePendingCount = pendingSyncCount.clamp(0, 1000);
    final syncStatus = offlineLocked
        ? StudyCompletionSyncStatus.offlineLocked
        : safePendingCount > 0
        ? StudyCompletionSyncStatus.pending
        : !driveConnected
        ? StudyCompletionSyncStatus.localOnly
        : StudyCompletionSyncStatus.synced;
    return StudyCompletionReceipt(
      savedAt: savedAt?.toUtc(),
      earnedXp: earnedXp.clamp(0, 1000000),
      streakDays: streakDays.clamp(0, 1000000),
      pendingSyncCount: safePendingCount,
      syncStatus: syncStatus,
    );
  }

  final DateTime? savedAt;
  final int earnedXp;
  final int streakDays;
  final int pendingSyncCount;
  final StudyCompletionSyncStatus syncStatus;

  bool get saved => savedAt != null;

  String get savedTimeLabel {
    final local = savedAt?.toLocal();
    if (local == null) return '저장 중';
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String get syncLabel => switch (syncStatus) {
    StudyCompletionSyncStatus.localOnly => '이 기기에 저장',
    StudyCompletionSyncStatus.pending => 'Drive 동기화 대기 $pendingSyncCount건',
    StudyCompletionSyncStatus.synced => 'Drive 반영 완료',
    StudyCompletionSyncStatus.offlineLocked =>
      pendingSyncCount == 0
          ? 'Drive 동기화 일시 중지'
          : 'Drive 동기화 일시 중지 · 대기 $pendingSyncCount건',
  };

  String get semanticsLabel =>
      '로컬 저장 영수증. ${saved ? '$savedTimeLabel 저장 완료' : '저장 중'}. '
      '획득 $earnedXp XP. 연속 학습 $streakDays일. $syncLabel.';
}
