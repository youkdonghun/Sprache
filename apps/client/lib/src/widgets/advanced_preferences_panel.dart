import 'package:flutter/material.dart';

import '../domain/app_experience_preferences.dart';
import '../domain/study_interaction_preferences.dart';
import '../theme/app_theme.dart';

class AdvancedPreferencesPanel extends StatelessWidget {
  const AdvancedPreferencesPanel({
    required this.experiencePreferences,
    required this.interactionPreferences,
    required this.ttsRate,
    required this.onExperiencePreferencesChanged,
    required this.onInteractionPreferencesChanged,
    required this.onTtsRateChanged,
    this.searchQuery = '',
    super.key,
  });

  final AppExperiencePreferences experiencePreferences;
  final StudyInteractionPreferences interactionPreferences;
  final double ttsRate;
  final ValueChanged<AppExperiencePreferences> onExperiencePreferencesChanged;
  final ValueChanged<StudyInteractionPreferences>
  onInteractionPreferencesChanged;
  final ValueChanged<double> onTtsRateChanged;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('advanced-preferences-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PreferenceExpansion(
          key: const Key('advanced-preferences-appearance'),
          forceExpanded: _matchesPreferenceSearch(
            searchQuery,
            '외형 화면 모드 시스템 라이트 다크 테마 강조 색상 팔레트 밀도 '
            '글자 크기 모션 움직임 진동 햅틱 효과음',
          ),
          icon: Icons.palette_outlined,
          title: '화면',
          summary:
              '${_colorModeLabel(experiencePreferences.colorMode)} · '
              '${_paletteLabel(experiencePreferences.accentPalette)} · '
              '${_densityLabel(experiencePreferences.density)}',
          children: [
            _OptionGroup<AppColorMode>(
              label: '화면 모드',
              semanticLabel: '화면 모드',
              keyPrefix: 'appearance-color-mode',
              value: experiencePreferences.colorMode,
              options: const [
                _PreferenceOption(
                  value: AppColorMode.system,
                  keyName: 'system',
                  label: '시스템',
                ),
                _PreferenceOption(
                  value: AppColorMode.light,
                  keyName: 'light',
                  label: '라이트',
                ),
                _PreferenceOption(
                  value: AppColorMode.dark,
                  keyName: 'dark',
                  label: '다크',
                ),
                _PreferenceOption(
                  value: AppColorMode.oled,
                  keyName: 'oled',
                  label: 'OLED',
                ),
              ],
              onChanged: (value) => onExperiencePreferencesChanged(
                experiencePreferences.copyWith(colorMode: value),
              ),
            ),
            _OptionGroup<AppAccentPalette>(
              label: '강조 색상',
              semanticLabel: '강조 색상 팔레트',
              keyPrefix: 'appearance-palette',
              value: experiencePreferences.accentPalette,
              options: [
                for (final palette in AppAccentPalette.values)
                  _PreferenceOption(
                    value: palette,
                    keyName: palette.name,
                    label: _paletteLabel(palette),
                    swatch: AppTheme.palettePreview(palette),
                  ),
              ],
              onChanged: (value) => onExperiencePreferencesChanged(
                experiencePreferences.copyWith(accentPalette: value),
              ),
            ),
            _OptionGroup<AppDensity>(
              label: '화면 간격',
              semanticLabel: '화면 간격',
              keyPrefix: 'appearance-density',
              value: experiencePreferences.density,
              options: const [
                _PreferenceOption(
                  value: AppDensity.platform,
                  keyName: 'platform',
                  label: '기기 기본',
                ),
                _PreferenceOption(
                  value: AppDensity.comfortable,
                  keyName: 'comfortable',
                  label: '여유롭게',
                ),
                _PreferenceOption(
                  value: AppDensity.compact,
                  keyName: 'compact',
                  label: '촘촘하게',
                ),
              ],
              onChanged: (value) => onExperiencePreferencesChanged(
                experiencePreferences.copyWith(density: value),
              ),
            ),
            _OptionGroup<AppTextScale>(
              label: '글자 크기',
              semanticLabel: '글자 크기',
              keyPrefix: 'appearance-text-scale',
              value: experiencePreferences.textScale,
              options: const [
                _PreferenceOption(
                  value: AppTextScale.system,
                  keyName: 'system',
                  label: '시스템',
                ),
                _PreferenceOption(
                  value: AppTextScale.small,
                  keyName: 'small',
                  label: '작게',
                ),
                _PreferenceOption(
                  value: AppTextScale.medium,
                  keyName: 'medium',
                  label: '보통',
                ),
                _PreferenceOption(
                  value: AppTextScale.large,
                  keyName: 'large',
                  label: '크게',
                ),
                _PreferenceOption(
                  value: AppTextScale.extraLarge,
                  keyName: 'extra-large',
                  label: '아주 크게',
                ),
              ],
              onChanged: (value) => onExperiencePreferencesChanged(
                experiencePreferences.copyWith(textScale: value),
              ),
            ),
            _CompactSwitch(
              controlKey: const Key('appearance-reduce-motion'),
              semanticLabel: '움직임 줄이기 설정',
              title: '움직임 줄이기',
              subtitle: '화면 전환과 강조 애니메이션을 최소화합니다.',
              value: experiencePreferences.motionLevel != AppMotionLevel.full,
              onChanged: (value) => onExperiencePreferencesChanged(
                experiencePreferences.copyWith(
                  motionLevel: value
                      ? AppMotionLevel.reduced
                      : AppMotionLevel.full,
                  reduceMotion: false,
                ),
              ),
            ),
            _CompactSwitch(
              controlKey: const Key('appearance-haptics'),
              semanticLabel: '진동 피드백 설정',
              title: '진동 피드백',
              value: experiencePreferences.hapticsEnabled,
              onChanged: (value) => onExperiencePreferencesChanged(
                experiencePreferences.copyWith(hapticsEnabled: value),
              ),
            ),
            _CompactSwitch(
              controlKey: const Key('appearance-sound'),
              semanticLabel: '효과음 설정',
              title: '효과음',
              value: experiencePreferences.soundEffectsEnabled,
              onChanged: (value) => onExperiencePreferencesChanged(
                experiencePreferences.copyWith(soundEffectsEnabled: value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _PreferenceExpansion(
          key: const Key('advanced-preferences-reading-audio'),
          forceExpanded: _matchesPreferenceSearch(
            searchQuery,
            '읽기 음성 소리 tts 발음 자동 재생 오프라인 반복 한국어 원어 표기 속도',
          ),
          icon: Icons.record_voice_over_outlined,
          title: '읽기·음성',
          summary:
              '${interactionPreferences.audioRepeatCount}회 반복 · '
              '속도 ${(ttsRate.clamp(0.2, 0.8) * 100).round()}%',
          children: [
            _CompactSwitch(
              controlKey: const Key('audio-autoplay-question'),
              semanticLabel: '문제 음성 자동 재생 설정',
              title: '문제 음성 자동 재생',
              value: interactionPreferences.autoPlayQuestionAudio,
              onChanged: (value) => onInteractionPreferencesChanged(
                interactionPreferences.copyWith(autoPlayQuestionAudio: value),
              ),
            ),
            _CompactSwitch(
              controlKey: const Key('audio-autoplay-answer'),
              semanticLabel: '정답 음성 자동 재생 설정',
              title: '정답 음성 자동 재생',
              value: interactionPreferences.autoPlayAnswerAudio,
              onChanged: (value) => onInteractionPreferencesChanged(
                interactionPreferences.copyWith(autoPlayAnswerAudio: value),
              ),
            ),
            _CompactSwitch(
              controlKey: const Key('audio-offline-voice'),
              semanticLabel: '오프라인 음성 우선 설정',
              title: '오프라인 음성 우선',
              subtitle: '인터넷 없이 쓸 수 있는 기기 음성을 먼저 재생합니다.',
              value: interactionPreferences.preferOfflineVoice,
              onChanged: (value) => onInteractionPreferencesChanged(
                interactionPreferences.copyWith(preferOfflineVoice: value),
              ),
            ),
            _OptionGroup<int>(
              label: '음성 반복',
              semanticLabel: '음성 반복 횟수',
              keyPrefix: 'audio-repeat',
              value: interactionPreferences.audioRepeatCount,
              options: const [
                _PreferenceOption(value: 1, keyName: '1', label: '1회'),
                _PreferenceOption(value: 2, keyName: '2', label: '2회'),
                _PreferenceOption(value: 3, keyName: '3', label: '3회'),
              ],
              onChanged: (value) => onInteractionPreferencesChanged(
                interactionPreferences.copyWith(audioRepeatCount: value),
              ),
            ),
            _CompactSwitch(
              controlKey: const Key('reading-korean'),
              semanticLabel: '한국어 읽기 표기 설정',
              title: '한국어 읽기 표기',
              value: interactionPreferences.showKoreanReading,
              onChanged: (value) => onInteractionPreferencesChanged(
                interactionPreferences.copyWith(showKoreanReading: value),
              ),
            ),
            _CompactSwitch(
              controlKey: const Key('reading-native'),
              semanticLabel: '원어 읽기 표기 설정',
              title: '원어 읽기 표기',
              value: interactionPreferences.showNativeReading,
              onChanged: (value) => onInteractionPreferencesChanged(
                interactionPreferences.copyWith(showNativeReading: value),
              ),
            ),
            _CompactSlider(
              controlKey: const Key('audio-tts-rate'),
              semanticLabel: 'TTS 음성 속도',
              title: '음성 속도',
              valueLabel: '${(ttsRate.clamp(0.2, 0.8) * 100).round()}%',
              value: ttsRate.clamp(0.2, 0.8),
              min: 0.2,
              max: 0.8,
              divisions: 6,
              onChanged: onTtsRateChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _PreferenceExpansion(
          key: const Key('advanced-preferences-quiz'),
          forceExpanded: _matchesPreferenceSearch(
            searchQuery,
            '퀴즈 문제 정답 방향 선택지 배치 섞기 자동 넘김 대기 채점',
          ),
          icon: Icons.quiz_outlined,
          title: '퀴즈 방식',
          summary:
              '${_directionLabel(interactionPreferences.answerDirection)} · '
              '${_choiceLayoutLabel(interactionPreferences.choiceLayout)} · '
              '${interactionPreferences.autoAdvanceCorrect ? '자동 넘김' : '직접 넘김'}',
          children: [
            _OptionGroup<StudyAnswerDirection>(
              label: '출제 방향',
              semanticLabel: '문제 출제 방향',
              keyPrefix: 'quiz-answer-direction',
              value: interactionPreferences.answerDirection,
              options: const [
                _PreferenceOption(
                  value: StudyAnswerDirection.learningToMeaning,
                  keyName: 'learning-to-meaning',
                  label: '학습어 → 뜻',
                ),
                _PreferenceOption(
                  value: StudyAnswerDirection.meaningToLearning,
                  keyName: 'meaning-to-learning',
                  label: '뜻 → 학습어',
                ),
                _PreferenceOption(
                  value: StudyAnswerDirection.mixed,
                  keyName: 'mixed',
                  label: '혼합',
                ),
              ],
              onChanged: (value) => onInteractionPreferencesChanged(
                interactionPreferences.copyWith(answerDirection: value),
              ),
            ),
            _OptionGroup<StudyChoiceLayout>(
              label: '선택지 모양',
              semanticLabel: '선택지 모양',
              keyPrefix: 'quiz-choice-layout',
              value: interactionPreferences.choiceLayout,
              options: const [
                _PreferenceOption(
                  value: StudyChoiceLayout.automatic,
                  keyName: 'automatic',
                  label: '자동',
                ),
                _PreferenceOption(
                  value: StudyChoiceLayout.list,
                  keyName: 'list',
                  label: '목록',
                ),
                _PreferenceOption(
                  value: StudyChoiceLayout.grid,
                  keyName: 'grid',
                  label: '격자',
                ),
              ],
              onChanged: (value) => onInteractionPreferencesChanged(
                interactionPreferences.copyWith(choiceLayout: value),
              ),
            ),
            _CompactSwitch(
              controlKey: const Key('quiz-shuffle-choices'),
              semanticLabel: '선택지 섞기 설정',
              title: '선택지 섞기',
              value: interactionPreferences.shuffleChoices,
              onChanged: (value) => onInteractionPreferencesChanged(
                interactionPreferences.copyWith(shuffleChoices: value),
              ),
            ),
            _CompactSwitch(
              controlKey: const Key('quiz-auto-next'),
              semanticLabel: '정답이면 다음 문제로 자동 이동 설정',
              title: '정답이면 자동으로 다음 문제',
              value: interactionPreferences.autoAdvanceCorrect,
              onChanged: (value) => onInteractionPreferencesChanged(
                interactionPreferences.copyWith(autoAdvanceCorrect: value),
              ),
            ),
            _CompactSlider(
              controlKey: const Key('quiz-auto-next-delay'),
              semanticLabel: '자동 넘김 대기 시간',
              title: '다음 문제까지 기다리기',
              valueLabel: _delayLabel(
                interactionPreferences.autoAdvanceDelayMs,
              ),
              value: interactionPreferences.autoAdvanceDelayMs
                  .clamp(300, 3000)
                  .toDouble(),
              min: 300,
              max: 3000,
              divisions: 27,
              onChanged: (value) => onInteractionPreferencesChanged(
                interactionPreferences.copyWith(
                  autoAdvanceDelayMs: value.round(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PreferenceExpansion extends StatefulWidget {
  const _PreferenceExpansion({
    required this.icon,
    required this.title,
    required this.summary,
    required this.children,
    this.forceExpanded = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String summary;
  final List<Widget> children;
  final bool forceExpanded;

  @override
  State<_PreferenceExpansion> createState() => _PreferenceExpansionState();
}

class _PreferenceExpansionState extends State<_PreferenceExpansion> {
  final ExpansibleController _controller = ExpansibleController();
  late bool _expanded = widget.forceExpanded;

  @override
  void didUpdateWidget(covariant _PreferenceExpansion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forceExpanded == widget.forceExpanded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.forceExpanded && !_expanded) {
        _controller.expand();
      } else if (!widget.forceExpanded &&
          oldWidget.forceExpanded &&
          _expanded) {
        _controller.collapse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ExpansionTile(
        controller: _controller,
        initiallyExpanded: widget.forceExpanded,
        onExpansionChanged: (value) => _expanded = value,
        dense: true,
        minTileHeight: 48,
        visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        leading: Icon(widget.icon, size: 21, color: colors.primary),
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          widget.summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          Divider(color: colors.outlineVariant),
          ...widget.children,
        ],
      ),
    );
  }
}

bool _matchesPreferenceSearch(String query, String keywords) {
  final tokens = query
      .trim()
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty);
  if (tokens.isEmpty) return false;
  final haystack = keywords.toLowerCase();
  return tokens.every(haystack.contains);
}

class _PreferenceOption<T> {
  const _PreferenceOption({
    required this.value,
    required this.keyName,
    required this.label,
    this.swatch,
  });

  final T value;
  final String keyName;
  final String label;
  final Color? swatch;
}

class _OptionGroup<T> extends StatelessWidget {
  const _OptionGroup({
    required this.label,
    required this.semanticLabel,
    required this.keyPrefix,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String semanticLabel;
  final String keyPrefix;
  final T value;
  final List<_PreferenceOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in options)
                _PreferenceChoice<T>(
                  controlKey: Key('$keyPrefix-${option.keyName}'),
                  semanticLabel: '$semanticLabel: ${option.label}',
                  label: option.label,
                  swatch: option.swatch,
                  selected: option.value == value,
                  onSelected: () => onChanged(option.value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreferenceChoice<T> extends StatelessWidget {
  const _PreferenceChoice({
    required this.controlKey,
    required this.semanticLabel,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.swatch,
  });

  final Key controlKey;
  final String semanticLabel;
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: controlKey,
      button: true,
      selected: selected,
      label: semanticLabel,
      onTap: onSelected,
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: ChoiceChip(
            selected: selected,
            showCheckmark: swatch == null,
            avatar: swatch == null
                ? null
                : CircleAvatar(backgroundColor: swatch, radius: 7),
            label: Text(label),
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: const EdgeInsets.symmetric(horizontal: 3),
            onSelected: (_) => onSelected(),
          ),
        ),
      ),
    );
  }
}

class _CompactSwitch extends StatelessWidget {
  const _CompactSwitch({
    required this.controlKey,
    required this.semanticLabel,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final Key controlKey;
  final String semanticLabel;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: controlKey,
      button: true,
      toggled: value,
      label: semanticLabel,
      onTap: () => onChanged(!value),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -3),
            title: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            subtitle: subtitle == null
                ? null
                : Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis),
            value: value,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _CompactSlider extends StatelessWidget {
  const _CompactSlider({
    required this.controlKey,
    required this.semanticLabel,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final Key controlKey;
  final String semanticLabel;
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        key: controlKey,
        container: true,
        label: semanticLabel,
        value: valueLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  valueLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: valueLabel,
              semanticFormatterCallback: (_) => '$semanticLabel $valueLabel',
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

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

String _densityLabel(AppDensity value) => switch (value) {
  AppDensity.platform => '기기 기본',
  AppDensity.comfortable => '여유롭게',
  AppDensity.compact => '촘촘하게',
};

String _directionLabel(StudyAnswerDirection value) => switch (value) {
  StudyAnswerDirection.learningToMeaning => '학습어 → 뜻',
  StudyAnswerDirection.meaningToLearning => '뜻 → 학습어',
  StudyAnswerDirection.mixed => '혼합',
};

String _choiceLayoutLabel(StudyChoiceLayout value) => switch (value) {
  StudyChoiceLayout.automatic => '자동 배치',
  StudyChoiceLayout.list => '목록 배치',
  StudyChoiceLayout.grid => '격자 배치',
};

String _delayLabel(int milliseconds) {
  final seconds = milliseconds.clamp(300, 3000) / 1000;
  return '${seconds.toStringAsFixed(seconds % 1 == 0 ? 0 : 1)}초';
}
