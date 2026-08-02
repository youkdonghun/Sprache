import 'learning_item.dart';
import 'progress.dart';
import 'study_preferences.dart';

enum StudySkill { meaning, writing, listening, sentence, pronunciation }

extension StudySkillLabel on StudySkill {
  String get koreanLabel => switch (this) {
    StudySkill.meaning => '뜻',
    StudySkill.writing => '쓰기',
    StudySkill.listening => '듣기',
    StudySkill.sentence => '문장',
    StudySkill.pronunciation => '발음',
  };
}

enum StudyErrorType {
  none,
  gaveUp,
  meaningRecall,
  writingAccuracy,
  listeningRecognition,
  sentenceStructure,
  pronunciation,
  slowResponse,
}

extension StudyErrorTypeLabel on StudyErrorType {
  String get koreanLabel => switch (this) {
    StudyErrorType.none => '정답',
    StudyErrorType.gaveUp => '모름',
    StudyErrorType.meaningRecall => '뜻 회상',
    StudyErrorType.writingAccuracy => '쓰기 정확도',
    StudyErrorType.listeningRecognition => '소리 구별',
    StudyErrorType.sentenceStructure => '문장 구조',
    StudyErrorType.pronunciation => '발음',
    StudyErrorType.slowResponse => '응답 지연',
  };
}

enum StudySessionStrategy { adaptive, balanced, custom }

extension StudySessionStrategyLabel on StudySessionStrategy {
  String get koreanLabel => switch (this) {
    StudySessionStrategy.adaptive => '적응형',
    StudySessionStrategy.balanced => '균형',
    StudySessionStrategy.custom => '사용자 지정',
  };

  String get description => switch (this) {
    StudySessionStrategy.adaptive => '오답·응답 시간·기술 숙련도를 바탕으로 취약 문제를 먼저 냅니다.',
    StudySessionStrategy.balanced => '뜻·쓰기·듣기·문장·발음 기술과 단어·문장을 고르게 섞습니다.',
    StudySessionStrategy.custom => '사용자가 만든 현재 큐 순서를 그대로 유지합니다.',
  };
}

class StudyAttemptMetric {
  const StudyAttemptMetric({
    required this.itemId,
    required this.skill,
    required this.errorType,
    required this.correct,
    required this.responseTimeMs,
    required this.recordedAt,
    this.usedHint = false,
  });

  final String itemId;
  final StudySkill skill;
  final StudyErrorType errorType;
  final bool correct;
  final int responseTimeMs;
  final DateTime recordedAt;
  final bool usedHint;

  Duration get responseTime => Duration(milliseconds: responseTimeMs);

  StudyAttemptMetric copyWithOutcome({
    required bool correct,
    required StudyErrorType errorType,
  }) => StudyAttemptMetric(
    itemId: itemId,
    skill: skill,
    errorType: errorType,
    correct: correct,
    responseTimeMs: responseTimeMs,
    recordedAt: recordedAt,
    usedHint: usedHint,
  );

  Map<String, Object?> toJson() => {
    'itemId': itemId,
    'skill': skill.name,
    'errorType': errorType.name,
    'correct': correct,
    'responseTimeMs': responseTimeMs.clamp(0, _maximumResponseTimeMs),
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'usedHint': usedHint,
  };

  factory StudyAttemptMetric.fromJson(Map<String, Object?> json) {
    final itemId = json['itemId'];
    final responseTimeMs = _exactInteger(json['responseTimeMs']);
    final recordedAt = DateTime.tryParse(json['recordedAt'] as String? ?? '');
    final skill = _enumByName(StudySkill.values, json['skill']);
    final errorType = _enumByName(StudyErrorType.values, json['errorType']);
    final correct = json['correct'];
    final usedHint = json['usedHint'];
    if (itemId is! String ||
        itemId.trim().isEmpty ||
        itemId.runes.length > 160 ||
        responseTimeMs == null ||
        responseTimeMs < 0 ||
        responseTimeMs > _maximumResponseTimeMs ||
        recordedAt == null ||
        skill == null ||
        errorType == null ||
        correct is! bool ||
        (usedHint != null && usedHint is! bool)) {
      throw const FormatException('Invalid study attempt metric');
    }
    return StudyAttemptMetric(
      itemId: itemId,
      skill: skill,
      errorType: errorType,
      correct: correct,
      responseTimeMs: responseTimeMs,
      recordedAt: recordedAt.toUtc(),
      usedHint: usedHint == true,
    );
  }
}

