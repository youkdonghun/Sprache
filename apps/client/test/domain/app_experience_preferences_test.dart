import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';

void main() {
  test('legacy-compatible defaults remain stable', () {
    const preferences = AppExperiencePreferences();

    expect(preferences.colorMode, AppColorMode.system);
    expect(preferences.accentPalette, AppAccentPalette.sprache);
    expect(preferences.density, AppDensity.platform);
    expect(preferences.textScale, AppTextScale.system);
    expect(preferences.surfaceTone, AppSurfaceTone.neutral);
    expect(preferences.cornerStyle, AppCornerStyle.balanced);
    expect(preferences.cardStyle, AppCardStyle.outlined);
    expect(preferences.contentWidth, AppContentWidth.balanced);
    expect(preferences.fontEmphasis, AppFontEmphasis.standard);
    expect(preferences.motionLevel, AppMotionLevel.full);
    expect(preferences.celebrationLevel, AppCelebrationLevel.full);
    expect(preferences.homeLayout, AppHomeLayout.balanced);
    expect(preferences.navigationLabelMode, AppNavigationLabelMode.always);
    expect(preferences.subjectSwitcherStyle, AppSubjectSwitcherStyle.full);
    expect(preferences.quickAddKind, AppQuickAddKind.word);
    expect(preferences.duplicateDefault, AppDuplicateDefault.ask);
    expect(preferences.feedbackDetail, AppFeedbackDetail.balanced);
    expect(preferences.progressStyle, AppProgressStyle.bar);
    expect(preferences.encouragementTone, AppEncouragementTone.calm);
    expect(preferences.readingLineHeight, AppReadingLineHeight.comfortable);
    expect(preferences.readingWidth, AppReadingWidth.balanced);
    expect(preferences.highContrast, isFalse);
    expect(preferences.showFocusRing, isTrue);
    expect(preferences.showHomeHeader, isTrue);
    expect(preferences.showStreak, isTrue);
    expect(preferences.showXp, isTrue);
    expect(preferences.showSyncStatus, isTrue);
    expect(preferences.showTodayPlan, isTrue);
    expect(preferences.showPinnedCollections, isTrue);
    expect(preferences.showRecentAdditions, isTrue);
    expect(preferences.showDataFlow, isTrue);
    expect(preferences.showSchedules, isTrue);
    expect(preferences.homeSectionOrder, AppHomeSection.values);
    expect(preferences.showQuickAdd, isTrue);
    expect(preferences.showGlobalSearch, isTrue);
    expect(preferences.quickAddFavoriteDefault, isFalse);
    expect(preferences.quickAddPriorityDefault, 0);
    expect(preferences.quickAddOpenDetails, isFalse);
    expect(preferences.quickAddKeepAddingDefault, isFalse);
    expect(preferences.quickAddAutoNormalize, isFalse);
    expect(preferences.quickAddRememberTags, isFalse);
    expect(preferences.quickAddDraftDelayMs, 450);
    expect(preferences.showShortcutHints, isTrue);
    expect(preferences.focusStudyMode, isFalse);
    expect(preferences.leftHandedControls, isFalse);
    expect(preferences.showStudyTimer, isTrue);
    expect(preferences.showQuestionCounter, isTrue);
    expect(preferences.perSubjectAccentEnabled, isFalse);
    expect(preferences.accentPaletteBySubject, isEmpty);
    expect(preferences.reduceMotion, isFalse);
    expect(preferences.hapticsEnabled, isFalse);
    expect(preferences.soundEffectsEnabled, isFalse);
    expect(preferences.effectiveReduceMotion, isFalse);
  });

  test('all experience preferences survive a JSON round trip', () {
    final preferences = AppExperiencePreferences(
      colorMode: AppColorMode.oled,
      accentPalette: AppAccentPalette.rose,
      density: AppDensity.compact,
      textScale: AppTextScale.extraLarge,
      surfaceTone: AppSurfaceTone.cool,
      cornerStyle: AppCornerStyle.square,
      cardStyle: AppCardStyle.elevated,
      contentWidth: AppContentWidth.wide,
      fontEmphasis: AppFontEmphasis.strong,
      motionLevel: AppMotionLevel.off,
      celebrationLevel: AppCelebrationLevel.subtle,
      homeLayout: AppHomeLayout.insights,
      navigationLabelMode: AppNavigationLabelMode.iconsOnly,
      subjectSwitcherStyle: AppSubjectSwitcherStyle.compact,
      quickAddKind: AppQuickAddKind.lastUsed,
      duplicateDefault: AppDuplicateDefault.separate,
      feedbackDetail: AppFeedbackDetail.coach,
      progressStyle: AppProgressStyle.minimal,
      encouragementTone: AppEncouragementTone.playful,
      readingLineHeight: AppReadingLineHeight.relaxed,
      readingWidth: AppReadingWidth.wide,
      highContrast: true,
      showFocusRing: false,
      showHomeHeader: false,
      showStreak: false,
      showXp: false,
      showSyncStatus: false,
      showTodayPlan: false,
      showPinnedCollections: false,
      showRecentAdditions: false,
      showDataFlow: false,
      showSchedules: false,
      homeSectionOrder: const [
        AppHomeSection.schedules,
        AppHomeSection.dataFlow,
        AppHomeSection.recentAdditions,
        AppHomeSection.pinnedCollections,
      ],
      showQuickAdd: false,
      showGlobalSearch: false,
      quickAddFavoriteDefault: true,
      quickAddPriorityDefault: 5,
      quickAddOpenDetails: true,
      quickAddKeepAddingDefault: true,
      quickAddAutoNormalize: true,
      quickAddRememberTags: true,
      quickAddDraftDelayMs: 1750,
      showShortcutHints: false,
      focusStudyMode: true,
      leftHandedControls: true,
      showStudyTimer: false,
      showQuestionCounter: false,
      perSubjectAccentEnabled: true,
      accentPaletteBySubject: const {
        'language:en': AppAccentPalette.sunrise,
        'language:ja': AppAccentPalette.mono,
      },
      reduceMotion: true,
      hapticsEnabled: true,
      soundEffectsEnabled: true,
      updatedAt: DateTime.utc(2026, 8, 2, 9, 30),
    );

    final json = preferences.toJson();
    final restored = AppExperiencePreferences.fromJson(json);

    expect(json['colorMode'], 'oled');
    expect(json['accentPalette'], 'rose');
    expect(restored.toJson(), json);
    expect(restored.effectiveReduceMotion, isTrue);
  });

  test('copyWith exposes and updates every preference', () {
    final updatedAt = DateTime.utc(2026, 8, 2, 12);
    final changed = const AppExperiencePreferences().copyWith(
      colorMode: AppColorMode.oled,
      accentPalette: AppAccentPalette.mint,
      density: AppDensity.comfortable,
      textScale: AppTextScale.medium,
      surfaceTone: AppSurfaceTone.warm,
      cornerStyle: AppCornerStyle.balanced,
      cardStyle: AppCardStyle.outlined,
      contentWidth: AppContentWidth.balanced,
      fontEmphasis: AppFontEmphasis.strong,
      motionLevel: AppMotionLevel.reduced,
      celebrationLevel: AppCelebrationLevel.off,
      homeLayout: AppHomeLayout.balanced,
      navigationLabelMode: AppNavigationLabelMode.selected,
      subjectSwitcherStyle: AppSubjectSwitcherStyle.compact,
      quickAddKind: AppQuickAddKind.sentence,
      duplicateDefault: AppDuplicateDefault.merge,
      feedbackDetail: AppFeedbackDetail.balanced,
      progressStyle: AppProgressStyle.steps,
      encouragementTone: AppEncouragementTone.minimal,
      readingLineHeight: AppReadingLineHeight.comfortable,
      readingWidth: AppReadingWidth.balanced,
      highContrast: true,
      showFocusRing: false,
      showHomeHeader: false,
      showStreak: false,
      showXp: false,
      showSyncStatus: false,
      showTodayPlan: false,
      showPinnedCollections: false,
      showRecentAdditions: false,
      showDataFlow: false,
      showSchedules: false,
      homeSectionOrder: const [
        AppHomeSection.dataFlow,
        AppHomeSection.schedules,
      ],
      showQuickAdd: false,
      showGlobalSearch: false,
      quickAddFavoriteDefault: true,
      quickAddPriorityDefault: 4,
      quickAddOpenDetails: true,
      quickAddKeepAddingDefault: true,
      quickAddAutoNormalize: true,
      quickAddRememberTags: true,
      quickAddDraftDelayMs: 800,
      showShortcutHints: false,
      focusStudyMode: true,
      leftHandedControls: true,
      showStudyTimer: false,
      showQuestionCounter: false,
      perSubjectAccentEnabled: true,
      accentPaletteBySubject: const {'language:de': AppAccentPalette.sunrise},
      reduceMotion: true,
      hapticsEnabled: true,
      soundEffectsEnabled: true,
      updatedAt: updatedAt,
    );

    expect(changed.colorMode, AppColorMode.oled);
    expect(changed.accentPalette, AppAccentPalette.mint);
    expect(changed.surfaceTone, AppSurfaceTone.warm);
    expect(changed.cornerStyle, AppCornerStyle.balanced);
    expect(changed.cardStyle, AppCardStyle.outlined);
    expect(changed.contentWidth, AppContentWidth.balanced);
    expect(changed.fontEmphasis, AppFontEmphasis.strong);
    expect(changed.motionLevel, AppMotionLevel.reduced);
    expect(changed.celebrationLevel, AppCelebrationLevel.off);
    expect(changed.homeLayout, AppHomeLayout.balanced);
    expect(changed.navigationLabelMode, AppNavigationLabelMode.selected);
    expect(changed.subjectSwitcherStyle, AppSubjectSwitcherStyle.compact);
    expect(changed.quickAddKind, AppQuickAddKind.sentence);
    expect(changed.duplicateDefault, AppDuplicateDefault.merge);
    expect(changed.feedbackDetail, AppFeedbackDetail.balanced);
    expect(changed.progressStyle, AppProgressStyle.steps);
    expect(changed.encouragementTone, AppEncouragementTone.minimal);
    expect(changed.readingLineHeight, AppReadingLineHeight.comfortable);
    expect(changed.readingWidth, AppReadingWidth.balanced);
    expect(changed.highContrast, isTrue);
    expect(changed.showFocusRing, isFalse);
    expect(changed.showHomeHeader, isFalse);
    expect(changed.showStreak, isFalse);
    expect(changed.showXp, isFalse);
    expect(changed.showSyncStatus, isFalse);
    expect(changed.showTodayPlan, isFalse);
    expect(changed.showPinnedCollections, isFalse);
    expect(changed.showRecentAdditions, isFalse);
    expect(changed.showDataFlow, isFalse);
    expect(changed.showSchedules, isFalse);
    expect(changed.homeSectionOrder, const [
      AppHomeSection.dataFlow,
      AppHomeSection.schedules,
    ]);
    expect(changed.showQuickAdd, isFalse);
    expect(changed.showGlobalSearch, isFalse);
    expect(changed.quickAddFavoriteDefault, isTrue);
    expect(changed.quickAddPriorityDefault, 4);
    expect(changed.quickAddOpenDetails, isTrue);
    expect(changed.quickAddKeepAddingDefault, isTrue);
    expect(changed.quickAddAutoNormalize, isTrue);
    expect(changed.quickAddRememberTags, isTrue);
    expect(changed.quickAddDraftDelayMs, 800);
    expect(changed.showShortcutHints, isFalse);
    expect(changed.focusStudyMode, isTrue);
    expect(changed.leftHandedControls, isTrue);
    expect(changed.showStudyTimer, isFalse);
    expect(changed.showQuestionCounter, isFalse);
    expect(changed.perSubjectAccentEnabled, isTrue);
    expect(changed.accentPaletteBySubject, {
      'language:de': AppAccentPalette.sunrise,
    });
    expect(changed.reduceMotion, isTrue);
    expect(changed.hapticsEnabled, isTrue);
    expect(changed.soundEffectsEnabled, isTrue);
    expect(changed.updatedAt, updatedAt);
    expect(changed.copyWith(updatedAt: null).updatedAt, isNull);
  });

  test('legacy and malformed values fall back without throwing', () {
    final legacy = AppExperiencePreferences.fromJson({
      'colorMode': 'dark',
      'accentPalette': 'violet',
      'density': 'compact',
      'textScale': 'large',
      'reduceMotion': true,
    });
    final malformed = AppExperiencePreferences.fromJson({
      'colorMode': 'midnight',
      'accentPalette': 12,
      'density': 'tiny',
      'textScale': 'huge',
      'surfaceTone': 'hot',
      'cornerStyle': 'circle',
      'cardStyle': 'glass',
      'contentWidth': 'infinite',
      'fontEmphasis': 'heavy',
      'motionLevel': 'sometimes',
      'celebrationLevel': 'confetti',
      'homeLayout': 'dense',
      'navigationLabelMode': 'hover',
      'subjectSwitcherStyle': 'hidden',
      'quickAddKind': 'auto',
      'duplicateDefault': 'replace',
      'feedbackDetail': 'verbose',
      'progressStyle': 'ring',
      'encouragementTone': 'loud',
      'readingLineHeight': 'huge',
      'readingWidth': 'edgeToEdge',
      'highContrast': 'yes',
      'showFocusRing': 0,
      'showHomeHeader': null,
      'showStreak': 'no',
      'showXp': 1,
      'showSyncStatus': const [],
      'showTodayPlan': const {},
      'showPinnedCollections': 'true',
      'showRecentAdditions': 1,
      'showDataFlow': 1,
      'showSchedules': 1,
      'homeSectionOrder': [
        'schedules',
        'schedules',
        42,
        'recentAdditions',
        'unknown',
      ],
      'showQuickAdd': 'true',
      'showGlobalSearch': 1,
      'quickAddFavoriteDefault': 'yes',
      'quickAddPriorityDefault': -20,
      'quickAddOpenDetails': 1,
      'quickAddKeepAddingDefault': 1,
      'quickAddAutoNormalize': 1,
      'quickAddRememberTags': 1,
      'quickAddDraftDelayMs': 99999,
      'showShortcutHints': 'yes',
      'focusStudyMode': 1,
      'leftHandedControls': 1,
      'showStudyTimer': 1,
      'showQuestionCounter': 1,
      'perSubjectAccentEnabled': 1,
      'accentPaletteBySubject': {
        ' language:en ': 'mint',
        'language:ja': 'invalid',
        7: 'rose',
        '': 'ocean',
        'language:de': 3,
      },
      'reduceMotion': 'yes',
      'hapticsEnabled': 1,
      'soundEffectsEnabled': null,
      'updatedAt': 'not-a-date',
    });

    expect(legacy.colorMode, AppColorMode.dark);
    expect(legacy.accentPalette, AppAccentPalette.violet);
    expect(legacy.density, AppDensity.compact);
    expect(legacy.textScale, AppTextScale.large);
    expect(legacy.motionLevel, AppMotionLevel.off);
    expect(legacy.effectiveReduceMotion, isTrue);

    expect(malformed.colorMode, AppColorMode.system);
    expect(malformed.accentPalette, AppAccentPalette.sprache);
    expect(malformed.density, AppDensity.platform);
    expect(malformed.textScale, AppTextScale.system);
    expect(malformed.surfaceTone, AppSurfaceTone.neutral);
    expect(malformed.cornerStyle, AppCornerStyle.balanced);
    expect(malformed.cardStyle, AppCardStyle.outlined);
    expect(malformed.contentWidth, AppContentWidth.balanced);
    expect(malformed.fontEmphasis, AppFontEmphasis.standard);
    expect(malformed.motionLevel, AppMotionLevel.full);
    expect(malformed.celebrationLevel, AppCelebrationLevel.full);
    expect(malformed.homeLayout, AppHomeLayout.balanced);
    expect(malformed.navigationLabelMode, AppNavigationLabelMode.always);
    expect(malformed.subjectSwitcherStyle, AppSubjectSwitcherStyle.full);
    expect(malformed.quickAddKind, AppQuickAddKind.word);
    expect(malformed.duplicateDefault, AppDuplicateDefault.ask);
    expect(malformed.feedbackDetail, AppFeedbackDetail.balanced);
    expect(malformed.progressStyle, AppProgressStyle.bar);
    expect(malformed.encouragementTone, AppEncouragementTone.calm);
    expect(malformed.readingLineHeight, AppReadingLineHeight.comfortable);
    expect(malformed.readingWidth, AppReadingWidth.balanced);
    expect(malformed.highContrast, isFalse);
    expect(malformed.showFocusRing, isTrue);
    expect(malformed.showHomeHeader, isTrue);
    expect(malformed.showStreak, isTrue);
    expect(malformed.showXp, isTrue);
    expect(malformed.showSyncStatus, isTrue);
    expect(malformed.showTodayPlan, isTrue);
    expect(malformed.showPinnedCollections, isTrue);
    expect(malformed.showRecentAdditions, isTrue);
    expect(malformed.showDataFlow, isTrue);
    expect(malformed.showSchedules, isTrue);
    expect(malformed.homeSectionOrder, const [
      AppHomeSection.schedules,
      AppHomeSection.recentAdditions,
      AppHomeSection.pinnedCollections,
      AppHomeSection.dataFlow,
    ]);
    expect(malformed.showQuickAdd, isTrue);
    expect(malformed.showGlobalSearch, isTrue);
    expect(malformed.quickAddFavoriteDefault, isFalse);
    expect(malformed.quickAddPriorityDefault, 0);
    expect(malformed.quickAddOpenDetails, isFalse);
    expect(malformed.quickAddKeepAddingDefault, isFalse);
    expect(malformed.quickAddAutoNormalize, isFalse);
    expect(malformed.quickAddRememberTags, isFalse);
    expect(malformed.quickAddDraftDelayMs, 2000);
    expect(malformed.showShortcutHints, isTrue);
    expect(malformed.focusStudyMode, isFalse);
    expect(malformed.leftHandedControls, isFalse);
    expect(malformed.showStudyTimer, isTrue);
    expect(malformed.showQuestionCounter, isTrue);
    expect(malformed.perSubjectAccentEnabled, isFalse);
    expect(malformed.accentPaletteBySubject, {
      'language:en': AppAccentPalette.mint,
    });
    expect(malformed.reduceMotion, isFalse);
    expect(malformed.hapticsEnabled, isFalse);
    expect(malformed.soundEffectsEnabled, isFalse);
    expect(malformed.updatedAt, isNull);
  });

  test('numeric safety ranges clamp and non-finite values use defaults', () {
    final highPriorityLowDelay = AppExperiencePreferences.fromJson({
      'quickAddPriorityDefault': 99,
      'quickAddDraftDelayMs': -1,
    });
    final nonFinite = AppExperiencePreferences.fromJson({
      'quickAddPriorityDefault': double.nan,
      'quickAddDraftDelayMs': double.infinity,
    });

    expect(highPriorityLowDelay.quickAddPriorityDefault, 5);
    expect(highPriorityLowDelay.quickAddDraftDelayMs, 200);
    expect(nonFinite.quickAddPriorityDefault, 0);
    expect(nonFinite.quickAddDraftDelayMs, 450);
  });

  test('effectiveReduceMotion supports the legacy flag and motion off', () {
    expect(
      const AppExperiencePreferences(
        motionLevel: AppMotionLevel.reduced,
      ).effectiveReduceMotion,
      isFalse,
    );
    expect(
      const AppExperiencePreferences(
        motionLevel: AppMotionLevel.off,
      ).effectiveReduceMotion,
      isTrue,
    );
    expect(
      const AppExperiencePreferences(reduceMotion: true).effectiveReduceMotion,
      isTrue,
    );
  });
}
