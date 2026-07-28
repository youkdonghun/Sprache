import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/scheduler.dart';

void main() {
  const scheduler = ReviewScheduler();
  final now = DateTime.utc(2026, 7, 27, 9);

  test('again schedules an item ten minutes later and adds a lapse', () {
    const current = ProgressRecord(itemId: 'item');
    final result = scheduler.apply(
      current: current,
      rating: ReviewRating.again,
      studiedAt: now,
    );

    expect(result.status, LearningStatus.learning);
    expect(result.lapseCount, 1);
    expect(result.nextReviewAt, now.add(const Duration(minutes: 10)));
  });

  test('good starts at one day and grows the interval by 2.2', () {
    const current = ProgressRecord(itemId: 'item');
    final first = scheduler.apply(
      current: current,
      rating: ReviewRating.good,
      studiedAt: now,
    );
    final second = scheduler.apply(
      current: first,
      rating: ReviewRating.good,
      studiedAt: first.nextReviewAt!,
    );

    expect(first.currentIntervalDays, 1);
    expect(second.currentIntervalDays, 2);
  });

  test('high accuracy with a sixty-day interval becomes mastered', () {
    const current = ProgressRecord(
      itemId: 'item',
      status: LearningStatus.review,
      correctCount: 10,
      currentIntervalDays: 30,
    );
    final result = scheduler.apply(
      current: current,
      rating: ReviewRating.good,
      studiedAt: now,
    );

    expect(result.currentIntervalDays, 66);
    expect(result.status, LearningStatus.mastered);
  });
}
