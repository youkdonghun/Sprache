import 'session_enhancements.dart';
import 'daily_practice_quests.dart';

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
  fifteenMinutes,
}

enum PracticeDifficultyPreset { relaxed, balanced, challenge }

enum PracticeHistoryScope { all, excludeCorrect, wrongOnly }

enum PracticeQueueOrder { dueFirst, newFirst }

enum PracticeDurationFilter {
  any,
  threeMinutes,
  fiveMinutes,
  tenMinutes,
  unlimited,
}

enum PracticeSkillFilter {
  all,
  recognition,
  recall,
  listening,
  speaking,
  sentence,
  memory,
}

enum PracticeCatalogSort { recommended, recent, launchCount, name }

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
    this.challengeScoringEnabled = false,
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
  final bool challengeScoringEnabled;

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
    bool? challengeScoringEnabled,
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
      challengeScoringEnabled:
          challengeScoringEnabled ?? this.challengeScoringEnabled,
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
    'challengeScoringEnabled': challengeScoringEnabled,
  };

  factory PracticeLaunchPreferences.fromJson(Map<String, Object?> json) {
    final rawChoiceCount = _intInRange(
      json['choiceCount'],
      fallback: 4,
      minimum: 2,
      maximum: 6,
    );
    return PracticeLaunchPreferences(
      length: _enumByName(
        PracticeSessionLength.values,
        json['length'],
        PracticeSessionLength.tenItems,
      ),
      itemCount: _intInRange(
        json['itemCount'],
        fallback: 10,
        minimum: 1,
        maximum: 100,
      ),
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
      challengeScoringEnabled: _boolOr(json['challengeScoringEnabled'], false),
    );
  }
}

class PracticeBestRecord {
  const PracticeBestRecord({
    required this.bestScore,
    this.bestElapsedMs,
    required this.updatedAt,
  });

  final int bestScore;
  final int? bestElapsedMs;
  final DateTime updatedAt;

  PracticeBestRecord record({
    required int score,
    int? elapsedMs,
    required DateTime at,
  }) {
    final safeScore = score.clamp(0, 100);
    final safeElapsed = elapsedMs?.clamp(1, 24 * 60 * 60 * 1000);
    final nextScore = safeScore > bestScore ? safeScore : bestScore;
    final nextElapsed = switch ((bestElapsedMs, safeElapsed)) {
      (null, final int value) => value,
      (final int current, final int value) when value < current => value,
      (final int current, _) => current,
      _ => null,
    };
    if (nextScore == bestScore && nextElapsed == bestElapsedMs) return this;
    return PracticeBestRecord(
      bestScore: nextScore,
      bestElapsedMs: nextElapsed,
      updatedAt: at.toUtc(),
    );
  }

  Map<String, Object?> toJson() => {
    'bestScore': bestScore,
    if (bestElapsedMs != null) 'bestElapsedMs': bestElapsedMs,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static PracticeBestRecord? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final score = raw['bestScore'];
    final elapsed = raw['bestElapsedMs'];
    final updatedAt = raw['updatedAt'];
    if (score is! num ||
        !score.isFinite ||
        score.toInt() < 0 ||
        score.toInt() > 100 ||
        (elapsed != null &&
            (elapsed is! num ||
                !elapsed.isFinite ||
                elapsed.toInt() < 1 ||
                elapsed.toInt() > 24 * 60 * 60 * 1000)) ||
        updatedAt is! String) {
      return null;
    }
    final parsedAt = DateTime.tryParse(updatedAt)?.toUtc();
    if (parsedAt == null) return null;
    return PracticeBestRecord(
      bestScore: score.toInt(),
      bestElapsedMs: elapsed == null ? null : (elapsed as num).toInt(),
      updatedAt: parsedAt,
    );
  }
}

class PracticePlaylist {
  const PracticePlaylist({
    required this.id,
    required this.name,
    required this.activityIds,
  });

  final String id;
  final String name;
  final List<String> activityIds;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'activityIds': activityIds,
  };

  static PracticePlaylist? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final ids = raw['activityIds'];
    if (id is! String ||
        !_isSafePracticeActivityId(id.trim()) ||
        name is! String ||
        name.trim().isEmpty ||
        name.runes.length > 40 ||
        ids is! List) {
      return null;
    }
    final normalizedIds = _normalizePracticeActivityOrder(
      ids.whereType<String>().where(isPlaylistCompatiblePracticeActivity),
      maximumEntries: 5,
    );
    if (normalizedIds.length < 2) return null;
    return PracticePlaylist(
      id: id.trim(),
      name: name.trim(),
      activityIds: List.unmodifiable(normalizedIds),
    );
  }
}

