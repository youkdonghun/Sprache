import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/review_forecast.dart';

void main() {
  test('review forecast puts every scheduled item in one time bucket', () {
    final now = DateTime.utc(2026, 7, 27, 9);
    const builder = ReviewForecastBuilder();
    final progress = [
      ProgressRecord(
        itemId: 'due',
        nextReviewAt: now.subtract(const Duration(minutes: 1)),
      ),
      ProgressRecord(
        itemId: 'later',
        nextReviewAt: now.add(const Duration(hours: 2)),
      ),
      ProgressRecord(
        itemId: 'tomorrow',
        nextReviewAt: now.add(const Duration(days: 1, hours: 2)),
      ),
      ProgressRecord(
        itemId: 'week',
        nextReviewAt: now.add(const Duration(days: 4)),
      ),
      ProgressRecord(
        itemId: 'outside-course',
        nextReviewAt: now.subtract(const Duration(days: 1)),
      ),
    ];

    final forecast = builder.build(
      progress: progress,
      itemIds: const {'due', 'later', 'tomorrow', 'week'},
      now: now,
    );

    expect(forecast.dueNow, 1);
    expect(forecast.laterToday, 1);
    expect(forecast.tomorrow, 1);
    expect(forecast.nextSevenDays, 1);
    expect(forecast.scheduledCount, 4);
    expect(forecast.nextReviewAt, progress.first.nextReviewAt);
  });
}