class StudySkillMastery {
  const StudySkillMastery({
    required this.skill,
    required this.attempts,
    required this.correctCount,
    required this.averageResponseTimeMs,
    required this.score,
  });

  final StudySkill skill;
  final int attempts;
  final int correctCount;
  final int averageResponseTimeMs;
  final double score;

  double get accuracy => attempts == 0 ? 0 : correctCount / attempts;
}

/// Transparent optional challenge score: accuracy 70, response speed 20,
/// and hint independence 10. This score never changes SRS progress or XP.
class PracticeChallengeScore {
  const PracticeChallengeScore({
    required this.total,
    required this.accuracyPoints,
    required this.speedPoints,
    required this.hintPoints,
    required this.averageResponseTimeMs,
    required this.hintCount,
  });

  factory PracticeChallengeScore.calculate({
    required int correctCount,
    required int wrongCount,
    required Duration elapsed,
    Iterable<StudyAttemptMetric> attemptMetrics = const [],
  }) {
    final attempts = (correctCount + wrongCount).clamp(0, 1000000);
    final metrics = attemptMetrics.take(1000).toList(growable: false);
    final accuracy = attempts == 0 ? 0.0 : correctCount / attempts;
    final accuracyPoints = (accuracy.clamp(0.0, 1.0) * 70).round();
    final averageResponseTimeMs = metrics.isNotEmpty
        ? metrics.fold<int>(0, (sum, metric) => sum + metric.responseTimeMs) ~/
              metrics.length
        : attempts == 0
        ? 0
        : elapsed.inMilliseconds.clamp(0, _maximumResponseTimeMs) ~/ attempts;
    // Four seconds earns all speed points; twenty seconds or more earns none.
    final speedRatio = (1 - ((averageResponseTimeMs - 4000) / 16000)).clamp(
      0.0,
      1.0,
    );
    final speedPoints = (speedRatio * 20).round();
    final hintCount = metrics.where((metric) => metric.usedHint).length;
    final hintRatio = metrics.isEmpty ? 0.0 : hintCount / metrics.length;
    final hintPoints = ((1 - hintRatio.clamp(0.0, 1.0)) * 10).round();
    return PracticeChallengeScore(
      total: (accuracyPoints + speedPoints + hintPoints).clamp(0, 100),
      accuracyPoints: accuracyPoints,
      speedPoints: speedPoints,
      hintPoints: hintPoints,
      averageResponseTimeMs: averageResponseTimeMs,
      hintCount: hintCount,
    );
  }

  final int total;
  final int accuracyPoints;
  final int speedPoints;
  final int hintPoints;
  final int averageResponseTimeMs;
  final int hintCount;
}

class StudyMasterySnapshot {
  StudyMasterySnapshot._(this._byItemAndSkill, this.bySkill);