class PracticeCatalogPreferences {
  const PracticeCatalogPreferences({
    this.favoriteActivityIds = const {},
    this.hiddenActivityIds = const {},
    this.launchByActivityId = const {},
    this.recentActivityIds = const [],
    this.favoriteActivityOrder = const [],
    this.quickLaunchActivityIds = const {},
    this.durationFilter = PracticeDurationFilter.any,
    this.skillFilter = PracticeSkillFilter.all,
    this.sortOrder = PracticeCatalogSort.recommended,
    this.launchCountByActivityId = const {},
    this.recommendationSnoozedUntilByActivityId = const {},
    this.recommendationWeightByActivityId = const {},
    this.surpriseDurationFilter = PracticeDurationFilter.any,
    this.surpriseSkillFilter = PracticeSkillFilter.all,
    this.surpriseFavoritesOnly = false,
    this.surpriseAvoidRecent = true,
    this.bestRecordsByActivityId = const {},
    this.playlists = const [],
    this.dailyQuestCompletionDayByScope = const {},
    this.dailyQuestAssignmentByScope = const {},
  });

  final Set<String> favoriteActivityIds;
  final Set<String> hiddenActivityIds;
  final Map<String, PracticeLaunchPreferences> launchByActivityId;
  final List<String> recentActivityIds;
  final List<String> favoriteActivityOrder;
  final Set<String> quickLaunchActivityIds;
  final PracticeDurationFilter durationFilter;
  final PracticeSkillFilter skillFilter;
  final PracticeCatalogSort sortOrder;
  final Map<String, int> launchCountByActivityId;
  final Map<String, DateTime> recommendationSnoozedUntilByActivityId;
  final Map<String, int> recommendationWeightByActivityId;
  final PracticeDurationFilter surpriseDurationFilter;
  final PracticeSkillFilter surpriseSkillFilter;
  final bool surpriseFavoritesOnly;
  final bool surpriseAvoidRecent;
  final Map<String, PracticeBestRecord> bestRecordsByActivityId;
  final List<PracticePlaylist> playlists;
  final Map<String, String> dailyQuestCompletionDayByScope;
  final Map<String, List<String>> dailyQuestAssignmentByScope;

  bool hasDailyQuestAssignment({
    required DateTime day,
    required String subjectId,
  }) => dailyQuestAssignmentByScope.containsKey(
    _dailyQuestAssignmentScopeKey(day, subjectId),
  );

  List<String> dailyQuestActivityIds({
    required DateTime day,
    required String subjectId,
    required Iterable<String> activityIds,
    int questCount = 3,
  }) {
    final scope = _dailyQuestAssignmentScopeKey(day, subjectId);
    final saved = dailyQuestAssignmentByScope[scope];
    if (saved != null && saved.isNotEmpty) return List.unmodifiable(saved);
    return List.unmodifiable(
      buildDailyPracticeQuests(
        day: day,
        subjectId: subjectId,
        activityIds: activityIds,
        questCount: questCount,
      ).map((quest) => quest.activityId),
    );
  }

  PracticeCatalogPreferences ensureDailyQuestAssignment({
    required DateTime day,
    required String subjectId,
    required Iterable<String> activityIds,
    int questCount = 3,
  }) {
    final scope = _dailyQuestAssignmentScopeKey(day, subjectId);
    if (scope.isEmpty || dailyQuestAssignmentByScope.containsKey(scope)) {
      return copyWith();
    }
    final ids = dailyQuestActivityIds(
      day: day,
      subjectId: subjectId,
      activityIds: activityIds,
      questCount: questCount,
    );
    if (ids.isEmpty) return copyWith();
    final next = <String, List<String>>{
      ...dailyQuestAssignmentByScope,
      scope: ids,
    };
    if (next.length > 60) {
      final ordered = next.entries.toList()
        ..sort((left, right) => right.key.compareTo(left.key));
      next
        ..clear()
        ..addEntries(ordered.take(60));
    }
    return copyWith(dailyQuestAssignmentByScope: next);
  }

  PracticeLaunchPreferences launchFor(String activityId) {
    final normalizedId = _canonicalPracticeActivityId(activityId);
    final direct =
        launchByActivityId[normalizedId] ?? launchByActivityId[activityId];
    if (direct != null) return direct;
    for (final entry in launchByActivityId.entries) {
      if (_canonicalPracticeActivityId(entry.key) == normalizedId) {
        return entry.value;
      }
    }
    return const PracticeLaunchPreferences();
  }

