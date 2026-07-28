import 'learning_item.dart';

enum StudyMode {
  mixed,
  review,
  weak,
  favorites,
  newItems,
  words,
  sentences,
  meaning,
  production,
  cloze,
  sentenceOrder,
  listening,
}

extension StudyModeLabel on StudyMode {
  String get label => switch (this) {
    StudyMode.mixed => '오늘의 혼합 학습',
    StudyMode.review => '복습 예정만',
    StudyMode.weak => '취약 표현 집중',
    StudyMode.favorites => '저장한 표현',
    StudyMode.newItems => '새 표현만',
    StudyMode.words => '단어 연습',
    StudyMode.sentences => '문장 연습',
    StudyMode.meaning => '뜻 고르기',
    StudyMode.production => '직접 쓰기',
    StudyMode.cloze => '문장 빈칸',
    StudyMode.sentenceOrder => '문장 배열',
    StudyMode.listening => '듣고 쓰기',
  };

  String get description => switch (this) {
    StudyMode.mixed => '복습과 새 표현을 균형 있게',
    StudyMode.review => '복습 시점이 된 표현부터',
    StudyMode.weak => '정확도 70% 미만 표현',
    StudyMode.favorites => '별표로 저장한 표현만 모아서',
    StudyMode.newItems => '아직 학습하지 않은 표현',
    StudyMode.words => '단어 문제만 골라서',
    StudyMode.sentences => '문장 문제만 골라서',
    StudyMode.meaning => '표현에 맞는 뜻을 선택',
    StudyMode.production => '뜻을 보고 외국어로 입력',
    StudyMode.cloze => '문맥에 맞는 표현 넣기',
    StudyMode.sentenceOrder => '흩어진 단어로 문장 만들기',
    StudyMode.listening => '발음을 듣고 직접 입력',
  };
}

enum StudyDeckScope { course, unit, favorites, personal }

extension StudyDeckScopeLabel on StudyDeckScope {
  String get label => switch (this) {
    StudyDeckScope.course => '현재 코스 전체',
    StudyDeckScope.unit => '단원 덱',
    StudyDeckScope.favorites => '저장한 표현',
    StudyDeckScope.personal => '내가 추가한 표현',
  };

  String get description => switch (this) {
    StudyDeckScope.course => '선택한 언어의 모든 학습 표현',
    StudyDeckScope.unit => '여섯 개 의사소통 단원 중 하나',
    StudyDeckScope.favorites => '별표로 저장한 나만의 복습 덱',
    StudyDeckScope.personal => '직접 입력하거나 가져온 표현',
  };
}

enum StudyDifficulty { all, newItems, learning, review, weak, mastered }

extension StudyDifficultyLabel on StudyDifficulty {
  String get label => switch (this) {
    StudyDifficulty.all => '모든 단계',
    StudyDifficulty.newItems => '처음 보는 표현',
    StudyDifficulty.learning => '학습 중',
    StudyDifficulty.review => '복습 단계',
    StudyDifficulty.weak => '취약 표현',
    StudyDifficulty.mastered => '익숙한 표현',
  };
}

const _sessionPlanValueNotProvided = Object();

class StudySessionPlan {
  const StudySessionPlan({
    this.mode = StudyMode.mixed,
    this.deck = StudyDeckScope.course,
    this.unitIndex = 0,
    this.difficulty = StudyDifficulty.all,
    this.tags = const {},
    this.levels = const {},
    this.includeWords = true,
    this.includeSentences = true,
    this.sentenceRatio = 0.3,
    this.itemLimit = 10,
    this.updatedAt,
  });

  final StudyMode mode;
  final StudyDeckScope deck;
  final int? unitIndex;
  final StudyDifficulty difficulty;
  final Set<String> tags;
  final Set<String> levels;
  final bool includeWords;
  final bool includeSentences;
  final double sentenceRatio;
  final int itemLimit;
  final DateTime? updatedAt;

