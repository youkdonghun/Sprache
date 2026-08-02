import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_experience_preferences.dart';
import '../domain/personalization_presets.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class PersonalizationScreen extends ConsumerWidget {
  const PersonalizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final preferences = state.preferences.experience;
    final subject = controller.activeSubject;

    return Scaffold(
      appBar: AppBar(
        title: const Text('개인화 스튜디오'),
        actions: [
          IconButton(
            key: const Key('copy-personalization-json'),
            tooltip: '개인화 설정 복사',
            onPressed: () => _copyPreferences(context, preferences),
            icon: const Icon(Icons.copy_all_outlined),
          ),
          IconButton(
            key: const Key('paste-personalization-json'),
            tooltip: '개인화 설정 붙여넣기',
            onPressed: () => _pastePreferences(context, controller),
            icon: const Icon(Icons.content_paste_go_outlined),
          ),
        ],
      ),
      body: PersonalizationPanel(
        preferences: preferences,
        subjectId: subject.id,
        subjectName: subject.name,
        onChanged: controller.updateExperiencePreferences,
      ),
    );
  }

  Future<void> _copyPreferences(
    BuildContext context,
    AppExperiencePreferences preferences,
  ) async {
    await Clipboard.setData(
      ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert(preferences.toJson()),
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('개인화 설정 JSON을 클립보드에 복사했습니다.')));
  }

  Future<void> _pastePreferences(
    BuildContext context,
    AppController controller,
  ) async {
    try {
      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      final decoded = jsonDecode(text ?? '');
      if (decoded is! Map) throw const FormatException();
      controller.updateExperiencePreferences(
        AppExperiencePreferences.fromJson(Map<String, Object?>.from(decoded)),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('검증한 개인화 설정을 적용했습니다.')));
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 Sprache 개인화 JSON이 아닙니다.')),
      );
    }
  }
}

class PersonalizationPanel extends StatelessWidget {
  const PersonalizationPanel({
    required this.preferences,
    required this.subjectId,
    required this.subjectName,
    required this.onChanged,
    super.key,
  });

  final AppExperiencePreferences preferences;
  final String subjectId;
  final String subjectName;
  final ValueChanged<AppExperiencePreferences> onChanged;

  AppAccentPalette get _effectivePalette => preferences.perSubjectAccentEnabled
      ? preferences.accentPaletteBySubject[subjectId] ??
            preferences.accentPalette
      : preferences.accentPalette;

  void _setPalette(AppAccentPalette palette) {
    if (!preferences.perSubjectAccentEnabled) {
      onChanged(preferences.copyWith(accentPalette: palette));
      return;
    }
    onChanged(
      preferences.copyWith(
        accentPaletteBySubject: {
          ...preferences.accentPaletteBySubject,
          subjectId: palette,
        },
      ),
    );
  }

