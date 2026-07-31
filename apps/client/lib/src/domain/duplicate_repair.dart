import 'package:unorm_dart/unorm_dart.dart' as unicode;

import 'active_study_session.dart';
import 'content_management.dart';
import 'learning_item.dart';
import 'progress.dart';
import 'study_history.dart';
import 'study_preferences.dart';

enum DuplicateMatchKind { exact, similar }

enum DuplicateMergeField { meanings, readings, examples, tags }

class DuplicateRepairGroup {
  const DuplicateRepairGroup({
    required this.id,
    required this.kind,
    required this.items,
    this.similarity = 1,
  });

  final String id;
  final DuplicateMatchKind kind;
  final List<LearningItem> items;
  final double similarity;
}

class DuplicateRepairCatalog {
  const DuplicateRepairCatalog({
    this.exactGroups = const [],
    this.similarSuggestions = const [],
  });

  final List<DuplicateRepairGroup> exactGroups;
  final List<DuplicateRepairGroup> similarSuggestions;

  bool get isEmpty => exactGroups.isEmpty && similarSuggestions.isEmpty;
}

class DuplicateMergeRequest {
  const DuplicateMergeRequest({
    required this.canonicalItemId,
    required this.duplicateItemIds,
    this.fields = const {
      DuplicateMergeField.meanings,
      DuplicateMergeField.readings,
      DuplicateMergeField.examples,
      DuplicateMergeField.tags,
    },
    this.confirmedSimilarSuggestion = false,
  });

  final String canonicalItemId;
  final Set<String> duplicateItemIds;
  final Set<DuplicateMergeField> fields;

  /// A near-similar candidate can only be merged after an explicit user action.
  /// Exact groups do not need this flag.
  final bool confirmedSimilarSuggestion;

  Set<String> get allItemIds => {canonicalItemId, ...duplicateItemIds};
}

class DuplicateRepairUndoToken {
  const DuplicateRepairUndoToken({
    required this.repairId,
    required this.changedAt,
    required this.canonicalItemId,
    required this.affectedItemIds,
    required this.originalItems,
    required this.expectedMergedItem,
    required this.originalProgress,
    required this.expectedProgress,
    required this.originalPreferences,
    required this.expectedPreferencesChangedAt,
    required this.originalRecentSessions,
    required this.expectedRecentSessions,
    required this.originalActiveSession,
    required this.expectedActiveSession,
    required this.originalTombstones,
  });

  final String repairId;
  final DateTime changedAt;
  final String canonicalItemId;
  final Set<String> affectedItemIds;
  final List<LearningItem> originalItems;
  final LearningItem expectedMergedItem;
  final Map<String, ProgressRecord> originalProgress;
  final ProgressRecord? expectedProgress;
  final StudyPreferences originalPreferences;
  final DateTime expectedPreferencesChangedAt;
  final List<StudySessionSummary> originalRecentSessions;
  final List<StudySessionSummary> expectedRecentSessions;
  final ActiveStudySession? originalActiveSession;
  final ActiveStudySession? expectedActiveSession;
  final Map<String, DateTime?> originalTombstones;
}

class DuplicateRepairResult {
  const DuplicateRepairResult({
    required this.canonicalItem,
    required this.removedItemIds,
    required this.undoToken,
  });

  final LearningItem canonicalItem;
  final Set<String> removedItemIds;
  final DuplicateRepairUndoToken undoToken;
}

enum DuplicateRepairUndoStatus { restored, conflict, alreadyUndone }

class DuplicateRepairUndoResult {
  const DuplicateRepairUndoResult(this.status);

  final DuplicateRepairUndoStatus status;

  bool get restored => status == DuplicateRepairUndoStatus.restored;
}

class DuplicateRepairAnalyzer {
  const DuplicateRepairAnalyzer({
    this.minimumSimilarity = 0.78,
    this.maximumSuggestions = 200,
  });

  final double minimumSimilarity;
  final int maximumSuggestions;