  StudySessionPlan copyWith({
    StudyMode? mode,
    StudyDeckScope? deck,
    Object? unitIndex = _sessionPlanValueNotProvided,
    StudyDifficulty? difficulty,
    Set<String>? tags,
    Set<String>? levels,
    bool? includeWords,
    bool? includeSentences,
    double? sentenceRatio,
    int? itemLimit,
    Object? updatedAt = _sessionPlanValueNotProvided,
  }) {
    return StudySessionPlan(
      mode: mode ?? this.mode,
      deck: deck ?? this.deck,
      unitIndex: identical(unitIndex, _sessionPlanValueNotProvided)
          ? this.unitIndex
          : unitIndex as int?,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      levels: levels ?? this.levels,
      includeWords: includeWords ?? this.includeWords,
      includeSentences: includeSentences ?? this.includeSentences,
      sentenceRatio: sentenceRatio ?? this.sentenceRatio,
      itemLimit: itemLimit ?? this.itemLimit,
      updatedAt: identical(updatedAt, _sessionPlanValueNotProvided)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'deck': deck.name,
    'unitIndex': unitIndex,
    'difficulty': difficulty.name,
    'tags': tags.toList()..sort(),
    'levels': levels.toList()..sort(),
    'includeWords': includeWords,
    'includeSentences': includeSentences,
    'sentenceRatio': sentenceRatio,
    'itemLimit': itemLimit,
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };

  factory StudySessionPlan.fromJson(Map<String, Object?> json) {
    final includeWords = json['includeWords'] as bool? ?? true;
    final includeSentences = json['includeSentences'] as bool? ?? true;
    final hasAtLeastOneKind = includeWords || includeSentences;
    return StudySessionPlan(
      mode: StudyMode.values.firstWhere(
        (value) => value.name == json['mode'],
        orElse: () => StudyMode.mixed,
      ),
      deck: StudyDeckScope.values.firstWhere(
        (value) => value.name == json['deck'],
        orElse: () => StudyDeckScope.course,
      ),
      unitIndex: ((json['unitIndex'] as num?)?.toInt() ?? 0).clamp(0, 5),
      difficulty: StudyDifficulty.values.firstWhere(
        (value) => value.name == json['difficulty'],
        orElse: () => StudyDifficulty.all,
      ),
      tags: ((json['tags'] as List<Object?>?) ?? const [])
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty && value.runes.length <= 80)
          .take(100)
          .toSet(),
      levels: ((json['levels'] as List<Object?>?) ?? const [])
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty && value.runes.length <= 80)
          .take(100)
          .toSet(),
      includeWords: hasAtLeastOneKind ? includeWords : true,
      includeSentences: hasAtLeastOneKind ? includeSentences : true,
      sentenceRatio: ((json['sentenceRatio'] as num?)?.toDouble() ?? 0.3).clamp(
        0,
        1,
      ),
      itemLimit: ((json['itemLimit'] as num?)?.toInt() ?? 10).clamp(5, 30),
      updatedAt: switch (json['updatedAt']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
    );
  }
}

class StudyPreferences {
  const StudyPreferences({
    this.dailyGoal = 100,
    this.sessionItemLimit = 10,
    this.newItemLimit = 10,
    this.reviewLimit = 30,
    this.sentenceRatio = 0.3,
    this.showReadingAids = true,
    this.ttsRate = 0.45,
    this.excludedItemIds = const {},
    this.favoriteItemIds = const {},
    this.completedMissionIds = const {},
    this.preferredMode = StudyMode.mixed,
    this.sessionPlan = const StudySessionPlan(),
  });

  final int dailyGoal;
  final int sessionItemLimit;
  final int newItemLimit;
  final int reviewLimit;
  final double sentenceRatio;
  final bool showReadingAids;
  final double ttsRate;
  final Set<String> excludedItemIds;
  final Set<String> favoriteItemIds;
  final Set<String> completedMissionIds;
  final StudyMode preferredMode;
  final StudySessionPlan sessionPlan;

