import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'routing/app_router.dart';
import 'services/window_workspace_service.dart';
import 'state/app_state.dart';
import 'state/connection_state.dart';
import 'theme/app_theme.dart';

class SpracheApp extends ConsumerStatefulWidget {
  const SpracheApp({super.key});

  @override
  ConsumerState<SpracheApp> createState() => _SpracheAppState();
}

class _SpracheAppState extends ConsumerState<SpracheApp>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  DateTime? _lastLifecycleSyncAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = DateTime.now();
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _backgroundedAt ??= now;
        _syncForLifecycle(now);
      case AppLifecycleState.resumed:
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt != null &&
            now.difference(backgroundedAt) >= const Duration(seconds: 15)) {
          _syncForLifecycle(now);
        }
    }
  }

  void _syncForLifecycle(DateTime now) {
    if (!ref.read(appControllerProvider).driveConnected) return;
    final connection = ref.read(connectionControllerProvider);
    if (connection.phase != ConnectionPhase.connected &&
        connection.phase != ConnectionPhase.failed) {
      return;
    }
    final lastSync = _lastLifecycleSyncAt;
    if (lastSync != null &&
        now.difference(lastSync) < const Duration(seconds: 3)) {
      return;
    }
    _lastLifecycleSyncAt = now;
    unawaited(ref.read(connectionControllerProvider.notifier).syncNow());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;

    return MaterialApp.router(
      title: 'Sprache',
      debugShowCheckedModeBanner: false,
      theme: isAndroid ? AppTheme.mobile : AppTheme.desktop,
      darkTheme: isAndroid ? AppTheme.mobileDark : AppTheme.desktopDark,
      themeMode: ThemeMode.system,
      themeAnimationDuration: const Duration(milliseconds: 220),
      routerConfig: router,
      builder: (context, child) {
        if (isWindows && child != null) {
          return CallbackShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.keyF,
                control: true,
                shift: true,
              ): () => unawaited(
                ref
                    .read(windowWorkspaceControllerProvider.notifier)
                    .toggleCompact(),
              ),
              const SingleActivator(
                LogicalKeyboardKey.keyM,
                control: true,
                shift: true,
              ): () => unawaited(
                ref.read(windowWorkspaceControllerProvider.notifier).minimize(),
              ),
            },
            child: Focus(autofocus: true, child: child),
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
