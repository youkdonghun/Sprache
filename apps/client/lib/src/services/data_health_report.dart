import '../state/app_state.dart';
import '../state/connection_state.dart';
import '../sync/sync_policy.dart';
import 'recovery_backup_catalog.dart';

enum DataHealthLevel { healthy, waiting, attention, unavailable }

class DataHealthSection {
  const DataHealthSection({
    required this.id,
    required this.title,
    required this.level,
    required this.summary,
    required this.detail,
    this.retryable = false,
  });

  final String id;
  final String title;
  final DataHealthLevel level;
  final String summary;
  final String detail;
  final bool retryable;
}

class BackupVerificationReceipt {
  const BackupVerificationReceipt({
    required this.createdAt,
    required this.byteLength,
    required this.verified,
    this.sha256Hex,
    this.itemCount,
    this.reason,
  });

  final DateTime createdAt;
  final int byteLength;
  final bool verified;
  final String? sha256Hex;
  final int? itemCount;
  final String? reason;

  String get clipboardText => [
    'Sprache 백업 검증 영수증',
    '시각(UTC): ${createdAt.toUtc().toIso8601String()}',
    '크기(bytes): $byteLength',
    '항목 수: ${itemCount ?? '기록 없음'}',
    '검증: ${verified ? '통과' : '확인 필요'}',
    'SHA-256: ${sha256Hex ?? '기록 없음'}',
    if (reason != null) '원인: $reason',
  ].join('\n');
}

class PendingDataSection {
  const PendingDataSection({
    required this.id,
    required this.title,
    required this.itemCount,
  });

  final String id;
  final String title;
  final int itemCount;
}

class DataHealthReport {
  const DataHealthReport({
    required this.sections,
    required this.pendingSections,
    required this.generatedAt,
    this.lastBackup,
  });

  final List<DataHealthSection> sections;
  final List<PendingDataSection> pendingSections;
  final DateTime generatedAt;
  final BackupVerificationReceipt? lastBackup;

  int get attentionCount => sections
      .where((section) => section.level == DataHealthLevel.attention)
      .length;
}

class DataHealthReportBuilder {
  const DataHealthReportBuilder();

  DataHealthReport build({
    required AppState app,
    required ConnectionState connection,
    required LocalRecoveryInventory recovery,
    DateTime? generatedAt,
  }) {
    final pending = app.pendingSync;
    final pendingSections = pending == null
        ? const <PendingDataSection>[]
        : _pendingSections(pending.payload);
    final lastCheckpoint = recovery.items
        .where((item) => item.verified && item.sha256Hex != null)
        .fold<LocalRecoveryBackup?>(
          null,
          (latest, item) =>
              latest == null || item.modifiedAt.isAfter(latest.modifiedAt)
              ? item
              : latest,
        );
    final lastBackup = lastCheckpoint != null
        ? BackupVerificationReceipt(
            createdAt: lastCheckpoint.modifiedAt,
            byteLength: lastCheckpoint.byteLength,
            verified: lastCheckpoint.verified,
            sha256Hex: lastCheckpoint.sha256Hex,
            itemCount: lastCheckpoint.itemCount,
            reason: lastCheckpoint.reason,
          )
        : null;

    return DataHealthReport(
      generatedAt: (generatedAt ?? DateTime.now()).toUtc(),
      lastBackup: lastBackup,
      pendingSections: pendingSections,
      sections: [
        DataHealthSection(
          id: 'sqlite',
          title: '앱 데이터베이스',
          level: app.isHydrated
              ? DataHealthLevel.healthy
              : DataHealthLevel.waiting,
          summary: app.isHydrated ? '로컬 DB 사용 가능' : '로컬 DB 여는 중',
          detail:
              '개인 콘텐츠 ${app.customItems.length}개 · 진도 ${app.progress.length}개 · 최근 세션 ${app.recentSessions.length}개',
        ),
        DataHealthSection(
          id: 'drive',
          title: 'Google Drive',
          level: switch (connection.phase) {
            ConnectionPhase.connected => DataHealthLevel.healthy,
            ConnectionPhase.connecting ||
            ConnectionPhase.syncing ||
            ConnectionPhase.disconnecting => DataHealthLevel.waiting,
            ConnectionPhase.failed => DataHealthLevel.attention,
            ConnectionPhase.disconnected => DataHealthLevel.unavailable,
          },
          summary: connection.policy.offlineLock
              ? 'Drive 동기화 일시 중지'
              : connection.displayStatus.label,
          detail: connection.policy.offlineLock
              ? '일시 중지를 해제할 때까지 Drive 요청을 보내지 않습니다.'
              : connection.diagnostic?.message ??
                    (connection.folderName == null
                        ? 'Drive를 연결하지 않아도 모든 학습 기능을 사용할 수 있습니다.'
                        : '폴더 ${connection.folderName}'),
          retryable:
              !connection.policy.offlineLock &&
              (connection.pendingChanges ||
                  connection.phase == ConnectionPhase.failed),
        ),
        DataHealthSection(
          id: 'pending',
          title: '동기화 대기열',
          level: pending == null
              ? DataHealthLevel.healthy
              : DataHealthLevel.waiting,
          summary: pending == null
              ? '대기 작업 없음'
              : '${pendingSections.length}개 섹션 전송 대기',
          detail: pending == null
              ? '로컬 변경은 모두 안전하게 반영되었습니다.'
              : '작업 ${pending.operationId} · 시도 ${pending.attempts}회 · 다음 시도 ${pending.nextAttemptAt.toLocal()}',
          retryable:
              pending != null &&
              !connection.policy.offlineLock &&
              (connection.runtimeReady ||
                  connection.phase == ConnectionPhase.connected),
        ),
      ],
    );
  }

  List<PendingDataSection> _pendingSections(Map<String, Object?> payload) {
    const labels = <String, String>{
      'profile': '계정 합산 지표',
      'settings': '학습·화면 설정',
      'progress': '문항별 진도',
      'customItems': '사용자 콘텐츠',
      'customItemTombstones': '삭제 기록',
      'recentSessions': '최근 학습 세션',
      'activeStudy': '진행 중 세션',
    };
    return [
      for (final entry in labels.entries)
        if (payload.containsKey(entry.key))
          PendingDataSection(
            id: entry.key,
            title: entry.value,
            itemCount: _itemCount(payload[entry.key]),
          ),
    ];
  }

  int _itemCount(Object? value) => switch (value) {
    final List<Object?> values => values.length,
    final Map<Object?, Object?> values => values.length,
    null => 0,
    _ => 1,
  };
}
