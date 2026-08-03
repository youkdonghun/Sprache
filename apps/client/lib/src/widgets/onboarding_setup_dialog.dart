import 'package:flutter/material.dart';

import '../data/sample_content.dart';
import '../domain/app_experience_preferences.dart';
import '../domain/language.dart';
import '../domain/learning_item.dart';
import '../domain/onboarding_profile.dart';
import '../theme/app_theme.dart';

class OnboardingSetupResult {
  const OnboardingSetupResult({required this.language, required this.profile});

  final LanguageTag language;
  final OnboardingProfile profile;
}

Future<OnboardingSetupResult?> showOnboardingSetupDialog({
  required BuildContext context,
  required LanguageTag initialLanguage,
  required OnboardingProfile initialProfile,
  required ValueChanged<OnboardingProfile> onDraft,
}) => showDialog<OnboardingSetupResult>(
  context: context,
  barrierDismissible: false,
  useRootNavigator: true,
  builder: (context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
      child: OnboardingSetupPanel(
        initialLanguage: initialLanguage,
        initialProfile: initialProfile,
        onDraft: onDraft,
        onComplete: (result) => Navigator.of(context).pop(result),
        onLater: () => Navigator.of(context).pop(),
      ),
    ),
  ),
);

class OnboardingSetupPanel extends StatefulWidget {
  const OnboardingSetupPanel({
    super.key,
    required this.initialLanguage,
    required this.initialProfile,
    required this.onDraft,
    required this.onComplete,
    required this.onLater,
  });

  final LanguageTag initialLanguage;
  final OnboardingProfile initialProfile;
  final ValueChanged<OnboardingProfile> onDraft;
  final ValueChanged<OnboardingSetupResult> onComplete;
  final VoidCallback onLater;

  @override
  State<OnboardingSetupPanel> createState() => _OnboardingSetupPanelState();
}

class _OnboardingSetupPanelState extends State<OnboardingSetupPanel> {
  late LanguageTag _language = _initialLanguage();
  late OnboardingProfile _profile = widget.initialProfile.copyWith(
    languageCode: _initialLanguage().code,
    deferred: false,
  );

  LanguageTag _initialLanguage() {
    for (final language in LanguageTag.values) {
      if (language.available &&
          language.code == widget.initialProfile.languageCode) {
        return language;
      }
    }
    return widget.initialLanguage.available
        ? widget.initialLanguage
        : LanguageTag.english;
  }

  void _change(OnboardingProfile next) {
    setState(() => _profile = next.copyWith(languageCode: _language.code));
    widget.onDraft(_profile);
  }

  void _changeLanguage(LanguageTag language) {
    setState(() {
      _language = language;
      _profile = _profile.copyWith(languageCode: language.code);
    });
    widget.onDraft(_profile);
  }

  void _goTo(int step) => _change(
    _profile.copyWith(
      draftStep: step,
      deferred: false,
      scheduleConfigured:
          _profile.scheduleConfigured || (_profile.draftStep == 2 && step > 2),
    ),
  );

  void _later() {
    final draft = _profile.copyWith(deferred: true);
    widget.onDraft(draft);
    widget.onLater();
  }

