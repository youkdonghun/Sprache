import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routing/app_router.dart';
import 'routing/inbound_intent.dart';
import 'domain/app_experience_preferences.dart';
import 'domain/accessibility_input_profile.dart';
import 'domain/app_platform.dart';
import 'domain/study_preferences.dart';
import 'services/app_clock.dart';
import 'services/media_lifecycle_coordinator.dart';
import 'services/platform_inbound_intent_service.dart';
import 'services/study_notification_service.dart';
import 'services/window_workspace_service.dart';
import 'state/app_state.dart';
import 'state/connection_state.dart';
import 'state/device_preferences_state.dart';
import 'state/local_storage_state.dart';
import 'state/pending_import_state.dart';
import 'theme/app_theme.dart';
import 'theme/study_accessibility_theme.dart';
import 'widgets/global_search_palette.dart';
import 'widgets/keyboard_help_overlay.dart';
import 'widgets/privacy_mode_scope.dart';
import 'widgets/quick_content_result_handler.dart';
import 'widgets/quick_content_sheet.dart';

class SpracheApp extends ConsumerStatefulWidget {
  const SpracheApp({super.key, this.launchArguments = const []});

  final List<String> launchArguments;

  @override
  ConsumerState<SpracheApp> createState() => _SpracheAppState();
}

