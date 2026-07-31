import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/services/study_notification_service.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('settings can reconnect all future study notifications', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    final now = DateTime.now().toUtc();
    final notifications = _RecordingNotificationService();
    final store = MemoryStudyStore(
      preferences: StudyPreferences(
        onboardingCompleted: true,
        savedSessionPlans: [
          StudySessionPlan(
            planId: 'settings-alert',
            title: '저녁 복습',
            scheduledAt: now.add(const Duration(hours: 2)),
            updatedAt: now,
          ),
        ],
      ),
    );

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(store),
            studyNotificationServiceProvider.overrideWithValue(notifications),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home-settings')));
      await tester.pumpAndSettle();

      expect(find.text('학습 일정 알림'), findsOneWidget);
      expect(find.text('미래 일정 1개를 Android 알림으로 관리합니다.'), findsOneWidget);

      final button = find.byKey(
        const Key('study-notification-configure-button'),
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(notifications.permissionRequests, 1);
      expect(
        notifications.reconciledPlans.last.single.planId,
        'settings-alert',
      );
      expect(find.textContaining('미래 일정 1개의 알림'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}

class _RecordingNotificationService implements StudyNotificationService {
  final reconciledPlans = <List<StudySessionPlan>>[];
  var permissionRequests = 0;

  @override
  Future<StudyNotificationPermission> requestPermission() async {
    permissionRequests += 1;
    return StudyNotificationPermission.granted;
  }

  @override
  Future<StudyNotificationReconcileResult> reconcile(
    Iterable<StudySessionPlan> plans, {
    DateTime? now,
  }) async {
    final copied = plans.toList(growable: false);
    reconciledPlans.add(copied);
    return StudyNotificationReconcileResult(
      available: true,
      scheduledCount: buildStudyNotificationSpecs(
        copied,
        now: now ?? DateTime.now(),
      ).length,
    );
  }
}
