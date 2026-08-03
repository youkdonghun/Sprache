import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/accessibility_input_profile.dart';
import '../theme/study_accessibility_theme.dart';

class AccessibilityInputProfileCard extends StatefulWidget {
  const AccessibilityInputProfileCard({
    required this.profile,
    required this.isWindows,
    required this.isAndroid,
    required this.onChanged,
    super.key,
  });

  final AccessibilityInputProfile profile;
  final bool isWindows;
  final bool isAndroid;
  final ValueChanged<AccessibilityInputProfile> onChanged;

  @override
  State<AccessibilityInputProfileCard> createState() =>
      _AccessibilityInputProfileCardState();
}

class _AccessibilityInputProfileCardState
    extends State<AccessibilityInputProfileCard> {
  String? _shortcutNotice;

  AccessibilityInputProfile get profile => widget.profile;

  void _remapStudy(StudyShortcutAction action, StudyShortcutKey key) {
    final result = profile.remapStudyShortcut(action, key);
    final displaced = result.displacedAction;
    setState(() {
      _shortcutNotice = displaced != null
          ? '${_shortcutActionLabel(displaced)} 단축키가 중복되어 “사용 안 함”으로 바뀌었습니다.'
          : null;
    });
    widget.onChanged(result.profile);
  }

  void _remapGlobal(GlobalShortcutAction action, StudyShortcutKey key) {
    final result = profile.remapGlobalShortcut(action, key);
    final displaced = result.displacedAction;
    setState(() {
      _shortcutNotice = displaced != null
          ? '${_globalShortcutActionLabel(displaced)} 단축키가 중복되어 “사용 안 함”으로 바뀌었습니다.'
          : null;
    });
    widget.onChanged(result.profile);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('accessibility-input-profile-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.accessibility_new_rounded, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '보기·입력 편의',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '이 설정은 이 기기에만 저장됩니다. 제스처를 끄더라도 화면 버튼과 키보드로 모든 기능을 이용할 수 있어요.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ProfileSwitch(
              controlKey: const Key('accessibility-large-rating-controls'),
              title: '복습 버튼 크게',
              subtitle: '다시·어려움·좋음·쉬움 버튼을 누르기 편하게 키웁니다.',
              value: profile.largeRatingControls,
              onChanged: (value) => widget.onChanged(
                profile.copyWith(largeRatingControls: value),
              ),
            ),
            _ProfileSwitch(
              controlKey: const Key('accessibility-high-contrast'),
              title: '고대비',
              subtitle: '카드 테두리와 입력 위치, 주요 버튼을 더 선명하게 보여 줍니다.',
              value: profile.highContrast,
              onChanged: (value) =>
                  widget.onChanged(profile.copyWith(highContrast: value)),
            ),
            _ProfileSwitch(
              controlKey: const Key('accessibility-reduce-motion'),
              title: '움직임 줄이기',
              subtitle: '화면 전환과 학습 피드백 애니메이션을 최소화합니다.',
              value: profile.reduceMotion,
              onChanged: (value) =>
                  widget.onChanged(profile.copyWith(reduceMotion: value)),
            ),
            _ProfileSwitch(
              controlKey: const Key('accessibility-reduce-transparency'),
              title: '투명도 줄이기',
              subtitle: '반투명 배경과 그림자를 줄여 화면 요소를 또렷하게 나눕니다.',
              value: profile.reduceTransparency,
              onChanged: (value) =>
                  widget.onChanged(profile.copyWith(reduceTransparency: value)),
            ),
            _ProfileSwitch(
              controlKey: const Key('accessibility-disable-timed-challenges'),
              title: '시간 제한 없이 학습',
              subtitle: '시간이 있는 게임도 제한 없이 천천히 풀 수 있게 바꿉니다.',
              value: profile.disableTimedChallenges,
              onChanged: (value) => widget.onChanged(
                profile.copyWith(disableTimedChallenges: value),
              ),
            ),
            const SizedBox(height: 10),
            _ProfileOptionGroup<AccessibilityCardScale>(
              label: '학습 카드 크기',
              keyPrefix: 'accessibility-card-scale',
              value: profile.cardScale,
              options: [
                for (final scale in AccessibilityCardScale.values)
                  (scale, _cardScaleLabel(scale)),
              ],
              onChanged: (value) =>
                  widget.onChanged(profile.copyWith(cardScale: value)),
            ),
            if (widget.isAndroid) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),
              _ProfileOptionGroup<AndroidSelectionGesture>(
                label: '화면에서 선택하는 방식',
                description: '탭이나 스와이프를 켜도 선택 버튼은 항상 표시됩니다.',
                keyPrefix: 'accessibility-android-gesture',
                value: profile.androidSelectionGesture,
                options: [
                  for (final gesture in AndroidSelectionGesture.values)
                    (gesture, _gestureLabel(gesture)),
                ],
                onChanged: (value) => widget.onChanged(
                  profile.copyWith(androidSelectionGesture: value),
                ),
              ),
            ],
            if (widget.isWindows) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),
              Text('앱 전역 단축키', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(
                '검색, 빠른 추가, 도움말, 창 동작에 쓸 키를 정합니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final action in GlobalShortcutAction.values)
                _ShortcutSelector(
                  keyName: 'global-${action.name}',
                  label: _globalShortcutActionLabel(action),
                  value: profile.globalShortcutFor(action),
                  onChanged: (key) => _remapGlobal(action, key),
                ),
              const SizedBox(height: 8),
              Text('학습 단축키', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(
                '이미 쓰는 키를 고르면 기존 단축키는 “사용 안 함”으로 바뀝니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final action in StudyShortcutAction.values)
                _ShortcutSelector(
                  keyName: action.name,
                  label: _shortcutActionLabel(action),
                  value: profile.shortcutFor(action),
                  onChanged: (key) => _remapStudy(action, key),
                ),
              if (_shortcutNotice case final notice?) ...[
                const SizedBox(height: 4),
                Semantics(
                  liveRegion: true,
                  label: '단축키 충돌. $notice',
                  child: Container(
                    key: const Key('accessibility-shortcut-conflict'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.error),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: colors.error),
                        const SizedBox(width: 8),
                        Expanded(child: Text(notice)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileSwitch extends StatelessWidget {
  const _ProfileSwitch({
    required this.controlKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Key controlKey;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: controlKey,
      label: '$title 설정',
      toggled: value,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          contentPadding: EdgeInsets.zero,
          title: Text(title),
          subtitle: Text(subtitle),
        ),
      ),
    );
  }
}

class _ProfileOptionGroup<T> extends StatelessWidget {
  const _ProfileOptionGroup({
    required this.label,
    required this.keyPrefix,
    required this.value,
    required this.options,
    required this.onChanged,
    this.description,
  });

  final String label;
  final String? description;
  final String keyPrefix;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        if (description != null) ...[
          const SizedBox(height: 3),
          Text(description!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 7),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              Semantics(
                selected: option.$1 == value,
                button: true,
                label: '$label ${option.$2}',
                child: ConstrainedBox(
                  key: Key('$keyPrefix-${_keyName(option.$1)}'),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: ChoiceChip(
                    label: Text(option.$2),
                    selected: option.$1 == value,
                    onSelected: (_) => onChanged(option.$1),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ShortcutSelector extends StatelessWidget {
  const _ShortcutSelector({
    required this.keyName,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String keyName;
  final String label;
  final StudyShortcutKey value;
  final ValueChanged<StudyShortcutKey> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              constraints.maxWidth < 420 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final selector = Semantics(
            label: '$label 단축키',
            child: SizedBox(
              key: Key('accessibility-shortcut-$keyName'),
              width: stacked ? double.infinity : 190,
              height: 48,
              child: DropdownButtonFormField<StudyShortcutKey>(
                initialValue: value,
                isExpanded: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: [
                  for (final key in StudyShortcutKey.values)
                    DropdownMenuItem(
                      value: key,
                      child: Text(key.displayLabelFor(defaultTargetPlatform)),
                    ),
                ],
                onChanged: (next) {
                  if (next != null) onChanged(next);
                },
              ),
            ),
          );
          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Text(label), const SizedBox(height: 4), selector],
            );
          }
          return Row(
            children: [
              Expanded(child: Text(label)),
              const SizedBox(width: 12),
              selector,
            ],
          );
        },
      ),
    );
  }
}

String _keyName(Object? value) => switch (value) {
  final Enum enumValue => enumValue.name,
  _ => value.toString(),
};

String _cardScaleLabel(AccessibilityCardScale value) => switch (value) {
  AccessibilityCardScale.standard => '기본',
  AccessibilityCardScale.large => '크게',
  AccessibilityCardScale.extraLarge => '아주 크게',
};

String _gestureLabel(AndroidSelectionGesture value) => switch (value) {
  AndroidSelectionGesture.buttonsOnly => '버튼만',
  AndroidSelectionGesture.tapAndButtons => '탭 + 버튼',
  AndroidSelectionGesture.swipeAndButtons => '스와이프 + 버튼',
};

String _shortcutActionLabel(StudyShortcutAction value) => switch (value) {
  StudyShortcutAction.revealAnswer => '정답 보기',
  StudyShortcutAction.playAudio => '음성 재생',
  StudyShortcutAction.rateAgain => '다시',
  StudyShortcutAction.rateHard => '어려움',
  StudyShortcutAction.rateGood => '좋음',
  StudyShortcutAction.rateEasy => '쉬움',
  StudyShortcutAction.nextItem => '다음 문제',
  StudyShortcutAction.showHint => '힌트',
  StudyShortcutAction.dontKnow => '모르겠어요',
  StudyShortcutAction.skip => '건너뛰기',
  StudyShortcutAction.pause => '일시정지',
};

String _globalShortcutActionLabel(GlobalShortcutAction value) =>
    switch (value) {
      GlobalShortcutAction.openSearch => '명령 팔레트·전체 검색',
      GlobalShortcutAction.quickAdd => '빠른 추가',
      GlobalShortcutAction.keyboardHelp => '키보드 도움말',
      GlobalShortcutAction.focusContent => '본문으로 이동',
      GlobalShortcutAction.toggleCompactWindow => '컴팩트 창 전환',
      GlobalShortcutAction.minimizeWindow => '창 최소화',
    };