  void _applyPreset(PersonalizationPreset preset) {
    final presetPreferences = preset.applyTo(preferences);
    if (!preferences.perSubjectAccentEnabled) {
      onChanged(presetPreferences);
      return;
    }
    onChanged(
      presetPreferences.copyWith(
        accentPalette: preferences.accentPalette,
        accentPaletteBySubject: {
          ...preferences.accentPaletteBySubject,
          subjectId: presetPreferences.accentPalette,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = AppTheme.contentMaxWidth(preferences.contentWidth);
    return ListView(
      key: const Key('personalization-panel'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '내가 편한 방식으로',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '기본값은 그대로 두고, 원하는 부분만 바꿀 수 있습니다. 모든 선택은 먼저 이 기기에 저장됩니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                _LivePreview(preferences: preferences),
                const SizedBox(height: 12),
                _PresetSection(onApply: _applyPreset),
                const SizedBox(height: 10),
                _ThemeProfileManager(
                  preferences: preferences,
                  onChanged: onChanged,
                ),
                const SizedBox(height: 10),
                _PersonalizationSection(
                  sectionKey: const Key('personalization-theme-section'),
                  icon: Icons.palette_outlined,
                  title: '테마·읽기',
                  summary:
                      '${_colorModeLabel(preferences.colorMode)} · '
                      '${_paletteLabel(_effectivePalette)} · '
                      '${_surfaceLabel(preferences.surfaceTone)}',
                  initiallyExpanded: true,
                  children: [
                    _ChoiceGroup<AppColorMode>(
                      label: '화면 모드',
                      value: preferences.colorMode,
                      values: AppColorMode.values,
                      labelFor: _colorModeLabel,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(colorMode: value)),
                    ),
                    if (!preferences.separateBrightnessAccents &&
                        !preferences.customAccentEnabled)
                      _ChoiceGroup<AppAccentPalette>(
                        label: '강조 색상',
                        value: _effectivePalette,
                        values: AppAccentPalette.values,
                        labelFor: _paletteLabel,
                        swatchFor: AppTheme.palettePreview,
                        onChanged: _setPalette,
                      ),
                    _PreferenceSwitch(
                      controlKey: const Key('theme-separate-accents'),
                      title: '라이트·다크 색상 따로 사용',
                      subtitle: '밝은 화면과 어두운 화면에 서로 다른 강조색을 적용합니다.',
                      value: preferences.separateBrightnessAccents,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(
                          separateBrightnessAccents: value,
                          perSubjectAccentEnabled: value
                              ? false
                              : preferences.perSubjectAccentEnabled,
                          customAccentEnabled: value
                              ? false
                              : preferences.customAccentEnabled,
                          lightAccentPalette: value
                              ? _effectivePalette
                              : preferences.lightAccentPalette,
                          darkAccentPalette: value
                              ? _effectivePalette
                              : preferences.darkAccentPalette,
                          activeThemeProfileId: null,
                        ),
                      ),
                    ),
                    if (preferences.separateBrightnessAccents) ...[
                      _ChoiceGroup<AppAccentPalette>(
                        controlKey: const Key('theme-light-accent-group'),
                        label: '라이트 강조색',
                        value: preferences.lightAccentPalette,
                        values: AppAccentPalette.values,
                        labelFor: _paletteLabel,
                        swatchFor: AppTheme.palettePreview,
                        onChanged: (value) => onChanged(
                          preferences.copyWith(
                            lightAccentPalette: value,
                            activeThemeProfileId: null,
                          ),
                        ),
                      ),
                      _ChoiceGroup<AppAccentPalette>(
                        controlKey: const Key('theme-dark-accent-group'),
                        label: '다크 강조색',
                        value: preferences.darkAccentPalette,
                        values: AppAccentPalette.values,
                        labelFor: _paletteLabel,
                        swatchFor: AppTheme.palettePreview,
                        onChanged: (value) => onChanged(
                          preferences.copyWith(
                            darkAccentPalette: value,
                            activeThemeProfileId: null,
                          ),
                        ),
                      ),
                    ],
                    _CustomAccentPreference(
                      enabled: preferences.customAccentEnabled,
                      rgb: preferences.customAccentRgb,
                      onEnabledChanged: (value) => onChanged(
                        preferences.copyWith(
                          customAccentEnabled: value,
                          separateBrightnessAccents: value
                              ? false
                              : preferences.separateBrightnessAccents,
                          perSubjectAccentEnabled: value
                              ? false
                              : preferences.perSubjectAccentEnabled,
                          activeThemeProfileId: null,
                        ),
                      ),
                      onRgbChanged: (value) => onChanged(
                        preferences.copyWith(
                          customAccentRgb: value,
                          activeThemeProfileId: null,
                        ),
                      ),
                    ),
                    _ChoiceGroup<AppThemeScheduleMode>(
                      controlKey: const Key('theme-schedule-group'),
                      label: '시간대 자동 테마',
                      value: preferences.themeScheduleMode,
                      values: AppThemeScheduleMode.values,
                      labelFor: _themeScheduleLabel,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(
                          themeScheduleMode: value,
                          activeThemeProfileId: null,
                        ),
                      ),
                    ),
                    if (preferences.themeScheduleMode !=
                        AppThemeScheduleMode.off) ...[
                      _ThemeSchedulePreview(preferences: preferences),
                      if (preferences.themeScheduleMode ==
                          AppThemeScheduleMode.custom) ...[
                        _SliderPreference(
                          controlKey: const Key('theme-dark-start-hour'),
                          title: '다크 모드 시작',
                          value: preferences.themeDarkStartHour.toDouble(),
                          valueLabel:
                              '${preferences.themeDarkStartHour.toString().padLeft(2, '0')}:00',
                          min: 0,
                          max: 23,
                          divisions: 23,
                          onChanged: (value) => onChanged(
                            preferences.copyWith(
                              themeDarkStartHour: value.round(),
                              activeThemeProfileId: null,
                            ),
                          ),
                        ),
                        _SliderPreference(
                          controlKey: const Key('theme-light-start-hour'),
                          title: '라이트 모드 시작',
                          value: preferences.themeLightStartHour.toDouble(),
                          valueLabel:
                              '${preferences.themeLightStartHour.toString().padLeft(2, '0')}:00',
                          min: 0,
                          max: 23,
                          divisions: 23,
                          onChanged: (value) => onChanged(
                            preferences.copyWith(
                              themeLightStartHour: value.round(),
                              activeThemeProfileId: null,
                            ),
                          ),
                        ),
                      ],
                      _PreferenceSwitch(
                        controlKey: const Key('theme-schedule-oled'),
                        title: '예약된 다크 모드에서 OLED 사용',
                        value: preferences.scheduledDarkUsesOled,
                        onChanged: (value) => onChanged(
                          preferences.copyWith(
                            scheduledDarkUsesOled: value,
                            activeThemeProfileId: null,
                          ),
                        ),
                      ),
                    ],
                    _PreferenceSwitch(
                      controlKey: const Key('theme-per-subject'),
                      title: '주제별 색상 기억',
                      subtitle: '$subjectName에서 고른 색상을 따로 기억합니다.',
                      value: preferences.perSubjectAccentEnabled,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(
                          perSubjectAccentEnabled: value,
                          separateBrightnessAccents: value
                              ? false
                              : preferences.separateBrightnessAccents,
                          customAccentEnabled: value
                              ? false
                              : preferences.customAccentEnabled,
                          accentPaletteBySubject: value
                              ? {
                                  ...preferences.accentPaletteBySubject,
                                  subjectId: _effectivePalette,
                                }
                              : preferences.accentPaletteBySubject,
                          activeThemeProfileId: null,
                        ),
                      ),
                    ),
                    _ChoiceGroup<AppSurfaceTone>(
                      label: '표면 색감',
                      value: preferences.surfaceTone,
                      values: AppSurfaceTone.values,
                      labelFor: _surfaceLabel,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(surfaceTone: value)),
                    ),
                    _ChoiceGroup<AppCornerStyle>(
                      label: '모서리',
                      value: preferences.cornerStyle,
                      values: AppCornerStyle.values,
                      labelFor: _cornerLabel,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(cornerStyle: value)),
                    ),
                    _ChoiceGroup<AppCardStyle>(
                      label: '카드 강조',
                      value: preferences.cardStyle,
                      values: AppCardStyle.values,
                      labelFor: _cardLabel,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(cardStyle: value)),
                    ),
                    _ChoiceGroup<AppFontEmphasis>(
                      label: '글자 굵기',
                      value: preferences.fontEmphasis,
                      values: AppFontEmphasis.values,
                      labelFor: _fontLabel,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(fontEmphasis: value)),
                    ),
                    _ChoiceGroup<AppFontFamily>(
                      controlKey: const Key('theme-font-family-group'),
                      label: '글꼴',
                      value: preferences.fontFamily,
                      values: AppFontFamily.values,
                      labelFor: _fontFamilyLabel,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(
                          fontFamily: value,
                          activeThemeProfileId: null,
                        ),
                      ),
                    ),
                    _ChoiceGroup<AppTextScale>(
                      label: '글자 크기',
                      value: preferences.textScale,
                      values: AppTextScale.values,
                      labelFor: _textScaleLabel,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(textScale: value)),
                    ),
                    _ChoiceGroup<AppStudyTextScale>(
                      controlKey: const Key('theme-study-text-scale-group'),
                      label: '학습 화면만 더 크게',
                      value: preferences.studyTextScale,
                      values: AppStudyTextScale.values,
                      labelFor: _studyTextScaleLabel,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(
                          studyTextScale: value,
                          activeThemeProfileId: null,
                        ),
                      ),
                    ),
                    _ChoiceGroup<AppCardAlignment>(
                      controlKey: const Key('theme-card-alignment-group'),
                      label: '학습 카드 정렬',
                      value: preferences.cardAlignment,
                      values: AppCardAlignment.values,
                      labelFor: _cardAlignmentLabel,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(
                          cardAlignment: value,
                          activeThemeProfileId: null,
                        ),
                      ),
                    ),
                    _ChoiceGroup<AppDecorationIntensity>(
                      controlKey: const Key('theme-decoration-group'),
                      label: '장식 강도',
                      value: preferences.decorationIntensity,
                      values: AppDecorationIntensity.values,
                      labelFor: _decorationIntensityLabel,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(
                          decorationIntensity: value,
                          activeThemeProfileId: null,
                        ),
                      ),
                    ),
                    _ChoiceGroup<AppReadingLineHeight>(
                      label: '읽기 행간',
                      value: preferences.readingLineHeight,
                      values: AppReadingLineHeight.values,
                      labelFor: _lineHeightLabel,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(readingLineHeight: value),
                      ),
                    ),
                    _ChoiceGroup<AppReadingWidth>(
                      label: '읽기 문단 폭',
                      value: preferences.readingWidth,
                      values: AppReadingWidth.values,
                      labelFor: _readingWidthLabel,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(readingWidth: value)),
                    ),
                    _ChoiceGroup<AppContentWidth>(
                      label: '데스크톱 본문 폭',
                      value: preferences.contentWidth,
                      values: AppContentWidth.values,
                      labelFor: _contentWidthLabel,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(contentWidth: value)),
                    ),
                    _ChoiceGroup<AppMotionLevel>(
                      label: '화면 전환',
                      value: preferences.motionLevel,
                      values: AppMotionLevel.values,
                      labelFor: _motionLabel,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(
                          motionLevel: value,
                          reduceMotion: value == AppMotionLevel.off,
                        ),
                      ),
                    ),
                    _ChoiceGroup<AppCelebrationLevel>(
                      label: '축하 효과',
                      value: preferences.celebrationLevel,
                      values: AppCelebrationLevel.values,
                      labelFor: _celebrationLabel,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(celebrationLevel: value),
                      ),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('theme-high-contrast'),
                      title: '강제 고대비',
                      value: preferences.highContrast,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(highContrast: value)),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('theme-focus-ring'),
                      title: '키보드 포커스 강조',
                      value: preferences.showFocusRing,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(showFocusRing: value)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _PersonalizationSection(
                  sectionKey: const Key('personalization-home-section'),
                  icon: Icons.space_dashboard_outlined,
                  title: '홈 대시보드',
                  summary:
                      '${_homeLayoutLabel(preferences.homeLayout)} · '
                      '${_visibleHomeSectionCount(preferences)}개 섹션',
                  children: [
                    _ChoiceGroup<AppHomeLayout>(
                      label: '홈 레이아웃',
                      value: preferences.homeLayout,
                      values: AppHomeLayout.values,
                      labelFor: _homeLayoutLabel,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(homeLayout: value)),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('home-show-header'),
                      title: '인사말·주제 헤더',
                      value: preferences.showHomeHeader,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(showHomeHeader: value),
                      ),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('home-show-streak'),
                      title: '연속 학습일',
                      value: preferences.showStreak,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(showStreak: value)),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('home-show-xp'),
                      title: 'XP·레벨',
                      value: preferences.showXp,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(showXp: value)),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('home-show-sync'),
                      title: '저장·동기화 상태',
                      value: preferences.showSyncStatus,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(showSyncStatus: value),
                      ),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('home-show-today-plan'),
                      title: '오늘 계획',
                      value: preferences.showTodayPlan,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(showTodayPlan: value)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '섹션 표시와 순서',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    for (final (index, section)
                        in preferences.homeSectionOrder.indexed)
                      _HomeSectionTile(
                        section: section,
                        visible: _homeSectionVisible(preferences, section),
                        canMoveUp: index > 0,
                        canMoveDown:
                            index < preferences.homeSectionOrder.length - 1,
                        onVisibilityChanged: (value) => onChanged(
                          _withHomeSectionVisibility(
                            preferences,
                            section,
                            value,
                          ),
                        ),
                        onMoveUp: () => onChanged(
                          _moveHomeSection(preferences, index, index - 1),
                        ),
                        onMoveDown: () => onChanged(
                          _moveHomeSection(preferences, index, index + 1),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const Key('reset-home-personalization'),
                        onPressed: () => onChanged(
                          preferences.copyWith(
                            homeLayout: AppHomeLayout.balanced,
                            showHomeHeader: true,
                            showStreak: true,
                            showXp: true,
                            showSyncStatus: true,
                            showTodayPlan: true,
                            showPinnedCollections: true,
                            showRecentAdditions: true,
                            showDataFlow: true,
                            showSchedules: true,
                            homeSectionOrder: defaultAppHomeSectionOrder,
                          ),
                        ),
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('홈 구성 초기화'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _PersonalizationSection(
                  sectionKey: const Key('personalization-navigation-section'),
                  icon: Icons.navigation_outlined,
                  title: '내비게이션',
                  summary: _navigationLabel(preferences.navigationLabelMode),
                  children: [
                    _ChoiceGroup<AppNavigationLabelMode>(
                      label: '탭 라벨',
                      value: preferences.navigationLabelMode,
                      values: AppNavigationLabelMode.values,
                      labelFor: _navigationLabel,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(navigationLabelMode: value),
                      ),
                    ),
                    _ChoiceGroup<AppNavigationIconStyle>(
                      controlKey: const Key('navigation-icon-style-group'),
                      label: '탐색 아이콘 모양',
                      value: preferences.navigationIconStyle,
                      values: AppNavigationIconStyle.values,
                      labelFor: _navigationIconStyleLabel,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(
                          navigationIconStyle: value,
                          activeThemeProfileId: null,
                        ),
                      ),
                    ),
                    _ChoiceGroup<AppSubjectSwitcherStyle>(
                      label: '주제 전환기',
                      value: preferences.subjectSwitcherStyle,
                      values: AppSubjectSwitcherStyle.values,
                      labelFor: _subjectSwitcherLabel,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(subjectSwitcherStyle: value),
                      ),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('navigation-show-quick-add'),
                      title: '빠른 추가 버튼',
                      value: preferences.showQuickAdd,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(showQuickAdd: value)),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('navigation-show-search'),
                      title: '전체 검색 버튼',
                      value: preferences.showGlobalSearch,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(showGlobalSearch: value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _PersonalizationSection(
                  sectionKey: const Key('personalization-quick-add-section'),
                  icon: Icons.playlist_add_rounded,
                  title: '빠른 자료 등록',
                  summary:
                      '${_quickKindLabel(preferences.quickAddKind)} · '
                      '${preferences.quickAddPriorityDefault}순위',
                  children: [
                    _ChoiceGroup<AppQuickAddKind>(
                      label: '기본 자료 종류',
                      value: preferences.quickAddKind,
                      values: AppQuickAddKind.values,
                      labelFor: _quickKindLabel,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(quickAddKind: value)),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('quick-default-details'),
                      title: '상세 필드 먼저 펼치기',
                      value: preferences.quickAddOpenDetails,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(quickAddOpenDetails: value),
                      ),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('quick-default-favorite'),
                      title: '기본 즐겨찾기',
                      value: preferences.quickAddFavoriteDefault,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(quickAddFavoriteDefault: value),
                      ),
                    ),
                    _SliderPreference(
                      controlKey: const Key('quick-default-priority'),
                      title: '기본 학습 우선순위',
                      value: preferences.quickAddPriorityDefault.toDouble(),
                      valueLabel: '${preferences.quickAddPriorityDefault} / 5',
                      min: 0,
                      max: 5,
                      divisions: 5,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(
                          quickAddPriorityDefault: value.round(),
                        ),
                      ),
                    ),
                    _ChoiceGroup<AppDuplicateDefault>(
                      label: '중복 기본 동작',
                      value: preferences.duplicateDefault,
                      values: AppDuplicateDefault.values,
                      labelFor: _duplicateLabel,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(duplicateDefault: value),
                      ),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('quick-auto-normalize'),
                      title: '저장 전 자동 정규화',
                      subtitle: 'Unicode NFKC와 공백 정리를 적용합니다.',
                      value: preferences.quickAddAutoNormalize,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(quickAddAutoNormalize: value),
                      ),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('quick-default-keep-adding'),
                      title: '저장 후 계속 추가를 기본으로',
                      value: preferences.quickAddKeepAddingDefault,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(quickAddKeepAddingDefault: value),
                      ),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('quick-remember-tags'),
                      title: '최근 태그 기억·추천',
                      value: preferences.quickAddRememberTags,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(quickAddRememberTags: value),
                      ),
                    ),
                    _SliderPreference(
                      controlKey: const Key('quick-draft-delay'),
                      title: '초안 자동 저장 간격',
                      value: preferences.quickAddDraftDelayMs.toDouble(),
                      valueLabel:
                          '${_draftDelayLabel(preferences.quickAddDraftDelayMs)} · '
                          '${preferences.quickAddDraftDelayMs / 1000}초',
                      min: 200,
                      max: 2000,
                      divisions: 18,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(
                          quickAddDraftDelayMs: value.round(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _PersonalizationSection(
                  sectionKey: const Key('personalization-study-section'),
                  icon: Icons.school_outlined,
                  title: '학습 집중',
                  summary: preferences.focusStudyMode ? '집중 모드' : '전체 정보',
                  children: [
                    _PreferenceSwitch(
                      controlKey: const Key('study-focus-mode-default'),
                      title: '집중 모드를 기본으로',
                      subtitle: '학습 중 부가 수치와 설명을 줄입니다.',
                      value: preferences.focusStudyMode,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(focusStudyMode: value),
                      ),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('study-left-handed-controls'),
                      title: '왼손잡이 조작 순서',
                      value: preferences.leftHandedControls,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(leftHandedControls: value),
                      ),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('study-shortcut-hints'),
                      title: '키보드 단축키 배지',
                      value: preferences.showShortcutHints,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(showShortcutHints: value),
                      ),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('study-show-timer'),
                      title: '예상 남은 시간',
                      value: preferences.showStudyTimer,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(showStudyTimer: value),
                      ),
                    ),
                    _PreferenceSwitch(
                      controlKey: const Key('study-show-question-count'),
                      title: '문제 번호',
                      value: preferences.showQuestionCounter,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(showQuestionCounter: value),
                      ),
                    ),
                    _ChoiceGroup<AppFeedbackDetail>(
                      label: '정답 피드백',
                      value: preferences.feedbackDetail,
                      values: AppFeedbackDetail.values,
                      labelFor: _feedbackLabel,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(feedbackDetail: value),
                      ),
                    ),
                    _ChoiceGroup<AppProgressStyle>(
                      label: '진도 표시',
                      value: preferences.progressStyle,
                      values: AppProgressStyle.values,
                      labelFor: _progressLabel,
                      onChanged: (value) =>
                          onChanged(preferences.copyWith(progressStyle: value)),
                    ),
                    _ChoiceGroup<AppEncouragementTone>(
                      label: '격려 문구',
                      value: preferences.encouragementTone,
                      values: AppEncouragementTone.values,
                      labelFor: _encouragementLabel,
                      onChanged: (value) => onChanged(
                        preferences.copyWith(encouragementTone: value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.preferences});

  final AppExperiencePreferences preferences;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '실시간 테마 미리보기',
      child: Card(
        key: const Key('personalization-live-preview'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_stories_rounded,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '오늘의 영어',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text('복습 8개 · 새 표현 4개'),
                      ],
                    ),
                  ),
                  if (preferences.showStreak) const Chip(label: Text('🔥 7일')),
                ],
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: 0.62,
                minHeight: preferences.progressStyle == AppProgressStyle.minimal
                    ? 3
                    : 7,
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final tileWidth = constraints.maxWidth >= 460
                      ? (constraints.maxWidth - 8) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: tileWidth,
                        child: _PreviewTile(
                          tileKey: const Key('personalization-card-preview'),
                          eyebrow: '단어 카드',
                          title: 'resilient',
                          subtitle: '회복력 있는 · 리질리언트',
                          icon: Icons.style_outlined,
                          alignment: preferences.cardAlignment,
                        ),
                      ),
                      SizedBox(
                        width: tileWidth,
                        child: _PreviewTile(
                          tileKey: const Key('personalization-quiz-preview'),
                          eyebrow: '퀴즈 선택지',
                          title: '꾸준한',
                          subtitle: '차분한 피드백 미리보기',
                          icon: Icons.quiz_outlined,
                          alignment: preferences.cardAlignment,
                          selected: true,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('이어서 학습'),
                  ),
                  OutlinedButton(onPressed: () {}, child: const Text('직접 선택')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.tileKey,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.alignment,
    this.selected = false,
  });

  final Key tileKey;
  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final AppCardAlignment alignment;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: tileKey,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? colors.secondaryContainer
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? colors.secondary : colors.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: selected ? colors.secondary : colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: alignment == AppCardAlignment.centered
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(eyebrow, style: Theme.of(context).textTheme.labelSmall),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: alignment == AppCardAlignment.centered
                      ? TextAlign.center
                      : TextAlign.start,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: alignment == AppCardAlignment.centered
                      ? TextAlign.center
                      : TextAlign.start,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetSection extends StatelessWidget {
  const _PresetSection({required this.onApply});

  final ValueChanged<PersonalizationPreset> onApply;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('원터치 프리셋', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '홈과 등록 기본값은 유지하고 화면 스타일만 바꿉니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in PersonalizationPreset.values)
                  ActionChip(
                    key: Key('personalization-preset-${preset.name}'),
                    avatar: Icon(_presetIcon(preset), size: 18),
                    label: Text(preset.label),
                    tooltip: preset.description,
                    onPressed: () => onApply(preset),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeProfileManager extends StatefulWidget {
  const _ThemeProfileManager({
    required this.preferences,
    required this.onChanged,
  });

  final AppExperiencePreferences preferences;
  final ValueChanged<AppExperiencePreferences> onChanged;

  @override
  State<_ThemeProfileManager> createState() => _ThemeProfileManagerState();
}

class _ThemeProfileManagerState extends State<_ThemeProfileManager> {
  final _nameController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveNew() {
    final name = _nameController.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) {
      setState(() => _error = '프로필 이름을 입력해 주세요.');
      return;
    }
    if (name.runes.length > 40) {
      setState(() => _error = '프로필 이름은 40자까지 사용할 수 있습니다.');
      return;
    }
    if (widget.preferences.themeProfiles.length >= 5) {
      setState(() => _error = '테마 프로필은 최대 5개까지 저장할 수 있습니다.');
      return;
    }
    final id = 'theme_${DateTime.now().microsecondsSinceEpoch}';
    final profile = AppThemeProfile.capture(
      id: id,
      name: name,
      preferences: widget.preferences,
    );
    widget.onChanged(
      widget.preferences.copyWith(
        themeProfiles: [...widget.preferences.themeProfiles, profile],
        activeThemeProfileId: id,
      ),
    );
    _nameController.clear();
    setState(() => _error = null);
  }

  void _overwriteActive() {
    final activeId = widget.preferences.activeThemeProfileId;
    final index = widget.preferences.themeProfiles.indexWhere(
      (profile) => profile.id == activeId,
    );
    if (index < 0) return;
    final current = widget.preferences.themeProfiles[index];
    final profiles = [...widget.preferences.themeProfiles];
    profiles[index] = AppThemeProfile.capture(
      id: current.id,
      name: current.name,
      preferences: widget.preferences,
    );
    widget.onChanged(widget.preferences.copyWith(themeProfiles: profiles));
  }

  void _delete(AppThemeProfile profile) {
    widget.onChanged(
      widget.preferences.copyWith(
        themeProfiles: [
          for (final candidate in widget.preferences.themeProfiles)
            if (candidate.id != profile.id) candidate,
        ],
        activeThemeProfileId:
            widget.preferences.activeThemeProfileId == profile.id
            ? null
            : widget.preferences.activeThemeProfileId,
      ),
    );
  }

  void _move(AppThemeProfile profile, int delta) {
    final profiles = [...widget.preferences.themeProfiles];
    final from = profiles.indexWhere((candidate) => candidate.id == profile.id);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= profiles.length) return;
    final moved = profiles.removeAt(from);
    profiles.insert(to, moved);
    widget.onChanged(widget.preferences.copyWith(themeProfiles: profiles));
  }

  void _duplicate(AppThemeProfile profile) {
    if (widget.preferences.themeProfiles.length >= 5) {
      setState(() => _error = '테마 프로필은 최대 5개까지 저장할 수 있습니다.');
      return;
    }
    const suffix = ' 복사본';
    final baseRunes = profile.name.runes.toList();
    final maxBaseLength = 40 - suffix.runes.length;
    final duplicateName =
        '${String.fromCharCodes(baseRunes.take(maxBaseLength))}$suffix';
    final duplicate = AppThemeProfile.tryFromJson({
      ...profile.toJson(),
      'id': 'theme_${DateTime.now().microsecondsSinceEpoch}',
      'name': duplicateName,
    })!;
    widget.onChanged(
      widget.preferences.copyWith(
        themeProfiles: [...widget.preferences.themeProfiles, duplicate],
      ),
    );
    setState(() => _error = null);
  }

  Future<void> _rename(AppThemeProfile profile) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) =>
          _RenameThemeProfileDialog(initialName: profile.name),
    );
    if (!mounted || name == null || name == profile.name) return;
    final renamed = AppThemeProfile.tryFromJson({
      ...profile.toJson(),
      'name': name,
    })!;
    widget.onChanged(
      widget.preferences.copyWith(
        themeProfiles: [
          for (final candidate in widget.preferences.themeProfiles)
            if (candidate.id == profile.id) renamed else candidate,
        ],
      ),
    );
  }

  void _handleProfileAction(
    _ThemeProfileAction action,
    AppThemeProfile profile,
  ) {
    switch (action) {
      case _ThemeProfileAction.rename:
        _rename(profile);
        break;
      case _ThemeProfileAction.duplicate:
        _duplicate(profile);
        break;
      case _ThemeProfileAction.delete:
        _delete(profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = widget.preferences.themeProfiles;
    final atLimit = profiles.length >= 5;
    return Card(
      key: const Key('theme-profile-manager'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('내 테마 프로필', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '현재 화면 설정을 최대 5개 저장하고 한 번에 전환할 수 있습니다. 손상된 프로필은 불러올 때 개별 제외됩니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (profiles.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (var index = 0; index < profiles.length; index++)
                ListTile(
                  key: Key('theme-profile-${profiles[index].id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    widget.preferences.activeThemeProfileId ==
                            profiles[index].id
                        ? Icons.check_circle_rounded
                        : Icons.palette_outlined,
                  ),
                  title: Text(profiles[index].name),
                  subtitle: Text(
                    '${_colorModeLabel(profiles[index].colorMode)} · ${_paletteLabel(profiles[index].accentPalette)}',
                  ),
                  onTap: () => widget.onChanged(
                    profiles[index].applyTo(widget.preferences),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('move-up-theme-profile-${profiles[index].id}'),
                        tooltip: '${profiles[index].name} 위로',
                        onPressed: index == 0
                            ? null
                            : () => _move(profiles[index], -1),
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                      IconButton(
                        key: Key(
                          'move-down-theme-profile-${profiles[index].id}',
                        ),
                        tooltip: '${profiles[index].name} 아래로',
                        onPressed: index == profiles.length - 1
                            ? null
                            : () => _move(profiles[index], 1),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                      PopupMenuButton<_ThemeProfileAction>(
                        key: Key('theme-profile-menu-${profiles[index].id}'),
                        tooltip: '${profiles[index].name} 관리',
                        onSelected: (action) =>
                            _handleProfileAction(action, profiles[index]),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: _ThemeProfileAction.rename,
                            child: Text('이름 변경'),
                          ),
                          PopupMenuItem(
                            value: _ThemeProfileAction.duplicate,
                            enabled: !atLimit,
                            child: const Text('복제'),
                          ),
                          const PopupMenuItem(
                            value: _ThemeProfileAction.delete,
                            child: Text('삭제'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            TextField(
              key: const Key('theme-profile-name'),
              controller: _nameController,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: '새 프로필 이름',
                hintText: '예: 야간 집중',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: atLimit ? null : (_) => _saveNew(),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (widget.preferences.activeThemeProfileId != null)
                  OutlinedButton.icon(
                    key: const Key('overwrite-active-theme-profile'),
                    onPressed: _overwriteActive,
                    icon: const Icon(Icons.save_as_outlined),
                    label: const Text('현재 설정으로 덮어쓰기'),
                  ),
                FilledButton.icon(
                  key: const Key('save-theme-profile'),
                  onPressed: atLimit ? null : _saveNew,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(atLimit ? '5개 저장됨' : '현재 테마 저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ThemeProfileAction { rename, duplicate, delete }

class _RenameThemeProfileDialog extends StatefulWidget {
  const _RenameThemeProfileDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameThemeProfileDialog> createState() =>
      _RenameThemeProfileDialogState();
}

class _RenameThemeProfileDialogState extends State<_RenameThemeProfileDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final normalized = _controller.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      setState(() => _error = '이름을 입력해 주세요.');
      return;
    }
    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('테마 프로필 이름 변경'),
    content: TextField(
      key: const Key('rename-theme-profile-name'),
      controller: _controller,
      autofocus: true,
      maxLength: 40,
      decoration: InputDecoration(labelText: '프로필 이름', errorText: _error),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('취소'),
      ),
      FilledButton(
        key: const Key('confirm-rename-theme-profile'),
        onPressed: _submit,
        child: const Text('변경'),
      ),
    ],
  );
}

class _CustomAccentPreference extends StatefulWidget {
  const _CustomAccentPreference({
    required this.enabled,
    required this.rgb,
    required this.onEnabledChanged,
    required this.onRgbChanged,
  });

  final bool enabled;
  final int rgb;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onRgbChanged;

  @override
  State<_CustomAccentPreference> createState() =>
      _CustomAccentPreferenceState();
}

class _CustomAccentPreferenceState extends State<_CustomAccentPreference> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _hex(widget.rgb));
  }

  @override
  void didUpdateWidget(covariant _CustomAccentPreference oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.rgb != widget.rgb) {
      _controller.text = _hex(widget.rgb);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  static String _hex(int rgb) =>
      (rgb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  void _update(String raw) {
    if (raw.length != 6) return;
    final parsed = int.tryParse(raw, radix: 16);
    if (parsed != null) widget.onRgbChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final safeColor = AppTheme.safeCustomAccentColor(
      widget.rgb,
      brightness: brightness,
      background: Theme.of(context).scaffoldBackgroundColor,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PreferenceSwitch(
          controlKey: const Key('theme-custom-accent-enabled'),
          title: '직접 만든 강조색',
          subtitle: '배경 대비가 낮으면 읽기 안전 기준에 맞게 자동 보정합니다.',
          value: widget.enabled,
          onChanged: widget.onEnabledChanged,
        ),
        if (widget.enabled)
          TextField(
            key: const Key('theme-custom-accent-hex'),
            controller: _controller,
            focusNode: _focusNode,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[0-9A-Fa-f]')),
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              labelText: 'HEX 색상',
              prefixText: '#',
              helperText: '적용 색상은 대비 안전 보정 후 표시됩니다.',
              suffixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: CircleAvatar(backgroundColor: safeColor),
              ),
            ),
            onChanged: _update,
            onSubmitted: _update,
          ),
      ],
    );
  }
}

class _ThemeSchedulePreview extends StatelessWidget {
  const _ThemeSchedulePreview({required this.preferences});

  final AppExperiencePreferences preferences;

  @override
  Widget build(BuildContext context) {
    final darkHour =
        preferences.themeScheduleMode == AppThemeScheduleMode.evening
        ? 19
        : preferences.themeDarkStartHour;
    final lightHour =
        preferences.themeScheduleMode == AppThemeScheduleMode.evening
        ? 7
        : preferences.themeLightStartHour;
    String label(int hour) => '${hour.toString().padLeft(2, '0')}:00';
    return Container(
      key: const Key('theme-schedule-preview'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.light_mode_rounded),
          const SizedBox(width: 8),
          Text('${label(lightHour)} 라이트'),
          const Expanded(child: Divider(indent: 10, endIndent: 10)),
          const Icon(Icons.dark_mode_rounded),
          const SizedBox(width: 8),
          Text('${label(darkHour)} 다크'),
        ],
      ),
    );
  }
}

class _PersonalizationSection extends StatelessWidget {
  const _PersonalizationSection({
    required this.sectionKey,
    required this.icon,
    required this.title,
    required this.summary,
    required this.children,
    this.initiallyExpanded = false,
  });

  final Key sectionKey;
  final IconData icon;
  final String title;
  final String summary;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: sectionKey,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [const Divider(), ...children],
      ),
    );
  }
}

class _ChoiceGroup<T> extends StatelessWidget {
  const _ChoiceGroup({
    required this.label,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onChanged,
    this.swatchFor,
    this.controlKey,
  });

  final String label;
  final T value;
  final List<T> values;
  final String Function(T) labelFor;
  final ValueChanged<T> onChanged;
  final Color Function(T)? swatchFor;
  final Key? controlKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: controlKey,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 7),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final option in values)
                ChoiceChip(
                  key: Key(
                    'personalization-${T.toString()}-${_enumName(option)}',
                  ),
                  selected: option == value,
                  avatar: swatchFor == null
                      ? null
                      : CircleAvatar(backgroundColor: swatchFor!(option)),
                  label: Text(labelFor(option)),
                  onSelected: (_) => onChanged(option),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.controlKey,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final Key controlKey;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      key: controlKey,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _SliderPreference extends StatelessWidget {
  const _SliderPreference({
    required this.controlKey,
    required this.title,
    required this.value,
    required this.valueLabel,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final Key controlKey;
  final String title;
  final double value;
  final String valueLabel;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: controlKey,
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title)),
              Text(valueLabel, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _HomeSectionTile extends StatelessWidget {
  const _HomeSectionTile({
    required this.section,
    required this.visible,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onVisibilityChanged,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final AppHomeSection section;
  final bool visible;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('home-section-${section.name}'),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Checkbox(
            key: Key('home-section-visible-${section.name}'),
            value: visible,
            onChanged: (value) {
              if (value != null) onVisibilityChanged(value);
            },
          ),
          Expanded(child: Text(_homeSectionLabel(section))),
          IconButton(
            key: Key('home-section-up-${section.name}'),
            tooltip: '위로',
            onPressed: canMoveUp ? onMoveUp : null,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
          IconButton(
            key: Key('home-section-down-${section.name}'),
            tooltip: '아래로',
            onPressed: canMoveDown ? onMoveDown : null,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ],
      ),
    );
  }
}

AppExperiencePreferences _moveHomeSection(
  AppExperiencePreferences preferences,
  int from,
  int to,
) {
  final order = [...preferences.homeSectionOrder];
  final section = order.removeAt(from);
  order.insert(to, section);
  return preferences.copyWith(homeSectionOrder: order);
}

bool _homeSectionVisible(
  AppExperiencePreferences preferences,
  AppHomeSection section,
) => switch (section) {
  AppHomeSection.pinnedCollections => preferences.showPinnedCollections,
  AppHomeSection.recentAdditions => preferences.showRecentAdditions,
  AppHomeSection.dataFlow => preferences.showDataFlow,
  AppHomeSection.schedules => preferences.showSchedules,
};

AppExperiencePreferences _withHomeSectionVisibility(
  AppExperiencePreferences preferences,
  AppHomeSection section,
  bool value,
) => switch (section) {
  AppHomeSection.pinnedCollections => preferences.copyWith(
    showPinnedCollections: value,
  ),
  AppHomeSection.recentAdditions => preferences.copyWith(
    showRecentAdditions: value,
  ),
  AppHomeSection.dataFlow => preferences.copyWith(showDataFlow: value),
  AppHomeSection.schedules => preferences.copyWith(showSchedules: value),
};

int _visibleHomeSectionCount(AppExperiencePreferences preferences) =>
    AppHomeSection.values.where((section) {
      return _homeSectionVisible(preferences, section);
    }).length +
    (preferences.showTodayPlan ? 1 : 0);

String _enumName(Object? value) => value is Enum ? value.name : '$value';

IconData _presetIcon(PersonalizationPreset preset) => switch (preset) {
  PersonalizationPreset.sprache => Icons.auto_awesome_rounded,
  PersonalizationPreset.focus => Icons.center_focus_strong_rounded,
  PersonalizationPreset.paper => Icons.article_outlined,
  PersonalizationPreset.oledNight => Icons.bedtime_outlined,
};

String _colorModeLabel(AppColorMode value) => switch (value) {
  AppColorMode.system => '시스템',
  AppColorMode.light => '라이트',
  AppColorMode.dark => '다크',
  AppColorMode.oled => 'OLED',
};

String _paletteLabel(AppAccentPalette value) => switch (value) {
  AppAccentPalette.sprache => 'Sprache',
  AppAccentPalette.forest => '포레스트',
  AppAccentPalette.ocean => '오션',
  AppAccentPalette.violet => '바이올렛',
  AppAccentPalette.coral => '코랄',
  AppAccentPalette.slate => '슬레이트',
  AppAccentPalette.sunrise => '선라이즈',
  AppAccentPalette.mint => '민트',
  AppAccentPalette.rose => '로즈',
  AppAccentPalette.mono => '모노',
};

String _surfaceLabel(AppSurfaceTone value) => switch (value) {
  AppSurfaceTone.neutral => '중립',
  AppSurfaceTone.warm => '따뜻한 종이',
  AppSurfaceTone.cool => '차가운 회색',
};

String _cornerLabel(AppCornerStyle value) => switch (value) {
  AppCornerStyle.rounded => '둥글게',
  AppCornerStyle.balanced => '균형',
  AppCornerStyle.square => '각지게',
};

String _cardLabel(AppCardStyle value) => switch (value) {
  AppCardStyle.flat => '평면',
  AppCardStyle.outlined => '테두리',
  AppCardStyle.elevated => '입체',
};

String _fontLabel(AppFontEmphasis value) => switch (value) {
  AppFontEmphasis.standard => '일반',
  AppFontEmphasis.strong => '선명하게',
};

String _fontFamilyLabel(AppFontFamily value) => switch (value) {
  AppFontFamily.notoSans => 'Noto Sans KR',
  AppFontFamily.system => '시스템 산세리프',
  AppFontFamily.serif => '플랫폼 세리프',
  AppFontFamily.monospace => '고정폭',
};

String _textScaleLabel(AppTextScale value) => switch (value) {
  AppTextScale.system => '시스템',
  AppTextScale.small => '작게',
  AppTextScale.medium => '보통',
  AppTextScale.large => '크게',
  AppTextScale.extraLarge => '아주 크게',
};

String _studyTextScaleLabel(AppStudyTextScale value) => switch (value) {
  AppStudyTextScale.sameAsApp => '앱과 같게',
  AppStudyTextScale.larger => '15% 크게',
  AppStudyTextScale.extraLarge => '30% 크게',
};

String _cardAlignmentLabel(AppCardAlignment value) => switch (value) {
  AppCardAlignment.adaptive => '화면에 맞게',
  AppCardAlignment.leading => '왼쪽 정렬',
  AppCardAlignment.centered => '가운데 정렬',
};

String _decorationIntensityLabel(AppDecorationIntensity value) =>
    switch (value) {
      AppDecorationIntensity.minimal => '최소',
      AppDecorationIntensity.balanced => '균형',
      AppDecorationIntensity.vivid => '생동감',
    };

String _themeScheduleLabel(AppThemeScheduleMode value) => switch (value) {
  AppThemeScheduleMode.off => '사용 안 함',
  AppThemeScheduleMode.evening => '저녁 19시 · 아침 7시',
  AppThemeScheduleMode.custom => '직접 지정',
};

String _lineHeightLabel(AppReadingLineHeight value) => switch (value) {
  AppReadingLineHeight.compact => '촘촘하게',
  AppReadingLineHeight.comfortable => '편안하게',
  AppReadingLineHeight.relaxed => '여유롭게',
};

String _readingWidthLabel(AppReadingWidth value) => switch (value) {
  AppReadingWidth.narrow => '좁게',
  AppReadingWidth.balanced => '균형',
  AppReadingWidth.wide => '넓게',
};

String _contentWidthLabel(AppContentWidth value) => switch (value) {
  AppContentWidth.focused => '집중',
  AppContentWidth.balanced => '균형',
  AppContentWidth.wide => '넓게',
};

String _motionLabel(AppMotionLevel value) => switch (value) {
  AppMotionLevel.full => '전체',
  AppMotionLevel.reduced => '은은하게',
  AppMotionLevel.off => '끄기',
};

String _celebrationLabel(AppCelebrationLevel value) => switch (value) {
  AppCelebrationLevel.full => '풍부하게',
  AppCelebrationLevel.subtle => '간결하게',
  AppCelebrationLevel.off => '끄기',
};

String _homeLayoutLabel(AppHomeLayout value) => switch (value) {
  AppHomeLayout.focus => '집중',
  AppHomeLayout.balanced => '균형',
  AppHomeLayout.insights => '인사이트',
};

String _navigationLabel(AppNavigationLabelMode value) => switch (value) {
  AppNavigationLabelMode.always => '항상 표시',
  AppNavigationLabelMode.selected => '선택한 탭만',
  AppNavigationLabelMode.iconsOnly => '아이콘 중심',
};

String _navigationIconStyleLabel(AppNavigationIconStyle value) =>
    switch (value) {
      AppNavigationIconStyle.adaptive => '선택 항목만 채움',
      AppNavigationIconStyle.outlined => '윤곽선',
      AppNavigationIconStyle.filled => '채움',
    };

String _subjectSwitcherLabel(AppSubjectSwitcherStyle value) => switch (value) {
  AppSubjectSwitcherStyle.full => '전체',
  AppSubjectSwitcherStyle.compact => '간단히',
};

String _quickKindLabel(AppQuickAddKind value) => switch (value) {
  AppQuickAddKind.word => '단어',
  AppQuickAddKind.sentence => '문장',
  AppQuickAddKind.lastUsed => '마지막 사용',
};

String _duplicateLabel(AppDuplicateDefault value) => switch (value) {
  AppDuplicateDefault.ask => '항상 질문',
  AppDuplicateDefault.merge => '뜻 병합',
  AppDuplicateDefault.separate => '별도 저장',
};

String _draftDelayLabel(int milliseconds) => switch (milliseconds) {
  <= 500 => '빠르게',
  <= 1000 => '균형',
  _ => '느리게',
};

String _feedbackLabel(AppFeedbackDetail value) => switch (value) {
  AppFeedbackDetail.concise => '간결',
  AppFeedbackDetail.balanced => '균형',
  AppFeedbackDetail.coach => '코치',
};

String _progressLabel(AppProgressStyle value) => switch (value) {
  AppProgressStyle.bar => '막대',
  AppProgressStyle.steps => '단계',
  AppProgressStyle.minimal => '최소',
};

String _encouragementLabel(AppEncouragementTone value) => switch (value) {
  AppEncouragementTone.calm => '차분하게',
  AppEncouragementTone.playful => '즐겁게',
  AppEncouragementTone.minimal => '최소',
};

String _homeSectionLabel(AppHomeSection section) => switch (section) {
  AppHomeSection.pinnedCollections => '고정 컬렉션',
  AppHomeSection.recentAdditions => '최근 추가 자료',
  AppHomeSection.dataFlow => '학습 데이터 흐름',
  AppHomeSection.schedules => '예약 학습',
};