  PracticeCatalogPreferences recordActivity(String activityId) {
    final normalizedId = _canonicalPracticeActivityId(activityId);
    if (!_isSafePracticeActivityId(normalizedId)) return copyWith();
    final nextCount = ((launchCountByActivityId[normalizedId] ?? 0) + 1).clamp(
      1,
      1000000,
    );
    return copyWith(
      recentActivityIds: [
        normalizedId,
        for (final current in recentActivityIds)
          if (_canonicalPracticeActivityId(current) != normalizedId) current,
      ],
      launchCountByActivityId: {
        ...launchCountByActivityId,
        normalizedId: nextCount,
      },
    );
  }

  Set<String> completedDailyQuestActivityIds({
    required DateTime day,
    required String subjectId,
    required Iterable<String> activityIds,
  }) {
    final dayKey = _practiceLocalDayKey(day);
    return {
      for (final rawId in activityIds)
        if (_canonicalPracticeActivityId(rawId) case final activityId)
          if (_isSafePracticeActivityId(activityId) &&
              dailyQuestCompletionDayByScope[_dailyQuestScopeKey(
                    subjectId,
                    activityId,
                  )] ==
                  dayKey)
            activityId,
    };
  }

  PracticeCatalogPreferences recordDailyQuestCompletion({
    required String activityId,
    required String subjectId,
    required DateTime completedAt,
  }) {
    final id = _canonicalPracticeActivityId(activityId);
    final scope = _dailyQuestScopeKey(subjectId, id);
    if (!_isSafePracticeActivityId(id) || scope.isEmpty) return copyWith();
    final dayKey = _practiceLocalDayKey(completedAt);
    final next = <String, String>{
      ...dailyQuestCompletionDayByScope,
      scope: dayKey,
    };
    if (next.length > 100) {
      final sorted = next.entries.toList()
        ..sort((left, right) {
          final byDay = right.value.compareTo(left.value);
          return byDay != 0 ? byDay : left.key.compareTo(right.key);
        });
      next
        ..clear()
        ..addEntries(sorted.take(100));
    }
    return copyWith(dailyQuestCompletionDayByScope: next);
  }

  PracticeCatalogPreferences snoozeRecommendation(
    String activityId,
    DateTime until,
  ) {
    final id = _canonicalPracticeActivityId(activityId);
    if (!_isSafePracticeActivityId(id)) return copyWith();
    return copyWith(
      recommendationSnoozedUntilByActivityId: {
        ...recommendationSnoozedUntilByActivityId,
        id: until.toUtc(),
      },
    );
  }

  PracticeCatalogPreferences clearRecommendationSnoozes() =>
      copyWith(recommendationSnoozedUntilByActivityId: const {});

  PracticeCatalogPreferences adjustRecommendationWeight(
    String activityId,
    int delta,
  ) {
    final id = _canonicalPracticeActivityId(activityId);
    if (!_isSafePracticeActivityId(id) || delta == 0) return copyWith();
    final next = ((recommendationWeightByActivityId[id] ?? 0) + delta).clamp(
      -3,
      3,
    );
    final weights = {...recommendationWeightByActivityId};
    if (next == 0) {
      weights.remove(id);
    } else {
      weights[id] = next;
    }
    return copyWith(recommendationWeightByActivityId: weights);
  }

  PracticeCatalogPreferences recordBest(
    String activityId, {
    required int score,
    int? elapsedMs,
    required DateTime at,
  }) {
    final id = _canonicalPracticeActivityId(activityId);
    if (!_isSafePracticeActivityId(id)) return copyWith();
    final current = bestRecordsByActivityId[id];
    final next = current == null
        ? PracticeBestRecord(
            bestScore: score.clamp(0, 100),
            bestElapsedMs: elapsedMs?.clamp(1, 24 * 60 * 60 * 1000),
            updatedAt: at.toUtc(),
          )
        : current.record(score: score, elapsedMs: elapsedMs, at: at);
    return copyWith(
      bestRecordsByActivityId: {...bestRecordsByActivityId, id: next},
    );
  }

  PracticeCatalogPreferences savePlaylist(PracticePlaylist playlist) {
    final safe = PracticePlaylist.tryFromJson(playlist.toJson());
    if (safe == null) return copyWith();
    return copyWith(
      playlists: [
        safe,
        for (final current in playlists)
          if (current.id != safe.id) current,
      ],
    );
  }

  PracticeCatalogPreferences removePlaylist(String playlistId) => copyWith(
    playlists: [
      for (final playlist in playlists)
        if (playlist.id != playlistId) playlist,
    ],
  );

