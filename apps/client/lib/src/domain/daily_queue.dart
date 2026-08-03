import 'learning_item.dart';
import 'progress.dart';
import 'study_preferences.dart';

class DailyQueueBuilder {
  const DailyQueueBuilder();

  List<LearningItem> build({
    required String courseId,
    required DateTime localDate,
    required List<LearningItem> items,
    required Map<String, ProgressRecord> progress,
    int newItemLimit = 10,
    int reviewLimit = 30,
    double sentenceRatio = 0.3,
    StudyQueuePriority queuePriority = StudyQueuePriority.dueFirst,
  }) {
    final today = DateTime(localDate.year, localDate.month, localDate.day);
    final due = <LearningItem>[];
    final fresh = <LearningItem>[];

    for (final item in items) {
      final record = progress[item.id];
      if (record == null || record.status == LearningStatus.newItem) {
        fresh.add(item);
        continue;
      }
      final nextReview = record.nextReviewAt;
      if (nextReview != null && !nextReview.isAfter(localDate)) {
        due.add(item);
      }
    }

    due.sort((left, right) {
      final leftProgress = progress[left.id]!;
      final rightProgress = progress[right.id]!;
      final dueOrder = leftProgress.nextReviewAt!.compareTo(
        rightProgress.nextReviewAt!,
      );
      if (dueOrder != 0) return dueOrder;
      final weaknessOrder = leftProgress.accuracy.compareTo(
        rightProgress.accuracy,
      );
      if (weaknessOrder != 0) return weaknessOrder;
      return right.priority.compareTo(left.priority);
    });

    fresh.sort((left, right) {
      final priorityOrder = right.priority.compareTo(left.priority);
      if (priorityOrder != 0) return priorityOrder;
      return _stableKey(
        '$courseId:${today.toIso8601String()}:${left.id}',
      ).compareTo(
        _stableKey('$courseId:${today.toIso8601String()}:${right.id}'),
      );
    });

    final candidates = queuePriority == StudyQueuePriority.newFirst
        ? [...fresh.take(newItemLimit), ...due.take(reviewLimit)]
        : [...due.take(reviewLimit), ...fresh.take(newItemLimit)];
    return _applySentenceRatio(candidates, sentenceRatio.clamp(0, 1));
  }

  List<LearningItem> _applySentenceRatio(
    List<LearningItem> candidates,
    double sentenceRatio,
  ) {
    if (candidates.length < 2) return candidates;
    final sentenceTarget = (candidates.length * sentenceRatio).round();
    final wordTarget = candidates.length - sentenceTarget;
    var sentences = 0;
    var words = 0;
    final selected = <LearningItem>[];
    final skipped = <LearningItem>[];

    for (final item in candidates) {
      final isSentence = item.kind == LearningItemKind.sentence;
      if (isSentence && sentences < sentenceTarget) {
        selected.add(item);
        sentences++;
      } else if (!isSentence && words < wordTarget) {
        selected.add(item);
        words++;
      } else {
        skipped.add(item);
      }
    }
    selected.addAll(skipped.take(candidates.length - selected.length));
    return selected;
  }

  int _stableKey(String value) {
    var hash = 2166136261;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0x7fffffff;
    }
    return hash;
  }
}
