import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/study_preferences.dart';

enum StudyNotificationPermission { granted, denied, unavailable }

class StudyNotificationSpec {
  const StudyNotificationSpec({
    required this.id,
    required this.planId,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.payload,
  });

  final int id;
  final String planId;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String payload;
}

class StudyNotificationReconcileResult {
  const StudyNotificationReconcileResult({
    required this.available,
    required this.scheduledCount,
    this.error,
  });

  final bool available;
  final int scheduledCount;
  final String? error;
}

class StudyNotificationSetupResult {
  const StudyNotificationSetupResult({
    required this.permission,
    required this.reconcileResult,
  });

  final StudyNotificationPermission permission;
  final StudyNotificationReconcileResult reconcileResult;
}

abstract class StudyNotificationService {
  Future<StudyNotificationPermission> requestPermission();

  Future<StudyNotificationReconcileResult> reconcile(
    Iterable<StudySessionPlan> plans, {
    DateTime? now,
  });
}

class DisabledStudyNotificationService implements StudyNotificationService {
  const DisabledStudyNotificationService();

  @override
  Future<StudyNotificationPermission> requestPermission() async =>
      StudyNotificationPermission.unavailable;

  @override
  Future<StudyNotificationReconcileResult> reconcile(
    Iterable<StudySessionPlan> plans, {
    DateTime? now,
  }) async {
    return const StudyNotificationReconcileResult(
      available: false,
      scheduledCount: 0,
    );
  }
}

List<StudyNotificationSpec> buildStudyNotificationSpecs(
  Iterable<StudySessionPlan> plans, {
  required DateTime now,
}) {
  final currentById = <String, StudySessionPlan>{};
  for (final plan in plans) {
    final planId = plan.planId.trim();
    final scheduledAt = plan.scheduledAt?.toUtc();
    if (planId.isEmpty ||
        scheduledAt == null ||
        !scheduledAt.isAfter(now.toUtc())) {
      continue;
    }
    final current = currentById[planId];
    final currentChangedAt =
        current?.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final incomingChangedAt =
        plan.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (current == null || !incomingChangedAt.isBefore(currentChangedAt)) {
      currentById[planId] = plan;
    }
  }

  final scheduledPlans = currentById.values.toList()
    ..sort((left, right) {
      final scheduleOrder = left.scheduledAt!.compareTo(right.scheduledAt!);
      if (scheduleOrder != 0) return scheduleOrder;
      return left.planId.compareTo(right.planId);
    });
  final usedIds = <int>{};
  return [
    for (final plan in scheduledPlans.take(20))
      _notificationSpecFor(plan, usedIds),
  ];
}

StudyNotificationSpec _notificationSpecFor(
  StudySessionPlan plan,
  Set<int> usedIds,
) {
  var notificationId = _stableNotificationId(plan.planId);
  while (!usedIds.add(notificationId)) {
    notificationId = notificationId == 0x7fffffff ? 1 : notificationId + 1;
  }
  final title = plan.title.trim().isEmpty ? '학습할 시간이에요' : plan.title.trim();
  return StudyNotificationSpec(
    id: notificationId,
    planId: plan.planId,
    title: title,
    body: '${plan.mode.label} · ${plan.itemLimit}개 표현을 시작해요.',
    scheduledAt: plan.scheduledAt!.toUtc(),
    payload: 'session-plan/${Uri.encodeComponent(plan.planId)}',
  );
}

int _stableNotificationId(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

class FlutterStudyNotificationService implements StudyNotificationService {
  FlutterStudyNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    TargetPlatform? platform,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _platform = platform ?? defaultTargetPlatform;

  static const _channelId = 'sprache_study_schedule';
  static const _channelName = '학습 일정';
  static const _channelDescription = '사용자가 저장한 학습 시작 시간을 알려줍니다.';

  final FlutterLocalNotificationsPlugin _plugin;
  final TargetPlatform _platform;
  Future<bool>? _initialization;
  Future<void> _serialOperation = Future.value();

  Future<bool> _ensureInitialized() {
    return _initialization ??= _initialize();
  }

  Future<bool> _initialize() async {
    if (kIsWeb ||
        (_platform != TargetPlatform.android &&
            _platform != TargetPlatform.windows)) {
      return false;
    }
    try {
      tz_data.initializeTimeZones();
      try {
        final localTimezone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
      } on Object {
        tz.setLocalLocation(tz.UTC);
      }
      final initialized = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_sprache'),
          windows: WindowsInitializationSettings(
            appName: 'Sprache',
            appUserModelId: 'Youkdonghun.Sprache.Study',
            guid: '0f1af001-eeda-4d84-b2d8-c8aa9368371c',
          ),
        ),
      );
      return initialized == true;
    } on Object {
      return false;
    }
  }

  @override
  Future<StudyNotificationPermission> requestPermission() async {
    if (!await _ensureInitialized()) {
      return StudyNotificationPermission.unavailable;
    }
    if (_platform == TargetPlatform.windows) {
      return StudyNotificationPermission.granted;
    }
    if (_platform != TargetPlatform.android) {
      return StudyNotificationPermission.unavailable;
    }
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final allowed = await android?.requestNotificationsPermission();
      return allowed == true
          ? StudyNotificationPermission.granted
          : StudyNotificationPermission.denied;
    } on Object catch (error, stackTrace) {
      debugPrint('Study notification permission request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return StudyNotificationPermission.unavailable;
    }
  }

  @override
  Future<StudyNotificationReconcileResult> reconcile(
    Iterable<StudySessionPlan> plans, {
    DateTime? now,
  }) {
    final copiedPlans = plans.toList(growable: false);
    final completer = Completer<StudyNotificationReconcileResult>();
    _serialOperation = _serialOperation.then((_) async {
      final result = await _reconcile(copiedPlans, now: now ?? DateTime.now());
      completer.complete(result);
    });
    return completer.future;
  }

  Future<StudyNotificationReconcileResult> _reconcile(
    List<StudySessionPlan> plans, {
    required DateTime now,
  }) async {
    if (!await _ensureInitialized()) {
      return const StudyNotificationReconcileResult(
        available: false,
        scheduledCount: 0,
      );
    }
    final specs = buildStudyNotificationSpecs(plans, now: now);
    try {
      if (_platform == TargetPlatform.windows) {
        await _plugin.cancelAll();
      } else {
        await _plugin.cancelAllPendingNotifications();
      }
      for (final spec in specs) {
        await _plugin.zonedSchedule(
          id: spec.id,
          title: spec.title,
          body: spec.body,
          scheduledDate: tz.TZDateTime.from(spec.scheduledAt, tz.local),
          notificationDetails: NotificationDetails(
            android: const AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.high,
              priority: Priority.high,
            ),
            windows: WindowsNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: spec.payload,
        );
      }
      return StudyNotificationReconcileResult(
        available: true,
        scheduledCount: specs.length,
      );
    } on Object catch (error, stackTrace) {
      debugPrint('Study notification reconciliation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return StudyNotificationReconcileResult(
        available: false,
        scheduledCount: 0,
        error: error.toString(),
      );
    }
  }
}

final studyNotificationServiceProvider = Provider<StudyNotificationService>(
  (ref) => FlutterStudyNotificationService(),
);
