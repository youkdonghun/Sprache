import 'answer_normalizer.dart';
import 'adaptive_study_session.dart';
import 'learning_item.dart';
import 'progress.dart';
import 'session_enhancements.dart';
import 'study_interaction_preferences.dart';
import 'study_preferences.dart';
import 'study_runtime_modes.dart';

extension StudyModeAnswerDirectionSupport on StudyMode {
  bool get allowsAnswerDirectionOverride => switch (this) {
    StudyMode.mixed ||
    StudyMode.review ||
    StudyMode.weak ||
    StudyMode.favorites ||
    StudyMode.newItems ||
    StudyMode.words ||
    StudyMode.sentences => true,
    StudyMode.meaning ||
    StudyMode.production ||
    StudyMode.cloze ||
    StudyMode.sentenceOrder ||
    StudyMode.listening ||
    StudyMode.pronunciation => false,
  };

  StudyAnswerDirection get effectiveFixedAnswerDirection => switch (this) {
    StudyMode.production ||
    StudyMode.sentenceOrder ||
    StudyMode.pronunciation => StudyAnswerDirection.meaningToLearning,
    StudyMode.meaning ||
    StudyMode.cloze ||
    StudyMode.listening => StudyAnswerDirection.learningToMeaning,
    _ => StudyAnswerDirection.mixed,
  };

  String get answerDirectionExplanation => switch (this) {
    StudyMode.meaning => '뜻 고르기는 외국어에서 한국어 방향으로 고정됩니다.',
    StudyMode.production => '직접 쓰기는 한국어에서 외국어 방향으로 고정됩니다.',
    StudyMode.cloze => '문장 빈칸은 원문의 빈칸을 채우는 방식으로 고정됩니다.',
    StudyMode.sentenceOrder => '문장 배열은 뜻을 보고 원문을 만드는 방식으로 고정됩니다.',
    StudyMode.listening => '듣고 쓰기는 들은 외국어를 그대로 입력하는 방식으로 고정됩니다.',
    StudyMode.pronunciation => '발음 따라하기는 목표 외국어를 듣고 말하는 방식으로 고정됩니다.',
    _ => '이번 세션에서 문제와 정답의 언어 방향을 선택할 수 있습니다.',
  };
}

extension StudyGradingStrictnessLabel on StudyGradingStrictness {
  String get koreanLabel => switch (this) {
    StudyGradingStrictness.lenient => '관대',
    StudyGradingStrictness.balanced => '균형',
    StudyGradingStrictness.strict => '엄격',
  };

  String get description => switch (this) {
    StudyGradingStrictness.lenient => '문장부호와 한 글자 오타를 허용합니다.',
    StudyGradingStrictness.balanced => '입력형 문제만 긴 답의 한 글자 오타를 허용합니다.',
    StudyGradingStrictness.strict => '문장부호를 포함해 정확히 일치해야 합니다.',
  };

  AnswerPolicy answerPolicy({required bool typedResponse}) => switch (this) {
    StudyGradingStrictness.lenient => const AnswerPolicy(allowTypo: true),
    StudyGradingStrictness.balanced => AnswerPolicy(allowTypo: typedResponse),
    StudyGradingStrictness.strict => const AnswerPolicy(
      caseSensitive: true,
      ignorePunctuation: false,
    ),
  };
}

enum PracticeInputProfile { standard, accessible }

extension PracticeInputProfileLabel on PracticeInputProfile {
  String get koreanLabel => switch (this) {
    PracticeInputProfile.standard => '기본 입력',
    PracticeInputProfile.accessible => '편한 입력',
  };

  String get description => switch (this) {
    PracticeInputProfile.standard => '컴팩트한 조작과 설정된 자동 넘김을 사용합니다.',
    PracticeInputProfile.accessible => '큰 버튼, 수동 넘김, 시간 제한 없는 게임을 사용합니다.',
  };

  double get minimumControlHeight =>
      this == PracticeInputProfile.accessible ? 64 : 52;

  bool get allowsAutomaticAdvance => this == PracticeInputProfile.standard;

