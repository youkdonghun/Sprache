import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/backup/study_summary_exporter.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_insights.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_preferences.dart';

void main() {
  final now = DateTime.utc(2026, 8, 2, 12);

  test('builds bounded calendar, trends, skills and subject comparison', () {
    final insights = LearningInsights.build(
      sessions: [
        _session(
          id: 'a',
          course: 'course-lang-en',
          start: DateTime.utc(2026, 8, 1, 10),
          minutes: 12,
          correct: 8,
          wrong: 2,
          xp: 18,
          mode: StudyMode.production,
        ),
        _session(
          id: 'b',
          course: 'course-lang-ja',
          start: DateTime.utc(2026, 8, 2, 9),
          minutes: 8,
          correct: 5,
          wrong: 5,
          xp: 12,
          mode: StudyMode.listening,
        ),
        _session(
          id: 'old',
          course: 'course-lang-en',
          start: DateTime.utc(2026, 7, 1),
          minutes: 5,
          correct: 1,
          wrong: 0,
          xp: 1,
          mode: StudyMode.mixed,
        ),
      ],
      items: const [],
      progress: const {},
      now: now,
      range: LearningInsightRange.sevenDays,
    );

    expect(insights.days, hasLength(7));
    expect(insights.sessionCount, 2);
    expect(insights.earnedXp, 30);
    expect(insights.duration, const Duration(minutes: 20));
    expect(insights.accuracy, closeTo(0.65, 0.001));
    expect(insights.skills.map((value) => value.skill), ['듣기', '쓰기']);
    expect(insights.subjects, hasLength(2));
    expect(insights.studiedDaysInLastSeven(), 2);
    expect(insights.weeklySessionGoalProgress(4), 0.5);
    expect(insights.durationInLastSeven(), const Duration(minutes: 20));
    expect(insights.weeklyDurationGoalProgress(40), 0.5);
    expect(
      insights.weeklyCombinedGoalProgress(targetDays: 4, targetMinutes: 80),
      0.25,
    );
  });

  test('ranks hard items with an explicit reason and last study date', () {
    final items = [
      _word('one', 'one'),
      _word('two', 'two'),
      _word('easy', 'easy'),
    ];
    final insights = LearningInsights.build(
      sessions: const [],
      items: items,
      progress: {
        'one': ProgressRecord(
          itemId: 'one',
          correctCount: 1,
          wrongCount: 4,
          lastResult: ReviewRating.again,
          lastStudiedAt: now,
        ),
        'two': const ProgressRecord(
          itemId: 'two',
          correctCount: 1,
          wrongCount: 1,
          lastResult: ReviewRating.hard,
        ),
        'easy': const ProgressRecord(
          itemId: 'easy',
          correctCount: 9,
          wrongCount: 1,
        ),
      },
      now: now,
      range: LearningInsightRange.all,
    );

    expect(insights.hardestItems.map((value) => value.itemId), ['one', 'two']);
    expect(insights.hardestItems.first.reason, '최근 답을 놓쳤어요');
    expect(insights.hardestItems.first.lastStudiedAt, now);
  });

  test('reports recent skill change and subject review volume', () {
    final insights = LearningInsights.build(
      sessions: [
        _session(
          id: 'earlier-writing',
          course: 'course-lang-en',
          start: DateTime.utc(2026, 8, 1, 10),
          minutes: 5,
          correct: 1,
          wrong: 3,
          xp: 5,
          mode: StudyMode.production,
        ),
        _session(
          id: 'recent-writing',
          course: 'course-lang-en',
          start: DateTime.utc(2026, 8, 2, 10),
          minutes: 5,
          correct: 3,
          wrong: 1,
          xp: 8,
          mode: StudyMode.production,
        ),
        _session(
          id: 'review',
          course: 'course-lang-en',
          start: DateTime.utc(2026, 8, 2, 11),
          minutes: 4,
          correct: 2,
          wrong: 0,
          xp: 4,
          mode: StudyMode.review,
        ),
      ],
      items: const [],
      progress: const {},
      now: now,
      range: LearningInsightRange.sevenDays,
    );

    final writing = insights.skills.singleWhere((value) => value.skill == '쓰기');
    expect(writing.recentAccuracyChange, closeTo(0.5, 0.001));
    expect(insights.subjects.single.reviewSessionCount, 1);
  });

  test('privacy-safe CSV contains metrics but never learning text', () {
    final secret = _word('secret-id', 'private expression');
    final insights = LearningInsights.build(
      sessions: [
        _session(
          id: 'csv',
          course: 'course-lang-en',
          start: DateTime.utc(2026, 8, 2, 10),
          minutes: 6,
          correct: 3,
          wrong: 1,
          xp: 7,
          mode: StudyMode.meaning,
        ),
      ],
      items: [secret],
      progress: const {
        'secret-id': ProgressRecord(
          itemId: 'secret-id',
          correctCount: 0,
          wrongCount: 2,
        ),
      },
      now: now,
      range: LearningInsightRange.sevenDays,
    );

    final csv = const StudySummaryExporter().exportCsv(insights);
    expect(csv, contains('date,sessions,minutes,xp'));
    expect(csv, contains('2026-08-02,1,6,7,3,1,4,75.0'));
    expect(csv, isNot(contains('private expression')));
    expect(csv, isNot(contains('secret-id')));
  });
}

StudySessionSummary _session({
  required String id,
  required String course,
  required DateTime start,
  required int minutes,
  required int correct,
  required int wrong,
  required int xp,
  required StudyMode mode,
}) => StudySessionSummary(
  sessionId: id,
  courseId: course,
  startedAt: start,
  endedAt: start.add(Duration(minutes: minutes)),
  correctCount: correct,
  wrongCount: wrong,
  earnedXp: xp,
  mode: mode,
);

LearningItem _word(String id, String text) => LearningItem(
  id: id,
  kind: LearningItemKind.word,
  learningLanguage: LanguageTag.english,
  subjectId: 'lang-en',
  text: text,
  translations: const ['뜻'],
  acceptedAnswers: const ['뜻'],
  capabilities: const {ExerciseCapability.recognition},
  source: ContentSource.userCreated,
);
