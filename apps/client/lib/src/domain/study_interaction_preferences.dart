enum StudyAnswerDirection { learningToMeaning, meaningToLearning, mixed }

enum StudyChoiceLayout { automatic, list, grid }

const _interactionTimestampNotProvided = Object();

class StudyInteractionPreferences {
  const StudyInteractionPreferences({
    this.autoPlayQuestionAudio = false,
    this.autoPlayAnswerAudio = false,
    this.preferOfflineVoice = true,
    this.audioRepeatCount = 1,
    this.showKoreanReading = true,
    this.showNativeReading = true,
    this.answerDirection = StudyAnswerDirection.mixed,
    this.choiceLayout = StudyChoiceLayout.automatic,
    this.shuffleChoices = true,
    this.autoAdvanceCorrect = false,
    this.autoAdvanceDelayMs = 900,
    this.updatedAt,
  });

  final bool autoPlayQuestionAudio;
  final bool autoPlayAnswerAudio;
  final bool preferOfflineVoice;
  final int audioRepeatCount;
  final bool showKoreanReading;
  final bool showNativeReading;
  final StudyAnswerDirection answerDirection;
  final StudyChoiceLayout choiceLayout;
  final bool shuffleChoices;
  final bool autoAdvanceCorrect;
  final int autoAdvanceDelayMs;
  final DateTime? updatedAt;

  StudyInteractionPreferences copyWith({
    bool? autoPlayQuestionAudio,
    bool? autoPlayAnswerAudio,
    bool? preferOfflineVoice,
    int? audioRepeatCount,
    bool? showKoreanReading,
    bool? showNativeReading,
    StudyAnswerDirection? answerDirection,
    StudyChoiceLayout? choiceLayout,
    bool? shuffleChoices,
    bool? autoAdvanceCorrect,
    int? autoAdvanceDelayMs,
    Object? updatedAt = _interactionTimestampNotProvided,
  }) {
    return StudyInteractionPreferences(
      autoPlayQuestionAudio:
          autoPlayQuestionAudio ?? this.autoPlayQuestionAudio,
      autoPlayAnswerAudio: autoPlayAnswerAudio ?? this.autoPlayAnswerAudio,
      preferOfflineVoice: preferOfflineVoice ?? this.preferOfflineVoice,
      audioRepeatCount: audioRepeatCount ?? this.audioRepeatCount,
      showKoreanReading: showKoreanReading ?? this.showKoreanReading,
      showNativeReading: showNativeReading ?? this.showNativeReading,
      answerDirection: answerDirection ?? this.answerDirection,
      choiceLayout: choiceLayout ?? this.choiceLayout,
      shuffleChoices: shuffleChoices ?? this.shuffleChoices,
      autoAdvanceCorrect: autoAdvanceCorrect ?? this.autoAdvanceCorrect,
      autoAdvanceDelayMs: autoAdvanceDelayMs ?? this.autoAdvanceDelayMs,
      updatedAt: identical(updatedAt, _interactionTimestampNotProvided)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  Map<String, Object?> toJson() => {
    'autoPlayQuestionAudio': autoPlayQuestionAudio,
    'autoPlayAnswerAudio': autoPlayAnswerAudio,
    'preferOfflineVoice': preferOfflineVoice,
    'audioRepeatCount': audioRepeatCount,
    'showKoreanReading': showKoreanReading,
    'showNativeReading': showNativeReading,
    'answerDirection': answerDirection.name,
    'choiceLayout': choiceLayout.name,
    'shuffleChoices': shuffleChoices,
    'autoAdvanceCorrect': autoAdvanceCorrect,
    'autoAdvanceDelayMs': autoAdvanceDelayMs,
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };

  factory StudyInteractionPreferences.fromJson(Map<String, Object?> json) {
    return StudyInteractionPreferences(
      autoPlayQuestionAudio: _boolOr(json['autoPlayQuestionAudio'], false),
      autoPlayAnswerAudio: _boolOr(json['autoPlayAnswerAudio'], false),
      preferOfflineVoice: _boolOr(json['preferOfflineVoice'], true),
      audioRepeatCount: ((json['audioRepeatCount'] as num?)?.toInt() ?? 1)
          .clamp(1, 3),
      showKoreanReading: _boolOr(json['showKoreanReading'], true),
      showNativeReading: _boolOr(json['showNativeReading'], true),
      answerDirection: _enumByName(
        StudyAnswerDirection.values,
        json['answerDirection'],
        StudyAnswerDirection.mixed,
      ),
      choiceLayout: _enumByName(
        StudyChoiceLayout.values,
        json['choiceLayout'],
        StudyChoiceLayout.automatic,
      ),
      shuffleChoices: _boolOr(json['shuffleChoices'], true),
      autoAdvanceCorrect: _boolOr(json['autoAdvanceCorrect'], false),
      autoAdvanceDelayMs: ((json['autoAdvanceDelayMs'] as num?)?.toInt() ?? 900)
          .clamp(300, 3000),
      updatedAt: switch (json['updatedAt']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
    );
  }
}

bool _boolOr(Object? raw, bool fallback) => raw is bool ? raw : fallback;

T _enumByName<T extends Enum>(Iterable<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