  PracticeCatalogPreferences copyWith({
    Set<String>? favoriteActivityIds,
    Set<String>? hiddenActivityIds,
    Map<String, PracticeLaunchPreferences>? launchByActivityId,
    List<String>? recentActivityIds,
    List<String>? favoriteActivityOrder,
    Set<String>? quickLaunchActivityIds,
    PracticeDurationFilter? durationFilter,
    PracticeSkillFilter? skillFilter,
    PracticeCatalogSort? sortOrder,
    Map<String, int>? launchCountByActivityId,
    Map<String, DateTime>? recommendationSnoozedUntilByActivityId,
    Map<String, int>? recommendationWeightByActivityId,
    PracticeDurationFilter? surpriseDurationFilter,
    PracticeSkillFilter? surpriseSkillFilter,
    bool? surpriseFavoritesOnly,
    bool? surpriseAvoidRecent,
    Map<String, PracticeBestRecord>? bestRecordsByActivityId,
    List<PracticePlaylist>? playlists,
    Map<String, String>? dailyQuestCompletionDayByScope,
    Map<String, List<String>>? dailyQuestAssignmentByScope,
  }) {
    final hidden = _normalizePracticeActivitySet(
      hiddenActivityIds ?? this.hiddenActivityIds,
    );
    final favorites = _normalizePracticeActivitySet(
      favoriteActivityIds ?? this.favoriteActivityIds,
    )..removeAll(hidden);
    final recent = _normalizePracticeActivityOrder(
      recentActivityIds ?? this.recentActivityIds,
      maximumEntries: 8,
    )..removeWhere(hidden.contains);
    final favoriteOrder = _normalizePracticeActivityOrder(
      favoriteActivityOrder ?? this.favoriteActivityOrder,
      maximumEntries: 50,
    )..removeWhere((id) => !favorites.contains(id));
    final quickLaunch = _normalizePracticeActivitySet(
      quickLaunchActivityIds ?? this.quickLaunchActivityIds,
    )..removeAll(hidden);
    final safePlaylists = _normalizePracticePlaylists(
      playlists ?? this.playlists,
      hiddenActivityIds: hidden,
    );
    return PracticeCatalogPreferences(
      favoriteActivityIds: Set.unmodifiable(favorites),
      hiddenActivityIds: Set.unmodifiable(hidden),
      launchByActivityId: Map.unmodifiable(
        _normalizePracticeLaunches(
          launchByActivityId ?? this.launchByActivityId,
        ),
      ),
      recentActivityIds: List.unmodifiable(recent),
      favoriteActivityOrder: List.unmodifiable(favoriteOrder),
      quickLaunchActivityIds: Set.unmodifiable(quickLaunch),
      durationFilter: durationFilter ?? this.durationFilter,
      skillFilter: skillFilter ?? this.skillFilter,
      sortOrder: sortOrder ?? this.sortOrder,
      launchCountByActivityId: Map.unmodifiable(
        _normalizePracticeIntMap(
          launchCountByActivityId ?? this.launchCountByActivityId,
          minimum: 1,
          maximum: 1000000,
        ),
      ),
      recommendationSnoozedUntilByActivityId: Map.unmodifiable(
        _normalizePracticeDateMap(
          recommendationSnoozedUntilByActivityId ??
              this.recommendationSnoozedUntilByActivityId,
        ),
      ),
      recommendationWeightByActivityId: Map.unmodifiable(
        _normalizePracticeIntMap(
          recommendationWeightByActivityId ??
              this.recommendationWeightByActivityId,
          minimum: -3,
          maximum: 3,
          excludeZero: true,
        ),
      ),
      surpriseDurationFilter:
          surpriseDurationFilter ?? this.surpriseDurationFilter,
      surpriseSkillFilter: surpriseSkillFilter ?? this.surpriseSkillFilter,
      surpriseFavoritesOnly:
          surpriseFavoritesOnly ?? this.surpriseFavoritesOnly,
      surpriseAvoidRecent: surpriseAvoidRecent ?? this.surpriseAvoidRecent,
      bestRecordsByActivityId: Map.unmodifiable(
        _normalizePracticeBestRecords(
          bestRecordsByActivityId ?? this.bestRecordsByActivityId,
        ),
      ),
      playlists: List.unmodifiable(safePlaylists),
      dailyQuestCompletionDayByScope: Map.unmodifiable(
        _normalizeDailyQuestCompletionMap(
          dailyQuestCompletionDayByScope ?? this.dailyQuestCompletionDayByScope,
        ),
      ),
      dailyQuestAssignmentByScope: Map.unmodifiable(
        _normalizeDailyQuestAssignmentMap(
          dailyQuestAssignmentByScope ?? this.dailyQuestAssignmentByScope,
        ),
      ),
    );
  }

