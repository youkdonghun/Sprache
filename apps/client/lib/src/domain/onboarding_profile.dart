enum LearningPurpose { dailyConversation, travel, work, exam, hobby }

enum SelfAssessedLevel { beginner, elementary, intermediate, advanced }

enum OnboardingEntryChoice { sampleLesson, importMyData }

enum OnboardingAccessibilityProfile { standard, easyAccess }

enum OnboardingThemeMode { system, light, dark }

enum OnboardingAccent { sprache, ocean, violet, coral }

enum HomeQuickAction { study, quickAdd, practice, library, importData, stats }

const defaultHomeQuickActions = <HomeQuickAction>[
  HomeQuickAction.study,
  HomeQuickAction.quickAdd,
  HomeQuickAction.practice,
];

/// Local-first draft and the durable result of the first-run setup.
///
/// The draft deliberately contains no account identifier. It can be persisted
/// before sign-in and is bounded while decoding so a damaged remote snapshot
/// cannot make onboarding unusable.
class OnboardingProfile {
  const OnboardingProfile({
    this.languageCode = '',
    this.purpose = LearningPurpose.dailyConversation,
    this.level = SelfAssessedLevel.beginner,
    this.dailyMinutes = 5,
    this.dailyGoal = 100,
    this.entryChoice = OnboardingEntryChoice.sampleLesson,
    this.draftStep = 0,
    this.studyWeekdays = const {1, 2, 3, 4, 5},
    this.scheduleConfigured = false,
    this.accessibilityProfile = OnboardingAccessibilityProfile.standard,
    this.themeMode = OnboardingThemeMode.system,
    this.accent = OnboardingAccent.sprache,
    this.quickActions = defaultHomeQuickActions,
    this.deferred = false,
  });

  static const int stepCount = 6;

  final String languageCode;
  final LearningPurpose purpose;
  final SelfAssessedLevel level;
  final int dailyMinutes;
  final int dailyGoal;
  final OnboardingEntryChoice entryChoice;
  final int draftStep;
  final Set<int> studyWeekdays;
  final bool scheduleConfigured;
  final OnboardingAccessibilityProfile accessibilityProfile;
  final OnboardingThemeMode themeMode;
  final OnboardingAccent accent;
  final List<HomeQuickAction> quickActions;
  final bool deferred;

  bool get easyAccess =>
      accessibilityProfile == OnboardingAccessibilityProfile.easyAccess;

  bool isStudyDay(DateTime localDate) =>
      !scheduleConfigured ||
      normalizedStudyWeekdays.contains(localDate.weekday);

  Set<int> get normalizedStudyWeekdays =>
      _normalizeStudyWeekdays(studyWeekdays);

