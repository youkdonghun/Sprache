import 'learning_item.dart';
import 'progress.dart';
import 'study_history.dart';
import 'study_preferences.dart';
import 'study_subject.dart';

enum LearningInsightRange { sevenDays, thirtyDays, ninetyDays, all }

extension LearningInsightRangeLabel on LearningInsightRange {
  String get label => switch (this) {
    LearningInsightRange.sevenDays => '7일',
    LearningInsightRange.thirtyDays => '30일',
    LearningInsightRange.ninetyDays => '90일',
    LearningInsightRange.all => '전체',
  };

  int? get dayCount => switch (this) {
    LearningInsightRange.sevenDays => 7,
    LearningInsightRange.thirtyDays => 30,
    LearningInsightRange.ninetyDays => 90,
    LearningInsightRange.all => null,
  };
}

class LearningInsightDay {
  const LearningInsightDay({
    required this.date,
    required this.sessionCount,
    required this.correctCount,
    required this.wrongCount,
    required this.earnedXp,
    required this.duration,
  });

  final DateTime date;
  final int sessionCount;
  final int correctCount;
  final int wrongCount;
  final int earnedXp;
  final Duration duration;

  int get attempts => correctCount + wrongCount;
  double? get accuracy => attempts == 0 ? null : correctCount / attempts;
  bool get studied => sessionCount > 0;

  int intensityFor({required int dailyGoal}) {
    if (!studied) return 0;
    if (dailyGoal <= 0) return earnedXp > 0 ? 2 : 1;
    final ratio = earnedXp / dailyGoal;
    if (ratio >= 1.5) return 4;
    if (ratio >= 1) return 3;
    if (ratio >= 0.5) return 2;
    return 1;
  }
}

class SkillLearningInsight {
  const SkillLearningInsight({
    required this.skill,
    required this.sessionCount,
    required this.correctCount,
    required this.wrongCount,
    required this.recentAccuracyChange,
  });

  final String skill;
  final int sessionCount;
  final int correctCount;
  final int wrongCount;
  final double? recentAccuracyChange;

  int get attempts => correctCount + wrongCount;
  double? get accuracy => attempts == 0 ? null : correctCount / attempts;
}

class SubjectLearningInsight {
  const SubjectLearningInsight({
    required this.courseId,
    required this.sessionCount,
    required this.earnedXp,
    required this.correctCount,
    required this.wrongCount,
    required this.duration,
    required this.reviewSessionCount,
  });

  final String courseId;
  final int sessionCount;
  final int earnedXp;
  final int correctCount;
  final int wrongCount;
  final Duration duration;
  final int reviewSessionCount;

  int get attempts => correctCount + wrongCount;
  double? get accuracy => attempts == 0 ? null : correctCount / attempts;
}

class HardestLearningItem {
  const HardestLearningItem({
    required this.itemId,
    required this.text,
    required this.correctCount,
    required this.wrongCount,
    required this.lastStudiedAt,
    required this.reason,
  });

  final String itemId;
  final String text;
  final int correctCount;
  final int wrongCount;
  final DateTime? lastStudiedAt;
  final String reason;

  int get attempts => correctCount + wrongCount;
  double get accuracy => attempts == 0 ? 0 : correctCount / attempts;
}

class LearningInsights {
  const LearningInsights({
    required this.range,
    required this.startedAt,
    required this.endedAt,
    required this.days,
    required this.skills,
    required this.subjects,
    required this.hardestItems,
  });

  factory LearningInsights.build({
    required Iterable<StudySessionSummary> sessions,
    required Iterable<LearningItem> items,
    required Map<String, ProgressRecord> progress,
    required DateTime now,
    required LearningInsightRange range,
    String? courseId,
  }) {
    final localNow = now.toLocal();
    final end = DateTime(localNow.year, localNow.month, localNow.day);
    final dayCount = range.dayCount;
    final start = dayCount == null
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : end.subtract(Duration(days: dayCount - 1));
    final filtered = sessions
        .where((session) {
          if (courseId != null && session.courseId != courseId) return false;
          final local = session.endedAt.toLocal();
          final date = DateTime(local.year, local.month, local.day);
          return !date.isBefore(start) && !date.isAfter(end);
        })
        .toList(growable: false);

    final daily = <DateTime, _MutableInsight>{};
    final skills = <String, _MutableInsight>{};
    final subjects = <String, _MutableInsight>{};
    for (final session in filtered) {
      final local = session.endedAt.toLocal();
      final date = DateTime(local.year, local.month, local.day);
      daily.putIfAbsent(date, _MutableInsight.new).add(session);
      skills
          .putIfAbsent(_skillForMode(session.mode.name), _MutableInsight.new)
          .add(session);
      subjects.putIfAbsent(session.courseId, _MutableInsight.new).add(session);
    }

    final visibleItems = courseId == null
        ? items
        : items.where(
            (item) => courseIdForSubject(item.effectiveSubjectId) == courseId,
          );
    final hardest =
        <HardestLearningItem>[
          for (final item in visibleItems)
            if (progress[item.id] case final record?)
              if (record.attempts > 0 && record.accuracy < 0.8)
                HardestLearningItem(
                  itemId: item.id,
                  text: item.text,
                  correctCount: record.correctCount,
                  wrongCount: record.wrongCount,
                  lastStudiedAt: record.lastStudiedAt,
                  reason: record.lastResult == ReviewRating.again
                      ? '최근 답을 놓쳤어요'
                      : record.accuracy < 0.5
                      ? '정확도가 50%보다 낮아요'
                      : '반복해서 확인하면 좋아요',
                ),
        ]..sort((left, right) {
          final accuracy = left.accuracy.compareTo(right.accuracy);
          if (accuracy != 0) return accuracy;
          final attempts = right.attempts.compareTo(left.attempts);
          if (attempts != 0) return attempts;
          return left.itemId.compareTo(right.itemId);
        });

    final calendarDays = <LearningInsightDay>[];
    if (dayCount != null) {
      for (var offset = 0; offset < dayCount; offset++) {
        final date = start.add(Duration(days: offset));
        calendarDays.add((daily[date] ?? _MutableInsight()).day(date));
      }
    } else {
      final dates = daily.keys.toList()..sort();
      for (final date in dates) {
        calendarDays.add(daily[date]!.day(date));
      }
    }

    return LearningInsights(
      range: range,
      startedAt: start,
      endedAt: end,
      days: List.unmodifiable(calendarDays),
      skills: List.unmodifiable(
        [for (final entry in skills.entries) entry.value.skill(entry.key)]
          ..sort((left, right) => left.skill.compareTo(right.skill)),
      ),
      subjects: List.unmodifiable(
        [for (final entry in subjects.entries) entry.value.subject(entry.key)]
          ..sort((left, right) => right.earnedXp.compareTo(left.earnedXp)),
      ),
      hardestItems: List.unmodifiable(hardest.take(12)),
    );
  }

