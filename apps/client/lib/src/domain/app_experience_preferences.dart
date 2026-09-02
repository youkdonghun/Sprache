enum AppColorMode { system, light, dark, oled }

enum AppAccentPalette {
  sprache,
  forest,
  ocean,
  violet,
  coral,
  slate,
  sunrise,
  mint,
  rose,
  mono,
}

enum AppDensity { platform, comfortable, compact }

enum AppTextScale { system, small, medium, large, extraLarge }

enum AppSurfaceTone { neutral, warm, cool }

enum AppCornerStyle { rounded, balanced, square }

enum AppCardStyle { flat, outlined, elevated }

enum AppContentWidth { focused, balanced, wide }

enum AppFontEmphasis { standard, strong }

enum AppFontFamily { notoSans, system, serif, monospace }

enum AppThemeScheduleMode { off, evening, custom }

enum AppStudyTextScale { sameAsApp, larger, extraLarge }

enum AppCardAlignment { adaptive, leading, centered }

enum AppNavigationIconStyle { adaptive, outlined, filled }

enum AppDecorationIntensity { minimal, balanced, vivid }

enum AppMotionLevel { full, reduced, off }

enum AppCelebrationLevel { full, subtle, off }

enum AppHomeLayout { focus, balanced, insights }

enum AppNavigationLabelMode { always, selected, iconsOnly }

enum AppSubjectSwitcherStyle { full, compact }

enum AppQuickAddKind { word, sentence, lastUsed }

enum AppDuplicateDefault { ask, merge, separate }

enum AppFeedbackDetail { concise, balanced, coach }

enum AppProgressStyle { bar, steps, minimal }

enum AppEncouragementTone { calm, playful, minimal }

enum AppReadingLineHeight { compact, comfortable, relaxed }

enum AppReadingWidth { narrow, balanced, wide }

enum AppHomeSection { pinnedCollections, recentAdditions, dataFlow, schedules }

const defaultAppHomeSectionOrder = <AppHomeSection>[
  AppHomeSection.pinnedCollections,
  AppHomeSection.recentAdditions,
  AppHomeSection.dataFlow,
  AppHomeSection.schedules,
];

const _experienceTimestampNotProvided = Object();
const _activeThemeProfileNotProvided = Object();

class AppThemeProfile {
  const AppThemeProfile({
    required this.id,
    required this.name,
    required this.colorMode,
    required this.accentPalette,
    required this.separateBrightnessAccents,
    required this.lightAccentPalette,
    required this.darkAccentPalette,
    required this.themeScheduleMode,
    required this.themeDarkStartHour,
    required this.themeLightStartHour,
    required this.scheduledDarkUsesOled,
    required this.customAccentEnabled,
    required this.customAccentRgb,
    required this.density,
    required this.surfaceTone,
    required this.cornerStyle,
    required this.cardStyle,
    required this.contentWidth,
    required this.fontEmphasis,
    required this.fontFamily,
    required this.textScale,
    required this.studyTextScale,
    required this.readingLineHeight,
    required this.readingWidth,
    required this.highContrast,
    required this.showFocusRing,
    required this.cardAlignment,
    required this.navigationIconStyle,
    required this.decorationIntensity,
    required this.motionLevel,
    required this.celebrationLevel,
  });

  factory AppThemeProfile.capture({
    required String id,
    required String name,
    required AppExperiencePreferences preferences,
  }) => AppThemeProfile(
    id: id,
    name: name,
    colorMode: preferences.colorMode,
    accentPalette: preferences.accentPalette,
    separateBrightnessAccents: preferences.separateBrightnessAccents,
    lightAccentPalette: preferences.lightAccentPalette,
    darkAccentPalette: preferences.darkAccentPalette,
    themeScheduleMode: preferences.themeScheduleMode,
    themeDarkStartHour: preferences.themeDarkStartHour,
    themeLightStartHour: preferences.themeLightStartHour,
    scheduledDarkUsesOled: preferences.scheduledDarkUsesOled,
    customAccentEnabled: preferences.customAccentEnabled,
    customAccentRgb: preferences.customAccentRgb,
    density: preferences.density,
    surfaceTone: preferences.surfaceTone,
    cornerStyle: preferences.cornerStyle,
    cardStyle: preferences.cardStyle,
    contentWidth: preferences.contentWidth,
    fontEmphasis: preferences.fontEmphasis,
    fontFamily: preferences.fontFamily,
    textScale: preferences.textScale,
    studyTextScale: preferences.studyTextScale,
    readingLineHeight: preferences.readingLineHeight,
    readingWidth: preferences.readingWidth,
    highContrast: preferences.highContrast,
    showFocusRing: preferences.showFocusRing,
    cardAlignment: preferences.cardAlignment,
    navigationIconStyle: preferences.navigationIconStyle,
    decorationIntensity: preferences.decorationIntensity,
    motionLevel: preferences.motionLevel,
    celebrationLevel: preferences.celebrationLevel,
  );

  final String id;
  final String name;
  final AppColorMode colorMode;
  final AppAccentPalette accentPalette;
  final bool separateBrightnessAccents;
  final AppAccentPalette lightAccentPalette;
  final AppAccentPalette darkAccentPalette;
  final AppThemeScheduleMode themeScheduleMode;
  final int themeDarkStartHour;
  final int themeLightStartHour;
  final bool scheduledDarkUsesOled;
  final bool customAccentEnabled;
  final int customAccentRgb;
  final AppDensity density;
  final AppSurfaceTone surfaceTone;
  final AppCornerStyle cornerStyle;
  final AppCardStyle cardStyle;
  final AppContentWidth contentWidth;
  final AppFontEmphasis fontEmphasis;
  final AppFontFamily fontFamily;
  final AppTextScale textScale;
  final AppStudyTextScale studyTextScale;
  final AppReadingLineHeight readingLineHeight;
  final AppReadingWidth readingWidth;
  final bool highContrast;
  final bool showFocusRing;
  final AppCardAlignment cardAlignment;
  final AppNavigationIconStyle navigationIconStyle;
  final AppDecorationIntensity decorationIntensity;
  final AppMotionLevel motionLevel;
  final AppCelebrationLevel celebrationLevel;

