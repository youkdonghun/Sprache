import 'dart:math' as math;

import 'package:timezone/timezone.dart' as tz;

import 'local_civil_schedule.dart';
import 'study_history.dart';
import 'study_preferences.dart';
import 'session_enhancements.dart';

class StudyRoutineGroup {
  const StudyRoutineGroup({
    required this.name,
    required this.plans,
    required this.weekdays,
    required this.minuteOfDay,
  });

  final String name;
  final List<StudySessionPlan> plans;
  final Set<int> weekdays;
  final int? minuteOfDay;
}

List<StudyRoutineGroup> groupStudyRoutines(Iterable<StudySessionPlan> plans) {
  final grouped = <String, List<StudySessionPlan>>{};
  for (final plan in plans) {
    final name = plan.routineName.trim();
    if (name.isEmpty) continue;
    grouped.putIfAbsent(name, () => []).add(plan);
  }
  final result = <StudyRoutineGroup>[];
  for (final entry in grouped.entries) {
    final ordered = [...entry.value]
      ..sort((left, right) {
        final order = left.routineOrder.compareTo(right.routineOrder);
        return order != 0 ? order : left.planId.compareTo(right.planId);
      });
    result.add(
      StudyRoutineGroup(
        name: entry.key,
        plans: List.unmodifiable(ordered),
        weekdays: Set.unmodifiable(
          ordered.expand((plan) => plan.routineWeekdays).toSet(),
        ),
        minuteOfDay: ordered
            .map((plan) => plan.routineMinuteOfDay)
            .whereType<int>()
            .firstOrNull,
      ),
    );
  }
  result.sort((left, right) => left.name.compareTo(right.name));
  return List.unmodifiable(result);
}

DateTime? nextRoutineOccurrence(
  StudySessionPlan plan, {
  required DateTime after,
  tz.Location? location,
}) {
  if (plan.routineName.trim().isEmpty || plan.routineWeekdays.isEmpty) {
    return null;
  }
  final localAfter = after.toLocal();
  final scheduled = plan.scheduledAt?.toLocal();
  final fallbackMinute = scheduled == null
      ? 19 * 60
      : scheduled.hour * 60 + scheduled.minute;
  final minute = (plan.routineMinuteOfDay ?? fallbackMinute).clamp(0, 1439);
  if (location != null) {
    return LocalCivilSchedule(
      weekdays: plan.routineWeekdays,
      minuteOfDay: minute,
    ).nextUtc(after: after, location: location);
  }
  for (var offset = 0; offset <= 7; offset++) {
    final day = DateTime(
      localAfter.year,
      localAfter.month,
      localAfter.day + offset,
    );
    if (!plan.routineWeekdays.contains(day.weekday)) continue;
    final candidate = DateTime(
      day.year,
      day.month,
      day.day,
      minute ~/ 60,
      minute % 60,
    );
    if (candidate.isAfter(localAfter)) return candidate.toUtc();
  }
  return null;
}

StudySessionPlan? buildTwoMinuteStudyPlan({
  required String subjectId,
  required Iterable<String> dueItemIds,
  required Iterable<String> weakItemIds,
  int maximumItems = 5,
}) {
  final safeMaximum = maximumItems.clamp(3, 5);
  final ids = <String>[];
  final seen = <String>{};
  void add(Iterable<String> candidates) {
    for (final raw in candidates) {
      final id = raw.trim();
      if (id.isNotEmpty && seen.add(id) && ids.length < safeMaximum) {
        ids.add(id);
      }
    }
  }

  add(dueItemIds);
  add(weakItemIds);
  if (ids.length < 3) return null;
  return StudySessionPlan(
    subjectId: subjectId,
    title: '2분 취약·복습',
    deck: StudyDeckScope.selected,
    difficulty: StudyDifficulty.all,
    queuePriority: StudyQueuePriority.dueFirst,
    historyFilter: StudyHistoryFilter.all,
    selectedItemIds: Set.unmodifiable(ids),
    itemLimit: ids.length,
    lengthMode: StudySessionLengthMode.timeBudget,
    timeBudgetMinutes: 2,
    recordProgress: true,
  );
}

class BacklogRedistribution {
  const BacklogRedistribution({
    required this.dailyItems,
    required this.scheduledItems,
    required this.remainingBacklog,
  });

  final List<int> dailyItems;
  final int scheduledItems;
  final int remainingBacklog;
}

BacklogRedistribution redistributeMissedStudy({
  required int missedItems,
  required int remainingStudyDays,
  required int dailyCap,
}) {
  final days = remainingStudyDays.clamp(0, 31);
  final cap = dailyCap.clamp(1, 100);
  final backlog = math.max(0, missedItems);
  if (days == 0 || backlog == 0) {
    return BacklogRedistribution(
      dailyItems: List.filled(days, 0),
      scheduledItems: 0,
      remainingBacklog: backlog,
    );
  }
  final scheduled = math.min(backlog, days * cap);
  final base = scheduled ~/ days;
  final remainder = scheduled % days;
  final distribution = [
    for (var index = 0; index < days; index++)
      base + (index < remainder ? 1 : 0),
  ];
  return BacklogRedistribution(
    dailyItems: List.unmodifiable(distribution),
    scheduledItems: scheduled,
    remainingBacklog: backlog - scheduled,
  );
}

class LocalStudyTimeRecommendation {
  const LocalStudyTimeRecommendation({
    required this.minuteOfDay,
    required this.sampleCount,
    required this.confidence,
  });

  final int minuteOfDay;
  final int sampleCount;
  final double confidence;

  String get label {
    final hour = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
    final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

LocalStudyTimeRecommendation? recommendLocalStudyTime(
  Iterable<StudySessionSummary> sessions, {
  int minimumSamples = 3,
}) {
  final values = sessions
      .where((session) => session.attempts > 0)
      .map((session) {
        final local = session.endedAt.toLocal();
        return local.hour * 60 + local.minute;
      })
      .take(20)
      .toList(growable: false);
  if (values.length < minimumSamples.clamp(1, 20)) return null;

  var x = 0.0;
  var y = 0.0;
  for (final minute in values) {
    final angle = minute / 1440 * math.pi * 2;
    x += math.cos(angle);
    y += math.sin(angle);
  }
  var angle = math.atan2(y, x);
  if (angle < 0) angle += math.pi * 2;
  final rawMinute = (angle / (math.pi * 2) * 1440).round() % 1440;
  final rounded = ((rawMinute / 15).round() * 15) % 1440;
  final confidence = math.sqrt(x * x + y * y) / values.length;
  return LocalStudyTimeRecommendation(
    minuteOfDay: rounded,
    sampleCount: values.length,
    confidence: confidence.clamp(0, 1),
  );
}