  factory StudyMasterySnapshot.fromAttempts(
    Iterable<StudyAttemptMetric> attempts,
  ) {
    final bounded = attempts.take(_maximumHistoryMetrics).toList();
    final itemBuckets = <String, List<StudyAttemptMetric>>{};
    final skillBuckets = <StudySkill, List<StudyAttemptMetric>>{
      for (final skill in StudySkill.values) skill: [],
    };
    for (final metric in bounded) {
      itemBuckets
          .putIfAbsent('${metric.itemId}|${metric.skill.name}', () => [])
          .add(metric);
      skillBuckets[metric.skill]!.add(metric);
    }
    final byItemAndSkill = <String, StudySkillMastery>{};
    for (final entry in itemBuckets.entries) {
      byItemAndSkill[entry.key] = _mastery(
        entry.value.first.skill,
        entry.value,
      );
    }
    final bySkill = <StudySkill, StudySkillMastery>{};
    for (final skill in StudySkill.values) {
      bySkill[skill] = _mastery(skill, skillBuckets[skill]!);
    }
    return StudyMasterySnapshot._(
      Map.unmodifiable(byItemAndSkill),
      Map.unmodifiable(bySkill),
    );
  }

  final Map<String, StudySkillMastery> _byItemAndSkill;
  final Map<StudySkill, StudySkillMastery> bySkill;

  StudySkillMastery masteryFor(String itemId, StudySkill skill) =>
      _byItemAndSkill['$itemId|${skill.name}'] ??
      StudySkillMastery(
        skill: skill,
        attempts: 0,
        correctCount: 0,
        averageResponseTimeMs: 0,
        score: 0.5,
      );

  StudySkill get weakestSkill {
    final ordered = [...StudySkill.values]
      ..sort((left, right) {
        final scoreOrder = bySkill[left]!.score.compareTo(
          bySkill[right]!.score,
        );
        if (scoreOrder != 0) return scoreOrder;
        return left.index.compareTo(right.index);
      });
    return ordered.first;
  }

  static StudySkillMastery _mastery(
    StudySkill skill,
    List<StudyAttemptMetric> metrics,
  ) {
    if (metrics.isEmpty) {
      return StudySkillMastery(
        skill: skill,
        attempts: 0,
        correctCount: 0,
        averageResponseTimeMs: 0,
        score: 0.5,
      );
    }
    final correct = metrics.where((metric) => metric.correct).length;
    final average =
        metrics.fold<int>(0, (sum, metric) => sum + metric.responseTimeMs) ~/
        metrics.length;
    final accuracy = correct / metrics.length;
    final speed = (1 - (average / _slowResponseThresholdMs)).clamp(0, 1);
    final hintPenalty =
        metrics.where((metric) => metric.usedHint).length /
        metrics.length *
        0.1;
    return StudySkillMastery(
      skill: skill,
      attempts: metrics.length,
      correctCount: correct,
      averageResponseTimeMs: average,
      score: (accuracy * 0.82 + speed * 0.18 - hintPenalty).clamp(0, 1),
    );
  }
}

class AdaptiveQueueRecommendation {
  const AdaptiveQueueRecommendation({
    required this.items,
    required this.reasonByItemId,
    required this.skillByItemId,
  });

  final List<LearningItem> items;
  final Map<String, String> reasonByItemId;
  final Map<String, StudySkill> skillByItemId;
}

class AdaptiveStudySessionEngine {
  const AdaptiveStudySessionEngine();

  AdaptiveQueueRecommendation recommend({
    required List<LearningItem> items,
    required StudyMode mode,
    required StudySessionStrategy strategy,
    required Map<String, ProgressRecord> progress,
    Iterable<StudyAttemptMetric> attemptHistory = const [],
    DateTime? now,
  }) {
    if (items.isEmpty) {
      return const AdaptiveQueueRecommendation(
        items: [],
        reasonByItemId: {},
        skillByItemId: {},
      );
    }
    final mastery = StudyMasterySnapshot.fromAttempts(attemptHistory);
    final at = now ?? DateTime.now();
    final skills = <String, StudySkill>{
      for (final (index, item) in items.indexed)
        item.id: _recommendedSkill(
          item,
          index: index,
          mode: mode,
          strategy: strategy,
          mastery: mastery,
        ),
    };
    final reasons = <String, String>{};
    for (final item in items) {
      final skill = skills[item.id]!;
      reasons[item.id] = _reason(
        item: item,
        skill: skill,
        progress: progress[item.id],
        mastery: mastery.masteryFor(item.id, skill),
        now: at,
        strategy: strategy,
      );
    }
    final ordered = switch (strategy) {
      StudySessionStrategy.custom => List<LearningItem>.of(items),
      StudySessionStrategy.adaptive => _adaptiveOrder(
        items,
        skills: skills,
        progress: progress,
        mastery: mastery,
        now: at,
      ),
      StudySessionStrategy.balanced => _balancedOrder(items, skills: skills),
    };
    return AdaptiveQueueRecommendation(
      items: List.unmodifiable(ordered),
      reasonByItemId: Map.unmodifiable(reasons),
      skillByItemId: Map.unmodifiable(skills),
    );
  }

