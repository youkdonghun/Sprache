import 'dart:math';

import 'language.dart';
import 'learning_item.dart';

/// Rules for an assessment session. Exam results are intentionally calculated
/// against the planned question count so a timeout cannot inflate accuracy.
class ExamConfiguration {
  const ExamConfiguration({
    this.questionCount = 10,
    this.timeLimit = const Duration(minutes: 10),
    this.passScore = 80,
  }) : assert(questionCount > 0),
       assert(passScore >= 1 && passScore <= 100);

  final int questionCount;
  final Duration timeLimit;
  final int passScore;

  Map<String, Object?> toJson() => {
    'questionCount': questionCount,
    'timeLimitSeconds': timeLimit.inSeconds,
    'passScore': passScore,
  };

  factory ExamConfiguration.fromJson(Map<String, Object?> json) {
    final questionCount = _exactInteger(json['questionCount']);
    final timeLimitSeconds = _exactInteger(json['timeLimitSeconds']);
    final passScore = _exactInteger(json['passScore']);
    if (questionCount == null ||
        questionCount < 1 ||
        questionCount > 100 ||
        timeLimitSeconds == null ||
        timeLimitSeconds < 60 ||
        timeLimitSeconds > 120 * 60 ||
        passScore == null ||
        passScore < 1 ||
        passScore > 100) {
      throw const FormatException('시험 설정이 올바르지 않습니다.');
    }
    return ExamConfiguration(
      questionCount: questionCount,
      timeLimit: Duration(seconds: timeLimitSeconds),
      passScore: passScore,
    );
  }

  ExamConfiguration normalizedFor(int availableQuestions) {
    final available = max(1, availableQuestions);
    return ExamConfiguration(
      questionCount: questionCount.clamp(1, available),
      timeLimit: Duration(seconds: timeLimit.inSeconds.clamp(60, 120 * 60)),
      passScore: passScore.clamp(1, 100),
    );
  }
}

class ExamReport {
  const ExamReport({
    required this.configuration,
    required this.correctCount,
    required this.answeredCount,
    required this.timedOut,
  });

  factory ExamReport.evaluate({
    required ExamConfiguration configuration,
    required int correctCount,
    required int answeredCount,
    required bool timedOut,
  }) {
    return ExamReport(
      configuration: configuration,
      correctCount: correctCount.clamp(0, configuration.questionCount),
      answeredCount: answeredCount.clamp(0, configuration.questionCount),
      timedOut: timedOut,
    );
  }

  final ExamConfiguration configuration;
  final int correctCount;
  final int answeredCount;
  final bool timedOut;

  int get unansweredCount => configuration.questionCount - answeredCount;
  int get score =>
      (correctCount / configuration.questionCount * 100).round().clamp(0, 100);
  bool get passed => score >= configuration.passScore;
}

enum LiveDifficultyLevel { supportive, standard, challenge }

extension LiveDifficultyLevelLabel on LiveDifficultyLevel {
  String get koreanLabel => switch (this) {
    LiveDifficultyLevel.supportive => '도움',
    LiveDifficultyLevel.standard => '균형',
    LiveDifficultyLevel.challenge => '도전',
  };

  String get explanation => switch (this) {
    LiveDifficultyLevel.supportive => '선택지를 줄이고 회상 단계를 낮춥니다.',
    LiveDifficultyLevel.standard => '현재 세션의 기본 난이도를 유지합니다.',
    LiveDifficultyLevel.challenge => '선택지를 늘리고 직접 회상하는 문제를 우선합니다.',
  };

  int choiceCountFor(int configuredCount) => switch (this) {
    LiveDifficultyLevel.supportive => min(3, configuredCount),
    LiveDifficultyLevel.standard => configuredCount,
    LiveDifficultyLevel.challenge => max(6, configuredCount),
  };
}

class LiveDifficultyAttempt {
  const LiveDifficultyAttempt({
    required this.correct,
    required this.responseTime,
    this.usedHint = false,
  });

  final bool correct;
  final Duration responseTime;
  final bool usedHint;
}

class LiveDifficultyDecision {
  const LiveDifficultyDecision({required this.level, required this.reason});

  final LiveDifficultyLevel level;
  final String reason;
}

/// Pure rolling-session difficulty policy. Only the five most recent answers
/// influence the next question, and a manual lock always wins.
class LiveDifficultyEngine {
  const LiveDifficultyEngine({this.windowSize = 5}) : assert(windowSize >= 3);

  final int windowSize;

