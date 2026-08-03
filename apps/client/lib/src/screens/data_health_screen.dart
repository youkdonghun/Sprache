import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/offline_readiness.dart';
import '../services/data_health_report.dart';
import '../services/recovery_backup_catalog.dart';
import '../services/tts_service.dart';
import '../state/app_state.dart';
import '../state/connection_state.dart';
import '../state/device_preferences_state.dart';
import '../state/local_storage_state.dart';
import '../theme/app_theme.dart';

class DataHealthScreen extends ConsumerStatefulWidget {
  const DataHealthScreen({super.key, this.catalog});

  final RecoveryBackupCatalogService? catalog;

  @override
  ConsumerState<DataHealthScreen> createState() => _DataHealthScreenState();
}

class _DataHealthScreenState extends ConsumerState<DataHealthScreen> {
  late final RecoveryBackupCatalogService _catalog;
  late Future<LocalRecoveryInventory> _inventory;
  Future<List<TtsVoice>>? _offlineVoices;
  String? _offlineVoiceLanguage;
  String? _busySection;

  @override
  void initState() {
    super.initState();
    _catalog = widget.catalog ?? RecoveryBackupCatalogService();
    _inventory = _catalog.inspect();
  }

  void _refresh() {
    setState(() {
      _inventory = _catalog.inspect();
      _offlineVoices = null;
      _offlineVoiceLanguage = null;
    });
  }

  Future<List<TtsVoice>> _voicesFor(String languageCode) {
    if (_offlineVoices == null || _offlineVoiceLanguage != languageCode) {
      _offlineVoiceLanguage = languageCode;
      final language = ref.read(appControllerProvider).selectedLanguage;
      _offlineVoices = ref
          .read(deviceTtsServiceProvider)
          .voicesFor(language, refresh: true);
    }
    return _offlineVoices!;
  }