  StudySkill _recommendedSkill(
    LearningItem item, {
    required int index,
    required StudyMode mode,
    required StudySessionStrategy strategy,
    required StudyMasterySnapshot mastery,
  }) {
    if (!_usesMixedExerciseTypes(mode)) {
      return studySkillFor(mode, item.kind, sequence: index);
    }
    final supported = <StudySkill>[
      if (item.capabilities.contains(ExerciseCapability.recognition))
        StudySkill.meaning,
      if (item.capabilities.contains(ExerciseCapability.production))
        StudySkill.writing,
      if (item.capabilities.contains(ExerciseCapability.listening))
        StudySkill.listening,
      if (item.kind == LearningItemKind.sentence &&
          (item.capabilities.contains(ExerciseCapability.cloze) ||
              item.capabilities.contains(ExerciseCapability.sentenceOrder)))
        StudySkill.sentence,
    ];
    if (supported.isEmpty) {
      return item.kind == LearningItemKind.sentence
          ? StudySkill.sentence
          : StudySkill.meaning;
    }
    if (strategy == StudySessionStrategy.balanced) {
      return supported[index % supported.length];
    }
    if (strategy == StudySessionStrategy.adaptive) {
      final ordered = [...supported]
        ..sort((left, right) {
          double score(StudySkill skill) {
            final itemMastery = mastery.masteryFor(item.id, skill);
            return itemMastery.attempts > 0
                ? itemMastery.score
                : mastery.bySkill[skill]!.score;
          }

          final scoreOrder = score(left).compareTo(score(right));
          if (scoreOrder != 0) return scoreOrder;
          return left.index.compareTo(right.index);
        });
      return ordered.first;
    }
    return studySkillFor(mode, item.kind, sequence: index);
  }

  bool _usesMixedExerciseTypes(StudyMode mode) => switch (mode) {
    StudyMode.mixed ||
    StudyMode.review ||
    StudyMode.weak ||
    StudyMode.favorites ||
    StudyMode.newItems ||
    StudyMode.words ||
    StudyMode.sentences => true,
    _ => false,
  };

  List<LearningItem> _adaptiveOrder(
    List<LearningItem> items, {
    required Map<String, StudySkill> skills,
    required Map<String, ProgressRecord> progress,
    required StudyMasterySnapshot mastery,
    required DateTime now,
  }) {
    final ordered = List<LearningItem>.of(items);
    ordered.sort((left, right) {
      final scoreOrder =
          _adaptiveScore(
            right,
            skill: skills[right.id]!,
            progress: progress[right.id],
            mastery: mastery.masteryFor(right.id, skills[right.id]!),
            now: now,
          ).compareTo(
            _adaptiveScore(
              left,
              skill: skills[left.id]!,
              progress: progress[left.id],
              mastery: mastery.masteryFor(left.id, skills[left.id]!),
              now: now,
            ),
          );
      if (scoreOrder != 0) return scoreOrder;
      return left.id.compareTo(right.id);
    });
    return ordered;
  }

