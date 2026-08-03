import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef AppNow = DateTime Function();

final appClockProvider = Provider<AppNow>((ref) => DateTime.now);

DateTime localCalendarDay(DateTime value) =>
    DateTime(value.year, value.month, value.day);

final calendarDayProvider = StateProvider<DateTime>(
  (ref) => localCalendarDay(ref.watch(appClockProvider)()),
);