  Future<void> _retry(String sectionId) async {
    if (_busySection != null) return;
    setState(() => _busySection = sectionId);
    try {
      await ref
          .read(connectionControllerProvider.notifier)
          .syncOrRestore(manual: true);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('상태를 다시 확인했습니다.')));
    } finally {
      if (mounted) setState(() => _busySection = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appControllerProvider);
    final connection = ref.watch(connectionControllerProvider);
    final localStorage = ref.watch(localStorageControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('데이터 상태'),
        actions: [
          IconButton(
            key: const Key('refresh-data-health'),
            tooltip: '다시 확인',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<LocalRecoveryInventory>(
        future: _inventory,
        builder: (context, snapshot) {
          if (!snapshot.hasData && snapshot.error == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final recovery =
              snapshot.data ??
              LocalRecoveryInventory(
                items: const [],
                minimumAge: const Duration(days: 30),
                inspectedAt: DateTime.now().toUtc(),
              );
          final report = const DataHealthReportBuilder().build(
            app: app,
            connection: connection,
            recovery: recovery,
          );
          return ListView(
            key: const Key('data-health-list'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _HealthSummary(report: report),
              const SizedBox(height: 12),
              for (final section in report.sections) ...[
                _HealthSectionCard(
                  section: section,
                  busy: _busySection == section.id,
                  onRetry: section.retryable ? () => _retry(section.id) : null,
                ),
                const SizedBox(height: 8),
              ],
              FutureBuilder<List<TtsVoice>>(
                future: _voicesFor(app.selectedLanguage.code),
                builder: (context, voiceSnapshot) {
                  final voices = voiceSnapshot.data;
                  final offlineTtsAvailable = voices?.any(
                    (voice) => voice.networkRequired != true,
                  );
                  final offline = const OfflineReadinessBuilder().build(
                    databaseReady: app.isHydrated,
                    localItemCount: ref
                        .read(appControllerProvider.notifier)
                        .allContentItems
                        .length,
                    offlineTtsAvailable: offlineTtsAvailable,
                    speechPackAvailable: null,
                    pendingWrites:
                        (app.pendingSync == null ? 0 : 1) +
                        localStorage.pendingImportCount,
                  );
                  return _OfflineReadinessCard(report: offline);
                },
              ),
              const SizedBox(height: 12),
              _BackupReceiptCard(receipt: report.lastBackup),
              if (report.pendingSections.isNotEmpty) ...[
                const SizedBox(height: 12),
                _PendingSectionsCard(
                  sections: report.pendingSections,
                  offlineLocked: connection.policy.offlineLock,
                  busy: _busySection != null,
                  onRetry: (section) => _retry('pending-${section.id}'),
                ),
              ],
              if (snapshot.error != null) ...[
                const SizedBox(height: 12),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.warning_amber_rounded),
                    title: Text('복구 사본 목록을 읽지 못했습니다.'),
                    subtitle: Text('앱 데이터와 현재 저장 연결은 그대로 유지됩니다.'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _OfflineReadinessCard extends StatelessWidget {
  const _OfflineReadinessCard({required this.report});

  final OfflineReadinessReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('offline-readiness-card'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  report.canStudy
                      ? Icons.offline_bolt_outlined
                      : Icons.cloud_off_outlined,
                  color: report.canStudy ? AppTheme.success : AppTheme.warning,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    report.canStudy
                        ? '인터넷 없이도 학습할 수 있어요'
                        : '오프라인 학습 준비를 확인해 주세요',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text('${report.readyCount}/${report.checks.length} 완료'),
              ],
            ),
            const SizedBox(height: 8),
            for (final check in report.checks)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  switch (check.level) {
                    OfflineReadinessLevel.ready => Icons.check_circle_outline,
                    OfflineReadinessLevel.deviceService =>
                      Icons.phonelink_setup_outlined,
                    OfflineReadinessLevel.unavailable =>
                      Icons.error_outline_rounded,
                    OfflineReadinessLevel.unknown => Icons.help_outline_rounded,
                  },
                  size: 20,
                  color: check.level == OfflineReadinessLevel.ready
                      ? AppTheme.success
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(check.label),
                subtitle: Text(check.detail),
              ),
            const Divider(),
            const Text(
              '뜻 고르기, 직접 쓰기, 카드 복습은 인터넷 없이 이용할 수 있습니다. '
              '오프라인 음성이나 언어팩이 없으면 읽기 표기와 자기 평가로 이어집니다.',
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthSummary extends StatelessWidget {
  const _HealthSummary({required this.report});

  final DataHealthReport report;

  @override
  Widget build(BuildContext context) {
    final healthy = report.attentionCount == 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: (healthy ? AppTheme.success : AppTheme.warning).withValues(
          alpha: 0.09,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (healthy ? AppTheme.success : AppTheme.warning).withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            healthy ? Icons.verified_user_outlined : Icons.health_and_safety,
            color: healthy ? AppTheme.success : AppTheme.warning,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  healthy ? '학습 데이터에 문제가 없어요' : '확인할 저장 항목이 있어요',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '마지막 확인 ${report.generatedAt.toLocal()} · 확인 필요 ${report.attentionCount}개',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthSectionCard extends StatelessWidget {
  const _HealthSectionCard({
    required this.section,
    required this.busy,
    required this.onRetry,
  });

  final DataHealthSection section;
  final bool busy;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (section.level) {
      DataHealthLevel.healthy => (
        Icons.check_circle_outline_rounded,
        AppTheme.success,
        '정상',
      ),
      DataHealthLevel.waiting => (
        Icons.schedule_rounded,
        AppTheme.warning,
        '대기',
      ),
      DataHealthLevel.attention => (
        Icons.error_outline_rounded,
        AppTheme.danger,
        '확인 필요',
      ),
      DataHealthLevel.unavailable => (
        Icons.remove_circle_outline_rounded,
        Theme.of(context).colorScheme.onSurfaceVariant,
        '선택 사항',
      ),
    };
    return Card(
      key: Key('data-health-${section.id}'),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Row(
          children: [
            Expanded(
              child: Text(
                section.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
        subtitle: Text('${section.summary}\n${section.detail}'),
        isThreeLine: true,
        trailing: onRetry == null
            ? null
            : IconButton(
                tooltip: '이 항목 다시 확인',
                onPressed: busy ? null : onRetry,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
      ),
    );
  }
}

class _BackupReceiptCard extends StatelessWidget {
  const _BackupReceiptCard({required this.receipt});

  final BackupVerificationReceipt? receipt;

  @override
  Widget build(BuildContext context) {
    final value = receipt;
    return Card(
      key: const Key('last-backup-receipt'),
      child: value == null
          ? const ListTile(
              leading: Icon(Icons.receipt_long_outlined),
              title: Text('백업 확인 기록'),
              subtitle: Text('아직 확인된 앱 내부 복구 사본이 없습니다.'),
            )
          : ListTile(
              leading: Icon(
                value.verified
                    ? Icons.verified_outlined
                    : Icons.gpp_maybe_outlined,
                color: value.verified ? AppTheme.success : AppTheme.warning,
              ),
              title: const Text(
                '마지막 백업 확인',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${value.createdAt.toLocal()} · ${_formatBytes(value.byteLength)}'
                '${value.itemCount == null ? '' : ' · 항목 ${value.itemCount}개'}\n'
                '${value.verified ? '파일 손상 없음' : '파일 상태 확인 필요'}'
                '${value.sha256Hex == null ? '' : ' · ${value.sha256Hex!.substring(0, 12)}…'}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                key: const Key('copy-backup-receipt'),
                tooltip: '백업 정보 복사',
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: value.clipboardText),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('백업 정보를 복사했습니다.')),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
              ),
            ),
    );
  }
}

class _PendingSectionsCard extends StatelessWidget {
  const _PendingSectionsCard({
    required this.sections,
    required this.offlineLocked,
    required this.busy,
    required this.onRetry,
  });

  final List<PendingDataSection> sections;
  final bool offlineLocked;
  final bool busy;
  final ValueChanged<PendingDataSection> onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('pending-sync-sections'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '아직 동기화되지 않은 항목',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 3),
            Text(
              offlineLocked
                  ? 'Drive 동기화 일시 중지를 해제하면 다시 시도할 수 있습니다.'
                  : '빠뜨리는 항목이 없도록 최신 전체 저장본도 함께 확인합니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            for (final section in sections)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(section.title),
                subtitle: Text('${section.itemCount}개 기다리는 중'),
                trailing: TextButton.icon(
                  key: Key('retry-pending-${section.id}'),
                  onPressed: offlineLocked || busy
                      ? null
                      : () => onRetry(section),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('재시도'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kib = bytes / 1024;
  if (kib < 1024) return '${kib.toStringAsFixed(1)} KB';
  return '${(kib / 1024).toStringAsFixed(1)} MB';
}