  LiveDifficultyDecision decide({
    required Iterable<LiveDifficultyAttempt> attempts,
    LiveDifficultyLevel? manualLock,
  }) {
    if (manualLock != null) {
      return LiveDifficultyDecision(
        level: manualLock,
        reason: '사용자가 ${manualLock.koreanLabel} 난이도로 고정했습니다.',
      );
    }
    final recent = attempts.toList(growable: false);
    final window = recent.length <= windowSize
        ? recent
        : recent.sublist(recent.length - windowSize);
    if (window.length < 3) {
      return const LiveDifficultyDecision(
        level: LiveDifficultyLevel.standard,
        reason: '초기 3문항은 균형 난이도로 측정합니다.',
      );
    }
    final correct = window.where((attempt) => attempt.correct).length;
    final accuracy = correct / window.length;
    final averageMs =
        window.fold<int>(
          0,
          (sum, attempt) => sum + attempt.responseTime.inMilliseconds,
        ) ~/
        window.length;
    final consecutiveWrong =
        window.length >= 2 &&
        !window[window.length - 1].correct &&
        !window[window.length - 2].correct;
    if (accuracy <= 0.5 || consecutiveWrong) {
      return LiveDifficultyDecision(
        level: LiveDifficultyLevel.supportive,
        reason:
            '최근 ${window.length}문항 정확도 ${(accuracy * 100).round()}%를 반영해 한 단계 낮춰습니다.',
      );
    }
    final hintFree = window.every((attempt) => !attempt.usedHint);
    if (accuracy >= 0.85 && averageMs <= 8000 && hintFree) {
      return LiveDifficultyDecision(
        level: LiveDifficultyLevel.challenge,
        reason: '최근 ${window.length}문항을 빠르고 정확하게 풀어 한 단계 높였습니다.',
      );
    }
    return LiveDifficultyDecision(
      level: LiveDifficultyLevel.standard,
      reason: '최근 ${window.length}문항의 속도와 정확도가 균형 구간입니다.',
    );
  }
}

class ListeningDiscriminationQuestion {
  const ListeningDiscriminationQuestion({
    required this.itemId,
    required this.spokenText,
    required this.fallbackClue,
    required this.choices,
    required this.selectionBasisLabel,
  });

  final String itemId;
  final String spokenText;
  final String fallbackClue;
  final List<String> choices;
  final String selectionBasisLabel;
}

class ListeningDiscriminationReadiness {
  const ListeningDiscriminationReadiness({
    required this.canStart,
    required this.eligibleTargetCount,
    required this.maximumChoiceCount,
  });

  factory ListeningDiscriminationReadiness.evaluate(
    Iterable<LearningItem> items,
  ) {
    final source = items.toList(growable: false);
    var eligibleTargets = 0;
    var maximumChoices = 0;
    const builder = ListeningDiscriminationBuilder();
    for (final target in source) {
      final choiceCount = builder.availableChoiceCount(
        target: target,
        candidates: source,
      );
      maximumChoices = max(maximumChoices, choiceCount);
      if (choiceCount >= ListeningDiscriminationBuilder.minimumChoiceCount) {
        eligibleTargets++;
      }
    }
    return ListeningDiscriminationReadiness(
      canStart: eligibleTargets > 0,
      eligibleTargetCount: eligibleTargets,
      maximumChoiceCount: maximumChoices,
    );
  }

  final bool canStart;
  final int eligibleTargetCount;
  final int maximumChoiceCount;

  String get reason => canStart
      ? '소리로 구별할 수 있는 표현 $eligibleTargetCount개'
      : '듣기 가능한 표현과 서로 구별되는 후보가 최소 3개 필요해요.';
}

/// Builds an audio-choice question from the closest pronunciation readings
/// available in the local deck. It falls back to spelling only when neither
/// side has explicit reading data, and never offers homophone duplicates.
class ListeningDiscriminationBuilder {
  const ListeningDiscriminationBuilder();

  static const minimumChoiceCount = 3;

  bool canBuild({
    required LearningItem target,
    required Iterable<LearningItem> candidates,
  }) =>
      availableChoiceCount(target: target, candidates: candidates) >=
      minimumChoiceCount;

  int availableChoiceCount({
    required LearningItem target,
    required Iterable<LearningItem> candidates,
  }) {
    if (!target.capabilities.contains(ExerciseCapability.listening)) return 0;
    return 1 + _eligibleAlternatives(target, candidates).length;
  }

  ListeningDiscriminationQuestion build({
    required LearningItem target,
    required Iterable<LearningItem> candidates,
    int choiceCount = 4,
  }) {
    final readingScheme = _preferredReadingScheme(target);
    final alternatives = _eligibleAlternatives(target, candidates);
    final values = <String>[target.text];
    for (final item in alternatives) {
      if (values.length >= choiceCount.clamp(minimumChoiceCount, 6)) break;
      if (!values.any((value) => _normalize(value) == _normalize(item.text))) {
        values.add(item.text);
      }
    }
    values.sort((left, right) {
      final leftKey = _stableKey('${target.id}|$left');
      final rightKey = _stableKey('${target.id}|$right');
      final order = leftKey.compareTo(rightKey);
      return order != 0 ? order : left.compareTo(right);
    });
    return ListeningDiscriminationQuestion(
      itemId: target.id,
      spokenText: target.text,
      fallbackClue: target.primaryTranslation,
      choices: List.unmodifiable(values),
      selectionBasisLabel: readingScheme == null
          ? '발음 표기가 없어 철자 유사도'
          : '${readingScheme.koreanLabel} 발음 표기 유사도',
    );
  }

