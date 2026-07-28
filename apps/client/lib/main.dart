import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (defaultTargetPlatform == TargetPlatform.windows) {
    await windowManager.ensureInitialized();
    const windowOptions = WindowOptions(
      size: Size(1040, 760),
      minimumSize: Size(380, 520),
      center: true,
      title: '작업 보드',
      titleBarStyle: TitleBarStyle.normal,
    );
    unawaited(
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setResizable(true);
        await windowManager.show();
        await windowManager.focus();
      }),
    );
  }

  runApp(const ProviderScope(child: SpracheApp()));
}
