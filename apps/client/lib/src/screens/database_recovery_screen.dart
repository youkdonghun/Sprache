import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/database/database_bootstrap.dart';

class DatabaseRecoveryScreen extends StatefulWidget {
  const DatabaseRecoveryScreen({
    super.key,
    required this.diagnostic,
    required this.onExport,
    required this.onRetry,
  });

  final DatabaseRecoveryDiagnostic diagnostic;
  final Future<String> Function() onExport;
  final Future<void> Function() onRetry;

  @override
  State<DatabaseRecoveryScreen> createState() => _DatabaseRecoveryScreenState();
}

class _DatabaseRecoveryScreenState extends State<DatabaseRecoveryScreen> {
  bool _exporting = false;
  bool _retrying = false;

  Future<void> _export() async {
    if (_exporting || _retrying) return;
    setState(() => _exporting = true);
    try {
      final message = await widget.onExport();
      if (mounted) _showMessage(message);
    } catch (_) {
      if (mounted) {
        _showMessage('복구 파일을 저장하지 못했습니다. 저장 위치 권한을 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _retry() async {
    if (_exporting || _retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } catch (_) {
      if (mounted) _showMessage('다시 열지 못했습니다. 안전 사본을 먼저 저장해 주세요.');
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  Future<void> _copyDiagnostic() async {
    await Clipboard.setData(
      ClipboardData(text: widget.diagnostic.clipboardText),
    );
    if (mounted) _showMessage('민감한 원문 없이 진단 정보를 복사했습니다.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final diagnostic = widget.diagnostic;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.errorContainer,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(
                            dimension: 58,
                            child: Icon(
                              Icons.health_and_safety_rounded,
                              color: colors.onErrorContainer,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '읽기 전용 복구 모드',
                                key: const Key('database-recovery-title'),
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                diagnostic.code.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              diagnostic.summary,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '복구가 끝날 때까지 학습 데이터에 새 내용을 쓰거나 초기화하지 않습니다. '
                              '먼저 안전 사본을 저장한 다음 앱을 다시 열어 보세요.',
                            ),
                            if (diagnostic.hasPreservedDatabase) ...[
                              const SizedBox(height: 14),
                              Container(
                                key: const Key('database-preserved-status'),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.verified_user_rounded,
                                      color: colors.onPrimaryContainer,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        '원본 데이터 파일 ${diagnostic.preservedFiles.length}개를 '
                                        '앱 안의 복구 폴더에 안전하게 보관했습니다.',
                                        style: TextStyle(
                                          color: colors.onPrimaryContainer,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _RecoveryDetails(diagnostic: diagnostic),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 560;
                        final export = FilledButton.icon(
                          key: const Key('export-database-recovery'),
                          onPressed: _exporting || _retrying ? null : _export,
                          icon: _exporting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.archive_rounded),
                          label: Text(_exporting ? '복구 파일 만드는 중…' : '복구 파일 저장'),
                        );
                        final retry = OutlinedButton.icon(
                          key: const Key('retry-database-open'),
                          onPressed: _exporting || _retrying ? null : _retry,
                          icon: _retrying
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded),
                          label: Text(_retrying ? '확인 중…' : '다시 열기'),
                        );
                        final copy = TextButton.icon(
                          key: const Key('copy-database-diagnostic'),
                          onPressed: _copyDiagnostic,
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('진단 복사'),
                        );
                        if (compact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              export,
                              const SizedBox(height: 8),
                              retry,
                              const SizedBox(height: 4),
                              copy,
                            ],
                          );
                        }
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.end,
                          children: [copy, retry, export],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '도움을 요청할 때는 먼저 진단 정보만 공유해 주세요. '
                      '복구 파일에는 개인 학습 데이터가 들어 있으니 믿을 수 있는 곳에만 보관하세요.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryDetails extends StatelessWidget {
  const _RecoveryDetails({required this.diagnostic});

  final DatabaseRecoveryDiagnostic diagnostic;

  @override
  Widget build(BuildContext context) {
    final detected = diagnostic.detectedSchemaVersion?.toString() ?? '확인 불가';
    final bytes = diagnostic.databaseByteLength;
    final size = bytes == null ? '확인 불가' : _formatBytes(bytes);
    return Card(
      child: ExpansionTile(
        key: const Key('database-recovery-details'),
        leading: const Icon(Icons.fact_check_outlined),
        title: const Text(
          '복구 진단',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(diagnostic.code.stableCode),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _detail(
            '데이터 형식',
            '$detected / 앱 ${diagnostic.expectedSchemaVersion}',
          ),
          _detail('원본 크기', size),
          _detail(
            '마지막 수정',
            diagnostic.databaseModifiedAt?.toLocal().toString() ?? '확인 불가',
          ),
          _detail('보존 파일', '${diagnostic.preservedFiles.length}개'),
          _detail('오류 요약', diagnostic.technicalSummary),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kib = bytes / 1024;
    if (kib < 1024) return '${kib.toStringAsFixed(1)} KB';
    return '${(kib / 1024).toStringAsFixed(1)} MB';
  }
}