  Map<String, Object?> toJson() {
    final normalized = copyWith();
    return {
      'favoriteActivityIds': normalized.favoriteActivityIds.toList()..sort(),
      'hiddenActivityIds': normalized.hiddenActivityIds.toList()..sort(),
      'launchByActivityId': {
        for (final entry
            in (normalized.launchByActivityId.entries.toList()
              ..sort((left, right) => left.key.compareTo(right.key))))
          entry.key: entry.value.toJson(),
      },
      'recentActivityIds': normalized.recentActivityIds,
      'favoriteActivityOrder': normalized.favoriteActivityOrder,
      'quickLaunchActivityIds': normalized.quickLaunchActivityIds.toList()
        ..sort(),
      'durationFilter': normalized.durationFilter.name,
      'skillFilter': normalized.skillFilter.name,
      'sortOrder': normalized.sortOrder.name,
      'launchCountByActivityId': {
        for (final entry
            in (normalized.launchCountByActivityId.entries.toList()
              ..sort((left, right) => left.key.compareTo(right.key))))
          entry.key: entry.value,
      },
      'recommendationSnoozedUntilByActivityId': {
        for (final entry
            in (normalized.recommendationSnoozedUntilByActivityId.entries
                .toList()
              ..sort((left, right) => left.key.compareTo(right.key))))
          entry.key: entry.value.toUtc().toIso8601String(),
      },
      'recommendationWeightByActivityId': {
        for (final entry
            in (normalized.recommendationWeightByActivityId.entries.toList()
              ..sort((left, right) => left.key.compareTo(right.key))))
          entry.key: entry.value,
      },
      'surpriseDurationFilter': normalized.surpriseDurationFilter.name,
      'surpriseSkillFilter': normalized.surpriseSkillFilter.name,
      'surpriseFavoritesOnly': normalized.surpriseFavoritesOnly,
      'surpriseAvoidRecent': normalized.surpriseAvoidRecent,
      'bestRecordsByActivityId': {
        for (final entry
            in (normalized.bestRecordsByActivityId.entries.toList()
              ..sort((left, right) => left.key.compareTo(right.key))))
          entry.key: entry.value.toJson(),
      },
      'playlists': [
        for (final playlist in normalized.playlists) playlist.toJson(),
      ],
      'dailyQuestCompletionDayByScope': {
        for (final entry
            in (normalized.dailyQuestCompletionDayByScope.entries.toList()
              ..sort((left, right) => left.key.compareTo(right.key))))
          entry.key: entry.value,
      },
      'dailyQuestAssignmentByScope': {
        for (final entry
            in (normalized.dailyQuestAssignmentByScope.entries.toList()
              ..sort((left, right) => left.key.compareTo(right.key))))
          entry.key: entry.value,
      },
    };
  }

