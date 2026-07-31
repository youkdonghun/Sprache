import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/services/study_notification_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native platform registers and cancels a scheduled alert', (
    tester,
  ) async {
    final platform = defaultTargetPlatform;
    expect(
      platform,
      anyOf(TargetPlatform.android, TargetPlatform.windows),
    );
    final plugin = FlutterLocalNotificationsPlugin();
    final service = FlutterStudyNotificationService(
      plugin: plugin,
      platform: platform,
    );
    final now = DateTime.now().toUtc();
    final result = await service.reconcile([
      StudySessionPlan(
        planId: 'windows-native-notification-smoke',
        title: 'Sprache 알림 실기기 검사',
        scheduledAt: now.add(const Duration(minutes: 2)),
        updatedAt: now,
      ),
    ], now: now);
    addTearDown(() async {
      if (platform == TargetPlatform.windows) {
        await plugin.cancelAll();
      } else {
        await plugin.cancelAllPendingNotifications();
      }
    });

    expect(result.available, isTrue, reason: result.error);
    expect(result.scheduledCount, 1);
    final pending = await plugin.pendingNotificationRequests();
    final expectedId = buildStudyNotificationSpecs(
      [
        StudySessionPlan(
          planId: 'windows-native-notification-smoke',
          scheduledAt: now.add(const Duration(minutes: 2)),
        ),
      ],
      now: now,
    ).single.id;
    expect(
      pending.map((notification) => notification.id),
      contains(expectedId),
    );
  });
}