  DuplicateRepairCatalog analyze(
    Iterable<LearningItem> source, {
    String? subjectId,
  }) {
    final items = source
        .where(
          (item) => subjectId == null || item.effectiveSubjectId == subjectId,
        )
        .toList(growable: false);
    final exactByKey = <String, List<LearningItem>>{};
    for (final item in items) {
      exactByKey.putIfAbsent(exactKey(item), () => []).add(item);
    }
    final exactGroups = <DuplicateRepairGroup>[
      for (final entry in exactByKey.entries)
        if (entry.value.length > 1)
          DuplicateRepairGroup(
            id: 'exact:${entry.key}',
            kind: DuplicateMatchKind.exact,
            items: List.unmodifiable(entry.value),
          ),
    ]..sort(_compareGroups);

    final exactPairs = <String>{};
    for (final group in exactGroups) {
      for (var left = 0; left < group.items.length; left++) {
        for (var right = left + 1; right < group.items.length; right++) {
          exactPairs.add(_pairKey(group.items[left], group.items[right]));
        }
      }
    }

    final comparable = {
      for (final item in items) item.id: _similarityText(item.text),
    };
    final candidatePairs = _candidatePairs(items, comparable);
    final suggestions = <DuplicateRepairGroup>[];
    for (final pair in candidatePairs) {
      if (suggestions.length >= maximumSuggestions) break;
      final left = items[pair.$1];
      final right = items[pair.$2];
      if (left.effectiveSubjectId != right.effectiveSubjectId ||
          left.learningLanguage != right.learningLanguage ||
          exactPairs.contains(_pairKey(left, right))) {
        continue;
      }
      final leftText = comparable[left.id]!;
      final rightText = comparable[right.id]!;
      final score = similarity(leftText, rightText);
      if (score < minimumSimilarity || score >= 1) continue;
      suggestions.add(
        DuplicateRepairGroup(
          id: 'similar:${_pairKey(left, right)}',
          kind: DuplicateMatchKind.similar,
          items: List.unmodifiable([left, right]),
          similarity: score,
        ),
      );
    }
    suggestions.sort((left, right) {
      final similarityOrder = right.similarity.compareTo(left.similarity);
      return similarityOrder != 0
          ? similarityOrder
          : _compareGroups(left, right);
    });
    return DuplicateRepairCatalog(
      exactGroups: List.unmodifiable(exactGroups),
      similarSuggestions: List.unmodifiable(suggestions),
    );
  }

  String exactKey(LearningItem item) => [
    item.effectiveSubjectId,
    item.learningLanguage.code,
    _exactText(item.text),
  ].join('|');

