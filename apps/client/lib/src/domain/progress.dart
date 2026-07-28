enum LearningStatus { newItem, learning, review, mastered, suspended }

enum ReviewRating { again, hard, good, easy }

class ProgressRecord {
  const ProgressRecord({
    required this.itemId,
    this.status = LearningStatus.newItem,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.lapseCount = 0,
    this.currentIntervalDays = 0,
    this.nextReviewAt,
    this.lastStudiedAt,
    this.lastResult,
  });

  final String itemId;
  final LearningStatus status;
  final int correctCount;
  final int wrongCount;
  final int lapseCount;
  final int currentIntervalDays;
  final DateTime? nextReviewAt;
  final DateTime? lastStudiedAt;
  final ReviewRating? lastResult;

  int get attempts => correctCount + wrongCount;
  double get accuracy => attempts == 0 ? 0 : correctCount / attempts;

  ProgressRecord copyWith({
    LearningStatus? status,
    int? correctCount,
    int? wrongCount,
    int? lapseCount,
    int? currentIntervalDays,
    DateTime? nextReviewAt,
    DateTime? lastStudiedAt,
    ReviewRating? lastResult,
  }) {
    return ProgressRecord(
      itemId: itemId,
      status: status ?? this.status,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      lapseCount: lapseCount ?? this.lapseCount,
      currentIntervalDays: currentIntervalDays ?? this.currentIntervalDays,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}
