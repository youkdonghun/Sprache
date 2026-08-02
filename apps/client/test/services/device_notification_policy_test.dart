import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/device_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/services/study_notification_service.dart';

void main() {
  final plan = StudySessionPlan(
    planId: 'private-plan',
    title: '비밀 단어 복습',
    subjectId: 'language:en',
    scheduledAt: DateTime(2026, 8, 2, 23),
  );

  test('quiet time defers notification and hidden mode redacts details', () {
    final specs = buildStudyNotificationSpecs(
      [plan],
      now: DateTime(2026, 8, 2, 20),
      preferences: const DeviceNotificationPreferences(
        quietStartMinutes: 22 * 60,
        quietEndMinutes: 7 * 60,
        lockScreenContent: NotificationLockScreenContent.hidden,
      ),
    );

    expect(specs.single.scheduledAt.toLocal(), DateTime(2026, 8, 3, 7));
    expect(specs.single.title, 'Sprache');
    expect(specs.single.body, isNot(contains('비밀')));
    expect(specs.single.payload, contains('private-plan'));
  });

  test('disabled device notifications produce no schedules', () {
    expect(
      buildStudyNotificationSpecs(
        [plan],
        now: DateTime(2026, 8, 2, 20),
        preferences: const DeviceNotificationPreferences(enabled: false),
      ),
      isEmpty,
    );
  });

  test('notification taps and snooze actions decode a safe exact plan', () {
    final receivedAt = DateTime.utc(2026, 8, 2, 10);
    final open = parseStudyNotificationAction(
      actionId: '',
      payload: 'session-plan/private-plan',
      receivedAt: receivedAt,
      notificationId: 31,
    );
    final snooze = parseStudyNotificationAction(
      actionId: 'snooze-30',
      payload: 'session-plan/private-plan',
      receivedAt: receivedAt,
    );

    expect(open?.kind, StudyNotificationActionKind.open);
    expect(open?.planId, 'private-plan');
    expect(open?.notificationId, 31);
    expect(snooze?.kind, StudyNotificationActionKind.snooze30);
  });

  test('notification action parser rejects unknown or unsafe payloads', () {
    final now = DateTime.utc(2026, 8, 2);
    expect(
      parseStudyNotificationAction(
        actionId: 'delete',
        payload: 'session-plan/private-plan',
        receivedAt: now,
      ),
      isNull,
    );
    expect(
      parseStudyNotificationAction(
        actionId: 'start',
        payload: 'session-plan/..%2Fsecret',
        receivedAt: now,
      ),
      isNull,
    );
    expect(
      parseStudyNotificationAction(
        actionId: 'start',
        payload: 'settings/notifications',
        receivedAt: now,
      ),
      isNull,
    );
  });
}
