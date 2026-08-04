import 'web_focus_workspace_stub.dart'
    if (dart.library.js_interop) 'web_focus_workspace_web.dart'
    as platform;

class WebFocusWorkspaceService {
  const WebFocusWorkspaceService();

  bool get isSupported => platform.isFullscreenSupported();

  bool get isActive => platform.isFullscreenActive();

  Future<bool> toggle() => platform.toggleFullscreen();
}
