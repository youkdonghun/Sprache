import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'routing/app_router.dart';
import 'domain/app_experience_preferences.dart';
import 'domain/app_platform.dart';
import 'services/app_clock.dart';
import 'services/window_workspace_service.dart';
import 'state/app_state.dart';
import 'state/connection_state.dart';
import 'state/local_storage_state.dart';
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
  bool _initialRestoreScheduled = false;
  Timer? _calendarTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshCalendarDay();
    });
  }

  @override
  void dispose() {
    _calendarTimer?.cancel();
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
        _refreshCalendarDay();
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt != null &&
            now.difference(backgroundedAt) >= const Duration(seconds: 15)) {
          _syncForLifecycle(now);
        }
    }
  }

  void _refreshCalendarDay() {
    final now = ref.read(appClockProvider)();
    final day = localCalendarDay(now);
    final calendarDay = ref.read(calendarDayProvider.notifier);
    if (calendarDay.state != day) calendarDay.state = day;
    _calendarTimer?.cancel();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    final delay = nextDay.difference(now) + const Duration(seconds: 1);
    _calendarTimer = Timer(
      delay.isNegative ? const Duration(seconds: 1) : delay,
      () {
        if (mounted) _refreshCalendarDay();
      },
    );
  }

  void _syncForLifecycle(DateTime now) {
    final appController = ref.read(appControllerProvider.notifier);
    if (!ref.read(appControllerProvider).driveConnected) {
      unawaited(() async {
        await appController.flushPendingWrites();
        if (!mounted) return;
        await ref.read(localStorageControllerProvider.notifier).flush();
      }());
      return;
    }
    final connection = ref.read(connectionControllerProvider);
    if (connection.busy) return;
    final lastSync = _lastLifecycleSyncAt;
    if (lastSync != null &&
        now.difference(lastSync) < const Duration(seconds: 3)) {
      return;
    }
    _lastLifecycleSyncAt = now;
    unawaited(() async {
      await appController.flushPendingWrites();
      if (!mounted) return;
      await ref.read(connectionControllerProvider.notifier).syncOrRestore();
    }());
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    ref.watch(localStorageControllerProvider);
    final shouldRestoreConnection = ref.watch(
      appControllerProvider.select(
        (state) => state.isHydrated && state.driveConnected,
      ),
    );
    if (!shouldRestoreConnection) {
      _initialRestoreScheduled = false;
    } else if (!_initialRestoreScheduled) {
      _initialRestoreScheduled = true;
      final connection = ref.read(connectionControllerProvider);
      if (connection.phase == ConnectionPhase.disconnected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(
            ref
                .read(connectionControllerProvider.notifier)
                .restoreSavedConnection(),
          );
        });
      }
    }
    final usesMobileTheme = usesMobileStudyExperience(defaultTargetPlatform);
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final experience = ref.watch(
      appControllerProvider.select((state) => state.preferences.experience),
    );
    final accessibilityProfile = ref.watch(accessibilityInputProfileProvider);
    final reduceMotion =
        experience.reduceMotion || accessibilityProfile.reduceMotion;
    final lightTheme = usesMobileTheme
        ? AppTheme.mobileFor(
            experience,
            brightness: Brightness.light,
            accessibilityProfile: accessibilityProfile,
          )
        : AppTheme.desktopFor(
            experience,
            brightness: Brightness.light,
            accessibilityProfile: accessibilityProfile,
          );
    final darkTheme = usesMobileTheme
        ? AppTheme.mobileFor(
            experience,
            brightness: Brightness.dark,
            accessibilityProfile: accessibilityProfile,
          )
        : AppTheme.desktopFor(
            experience,
            brightness: Brightness.dark,
            accessibilityProfile: accessibilityProfile,
          );

    return MaterialApp.router(
      title: 'Sprache',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: switch (experience.colorMode) {
        AppColorMode.system => ThemeMode.system,
        AppColorMode.light => ThemeMode.light,
        AppColorMode.dark => ThemeMode.dark,
      },
      themeAnimationDuration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      routerConfig: router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final preferredScale = switch (experience.textScale) {
          AppTextScale.system => null,
          AppTextScale.small => 0.9,
          AppTextScale.medium => 1.0,
          AppTextScale.large => 1.2,
        };
        final scaledChild = MediaQuery(
          data: mediaQuery.copyWith(
            disableAnimations: mediaQuery.disableAnimations || reduceMotion,
            highContrast:
                mediaQuery.highContrast || accessibilityProfile.highContrast,
            textScaler: preferredScale == null
                ? mediaQuery.textScaler
                : TextScaler.linear(
                    (mediaQuery.textScaler.scale(1) * preferredScale).clamp(
                      0.8,
                      2.0,
                    ),
                  ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
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
            child: Focus(autofocus: true, child: scaledChild),
          );
        }
        return scaledChild;
      },
    );
  }
}
