import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/study_preferences.dart';

void main() {
  test('active session survives a JSON round trip', () {
    final startedAt = DateTime.utc(2026, 7, 27, 9);
    final session = ActiveStudySession(
      sessionId: 'session-1',
      courseId: 'ko-en',
      mode: StudyMode.meaning,
      unitIndex: 2,
      itemIds: const ['a', 'b', 'c'],
      currentIndex: 1,
      correctCount: 1,
      wrongCount: 0,
      earnedXp: 10,
      startedAt: startedAt,
      updatedAt: startedAt.add(const Duration(minutes: 2)),
    );

    final restored = ActiveStudySession.fromJson(session.toJson());

    expect(restored.sessionId, 'session-1');
    expect(restored.mode, StudyMode.meaning);
    expect(restored.unitIndex, 2);
    expect(restored.itemIds, ['a', 'b', 'c']);
    expect(restored.currentIndex, 1);
    expect(restored.remainingCount, 2);
    expect(restored.progress, closeTo(1 / 3, 0.001));
    expect(restored.earnedXp, 10);
  });

  test('active session rejects missing identity and item data', () {
    expect(() => ActiveStudySession.fromJson(const {}), throwsFormatException);
  });

  test('restored active session clamps unsafe persisted counters', () {
    final restored = ActiveStudySession.fromJson({
      'sessionId': 'session-2',
      'courseId': 'ko-ja',
      'mode': 'unknown',
      'itemIds': ['a', 'b'],
      'currentIndex': 99,
      'correctCount': -1,
      'wrongCount': -10,
      'earnedXp': -5,
      'startedAt': '2026-07-27T09:00:00Z',
      'updatedAt': '2026-07-27T09:02:00Z',
    });

    expect(restored.mode, StudyMode.mixed);
    expect(restored.currentIndex, 2);
    expect(restored.correctCount, 0);
    expect(restored.wrongCount, 0);
    expect(restored.earnedXp, 0);
  });

  test('pause, resume, and derived sessions preserve a bounded lineage', () {
    final startedAt = DateTime.utc(2026, 7, 28, 9);
    final started = ActiveStudySession.started(
      sessionId: 'root-session',
      courseId: 'ko-en',
      mode: StudyMode.mixed,
      unitIndex: 1,
      itemIds: const ['a', 'b', 'c'],
      startedAt: startedAt,
    );
    final paused = started.pause(startedAt.add(const Duration(minutes: 2)));
    final resumed = paused.resume(startedAt.add(const Duration(minutes: 5)));
    final branched = resumed.derive(
      newSessionId: 'branch-session',
      nextOrigin: StudySessionOrigin.remaining,
      selectedItemIds: const ['b', 'c'],
      startedAt: startedAt.add(const Duration(minutes: 6)),
    );
    final restored = ActiveStudySession.fromJson(branched.toJson());

    expect(paused.phase, ActiveStudySessionPhase.paused);
    expect(resumed.phase, ActiveStudySessionPhase.active);
    expect(restored.rootSessionId, 'root-session');
    expect(restored.parentSessionId, 'root-session');
    expect(restored.origin, StudySessionOrigin.remaining);
    expect(restored.generation, 1);
    expect(restored.pauseCount, 1);
    expect(restored.resumeCount, 1);
    expect(restored.journey.map((event) => event.action), [
      StudySessionJourneyAction.started,
      StudySessionJourneyAction.paused,
      StudySessionJourneyAction.resumed,
      StudySessionJourneyAction.branchedRemaining,
    ]);
  });

  test('repeated lifecycle actions remain unique at the same clock value', () {
    final at = DateTime.utc(2026, 7, 28, 12);
    final session = ActiveStudySession.started(
      sessionId: 'same-clock-session',
      courseId: 'ko-en',
      mode: StudyMode.meaning,
      unitIndex: null,
      itemIds: const ['item-1'],
      startedAt: at,
    ).pause(at).resume(at).pause(at).resume(at);

    expect(
      session.journey.map((event) => event.eventId).toSet(),
      hasLength(session.journey.length),
    );
    expect(ActiveStudySession.fromJson(session.toJson()).journey, hasLength(5));
  });

  test(
    'active session preserves repeated queue entries and prior mistakes',
    () {
      final startedAt = DateTime.utc(2026, 7, 28, 10);
      final session =
          ActiveStudySession.started(
            sessionId: 'repeat-session',
            courseId: 'ko-en',
            mode: StudyMode.meaning,
            unitIndex: null,
            itemIds: const ['a', 'b'],
            startedAt: startedAt,
          ).copyWith(
            itemIds: const ['a', 'b', 'a'],
            wrongItemIds: const {'a'},
            currentIndex: 2,
            wrongCount: 1,
            updatedAt: startedAt.add(const Duration(minutes: 1)),
          );

      final restored = ActiveStudySession.fromJson(session.toJson());

      expect(restored.itemIds, ['a', 'b', 'a']);
      expect(restored.originalItemIds, ['a', 'b']);
      expect(restored.wrongItemIds, {'a'});
    },
  );

  test('rejects unknown lifecycle enum and duplicate journey event IDs', () {
    final startedAt = DateTime.utc(2026, 7, 28, 11);
    final session = ActiveStudySession.started(
      sessionId: 'invalid-session',
      courseId: 'ko-en',
      mode: StudyMode.mixed,
      unitIndex: null,
      itemIds: const ['a'],
      startedAt: startedAt,
    ).toJson();

    expect(
      () => ActiveStudySession.fromJson({...session, 'phase': 'sleeping'}),
      throwsFormatException,
    );
    final journey = session['journey']! as List<Object?>;
    expect(
      () => ActiveStudySession.fromJson({
        ...session,
        'journey': [...journey, journey.single],
      }),
      throwsFormatException,
    );
  });
}