  LearningItem recommendCanonical(
    Iterable<LearningItem> source,
    Map<String, ProgressRecord> progressById,
  ) {
    final items = source.toList(growable: false);
    if (items.isEmpty) {
      throw ArgumentError.value(
        source,
        'source',
        'At least one item is needed.',
      );
    }
    final ranked = [...items]
      ..sort((left, right) {
        final leftProgress = progressById[left.id];
        final rightProgress = progressById[right.id];
        final attemptsOrder = (rightProgress?.attempts ?? 0).compareTo(
          leftProgress?.attempts ?? 0,
        );
        if (attemptsOrder != 0) return attemptsOrder;
        final statusOrder =
            _statusStrength(
              rightProgress?.status ?? LearningStatus.newItem,
            ).compareTo(
              _statusStrength(leftProgress?.status ?? LearningStatus.newItem),
            );
        if (statusOrder != 0) return statusOrder;
        final updatedOrder =
            (right.updatedAt ??
                    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true))
                .compareTo(
                  left.updatedAt ??
                      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
                );
        if (updatedOrder != 0) return updatedOrder;
        return left.id.compareTo(right.id);
      });
    return ranked.first;
  }

  double similarity(String left, String right) {
    if (left == right) return 1;
    if (left.isEmpty || right.isEmpty) return 0;
    final leftRunes = left.runes.take(160).toList(growable: false);
    final rightRunes = right.runes.take(160).toList(growable: false);
    final maximumLength = leftRunes.length > rightRunes.length
        ? leftRunes.length
        : rightRunes.length;
    if ((leftRunes.length - rightRunes.length).abs() >
        (maximumLength * (1 - minimumSimilarity)).ceil() + 1) {
      return 0;
    }
    final distance = _levenshtein(leftRunes, rightRunes);
    return 1 - (distance / maximumLength);
  }

  Set<(int, int)> _candidatePairs(
    List<LearningItem> items,
    Map<String, String> comparable,
  ) {
    final buckets = <String, List<int>>{};
    for (final (index, item) in items.indexed) {
      final text = comparable[item.id]!;
      final scope = '${item.effectiveSubjectId}|${item.learningLanguage.code}';
      final tokens = text.runes.toList(growable: false);
      if (tokens.length < 5) {
        final first = tokens.isEmpty ? 0 : tokens.first;
        for (
          var length = tokens.length - 1;
          length <= tokens.length + 1;
          length++
        ) {
          if (length >= 0) {
            buckets
                .putIfAbsent('$scope|short:$first:$length', () => [])
                .add(index);
          }
        }
        continue;
      }
      for (var offset = 0; offset <= tokens.length - 3; offset++) {
        final trigram = String.fromCharCodes(
          tokens.sublist(offset, offset + 3),
        );
        buckets.putIfAbsent('$scope|tri:$trigram', () => []).add(index);
      }
    }

    final sharedTokens = <(int, int), int>{};
    for (final indexes in buckets.values) {
      if (sharedTokens.length >= maximumSuggestions * 50) break;
      final unique = indexes.toSet().toList(growable: false);
      // Very common trigrams are not useful fuzzy signals and can otherwise
      // turn a 20,000-row library scan into a quadratic operation.
      if (unique.length < 2 || unique.length > 80) continue;
      for (var left = 0; left < unique.length; left++) {
        for (var right = left + 1; right < unique.length; right++) {
          final first = unique[left] < unique[right]
              ? unique[left]
              : unique[right];
          final second = unique[left] < unique[right]
              ? unique[right]
              : unique[left];
          final pair = (first, second);
          sharedTokens[pair] = (sharedTokens[pair] ?? 0) + 1;
          if (sharedTokens.length >= maximumSuggestions * 50) break;
        }
        if (sharedTokens.length >= maximumSuggestions * 50) break;
      }
    }
    final ranked = sharedTokens.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));
    return ranked
        .where((entry) {
          final leftText = comparable[items[entry.key.$1].id]!;
          final rightText = comparable[items[entry.key.$2].id]!;
          final maximum = leftText.length > rightText.length
              ? leftText.length
              : rightText.length;
          return (leftText.length - rightText.length).abs() <=
              (maximum * (1 - minimumSimilarity)).ceil() + 1;
        })
        .take(maximumSuggestions * 20)
        .map((entry) => entry.key)
        .toSet();
  }

  int _levenshtein(List<int> left, List<int> right) {
    if (left.length > right.length) return _levenshtein(right, left);
    var previous = List<int>.generate(left.length + 1, (index) => index);
    for (var rightIndex = 1; rightIndex <= right.length; rightIndex++) {
      final current = List<int>.filled(left.length + 1, 0);
      current[0] = rightIndex;
      for (var leftIndex = 1; leftIndex <= left.length; leftIndex++) {
        final substitution =
            previous[leftIndex - 1] +
            (left[leftIndex - 1] == right[rightIndex - 1] ? 0 : 1);
        final insertion = current[leftIndex - 1] + 1;
        final deletion = previous[leftIndex] + 1;
        current[leftIndex] = substitution < insertion
            ? (substitution < deletion ? substitution : deletion)
            : (insertion < deletion ? insertion : deletion);
      }
      previous = current;
    }
    return previous[left.length];
  }

  String _exactText(String value) =>
      unicode.nfkc(value).toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  String _similarityText(String value) => unicode
      .nfkd(unicode.nfkc(value))
      .toLowerCase()
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

  String _pairKey(LearningItem left, LearningItem right) =>
      left.id.compareTo(right.id) <= 0
      ? '${left.id}|${right.id}'
      : '${right.id}|${left.id}';

  int _compareGroups(DuplicateRepairGroup left, DuplicateRepairGroup right) {
    final textOrder = _exactText(
      left.items.first.text,
    ).compareTo(_exactText(right.items.first.text));
    return textOrder != 0
        ? textOrder
        : left.items.first.id.compareTo(right.items.first.id);
  }

  int _statusStrength(LearningStatus status) => switch (status) {
    LearningStatus.newItem => 0,
    LearningStatus.learning => 1,
    LearningStatus.suspended => 2,
    LearningStatus.review => 3,
    LearningStatus.mastered => 4,
  };
}

