import 'session_enhancements.dart';

enum StudyAnswerDirection { learningToMeaning, meaningToLearning, mixed }

enum StudyChoiceLayout { automatic, list, grid }

enum PracticeSessionLength {
  fiveItems,
  tenItems,
  twentyItems,
  allItems,
  threeMinutes,
  fiveMinutes,
  tenMinutes,
}

enum PracticeDifficultyPreset { relaxed, balanced, challenge }

enum PracticeHistoryScope { all, excludeCorrect, wrongOnly }

enum PracticeQueueOrder { dueFirst, newFirst }

class PracticeLaunchPreferences {
  const PracticeLaunchPreferences({
    this.length = PracticeSessionLength.tenItems,
    this.itemCount = 10,
    this.difficulty = PracticeDifficultyPreset.balanced,
    this.historyScope = PracticeHistoryScope.all,
    this.queueOrder = PracticeQueueOrder.dueFirst,
    this.answerDirection = StudyAnswerDirection.mixed,
    this.gradingStrictness = StudyGradingStrictness.balanced,
    this.choiceCount = 4,
    this.recordProgress = true,
    this.hintsEnabled = true,
    this.autoAdvance = false,
    this.soundEnabled = false,
    this.largeControls = false,
  });

  final PracticeSessionLength length;
  final int itemCount;
  final PracticeDifficultyPreset difficulty;
  final PracticeHistoryScope historyScope;
  final PracticeQueueOrder queueOrder;
  final StudyAnswerDirection answerDirection;
  final StudyGradingStrictness gradingStrictness;
  final int choiceCount;
  final bool recordProgress;
  final bool hintsEnabled;
  final bool autoAdvance;
  final bool soundEnabled;
  final bool largeControls;

  PracticeLaunchPreferences copyWith({
    PracticeSessionLength? length,
    int? itemCount,
    PracticeDifficultyPreset? difficulty,
    PracticeHistoryScope? historyScope,
    PracticeQueueOrder? queueOrder,
    StudyAnswerDirection? answerDirection,
    StudyGradingStrictness? gradingStrictness,
    int? choiceCount,
    bool? recordProgress,
    bool? hintsEnabled,
    bool? autoAdvance,
    bool? soundEnabled,
    bool? largeControls,
  }) {
    return PracticeLaunchPreferences(
      length: length ?? this.length,
      itemCount: itemCount ?? this.itemCount,
      difficulty: difficulty ?? this.difficulty,
      historyScope: historyScope ?? this.historyScope,
      queueOrder: queueOrder ?? this.queueOrder,
      answerDirection: answerDirection ?? this.answerDirection,
      gradingStrictness: gradingStrictness ?? this.gradingStrictness,
      choiceCount: choiceCount ?? this.choiceCount,
      recordProgress: recordProgress ?? this.recordProgress,
      hintsEnabled: hintsEnabled ?? this.hintsEnabled,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      largeControls: largeControls ?? this.largeControls,
    );
  }

  Map<String, Object?> toJson() => {
    'length': length.name,
    'itemCount': itemCount,
    'difficulty': difficulty.name,
    'historyScope': historyScope.name,
    'queueOrder': queueOrder.name,
    'answerDirection': answerDirection.name,
    'gradingStrictness': gradingStrictness.name,
    'choiceCount': choiceCount,
    'recordProgress': recordProgress,
    'hintsEnabled': hintsEnabled,
    'autoAdvance': autoAdvance,
    'soundEnabled': soundEnabled,
    'largeControls': largeControls,
  };

