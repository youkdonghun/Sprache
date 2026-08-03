import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/accessibility_input_profile.dart';
import '../theme/study_accessibility_theme.dart';
import 'focus_restoration.dart';

enum KeyboardHelpContext { global, study, flashcards, pronunciation }

KeyboardHelpContext keyboardHelpContextForLocation(String location) {
  if (location.startsWith('/study')) return KeyboardHelpContext.study;
  if (location.startsWith('/flashcards')) return KeyboardHelpContext.flashcards;
  if (location.startsWith('/pronunciation')) {
    return KeyboardHelpContext.pronunciation;
  }
  return KeyboardHelpContext.global;
}

Future<void> showKeyboardHelpOverlay({
  required BuildContext context,
  required AccessibilityInputProfile profile,
  KeyboardHelpContext helpContext = KeyboardHelpContext.global,
  FocusNode? fallbackFocus,
}) async {
  await showFocusRestoringDialog<void>(
    context: context,
    fallbackFocus: fallbackFocus,
    builder: (dialogContext) =>
        _KeyboardHelpDialog(profile: profile, helpContext: helpContext),
  );
}

class _KeyboardHelpDialog extends StatelessWidget {
  const _KeyboardHelpDialog({required this.profile, required this.helpContext});

  final AccessibilityInputProfile profile;
  final KeyboardHelpContext helpContext;

  @override
  Widget build(BuildContext context) {
    final globalEntries = [
      for (final action in GlobalShortcutAction.values)
        if (profile.globalShortcutFor(action) != StudyShortcutKey.none)
          (_globalActionLabel(action), profile.globalShortcutFor(action)),
    ];
    final studyActions = switch (helpContext) {
      KeyboardHelpContext.global => const <StudyShortcutAction>[],
      KeyboardHelpContext.study => const [
        StudyShortcutAction.playAudio,
        StudyShortcutAction.showHint,
        StudyShortcutAction.dontKnow,
        StudyShortcutAction.skip,
        StudyShortcutAction.pause,
        StudyShortcutAction.nextItem,
        StudyShortcutAction.rateAgain,
        StudyShortcutAction.rateHard,
        StudyShortcutAction.rateGood,
        StudyShortcutAction.rateEasy,
      ],
      KeyboardHelpContext.flashcards => const [
        StudyShortcutAction.revealAnswer,
        StudyShortcutAction.playAudio,
        StudyShortcutAction.rateAgain,
        StudyShortcutAction.rateHard,
        StudyShortcutAction.rateGood,
        StudyShortcutAction.rateEasy,
        StudyShortcutAction.nextItem,
      ],
      KeyboardHelpContext.pronunciation => const [
        StudyShortcutAction.playAudio,
        StudyShortcutAction.revealAnswer,
        StudyShortcutAction.rateAgain,
        StudyShortcutAction.rateHard,
        StudyShortcutAction.nextItem,
      ],
    };
    final studyEntries = [
      for (final action in studyActions)
        if (profile.shortcutFor(action) != StudyShortcutKey.none)
          (_studyActionLabel(action), profile.shortcutFor(action)),
    ];

    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: AlertDialog(
        key: const Key('keyboard-help-overlay'),
        title: Row(
          children: [
            const Icon(Icons.keyboard_alt_outlined),
            const SizedBox(width: 10),
            Expanded(child: Text(_title(helpContext))),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('지금 화면에서 쓸 수 있는 키예요. 설정 > 키보드에서 언제든 바꿀 수 있어요.'),
                if (studyEntries.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _HelpSection(title: '현재 학습', entries: studyEntries),
                ],
                const SizedBox(height: 16),
                _HelpSection(title: '앱 전체', entries: globalEntries),
              ],
            ),
          ),
        ),
        actions: [
          FocusTraversalOrder(
            order: const NumericFocusOrder(1),
            child: FilledButton(
              key: const Key('close-keyboard-help'),
              autofocus: true,
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.entries});

  final String title;
  final List<(String, StudyShortcutKey)> entries;

  @override
  Widget build(BuildContext context) {
    final useStackedLayout =
        MediaQuery.sizeOf(context).width < 600 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return Semantics(
      container: true,
      label: title,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _HelpEntry(
                label: entry.$1,
                shortcut: entry.$2,
                stacked: useStackedLayout,
              ),
            ),
        ],
      ),
    );
  }
}

class _HelpEntry extends StatelessWidget {
  const _HelpEntry({
    required this.label,
    required this.shortcut,
    required this.stacked,
  });

  final String label;
  final StudyShortcutKey shortcut;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final labelWidget = Text(label);
    final keyWidget = Semantics(
      label: '$label 단축키 ${shortcut.displayLabelFor(defaultTargetPlatform)}',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: Text(
            shortcut.displayLabelFor(defaultTargetPlatform),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [labelWidget, const SizedBox(height: 4), keyWidget],
      );
    }
    return Row(
      children: [
        Expanded(child: labelWidget),
        const SizedBox(width: 12),
        keyWidget,
      ],
    );
  }
}

String _title(KeyboardHelpContext context) => switch (context) {
  KeyboardHelpContext.global => '키보드 도움말',
  KeyboardHelpContext.study => '퀴즈 단축키',
  KeyboardHelpContext.flashcards => '플래시카드 단축키',
  KeyboardHelpContext.pronunciation => '발음 연습 단축키',
};

String _studyActionLabel(StudyShortcutAction value) => switch (value) {
  StudyShortcutAction.revealAnswer => '정답 보기',
  StudyShortcutAction.playAudio => '음성 재생',
  StudyShortcutAction.rateAgain => '다시 보기',
  StudyShortcutAction.rateHard => '어려웠어요',
  StudyShortcutAction.rateGood => '알겠어요',
  StudyShortcutAction.rateEasy => '쉬웠어요',
  StudyShortcutAction.nextItem => '제출 또는 다음 문제',
  StudyShortcutAction.showHint => '힌트',
  StudyShortcutAction.dontKnow => '모르겠어요',
  StudyShortcutAction.skip => '건너뛰기',
  StudyShortcutAction.pause => '일시정지',
};

String _globalActionLabel(GlobalShortcutAction value) => switch (value) {
  GlobalShortcutAction.openSearch => '전체 검색',
  GlobalShortcutAction.quickAdd => '빠른 추가',
  GlobalShortcutAction.keyboardHelp => '키보드 도움말',
  GlobalShortcutAction.focusContent => '본문으로 이동',
  GlobalShortcutAction.toggleCompactWindow => '작은 창으로 전환',
  GlobalShortcutAction.minimizeWindow => '창 최소화',
};
