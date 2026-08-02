import 'package:flutter/material.dart';

import '../integrations/google/google_connection_service.dart';
import '../integrations/google/google_drive_client.dart';
import '../services/recovery_backup_catalog.dart';

class StorageMaintenanceDialog extends StatefulWidget {
  const StorageMaintenanceDialog({
    super.key,
    required this.localCatalog,
    this.remoteService,
    this.onRestoreLocal,
  });

  final RecoveryBackupCatalogService localCatalog;
  final RemoteStorageRetentionService? remoteService;
  final Future<void> Function(LocalRecoveryBackup backup)? onRestoreLocal;

  @override
  State<StorageMaintenanceDialog> createState() =>
      _StorageMaintenanceDialogState();
}

class _StorageMaintenanceDialogState extends State<StorageMaintenanceDialog> {
  LocalRecoveryInventory? _local;
  DriveRetentionInventory? _remote;
  final _selectedLocal = <String>{};
  final _selectedRemote = <String>{};
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final local = await widget.localCatalog.inspect();
      final remoteService = widget.remoteService;
      final remote = remoteService == null
          ? null
          : await remoteService.inspectDriveRetention();
      if (!mounted) return;
      setState(() {
        _local = local;
        _remote = remote;
        _selectedLocal.clear();
        _selectedRemote.clear();
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = '보존 항목을 확인하지 못했습니다. 연결 상태와 폴더 권한을 확인해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteLocal() async {
    final inventory = _local;
    if (inventory == null || _selectedLocal.isEmpty) return;
    final approved = await _confirm(
      title: '로컬 복구 사본을 삭제할까요?',
      body:
          '선택한 ${_selectedLocal.length}개는 30일 이상 지난 사본입니다. '
          '이 작업은 휴지통을 거치지 않으며 되돌릴 수 없습니다.',
      action: '영구 삭제',
    );
    if (!approved || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await widget.localCatalog.deleteSelected(
        inventory: inventory,
        selectedIds: _selectedLocal,
      );
      if (!mounted) return;
      _showMessage(
        '로컬 복구 사본 ${result.deletedCount}개 · ${_formatBytes(result.deletedBytes)}를 삭제했습니다.',
      );
      await _refresh();
    } catch (_) {
      if (mounted) _showMessage('목록이 바뀌었거나 삭제 권한이 없습니다. 새로고침 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _trashRemote() async {
    final inventory = _remote;
    final service = widget.remoteService;
    if (inventory == null || service == null || _selectedRemote.isEmpty) return;
    final approved = await _confirm(
      title: 'Drive의 이전 파일을 정리할까요?',
      body:
          '선택한 ${_selectedRemote.length}개는 현재 manifest가 참조하지 않고 '
          '30일 이상 지난 파일입니다. 영구 삭제하지 않고 Google Drive 휴지통으로 이동합니다.',
      action: '휴지통으로 이동',
    );
    if (!approved || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await service.trashDriveRetentionItems(
        inventory: inventory,
        selectedFileIds: _selectedRemote,
      );
      if (!mounted) return;
      _showMessage(
        'Drive 파일 ${result.trashedCount}개 · ${_formatBytes(result.trashedBytes)}를 휴지통으로 옮겼습니다.',
      );
      await _refresh();
    } catch (_) {
      if (mounted) _showMessage('manifest가 바뀌었거나 Drive 정리에 실패했습니다. 새로고침해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String action,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.cleaning_services_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '저장 공간 관리',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '새로고침',
                    onPressed: _busy ? null : _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Text('자동 삭제하지 않습니다. 30일 보존 기간이 지난 항목만 직접 선택할 수 있습니다.'),
              const SizedBox(height: 14),
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: ListView(
                  children: [
                    _LocalRetentionSection(
                      inventory: _local,
                      selected: _selectedLocal,
                      enabled: !_busy,
                      onChanged: (id, value) => setState(() {
                        value
                            ? _selectedLocal.add(id)
                            : _selectedLocal.remove(id);
                      }),
                      onDelete: _selectedLocal.isEmpty || _busy
                          ? null
                          : _deleteLocal,
                      onRestore: widget.onRestoreLocal,
                    ),
                    const SizedBox(height: 12),
                    _DriveRetentionSection(
                      connected: widget.remoteService != null,
                      inventory: _remote,
                      selected: _selectedRemote,
                      enabled: !_busy,
                      onChanged: (id, value) => setState(() {
                        value
                            ? _selectedRemote.add(id)
                            : _selectedRemote.remove(id);
                      }),
                      onTrash: _selectedRemote.isEmpty || _busy
                          ? null
                          : _trashRemote,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalRetentionSection extends StatelessWidget {
  const _LocalRetentionSection({
    required this.inventory,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.onDelete,
    required this.onRestore,
  });

  final LocalRecoveryInventory? inventory;
  final Set<String> selected;
  final bool enabled;
  final void Function(String id, bool value) onChanged;
  final VoidCallback? onDelete;
  final Future<void> Function(LocalRecoveryBackup backup)? onRestore;

  @override
  Widget build(BuildContext context) {
    final items = inventory?.items ?? const <LocalRecoveryBackup>[];
    return _RetentionCard(
      key: const Key('local-recovery-retention'),
      title: '로컬 DB 복구 사본',
      subtitle: items.isEmpty
          ? '보존된 사본이 없습니다.'
          : '${items.length}개 · 정리 가능 ${inventory!.eligibleCount}개',
      action: OutlinedButton.icon(
        onPressed: onDelete,
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('선택 영구 삭제'),
      ),
      children: [
        for (final item in items)
          CheckboxListTile(
            dense: true,
            value: selected.contains(item.id),
            onChanged: enabled && item.eligibleForCleanup
                ? (value) => onChanged(item.id, value ?? false)
                : null,
            title: Text(
              item.reason == null ? item.id : _reasonLabel(item.reason!),
            ),
            subtitle: Text(
              '${_formatDateTime(item.modifiedAt)} · ${_formatBytes(item.byteLength)} · ${item.fileCount}개 파일'
              '${item.itemCount == null ? '' : ' · 항목 ${item.itemCount}개'}'
              '${item.sha256Hex == null ? '' : ' · ${item.verified ? 'SHA-256 확인' : '검증 실패'}'}'
              '${item.eligibleForCleanup ? '' : ' · 30일 보존 중'}',
            ),
            secondary: item.sha256Hex == null
                ? null
                : IconButton(
                    key: Key('restore-checkpoint-${item.id}'),
                    tooltip: item.verified ? '이 안전 지점 복원' : '손상되어 복원할 수 없음',
                    onPressed: enabled && item.verified && onRestore != null
                        ? () => onRestore!(item)
                        : null,
                    icon: const Icon(Icons.restore_rounded),
                  ),
          ),
      ],
    );
  }
}

class _DriveRetentionSection extends StatelessWidget {
  const _DriveRetentionSection({
    required this.connected,
    required this.inventory,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.onTrash,
  });

  final bool connected;
  final DriveRetentionInventory? inventory;
  final Set<String> selected;
  final bool enabled;
  final void Function(String id, bool value) onChanged;
  final VoidCallback? onTrash;

  @override
  Widget build(BuildContext context) {
    final items = inventory?.items ?? const <DriveRetentionItem>[];
    return _RetentionCard(
      key: const Key('drive-retention'),
      title: 'Google Drive 이전 동기화 파일',
      subtitle: !connected
          ? 'Drive 연결 후 확인할 수 있습니다.'
          : items.isEmpty
          ? '현재 manifest가 참조하지 않는 파일이 없습니다.'
          : '${items.length}개 · 정리 가능 ${inventory!.eligibleCount}개',
      action: OutlinedButton.icon(
        onPressed: onTrash,
        icon: const Icon(Icons.delete_sweep_outlined),
        label: const Text('선택 휴지통 이동'),
      ),
      children: [
        for (final item in items)
          CheckboxListTile(
            dense: true,
            value: selected.contains(item.fileId),
            onChanged: enabled && item.eligibleForCleanup
                ? (value) => onChanged(item.fileId, value ?? false)
                : null,
            title: Text(item.fileName),
            subtitle: Text(
              '${item.folderName} · ${_formatBytes(item.byteLength)}'
              '${item.eligibleForCleanup ? '' : ' · 30일 보존 중'}',
            ),
          ),
      ],
    );
  }
}

class _RetentionCard extends StatelessWidget {
  const _RetentionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.children,
  });

  final String title;
  final String subtitle;
  final Widget action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            if (children.isNotEmpty) ...[
              const Divider(height: 20),
              ...children,
            ],
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: action),
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

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}.${two(local.month)}.${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _reasonLabel(String value) => switch (value) {
  'bulkImport' => '대량 가져오기 전 안전 지점',
  'bulkDelete' => '일괄 삭제 전 안전 지점',
  'restore' => '백업 복원 전 안전 지점',
  _ => '수동 안전 지점',
};