  final LearningInsightRange range;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<LearningInsightDay> days;
  final List<SkillLearningInsight> skills;
  final List<SubjectLearningInsight> subjects;
  final List<HardestLearningItem> hardestItems;

  int get sessionCount => days.fold(0, (sum, day) => sum + day.sessionCount);
  int get earnedXp => days.fold(0, (sum, day) => sum + day.earnedXp);
  int get correctCount => days.fold(0, (sum, day) => sum + day.correctCount);
  int get wrongCount => days.fold(0, (sum, day) => sum + day.wrongCount);
  int get attempts => correctCount + wrongCount;
  double? get accuracy => attempts == 0 ? null : correctCount / attempts;
  Duration get duration =>
      days.fold(Duration.zero, (sum, day) => sum + day.duration);

  int studiedDaysInLastSeven() =>
      days.reversed.take(7).where((day) => day.studied).length;

  Duration durationInLastSeven() => days.reversed
      .take(7)
      .fold(Duration.zero, (sum, day) => sum + day.duration);

  double weeklySessionGoalProgress(int targetDays) {
    if (targetDays <= 0) return 0;
    return (studiedDaysInLastSeven() / targetDays).clamp(0.0, 1.0).toDouble();
  }

  double weeklyDurationGoalProgress(int targetMinutes) {
    if (targetMinutes <= 0) return 0;
    return (durationInLastSeven().inMinutes / targetMinutes)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double weeklyCombinedGoalProgress({
    required int targetDays,
    required int targetMinutes,
  }) => weeklySessionGoalProgress(
    targetDays,
  ).clamp(0.0, weeklyDurationGoalProgress(targetMinutes)).toDouble();
}

class _MutableInsight {
  var sessions = 0;
  var correct = 0;
  var wrong = 0;
  var xp = 0;
  var duration = Duration.zero;
  var reviewSessions = 0;
  final accuracyHistory = <(DateTime, int, int)>[];

  void add(StudySessionSummary session) {
    sessions++;
    correct += session.correctCount;
    wrong += session.wrongCount;
    xp += session.earnedXp;
    if (const {
      StudyMode.review,
      StudyMode.weak,
      StudyMode.favorites,
    }.contains(session.mode)) {
      reviewSessions++;
    }
    accuracyHistory.add((
      session.endedAt.toUtc(),
      session.correctCount,
      session.wrongCount,
    ));
    final elapsed = session.endedAt.difference(session.startedAt);
    if (!elapsed.isNegative && elapsed <= const Duration(hours: 12)) {
      duration += elapsed;
    }
  }

  LearningInsightDay day(DateTime date) => LearningInsightDay(
    date: date,
    sessionCount: sessions,
    correctCount: correct,
    wrongCount: wrong,
    earnedXp: xp,
    duration: duration,
  );

  SkillLearningInsight skill(String name) => SkillLearningInsight(
    skill: name,
    sessionCount: sessions,
    correctCount: correct,
    wrongCount: wrong,
    recentAccuracyChange: _recentAccuracyChange(),
  );

  SubjectLearningInsight subject(String courseId) => SubjectLearningInsight(
    courseId: courseId,
    sessionCount: sessions,
    earnedXp: xp,
    correctCount: correct,
    wrongCount: wrong,
    duration: duration,
    reviewSessionCount: reviewSessions,
  );

  double? _recentAccuracyChange() {
    final history = [...accuracyHistory]
      ..sort((left, right) => left.$1.compareTo(right.$1));
    if (history.length < 2) return null;
    final split = history.length ~/ 2;
    final earlier = history.take(split);
    final recent = history.skip(split);

    double? accuracy(Iterable<(DateTime, int, int)> values) {
      var correct = 0;
      var wrong = 0;
      for (final value in values) {
        correct += value.$2;
        wrong += value.$3;
      }
      final attempts = correct + wrong;
      return attempts == 0 ? null : correct / attempts;
    }

    final before = accuracy(earlier);
    final after = accuracy(recent);
    return before == null || after == null ? null : after - before;
  }
}

String _skillForMode(String mode) => switch (mode) {
  'meaning' => '뜻 고르기',
  'production' => '쓰기',
  'listening' => '듣기',
  'pronunciation' => '발음',
  'cloze' || 'sentenceOrder' || 'sentences' => '문장',
  'words' => '단어',
  _ => '혼합',
};
