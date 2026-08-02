import 'app_experience_preferences.dart';
import 'content_management.dart';
import 'import_distribution.dart';
import 'learning_item.dart';
import 'learning_group.dart';
import 'onboarding_profile.dart';
import 'session_enhancements.dart';
import 'smart_collection.dart';
import 'study_interaction_preferences.dart';
import 'study_limits.dart';
import 'study_subject.dart';

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
  pronunciation,
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
    StudyMode.pronunciation => '발음 따라하기',
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
    StudyMode.pronunciation => '목표 발음을 듣고 직접 말하기',
  };
}

enum StudyDeckScope { course, unit, favorites, personal, selected }

extension StudyDeckScopeLabel on StudyDeckScope {
  String get label => switch (this) {
    StudyDeckScope.course => '현재 코스 전체',
    StudyDeckScope.unit => '단원 덱',
    StudyDeckScope.favorites => '저장한 표현',
    StudyDeckScope.personal => '내가 추가한 표현',
    StudyDeckScope.selected => '직접 고른 표현',
  };

  String get description => switch (this) {
    StudyDeckScope.course => '선택한 언어의 모든 학습 표현',
    StudyDeckScope.unit => '여섯 개 의사소통 단원 중 하나',
    StudyDeckScope.favorites => '별표로 저장한 나만의 복습 덱',
    StudyDeckScope.personal => '직접 입력하거나 가져온 표현',
    StudyDeckScope.selected => '이번 퀴즈에 넣을 단어와 문장을 직접 선택',
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

enum StudyQueuePriority { dueFirst, newFirst }

extension StudyQueuePriorityLabel on StudyQueuePriority {
  String get label => switch (this) {
    StudyQueuePriority.dueFirst => '복습 먼저',
    StudyQueuePriority.newFirst => '새 자료 먼저',
  };
}

enum StudyHistoryFilter { all, excludeCorrect, wrongOnly }

extension StudyHistoryFilterLabel on StudyHistoryFilter {
  String get label => switch (this) {
    StudyHistoryFilter.all => '모두 포함',
    StudyHistoryFilter.excludeCorrect => '맞힌 항목 제외',
    StudyHistoryFilter.wrongOnly => '틀린 항목만',
  };
}

const _sessionPlanValueNotProvided = Object();

class StudySessionPlan {
  const StudySessionPlan({
    this.planId = '',
    this.subjectId = '',
    this.mode = StudyMode.mixed,
    this.deck = StudyDeckScope.course,
    this.unitIndex = 0,
    this.difficulty = StudyDifficulty.all,
    this.queuePriority = StudyQueuePriority.dueFirst,
    this.historyFilter = StudyHistoryFilter.all,
    this.groupIds = const {},
    this.tags = const {},
    this.levels = const {},
    this.includeWords = true,
    this.includeSentences = true,
    this.sentenceRatio = 0.3,
    this.itemLimit = 10,
    this.lengthMode = StudySessionLengthMode.itemCount,
    this.timeBudgetMinutes = 5,
    this.recordProgress = true,
    this.answerDirectionOverride,
    this.gradingStrictness = StudyGradingStrictness.balanced,
    this.choiceCount = 4,
    this.hintsEnabled = true,
    this.autoAdvanceOverride,
    this.soundEffectsOverride,
    this.largeControls = false,
    this.examSchedule,
    this.backlogRecovery = const BacklogRecoverySettings(),
    this.title = '',
    this.scheduledAt,
    this.routineName = '',
    this.routineWeekdays = const {},
    this.routineMinuteOfDay,
    this.routineOrder = 0,
    this.selectedItemIds = const {},
    this.updatedAt,
  });

  final String planId;
  final String subjectId;
  final StudyMode mode;
  final StudyDeckScope deck;
  final int? unitIndex;
  final StudyDifficulty difficulty;
  final StudyQueuePriority queuePriority;
  final StudyHistoryFilter historyFilter;
  final Set<String> groupIds;
  final Set<String> tags;
  final Set<String> levels;
  final bool includeWords;
  final bool includeSentences;
  final double sentenceRatio;
  final int itemLimit;
  final StudySessionLengthMode lengthMode;
  final int timeBudgetMinutes;
  final bool recordProgress;
  final StudyAnswerDirection? answerDirectionOverride;
  final StudyGradingStrictness gradingStrictness;
  final int choiceCount;
  final bool hintsEnabled;
  final bool? autoAdvanceOverride;
  final bool? soundEffectsOverride;
  final bool largeControls;
  final ExamSchedule? examSchedule;
  final BacklogRecoverySettings backlogRecovery;
  final String title;
  final DateTime? scheduledAt;
  final String routineName;
  final Set<int> routineWeekdays;
  final int? routineMinuteOfDay;
  final int routineOrder;
  final Set<String> selectedItemIds;
  final DateTime? updatedAt;

  int effectiveItemLimit({double averageSecondsPerItem = 30}) {
    final normalizedSeconds = averageSecondsPerItem.clamp(5, 300);
    final timeBased = ((timeBudgetMinutes * 60) / normalizedSeconds).round();
    var limit = lengthMode == StudySessionLengthMode.timeBudget
        ? timeBased
        : itemLimit;
    if (backlogRecovery.enabled) {
      limit = limit.clamp(1, backlogRecovery.dailyLimit);
    }
    return limit.clamp(
      StudyLimits.minSessionItems,
      StudyLimits.maxSessionItems,
    );
  }

  StudySessionPlan copyWith({
    String? planId,
    String? subjectId,
    StudyMode? mode,
    StudyDeckScope? deck,
    Object? unitIndex = _sessionPlanValueNotProvided,
    StudyDifficulty? difficulty,
    StudyQueuePriority? queuePriority,
    StudyHistoryFilter? historyFilter,
    Set<String>? groupIds,
    Set<String>? tags,
    Set<String>? levels,
    bool? includeWords,
    bool? includeSentences,
    double? sentenceRatio,
    int? itemLimit,
    StudySessionLengthMode? lengthMode,
    int? timeBudgetMinutes,
    bool? recordProgress,
    Object? answerDirectionOverride = _sessionPlanValueNotProvided,
    StudyGradingStrictness? gradingStrictness,
    int? choiceCount,
    bool? hintsEnabled,
    Object? autoAdvanceOverride = _sessionPlanValueNotProvided,
    Object? soundEffectsOverride = _sessionPlanValueNotProvided,
    bool? largeControls,
    Object? examSchedule = _sessionPlanValueNotProvided,
    BacklogRecoverySettings? backlogRecovery,
    String? title,
    Object? scheduledAt = _sessionPlanValueNotProvided,
    String? routineName,
    Set<int>? routineWeekdays,
    Object? routineMinuteOfDay = _sessionPlanValueNotProvided,
    int? routineOrder,
    Set<String>? selectedItemIds,
    Object? updatedAt = _sessionPlanValueNotProvided,
  }) {
    return StudySessionPlan(
      planId: planId ?? this.planId,
      subjectId: subjectId ?? this.subjectId,
      mode: mode ?? this.mode,
      deck: deck ?? this.deck,
      unitIndex: identical(unitIndex, _sessionPlanValueNotProvided)
          ? this.unitIndex
          : unitIndex as int?,
      difficulty: difficulty ?? this.difficulty,
      queuePriority: queuePriority ?? this.queuePriority,
      historyFilter: historyFilter ?? this.historyFilter,
      groupIds: groupIds ?? this.groupIds,
      tags: tags ?? this.tags,
      levels: levels ?? this.levels,
      includeWords: includeWords ?? this.includeWords,
      includeSentences: includeSentences ?? this.includeSentences,
      sentenceRatio: sentenceRatio ?? this.sentenceRatio,
      itemLimit: itemLimit ?? this.itemLimit,
      lengthMode: lengthMode ?? this.lengthMode,
      timeBudgetMinutes: timeBudgetMinutes ?? this.timeBudgetMinutes,
      recordProgress: recordProgress ?? this.recordProgress,
      answerDirectionOverride:
          identical(answerDirectionOverride, _sessionPlanValueNotProvided)
          ? this.answerDirectionOverride
          : answerDirectionOverride as StudyAnswerDirection?,
      gradingStrictness: gradingStrictness ?? this.gradingStrictness,
      choiceCount: choiceCount ?? this.choiceCount,
      hintsEnabled: hintsEnabled ?? this.hintsEnabled,
      autoAdvanceOverride:
          identical(autoAdvanceOverride, _sessionPlanValueNotProvided)
          ? this.autoAdvanceOverride
          : autoAdvanceOverride as bool?,
      soundEffectsOverride:
          identical(soundEffectsOverride, _sessionPlanValueNotProvided)
          ? this.soundEffectsOverride
          : soundEffectsOverride as bool?,
      largeControls: largeControls ?? this.largeControls,
      examSchedule: identical(examSchedule, _sessionPlanValueNotProvided)
          ? this.examSchedule
          : examSchedule as ExamSchedule?,
      backlogRecovery: backlogRecovery ?? this.backlogRecovery,
      title: title ?? this.title,
      scheduledAt: identical(scheduledAt, _sessionPlanValueNotProvided)
          ? this.scheduledAt
          : scheduledAt as DateTime?,
      routineName: routineName ?? this.routineName,
      routineWeekdays: routineWeekdays ?? this.routineWeekdays,
      routineMinuteOfDay:
          identical(routineMinuteOfDay, _sessionPlanValueNotProvided)
          ? this.routineMinuteOfDay
          : routineMinuteOfDay as int?,
      routineOrder: routineOrder ?? this.routineOrder,
      selectedItemIds: selectedItemIds ?? this.selectedItemIds,
      updatedAt: identical(updatedAt, _sessionPlanValueNotProvided)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  Map<String, Object?> toJson() => {
    'planId': planId,
    'subjectId': subjectId,
    'mode': mode.name,
    'deck': deck.name,
    'unitIndex': unitIndex,
    'difficulty': difficulty.name,
    'queuePriority': queuePriority.name,
    'historyFilter': historyFilter.name,
    'groupIds': groupIds.toList()..sort(),
    'tags': tags.toList()..sort(),
    'levels': levels.toList()..sort(),
    'includeWords': includeWords,
    'includeSentences': includeSentences,
    'sentenceRatio': sentenceRatio,
    'itemLimit': itemLimit,
    'lengthMode': lengthMode.name,
    'timeBudgetMinutes': timeBudgetMinutes,
    'recordProgress': recordProgress,
    if (answerDirectionOverride != null)
      'answerDirectionOverride': answerDirectionOverride!.name,
    'gradingStrictness': gradingStrictness.name,
    'choiceCount': choiceCount,
    'hintsEnabled': hintsEnabled,
    if (autoAdvanceOverride != null) 'autoAdvanceOverride': autoAdvanceOverride,
    if (soundEffectsOverride != null)
      'soundEffectsOverride': soundEffectsOverride,
    'largeControls': largeControls,
    if (examSchedule != null) 'examSchedule': examSchedule!.toJson(),
    'backlogRecovery': backlogRecovery.toJson(),
    'title': title,
    'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
    if (routineName.isNotEmpty) 'routineName': routineName,
    if (routineWeekdays.isNotEmpty)
      'routineWeekdays': routineWeekdays.toList()..sort(),
    if (routineMinuteOfDay != null)
      'routineMinuteOfDay': routineMinuteOfDay!.clamp(0, 1439),
    if (routineName.isNotEmpty) 'routineOrder': routineOrder.clamp(0, 19),
    'selectedItemIds': selectedItemIds.toList()..sort(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };

  factory StudySessionPlan.fromJson(Map<String, Object?> json) {
    final includeWords = json['includeWords'] as bool? ?? true;
    final includeSentences = json['includeSentences'] as bool? ?? true;
    final hasAtLeastOneKind = includeWords || includeSentences;
    return StudySessionPlan(
      planId: String.fromCharCodes(
        (json['planId'] as String? ?? '').trim().runes.take(80),
      ),
      subjectId: _safeSubjectId(json['subjectId'], fallback: ''),
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
      queuePriority: StudyQueuePriority.values.firstWhere(
        (value) => value.name == json['queuePriority'],
        orElse: () => StudyQueuePriority.dueFirst,
      ),
      historyFilter: StudyHistoryFilter.values.firstWhere(
        (value) => value.name == json['historyFilter'],
        orElse: () => StudyHistoryFilter.all,
      ),
      groupIds: ((json['groupIds'] as List<Object?>?) ?? const [])
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty && value.runes.length <= 160)
          .take(100)
          .toSet(),
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
      itemLimit: ((json['itemLimit'] as num?)?.toInt() ?? 10).clamp(
        StudyLimits.minSessionItems,
        StudyLimits.maxSessionItems,
      ),
      lengthMode: StudySessionLengthMode.values.firstWhere(
        (value) => value.name == json['lengthMode'],
        orElse: () => StudySessionLengthMode.itemCount,
      ),
      timeBudgetMinutes: ((json['timeBudgetMinutes'] as num?)?.toInt() ?? 5)
          .clamp(2, 15),
      recordProgress: json['recordProgress'] != false,
      answerDirectionOverride: StudyAnswerDirection.values
          .where((value) => value.name == json['answerDirectionOverride'])
          .firstOrNull,
      gradingStrictness: StudyGradingStrictness.values.firstWhere(
        (value) => value.name == json['gradingStrictness'],
        orElse: () => StudyGradingStrictness.balanced,
      ),
      choiceCount:
          const {2, 4, 6}.contains((json['choiceCount'] as num?)?.toInt())
          ? (json['choiceCount']! as num).toInt()
          : 4,
      hintsEnabled: json['hintsEnabled'] != false,
      autoAdvanceOverride: json['autoAdvanceOverride'] is bool
          ? json['autoAdvanceOverride']! as bool
          : null,
      soundEffectsOverride: json['soundEffectsOverride'] is bool
          ? json['soundEffectsOverride']! as bool
          : null,
      largeControls: json['largeControls'] == true,
      examSchedule: switch (json['examSchedule']) {
        final Map value => ExamSchedule.fromJson(
          Map<String, Object?>.from(value),
        ),
        _ => null,
      },
      backlogRecovery: switch (json['backlogRecovery']) {
        final Map value => BacklogRecoverySettings.fromJson(
          Map<String, Object?>.from(value),
        ),
        _ => const BacklogRecoverySettings(),
      },
      title: String.fromCharCodes(
        (json['title'] as String? ?? '').trim().runes.take(60),
      ),
      scheduledAt: switch (json['scheduledAt']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
      routineName: String.fromCharCodes(
        (json['routineName'] as String? ?? '').trim().runes.take(40),
      ),
      routineWeekdays: ((json['routineWeekdays'] as List<Object?>?) ?? const [])
          .whereType<num>()
          .map((value) => value.toInt())
          .where(
            (value) => value >= DateTime.monday && value <= DateTime.sunday,
          )
          .take(7)
          .toSet(),
      routineMinuteOfDay: switch (json['routineMinuteOfDay']) {
        final num value => value.toInt().clamp(0, 1439),
        _ => null,
      },
      routineOrder: ((json['routineOrder'] as num?)?.toInt() ?? 0).clamp(0, 19),
      selectedItemIds: ((json['selectedItemIds'] as List<Object?>?) ?? const [])
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty && value.runes.length <= 160)
          .take(500)
          .toSet(),
      updatedAt: switch (json['updatedAt']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
    );
  }
}

class StudyPreferences {
  const StudyPreferences({
    this.onboardingCompleted = false,
    this.onboardingProfile = const OnboardingProfile(),
    this.dailyGoal = 100,
    this.dailyGoalsBySubject = const {},
    this.weeklyTargetDays = 5,
    this.weeklyTargetMinutes = 90,
    this.sessionItemLimit = 10,
    this.newItemLimit = 10,
    this.reviewLimit = 30,
    this.sentenceRatio = 0.3,
    this.showReadingAids = true,
    this.ttsRate = 0.45,
    this.experience = const AppExperiencePreferences(),
    this.interaction = const StudyInteractionPreferences(),
    this.settingsUpdatedAt,
    this.excludedItemIds = const {},
    this.excludedItemChangedAtById = const {},
    this.favoriteItemIds = const {},
    this.favoriteItemChangedAtById = const {},
    this.completedMissionIds = const {},
    this.preferredMode = StudyMode.mixed,
    this.sessionPlan = const StudySessionPlan(),
    this.savedSessionPlans = const [],
    this.savedSessionPlanTombstones = const {},
    this.activeSubjectId = '',
    this.activeSubjectChangedAt,
    this.customSubjects = const [],
    this.hiddenSubjectIds = const {},
    this.subjectVisibilityChangedAtById = const {},
    this.importDistributionRules = const [],
    this.learningGroups = const [],
    this.learningGroupTombstones = const {},
    this.dailyGoalChangedAtBySubject = const {},
    this.smartCollections = const [],
    this.smartCollectionTombstones = const {},
    this.trashEntries = const [],
    this.trashEntryTombstones = const {},
    this.importMappingPresets = const [],
    this.importReceipts = const [],
    this.contentCorrections = const [],
    this.contentCorrectionTombstones = const {},
    this.contentItemAliases = const {},
  });

  final bool onboardingCompleted;
  final OnboardingProfile onboardingProfile;
  final int dailyGoal;
  final Map<String, int> dailyGoalsBySubject;
  final int weeklyTargetDays;
  final int weeklyTargetMinutes;
  final int sessionItemLimit;
  final int newItemLimit;
  final int reviewLimit;
  final double sentenceRatio;
  final bool showReadingAids;
  final double ttsRate;
  final AppExperiencePreferences experience;
  final StudyInteractionPreferences interaction;
  final DateTime? settingsUpdatedAt;
  final Set<String> excludedItemIds;
  final Map<String, DateTime> excludedItemChangedAtById;
  final Set<String> favoriteItemIds;
  final Map<String, DateTime> favoriteItemChangedAtById;
  final Set<String> completedMissionIds;
  final StudyMode preferredMode;
  final StudySessionPlan sessionPlan;
  final List<StudySessionPlan> savedSessionPlans;
  final Map<String, DateTime> savedSessionPlanTombstones;
  final String activeSubjectId;
  final DateTime? activeSubjectChangedAt;
  final List<StudySubject> customSubjects;
  final Set<String> hiddenSubjectIds;
  final Map<String, DateTime> subjectVisibilityChangedAtById;
  final List<ImportDistributionRule> importDistributionRules;
  final List<LearningGroupDefinition> learningGroups;
  final Map<String, DateTime> learningGroupTombstones;
  final Map<String, DateTime> dailyGoalChangedAtBySubject;
  final List<SmartCollectionDefinition> smartCollections;
  final Map<String, DateTime> smartCollectionTombstones;
  final List<TrashEntry> trashEntries;
  final Map<String, DateTime> trashEntryTombstones;
  final List<ImportMappingPreset> importMappingPresets;
  final List<ImportBatchReceipt> importReceipts;
  final List<ContentCorrection> contentCorrections;
  final Map<String, DateTime> contentCorrectionTombstones;
  final Map<String, String> contentItemAliases;

  StudyPreferences copyWith({
    bool? onboardingCompleted,
    OnboardingProfile? onboardingProfile,
    int? dailyGoal,
    Map<String, int>? dailyGoalsBySubject,
    int? weeklyTargetDays,
    int? weeklyTargetMinutes,
    int? sessionItemLimit,
    int? newItemLimit,
    int? reviewLimit,
    double? sentenceRatio,
    bool? showReadingAids,
    double? ttsRate,
    AppExperiencePreferences? experience,
    StudyInteractionPreferences? interaction,
    DateTime? settingsUpdatedAt,
    Set<String>? excludedItemIds,
    Map<String, DateTime>? excludedItemChangedAtById,
    Set<String>? favoriteItemIds,
    Map<String, DateTime>? favoriteItemChangedAtById,
    Set<String>? completedMissionIds,
    StudyMode? preferredMode,
    StudySessionPlan? sessionPlan,
    List<StudySessionPlan>? savedSessionPlans,
    Map<String, DateTime>? savedSessionPlanTombstones,
    String? activeSubjectId,
    DateTime? activeSubjectChangedAt,
    List<StudySubject>? customSubjects,
    Set<String>? hiddenSubjectIds,
    Map<String, DateTime>? subjectVisibilityChangedAtById,
    List<ImportDistributionRule>? importDistributionRules,
    List<LearningGroupDefinition>? learningGroups,
    Map<String, DateTime>? learningGroupTombstones,
    Map<String, DateTime>? dailyGoalChangedAtBySubject,
    List<SmartCollectionDefinition>? smartCollections,
    Map<String, DateTime>? smartCollectionTombstones,
    List<TrashEntry>? trashEntries,
    Map<String, DateTime>? trashEntryTombstones,
    List<ImportMappingPreset>? importMappingPresets,
    List<ImportBatchReceipt>? importReceipts,
    List<ContentCorrection>? contentCorrections,
    Map<String, DateTime>? contentCorrectionTombstones,
    Map<String, String>? contentItemAliases,
  }) {
    final nextInteraction =
        interaction ??
        (showReadingAids == null
            ? this.interaction
            : this.interaction.copyWith(
                showKoreanReading: showReadingAids,
                showNativeReading: showReadingAids,
              ));
    return StudyPreferences(
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingProfile: onboardingProfile ?? this.onboardingProfile,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      dailyGoalsBySubject: dailyGoalsBySubject ?? this.dailyGoalsBySubject,
      weeklyTargetDays: weeklyTargetDays ?? this.weeklyTargetDays,
      weeklyTargetMinutes: weeklyTargetMinutes ?? this.weeklyTargetMinutes,
      sessionItemLimit: sessionItemLimit ?? this.sessionItemLimit,
      newItemLimit: newItemLimit ?? this.newItemLimit,
      reviewLimit: reviewLimit ?? this.reviewLimit,
      sentenceRatio: sentenceRatio ?? this.sentenceRatio,
      showReadingAids:
          showReadingAids ??
          (interaction == null
              ? this.showReadingAids
              : nextInteraction.showKoreanReading ||
                    nextInteraction.showNativeReading),
      ttsRate: ttsRate ?? this.ttsRate,
      experience: experience ?? this.experience,
      interaction: nextInteraction,
      settingsUpdatedAt: settingsUpdatedAt ?? this.settingsUpdatedAt,
      excludedItemIds: excludedItemIds ?? this.excludedItemIds,
      excludedItemChangedAtById:
          excludedItemChangedAtById ?? this.excludedItemChangedAtById,
      favoriteItemIds: favoriteItemIds ?? this.favoriteItemIds,
      favoriteItemChangedAtById:
          favoriteItemChangedAtById ?? this.favoriteItemChangedAtById,
      completedMissionIds: completedMissionIds ?? this.completedMissionIds,
      preferredMode: preferredMode ?? this.preferredMode,
      sessionPlan: sessionPlan ?? this.sessionPlan,
      savedSessionPlans: savedSessionPlans ?? this.savedSessionPlans,
      savedSessionPlanTombstones:
          savedSessionPlanTombstones ?? this.savedSessionPlanTombstones,
      activeSubjectId: activeSubjectId ?? this.activeSubjectId,
      activeSubjectChangedAt:
          activeSubjectChangedAt ?? this.activeSubjectChangedAt,
      customSubjects: customSubjects ?? this.customSubjects,
      hiddenSubjectIds: hiddenSubjectIds ?? this.hiddenSubjectIds,
      subjectVisibilityChangedAtById:
          subjectVisibilityChangedAtById ?? this.subjectVisibilityChangedAtById,
      importDistributionRules:
          importDistributionRules ?? this.importDistributionRules,
      learningGroups: learningGroups ?? this.learningGroups,
      learningGroupTombstones:
          learningGroupTombstones ?? this.learningGroupTombstones,
      dailyGoalChangedAtBySubject:
          dailyGoalChangedAtBySubject ?? this.dailyGoalChangedAtBySubject,
      smartCollections: smartCollections ?? this.smartCollections,
      smartCollectionTombstones:
          smartCollectionTombstones ?? this.smartCollectionTombstones,
      trashEntries: trashEntries ?? this.trashEntries,
      trashEntryTombstones: trashEntryTombstones ?? this.trashEntryTombstones,
      importMappingPresets: importMappingPresets ?? this.importMappingPresets,
      importReceipts: importReceipts ?? this.importReceipts,
      contentCorrections: contentCorrections ?? this.contentCorrections,
      contentCorrectionTombstones:
          contentCorrectionTombstones ?? this.contentCorrectionTombstones,
      contentItemAliases: contentItemAliases ?? this.contentItemAliases,
    );
  }

  Map<String, Object?> toJson() => {
    'onboardingCompleted': onboardingCompleted,
    'onboardingProfile': onboardingProfile.toJson(),
    'dailyGoal': dailyGoal,
    'dailyGoalsBySubject': {
      for (final entry
          in (dailyGoalsBySubject.entries.toList()
            ..sort((left, right) => left.key.compareTo(right.key))))
        entry.key: entry.value,
    },
    'weeklyTargetDays': weeklyTargetDays,
    'weeklyTargetMinutes': weeklyTargetMinutes,
    'sessionItemLimit': sessionItemLimit,
    'newItemLimit': newItemLimit,
    'reviewLimit': reviewLimit,
    'sentenceRatio': sentenceRatio,
    'showReadingAids': showReadingAids,
    'ttsRate': ttsRate,
    'experience': experience.toJson(),
    'interaction': interaction.toJson(),
    if (settingsUpdatedAt != null)
      'settingsUpdatedAt': settingsUpdatedAt!.toUtc().toIso8601String(),
    'excludedItemIds': excludedItemIds.toList()..sort(),
    if (excludedItemChangedAtById.isNotEmpty)
      'excludedItemChangedAtById': _dateMapToJson(excludedItemChangedAtById),
    'favoriteItemIds': favoriteItemIds.toList()..sort(),
    if (favoriteItemChangedAtById.isNotEmpty)
      'favoriteItemChangedAtById': _dateMapToJson(favoriteItemChangedAtById),
    'completedMissionIds': completedMissionIds.toList()..sort(),
    'preferredMode': preferredMode.name,
    'sessionPlan': sessionPlan.toJson(),
    'savedSessionPlans': [for (final plan in savedSessionPlans) plan.toJson()],
    if (savedSessionPlanTombstones.isNotEmpty)
      'savedSessionPlanTombstones': _dateMapToJson(savedSessionPlanTombstones),
    'activeSubjectId': activeSubjectId,
    if (activeSubjectChangedAt != null)
      'activeSubjectChangedAt': activeSubjectChangedAt!
          .toUtc()
          .toIso8601String(),
    'customSubjects': [for (final subject in customSubjects) subject.toJson()],
    if (hiddenSubjectIds.isNotEmpty)
      'hiddenSubjectIds': hiddenSubjectIds.toList()..sort(),
    if (subjectVisibilityChangedAtById.isNotEmpty)
      'subjectVisibilityChangedAtById': _dateMapToJson(
        subjectVisibilityChangedAtById,
      ),
    if (importDistributionRules.isNotEmpty)
      'importDistributionRules': [
        for (final rule in importDistributionRules) rule.toJson(),
      ],
    'learningGroups': [for (final group in learningGroups) group.toJson()],
    if (learningGroupTombstones.isNotEmpty)
      'learningGroupTombstones': _dateMapToJson(learningGroupTombstones),
    if (dailyGoalChangedAtBySubject.isNotEmpty)
      'dailyGoalChangedAtBySubject': {
        for (final entry
            in (dailyGoalChangedAtBySubject.entries.toList()
              ..sort((left, right) => left.key.compareTo(right.key))))
          entry.key: entry.value.toUtc().toIso8601String(),
      },
    if (smartCollections.isNotEmpty)
      'smartCollections': [
        for (final collection in smartCollections) collection.toJson(),
      ],
    if (smartCollectionTombstones.isNotEmpty)
      'smartCollectionTombstones': _dateMapToJson(smartCollectionTombstones),
    if (trashEntries.isNotEmpty)
      'trashEntries': [for (final entry in trashEntries) entry.toJson()],
    if (trashEntryTombstones.isNotEmpty)
      'trashEntryTombstones': _dateMapToJson(trashEntryTombstones),
    if (importMappingPresets.isNotEmpty)
      'importMappingPresets': [
        for (final preset in importMappingPresets) preset.toJson(),
      ],
    if (importReceipts.isNotEmpty)
      'importReceipts': [
        for (final receipt in importReceipts) receipt.toJson(),
      ],
    if (contentCorrections.isNotEmpty)
      'contentCorrections': [
        for (final correction in contentCorrections) correction.toJson(),
      ],
    if (contentCorrectionTombstones.isNotEmpty)
      'contentCorrectionTombstones': _dateMapToJson(
        contentCorrectionTombstones,
      ),
    if (contentItemAliases.isNotEmpty)
      'contentItemAliases': {
        for (final entry
            in (contentItemAliases.entries.toList()
              ..sort((left, right) => left.key.compareTo(right.key))))
          entry.key: entry.value,
      },
  };

  factory StudyPreferences.fromJson(Map<String, Object?> json) {
    final rawMode = json['preferredMode'] as String?;
    final customSubjects = _parseCustomSubjects(json['customSubjects']);
    final activeSubjectId = _safeSubjectId(
      json['activeSubjectId'],
      fallback: '',
    );
    final legacyShowReadingAids = json['showReadingAids'] is bool
        ? json['showReadingAids']! as bool
        : true;
    final experience = json['experience'] is Map
        ? AppExperiencePreferences.fromJson(
            Map<String, Object?>.from(json['experience']! as Map),
          )
        : const AppExperiencePreferences();
    final interaction = json['interaction'] is Map
        ? StudyInteractionPreferences.fromJson(
            Map<String, Object?>.from(json['interaction']! as Map),
          )
        : StudyInteractionPreferences(
            showKoreanReading: legacyShowReadingAids,
            showNativeReading: legacyShowReadingAids,
          );
    StudySessionPlan scopeLegacyPlan(StudySessionPlan plan) {
      if (plan.subjectId.isNotEmpty || activeSubjectId.isEmpty) return plan;
      return plan.copyWith(subjectId: activeSubjectId);
    }

    final sessionPlan = json['sessionPlan'] is Map
        ? scopeLegacyPlan(
            StudySessionPlan.fromJson(
              Map<String, Object?>.from(json['sessionPlan']! as Map),
            ),
          )
        : StudySessionPlan(subjectId: activeSubjectId);
    return StudyPreferences(
      // A persisted settings document without this flag predates onboarding.
      // Treat only that legacy shape as already onboarded. A truly fresh
      // install never calls fromJson (the store returns StudyPreferences()),
      // so it still receives the first-run experience.
      onboardingCompleted: json.containsKey('onboardingCompleted')
          ? json['onboardingCompleted'] as bool? ?? false
          : true,
      onboardingProfile: json['onboardingProfile'] is Map
          ? OnboardingProfile.fromJson(
              Map<String, Object?>.from(json['onboardingProfile']! as Map),
            )
          : const OnboardingProfile(),
      dailyGoal: ((json['dailyGoal'] as num?)?.toInt() ?? 100).clamp(20, 500),
      dailyGoalsBySubject: _parseDailyGoalsBySubject(
        json['dailyGoalsBySubject'],
      ),
      weeklyTargetDays: ((json['weeklyTargetDays'] as num?)?.toInt() ?? 5)
          .clamp(1, 7),
      weeklyTargetMinutes:
          ((json['weeklyTargetMinutes'] as num?)?.toInt() ?? 90).clamp(5, 840),
      sessionItemLimit: ((json['sessionItemLimit'] as num?)?.toInt() ?? 10)
          .clamp(StudyLimits.minSessionItems, StudyLimits.maxSessionItems),
      newItemLimit: ((json['newItemLimit'] as num?)?.toInt() ?? 10).clamp(
        0,
        50,
      ),
      reviewLimit: ((json['reviewLimit'] as num?)?.toInt() ?? 30).clamp(1, 100),
      sentenceRatio: ((json['sentenceRatio'] as num?)?.toDouble() ?? 0.3).clamp(
        0,
        1,
      ),
      showReadingAids: legacyShowReadingAids,
      ttsRate: ((json['ttsRate'] as num?)?.toDouble() ?? 0.45).clamp(0.2, 0.8),
      experience: experience,
      interaction: interaction,
      settingsUpdatedAt: switch (json['settingsUpdatedAt']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
      excludedItemIds: ((json['excludedItemIds'] as List<Object?>?) ?? const [])
          .whereType<String>()
          .toSet(),
      excludedItemChangedAtById: _parseChangedAtById(
        json['excludedItemChangedAtById'],
        maximumEntries: 50000,
        maximumIdLength: 160,
      ),
      favoriteItemIds: ((json['favoriteItemIds'] as List<Object?>?) ?? const [])
          .whereType<String>()
          .toSet(),
      favoriteItemChangedAtById: _parseChangedAtById(
        json['favoriteItemChangedAtById'],
        maximumEntries: 50000,
        maximumIdLength: 160,
      ),
      completedMissionIds:
          ((json['completedMissionIds'] as List<Object?>?) ?? const [])
              .whereType<String>()
              .toSet(),
      preferredMode: StudyMode.values.firstWhere(
        (mode) => mode.name == rawMode,
        orElse: () => StudyMode.mixed,
      ),
      sessionPlan: sessionPlan,
      savedSessionPlans:
          ((json['savedSessionPlans'] as List<Object?>?) ?? const [])
              .whereType<Map>()
              .map(
                (raw) => scopeLegacyPlan(
                  StudySessionPlan.fromJson(Map<String, Object?>.from(raw)),
                ),
              )
              .where((plan) => plan.planId.isNotEmpty)
              .take(20)
              .toList(growable: false),
      savedSessionPlanTombstones: _parseChangedAtById(
        json['savedSessionPlanTombstones'],
        maximumEntries: 100,
        maximumIdLength: 80,
      ),
      activeSubjectId: activeSubjectId,
      activeSubjectChangedAt: switch (json['activeSubjectChangedAt']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
      customSubjects: customSubjects,
      hiddenSubjectIds: _parseSubjectIdSet(json['hiddenSubjectIds']),
      subjectVisibilityChangedAtById: _parseChangedAtById(
        json['subjectVisibilityChangedAtById'],
        maximumEntries: 100,
        maximumIdLength: 80,
      ),
      importDistributionRules: _parseImportDistributionRules(
        json['importDistributionRules'],
      ),
      learningGroups: _parseLearningGroups(json['learningGroups']),
      learningGroupTombstones: _parseChangedAtById(
        json['learningGroupTombstones'],
        maximumEntries: 500,
        maximumIdLength: 240,
      ),
      dailyGoalChangedAtBySubject: _parseDailyGoalChangedAtBySubject(
        json['dailyGoalChangedAtBySubject'],
      ),
      smartCollections: _parseStructuredList(
        json['smartCollections'],
        maximumEntries: 100,
        parse: SmartCollectionDefinition.fromJson,
      ),
      smartCollectionTombstones: _parseChangedAtById(
        json['smartCollectionTombstones'],
        maximumEntries: 200,
        maximumIdLength: 80,
      ),
      trashEntries: _parseStructuredList(
        json['trashEntries'],
        maximumEntries: 2000,
        parse: TrashEntry.fromJson,
      ),
      trashEntryTombstones: _parseChangedAtById(
        json['trashEntryTombstones'],
        maximumEntries: 4000,
        maximumIdLength: 160,
      ),
      importMappingPresets: _parseStructuredList(
        json['importMappingPresets'],
        maximumEntries: 50,
        parse: ImportMappingPreset.fromJson,
      ),
      importReceipts: _parseStructuredList(
        json['importReceipts'],
        maximumEntries: 30,
        parse: ImportBatchReceipt.fromJson,
      ),
      contentCorrections: _parseStructuredList(
        json['contentCorrections'],
        maximumEntries: 2000,
        parse: ContentCorrection.fromJson,
      ),
      contentCorrectionTombstones: _parseChangedAtById(
        json['contentCorrectionTombstones'],
        maximumEntries: 4000,
        maximumIdLength: 160,
      ),
      contentItemAliases: _parseItemAliases(json['contentItemAliases']),
    );
  }

  bool includes(LearningItem item) => !excludedItemIds.contains(item.id);

  int dailyGoalFor(String subjectId) {
    final normalized = _safeSubjectId(subjectId, fallback: subjectId);
    return dailyGoalsBySubject[normalized] ?? dailyGoal;
  }

  StudyPreferences withDailyGoalForSubject(
    String subjectId,
    int goal, {
    DateTime? changedAt,
  }) {
    final normalized = normalizeStudySubjectId(subjectId);
    final effectiveChangedAt = (changedAt ?? DateTime.now()).toUtc();
    return copyWith(
      dailyGoalsBySubject: {
        ...dailyGoalsBySubject,
        normalized: goal.clamp(20, 500),
      },
      dailyGoalChangedAtBySubject: {
        ...dailyGoalChangedAtBySubject,
        normalized: effectiveChangedAt,
      },
    );
  }

  bool isFavorite(String itemId) => favoriteItemIds.contains(itemId);

  bool hasCompletedMission(String courseId, int unitIndex) =>
      completedMissionIds.contains('$courseId:$unitIndex');
}

String _safeSubjectId(Object? value, {required String fallback}) {
  if (value is! String) return fallback;
  try {
    return normalizeStudySubjectId(value);
  } on FormatException {
    return fallback;
  }
}

List<StudySubject> _parseCustomSubjects(Object? raw) {
  if (raw is! List<Object?>) return const [];
  final subjects = <String, StudySubject>{};
  for (final value in raw.whereType<Map>()) {
    try {
      final subject = StudySubject.fromJson(Map<String, Object?>.from(value));
      final isBuiltInOverride =
          subject.kind == StudySubjectKind.language &&
          builtInLanguageSubjects.any((builtIn) => builtIn.id == subject.id);
      if (subject.kind == StudySubjectKind.general || isBuiltInOverride) {
        subjects[subject.id] = subject;
      }
    } on FormatException {
      // One malformed remote subject must not discard healthy preferences.
    }
  }
  return subjects.values.take(100).toList(growable: false);
}

Set<String> _parseSubjectIdSet(Object? raw) {
  if (raw is! List<Object?>) return const {};
  final ids = <String>{};
  for (final value in raw.whereType<String>()) {
    try {
      ids.add(normalizeStudySubjectId(value));
    } on FormatException {
      // Ignore a malformed remote visibility entry without losing the rest.
    }
  }
  return Set.unmodifiable(ids.take(100));
}

List<ImportDistributionRule> _parseImportDistributionRules(Object? raw) {
  if (raw is! List<Object?>) return const [];
  final rules = <String, ImportDistributionRule>{};
  for (final value in raw.whereType<Map>()) {
    try {
      final rule = ImportDistributionRule.fromJson(
        Map<String, Object?>.from(value),
      );
      final current = rules[rule.key];
      if (current == null || rule.updatedAt.isAfter(current.updatedAt)) {
        rules[rule.key] = rule;
      }
    } on FormatException {
      // One malformed rule must not discard other synchronized preferences.
    }
  }
  return List.unmodifiable(rules.values.take(200));
}

List<LearningGroupDefinition> _parseLearningGroups(Object? raw) {
  if (raw is! List<Object?>) return const [];
  final groups = <String, LearningGroupDefinition>{};
  for (final value in raw.whereType<Map>()) {
    try {
      final group = LearningGroupDefinition.fromJson(
        Map<String, Object?>.from(value),
      );
      final current = groups[group.id];
      if (current == null || group.updatedAt.isAfter(current.updatedAt)) {
        groups[group.id] = group;
      }
    } on FormatException {
      // One malformed remote group must not discard healthy preferences.
    }
  }
  final values = groups.values.toList()
    ..sort((left, right) {
      final subjectOrder = left.subjectId.compareTo(right.subjectId);
      if (subjectOrder != 0) return subjectOrder;
      final pinOrder = (right.pinned ? 1 : 0).compareTo(left.pinned ? 1 : 0);
      if (pinOrder != 0) return pinOrder;
      final manualOrder = left.sortOrder.compareTo(right.sortOrder);
      if (manualOrder != 0) return manualOrder;
      return left.name.compareTo(right.name);
    });
  return List.unmodifiable(values.take(500));
}

Map<String, int> _parseDailyGoalsBySubject(Object? raw) {
  if (raw is! Map) return const {};
  final goals = <String, int>{};
  for (final entry in raw.entries.take(100)) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String || value is! num || !value.isFinite) continue;
    try {
      final subjectId = normalizeStudySubjectId(key);
      goals[subjectId] = value.toInt().clamp(20, 500);
    } on FormatException {
      // One malformed subject goal must not discard healthy preferences.
    }
  }
  return Map.unmodifiable(goals);
}

Map<String, DateTime> _parseDailyGoalChangedAtBySubject(Object? raw) {
  if (raw is! Map) return const {};
  final values = <String, DateTime>{};
  for (final entry in raw.entries.take(100)) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String || value is! String) continue;
    try {
      final subjectId = normalizeStudySubjectId(key);
      final changedAt = DateTime.tryParse(value)?.toUtc();
      if (changedAt != null) values[subjectId] = changedAt;
    } on FormatException {
      // One malformed timestamp must not discard healthy preferences.
    }
  }
  return Map.unmodifiable(values);
}

Map<String, String> _dateMapToJson(Map<String, DateTime> values) {
  final entries = values.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return {
    for (final entry in entries)
      entry.key: entry.value.toUtc().toIso8601String(),
  };
}

Map<String, DateTime> _parseChangedAtById(
  Object? raw, {
  required int maximumEntries,
  required int maximumIdLength,
}) {
  if (raw is! Map) return const {};
  final values = <String, DateTime>{};
  for (final entry in raw.entries.take(maximumEntries)) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String ||
        key.trim().isEmpty ||
        key.runes.length > maximumIdLength ||
        value is! String) {
      continue;
    }
    final changedAt = DateTime.tryParse(value)?.toUtc();
    if (changedAt != null) values[key] = changedAt;
  }
  return Map.unmodifiable(values);
}

Map<String, String> _parseItemAliases(Object? raw) {
  if (raw is! Map) return const {};
  final parsed = <String, String>{};
  for (final entry in raw.entries.take(50000)) {
    final source = entry.key;
    final target = entry.value;
    if (source is! String ||
        target is! String ||
        source.trim().isEmpty ||
        target.trim().isEmpty ||
        source.runes.length > 160 ||
        target.runes.length > 160 ||
        source == target) {
      continue;
    }
    parsed[source] = target;
  }
  String resolve(String source) {
    var current = source;
    final path = <String>[];
    final positions = <String, int>{};
    while (true) {
      final cycleStart = positions[current];
      if (cycleStart != null) {
        final cycle = path.sublist(cycleStart)..sort();
        return cycle.first;
      }
      positions[current] = path.length;
      path.add(current);
      final next = parsed[current];
      if (next == null || next == current) return current;
      current = next;
    }
  }

  final aliases = <String, String>{};
  final sources = parsed.keys.toList()..sort();
  for (final source in sources) {
    final target = resolve(source);
    if (source != target) aliases[source] = target;
  }
  return Map.unmodifiable(aliases);
}

List<T> _parseStructuredList<T>(
  Object? raw, {
  required int maximumEntries,
  required T Function(Map<String, Object?> json) parse,
}) {
  if (raw is! List<Object?>) return const [];
  final values = <T>[];
  for (final entry in raw.take(maximumEntries)) {
    if (entry is! Map) continue;
    try {
      values.add(parse(Map<String, Object?>.from(entry)));
    } on FormatException {
      // Keep healthy synchronized records when one optional record is malformed.
    }
  }
  return List.unmodifiable(values);
}
