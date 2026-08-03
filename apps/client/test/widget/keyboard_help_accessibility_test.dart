import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/accessibility_input_profile.dart';
import 'package:sprache/src/theme/study_accessibility_theme.dart';
import 'package:sprache/src/widgets/focus_restoration.dart';
import 'package:sprache/src/widgets/keyboard_help_overlay.dart';

void main() {
  testWidgets('contextual keyboard help opens from remapped global shortcut', (
    tester,
  ) async {
    const profile = AccessibilityInputProfile();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => CallbackShortcuts(
            bindings: profile.globalBindingsFor({
              GlobalShortcutAction.keyboardHelp: () => showKeyboardHelpOverlay(
                context: context,
                profile: profile,
                helpContext: KeyboardHelpContext.study,
              ),
            }),
            child: const Focus(
              autofocus: true,
              child: Scaffold(body: Text('학습 화면')),
            ),
          ),
        ),
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('keyboard-help-overlay')), findsOneWidget);
    expect(find.text('퀴즈 단축키'), findsOneWidget);
    expect(find.text('힌트'), findsOneWidget);
    expect(find.text('Ctrl+H'), findsOneWidget);
    expect(find.text('키보드 도움말'), findsWidgets);
    expect(find.text('Ctrl+/'), findsOneWidget);
  });

  testWidgets(
    'dialog restores launcher focus and defines initial modal focus',
    (tester) async {
      final launcherFocus = FocusNode(debugLabel: 'test-launcher');
      addTearDown(launcherFocus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                key: const Key('focus-launcher'),
                focusNode: launcherFocus,
                onPressed: () => showFocusRestoringDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('초점 테스트'),
                    actions: [
                      FilledButton(
                        key: const Key('focus-dialog-close'),
                        autofocus: true,
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('닫기'),
                      ),
                    ],
                  ),
                ),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );

      launcherFocus.requestFocus();
      await tester.pump();
      expect(launcherFocus.hasFocus, isTrue);
      await tester.tap(find.byKey(const Key('focus-launcher')));
      await tester.pumpAndSettle();
      final closeButton = tester.widget<FilledButton>(
        find.byKey(const Key('focus-dialog-close')),
      );
      expect(closeButton.autofocus, isTrue);
      await tester.tap(find.byKey(const Key('focus-dialog-close')));
      await tester.pumpAndSettle();

      expect(launcherFocus.hasFocus, isTrue);
    },
  );

  testWidgets('help remains usable at 320px and 2x text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showKeyboardHelpOverlay(
                  context: context,
                  profile: const AccessibilityInputProfile(),
                  helpContext: KeyboardHelpContext.study,
                ),
                child: const Text('도움말'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('도움말'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('keyboard-help-overlay')), findsOneWidget);
      expect(find.byKey(const Key('close-keyboard-help')), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.reset();
    }
  });
}