  StudyPreferences copyWith({
    int? dailyGoal,
    int? sessionItemLimit,
    int? newItemLimit,
    int? reviewLimit,
    double? sentenceRatio,
    bool? showReadingAids,
    double? ttsRate,
    Set<String>? excludedItemIds,
    Set<String>? favoriteItemIds,
    Set<String>? completedMissionIds,
    StudyMode? preferredMode,
    StudySessionPlan? sessionPlan,
  }) {
    return StudyPreferences(
      dailyGoal: dailyGoal ?? this.dailyGoal,
      sessionItemLimit: sessionItemLimit ?? this.sessionItemLimit,
      newItemLimit: newItemLimit ?? this.newItemLimit,
      reviewLimit: reviewLimit ?? this.reviewLimit,
      sentenceRatio: sentenceRatio ?? this.sentenceRatio,
      showReadingAids: showReadingAids ?? this.showReadingAids,
      ttsRate: ttsRate ?? this.ttsRate,
      excludedItemIds: excludedItemIds ?? this.excludedItemIds,
      favoriteItemIds: favoriteItemIds ?? this.favoriteItemIds,
      completedMissionIds: completedMissionIds ?? this.completedMissionIds,
      preferredMode: preferredMode ?? this.preferredMode,
      sessionPlan: sessionPlan ?? this.sessionPlan,
    );
  }

  Map<String, Object?> toJson() => {
    'dailyGoal': dailyGoal,
    'sessionItemLimit': sessionItemLimit,
    'newItemLimit': newItemLimit,
    'reviewLimit': reviewLimit,
    'sentenceRatio': sentenceRatio,
    'showReadingAids': showReadingAids,
    'ttsRate': ttsRate,
    'excludedItemIds': excludedItemIds.toList()..sort(),
    'favoriteItemIds': favoriteItemIds.toList()..sort(),
    'completedMissionIds': completedMissionIds.toList()..sort(),
    'preferredMode': preferredMode.name,
    'sessionPlan': sessionPlan.toJson(),
  };

  factory StudyPreferences.fromJson(Map<String, Object?> json) {
    final rawMode = json['preferredMode'] as String?;
    return StudyPreferences(
      dailyGoal: ((json['dailyGoal'] as num?)?.toInt() ?? 100).clamp(20, 500),
      sessionItemLimit: ((json['sessionItemLimit'] as num?)?.toInt() ?? 10)
          .clamp(5, 30),
      newItemLimit: ((json['newItemLimit'] as num?)?.toInt() ?? 10).clamp(
        0,
        50,
      ),
      reviewLimit: ((json['reviewLimit'] as num?)?.toInt() ?? 30).clamp(1, 100),
      sentenceRatio: ((json['sentenceRatio'] as num?)?.toDouble() ?? 0.3).clamp(
        0,
        1,
      ),
      showReadingAids: json['showReadingAids'] as bool? ?? true,
      ttsRate: ((json['ttsRate'] as num?)?.toDouble() ?? 0.45).clamp(0.2, 0.8),
      excludedItemIds: ((json['excludedItemIds'] as List<Object?>?) ?? const [])
          .whereType<String>()
          .toSet(),
      favoriteItemIds: ((json['favoriteItemIds'] as List<Object?>?) ?? const [])
          .whereType<String>()
          .toSet(),
      completedMissionIds:
          ((json['completedMissionIds'] as List<Object?>?) ?? const [])
              .whereType<String>()
              .toSet(),
      preferredMode: StudyMode.values.firstWhere(
        (mode) => mode.name == rawMode,
        orElse: () => StudyMode.mixed,
      ),
      sessionPlan: json['sessionPlan'] is Map
          ? StudySessionPlan.fromJson(
              Map<String, Object?>.from(json['sessionPlan']! as Map),
            )
          : const StudySessionPlan(),
    );
  }

  bool includes(LearningItem item) => !excludedItemIds.contains(item.id);

  bool isFavorite(String itemId) => favoriteItemIds.contains(itemId);

  bool hasCompletedMission(String courseId, int unitIndex) =>
      completedMissionIds.contains('$courseId:$unitIndex');
}
