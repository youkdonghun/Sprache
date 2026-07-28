import 'progress.dart';

class ReviewForecast {
  const ReviewForecast({
    required this.dueNow,
    required this.laterToday,
    required this.tomorrow,
    required this.nextSevenDays,
    this.nextReviewAt,
  });

  final int dueNow;
  final int laterToday;
  final int tomorrow;
  final int nextSevenDays;
  final DateTime? nextReviewAt;

  int get scheduledCount => dueNow + laterToday + tomorrow + nextSevenDays;
}

class ReviewForecastBuilder {
  const ReviewForecastBuilder();

  ReviewForecast build({
    required Iterable<ProgressRecord> progress,
    required Set<String> itemIds,
    required DateTime now,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrowStart = today.add(const Duration(days: 1));
    final dayAfterTomorrow = today.add(const Duration(days: 2));
    final eightDaysFromToday = today.add(const Duration(days: 8));
    var dueNow = 0;
    var laterToday = 0;
    var tomorrow = 0;
    var nextSevenDays = 0;
    DateTime? nextReviewAt;

    for (final record in progress) {
      if (!itemIds.contains(record.itemId)) continue;
      final reviewAt = record.nextReviewAt;
      if (reviewAt == null) continue;
      if (nextReviewAt == null || reviewAt.isBefore(nextReviewAt)) {
        nextReviewAt = reviewAt;
      }
      if (!reviewAt.isAfter(now)) {
        dueNow++;
      } else if (reviewAt.isBefore(tomorrowStart)) {
        laterToday++;
      } else if (reviewAt.isBefore(dayAfterTomorrow)) {
        tomorrow++;
      } else if (reviewAt.isBefore(eightDaysFromToday)) {
        nextSevenDays++;
      }
    }

    return ReviewForecast(
      dueNow: dueNow,
      laterToday: laterToday,
      tomorrow: tomorrow,
      nextSevenDays: nextSevenDays,
      nextReviewAt: nextReviewAt,
    );
  }
}