  List<LearningItem> _eligibleAlternatives(
    LearningItem target,
    Iterable<LearningItem> candidates,
  ) {
    final normalizedTarget = _normalize(target.text);
    final readingScheme = _preferredReadingScheme(target);
    final targetPronunciation = _pronunciationKey(
      target,
      readingScheme: readingScheme,
    );
    final alternatives =
        candidates
            .where(
              (item) =>
                  item.id != target.id &&
                  item.learningLanguage == target.learningLanguage &&
                  item.capabilities.contains(ExerciseCapability.listening) &&
                  _normalize(item.text) != normalizedTarget &&
                  _hasComparableReading(item, readingScheme) &&
                  _pronunciationKey(item, readingScheme: readingScheme) !=
                      targetPronunciation &&
                  item.text.trim().isNotEmpty,
            )
            .toList(growable: false)
          ..sort((left, right) {
            final distanceOrder =
                _editDistance(
                  targetPronunciation,
                  _pronunciationKey(left, readingScheme: readingScheme),
                ).compareTo(
                  _editDistance(
                    targetPronunciation,
                    _pronunciationKey(right, readingScheme: readingScheme),
                  ),
                );
            if (distanceOrder != 0) return distanceOrder;
            return left.id.compareTo(right.id);
          });
    final usedPronunciations = <String>{targetPronunciation};
    return [
      for (final item in alternatives)
        if (usedPronunciations.add(
          _pronunciationKey(item, readingScheme: readingScheme),
        ))
          item,
    ];
  }
}

enum SequentialMatchOutcome { learningSelected, matched, mismatch, ignored }

class SequentialMatchTransition {
  const SequentialMatchTransition({required this.state, required this.outcome});

  final SequentialMatchState state;
  final SequentialMatchOutcome outcome;
}

/// Keyboard and screen-reader friendly matching state: a learning-side choice
/// must be selected before a meaning-side choice can be evaluated.
class SequentialMatchState {
  const SequentialMatchState({
    this.selectedLearningId,
    this.matchedIds = const {},
    this.mistakes = 0,
  });

  final String? selectedLearningId;
  final Set<String> matchedIds;
  final int mistakes;

  bool get awaitingMeaning => selectedLearningId != null;

  SequentialMatchTransition selectLearning(String itemId) {
    if (matchedIds.contains(itemId)) {
      return SequentialMatchTransition(
        state: this,
        outcome: SequentialMatchOutcome.ignored,
      );
    }
    return SequentialMatchTransition(
      state: SequentialMatchState(
        selectedLearningId: itemId,
        matchedIds: matchedIds,
        mistakes: mistakes,
      ),
      outcome: SequentialMatchOutcome.learningSelected,
    );
  }

  SequentialMatchTransition selectMeaning(String itemId) {
    final selected = selectedLearningId;
    if (selected == null || matchedIds.contains(itemId)) {
      return SequentialMatchTransition(
        state: this,
        outcome: SequentialMatchOutcome.ignored,
      );
    }
    if (selected == itemId) {
      return SequentialMatchTransition(
        state: SequentialMatchState(
          matchedIds: Set.unmodifiable({...matchedIds, itemId}),
          mistakes: mistakes,
        ),
        outcome: SequentialMatchOutcome.matched,
      );
    }
    return SequentialMatchTransition(
      state: SequentialMatchState(
        matchedIds: matchedIds,
        mistakes: mistakes + 1,
      ),
      outcome: SequentialMatchOutcome.mismatch,
    );
  }
}

String _normalize(String value) => value.trim().toLowerCase();

ReadingScheme? _preferredReadingScheme(LearningItem item) {
  for (final scheme in const [
    ReadingScheme.kana,
    ReadingScheme.romaji,
    ReadingScheme.pinyin,
    ReadingScheme.hangul,
  ]) {
    if ((item.reading(scheme) ?? '').trim().isNotEmpty) return scheme;
  }
  return null;
}

bool _hasComparableReading(LearningItem item, ReadingScheme? readingScheme) {
  if (readingScheme == null) return true;
  return (item.reading(readingScheme) ?? '').trim().isNotEmpty;
}

String _pronunciationKey(
  LearningItem item, {
  required ReadingScheme? readingScheme,
}) {
  final reading = readingScheme == null ? null : item.reading(readingScheme);
  return _normalize(reading ?? item.text);
}

int _stableKey(String value) {
  var result = 17;
  for (final rune in value.runes) {
    result = (result * 37 + rune) & 0x7fffffff;
  }
  return result;
}

int _editDistance(String left, String right) {
  if (left.isEmpty) return right.length;
  if (right.isEmpty) return left.length;
  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var i = 1; i <= left.length; i++) {
    final current = List<int>.filled(right.length + 1, 0)..[0] = i;
    for (var j = 1; j <= right.length; j++) {
      final substitution = left.codeUnitAt(i - 1) == right.codeUnitAt(j - 1)
          ? 0
          : 1;
      current[j] = min(
        min(current[j - 1] + 1, previous[j] + 1),
        previous[j - 1] + substitution,
      );
    }
    previous = current;
  }
  return previous.last;
}

int? _exactInteger(Object? raw) {
  if (raw is! num || !raw.isFinite || raw != raw.round()) return null;
  return raw.toInt();
}