  factory PracticeLaunchPreferences.fromJson(Map<String, Object?> json) {
    final rawChoiceCount = (json['choiceCount'] as num?)?.toInt() ?? 4;
    return PracticeLaunchPreferences(
      length: _enumByName(
        PracticeSessionLength.values,
        json['length'],
        PracticeSessionLength.tenItems,
      ),
      itemCount: ((json['itemCount'] as num?)?.toInt() ?? 10).clamp(1, 100),
      difficulty: _enumByName(
        PracticeDifficultyPreset.values,
        json['difficulty'],
        PracticeDifficultyPreset.balanced,
      ),
      historyScope: _enumByName(
        PracticeHistoryScope.values,
        json['historyScope'],
        PracticeHistoryScope.all,
      ),
      queueOrder: _enumByName(
        PracticeQueueOrder.values,
        json['queueOrder'],
        PracticeQueueOrder.dueFirst,
      ),
      answerDirection: _enumByName(
        StudyAnswerDirection.values,
        json['answerDirection'],
        StudyAnswerDirection.mixed,
      ),
      gradingStrictness: _enumByName(
        StudyGradingStrictness.values,
        json['gradingStrictness'],
        StudyGradingStrictness.balanced,
      ),
      choiceCount: const {2, 4, 6}.contains(rawChoiceCount)
          ? rawChoiceCount
          : 4,
      recordProgress: _boolOr(json['recordProgress'], true),
      hintsEnabled: _boolOr(json['hintsEnabled'], true),
      autoAdvance: _boolOr(json['autoAdvance'], false),
      soundEnabled: _boolOr(json['soundEnabled'], false),
      largeControls: _boolOr(json['largeControls'], false),
    );
  }
}

class PracticeCatalogPreferences {
  const PracticeCatalogPreferences({
    this.favoriteActivityIds = const {},
    this.hiddenActivityIds = const {},
    this.launchByActivityId = const {},
  });

  final Set<String> favoriteActivityIds;
  final Set<String> hiddenActivityIds;
  final Map<String, PracticeLaunchPreferences> launchByActivityId;

  PracticeLaunchPreferences launchFor(String activityId) =>
      launchByActivityId[activityId] ?? const PracticeLaunchPreferences();

  PracticeCatalogPreferences copyWith({
    Set<String>? favoriteActivityIds,
    Set<String>? hiddenActivityIds,
    Map<String, PracticeLaunchPreferences>? launchByActivityId,
  }) {
    return PracticeCatalogPreferences(
      favoriteActivityIds: Set.unmodifiable(
        favoriteActivityIds ?? this.favoriteActivityIds,
      ),
      hiddenActivityIds: Set.unmodifiable(
        hiddenActivityIds ?? this.hiddenActivityIds,
      ),
      launchByActivityId: Map.unmodifiable(
        launchByActivityId ?? this.launchByActivityId,
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'favoriteActivityIds': favoriteActivityIds.toList()..sort(),
    'hiddenActivityIds': hiddenActivityIds.toList()..sort(),
    'launchByActivityId': {
      for (final entry
          in (launchByActivityId.entries.toList()
            ..sort((left, right) => left.key.compareTo(right.key))))
        entry.key: entry.value.toJson(),
    },
  };

  factory PracticeCatalogPreferences.fromJson(Map<String, Object?> json) {
    Set<String> safeIds(Object? raw) => ((raw as List<Object?>?) ?? const [])
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && value.runes.length <= 160)
        .take(50)
        .toSet();

    final launches = <String, PracticeLaunchPreferences>{};
    final rawLaunches = json['launchByActivityId'];
    if (rawLaunches is Map) {
      for (final entry in rawLaunches.entries.take(50)) {
        final id = entry.key;
        final rawValue = entry.value;
        if (id is! String ||
            id.trim().isEmpty ||
            id.runes.length > 160 ||
            rawValue is! Map) {
          continue;
        }
        final safeValue = <String, Object?>{
          for (final valueEntry in rawValue.entries)
            if (valueEntry.key is String)
              valueEntry.key! as String: valueEntry.value,
        };
        launches[id.trim()] = PracticeLaunchPreferences.fromJson(safeValue);
      }
    }
    final hidden = safeIds(json['hiddenActivityIds']);
    return PracticeCatalogPreferences(
      favoriteActivityIds: safeIds(json['favoriteActivityIds'])
        ..removeAll(hidden),
      hiddenActivityIds: hidden,
      launchByActivityId: Map.unmodifiable(launches),
    );
  }
}

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
    this.practiceCatalog = const PracticeCatalogPreferences(),
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
  final PracticeCatalogPreferences practiceCatalog;
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
    PracticeCatalogPreferences? practiceCatalog,
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
      practiceCatalog: practiceCatalog ?? this.practiceCatalog,
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
    'practiceCatalog': practiceCatalog.toJson(),
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
      practiceCatalog: json['practiceCatalog'] is Map
          ? PracticeCatalogPreferences.fromJson(
              Map<String, Object?>.from(json['practiceCatalog']! as Map),
            )
          : const PracticeCatalogPreferences(),
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
