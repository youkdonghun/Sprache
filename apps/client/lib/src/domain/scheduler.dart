import 'dart:math';

import 'progress.dart';

class ReviewScheduler {
  const ReviewScheduler();

  ProgressRecord apply({
    required ProgressRecord current,
    required ReviewRating rating,
    required DateTime studiedAt,
  }) {
    if (rating == ReviewRating.again) {
      return current.copyWith(
        status: LearningStatus.learning,
        wrongCount: current.wrongCount + 1,
        lapseCount: current.lapseCount + 1,
        currentIntervalDays: 0,
        nextReviewAt: studiedAt.add(const Duration(minutes: 10)),
        lastStudiedAt: studiedAt,
        lastResult: rating,
      );
    }

    final multiplier = switch (rating) {
      ReviewRating.hard => 1.2,
      ReviewRating.good => 2.2,
      ReviewRating.easy => 3.5,
      ReviewRating.again => 0,
    };
    final initialDays = switch (rating) {
      ReviewRating.hard => 1,
      ReviewRating.good => current.correctCount == 0 ? 1 : 3,
      ReviewRating.easy => 3,
      ReviewRating.again => 0,
    };
    final interval = current.currentIntervalDays == 0
        ? initialDays
        : max(1, (current.currentIntervalDays * multiplier).round());
    final correctCount = current.correctCount + 1;
    final attempts = correctCount + current.wrongCount;
    final accuracy = attempts == 0 ? 0 : correctCount / attempts;
    final mastered = interval >= 60 && accuracy >= 0.9;

    return current.copyWith(
      status: mastered ? LearningStatus.mastered : LearningStatus.review,
      correctCount: correctCount,
      currentIntervalDays: interval,
      nextReviewAt: studiedAt.add(Duration(days: interval)),
      lastStudiedAt: studiedAt,
      lastResult: rating,
    );
  }
}