  AppExperiencePreferences applyTo(AppExperiencePreferences current) =>
      current.copyWith(
        colorMode: colorMode,
        accentPalette: accentPalette,
        separateBrightnessAccents: separateBrightnessAccents,
        lightAccentPalette: lightAccentPalette,
        darkAccentPalette: darkAccentPalette,
        themeScheduleMode: themeScheduleMode,
        themeDarkStartHour: themeDarkStartHour,
        themeLightStartHour: themeLightStartHour,
        scheduledDarkUsesOled: scheduledDarkUsesOled,
        customAccentEnabled: customAccentEnabled,
        customAccentRgb: customAccentRgb,
        perSubjectAccentEnabled: false,
        density: density,
        surfaceTone: surfaceTone,
        cornerStyle: cornerStyle,
        cardStyle: cardStyle,
        contentWidth: contentWidth,
        fontEmphasis: fontEmphasis,
        fontFamily: fontFamily,
        textScale: textScale,
        studyTextScale: studyTextScale,
        readingLineHeight: readingLineHeight,
        readingWidth: readingWidth,
        highContrast: highContrast,
        showFocusRing: showFocusRing,
        cardAlignment: cardAlignment,
        navigationIconStyle: navigationIconStyle,
        decorationIntensity: decorationIntensity,
        motionLevel: motionLevel,
        reduceMotion: motionLevel == AppMotionLevel.off,
        celebrationLevel: celebrationLevel,
        activeThemeProfileId: id,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'colorMode': colorMode.name,
    'accentPalette': accentPalette.name,
    'separateBrightnessAccents': separateBrightnessAccents,
    'lightAccentPalette': lightAccentPalette.name,
    'darkAccentPalette': darkAccentPalette.name,
    'themeScheduleMode': themeScheduleMode.name,
    'themeDarkStartHour': themeDarkStartHour,
    'themeLightStartHour': themeLightStartHour,
    'scheduledDarkUsesOled': scheduledDarkUsesOled,
    'customAccentEnabled': customAccentEnabled,
    'customAccentRgb': customAccentRgb,
    'density': density.name,
    'surfaceTone': surfaceTone.name,
    'cornerStyle': cornerStyle.name,
    'cardStyle': cardStyle.name,
    'contentWidth': contentWidth.name,
    'fontEmphasis': fontEmphasis.name,
    'fontFamily': fontFamily.name,
    'textScale': textScale.name,
    'studyTextScale': studyTextScale.name,
    'readingLineHeight': readingLineHeight.name,
    'readingWidth': readingWidth.name,
    'highContrast': highContrast,
    'showFocusRing': showFocusRing,
    'cardAlignment': cardAlignment.name,
    'navigationIconStyle': navigationIconStyle.name,
    'decorationIntensity': decorationIntensity.name,
    'motionLevel': motionLevel.name,
    'celebrationLevel': celebrationLevel.name,
  };

  static AppThemeProfile? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = <String, Object?>{
      for (final entry in raw.entries)
        if (entry.key is String) entry.key! as String: entry.value,
    };
    final id = _safeProfileId(json['id']);
    final name = _safeProfileName(json['name']);
    if (id == null || name == null) return null;
    final colorMode = _strictEnum(AppColorMode.values, json['colorMode']);
    final accent = _strictEnum(AppAccentPalette.values, json['accentPalette']);
    final lightAccent = _strictEnum(
      AppAccentPalette.values,
      json['lightAccentPalette'],
    );
    final darkAccent = _strictEnum(
      AppAccentPalette.values,
      json['darkAccentPalette'],
    );
    final schedule = _strictEnum(
      AppThemeScheduleMode.values,
      json['themeScheduleMode'],
    );
    final surface = _strictEnum(AppSurfaceTone.values, json['surfaceTone']);
    final corner = _strictEnum(AppCornerStyle.values, json['cornerStyle']);
    final card = _strictEnum(AppCardStyle.values, json['cardStyle']);
    final width = _strictEnum(AppContentWidth.values, json['contentWidth']);
    final emphasis = _strictEnum(AppFontEmphasis.values, json['fontEmphasis']);
    final font = _strictEnum(AppFontFamily.values, json['fontFamily']);
    final textScale = _strictEnum(AppTextScale.values, json['textScale']);
    final studyScale = _strictEnum(
      AppStudyTextScale.values,
      json['studyTextScale'],
    );
    final lineHeight = _strictEnum(
      AppReadingLineHeight.values,
      json['readingLineHeight'],
    );
    final readingWidth = _strictEnum(
      AppReadingWidth.values,
      json['readingWidth'],
    );
    final alignment = _strictEnum(
      AppCardAlignment.values,
      json['cardAlignment'],
    );
    final iconStyle = _strictEnum(
      AppNavigationIconStyle.values,
      json['navigationIconStyle'],
    );
    final decoration = _strictEnum(
      AppDecorationIntensity.values,
      json['decorationIntensity'],
    );
    final darkHour = _strictHour(json['themeDarkStartHour']);
    final lightHour = _strictHour(json['themeLightStartHour']);
    final rgb = _strictRgb(json['customAccentRgb']);
    final density = _strictEnum(AppDensity.values, json['density']);
    final motion = _strictEnum(AppMotionLevel.values, json['motionLevel']);
    final celebration = _strictEnum(
      AppCelebrationLevel.values,
      json['celebrationLevel'],
    );
    if (colorMode == null ||
        accent == null ||
        lightAccent == null ||
        darkAccent == null ||
        schedule == null ||
        surface == null ||
        corner == null ||
        card == null ||
        width == null ||
        emphasis == null ||
        font == null ||
        textScale == null ||
        studyScale == null ||
        lineHeight == null ||
        readingWidth == null ||
        alignment == null ||
        iconStyle == null ||
        decoration == null ||
        darkHour == null ||
        lightHour == null ||
        rgb == null ||
        density == null ||
        motion == null ||
        celebration == null) {
      return null;
    }
    for (final field in const [
      'separateBrightnessAccents',
      'scheduledDarkUsesOled',
      'customAccentEnabled',
      'highContrast',
      'showFocusRing',
    ]) {
      if (json[field] is! bool) return null;
    }
    return AppThemeProfile(
      id: id,
      name: name,
      colorMode: colorMode,
      accentPalette: accent,
      separateBrightnessAccents: json['separateBrightnessAccents']! as bool,
      lightAccentPalette: lightAccent,
      darkAccentPalette: darkAccent,
      themeScheduleMode: schedule,
      themeDarkStartHour: darkHour,
      themeLightStartHour: lightHour,
      scheduledDarkUsesOled: json['scheduledDarkUsesOled']! as bool,
      customAccentEnabled: json['customAccentEnabled']! as bool,
      customAccentRgb: rgb,
      density: density,
      surfaceTone: surface,
      cornerStyle: corner,
      cardStyle: card,
      contentWidth: width,
      fontEmphasis: emphasis,
      fontFamily: font,
      textScale: textScale,
      studyTextScale: studyScale,
      readingLineHeight: lineHeight,
      readingWidth: readingWidth,
      highContrast: json['highContrast']! as bool,
      showFocusRing: json['showFocusRing']! as bool,
      cardAlignment: alignment,
      navigationIconStyle: iconStyle,
      decorationIntensity: decoration,
      motionLevel: motion,
      celebrationLevel: celebration,
    );
  }
}