  DateTime nextStudyDate(DateTime localDate, {bool includeToday = true}) {
    var candidate = DateTime(localDate.year, localDate.month, localDate.day);
    if (!includeToday) candidate = candidate.add(const Duration(days: 1));
    if (!scheduleConfigured) return candidate;
    for (var offset = 0; offset < 8; offset++) {
      if (normalizedStudyWeekdays.contains(candidate.weekday)) return candidate;
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  DateTime nextStudyDateTime(DateTime value, {bool includeToday = true}) {
    final local = value.toLocal();
    final date = nextStudyDate(local, includeToday: includeToday);
    return DateTime(
      date.year,
      date.month,
      date.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

  /// Used by the practice catalog's persisted recommendation weighting.
  String get recommendedActivityId => switch (purpose) {
    LearningPurpose.dailyConversation => 'mixed-quiz',
    LearningPurpose.travel => 'pronunciation',
    LearningPurpose.work => 'production-writing',
    LearningPurpose.exam => 'meaning-choice',
    LearningPurpose.hobby => 'words-review',
  };

  String get recommendedStarterGroupLabel => switch (purpose) {
    LearningPurpose.dailyConversation => '매일 쓰는 표현',
    LearningPurpose.travel => '여행 필수 표현',
    LearningPurpose.work => '업무 핵심 표현',
    LearningPurpose.exam => '시험 집중 복습',
    LearningPurpose.hobby => '관심 단어 모음',
  };

  OnboardingProfile copyWith({
    String? languageCode,
    LearningPurpose? purpose,
    SelfAssessedLevel? level,
    int? dailyMinutes,
    int? dailyGoal,
    OnboardingEntryChoice? entryChoice,
    int? draftStep,
    Set<int>? studyWeekdays,
    bool? scheduleConfigured,
    OnboardingAccessibilityProfile? accessibilityProfile,
    OnboardingThemeMode? themeMode,
    OnboardingAccent? accent,
    List<HomeQuickAction>? quickActions,
    bool? deferred,
  }) => OnboardingProfile(
    languageCode: languageCode ?? this.languageCode,
    purpose: purpose ?? this.purpose,
    level: level ?? this.level,
    dailyMinutes: (dailyMinutes ?? this.dailyMinutes).clamp(3, 60),
    dailyGoal: (dailyGoal ?? this.dailyGoal).clamp(20, 500),
    entryChoice: entryChoice ?? this.entryChoice,
    draftStep: (draftStep ?? this.draftStep).clamp(0, stepCount - 1),
    studyWeekdays: _normalizeStudyWeekdays(studyWeekdays ?? this.studyWeekdays),
    scheduleConfigured: scheduleConfigured ?? this.scheduleConfigured,
    accessibilityProfile: accessibilityProfile ?? this.accessibilityProfile,
    themeMode: themeMode ?? this.themeMode,
    accent: accent ?? this.accent,
    quickActions: _normalizeQuickActions(quickActions ?? this.quickActions),
    deferred: deferred ?? this.deferred,
  );

  Map<String, Object?> toJson() => {
    if (languageCode.isNotEmpty) 'languageCode': languageCode,
    'purpose': purpose.name,
    'level': level.name,
    'dailyMinutes': dailyMinutes.clamp(3, 60),
    'dailyGoal': dailyGoal.clamp(20, 500),
    'entryChoice': entryChoice.name,
    'draftStep': draftStep.clamp(0, stepCount - 1),
    'studyWeekdays': normalizedStudyWeekdays.toList()..sort(),
    'scheduleConfigured': scheduleConfigured,
    'accessibilityProfile': accessibilityProfile.name,
    'themeMode': themeMode.name,
    'accent': accent.name,
    'quickActions': _normalizeQuickActions(
      quickActions,
    ).map((value) => value.name).toList(growable: false),
    'deferred': deferred,
  };

  factory OnboardingProfile.fromJson(Map<String, Object?> json) {
    return OnboardingProfile(
      languageCode: _safeLanguageCode(json['languageCode']),
      purpose: _enumByName(
        LearningPurpose.values,
        json['purpose'],
        LearningPurpose.dailyConversation,
      ),
      level: _enumByName(
        SelfAssessedLevel.values,
        json['level'],
        SelfAssessedLevel.beginner,
      ),
      dailyMinutes: _safeInt(json['dailyMinutes'], 5, 3, 60),
      dailyGoal: _safeInt(json['dailyGoal'], 100, 20, 500),
      entryChoice: _enumByName(
        OnboardingEntryChoice.values,
        json['entryChoice'],
        OnboardingEntryChoice.sampleLesson,
      ),
      draftStep: _safeInt(json['draftStep'], 0, 0, stepCount - 1),
      studyWeekdays: _parseStudyWeekdays(json['studyWeekdays']),
      scheduleConfigured: json['scheduleConfigured'] is bool
          ? json['scheduleConfigured']! as bool
          : false,
      accessibilityProfile: _enumByName(
        OnboardingAccessibilityProfile.values,
        json['accessibilityProfile'],
        OnboardingAccessibilityProfile.standard,
      ),
      themeMode: _enumByName(
        OnboardingThemeMode.values,
        json['themeMode'],
        OnboardingThemeMode.system,
      ),
      accent: _enumByName(
        OnboardingAccent.values,
        json['accent'],
        OnboardingAccent.sprache,
      ),
      quickActions: _parseQuickActions(json['quickActions']),
      deferred: json['deferred'] is bool ? json['deferred']! as bool : false,
    );
  }
}

Set<int> _normalizeStudyWeekdays(Iterable<int> values) {
  final safe = values.where((value) => value >= 1 && value <= 7).toSet();
  if (safe.isEmpty) return const {1, 2, 3, 4, 5};
  return Set.unmodifiable(safe);
}

Set<int> _parseStudyWeekdays(Object? raw) {
  if (raw is! List) return const {1, 2, 3, 4, 5};
  return _normalizeStudyWeekdays(
    raw.whereType<num>().map((value) => value.toInt()),
  );
}

List<HomeQuickAction> _normalizeQuickActions(Iterable<HomeQuickAction> values) {
  final result = <HomeQuickAction>[];
  for (final value in values) {
    if (!result.contains(value)) result.add(value);
    if (result.length == 3) break;
  }
  for (final value in defaultHomeQuickActions) {
    if (result.length == 3) break;
    if (!result.contains(value)) result.add(value);
  }
  return List.unmodifiable(result);
}

List<HomeQuickAction> _parseQuickActions(Object? raw) {
  if (raw is! List) return defaultHomeQuickActions;
  final values = <HomeQuickAction>[];
  for (final name in raw.whereType<String>()) {
    for (final value in HomeQuickAction.values) {
      if (value.name == name) values.add(value);
    }
  }
  return _normalizeQuickActions(values);
}

String _safeLanguageCode(Object? raw) {
  if (raw is! String) return '';
  final value = raw.trim();
  if (!RegExp(r'^[A-Za-z]{2,3}(?:-[A-Za-z]{2,8})?$').hasMatch(value)) {
    return '';
  }
  return value;
}

int _safeInt(Object? raw, int fallback, int minimum, int maximum) {
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
