import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/quiz_session_support.dart';
import 'package:sprache/src/domain/study_limits.dart';
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
      initialItemIds: const ['a', 'b', 'c'],
      finalCorrectItemIds: const {'a'},
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
    expect(restored.finalCorrectItemIds, {'a'});
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
            finalCorrectItemIds: const {'b'},
            currentIndex: 2,
            wrongCount: 1,
            updatedAt: startedAt.add(const Duration(minutes: 1)),
          );

      final restored = ActiveStudySession.fromJson(session.toJson());

      expect(restored.itemIds, ['a', 'b', 'a']);
      expect(restored.originalItemIds, ['a', 'b']);
      expect(restored.wrongItemIds, {'a'});
      expect(restored.finalCorrectItemIds, {'b'});
      expect(restored.unresolvedWrongItemIds, {'a'});
    },
  );

  test('supports 1000 initial items and 3000 retry queue entries', () {
    final startedAt = DateTime.utc(2026, 7, 28, 13);
    final initial = [
      for (var index = 0; index < StudyLimits.maxSessionItems; index++)
        'item-$index',
    ];
    final queue = [...initial, ...initial, ...initial];
    final session =
        ActiveStudySession.started(
          sessionId: 'thousand-session',
          courseId: 'ko-en',
          mode: StudyMode.mixed,
          unitIndex: null,
          itemIds: initial,
          startedAt: startedAt,
        ).copyWith(
          itemIds: queue,
          currentIndex: StudyLimits.maxSessionItems + 500,
          wrongItemIds: initial.take(10).toSet(),
          finalCorrectItemIds: initial.skip(10).take(20).toSet(),
        );

    final paused = session.pause(startedAt.add(const Duration(minutes: 1)));
    final restored = ActiveStudySession.fromJson(paused.toJson());

    expect(restored.itemIds, hasLength(StudyLimits.maxActiveQueueEntries));
    expect(restored.initialItemIds, hasLength(StudyLimits.maxSessionItems));
    expect(restored.journey.last.itemCount, StudyLimits.maxSessionItems);

    expect(
      () => ActiveStudySession.fromJson({
        ...paused.toJson(),
        'itemIds': [...queue, 'overflow'],
      }),
      throwsFormatException,
    );
  });

  test('started sessions require at most 1000 unique initial items', () {
    final startedAt = DateTime.utc(2026, 7, 28, 14);
    expect(
      () => ActiveStudySession.started(
        sessionId: 'duplicates',
        courseId: 'ko-en',
        mode: StudyMode.mixed,
        unitIndex: null,
        itemIds: const ['a', 'a'],
        startedAt: startedAt,
      ),
      throwsArgumentError,
    );
    expect(
      () => ActiveStudySession.started(
        sessionId: 'too-many',
        courseId: 'ko-en',
        mode: StudyMode.mixed,
        unitIndex: null,
        itemIds: [
          for (var index = 0; index <= StudyLimits.maxSessionItems; index++)
            'item-$index',
        ],
        startedAt: startedAt,
      ),
      throwsArgumentError,
    );
  });

  test('exam attempt reviews survive resume and reset on derived sessions', () {
    final startedAt = DateTime.utc(2026, 8, 3, 9);
    final review = QuizAttemptReview(
      sequence: 1,
      itemId: 'a',
      prompt: 'alpha',
      expectedAnswer: '알파',
      userAnswer: '알파',
      exerciseType: 'recognition',
      correct: true,
      rating: ReviewRating.good,
      usedHint: false,
    );
    final session = ActiveStudySession.started(
      sessionId: 'exam-review-session',
      courseId: 'ko-en',
      mode: StudyMode.meaning,
      unitIndex: null,
      itemIds: const ['a', 'b'],
      startedAt: startedAt,
    ).copyWith(attemptReviews: [review]);

    final restored = ActiveStudySession.fromJson(session.toJson());
    final derived = restored.derive(
      newSessionId: 'derived-session',
      nextOrigin: StudySessionOrigin.restarted,
      selectedItemIds: const ['a', 'b'],
      startedAt: startedAt.add(const Duration(minutes: 1)),
    );

    expect(restored.attemptReviews, hasLength(1));
    expect(restored.attemptReviews.single.prompt, 'alpha');
    expect(restored.attemptReviews.single.rating, ReviewRating.good);
    expect(derived.attemptReviews, isEmpty);
    expect(derived.attemptMetrics, isEmpty);
  });

  test('active session rejects unsafe or unknown attempt reviews', () {
    final session = ActiveStudySession.started(
      sessionId: 'invalid-review-session',
      courseId: 'ko-en',
      mode: StudyMode.meaning,
      unitIndex: null,
      itemIds: const ['a'],
      startedAt: DateTime.utc(2026, 8, 3, 9),
    ).toJson();
    final review = QuizAttemptReview(
      sequence: 1,
      itemId: 'missing',
      prompt: 'alpha',
      expectedAnswer: '알파',
      userAnswer: '',
      exerciseType: 'recognition:gaveUp',
      correct: false,
      rating: ReviewRating.again,
      usedHint: false,
    ).toJson();

    expect(
      () => ActiveStudySession.fromJson({
        ...session,
        'attemptReviews': [review],
      }),
      throwsFormatException,
    );
    expect(
      () => ActiveStudySession.fromJson({
        ...session,
        'attemptReviews': [
          {...review, 'itemId': 'a', 'rating': 'perfect'},
        ],
      }),
      throwsFormatException,
    );
  });

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
