import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool isFullscreenSupported() => web.document.fullscreenEnabled;

bool isFullscreenActive() => web.document.fullscreenElement != null;

Future<bool> toggleFullscreen() async {
  if (!isFullscreenSupported()) return false;
  if (isFullscreenActive()) {
    await web.document.exitFullscreen().toDart;
    return false;
  }
  final root = web.document.documentElement;
  if (root == null) return false;
  await root.requestFullscreen().toDart;
  return true;
}
