import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/release_link_share_service.dart';
import '../services/release_update_coordinator.dart';
import '../services/release_update_service.dart';

class StartupReleaseUpdatePrompt extends StatefulWidget {
  const StartupReleaseUpdatePrompt({
    required this.child,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.manifestUrl,
    this.enabled = true,
    this.coordinator,
    this.linkShareService,
    super.key,
  });

  final Widget child;
  final String currentVersion;
  final int currentBuildNumber;
  final String manifestUrl;
  final bool enabled;
  final ReleaseUpdateCoordinator? coordinator;
  final ReleaseLinkShareService? linkShareService;

  @override
  State<StartupReleaseUpdatePrompt> createState() =>
      _StartupReleaseUpdatePromptState();
}

class _StartupReleaseUpdatePromptState
    extends State<StartupReleaseUpdatePrompt> {
  late ReleaseUpdateCoordinator _coordinator;
  late ReleaseLinkShareService _linkShareService;
  ReleaseUpdateCheck? _check;
  bool _dismissed = false;
  bool _checking = false;
  bool _applying = false;
  bool _sharing = false;
  double? _progress;
  String? _status;

  @override
  void initState() {
    super.initState();
    _configureServices();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnce());
  }

  @override
  void didUpdateWidget(covariant StartupReleaseUpdatePrompt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator ||
        oldWidget.manifestUrl != widget.manifestUrl ||
        oldWidget.linkShareService != widget.linkShareService) {
      _configureServices();
    }
  }

  void _configureServices() {
    _coordinator =
        widget.coordinator ??
        DeviceReleaseUpdateCoordinator(
          manifestUri: Uri.parse(widget.manifestUrl),
        );
    _linkShareService =
        widget.linkShareService ?? const DeviceReleaseLinkShareService();
  }

  Future<void> _checkOnce() async {
    if (!mounted ||
        !widget.enabled ||
        _checking ||
        ReleaseVersion.tryParse(widget.currentVersion) == null) {
      return;
    }
    _checking = true;
    try {
      final result = await _coordinator.check(
        widget.currentVersion,
        currentBuildNumber: widget.currentBuildNumber,
      );
      if (mounted && result.updateAvailable) {
        setState(() => _check = result);
      }
    } on Object {
      // 시작 확인은 조용히 실패한다. 사용자는 설정에서 직접 다시 확인할 수 있다.
    } finally {
      _checking = false;
    }
  }

  Future<void> _applyUpdate() async {
    final check = _check;
    if (check == null || _applying) return;
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
            if (_progress != null) {
              _status = '다운로드 ${(_progress! * 100).clamp(0, 100).round()}%';
            }
          });
        },
      );
      if (mounted) setState(() => _status = result.message);
    } catch (error) {
      if (mounted) setState(() => _status = _updateMessageOf(error));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _shareAppLinks(BuildContext actionContext) async {
    final check = _check;
    if (check == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final box = actionContext.findRenderObject();
      final origin = box is RenderBox
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      await _linkShareService.shareAppLinks(
        manifest: check.manifest,
        origin: origin,
      );
      if (mounted) setState(() => _status = 'Android·iPhone 설치 링크를 공유했습니다.');
    } catch (error) {
      await Clipboard.setData(
        ClipboardData(text: appInstallShareText(check.manifest)),
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
    if (check == null || _dismissed) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          left: 12,
          right: 12,
          top: MediaQuery.paddingOf(context).top + 8,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Material(
                key: const Key('startup-release-update-prompt'),
                elevation: 8,
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.system_update_alt_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '새 버전 ${check.manifest.version}이 있어요',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  check.manifest.notes.firstOrNull ??
                                      '업데이트하면 최신 기능과 수정 사항을 사용할 수 있습니다.',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: const Key('dismiss-startup-update'),
                            onPressed: _applying
                                ? null
                                : () => setState(() => _dismissed = true),
                            tooltip: '나중에',
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      if (_applying) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: _progress),
                      ],
                      if (_status case final status?) ...[
                        const SizedBox(height: 6),
                        Semantics(liveRegion: true, child: Text(status)),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Builder(
                            builder: (actionContext) => OutlinedButton.icon(
                              key: const Key('share-startup-app-links'),
                              onPressed: _sharing
                                  ? null
                                  : () => _shareAppLinks(actionContext),
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('앱 링크 공유'),
                            ),
                          ),
                          FilledButton.icon(
                            key: const Key('apply-startup-update'),
                            onPressed: _applying ? null : _applyUpdate,
                            icon: const Icon(Icons.download_rounded),
                            label: Text(
                              _coordinator.platformKey == 'pwa'
                                  ? '지금 적용'
                                  : '지금 업데이트',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _updateMessageOf(Object error) {
  if (error is ReleaseUpdateException) return error.message;
  return '업데이트 작업을 완료하지 못했습니다.';
}