StudySessionSummary remapSummaryItemIds(
  StudySessionSummary source,
  Map<String, String> aliases,
) {
  final itemIds = _remapList(source.itemIds, aliases);
  final itemIdSet = itemIds.toSet();
  return StudySessionSummary(
    sessionId: source.sessionId,
    courseId: source.courseId,
    startedAt: source.startedAt,
    endedAt: source.endedAt,
    correctCount: source.correctCount,
    wrongCount: source.wrongCount,
    earnedXp: source.earnedXp,
    origin: source.origin,
    rootSessionId: source.rootSessionId,
    parentSessionId: source.parentSessionId,
    generation: source.generation,
    pauseCount: source.pauseCount,
    resumeCount: source.resumeCount,
    journey: source.journey,
    itemIds: itemIds,
    wrongItemIds: _remapSet(
      source.wrongItemIds,
      aliases,
    ).intersection(itemIdSet),
    finalCorrectItemIds: _remapSet(
      source.finalCorrectItemIds,
      aliases,
    ).intersection(itemIdSet),
    mode: source.mode,
    historyFilter: source.historyFilter,
    recordProgress: source.recordProgress,
    backlogRecovery: source.backlogRecovery,
  );
}

ActiveStudySession remapActiveSessionItemIds(
  ActiveStudySession source,
  Map<String, String> aliases,
) {
  final completedBefore = source.itemIds
      .take(source.currentIndex.clamp(0, source.itemIds.length))
      .toList(growable: false);
  final remappedItems = _remapList(source.itemIds, aliases);
  final remappedInitial = _remapList(source.originalItemIds, aliases);
  final remappedCompleted = _remapList(completedBefore, aliases);
  final itemIdSet = remappedItems.toSet();
  return source.copyWith(
    itemIds: remappedItems,
    initialItemIds: remappedInitial,
    currentIndex: remappedCompleted.length.clamp(0, remappedItems.length),
    wrongItemIds: _remapSet(
      source.wrongItemIds,
      aliases,
    ).intersection(itemIdSet),
    finalCorrectItemIds: _remapSet(
      source.finalCorrectItemIds,
      aliases,
    ).intersection(itemIdSet),
  );
}

StudySessionPlan remapPlanItemIds(
  StudySessionPlan source,
  Map<String, String> aliases,
) => source.copyWith(
  selectedItemIds: _remapSet(source.selectedItemIds, aliases),
);

List<String> _remapList(Iterable<String> source, Map<String, String> aliases) {
  final seen = <String>{};
  return [
    for (final itemId in source)
      if (seen.add(aliases[itemId] ?? itemId)) aliases[itemId] ?? itemId,
  ];
}

Set<String> _remapSet(Iterable<String> source, Map<String, String> aliases) => {
  for (final itemId in source) aliases[itemId] ?? itemId,
};

List<ContentCorrection> remapContentCorrections(
  Iterable<ContentCorrection> source,
  Map<String, String> aliases,
) {
  final byKey = <String, ContentCorrection>{};
  for (final correction in source) {
    final itemId = aliases[correction.itemId] ?? correction.itemId;
    final remapped = ContentCorrection(
      itemId: itemId,
      field: correction.field,
      note: correction.note,
      proposedValue: correction.proposedValue,
      updatedAt: correction.updatedAt,
      resolved: correction.resolved,
    );
    final key = '$itemId|${correction.field}';
    final current = byKey[key];
    if (current == null || remapped.updatedAt.isAfter(current.updatedAt)) {
      byKey[key] = remapped;
    }
  }
  return List.unmodifiable(byKey.values);
}