  factory PracticeCatalogPreferences.fromJson(Map<String, Object?> json) {
    Iterable<String> stringValues(Object? raw) =>
        raw is List<Object?> ? raw.whereType<String>() : const <String>[];

    Set<String> safeIds(Object? raw) =>
        _normalizePracticeActivitySet(stringValues(raw));

    List<String> safeOrder(Object? raw, {required int maximumEntries}) =>
        _normalizePracticeActivityOrder(
          stringValues(raw),
          maximumEntries: maximumEntries,
        );

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
        final normalizedId = _canonicalPracticeActivityId(id);
        if (!_isSafePracticeActivityId(normalizedId)) continue;
        launches[normalizedId] = PracticeLaunchPreferences.fromJson(safeValue);
      }
    }
    final hidden = safeIds(json['hiddenActivityIds']);
    final launchCounts = _parsePracticeIntMap(
      json['launchCountByActivityId'],
      minimum: 1,
      maximum: 1000000,
    );
    final weights = _parsePracticeIntMap(
      json['recommendationWeightByActivityId'],
      minimum: -3,
      maximum: 3,
      excludeZero: true,
    );
    final snoozes = <String, DateTime>{};
    final rawSnoozes = json['recommendationSnoozedUntilByActivityId'];
    if (rawSnoozes is Map) {
      for (final entry in rawSnoozes.entries.take(50)) {
        if (entry.key case final String rawId) {
          final id = _canonicalPracticeActivityId(rawId);
          final parsed = entry.value is String
              ? DateTime.tryParse(entry.value! as String)?.toUtc()
              : null;
          if (_isSafePracticeActivityId(id) && parsed != null) {
            snoozes[id] = parsed;
          }
        }
      }
    }
    final bestRecords = <String, PracticeBestRecord>{};
    final rawBestRecords = json['bestRecordsByActivityId'];
    if (rawBestRecords is Map) {
      for (final entry in rawBestRecords.entries.take(50)) {
        if (entry.key case final String rawId) {
          final id = _canonicalPracticeActivityId(rawId);
          final record = PracticeBestRecord.tryFromJson(entry.value);
          if (_isSafePracticeActivityId(id) && record != null) {
            bestRecords[id] = record;
          }
        }
      }
    }
    final playlists = <PracticePlaylist>[];
    if (json['playlists'] case final List<Object?> rawPlaylists) {
      for (final rawPlaylist in rawPlaylists.take(10)) {
        final playlist = PracticePlaylist.tryFromJson(rawPlaylist);
        if (playlist != null) playlists.add(playlist);
      }
    }
    final dailyQuestCompletions = <String, String>{};
    final rawDailyQuestCompletions = json['dailyQuestCompletionDayByScope'];
    if (rawDailyQuestCompletions is Map) {
      for (final entry in rawDailyQuestCompletions.entries.take(100)) {
        if (entry.key is String && entry.value is String) {
          dailyQuestCompletions[entry.key! as String] = entry.value! as String;
        }
      }
    }
    final dailyQuestAssignments = <String, List<String>>{};
    final rawDailyQuestAssignments = json['dailyQuestAssignmentByScope'];
    if (rawDailyQuestAssignments is Map) {
      for (final entry in rawDailyQuestAssignments.entries.take(60)) {
        if (entry.key is String && entry.value is List<Object?>) {
          dailyQuestAssignments[entry.key! as String] = (entry.value! as List)
              .whereType<String>()
              .toList(growable: false);
        }
      }
    }
    return PracticeCatalogPreferences(
      favoriteActivityIds: safeIds(json['favoriteActivityIds'])
        ..removeAll(hidden),
      hiddenActivityIds: hidden,
      launchByActivityId: launches,
      recentActivityIds: safeOrder(
        json['recentActivityIds'],
        maximumEntries: 8,
      ),
      favoriteActivityOrder: safeOrder(
        json['favoriteActivityOrder'],
        maximumEntries: 50,
      ),
      quickLaunchActivityIds: safeIds(json['quickLaunchActivityIds']),
      durationFilter: _enumByName(
        PracticeDurationFilter.values,
        json['durationFilter'],
        PracticeDurationFilter.any,
      ),
      skillFilter: _enumByName(
        PracticeSkillFilter.values,
        json['skillFilter'],
        PracticeSkillFilter.all,
      ),
      sortOrder: _enumByName(
        PracticeCatalogSort.values,
        json['sortOrder'],
        PracticeCatalogSort.recommended,
      ),
      launchCountByActivityId: launchCounts,
      recommendationSnoozedUntilByActivityId: snoozes,
      recommendationWeightByActivityId: weights,
      surpriseDurationFilter: _enumByName(
        PracticeDurationFilter.values,
        json['surpriseDurationFilter'],
        PracticeDurationFilter.any,
      ),
      surpriseSkillFilter: _enumByName(
        PracticeSkillFilter.values,
        json['surpriseSkillFilter'],
        PracticeSkillFilter.all,
      ),
      surpriseFavoritesOnly: _boolOr(json['surpriseFavoritesOnly'], false),
      surpriseAvoidRecent: _boolOr(json['surpriseAvoidRecent'], true),
      bestRecordsByActivityId: bestRecords,
      playlists: playlists,
      dailyQuestCompletionDayByScope: dailyQuestCompletions,
      dailyQuestAssignmentByScope: dailyQuestAssignments,
    ).copyWith();
  }
}

String _practiceLocalDayKey(DateTime value) {
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)}';
}

String _dailyQuestScopeKey(String subjectId, String activityId) {
  final subject = subjectId.trim();
  if (!_isSafeDailyQuestSubject(subject)) return '';
  return '$subject|$activityId';
}

String _dailyQuestAssignmentScopeKey(DateTime day, String subjectId) {
  final subject = subjectId.trim();
  if (!_isSafeDailyQuestSubject(subject)) return '';
  return '${_practiceLocalDayKey(day)}|$subject';
}

bool _isSafeDailyQuestSubject(String value) =>
    value.isNotEmpty &&
    value.runes.length <= 80 &&
    RegExp(r'^[A-Za-z0-9._:-]+$').hasMatch(value);

String _decodeDailyQuestSubject(String value) {
  try {
    return Uri.decodeComponent(value);
  } on FormatException {
    return '';
  }
}

