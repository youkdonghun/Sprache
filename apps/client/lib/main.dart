import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app_bootstrap.dart';
import 'src/data/database/database_bootstrap.dart';
import 'src/services/release_runtime_probe.dart';
import 'src/services/temporary_voice_recording_service.dart';
import 'src/services/window_placement_service.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize();
  final releaseRuntimeProbe = ReleaseRuntimeProbe.fromEnvironment(
    defaultTargetPlatform,
  );
  if (!kIsWeb) {
    await const TemporaryVoiceRecordingJanitor().clearAbandonedFiles();
  }

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await windowManager.ensureInitialized();
    final placementService = WindowPlacementService();
    final restored = await placementService.loadSafe();
    final windowOptions = WindowOptions(
      size: restored?.bounds.size ?? const Size(1040, 760),
      minimumSize: Size(380, 520),
      center: restored == null,
      title: 'Sprache',
      titleBarStyle: TitleBarStyle.normal,
    );
    unawaited(
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setResizable(true);
        if (restored != null) {
          await windowManager.setBounds(restored.bounds);
          if (restored.maximized) await windowManager.maximize();
        }
        await windowManager.show();
        if (restored?.focused ?? true) await windowManager.focus();
        placementService.startTracking();
      }),
    );
  }

  final bootstrap = SpracheBootstrap(
    bootstrapper: DatabaseBootstrapService(),
    launchArguments: arguments,
  );
  final releaseFrameBoundaryKey = releaseRuntimeProbe.enabled
      ? GlobalKey(debugLabel: 'release-runtime-frame')
      : null;
  runApp(
    releaseFrameBoundaryKey == null
        ? bootstrap
        : RepaintBoundary(key: releaseFrameBoundaryKey, child: bootstrap),
  );
  if (releaseFrameBoundaryKey != null) {
    unawaited(
      _recordReleaseRuntimeEvidence(
        releaseRuntimeProbe,
        WidgetsBinding.instance.endOfFrame,
        () => _captureReleaseFramePng(releaseFrameBoundaryKey),
      ),
    );
  }
}

Future<void> _recordReleaseRuntimeEvidence(
  ReleaseRuntimeProbe probe,
  Future<void> endOfFrame,
  ReleaseProbeFrameCapture captureFrame,
) async {
  try {
    await probe.recordAfterFirstFrame(endOfFrame, captureFrame: captureFrame);
  } on Object catch (error, stackTrace) {
    debugPrint('Release runtime probe failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<Uint8List> _captureReleaseFramePng(GlobalKey boundaryKey) async {
  final context = boundaryKey.currentContext;
  if (context == null) {
    throw StateError('Release frame boundary is not mounted.');
  }
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) {
    throw StateError('Release frame boundary is not renderable.');
  }

  final image = await renderObject.toImage(
    pixelRatio: View.of(context).devicePixelRatio,
  );
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw StateError('Flutter could not encode the first frame as PNG.');
    }
    return byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
  } finally {
    image.dispose();
  }
}
