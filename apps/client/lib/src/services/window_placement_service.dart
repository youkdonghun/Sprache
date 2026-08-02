import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

class WindowPlacement {
  const WindowPlacement({
    required this.bounds,
    required this.maximized,
    required this.focused,
  });

  final Rect bounds;
  final bool maximized;
  final bool focused;

  Map<String, Object?> toJson() => {
    'left': bounds.left,
    'top': bounds.top,
    'width': bounds.width,
    'height': bounds.height,
    'maximized': maximized,
    'focused': focused,
  };

  static WindowPlacement? fromJson(Object? value) {
    if (value is! Map) return null;
    final left = value['left'];
    final top = value['top'];
    final width = value['width'];
    final height = value['height'];
    if (left is! num ||
        top is! num ||
        width is! num ||
        height is! num ||
        !left.isFinite ||
        !top.isFinite ||
        !width.isFinite ||
        !height.isFinite ||
        width < 200 ||
        height < 200) {
      return null;
    }
    return WindowPlacement(
      bounds: Rect.fromLTWH(
        left.toDouble(),
        top.toDouble(),
        width.toDouble(),
        height.toDouble(),
      ),
      maximized: value['maximized'] == true,
      focused: value['focused'] != false,
    );
  }
}

Rect clampWindowToDisplays(Rect requested, List<Rect> displays) {
  if (displays.isEmpty) return requested;
  var target = displays.first;
  var bestArea = 0.0;
  for (final display in displays) {
    final intersection = requested.intersect(display);
    final area =
        intersection.width.clamp(0, double.infinity).toDouble() *
        intersection.height.clamp(0, double.infinity).toDouble();
    if (area > bestArea) {
      bestArea = area;
      target = display;
    }
  }
  final width = requested.width
      .clamp(target.width < 380 ? target.width : 380, target.width)
      .toDouble();
  final height = requested.height
      .clamp(target.height < 520 ? target.height : 520, target.height)
      .toDouble();
  final left = requested.left
      .clamp(target.left, target.right - width)
      .toDouble();
  final top = requested.top
      .clamp(target.top, target.bottom - height)
      .toDouble();
  return Rect.fromLTWH(left, top, width, height);
}

class WindowPlacementService with WindowListener {
  WindowPlacementService({Future<Directory> Function()? supportDirectory})
    : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _supportDirectory;
  Timer? _saveDebounce;
  bool _focused = true;

  Future<File> _file() async => File(
    p.join((await _supportDirectory()).path, 'window-placement-v1.json'),
  );

  Future<WindowPlacement?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      return WindowPlacement.fromJson(jsonDecode(await file.readAsString()));
    } on Object {
      return null;
    }
  }

  Future<List<Rect>> visibleDisplays() async {
    try {
      return (await screenRetriever.getAllDisplays())
          .map(
            (display) => Rect.fromLTWH(
              display.visiblePosition?.dx ?? 0,
              display.visiblePosition?.dy ?? 0,
              display.visibleSize?.width ?? display.size.width,
              display.visibleSize?.height ?? display.size.height,
            ),
          )
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<WindowPlacement?> loadSafe() async {
    final saved = await load();
    if (saved == null) return null;
    return WindowPlacement(
      bounds: clampWindowToDisplays(saved.bounds, await visibleDisplays()),
      maximized: saved.maximized,
      focused: saved.focused,
    );
  }

  void startTracking() {
    windowManager.addListener(this);
  }

  void dispose() {
    _saveDebounce?.cancel();
    windowManager.removeListener(this);
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(saveCurrent()),
    );
  }

  Future<void> saveCurrent() async {
    try {
      final placement = WindowPlacement(
        bounds: await windowManager.getBounds(),
        maximized: await windowManager.isMaximized(),
        focused: _focused,
      );
      final file = await _file();
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsString(
        jsonEncode(placement.toJson()),
        flush: true,
      );
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
    } on Object {
      // Window persistence must never keep the app from opening or closing.
    }
  }

  @override
  void onWindowBlur() {
    _focused = false;
    _scheduleSave();
  }

  @override
  void onWindowFocus() {
    _focused = true;
    _scheduleSave();
  }

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();

  @override
  void onWindowClose() => unawaited(saveCurrent());
}