Map<String, List<String>> _normalizeDailyQuestAssignmentMap(
  Map<String, List<String>> source,
) {
  final result = <String, List<String>>{};
  for (final entry in source.entries) {
    final separator = entry.key.indexOf('|');
    final day = separator <= 0 ? '' : entry.key.substring(0, separator);
    final parsedDay = DateTime.tryParse(day);
    final safeDay =
        parsedDay != null &&
        day.length == 10 &&
        _practiceLocalDayKey(parsedDay) == day;
    final rawSubject = separator < 0 ? '' : entry.key.substring(separator + 1);
    final subject = _decodeDailyQuestSubject(rawSubject);
    final ids = _normalizePracticeActivityOrder(
      entry.value,
      maximumEntries: 3,
    );
    if (safeDay &&
        _isSafeDailyQuestSubject(subject) &&
        ids.isNotEmpty) {
      result['$day|$subject'] = List.unmodifiable(ids);
    }
  }
  final ordered = result.entries.toList()
    ..sort((left, right) => right.key.compareTo(left.key));
  return Map.fromEntries(ordered.take(60));
}

Map<String, String> _normalizeDailyQuestCompletionMap(
  Map<String, String> source,
) {
  final entries = <MapEntry<String, String>>[];
  for (final entry in source.entries) {
    final separator = entry.key.indexOf('|');
    final rawSubject = separator < 0 ? '' : entry.key.substring(0, separator);
    final subject = _decodeDailyQuestSubject(rawSubject);
    final activityId = separator < 0
        ? ''
        : _canonicalPracticeActivityId(entry.key.substring(separator + 1));
    final parsedDay = DateTime.tryParse(entry.value);
    final safeDay =
        parsedDay != null &&
        entry.value.length == 10 &&
        _practiceLocalDayKey(parsedDay) == entry.value;
    if (separator > 0 &&
        _isSafeDailyQuestSubject(subject) &&
        _isSafePracticeActivityId(activityId) &&
        safeDay) {
      entries.add(MapEntry('$subject|$activityId', entry.value));
    }
  }
  entries.sort((left, right) {
    final byDay = right.value.compareTo(left.value);
    return byDay != 0 ? byDay : left.key.compareTo(right.key);
  });
  return Map.fromEntries(entries.take(100));
}

Set<String> _normalizePracticeActivitySet(Iterable<String> source) {
  final result = <String>{};
  for (final raw in source) {
    final id = _canonicalPracticeActivityId(raw);
    if (_isSafePracticeActivityId(id)) result.add(id);
    if (result.length == 50) break;
  }
  return result;
}

List<String> _normalizePracticeActivityOrder(
  Iterable<String> source, {
  required int maximumEntries,
}) {
  final used = <String>{};
  final result = <String>[];
  for (final raw in source) {
    final id = _canonicalPracticeActivityId(raw);
    if (_isSafePracticeActivityId(id) && used.add(id)) result.add(id);
    if (result.length == maximumEntries) break;
  }
  return result;
}

Map<String, PracticeLaunchPreferences> _normalizePracticeLaunches(
  Map<String, PracticeLaunchPreferences> source,
) {
  final result = <String, PracticeLaunchPreferences>{};
  for (final entry in source.entries) {
    final id = _canonicalPracticeActivityId(entry.key);
    if (_isSafePracticeActivityId(id)) result[id] = entry.value;
    if (result.length == 50) break;
  }
  return result;
}

Map<String, int> _normalizePracticeIntMap(
  Map<String, int> source, {
  required int minimum,
  required int maximum,
  bool excludeZero = false,
}) {
  final result = <String, int>{};
  for (final entry in source.entries) {
    final id = _canonicalPracticeActivityId(entry.key);
    final value = entry.value;
    if (_isSafePracticeActivityId(id) &&
        value >= minimum &&
        value <= maximum &&
        (!excludeZero || value != 0)) {
      result[id] = value;
    }
    if (result.length == 50) break;
  }
  return result;
}

Map<String, int> _parsePracticeIntMap(
  Object? raw, {
  required int minimum,
  required int maximum,
  bool excludeZero = false,
}) {
  final values = <String, int>{};
  if (raw is! Map) return values;
  for (final entry in raw.entries.take(50)) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String || value is! num || !value.isFinite) continue;
    final integer = value.toInt();
    if (value != integer ||
        integer < minimum ||
        integer > maximum ||
        (excludeZero && integer == 0)) {
      continue;
    }
    final id = _canonicalPracticeActivityId(key);
    if (_isSafePracticeActivityId(id)) values[id] = integer;
  }
  return values;
}

Map<String, DateTime> _normalizePracticeDateMap(Map<String, DateTime> source) {
  final result = <String, DateTime>{};
  for (final entry in source.entries) {
    final id = _canonicalPracticeActivityId(entry.key);
    if (_isSafePracticeActivityId(id)) result[id] = entry.value.toUtc();
    if (result.length == 50) break;
  }
  return result;
}