  List<LearningItem> _balancedOrder(
    List<LearningItem> items, {
    required Map<String, StudySkill> skills,
  }) {
    final buckets = <String, List<LearningItem>>{};
    for (final item in items) {
      final key = '${skills[item.id]!.name}:${item.kind.name}';
      buckets.putIfAbsent(key, () => []).add(item);
    }
    final keys = buckets.keys.toList()..sort();
    final result = <LearningItem>[];
    while (result.length < items.length) {
      var added = false;
      for (final key in keys) {
        final bucket = buckets[key]!;
        if (bucket.isEmpty) continue;
        result.add(bucket.removeAt(0));
        added = true;
      }
      if (!added) break;
    }
    return result;
  }

  int _adaptiveScore(
    LearningItem item, {
    required StudySkill skill,
    required ProgressRecord? progress,
    required StudySkillMastery mastery,
    required DateTime now,
  }) {
    var score = ((1 - mastery.score) * 100).round();
    if (mastery.attempts == 0) score += 24;
    if (mastery.averageResponseTimeMs > _slowResponseThresholdMs) score += 24;
    if (progress?.lastResult == ReviewRating.again) score += 55;
    if (progress?.nextReviewAt case final due? when !due.isAfter(now)) {
      score += 32;
    }
    if (progress != null && progress.attempts > 0) {
      score += ((1 - progress.accuracy) * 45).round();
    }
    if (item.kind == LearningItemKind.sentence &&
        skill == StudySkill.sentence) {
      score += 4;
    }
    return score;
  }

  String _reason({
    required LearningItem item,
    required StudySkill skill,
    required ProgressRecord? progress,
    required StudySkillMastery mastery,
    required DateTime now,
    required StudySessionStrategy strategy,
  }) {
    if (strategy == StudySessionStrategy.custom) return '사용자가 정한 순서';
    if (strategy == StudySessionStrategy.balanced) {
      return '${skill.koreanLabel} 기술과 ${item.kind == LearningItemKind.word ? '단어' : '문장'} 비율 균형';
    }
    if (progress?.lastResult == ReviewRating.again) return '최근 오답 우선';
    if (mastery.attempts > 0 && mastery.score < 0.65) {
      return '${skill.koreanLabel} 숙련도 보강';
    }
    if (mastery.averageResponseTimeMs > _slowResponseThresholdMs) {
      return '응답 시간이 길었던 ${skill.koreanLabel} 문제';
    }
    if (progress?.nextReviewAt case final due? when !due.isAfter(now)) {
      return '복습 시점 도달';
    }
    if (mastery.attempts == 0) return '아직 측정하지 않은 ${skill.koreanLabel} 기술';
    return '${skill.koreanLabel} 숙련도 유지';
  }
}

class StudyQueuePreviewEntry {
  const StudyQueuePreviewEntry({
    required this.sequence,
    required this.kind,
    required this.skill,
    required this.reason,
  });

  final int sequence;
  final LearningItemKind kind;
  final StudySkill skill;
  final String reason;
}

class StudyQueuePreview {
  const StudyQueuePreview({
    required this.entries,
    required this.wordCount,
    required this.sentenceCount,
  });

  factory StudyQueuePreview.fromRecommendation(
    AdaptiveQueueRecommendation recommendation,
  ) {
    final entries = <StudyQueuePreviewEntry>[];
    for (final (index, item) in recommendation.items.indexed) {
      entries.add(
        StudyQueuePreviewEntry(
          sequence: index + 1,
          kind: item.kind,
          skill:
              recommendation.skillByItemId[item.id] ??
              (item.kind == LearningItemKind.sentence
                  ? StudySkill.sentence
                  : StudySkill.meaning),
          reason: recommendation.reasonByItemId[item.id] ?? '학습 큐',
        ),
      );
    }
    final words = recommendation.items
        .where((item) => item.kind == LearningItemKind.word)
        .length;
    return StudyQueuePreview(
      entries: List.unmodifiable(entries),
      wordCount: words,
      sentenceCount: recommendation.items.length - words,
    );
  }