class AppExperiencePreferences {
  const AppExperiencePreferences({
    this.colorMode = AppColorMode.system,
    this.accentPalette = AppAccentPalette.sprache,
    this.separateBrightnessAccents = false,
    this.lightAccentPalette = AppAccentPalette.sprache,
    this.darkAccentPalette = AppAccentPalette.sprache,
    this.themeScheduleMode = AppThemeScheduleMode.off,
    this.themeDarkStartHour = 19,
    this.themeLightStartHour = 7,
    this.scheduledDarkUsesOled = false,
    this.customAccentEnabled = false,
    this.customAccentRgb = 0x3D8F40,
    this.themeProfiles = const [],
    this.activeThemeProfileId,
    this.density = AppDensity.platform,
    this.textScale = AppTextScale.system,
    this.surfaceTone = AppSurfaceTone.neutral,
    this.cornerStyle = AppCornerStyle.balanced,
    this.cardStyle = AppCardStyle.outlined,
    this.contentWidth = AppContentWidth.balanced,
    this.fontEmphasis = AppFontEmphasis.standard,
    this.fontFamily = AppFontFamily.notoSans,
    this.studyTextScale = AppStudyTextScale.sameAsApp,
    this.cardAlignment = AppCardAlignment.adaptive,
    this.navigationIconStyle = AppNavigationIconStyle.adaptive,
    this.decorationIntensity = AppDecorationIntensity.balanced,
    this.motionLevel = AppMotionLevel.full,
    this.celebrationLevel = AppCelebrationLevel.full,
    this.homeLayout = AppHomeLayout.balanced,
    this.navigationLabelMode = AppNavigationLabelMode.always,
    this.subjectSwitcherStyle = AppSubjectSwitcherStyle.full,
    this.quickAddKind = AppQuickAddKind.word,
    this.duplicateDefault = AppDuplicateDefault.ask,
    this.feedbackDetail = AppFeedbackDetail.balanced,
    this.progressStyle = AppProgressStyle.bar,
    this.encouragementTone = AppEncouragementTone.calm,
    this.readingLineHeight = AppReadingLineHeight.comfortable,
    this.readingWidth = AppReadingWidth.balanced,
    this.highContrast = false,
    this.showFocusRing = true,
    this.simpleHome = true,
    this.showHomeHeader = true,
    this.showStreak = true,
    this.showXp = true,
    this.showSyncStatus = true,
    this.showTodayPlan = true,
    this.showPinnedCollections = true,
    this.showRecentAdditions = true,
    this.showDataFlow = true,
    this.showSchedules = true,
    this.homeSectionOrder = defaultAppHomeSectionOrder,
    this.showQuickAdd = true,
    this.showGlobalSearch = true,
    this.quickAddFavoriteDefault = false,
    this.quickAddPriorityDefault = 0,
    this.quickAddOpenDetails = false,
    this.quickAddKeepAddingDefault = false,
    this.quickAddAutoNormalize = false,
    this.quickAddRememberTags = false,
    this.quickAddDraftDelayMs = 450,
    this.showShortcutHints = true,
    this.focusStudyMode = false,
    this.leftHandedControls = false,
    this.showStudyTimer = true,
    this.showQuestionCounter = true,
    this.perSubjectAccentEnabled = false,
    this.accentPaletteBySubject = const {},
    this.reduceMotion = false,
    this.hapticsEnabled = false,
    this.soundEffectsEnabled = false,
    this.updatedAt,
  });

