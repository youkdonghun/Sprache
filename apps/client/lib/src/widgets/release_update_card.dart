import 'package:flutter/material.dart';

import '../services/release_update_coordinator.dart';
import '../services/release_update_service.dart';

class ReleaseUpdateCard extends StatefulWidget {
  const ReleaseUpdateCard({
    required this.currentVersion,
    required this.manifestUrl,
    this.coordinator,
    super.key,
  });

  final String currentVersion;
  final String manifestUrl;
  final ReleaseUpdateCoordinator? coordinator;

  @override
  State<ReleaseUpdateCard> createState() => _ReleaseUpdateCardState();
}

class _ReleaseUpdateCardState extends State<ReleaseUpdateCard> {
  late ReleaseUpdateCoordinator _coordinator;
  ReleaseUpdateCheck? _check;
  String? _status;
  bool _checking = false;
  bool _applying = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _coordinator = widget.coordinator ??
        DeviceReleaseUpdateCoordinator(
          manifestUri: Uri.parse(widget.manifestUrl),
        );
  }

  @override
  void didUpdateWidget(covariant ReleaseUpdateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator ||
        oldWidget.manifestUrl != widget.manifestUrl) {
      _coordinator = widget.coordinator ??
          DeviceReleaseUpdateCoordinator(
            manifestUri: Uri.parse(widget.manifestUrl),
          );
      _check = null;
      _status = null;
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checking || _applying) return;
    setState(() {
      _checking = true;
      _status = '최신 버전을 확인하고 있습니다.';
      _check = null;
    });
    try {
      final result = await _coordinator.check(widget.currentVersion);
      if (!mounted) return;
      setState(() {
        _check = result;
        _status = result.updateAvailable
            ? '${result.manifest.version} 업데이트를 사용할 수 있습니다.'
            : '현재 최신 버전을 사용하고 있습니다.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = _messageOf(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _applyUpdate() async {
    final check = _check;
    if (check == null || !check.updateAvailable || _applying) return;
    setState(() {
      _applying = true;
      _progress = null;
      _status = _coordinator.platformKey == 'pwa'
          ? '새 웹 버전을 적용하고 있습니다.'
          : '업데이트 파일을 준비하고 있습니다.';
    });
    try {
      final result = await _coordinator.apply(
        check,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _progress = total <= 0 ? null : received / total;
            _status = '다운로드 ${(_progress! * 100).clamp(0, 100).round()}%';
          });
        },
      );
      if (mounted) setState(() => _status = result.message);
    } catch (error) {
      if (mounted) setState(() => _status = _messageOf(error));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final check = _check;
    final updateAvailable = check?.updateAvailable ?? false;
    final latestVersion = check?.manifest.version.toString();
    final actionLabel = _coordinator.platformKey == 'pwa'
        ? '새 버전 적용'
        : check?.artifact == null
        ? '릴리스 페이지 열기'
        : '다운로드 및 설치';
    return Card(
      key: const Key('release-update-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update_alt_rounded),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '앱 업데이트',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '현재 ${widget.currentVersion}'
                        '${latestVersion == null ? '' : ' · 최신 $latestVersion'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              '공개 GitHub Release에서 파일을 받고 크기와 SHA-256을 확인한 뒤 설치 화면을 엽니다.',
            ),
            if (check != null && check.manifest.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final note in check.manifest.notes.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text('• $note'),
                ),
            ],
            if (_applying) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(
                key: const Key('release-download-progress'),
                value: _progress,
              ),
            ],
            if (_status case final status?) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(status, key: const Key('release-update-status')),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('check-release-update'),
                  onPressed: _checking || _applying ? null : _checkForUpdate,
                  icon: Icon(
                    _checking ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
                  ),
                  label: Text(_checking ? '확인 중' : '업데이트 확인'),
                ),
                if (updateAvailable)
                  FilledButton.icon(
                    key: const Key('apply-release-update'),
                    onPressed: _applying ? null : _applyUpdate,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(actionLabel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _messageOf(Object error) {
  if (error is ReleaseUpdateException) return error.message;
  return '업데이트 작업을 완료하지 못했습니다.';
}