  void _complete(OnboardingEntryChoice entry) {
    final result = _profile.copyWith(
      entryChoice: entry,
      draftStep: OnboardingProfile.stepCount - 1,
      deferred: false,
    );
    widget.onDraft(result);
    widget.onComplete(
      OnboardingSetupResult(language: _language, profile: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final step = _profile.draftStep;
    final colors = Theme.of(context).colorScheme;
    return Column(
      key: const Key('onboarding-step-panel'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '처음 학습 설정',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${step + 1}/${OnboardingProfile.stepCount}단계 · 고른 내용은 이 기기에 바로 저장돼요.',
                      key: const Key('onboarding-progress-label'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('onboarding-later'),
                onPressed: _later,
                child: const Text('나중에'),
              ),
              IconButton(
                tooltip: '나중에 이어서 설정',
                onPressed: _later,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        LinearProgressIndicator(
          key: const Key('onboarding-progress'),
          value: (step + 1) / OnboardingProfile.stepCount,
          minHeight: 5,
          backgroundColor: colors.surfaceContainerHighest,
        ),
        Expanded(
          child: SingleChildScrollView(
            key: Key('onboarding-step-${step + 1}'),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(step),
                child: switch (step) {
                  0 => _languageAndPurpose(),
                  1 => _levelAndTime(),
                  2 => _studyDays(),
                  3 => _accessibilityAndTheme(),
                  4 => _quickActions(),
                  _ => _reviewAndPreview(),
                },
              ),
            ),
          ),
        ),
        if (step < OnboardingProfile.stepCount - 1)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    key: const Key('onboarding-previous'),
                    onPressed: step == 0 ? null : () => _goTo(step - 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('이전'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('onboarding-next'),
                    onPressed: () => _goTo(step + 1),
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('다음'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _languageAndPurpose() => _StepSection(
    title: '배울 언어와 목표',
    description: '고른 목표에 맞춰 첫 학습과 게임을 추천해 드려요.',
    children: [
      const _FieldLabel('학습 언어'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final language in LanguageTag.values.where(
            (value) => value.available,
          ))
            ChoiceChip(
              key: Key('onboarding-language-${language.code}'),
              selected: _language == language,
              onSelected: (_) => _changeLanguage(language),
              avatar: CircleAvatar(child: Text(language.symbol)),
              label: Text(language.koreanName),
            ),
        ],
      ),
      const SizedBox(height: 20),
      const _FieldLabel('학습 목적'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final purpose in LearningPurpose.values)
            ChoiceChip(
              key: Key('onboarding-purpose-${purpose.name}'),
              selected: _profile.purpose == purpose,
              onSelected: (_) => _change(_profile.copyWith(purpose: purpose)),
              avatar: Icon(_purposeIcon(purpose), size: 18),
              label: Text(_purposeLabel(purpose)),
            ),
        ],
      ),
    ],
  );

  Widget _levelAndTime() => _StepSection(
    title: '내 수준과 하루 학습 시간',
    description: '처음 보여 줄 자료 수와 학습 길이를 알맞게 맞춰요.',
    children: [
      const _FieldLabel('현재 수준'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final level in SelfAssessedLevel.values)
            ChoiceChip(
              key: Key('onboarding-level-${level.name}'),
              selected: _profile.level == level,
              onSelected: (_) => _change(_profile.copyWith(level: level)),
              label: Text(_levelLabel(level)),
            ),
        ],
      ),
      const SizedBox(height: 20),
      const _FieldLabel('하루 학습 시간'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final target in const [(3, 50), (5, 100), (10, 150), (15, 200)])
            ChoiceChip(
              key: Key('onboarding-goal-${target.$2}'),
              selected: _profile.dailyGoal == target.$2,
              onSelected: (_) => _change(
                _profile.copyWith(
                  dailyMinutes: target.$1,
                  dailyGoal: target.$2,
                ),
              ),
              label: Text('${target.$1}분 · ${target.$2} XP'),
            ),
        ],
      ),
    ],
  );

  Widget _studyDays() {
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return _StepSection(
      title: '공부할 요일',
      description: '고르지 않은 날은 쉬는 날로 두고, 알림은 다음 학습일로 넘겨요.',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var weekday = 1; weekday <= 7; weekday++)
              FilterChip(
                key: Key('onboarding-weekday-$weekday'),
                selected: _profile.normalizedStudyWeekdays.contains(weekday),
                onSelected: (selected) {
                  final next = {..._profile.normalizedStudyWeekdays};
                  if (selected) {
                    next.add(weekday);
                  } else if (next.length > 1) {
                    next.remove(weekday);
                  }
                  _change(
                    _profile.copyWith(
                      studyWeekdays: next,
                      scheduleConfigured: true,
                    ),
                  );
                },
                avatar: Icon(
                  _profile.normalizedStudyWeekdays.contains(weekday)
                      ? Icons.school_rounded
                      : Icons.bedtime_outlined,
                  size: 17,
                ),
                label: Text(labels[weekday - 1]),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _InfoBox(
          icon: Icons.event_available_rounded,
          text:
              '학습 ${_profile.normalizedStudyWeekdays.length}일 · 휴식 ${7 - _profile.normalizedStudyWeekdays.length}일',
        ),
      ],
    );
  }

  Widget _accessibilityAndTheme() {
    final previewPreferences = AppExperiencePreferences(
      colorMode: _colorMode(_profile.themeMode),
      accentPalette: _accentPalette(_profile.accent),
      highContrast: _profile.easyAccess,
      textScale: _profile.easyAccess ? AppTextScale.large : AppTextScale.system,
      showFocusRing: true,
    );
    final brightness = switch (_profile.themeMode) {
      OnboardingThemeMode.dark => Brightness.dark,
      OnboardingThemeMode.light => Brightness.light,
      OnboardingThemeMode.system => Theme.of(context).brightness,
    };
    return _StepSection(
      title: '편하게 볼 수 있는 화면',
      description: '카드와 버튼 크기를 미리 보고 골라 보세요.',
      children: [
        SegmentedButton<OnboardingAccessibilityProfile>(
          key: const Key('onboarding-accessibility-profile'),
          segments: const [
            ButtonSegment(
              value: OnboardingAccessibilityProfile.standard,
              icon: Icon(Icons.tune_rounded),
              label: Text('기본'),
            ),
            ButtonSegment(
              value: OnboardingAccessibilityProfile.easyAccess,
              icon: Icon(Icons.accessibility_new_rounded),
              label: Text('편한 조작'),
            ),
          ],
          selected: {_profile.accessibilityProfile},
          onSelectionChanged: (values) =>
              _change(_profile.copyWith(accessibilityProfile: values.first)),
        ),
        const SizedBox(height: 8),
        Text(
          _profile.easyAccess
              ? '큰 버튼 · 큰 글자 · 고대비 · 시간 제한 없는 문제를 기본으로 사용합니다.'
              : '시스템 글자와 기본 대비를 사용합니다.',
        ),
        const SizedBox(height: 18),
        const _FieldLabel('화면 모드'),
        Wrap(
          spacing: 8,
          children: [
            for (final mode in OnboardingThemeMode.values)
              ChoiceChip(
                key: Key('onboarding-theme-${mode.name}'),
                selected: _profile.themeMode == mode,
                onSelected: (_) => _change(_profile.copyWith(themeMode: mode)),
                label: Text(_themeLabel(mode)),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const _FieldLabel('대표 강조색'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final accent in OnboardingAccent.values)
              ChoiceChip(
                key: Key('onboarding-accent-${accent.name}'),
                selected: _profile.accent == accent,
                onSelected: (_) => _change(_profile.copyWith(accent: accent)),
                avatar: CircleAvatar(
                  backgroundColor: AppTheme.palettePreview(
                    _accentPalette(accent),
                  ),
                ),
                label: Text(_accentLabel(accent)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Theme(
          data: AppTheme.mobileFor(previewPreferences, brightness: brightness),
          child: Builder(
            builder: (context) => Card(
              key: const Key('onboarding-theme-preview'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('오늘의 맞춤 학습 · 5분')),
                    FilledButton(onPressed: () {}, child: const Text('시작')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickActions() => _StepSection(
    title: '홈 바로가기 3개',
    description: '자주 쓰는 기능을 고르고 원하는 순서로 놓아 보세요.',
    children: [
      for (final (index, action) in _profile.quickActions.indexed)
        Card(
          key: Key('onboarding-quick-action-$index'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            child: Row(
              children: [
                CircleAvatar(child: Text('${index + 1}')),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<HomeQuickAction>(
                    value: action,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final value in HomeQuickAction.values)
                        DropdownMenuItem(
                          value: value,
                          child: Row(
                            children: [
                              Icon(_quickActionIcon(value), size: 19),
                              const SizedBox(width: 8),
                              Text(_quickActionLabel(value)),
                            ],
                          ),
                        ),
                    ],
                    selectedItemBuilder: (context) => [
                      for (final value in HomeQuickAction.values)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _quickActionLabel(value),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null || value == action) return;
                      final next = [..._profile.quickActions];
                      final duplicate = next.indexOf(value);
                      if (duplicate >= 0) next[duplicate] = action;
                      next[index] = value;
                      _change(_profile.copyWith(quickActions: next));
                    },
                  ),
                ),
                IconButton(
                  key: Key('onboarding-quick-action-up-$index'),
                  tooltip: '위로',
                  onPressed: index == 0
                      ? null
                      : () => _moveQuickAction(index, index - 1),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                IconButton(
                  key: Key('onboarding-quick-action-down-$index'),
                  tooltip: '아래로',
                  onPressed: index == 2
                      ? null
                      : () => _moveQuickAction(index, index + 1),
                  icon: const Icon(Icons.arrow_downward_rounded),
                ),
              ],
            ),
          ),
        ),
    ],
  );

  void _moveQuickAction(int from, int to) {
    final next = [..._profile.quickActions];
    final value = next.removeAt(from);
    next.insert(to, value);
    _change(_profile.copyWith(quickActions: next));
  }

  Widget _reviewAndPreview() {
    final preview = sampleContent
        .where((item) => item.learningLanguage == _language)
        .where(_matchesPurpose)
        .take(3)
        .toList(growable: false);
    final fallback = preview.length == 3
        ? preview
        : sampleContent
              .where((item) => item.learningLanguage == _language)
              .take(3)
              .toList(growable: false);
    return _StepSection(
      title: '마지막으로 확인해 주세요',
      description: '가입 없이 샘플 3문제를 먼저 풀 수 있고, 결과는 이 기기에 저장돼요.',
      children: [
        _ReviewGrid(
          rows: [
            ('언어', _language.koreanName),
            ('목적', _purposeLabel(_profile.purpose)),
            ('수준', _levelLabel(_profile.level)),
            ('시간', '${_profile.dailyMinutes}분 · ${_profile.dailyGoal} XP'),
            ('시작', '샘플 또는 내 자료 가져오기'),
            (
              '추천',
              '${_profile.recommendedStarterGroupLabel} · ${_quickActionLabel(_profile.quickActions.first)}',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('첫 샘플 미리보기', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '3문제 · 약 ${_profile.easyAccess ? 3 : 2}분 · 천천히 풀어도 괜찮아요',
          key: const Key('onboarding-sample-estimate'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final (index, item) in fallback.indexed)
          ListTile(
            key: Key('onboarding-sample-${index + 1}'),
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(
              item.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              item.primaryTranslation,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const SizedBox(height: 12),
        const _InfoBox(
          icon: Icons.lock_outline_rounded,
          text: '샘플 학습에는 계정이 필요 없어요. 백업하거나 다른 기기에서 이어볼 때만 Google을 연결하세요.',
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('complete-first-run-setup'),
          onPressed: () => _complete(OnboardingEntryChoice.sampleLesson),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text('${_language.koreanName} 샘플 3문제 시작'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('onboarding-import-data'),
          onPressed: () => _complete(OnboardingEntryChoice.importMyData),
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('내 Excel·CSV 자료 가져오기'),
        ),
      ],
    );
  }

  bool _matchesPurpose(LearningItem item) => switch (_profile.purpose) {
    LearningPurpose.dailyConversation => true,
    LearningPurpose.travel => item.kind == LearningItemKind.sentence,
    LearningPurpose.work => item.capabilities.contains(
      ExerciseCapability.production,
    ),
    LearningPurpose.exam => item.priority > 0,
    LearningPurpose.hobby => item.kind == LearningItemKind.word,
  };
}

class _StepSection extends StatelessWidget {
  const _StepSection({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 5),
      Text(description, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: 18),
      ...children,
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    ),
  );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

class _ReviewGrid extends StatelessWidget {
  const _ReviewGrid({required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    row.$1,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Expanded(child: Text(row.$2)),
              ],
            ),
            if (index != rows.length - 1) const Divider(height: 18),
          ],
        ],
      ),
    ),
  );
}

String _purposeLabel(LearningPurpose value) => switch (value) {
  LearningPurpose.dailyConversation => '매일 꾸준히',
  LearningPurpose.travel => '회화·여행',
  LearningPurpose.work => '업무',
  LearningPurpose.exam => '시험 대비',
  LearningPurpose.hobby => '취미·단어',
};

IconData _purposeIcon(LearningPurpose value) => switch (value) {
  LearningPurpose.dailyConversation => Icons.calendar_today_rounded,
  LearningPurpose.travel => Icons.flight_takeoff_rounded,
  LearningPurpose.work => Icons.work_outline_rounded,
  LearningPurpose.exam => Icons.fact_check_rounded,
  LearningPurpose.hobby => Icons.auto_stories_rounded,
};

String _levelLabel(SelfAssessedLevel value) => switch (value) {
  SelfAssessedLevel.beginner => '처음',
  SelfAssessedLevel.elementary => '기초',
  SelfAssessedLevel.intermediate => '중급',
  SelfAssessedLevel.advanced => '고급',
};

String _themeLabel(OnboardingThemeMode value) => switch (value) {
  OnboardingThemeMode.system => '시스템',
  OnboardingThemeMode.light => '밝게',
  OnboardingThemeMode.dark => '어둡게',
};

String _accentLabel(OnboardingAccent value) => switch (value) {
  OnboardingAccent.sprache => 'Sprache',
  OnboardingAccent.ocean => '오션',
  OnboardingAccent.violet => '바이올렛',
  OnboardingAccent.coral => '코랄',
};

String _quickActionLabel(HomeQuickAction value) => switch (value) {
  HomeQuickAction.study => '추천 학습',
  HomeQuickAction.quickAdd => '빠른 추가',
  HomeQuickAction.practice => '게임·퀴즈',
  HomeQuickAction.library => '자료함',
  HomeQuickAction.importData => '가져오기',
  HomeQuickAction.stats => '통계',
};

IconData _quickActionIcon(HomeQuickAction value) => switch (value) {
  HomeQuickAction.study => Icons.play_arrow_rounded,
  HomeQuickAction.quickAdd => Icons.add_circle_outline_rounded,
  HomeQuickAction.practice => Icons.sports_esports_rounded,
  HomeQuickAction.library => Icons.folder_copy_outlined,
  HomeQuickAction.importData => Icons.upload_file_rounded,
  HomeQuickAction.stats => Icons.insights_rounded,
};

AppColorMode _colorMode(OnboardingThemeMode value) => switch (value) {
  OnboardingThemeMode.system => AppColorMode.system,
  OnboardingThemeMode.light => AppColorMode.light,
  OnboardingThemeMode.dark => AppColorMode.dark,
};

AppAccentPalette _accentPalette(OnboardingAccent value) => switch (value) {
  OnboardingAccent.sprache => AppAccentPalette.sprache,
  OnboardingAccent.ocean => AppAccentPalette.ocean,
  OnboardingAccent.violet => AppAccentPalette.violet,
  OnboardingAccent.coral => AppAccentPalette.coral,
};

extension OnboardingProfileApplication on OnboardingProfile {
  AppColorMode get appColorMode => _colorMode(themeMode);

  AppAccentPalette get appAccentPalette => _accentPalette(accent);
}

extension HomeQuickActionPresentation on HomeQuickAction {
  String get label => _quickActionLabel(this);

  IconData get icon => _quickActionIcon(this);
}