class _SpracheAppState extends ConsumerState<SpracheApp>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  DateTime? _lastLifecycleSyncAt;
  bool _initialRestoreScheduled = false;
  Timer? _calendarTimer;
  Timer? _themeScheduleTimer;
  Timer? _privacyCurtainTimer;
  StreamSubscription<StudyNotificationAction>? _notificationActionSubscription;
  StreamSubscription<String>? _inboundIntentSubscription;
  late final MediaLifecycleCoordinator _mediaLifecycleCoordinator;
  StudyNotificationAction? _pendingNotificationAction;
  final List<AppInboundIntent> _pendingInboundIntents = [];
  final Map<String, DateTime> _recentInboundIntents = {};
  bool _handlingNotificationAction = false;
  bool _handlingInboundIntent = false;
  final Map<String, DateTime> _recentNotificationActions = {};
  DateTime? _scheduledThemeBoundary;
  bool _privacyCurtainVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final mediaRegistry = ref.read(mediaLifecycleRegistryProvider);
    _mediaLifecycleCoordinator = MediaLifecycleCoordinator(
      persistCheckpoint: () async {
        await mediaRegistry.persistCheckpoints();
        await ref.read(appControllerProvider.notifier).flushPendingWrites();
        await ref.read(localStorageControllerProvider.notifier).flush();
      },
      stopTextToSpeech: mediaRegistry.stopTextToSpeech,
      stopSpeechRecognition: mediaRegistry.stopSpeechRecognition,
      stopRecording: mediaRegistry.stopRecording,
      stopEffects: mediaRegistry.stopEffects,
    );
    final notificationService = ref.read(studyNotificationServiceProvider);
    if (notificationService is StudyNotificationActionSource) {
      _notificationActionSubscription =
          (notificationService as StudyNotificationActionSource).actions.listen(
            _queueNotificationAction,
          );
    }
    final inboundSource = ref.read(platformInboundIntentSourceProvider);
    _inboundIntentSubscription = inboundSource.intents.listen(
      (raw) => _queueInboundIntent(raw),
    );
    for (final argument in widget.launchArguments) {
      _queueInboundIntent(argument, launchArgument: true);
    }
    unawaited(() async {
      final initialIntent = await inboundSource.initialIntent();
      if (mounted && initialIntent != null) _queueInboundIntent(initialIntent);
    }());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshCalendarDay();
    });
  }

  @override
  void dispose() {
    _calendarTimer?.cancel();
    _themeScheduleTimer?.cancel();
    _privacyCurtainTimer?.cancel();
    unawaited(_notificationActionSubscription?.cancel());
    unawaited(_inboundIntentSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _queueInboundIntent(String raw, {bool launchArgument = false}) {
    if (!mounted) return;
    const parser = InboundIntentParser();
    final parsed = launchArgument
        ? parser.parseLaunchArgument(raw)
        : parser.parse(raw);
    final intent = parsed.intent;
    if (!parsed.accepted || intent == null) return;
    final key = switch (intent) {
      SessionPlanInboundIntent(:final planId) => 'plan:$planId',
      RouteInboundIntent(:final route) => 'route:$route',
      ImportFileInboundIntent(:final uri) => 'file:$uri',
    };
    final now = ref.read(appClockProvider)();
    final previous = _recentInboundIntents[key];
    if (previous != null &&
        now.difference(previous).abs() < const Duration(seconds: 5)) {
      return;
    }
    _recentInboundIntents
      ..removeWhere(
        (_, receivedAt) =>
            now.difference(receivedAt).abs() > const Duration(minutes: 5),
      )
      ..[key] = now;
    _pendingInboundIntents.add(intent);
    _scheduleInboundIntentDrain();
  }

  void _scheduleInboundIntentDrain() {
    if (_handlingInboundIntent || _pendingInboundIntents.isEmpty) return;
    if (!ref.read(appControllerProvider).isHydrated) return;
    _handlingInboundIntent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        while (mounted && _pendingInboundIntents.isNotEmpty) {
          final intent = _pendingInboundIntents.removeAt(0);
          await _applyInboundIntent(intent);
        }
      } finally {
        _handlingInboundIntent = false;
        if (mounted && _pendingInboundIntents.isNotEmpty) {
          _scheduleInboundIntentDrain();
        }
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _applyInboundIntent(AppInboundIntent intent) async {
    final router = ref.read(appRouterProvider);
    switch (intent) {
      case RouteInboundIntent(:final route):
        router.go(route);
      case SessionPlanInboundIntent(:final planId):
        final controller = ref.read(appControllerProvider.notifier);
        final plan = ref
            .read(appControllerProvider)
            .preferences
            .savedSessionPlans
            .where((candidate) => candidate.planId == planId)
            .firstOrNull;
        if (plan != null) {
          if (controller.activeSubject.id != plan.subjectId) {
            controller.selectSubject(plan.subjectId);
          }
          controller.useSavedSessionPlan(plan);
        }
        router.go('/session-builder');
      case ImportFileInboundIntent(:final uri):
        try {
          final payload = await ref
              .read(platformInboundIntentSourceProvider)
              .readFile(uri);
          if (!mounted) return;
          ref.read(pendingImportFileProvider.notifier).state =
              PendingImportFile(name: payload.name, bytes: payload.bytes);
          router.go('/import');
        } on Object catch (error, stackTrace) {
          debugPrint('Inbound import preview rejected: $error\n$stackTrace');
        }
    }
  }

  void _queueNotificationAction(StudyNotificationAction action) {
    if (!mounted) return;
    final token =
        '${action.notificationId ?? action.planId}:${action.kind.name}:${action.planId}';
    final previous = _recentNotificationActions[token];
    if (previous != null &&
        action.receivedAt.difference(previous).abs() <
            const Duration(seconds: 5)) {
      return;
    }
    _recentNotificationActions
      ..removeWhere(
        (key, receivedAt) =>
            action.receivedAt.difference(receivedAt).abs() >
            const Duration(minutes: 5),
      )
      ..[token] = action.receivedAt;
    _pendingNotificationAction = action;
    _scheduleNotificationActionDrain();
  }

  void _scheduleNotificationActionDrain() {
    if (_handlingNotificationAction || _pendingNotificationAction == null) {
      return;
    }
    if (!ref.read(appControllerProvider).isHydrated) return;
    _handlingNotificationAction = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final action = _pendingNotificationAction;
        _pendingNotificationAction = null;
        if (!mounted || action == null) return;
        final applied = await ref
            .read(appControllerProvider.notifier)
            .applyStudyNotificationAction(action);
        if (!mounted) return;
        if (action.kind == StudyNotificationActionKind.open) {
          ref.read(appRouterProvider).go('/session-builder');
          return;
        }
        if (action.kind == StudyNotificationActionKind.start) {
          if (!applied) {
            ref.read(appRouterProvider).go('/session-builder');
            return;
          }
          final plan = ref
              .read(appControllerProvider.notifier)
              .activeSessionPlan;
          ref
              .read(appRouterProvider)
              .go(
                plan.mode == StudyMode.pronunciation
                    ? '/pronunciation?custom=true'
                    : '/study?mode=${plan.mode.name}&custom=true',
              );
        }
      } finally {
        _handlingNotificationAction = false;
        if (mounted && _pendingNotificationAction != null) {
          _scheduleNotificationActionDrain();
        }
      }
    });
    WidgetsBinding.instance.scheduleFrame();
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
        _schedulePrivacyCurtain();
        unawaited(_mediaLifecycleCoordinator.enterBackground());
        _syncForLifecycle(now);
      case AppLifecycleState.resumed:
        _mediaLifecycleCoordinator.resume();
        _privacyCurtainTimer?.cancel();
        _privacyCurtainTimer = null;
        _privacyCurtainVisible = false;
        _refreshCalendarDay();
        _scheduledThemeBoundary = null;
        if (mounted) setState(() {});
        final backgroundedAt = _backgroundedAt;
        _backgroundedAt = null;
        if (backgroundedAt != null &&
            now.difference(backgroundedAt) >= const Duration(seconds: 15)) {
          _syncForLifecycle(now);
        }
    }
  }

  void _schedulePrivacyCurtain() {
    _privacyCurtainTimer?.cancel();
    final duration = ref
        .read(devicePreferencesControllerProvider)
        .preferences
        .privacy
        .curtainDuration;
    if (duration == null) return;
    if (duration == Duration.zero) {
      if (mounted) setState(() => _privacyCurtainVisible = true);
      return;
    }
    _privacyCurtainTimer = Timer(duration, () {
      if (mounted && _backgroundedAt != null) {
        setState(() => _privacyCurtainVisible = true);
      }
    });
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

  void _scheduleThemeRefresh(AppExperiencePreferences experience) {
    final now = ref.read(appClockProvider)();
    final boundary = experience.nextThemeBoundaryAfter(now);
    if (boundary == _scheduledThemeBoundary) return;
    _themeScheduleTimer?.cancel();
    _scheduledThemeBoundary = boundary;
    if (boundary == null) return;
    final delay = boundary.difference(now) + const Duration(milliseconds: 50);
    _themeScheduleTimer = Timer(
      delay.isNegative ? const Duration(milliseconds: 50) : delay,
      () {
        _scheduledThemeBoundary = null;
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _openQuickAdd(BuildContext context) async {
    final result = await showQuickContentSheet(context: context);
    if (!mounted || !context.mounted) return;
    await handleQuickContentResult(context: context, ref: ref, result: result);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final devicePrivacy = ref.watch(
      devicePreferencesControllerProvider.select(
        (state) => state.preferences.privacy,
      ),
    );
    ref.watch(localStorageControllerProvider);
    final hydrationConnection = ref.watch(
      appControllerProvider.select(
        (state) => (state.isHydrated, state.driveConnected),
      ),
    );
    final shouldRestoreConnection =
        hydrationConnection.$1 && hydrationConnection.$2;
    if (_pendingNotificationAction != null) {
      _scheduleNotificationActionDrain();
    }
    if (_pendingInboundIntents.isNotEmpty) {
      _scheduleInboundIntentDrain();
    }
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
    final supportsWindowWorkspace =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final experienceSelection = ref.watch(
      appControllerProvider.select(
        (state) => (state.preferences.experience, state.activeSubjectId),
      ),
    );
    final baseExperience = experienceSelection.$1;
    final subjectPalette = baseExperience.perSubjectAccentEnabled
        ? baseExperience.accentPaletteBySubject[experienceSelection.$2]
        : null;
    final subjectExperience = subjectPalette == null
        ? baseExperience
        : baseExperience.copyWith(
            accentPalette: subjectPalette,
            separateBrightnessAccents: false,
            customAccentEnabled: false,
          );
    _scheduleThemeRefresh(subjectExperience);
    final effectiveColorMode = subjectExperience.colorModeAt(
      ref.read(appClockProvider)(),
    );
    final experience = effectiveColorMode == subjectExperience.colorMode
        ? subjectExperience
        : subjectExperience.copyWith(colorMode: effectiveColorMode);
    final accessibilityProfile = ref.watch(accessibilityInputProfileProvider);
    final reduceMotion =
        experience.effectiveReduceMotion || accessibilityProfile.reduceMotion;
    final effectiveAccessibilityProfile = accessibilityProfile.copyWith(
      highContrast:
          accessibilityProfile.highContrast || experience.highContrast,
      reduceMotion: reduceMotion,
    );
    final lightTheme = usesMobileTheme
        ? AppTheme.mobileFor(
            experience,
            brightness: Brightness.light,
            accessibilityProfile: effectiveAccessibilityProfile,
          )
        : AppTheme.desktopFor(
            experience,
            brightness: Brightness.light,
            accessibilityProfile: effectiveAccessibilityProfile,
          );
    final darkTheme = usesMobileTheme
        ? AppTheme.mobileFor(
            experience,
            brightness: Brightness.dark,
            accessibilityProfile: effectiveAccessibilityProfile,
          )
        : AppTheme.desktopFor(
            experience,
            brightness: Brightness.dark,
            accessibilityProfile: effectiveAccessibilityProfile,
          );

    return MaterialApp.router(
      title: 'Sprache',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: switch (experience.colorMode) {
        AppColorMode.system => ThemeMode.system,
        AppColorMode.light => ThemeMode.light,
        AppColorMode.dark || AppColorMode.oled => ThemeMode.dark,
      },
      themeAnimationDuration: reduceMotion
          ? Duration.zero
          : experience.motionLevel == AppMotionLevel.reduced
          ? const Duration(milliseconds: 90)
          : const Duration(milliseconds: 180),
      routerConfig: router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final preferredScale = switch (experience.textScale) {
          AppTextScale.system => null,
          AppTextScale.small => 0.9,
          AppTextScale.medium => 1.0,
          AppTextScale.large => 1.2,
          AppTextScale.extraLarge => 1.4,
        };
        Widget scaledChild = MediaQuery(
          data: mediaQuery.copyWith(
            disableAnimations: mediaQuery.disableAnimations || reduceMotion,
            highContrast:
                mediaQuery.highContrast ||
                effectiveAccessibilityProfile.highContrast,
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
        if (devicePrivacy.privacyMode) {
          scaledChild = _PrivacyModeFrame(child: scaledChild);
        }
        if (_privacyCurtainVisible) {
          scaledChild = Stack(
            fit: StackFit.expand,
            children: [scaledChild, const _PrivacyCurtain()],
          );
        }
        final globalBindings = effectiveAccessibilityProfile.globalBindingsFor({
          GlobalShortcutAction.openSearch: () =>
              unawaited(showGlobalSearchPalette(context, ref)),
          GlobalShortcutAction.quickAdd: () =>
              unawaited(_openQuickAdd(context)),
          GlobalShortcutAction.keyboardHelp: () => unawaited(
            showKeyboardHelpOverlay(
              context: context,
              profile: effectiveAccessibilityProfile,
              helpContext: keyboardHelpContextForLocation(
                router.routeInformationProvider.value.uri.path,
              ),
            ),
          ),
          if (supportsWindowWorkspace)
            GlobalShortcutAction.toggleCompactWindow: () => unawaited(
              ref
                  .read(windowWorkspaceControllerProvider.notifier)
                  .toggleCompact(),
            ),
          if (supportsWindowWorkspace)
            GlobalShortcutAction.minimizeWindow: () => unawaited(
              ref.read(windowWorkspaceControllerProvider.notifier).minimize(),
            ),
        });
        return CallbackShortcuts(
          key: const Key('app-global-shortcuts'),
          bindings: globalBindings,
          child: Focus(autofocus: true, child: scaledChild),
        );
      },
    );
  }
}

class _PrivacyModeFrame extends StatelessWidget {
  const _PrivacyModeFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PrivacyModeScope(
      enabled: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            top: MediaQuery.paddingOf(context).top + 4,
            right: 10,
            child: IgnorePointer(
              child: Semantics(
                label: '사생활 보호 모드 사용 중',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.inverseSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 15,
                          color: Theme.of(context).colorScheme.onInverseSurface,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '보호 모드',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCurtain extends StatelessWidget {
  const _PrivacyCurtain();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const Key('privacy-curtain'),
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Semantics(
          label: 'Sprache 내용이 보호되었습니다',
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded, size: 52),
              SizedBox(height: 12),
              Text(
                'Sprache 보호 중',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 5),
              Text('앱으로 돌아오면 내용이 다시 표시됩니다.'),
            ],
          ),
        ),
      ),
    );
  }
}
