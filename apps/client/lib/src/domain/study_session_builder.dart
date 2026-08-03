import 'learning_item.dart';
import 'learning_group.dart';
import 'progress.dart';
import 'study_preferences.dart';

class StudySessionBuildResult {
  const StudySessionBuildResult({
    required this.items,
    required this.matchingCount,
    required this.matchingWordCount,
    required this.matchingSentenceCount,
  });

  final List<LearningItem> items;
  final int matchingCount;
  final int matchingWordCount;
  final int matchingSentenceCount;

  int get selectedWordCount =>
      items.where((item) => item.kind == LearningItemKind.word).length;

  int get selectedSentenceCount => items.length - selectedWordCount;

  bool get isEmpty => items.isEmpty;
}

class StudySessionBuilder {
  const StudySessionBuilder();

  StudySessionBuildResult build({
    required String courseId,
    required DateTime localDate,
    required List<LearningItem> items,
    required Map<String, ProgressRecord> progress,
    required StudySessionPlan plan,
    double averageSecondsPerItem = 30,
    Set<String> favoriteItemIds = const {},
    Set<String> personalItemIds = const {},
    int recoveryItemsStudiedToday = 0,
  }) {
    final matching = items
        .where((item) {
          if (!_matchesDeck(
            item,
            plan,
            favoriteItemIds: favoriteItemIds,
            personalItemIds: personalItemIds,
          )) {
            return false;
          }
          if (plan.tags.isNotEmpty &&
              !item.tags.any((tag) => plan.tags.contains(tag))) {
            return false;
          }
          if (plan.groupIds.isNotEmpty) {
            final itemGroupIds = {
              for (final name in learningGroupsOf(item))
                learningGroupDefinitionId(plan.subjectId, name),
            };
            if (itemGroupIds.intersection(plan.groupIds).isEmpty) return false;
          }
          if (plan.levels.isNotEmpty && !plan.levels.contains(item.level)) {
            return false;
          }
          if (item.kind == LearningItemKind.word && !plan.includeWords) {
            return false;
          }
          if (item.kind == LearningItemKind.sentence &&
              !plan.includeSentences) {
            return false;
          }
          if (!_matchesHistory(progress[item.id], plan.historyFilter)) {
            return false;
          }
          if (!_matchesDifficulty(progress[item.id], plan.difficulty)) {
            return false;
          }
          return _supportsMode(item, plan.mode);
        })
        .toList(growable: false);

    final ranked = [...matching]
      ..sort(
        (left, right) => _compareItems(
          left,
          right,
          progress: progress,
          courseId: courseId,
          localDate: localDate,
          queuePriority: plan.queuePriority,
          backlogRecovery: plan.backlogRecovery.enabled,
        ),
      );
    final requestedLimit = plan.effectiveItemLimit(
      averageSecondsPerItem: averageSecondsPerItem,
    );
    final remainingRecoveryLimit = plan.backlogRecovery.enabled
        ? (plan.backlogRecovery.dailyLimit - recoveryItemsStudiedToday).clamp(
            0,
            plan.backlogRecovery.dailyLimit,
          )
        : requestedLimit;
    final selected = _applyKindRatio(
      ranked,
      itemLimit: requestedLimit.clamp(0, remainingRecoveryLimit),
      sentenceRatio: plan.sentenceRatio,
      includeWords: plan.includeWords,
      includeSentences: plan.includeSentences,
    );

    return StudySessionBuildResult(
      items: selected,
      matchingCount: matching.length,
      matchingWordCount: matching
          .where((item) => item.kind == LearningItemKind.word)
          .length,
      matchingSentenceCount: matching
          .where((item) => item.kind == LearningItemKind.sentence)
          .length,
    );
  }

  bool _matchesDeck(
    LearningItem item,
    StudySessionPlan plan, {
    required Set<String> favoriteItemIds,
    required Set<String> personalItemIds,
  }) {
    return switch (plan.deck) {
      StudyDeckScope.course => true,
      StudyDeckScope.unit => item.tags.contains('unit-${plan.unitIndex ?? 0}'),
      StudyDeckScope.favorites => favoriteItemIds.contains(item.id),
      StudyDeckScope.personal => personalItemIds.contains(item.id),
      StudyDeckScope.selected => plan.selectedItemIds.contains(item.id),
    };
  }

  bool _matchesDifficulty(ProgressRecord? record, StudyDifficulty difficulty) {
    return switch (difficulty) {
      StudyDifficulty.all => true,
      StudyDifficulty.newItems =>
        record == null || record.status == LearningStatus.newItem,
      StudyDifficulty.learning => record?.status == LearningStatus.learning,
      StudyDifficulty.review => record?.status == LearningStatus.review,
      StudyDifficulty.weak =>
        record != null && record.attempts > 0 && record.accuracy < 0.7,
      StudyDifficulty.mastered => record?.status == LearningStatus.mastered,
    };
  }

  bool _matchesHistory(ProgressRecord? record, StudyHistoryFilter filter) {
    return switch (filter) {
      StudyHistoryFilter.all => true,
      StudyHistoryFilter.excludeCorrect =>
        record == null || record.correctCount == 0,
      StudyHistoryFilter.wrongOnly => record?.lastResult == ReviewRating.again,
    };
  }