Map<String, PracticeBestRecord> _normalizePracticeBestRecords(
  Map<String, PracticeBestRecord> source,
) {
  final result = <String, PracticeBestRecord>{};
  for (final entry in source.entries) {
    final id = _canonicalPracticeActivityId(entry.key);
    final safe = PracticeBestRecord.tryFromJson(entry.value.toJson());
    if (_isSafePracticeActivityId(id) && safe != null) result[id] = safe;
    if (result.length == 50) break;
  }
  return result;
}

List<PracticePlaylist> _normalizePracticePlaylists(
  Iterable<PracticePlaylist> source, {
  required Set<String> hiddenActivityIds,
}) {
  final result = <PracticePlaylist>[];
  final used = <String>{};
  for (final playlist in source) {
    final visibleIds = playlist.activityIds
        .where((id) => !hiddenActivityIds.contains(id))
        .toList(growable: false);
    final safe = PracticePlaylist.tryFromJson({
      ...playlist.toJson(),
      'activityIds': visibleIds,
    });
    if (safe != null && used.add(safe.id)) result.add(safe);
    if (result.length == 10) break;
  }
  return result;
}

bool _isSafePracticeActivityId(String value) =>
    value.isNotEmpty &&
    value == value.trim() &&
    value.runes.length <= 160 &&
    !value.runes.any((rune) => rune < 0x20 || rune == 0x7f);

bool isPlaylistCompatiblePracticeActivity(String activityId) =>
    practiceRouteForActivityId(activityId) != null;

String? practiceRouteForActivityId(String activityId) {
  return switch (_canonicalPracticeActivityId(activityId)) {
    'mixed-quiz' => '/study?mode=mixed',
    'meaning-choice' => '/study?mode=meaning',
    'production-writing' => '/study?mode=production',
    'sentence-cloze' => '/study?mode=cloze',
    'sentence-order' => '/study?mode=sentenceOrder',
    'listening-dictation' => '/study?mode=listening',
    'listening-discrimination' =>
      '/study?mode=listening&practiceActivityId=listening-discrimination',
    'exam-simulator' =>
      '/study?mode=mixed&exam=true&practiceActivityId=exam-simulator',
    'match-sprint' => '/study?mode=mixed&match=true',
    'due-review' => '/study?mode=review',
    'recent-wrong' => '/study?mode=weak&historyFilter=wrongOnly',
    'weak-review' => '/study?mode=weak',
    'favorites-review' => '/study?mode=favorites',
    'words-review' => '/study?mode=words',
    _ => null,
  };
}

String _canonicalPracticeActivityId(String raw) {
  final value = raw.trim();
  if (value.isEmpty || !value.startsWith('/')) return value;
  final uri = Uri.tryParse(value);
  if (uri == null) return value;
  if (uri.path == '/study') {
    final mode = uri.queryParameters['mode'];
    if (uri.queryParameters['exam'] == 'true') return 'exam-simulator';
    if (uri.queryParameters['practiceActivityId'] ==
        'listening-discrimination') {
      return 'listening-discrimination';
    }
    if (mode == 'weak' && uri.queryParameters['historyFilter'] == 'wrongOnly') {
      return 'recent-wrong';
    }
    return switch (mode) {
      'mixed' when uri.queryParameters['match'] == 'true' => 'match-sprint',
      'mixed' => 'mixed-quiz',
      'review' => 'due-review',
      'weak' => 'weak-review',
      'favorites' => 'favorites-review',
      'words' => 'words-review',
      'meaning' => 'meaning-choice',
      'production' => 'production-writing',
      'cloze' => 'sentence-cloze',
      'sentenceOrder' => 'sentence-order',
      'listening' => 'listening-dictation',
      _ => value,
    };
  }
  if (uri.path == '/cards') {
    return switch (uri.queryParameters['kind']) {
      'words' => 'word-cards',
      'sentences' => 'sentence-cards',
      _ => 'mixed-cards',
    };
  }
  if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'notes') {
    return 'unit-notes';
  }
  return switch (uri.path) {
    '/pronunciation' => 'pronunciation',
    '/missions' => 'situation-missions',
    '/path' => 'course-path',
    _ => value,
  };
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
      audioRepeatCount: _intInRange(
        json['audioRepeatCount'],
        fallback: 1,
        minimum: 1,
        maximum: 3,
      ),
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
      autoAdvanceDelayMs: _intInRange(
        json['autoAdvanceDelayMs'],
        fallback: 900,
        minimum: 300,
        maximum: 3000,
      ),
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

int _intInRange(
  Object? raw, {
  required int fallback,
  required int minimum,
  required int maximum,
}) {
  if (raw is! num || !raw.isFinite) return fallback;
  return raw.toInt().clamp(minimum, maximum);
}

T _enumByName<T extends Enum>(Iterable<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
