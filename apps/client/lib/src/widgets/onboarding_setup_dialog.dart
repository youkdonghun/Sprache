import 'package:flutter/material.dart';

import '../data/sample_content.dart';
import '../domain/app_experience_preferences.dart';
import '../domain/language.dart';
import '../domain/learning_item.dart';
import '../domain/onboarding_profile.dart';

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
  static const _setupStepCount = 2;

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

  void _goTo(int step) =>
      _change(_profile.copyWith(draftStep: step, deferred: false));

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
    final step = _profile.draftStep == 0 ? 0 : 1;
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
                      '${step + 1}/$_setupStepCount단계 · 언어와 목표만 고르면 바로 시작해요.',
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
          value: (step + 1) / _setupStepCount,
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
                  _ => _reviewAndPreview(),
                },
              ),
            ),
          ),
        ),
        if (step < _setupStepCount - 1)
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
      title: '준비됐어요',
      description:
          '${_language.koreanName} 샘플로 바로 시작합니다. 나머지 설정은 써 보면서 천천히 바꿔도 돼요.',
      children: [
        _InfoBox(
          icon: Icons.timer_outlined,
          text:
              '${_purposeLabel(_profile.purpose)} · 약 2분 · 샘플 3문제 · 로그인 없이 체험',
        ),
        const SizedBox(height: 8),
        for (final (index, item) in fallback.take(1).indexed)
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