  bool _supportsMode(LearningItem item, StudyMode mode) {
    return switch (mode) {
      StudyMode.mixed ||
      StudyMode.review ||
      StudyMode.weak ||
      StudyMode.favorites ||
      StudyMode.newItems => true,
      StudyMode.words => item.kind == LearningItemKind.word,
      StudyMode.sentences => item.kind == LearningItemKind.sentence,
      StudyMode.meaning => item.capabilities.contains(
        ExerciseCapability.recognition,
      ),
      StudyMode.production => item.capabilities.contains(
        ExerciseCapability.production,
      ),
      StudyMode.cloze =>
        item.kind == LearningItemKind.sentence &&
            item.sentenceTokens.length >= 2 &&
            item.capabilities.contains(ExerciseCapability.cloze),
      StudyMode.sentenceOrder =>
        item.kind == LearningItemKind.sentence &&
            item.sentenceTokens.length >= 2 &&
            item.capabilities.contains(ExerciseCapability.sentenceOrder),
      StudyMode.listening => item.capabilities.contains(
        ExerciseCapability.listening,
      ),
      StudyMode.pronunciation => item.capabilities.contains(
        ExerciseCapability.listening,
      ),
    };
  }

  int _compareItems(
    LearningItem left,
    LearningItem right, {
    required Map<String, ProgressRecord> progress,
    required String courseId,
    required DateTime localDate,
    required StudyQueuePriority queuePriority,
    required bool backlogRecovery,
  }) {
    final leftProgress = progress[left.id];
    final rightProgress = progress[right.id];
    if (backlogRecovery) {
      final recoveryOrder = _recoveryScore(
        rightProgress,
        localDate,
      ).compareTo(_recoveryScore(leftProgress, localDate));
      if (recoveryOrder != 0) return recoveryOrder;
    }
    final rankOrder = _learningRank(
      leftProgress,
      localDate,
      queuePriority,
    ).compareTo(_learningRank(rightProgress, localDate, queuePriority));
    if (rankOrder != 0) return rankOrder;

    final leftDue = leftProgress?.nextReviewAt;
    final rightDue = rightProgress?.nextReviewAt;
    if (leftDue != null && rightDue != null) {
      final dueOrder = leftDue.compareTo(rightDue);
      if (dueOrder != 0) return dueOrder;
    }

    if (leftProgress != null &&
        rightProgress != null &&
        leftProgress.attempts > 0 &&
        rightProgress.attempts > 0) {
      final accuracyOrder = leftProgress.accuracy.compareTo(
        rightProgress.accuracy,
      );
      if (accuracyOrder != 0) return accuracyOrder;
    }

    final priorityOrder = right.priority.compareTo(left.priority);
    if (priorityOrder != 0) return priorityOrder;

    final date = DateTime(localDate.year, localDate.month, localDate.day);
    return _stableKey(
      '$courseId:${date.toIso8601String()}:${left.id}',
    ).compareTo(_stableKey('$courseId:${date.toIso8601String()}:${right.id}'));
  }

  int _learningRank(
    ProgressRecord? record,
    DateTime now,
    StudyQueuePriority queuePriority,
  ) {
    final dueAt = record?.nextReviewAt;
    final due = dueAt != null && !dueAt.isAfter(now);
    final weak = record != null && record.attempts > 0 && record.accuracy < 0.7;
    final fresh = record == null || record.status == LearningStatus.newItem;
    if (queuePriority == StudyQueuePriority.newFirst) {
      if (fresh) return 0;
      if (due) return 1;
      if (weak) return 2;
      return 3;
    }
    if (due) return 0;
    if (weak) return 1;
    if (fresh) return 2;
    return 3;
  }

  int _recoveryScore(ProgressRecord? record, DateTime now) {
    if (record == null || record.attempts == 0) return 0;
    final dueAt = record.nextReviewAt;
    final overdueDays = dueAt == null || dueAt.isAfter(now)
        ? 0
        : now.difference(dueAt).inDays.clamp(0, 365);
    final weakness = ((1 - record.accuracy.clamp(0, 1)) * 100).round();
    final unresolvedWrong = record.lastResult == ReviewRating.again ? 40 : 0;
    return overdueDays * 10 + weakness + unresolvedWrong;
  }

  List<LearningItem> _applyKindRatio(
    List<LearningItem> ranked, {
    required int itemLimit,
    required double sentenceRatio,
    required bool includeWords,
    required bool includeSentences,
  }) {
    if (ranked.isEmpty || itemLimit <= 0) return const [];
    final limit = itemLimit.clamp(1, ranked.length);
    if (!includeWords || !includeSentences) {
      return ranked.take(limit).toList(growable: false);
    }

    final sentenceTarget = (limit * sentenceRatio.clamp(0, 1)).round();
    final wordTarget = limit - sentenceTarget;
    final sentences = ranked
        .where((item) => item.kind == LearningItemKind.sentence)
        .toList(growable: false);
    final words = ranked
        .where((item) => item.kind == LearningItemKind.word)
        .toList(growable: false);
    final selectedIds = <String>{
      for (final item in sentences.take(sentenceTarget)) item.id,
      for (final item in words.take(wordTarget)) item.id,
    };
    if (selectedIds.length < limit) {
      for (final item in ranked) {
        selectedIds.add(item.id);
        if (selectedIds.length == limit) break;
      }
    }
    return ranked
        .where((item) => selectedIds.contains(item.id))
        .take(limit)
        .toList(growable: false);
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
