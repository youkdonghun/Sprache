import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/release_link_share_service.dart';
import '../services/release_update_coordinator.dart';
import '../services/release_update_service.dart';

class ReleaseUpdateCard extends StatefulWidget {
  const ReleaseUpdateCard({
    required this.currentVersion,
    required this.manifestUrl,
    this.currentBuildNumber = 0,
    this.coordinator,
    this.linkShareService,
    super.key,
  });

  final String currentVersion;
  final int currentBuildNumber;
  final String manifestUrl;
  final ReleaseUpdateCoordinator? coordinator;
  final ReleaseLinkShareService? linkShareService;

  @override
  State<ReleaseUpdateCard> createState() => _ReleaseUpdateCardState();
}

class _ReleaseUpdateCardState extends State<ReleaseUpdateCard> {
  late ReleaseUpdateCoordinator _coordinator;
  late ReleaseLinkShareService _linkShareService;
  ReleaseUpdateCheck? _check;
  String? _status;
  bool _checking = false;
  bool _applying = false;
  bool _sharing = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _coordinator =
        widget.coordinator ??
        DeviceReleaseUpdateCoordinator(
          manifestUri: Uri.parse(widget.manifestUrl),
        );
    _linkShareService =
        widget.linkShareService ?? const DeviceReleaseLinkShareService();
  }

  @override
  void didUpdateWidget(covariant ReleaseUpdateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator ||
        oldWidget.manifestUrl != widget.manifestUrl ||
        oldWidget.linkShareService != widget.linkShareService) {
      _coordinator =
          widget.coordinator ??
          DeviceReleaseUpdateCoordinator(
            manifestUri: Uri.parse(widget.manifestUrl),
          );
      _check = null;
      _status = null;
      _linkShareService =
          widget.linkShareService ?? const DeviceReleaseLinkShareService();
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
      final result = await _coordinator.check(
        widget.currentVersion,
        currentBuildNumber: widget.currentBuildNumber,
      );
      if (!mounted) return;
      setState(() {
        _check = result;
        _status = result.updateAvailable
            ? '${result.manifest.version} 업데이트를 사용할 수 있습니다.'
            : result.canRedownloadCurrentAndroidApk
            ? '현재 최신 버전입니다. 필요하면 APK를 다시 받을 수 있습니다.'
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
    if (check == null ||
        (!check.updateAvailable && !check.canRedownloadCurrentAndroidApk) ||
        _applying) {
      return;
    }
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
            _status = _progress == null
                ? '업데이트 파일을 다운로드하고 있습니다.'
                : '다운로드 ${(_progress! * 100).clamp(0, 100).round()}%';
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

  Future<void> _shareAppLinks(BuildContext actionContext) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final box = actionContext.findRenderObject();
      final origin = box is RenderBox
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      await _linkShareService.shareAppLinks(
        manifest: _check?.manifest,
        origin: origin,
      );
      if (mounted) setState(() => _status = 'Android·iPhone 설치 링크를 공유했습니다.');
    } catch (error) {
      await Clipboard.setData(
        ClipboardData(text: appInstallShareText(_check?.manifest)),
      );
      if (mounted) {
        setState(() => _status = '공유창을 열 수 없어 설치 링크를 복사했습니다.');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final check = _check;
    final updateAvailable = check?.updateAvailable ?? false;
    final canApply =
        updateAvailable || (check?.canRedownloadCurrentAndroidApk ?? false);
    final latestVersion = check?.manifest.version.toString();
    final actionLabel =
        check?.canRedownloadCurrentAndroidApk == true && !updateAvailable
        ? '최신 APK 다시 받기'
        : _coordinator.platformKey == 'android'
        ? 'APK 업데이트 받기'
        : _coordinator.platformKey == 'pwa'
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
                        '업데이트·앱 공유',
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
            const Text('공식 배포 파일이 맞는지 확인한 뒤 설치 화면을 열어요.'),
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
                    _checking
                        ? Icons.hourglass_top_rounded
                        : Icons.refresh_rounded,
                  ),
                  label: Text(_checking ? '확인 중' : '업데이트 확인'),
                ),
                if (canApply)
                  FilledButton.icon(
                    key: const Key('apply-release-update'),
                    onPressed: _applying ? null : _applyUpdate,
                    icon: const Icon(Icons.download_rounded),
                    label: Text(actionLabel),
                  ),
                Builder(
                  builder: (actionContext) => OutlinedButton.icon(
                    key: const Key('share-app-install-links'),
                    onPressed: _sharing
                        ? null
                        : () => _shareAppLinks(actionContext),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('앱 설치 링크 공유'),
                  ),
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
