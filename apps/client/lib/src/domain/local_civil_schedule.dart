import 'package:timezone/timezone.dart' as tz;

/// A recurring wall-clock schedule that is independent of a UTC offset.
///
/// Persisting weekdays and minute-of-day (rather than tomorrow's UTC offset)
/// lets the same routine stay at, for example, 09:00 after travel or a DST
/// transition. Only the next occurrence is derived again; historical UTC
/// study instants are never rewritten.
class LocalCivilSchedule {
  LocalCivilSchedule({
    required Iterable<int> weekdays,
    required this.minuteOfDay,
  }) : weekdays = Set<int>.unmodifiable(weekdays) {
    if (this.weekdays.any((day) => day < 1 || day > 7)) {
      throw const FormatException('Weekdays must be in the range 1 through 7.');
    }
    if (minuteOfDay < 0 || minuteOfDay > 1439) {
      throw const FormatException(
        'Minute of day must be in the range 0 through 1439.',
      );
    }
  }

  final Set<int> weekdays;
  final int minuteOfDay;

  DateTime? nextUtc({required DateTime after, required tz.Location location}) {
    if (weekdays.isEmpty) return null;
    final afterUtc = after.toUtc();
    final localAfter = tz.TZDateTime.from(afterUtc, location);
    for (var offset = 0; offset <= 7; offset++) {
      // UTC is used only as a Gregorian calendar calculator here. It avoids
      // accidentally skipping a civil date whose local midnight is affected
      // by an offset transition.
      final civilDay = DateTime.utc(
        localAfter.year,
        localAfter.month,
        localAfter.day + offset,
      );
      if (!weekdays.contains(civilDay.weekday)) continue;
      final candidates = _utcCandidatesForCivilMinute(
        location: location,
        year: civilDay.year,
        month: civilDay.month,
        day: civilDay.day,
        hour: minuteOfDay ~/ 60,
        minute: minuteOfDay % 60,
      );
      for (final candidate in candidates) {
        if (candidate.isAfter(afterUtc)) return candidate;
      }
    }
    return null;
  }
}

List<DateTime> _utcCandidatesForCivilMinute({
  required tz.Location location,
  required int year,
  required int month,
  required int day,
  required int hour,
  required int minute,
}) {
  final normalized = tz.TZDateTime(location, year, month, day, hour, minute);
  final center = normalized.toUtc();
  final exact = <DateTime>[];

  // A repeated DST hour has two valid UTC instants. timezone's constructor
  // chooses one, so inspect the nearby offset window and retain both.
  for (var deltaMinutes = -180; deltaMinutes <= 180; deltaMinutes++) {
    final instant = center.add(Duration(minutes: deltaMinutes));
    final local = tz.TZDateTime.from(instant, location);
    if (local.year == year &&
        local.month == month &&
        local.day == day &&
        local.hour == hour &&
        local.minute == minute) {
      exact.add(instant);
    }
  }
  if (exact.isNotEmpty) {
    exact.sort();
    return List<DateTime>.unmodifiable(exact);
  }

  // A spring-forward gap has no exact wall-clock instant. timezone normalizes
  // it to the corresponding first valid post-transition time, which is safer
  // than silently moving the routine to another date.
  final normalizedLocal = tz.TZDateTime.from(center, location);
  if (normalizedLocal.year == year &&
      normalizedLocal.month == month &&
      normalizedLocal.day == day) {
    return [center];
  }
  return const [];
}