  bool get allowsTimedChallenge => this == PracticeInputProfile.standard;
}

class QuizSessionOptions {
  const QuizSessionOptions({
    required this.answerDirection,
    required this.gradingStrength,
    required this.inputProfile,
    this.strategy = StudySessionStrategy.adaptive,
    this.breakReminderMinutes = 20,
    this.showKoreanReading = true,
    this.showNativeReading = true,
    this.ttsRate = 0.45,
    this.liveDifficultyLock,
  });

  final StudyAnswerDirection answerDirection;
  final StudyGradingStrictness gradingStrength;
  final PracticeInputProfile inputProfile;
  final StudySessionStrategy strategy;
  final int breakReminderMinutes;
  final bool showKoreanReading;
  final bool showNativeReading;
  final double ttsRate;
  final LiveDifficultyLevel? liveDifficultyLock;

  StudySessionRuntimeOptions get runtimeOptions => StudySessionRuntimeOptions(
    strategy: strategy,
    breakReminderMinutes: breakReminderMinutes,
    showKoreanReading: showKoreanReading,
    showNativeReading: showNativeReading,
    ttsRate: ttsRate,
    liveDifficultyLock: liveDifficultyLock,
  );

  QuizSessionOptions copyWith({
    StudyAnswerDirection? answerDirection,
    StudyGradingStrictness? gradingStrength,
    PracticeInputProfile? inputProfile,
    StudySessionStrategy? strategy,
    int? breakReminderMinutes,
    bool? showKoreanReading,
    bool? showNativeReading,
    double? ttsRate,
    Object? liveDifficultyLock = _quizOptionNotProvided,
  }) {
    return QuizSessionOptions(
      answerDirection: answerDirection ?? this.answerDirection,
      gradingStrength: gradingStrength ?? this.gradingStrength,
      inputProfile: inputProfile ?? this.inputProfile,
      strategy: strategy ?? this.strategy,
      breakReminderMinutes: breakReminderMinutes ?? this.breakReminderMinutes,
      showKoreanReading: showKoreanReading ?? this.showKoreanReading,
      showNativeReading: showNativeReading ?? this.showNativeReading,
      ttsRate: ttsRate ?? this.ttsRate,
      liveDifficultyLock: identical(liveDifficultyLock, _quizOptionNotProvided)
          ? this.liveDifficultyLock
          : liveDifficultyLock as LiveDifficultyLevel?,
    );
  }
}

const _quizOptionNotProvided = Object();

class QuizAttemptReview {
  const QuizAttemptReview({
    required this.sequence,
    required this.itemId,
    required this.prompt,
    required this.expectedAnswer,
    required this.userAnswer,
    required this.exerciseType,
    required this.correct,
    required this.rating,
    required this.usedHint,
    this.correctionLabel,
  });

  final int sequence;
  final String itemId;
  final String prompt;
  final String expectedAnswer;
  final String userAnswer;
  final String exerciseType;
  final bool correct;
  final ReviewRating rating;
  final bool usedHint;
  final String? correctionLabel;

  Map<String, Object?> toJson() => {
    'sequence': sequence,
    'itemId': itemId,
    'prompt': prompt,
    'expectedAnswer': expectedAnswer,
    'userAnswer': userAnswer,
    'exerciseType': exerciseType,
    'correct': correct,
    'rating': rating.name,
    'usedHint': usedHint,
    if (correctionLabel != null) 'correctionLabel': correctionLabel,
  };