  final List<StudyQueuePreviewEntry> entries;
  final int wordCount;
  final int sentenceCount;

  int get total => wordCount + sentenceCount;
  int get sentencePercent =>
      total == 0 ? 0 : (sentenceCount / total * 100).round();
}

class StudySessionRuntimeOptions {
  const StudySessionRuntimeOptions({
    this.strategy = StudySessionStrategy.adaptive,
    this.breakReminderMinutes = 20,
    this.showKoreanReading = true,
    this.showNativeReading = true,
    this.ttsRate = 0.45,
  });

  final StudySessionStrategy strategy;
  final int breakReminderMinutes;
  final bool showKoreanReading;
  final bool showNativeReading;
  final double ttsRate;

  StudySessionRuntimeOptions copyWith({
    StudySessionStrategy? strategy,
    int? breakReminderMinutes,
    bool? showKoreanReading,
    bool? showNativeReading,
    double? ttsRate,
  }) => StudySessionRuntimeOptions(
    strategy: strategy ?? this.strategy,
    breakReminderMinutes: breakReminderMinutes ?? this.breakReminderMinutes,
    showKoreanReading: showKoreanReading ?? this.showKoreanReading,
    showNativeReading: showNativeReading ?? this.showNativeReading,
    ttsRate: ttsRate ?? this.ttsRate,
  );

  Map<String, Object?> toJson() => {
    'strategy': strategy.name,
    'breakReminderMinutes': _validBreakMinutes(breakReminderMinutes),
    'showKoreanReading': showKoreanReading,
    'showNativeReading': showNativeReading,
    'ttsRate': ttsRate.clamp(0.2, 0.8),
  };

  factory StudySessionRuntimeOptions.fromJson(Map<String, Object?> json) {
    final strategy = _enumByName(StudySessionStrategy.values, json['strategy']);
    final breakMinutes = _exactInteger(json['breakReminderMinutes']);
    final showKorean = json['showKoreanReading'];
    final showNative = json['showNativeReading'];
    final rate = json['ttsRate'];
    if (strategy == null ||
        breakMinutes == null ||
        !const {0, 10, 20, 30}.contains(breakMinutes) ||
        showKorean is! bool ||
        showNative is! bool ||
        rate is! num ||
        !rate.isFinite ||
        rate < 0.2 ||
        rate > 0.8) {
      throw const FormatException('Invalid study session runtime options');
    }
    return StudySessionRuntimeOptions(
      strategy: strategy,
      breakReminderMinutes: breakMinutes,
      showKoreanReading: showKorean,
      showNativeReading: showNative,
      ttsRate: rate.toDouble(),
    );
  }
}

class StudyInputCheckpoint {
  const StudyInputCheckpoint({
    required this.itemId,
    required this.exerciseType,
    required this.savedAt,
    this.answerText = '',
    this.selectedChoice,
    this.orderedTokens = const [],
  });

  final String itemId;
  final String exerciseType;
  final String answerText;
  final String? selectedChoice;
  final List<String> orderedTokens;
  final DateTime savedAt;

  bool get isMeaningful =>
      answerText.isNotEmpty ||
      (selectedChoice?.isNotEmpty ?? false) ||
      orderedTokens.isNotEmpty;

  Map<String, Object?> toJson() => {
    'itemId': itemId,
    'exerciseType': exerciseType,
    'answerText': answerText,
    if (selectedChoice != null) 'selectedChoice': selectedChoice,
    'orderedTokens': orderedTokens,
    'savedAt': savedAt.toUtc().toIso8601String(),
  };