  final AppColorMode colorMode;
  final AppAccentPalette accentPalette;
  final bool separateBrightnessAccents;
  final AppAccentPalette lightAccentPalette;
  final AppAccentPalette darkAccentPalette;
  final AppThemeScheduleMode themeScheduleMode;
  final int themeDarkStartHour;
  final int themeLightStartHour;
  final bool scheduledDarkUsesOled;
  final bool customAccentEnabled;
  final int customAccentRgb;
  final List<AppThemeProfile> themeProfiles;
  final String? activeThemeProfileId;
  final AppDensity density;
  final AppTextScale textScale;
  final AppSurfaceTone surfaceTone;
  final AppCornerStyle cornerStyle;
  final AppCardStyle cardStyle;
  final AppContentWidth contentWidth;
  final AppFontEmphasis fontEmphasis;
  final AppFontFamily fontFamily;
  final AppStudyTextScale studyTextScale;
  final AppCardAlignment cardAlignment;
  final AppNavigationIconStyle navigationIconStyle;
  final AppDecorationIntensity decorationIntensity;
  final AppMotionLevel motionLevel;
  final AppCelebrationLevel celebrationLevel;
  final AppHomeLayout homeLayout;
  final AppNavigationLabelMode navigationLabelMode;
  final AppSubjectSwitcherStyle subjectSwitcherStyle;
  final AppQuickAddKind quickAddKind;
  final AppDuplicateDefault duplicateDefault;
  final AppFeedbackDetail feedbackDetail;
  final AppProgressStyle progressStyle;
  final AppEncouragementTone encouragementTone;
  final AppReadingLineHeight readingLineHeight;
  final AppReadingWidth readingWidth;
  final bool highContrast;
  final bool showFocusRing;
  final bool simpleHome;
  final bool showHomeHeader;
  final bool showStreak;
  final bool showXp;
  final bool showSyncStatus;
  final bool showTodayPlan;
  final bool showPinnedCollections;
  final bool showRecentAdditions;
  final bool showDataFlow;
  final bool showSchedules;
  final List<AppHomeSection> homeSectionOrder;
  final bool showQuickAdd;
  final bool showGlobalSearch;
  final bool quickAddFavoriteDefault;
  final int quickAddPriorityDefault;
  final bool quickAddOpenDetails;
  final bool quickAddKeepAddingDefault;
  final bool quickAddAutoNormalize;
  final bool quickAddRememberTags;
  final int quickAddDraftDelayMs;
  final bool showShortcutHints;
  final bool focusStudyMode;
  final bool leftHandedControls;
  final bool showStudyTimer;
  final bool showQuestionCounter;
  final bool perSubjectAccentEnabled;
  final Map<String, AppAccentPalette> accentPaletteBySubject;

  /// Kept so snapshots written before [motionLevel] remain compatible.
  final bool reduceMotion;
  final bool hapticsEnabled;
  final bool soundEffectsEnabled;
  final DateTime? updatedAt;

  bool get effectiveReduceMotion =>
      reduceMotion || motionLevel == AppMotionLevel.off;

  AppAccentPalette accentPaletteForBrightness({required bool isDark}) =>
      separateBrightnessAccents
      ? isDark
            ? darkAccentPalette
            : lightAccentPalette
      : accentPalette;

  AppColorMode colorModeAt(DateTime localTime) {
    if (themeScheduleMode == AppThemeScheduleMode.off) return colorMode;
    final darkHour = themeScheduleMode == AppThemeScheduleMode.evening
        ? 19
        : themeDarkStartHour;
    final lightHour = themeScheduleMode == AppThemeScheduleMode.evening
        ? 7
        : themeLightStartHour;
    if (darkHour == lightHour) return colorMode;
    final hour = localTime.hour;
    final isDark = darkHour < lightHour
        ? hour >= darkHour && hour < lightHour
        : hour >= darkHour || hour < lightHour;
    if (!isDark) return AppColorMode.light;
    return scheduledDarkUsesOled ? AppColorMode.oled : AppColorMode.dark;
  }