  factory QuizAttemptReview.fromJson(Map<String, Object?> json) {
    final sequence = _quizReviewInteger(json['sequence']);
    final itemId = json['itemId'];
    final prompt = json['prompt'];
    final expectedAnswer = json['expectedAnswer'];
    final userAnswer = json['userAnswer'];
    final exerciseType = json['exerciseType'];
    final correct = json['correct'];
    final ratingName = json['rating'];
    final usedHint = json['usedHint'];
    final correctionLabel = json['correctionLabel'];
    final rating = ratingName is String
        ? ReviewRating.values
              .where((candidate) => candidate.name == ratingName)
              .firstOrNull
        : null;
    if (sequence == null ||
        sequence < 1 ||
        sequence > 1000000 ||
        !_validQuizReviewText(itemId, maximumLength: 160) ||
        !_validQuizReviewText(prompt, maximumLength: 4000) ||
        !_validQuizReviewText(expectedAnswer, maximumLength: 4000) ||
        userAnswer is! String ||
        userAnswer.runes.length > 4000 ||
        !_validQuizReviewText(exerciseType, maximumLength: 80) ||
        correct is! bool ||
        rating == null ||
        usedHint is! bool ||
        (correctionLabel != null &&
            (correctionLabel is! String ||
                correctionLabel.runes.length > 400))) {
      throw const FormatException('Invalid quiz attempt review');
    }
    return QuizAttemptReview(
      sequence: sequence,
      itemId: itemId as String,
      prompt: prompt as String,
      expectedAnswer: expectedAnswer as String,
      userAnswer: userAnswer,
      exerciseType: exerciseType as String,
      correct: correct,
      rating: rating,
      usedHint: usedHint,
      correctionLabel: correctionLabel as String?,
    );
  }

  QuizAttemptReview copyWith({
    bool? correct,
    ReviewRating? rating,
    Object? correctionLabel = _keepCorrectionLabel,
  }) {
    return QuizAttemptReview(
      sequence: sequence,
      itemId: itemId,
      prompt: prompt,
      expectedAnswer: expectedAnswer,
      userAnswer: userAnswer,
      exerciseType: exerciseType,
      correct: correct ?? this.correct,
      rating: rating ?? this.rating,
      usedHint: usedHint,
      correctionLabel: identical(correctionLabel, _keepCorrectionLabel)
          ? this.correctionLabel
          : correctionLabel as String?,
    );
  }

  int get earnedXp => switch (rating) {
    ReviewRating.again => 5,
    ReviewRating.hard => 8,
    ReviewRating.good => 10,
    ReviewRating.easy => 15,
  };
}

const _keepCorrectionLabel = Object();

int? _quizReviewInteger(Object? raw) {
  if (raw is! num || !raw.isFinite || raw != raw.round()) return null;
  return raw.toInt();
}

bool _validQuizReviewText(Object? raw, {required int maximumLength}) =>
    raw is String && raw.trim().isNotEmpty && raw.runes.length <= maximumLength;

class QuizRepairAdvisor {
  const QuizRepairAdvisor({this.failureThreshold = 2});

  final int failureThreshold;

  bool shouldOfferRepair(int failureCount) => failureCount >= failureThreshold;
}

enum MatchSprintMode { timed, tenPairs }

extension MatchSprintModeLabel on MatchSprintMode {
  String get koreanLabel => switch (this) {
    MatchSprintMode.timed => '60초',
    MatchSprintMode.tenPairs => '10쌍',
  };
}

class MatchSprintPair {
  const MatchSprintPair({
    required this.itemId,
    required this.learningText,
    required this.meaningText,
  });

  final String itemId;
  final String learningText;
  final String meaningText;
}

class MatchSprintDeck {
  const MatchSprintDeck(this.pairs);

  final List<MatchSprintPair> pairs;

  factory MatchSprintDeck.fromItems(
    Iterable<LearningItem> items, {
    int maximumPairs = 10,
  }) {
    final learningTexts = <String>{};
    final meaningTexts = <String>{};
    final pairs = <MatchSprintPair>[];
    for (final item in items) {
      final learning = item.text.trim();
      final meaning = item.primaryTranslation.trim();
      if (learning.isEmpty || meaning.isEmpty) continue;
      final learningKey = _matchKey(learning);
      final meaningKey = _matchKey(meaning);
      if (!learningTexts.add(learningKey) || !meaningTexts.add(meaningKey)) {
        continue;
      }
      pairs.add(
        MatchSprintPair(
          itemId: item.id,
          learningText: learning,
          meaningText: meaning,
        ),
      );
      if (pairs.length >= maximumPairs) break;
    }
    return MatchSprintDeck(List.unmodifiable(pairs));
  }

  bool get canStart => pairs.length >= 2;
}

String _matchKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