  factory StudyInputCheckpoint.fromJson(Map<String, Object?> json) {
    final itemId = json['itemId'];
    final exerciseType = json['exerciseType'];
    final answerText = json['answerText'];
    final selectedChoice = json['selectedChoice'];
    final rawTokens = json['orderedTokens'];
    final savedAt = DateTime.tryParse(json['savedAt'] as String? ?? '');
    if (itemId is! String ||
        itemId.trim().isEmpty ||
        itemId.runes.length > 160 ||
        exerciseType is! String ||
        exerciseType.trim().isEmpty ||
        exerciseType.runes.length > 40 ||
        answerText is! String ||
        answerText.runes.length > 4000 ||
        (selectedChoice != null &&
            (selectedChoice is! String ||
                selectedChoice.runes.length > 1000)) ||
        rawTokens is! List<Object?> ||
        rawTokens.length > 200 ||
        rawTokens.any(
          (value) => value is! String || value.runes.length > 160,
        ) ||
        savedAt == null) {
      throw const FormatException('Invalid study input checkpoint');
    }
    return StudyInputCheckpoint(
      itemId: itemId,
      exerciseType: exerciseType,
      answerText: answerText,
      selectedChoice: selectedChoice as String?,
      orderedTokens: List.unmodifiable(rawTokens.cast<String>()),
      savedAt: savedAt.toUtc(),
    );
  }
}

class StudyBreakSchedule {
  const StudyBreakSchedule(this.intervalMinutes)
    : assert(
        intervalMinutes == 0 ||
            intervalMinutes == 10 ||
            intervalMinutes == 20 ||
            intervalMinutes == 30,
      );

  final int intervalMinutes;

  Duration? delayUntilNext({
    required DateTime startedAt,
    required DateTime now,
    int remindersShown = 0,
  }) {
    if (intervalMinutes == 0) return null;
    final target = startedAt.toUtc().add(
      Duration(minutes: intervalMinutes * (remindersShown + 1)),
    );
    final delay = target.difference(now.toUtc());
    return delay.isNegative ? Duration.zero : delay;
  }
}

StudySkill studySkillFor(
  StudyMode mode,
  LearningItemKind kind, {
  int sequence = 0,
}) => switch (mode) {
  StudyMode.meaning => StudySkill.meaning,
  StudyMode.production || StudyMode.words => StudySkill.writing,
  StudyMode.listening => StudySkill.listening,
  StudyMode.pronunciation => StudySkill.pronunciation,
  StudyMode.cloze ||
  StudyMode.sentenceOrder ||
  StudyMode.sentences => StudySkill.sentence,
  StudyMode.mixed ||
  StudyMode.review ||
  StudyMode.weak ||
  StudyMode.favorites ||
  StudyMode.newItems =>
    kind == LearningItemKind.sentence
        ? StudySkill.sentence
        : sequence.isEven
        ? StudySkill.meaning
        : StudySkill.writing,
};

StudyErrorType studyErrorTypeFor({
  required StudySkill skill,
  required bool correct,
  required bool gaveUp,
  required int responseTimeMs,
}) {
  if (gaveUp) return StudyErrorType.gaveUp;
  if (correct) {
    return responseTimeMs > _slowResponseThresholdMs
        ? StudyErrorType.slowResponse
        : StudyErrorType.none;
  }
  return switch (skill) {
    StudySkill.meaning => StudyErrorType.meaningRecall,
    StudySkill.writing => StudyErrorType.writingAccuracy,
    StudySkill.listening => StudyErrorType.listeningRecognition,
    StudySkill.sentence => StudyErrorType.sentenceStructure,
    StudySkill.pronunciation => StudyErrorType.pronunciation,
  };
}

const _maximumResponseTimeMs = 30 * 60 * 1000;
const _slowResponseThresholdMs = 12000;
const _maximumHistoryMetrics = 5000;

T? _enumByName<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}

int? _exactInteger(Object? raw) {
  if (raw is! num || !raw.isFinite || raw != raw.round()) return null;
  return raw.toInt();
}

int _validBreakMinutes(int value) =>
    const {0, 10, 20, 30}.contains(value) ? value : 20;