  DateTime? nextThemeBoundaryAfter(DateTime localTime) {
    if (themeScheduleMode == AppThemeScheduleMode.off) return null;
    final darkHour = themeScheduleMode == AppThemeScheduleMode.evening
        ? 19
        : themeDarkStartHour;
    final lightHour = themeScheduleMode == AppThemeScheduleMode.evening
        ? 7
        : themeLightStartHour;
    if (darkHour == lightHour) return null;
    DateTime nextAt(int hour) {
      var candidate = DateTime(
        localTime.year,
        localTime.month,
        localTime.day,
        hour,
      );
      if (!candidate.isAfter(localTime)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }

    final nextDark = nextAt(darkHour);
    final nextLight = nextAt(lightHour);
    return nextDark.isBefore(nextLight) ? nextDark : nextLight;
  }

  AppExperiencePreferences copyWith({
    AppColorMode? colorMode,
    AppAccentPalette? accentPalette,
    bool? separateBrightnessAccents,
    AppAccentPalette? lightAccentPalette,
    AppAccentPalette? darkAccentPalette,
    AppThemeScheduleMode? themeScheduleMode,
    int? themeDarkStartHour,
    int? themeLightStartHour,
    bool? scheduledDarkUsesOled,
    bool? customAccentEnabled,
    int? customAccentRgb,
    List<AppThemeProfile>? themeProfiles,
    Object? activeThemeProfileId = _activeThemeProfileNotProvided,
    AppDensity? density,
    AppTextScale? textScale,
    AppSurfaceTone? surfaceTone,
    AppCornerStyle? cornerStyle,
    AppCardStyle? cardStyle,
    AppContentWidth? contentWidth,
    AppFontEmphasis? fontEmphasis,
    AppFontFamily? fontFamily,
    AppStudyTextScale? studyTextScale,
    AppCardAlignment? cardAlignment,
    AppNavigationIconStyle? navigationIconStyle,
    AppDecorationIntensity? decorationIntensity,
    AppMotionLevel? motionLevel,
    AppCelebrationLevel? celebrationLevel,
    AppHomeLayout? homeLayout,
    AppNavigationLabelMode? navigationLabelMode,
    AppSubjectSwitcherStyle? subjectSwitcherStyle,
    AppQuickAddKind? quickAddKind,
    AppDuplicateDefault? duplicateDefault,
    AppFeedbackDetail? feedbackDetail,
    AppProgressStyle? progressStyle,
    AppEncouragementTone? encouragementTone,
    AppReadingLineHeight? readingLineHeight,
    AppReadingWidth? readingWidth,
    bool? highContrast,
    bool? showFocusRing,
    bool? simpleHome,
    bool? showHomeHeader,
    bool? showStreak,
    bool? showXp,
    bool? showSyncStatus,
    bool? showTodayPlan,
    bool? showPinnedCollections,
    bool? showRecentAdditions,
    bool? showDataFlow,
    bool? showSchedules,
    List<AppHomeSection>? homeSectionOrder,
    bool? showQuickAdd,
    bool? showGlobalSearch,
    bool? quickAddFavoriteDefault,
    int? quickAddPriorityDefault,
    bool? quickAddOpenDetails,
    bool? quickAddKeepAddingDefault,
    bool? quickAddAutoNormalize,
    bool? quickAddRememberTags,
    int? quickAddDraftDelayMs,
    bool? showShortcutHints,
    bool? focusStudyMode,
    bool? leftHandedControls,
    bool? showStudyTimer,
    bool? showQuestionCounter,
    bool? perSubjectAccentEnabled,
    Map<String, AppAccentPalette>? accentPaletteBySubject,
    bool? reduceMotion,
    bool? hapticsEnabled,
    bool? soundEffectsEnabled,
    Object? updatedAt = _experienceTimestampNotProvided,
  }) {
    return AppExperiencePreferences(
      colorMode: colorMode ?? this.colorMode,
      accentPalette: accentPalette ?? this.accentPalette,
      separateBrightnessAccents:
          separateBrightnessAccents ?? this.separateBrightnessAccents,
      lightAccentPalette: lightAccentPalette ?? this.lightAccentPalette,
      darkAccentPalette: darkAccentPalette ?? this.darkAccentPalette,
      themeScheduleMode: themeScheduleMode ?? this.themeScheduleMode,
      themeDarkStartHour: themeDarkStartHour ?? this.themeDarkStartHour,
      themeLightStartHour: themeLightStartHour ?? this.themeLightStartHour,
      scheduledDarkUsesOled:
          scheduledDarkUsesOled ?? this.scheduledDarkUsesOled,
      customAccentEnabled: customAccentEnabled ?? this.customAccentEnabled,
      customAccentRgb: customAccentRgb ?? this.customAccentRgb,
      themeProfiles: List<AppThemeProfile>.unmodifiable(
        (themeProfiles ?? this.themeProfiles).take(5),
      ),
      activeThemeProfileId:
          identical(activeThemeProfileId, _activeThemeProfileNotProvided)
          ? this.activeThemeProfileId
          : activeThemeProfileId as String?,
      density: density ?? this.density,
      textScale: textScale ?? this.textScale,
      surfaceTone: surfaceTone ?? this.surfaceTone,
      cornerStyle: cornerStyle ?? this.cornerStyle,
      cardStyle: cardStyle ?? this.cardStyle,
      contentWidth: contentWidth ?? this.contentWidth,
      fontEmphasis: fontEmphasis ?? this.fontEmphasis,
      fontFamily: fontFamily ?? this.fontFamily,
      studyTextScale: studyTextScale ?? this.studyTextScale,
      cardAlignment: cardAlignment ?? this.cardAlignment,
      navigationIconStyle: navigationIconStyle ?? this.navigationIconStyle,
      decorationIntensity: decorationIntensity ?? this.decorationIntensity,
      motionLevel: motionLevel ?? this.motionLevel,
      celebrationLevel: celebrationLevel ?? this.celebrationLevel,
      homeLayout: homeLayout ?? this.homeLayout,
      navigationLabelMode: navigationLabelMode ?? this.navigationLabelMode,
      subjectSwitcherStyle: subjectSwitcherStyle ?? this.subjectSwitcherStyle,
      quickAddKind: quickAddKind ?? this.quickAddKind,
      duplicateDefault: duplicateDefault ?? this.duplicateDefault,
      feedbackDetail: feedbackDetail ?? this.feedbackDetail,
      progressStyle: progressStyle ?? this.progressStyle,
      encouragementTone: encouragementTone ?? this.encouragementTone,
      readingLineHeight: readingLineHeight ?? this.readingLineHeight,
      readingWidth: readingWidth ?? this.readingWidth,
      highContrast: highContrast ?? this.highContrast,
      showFocusRing: showFocusRing ?? this.showFocusRing,
      simpleHome: simpleHome ?? this.simpleHome,
      showHomeHeader: showHomeHeader ?? this.showHomeHeader,
      showStreak: showStreak ?? this.showStreak,
      showXp: showXp ?? this.showXp,
      showSyncStatus: showSyncStatus ?? this.showSyncStatus,
      showTodayPlan: showTodayPlan ?? this.showTodayPlan,
      showPinnedCollections:
          showPinnedCollections ?? this.showPinnedCollections,
      showRecentAdditions: showRecentAdditions ?? this.showRecentAdditions,
      showDataFlow: showDataFlow ?? this.showDataFlow,
      showSchedules: showSchedules ?? this.showSchedules,
      homeSectionOrder: List<AppHomeSection>.unmodifiable(
        homeSectionOrder ?? this.homeSectionOrder,
      ),
      showQuickAdd: showQuickAdd ?? this.showQuickAdd,
      showGlobalSearch: showGlobalSearch ?? this.showGlobalSearch,
      quickAddFavoriteDefault:
          quickAddFavoriteDefault ?? this.quickAddFavoriteDefault,
      quickAddPriorityDefault:
          quickAddPriorityDefault ?? this.quickAddPriorityDefault,
      quickAddOpenDetails: quickAddOpenDetails ?? this.quickAddOpenDetails,
      quickAddKeepAddingDefault:
          quickAddKeepAddingDefault ?? this.quickAddKeepAddingDefault,
      quickAddAutoNormalize:
          quickAddAutoNormalize ?? this.quickAddAutoNormalize,
      quickAddRememberTags: quickAddRememberTags ?? this.quickAddRememberTags,
      quickAddDraftDelayMs: quickAddDraftDelayMs ?? this.quickAddDraftDelayMs,
      showShortcutHints: showShortcutHints ?? this.showShortcutHints,
      focusStudyMode: focusStudyMode ?? this.focusStudyMode,
      leftHandedControls: leftHandedControls ?? this.leftHandedControls,
      showStudyTimer: showStudyTimer ?? this.showStudyTimer,
      showQuestionCounter: showQuestionCounter ?? this.showQuestionCounter,
      perSubjectAccentEnabled:
          perSubjectAccentEnabled ?? this.perSubjectAccentEnabled,
      accentPaletteBySubject: Map<String, AppAccentPalette>.unmodifiable(
        accentPaletteBySubject ?? this.accentPaletteBySubject,
      ),
      reduceMotion: reduceMotion ?? this.reduceMotion,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      updatedAt: identical(updatedAt, _experienceTimestampNotProvided)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }

  Map<String, Object?> toJson() => {
    'colorMode': colorMode.name,
    'accentPalette': accentPalette.name,
    'separateBrightnessAccents': separateBrightnessAccents,
    'lightAccentPalette': lightAccentPalette.name,
    'darkAccentPalette': darkAccentPalette.name,
    'themeScheduleMode': themeScheduleMode.name,
    'themeDarkStartHour': themeDarkStartHour,
    'themeLightStartHour': themeLightStartHour,
    'scheduledDarkUsesOled': scheduledDarkUsesOled,
    'customAccentEnabled': customAccentEnabled,
    'customAccentRgb': customAccentRgb,
    'themeProfiles': themeProfiles
        .map((profile) => profile.toJson())
        .toList(growable: false),
    if (activeThemeProfileId != null)
      'activeThemeProfileId': activeThemeProfileId,
    'density': density.name,
    'textScale': textScale.name,
    'surfaceTone': surfaceTone.name,
    'cornerStyle': cornerStyle.name,
    'cardStyle': cardStyle.name,
    'contentWidth': contentWidth.name,
    'fontEmphasis': fontEmphasis.name,
    'fontFamily': fontFamily.name,
    'studyTextScale': studyTextScale.name,
    'cardAlignment': cardAlignment.name,
    'navigationIconStyle': navigationIconStyle.name,
    'decorationIntensity': decorationIntensity.name,
    'motionLevel': motionLevel.name,
    'celebrationLevel': celebrationLevel.name,
    'homeLayout': homeLayout.name,
    'navigationLabelMode': navigationLabelMode.name,
    'subjectSwitcherStyle': subjectSwitcherStyle.name,
    'quickAddKind': quickAddKind.name,
    'duplicateDefault': duplicateDefault.name,
    'feedbackDetail': feedbackDetail.name,
    'progressStyle': progressStyle.name,
    'encouragementTone': encouragementTone.name,
    'readingLineHeight': readingLineHeight.name,
    'readingWidth': readingWidth.name,
    'highContrast': highContrast,
    'showFocusRing': showFocusRing,
    'simpleHome': simpleHome,
    'showHomeHeader': showHomeHeader,
    'showStreak': showStreak,
    'showXp': showXp,
    'showSyncStatus': showSyncStatus,
    'showTodayPlan': showTodayPlan,
    'showPinnedCollections': showPinnedCollections,
    'showRecentAdditions': showRecentAdditions,
    'showDataFlow': showDataFlow,
    'showSchedules': showSchedules,
    'homeSectionOrder': homeSectionOrder
        .map((section) => section.name)
        .toList(growable: false),
    'showQuickAdd': showQuickAdd,
    'showGlobalSearch': showGlobalSearch,
    'quickAddFavoriteDefault': quickAddFavoriteDefault,
    'quickAddPriorityDefault': quickAddPriorityDefault,
    'quickAddOpenDetails': quickAddOpenDetails,
    'quickAddKeepAddingDefault': quickAddKeepAddingDefault,
    'quickAddAutoNormalize': quickAddAutoNormalize,
    'quickAddRememberTags': quickAddRememberTags,
    'quickAddDraftDelayMs': quickAddDraftDelayMs,
    'showShortcutHints': showShortcutHints,
    'focusStudyMode': focusStudyMode,
    'leftHandedControls': leftHandedControls,
    'showStudyTimer': showStudyTimer,
    'showQuestionCounter': showQuestionCounter,
    'perSubjectAccentEnabled': perSubjectAccentEnabled,
    'accentPaletteBySubject': {
      for (final subjectId in (accentPaletteBySubject.keys.toList()..sort()))
        subjectId: accentPaletteBySubject[subjectId]!.name,
    },
    'reduceMotion': reduceMotion,
    'hapticsEnabled': hapticsEnabled,
    'soundEffectsEnabled': soundEffectsEnabled,
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };

  factory AppExperiencePreferences.fromJson(Map<String, Object?> json) {
    final legacyReduceMotion = _boolOr(json['reduceMotion'], false);
    final motionLevel = json.containsKey('motionLevel')
        ? _enumByName(
            AppMotionLevel.values,
            json['motionLevel'],
            AppMotionLevel.full,
          )
        : legacyReduceMotion
        ? AppMotionLevel.off
        : AppMotionLevel.full;
    final themeProfiles = _parseThemeProfiles(json['themeProfiles']);
    final requestedActiveProfileId = _safeProfileId(
      json['activeThemeProfileId'],
    );
    final activeThemeProfileId =
        requestedActiveProfileId != null &&
            themeProfiles.any(
              (profile) => profile.id == requestedActiveProfileId,
            )
        ? requestedActiveProfileId
        : null;
    return AppExperiencePreferences(
      colorMode: _enumByName(
        AppColorMode.values,
        json['colorMode'],
        AppColorMode.system,
      ),
      accentPalette: _enumByName(
        AppAccentPalette.values,
        json['accentPalette'],
        AppAccentPalette.sprache,
      ),
      separateBrightnessAccents: _boolOr(
        json['separateBrightnessAccents'],
        false,
      ),
      lightAccentPalette: _enumByName(
        AppAccentPalette.values,
        json['lightAccentPalette'],
        AppAccentPalette.sprache,
      ),
      darkAccentPalette: _enumByName(
        AppAccentPalette.values,
        json['darkAccentPalette'],
        AppAccentPalette.sprache,
      ),
      themeScheduleMode: _enumByName(
        AppThemeScheduleMode.values,
        json['themeScheduleMode'],
        AppThemeScheduleMode.off,
      ),
      themeDarkStartHour: _intInRange(
        json['themeDarkStartHour'],
        fallback: 19,
        minimum: 0,
        maximum: 23,
      ),
      themeLightStartHour: _intInRange(
        json['themeLightStartHour'],
        fallback: 7,
        minimum: 0,
        maximum: 23,
      ),
      scheduledDarkUsesOled: _boolOr(json['scheduledDarkUsesOled'], false),
      customAccentEnabled: _boolOr(json['customAccentEnabled'], false),
      customAccentRgb: _intInRange(
        json['customAccentRgb'],
        fallback: 0x3D8F40,
        minimum: 0,
        maximum: 0xFFFFFF,
      ),
      themeProfiles: themeProfiles,
      activeThemeProfileId: activeThemeProfileId,
      density: _enumByName(
        AppDensity.values,
        json['density'],
        AppDensity.platform,
      ),
      textScale: _enumByName(
        AppTextScale.values,
        json['textScale'],
        AppTextScale.system,
      ),
      surfaceTone: _enumByName(
        AppSurfaceTone.values,
        json['surfaceTone'],
        AppSurfaceTone.neutral,
      ),
      cornerStyle: _enumByName(
        AppCornerStyle.values,
        json['cornerStyle'],
        AppCornerStyle.balanced,
      ),
      cardStyle: _enumByName(
        AppCardStyle.values,
        json['cardStyle'],
        AppCardStyle.outlined,
      ),
      contentWidth: _enumByName(
        AppContentWidth.values,
        json['contentWidth'],
        AppContentWidth.balanced,
      ),
      fontEmphasis: _enumByName(
        AppFontEmphasis.values,
        json['fontEmphasis'],
        AppFontEmphasis.standard,
      ),
      fontFamily: _enumByName(
        AppFontFamily.values,
        json['fontFamily'],
        AppFontFamily.notoSans,
      ),
      studyTextScale: _enumByName(
        AppStudyTextScale.values,
        json['studyTextScale'],
        AppStudyTextScale.sameAsApp,
      ),
      cardAlignment: _enumByName(
        AppCardAlignment.values,
        json['cardAlignment'],
        AppCardAlignment.adaptive,
      ),
      navigationIconStyle: _enumByName(
        AppNavigationIconStyle.values,
        json['navigationIconStyle'],
        AppNavigationIconStyle.adaptive,
      ),
      decorationIntensity: _enumByName(
        AppDecorationIntensity.values,
        json['decorationIntensity'],
        AppDecorationIntensity.balanced,
      ),
      motionLevel: motionLevel,
      celebrationLevel: _enumByName(
        AppCelebrationLevel.values,
        json['celebrationLevel'],
        AppCelebrationLevel.full,
      ),
      homeLayout: _enumByName(
        AppHomeLayout.values,
        json['homeLayout'],
        AppHomeLayout.balanced,
      ),
      navigationLabelMode: _enumByName(
        AppNavigationLabelMode.values,
        json['navigationLabelMode'],
        AppNavigationLabelMode.always,
      ),
      subjectSwitcherStyle: _enumByName(
        AppSubjectSwitcherStyle.values,
        json['subjectSwitcherStyle'],
        AppSubjectSwitcherStyle.full,
      ),
      quickAddKind: _enumByName(
        AppQuickAddKind.values,
        json['quickAddKind'],
        AppQuickAddKind.word,
      ),
      duplicateDefault: _enumByName(
        AppDuplicateDefault.values,
        json['duplicateDefault'],
        AppDuplicateDefault.ask,
      ),
      feedbackDetail: _enumByName(
        AppFeedbackDetail.values,
        json['feedbackDetail'],
        AppFeedbackDetail.balanced,
      ),
      progressStyle: _enumByName(
        AppProgressStyle.values,
        json['progressStyle'],
        AppProgressStyle.bar,
      ),
      encouragementTone: _enumByName(
        AppEncouragementTone.values,
        json['encouragementTone'],
        AppEncouragementTone.calm,
      ),
      readingLineHeight: _enumByName(
        AppReadingLineHeight.values,
        json['readingLineHeight'],
        AppReadingLineHeight.comfortable,
      ),
      readingWidth: _enumByName(
        AppReadingWidth.values,
        json['readingWidth'],
        AppReadingWidth.balanced,
      ),
      highContrast: _boolOr(json['highContrast'], false),
      showFocusRing: _boolOr(json['showFocusRing'], true),
      simpleHome: _boolOr(json['simpleHome'], true),
      showHomeHeader: _boolOr(json['showHomeHeader'], true),
      showStreak: _boolOr(json['showStreak'], true),
      showXp: _boolOr(json['showXp'], true),
      showSyncStatus: _boolOr(json['showSyncStatus'], true),
      showTodayPlan: _boolOr(json['showTodayPlan'], true),
      showPinnedCollections: _boolOr(json['showPinnedCollections'], true),
      showRecentAdditions: _boolOr(json['showRecentAdditions'], true),
      showDataFlow: _boolOr(json['showDataFlow'], true),
      showSchedules: _boolOr(json['showSchedules'], true),
      homeSectionOrder: _parseHomeSectionOrder(json['homeSectionOrder']),
      showQuickAdd: _boolOr(json['showQuickAdd'], true),
      showGlobalSearch: _boolOr(json['showGlobalSearch'], true),
      quickAddFavoriteDefault: _boolOr(json['quickAddFavoriteDefault'], false),
      quickAddPriorityDefault: _intInRange(
        json['quickAddPriorityDefault'],
        fallback: 0,
        minimum: 0,
        maximum: 5,
      ),
      quickAddOpenDetails: _boolOr(json['quickAddOpenDetails'], false),
      quickAddKeepAddingDefault: _boolOr(
        json['quickAddKeepAddingDefault'],
        false,
      ),
      quickAddAutoNormalize: _boolOr(json['quickAddAutoNormalize'], false),
      quickAddRememberTags: _boolOr(json['quickAddRememberTags'], false),
      quickAddDraftDelayMs: _intInRange(
        json['quickAddDraftDelayMs'],
        fallback: 450,
        minimum: 200,
        maximum: 2000,
      ),
      showShortcutHints: _boolOr(json['showShortcutHints'], true),
      focusStudyMode: _boolOr(json['focusStudyMode'], false),
      leftHandedControls: _boolOr(json['leftHandedControls'], false),
      showStudyTimer: _boolOr(json['showStudyTimer'], true),
      showQuestionCounter: _boolOr(json['showQuestionCounter'], true),
      perSubjectAccentEnabled: _boolOr(json['perSubjectAccentEnabled'], false),
      accentPaletteBySubject: _parseAccentPaletteBySubject(
        json['accentPaletteBySubject'],
      ),
      reduceMotion: motionLevel == AppMotionLevel.off,
      hapticsEnabled: _boolOr(json['hapticsEnabled'], false),
      soundEffectsEnabled: _boolOr(json['soundEffectsEnabled'], false),
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
  final value = raw.toInt();
  if (value < minimum) return minimum;
  if (value > maximum) return maximum;
  return value;
}

List<AppHomeSection> _parseHomeSectionOrder(Object? raw) {
  final result = <AppHomeSection>[];
  final seen = <AppHomeSection>{};
  if (raw is List) {
    for (final value in raw.take(100)) {
      final section = _enumByNameOrNull(AppHomeSection.values, value);
      if (section != null && seen.add(section)) result.add(section);
    }
  }
  for (final section in AppHomeSection.values) {
    if (seen.add(section)) result.add(section);
  }
  return List.unmodifiable(result);
}

Map<String, AppAccentPalette> _parseAccentPaletteBySubject(Object? raw) {
  if (raw is! Map) return const {};
  final result = <String, AppAccentPalette>{};
  for (final entry in raw.entries) {
    final rawSubjectId = entry.key;
    if (rawSubjectId is! String) continue;
    final subjectId = rawSubjectId.trim();
    if (subjectId.isEmpty || subjectId.runes.length > 160) continue;
    final palette = _enumByNameOrNull(AppAccentPalette.values, entry.value);
    if (palette == null) continue;
    result[subjectId] = palette;
    if (result.length >= 100) break;
  }
  return Map.unmodifiable(result);
}

List<AppThemeProfile> _parseThemeProfiles(Object? raw) {
  if (raw is! List) return const [];
  final result = <AppThemeProfile>[];
  final ids = <String>{};
  for (final value in raw.take(25)) {
    final profile = AppThemeProfile.tryFromJson(value);
    if (profile == null || !ids.add(profile.id)) continue;
    result.add(profile);
    if (result.length >= 5) break;
  }
  return List.unmodifiable(result);
}

String? _safeProfileId(Object? raw) {
  if (raw is! String) return null;
  final value = raw.trim();
  if (value.isEmpty || value.runes.length > 64) return null;
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) return null;
  return value;
}

String? _safeProfileName(Object? raw) {
  if (raw is! String) return null;
  final value = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (value.isEmpty || value.runes.length > 40) return null;
  return value;
}

T? _strictEnum<T extends Enum>(Iterable<T> values, Object? raw) {
  if (raw is! String) return null;
  return _enumByNameOrNull(values, raw);
}

int? _strictHour(Object? raw) {
  if (raw is! num || !raw.isFinite || raw != raw.roundToDouble()) return null;
  final value = raw.toInt();
  return value >= 0 && value <= 23 ? value : null;
}

int? _strictRgb(Object? raw) {
  if (raw is! num || !raw.isFinite || raw != raw.roundToDouble()) return null;
  final value = raw.toInt();
  return value >= 0 && value <= 0xFFFFFF ? value : null;
}

T _enumByName<T extends Enum>(Iterable<T> values, Object? raw, T fallback) =>
    _enumByNameOrNull(values, raw) ?? fallback;

T? _enumByNameOrNull<T extends Enum>(Iterable<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}
