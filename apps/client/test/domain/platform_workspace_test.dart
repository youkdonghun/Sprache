import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/accessibility_input_profile.dart';
import 'package:sprache/src/domain/platform_workspace.dart';
import 'package:sprache/src/theme/study_accessibility_theme.dart';

void main() {
  test('command shortcuts use Meta on macOS and Control on Windows', () {
    final mac = StudyShortcutKey.controlK.activatorFor(TargetPlatform.macOS)!;
    final windows = StudyShortcutKey.controlK.activatorFor(
      TargetPlatform.windows,
    )!;

    expect(mac.meta, isTrue);
    expect(mac.control, isFalse);
    expect(windows.control, isTrue);
    expect(windows.meta, isFalse);
    expect(
      StudyShortcutKey.controlK.displayLabelFor(TargetPlatform.macOS),
      '⌘+K',
    );
  });

  test('adaptive two-pane respects tablets and narrow desktop windows', () {
    expect(
      usesAdaptiveTwoPane(platform: TargetPlatform.android, width: 759),
      isFalse,
    );
    expect(
      usesAdaptiveTwoPane(platform: TargetPlatform.android, width: 760),
      isTrue,
    );
    expect(
      usesAdaptiveTwoPane(platform: TargetPlatform.iOS, width: 820),
      isTrue,
    );
    expect(
      usesAdaptiveTwoPane(platform: TargetPlatform.macOS, width: 720),
      isTrue,
    );
    expect(
      usesAdaptiveTwoPane(platform: TargetPlatform.windows, width: 719),
      isFalse,
    );
  });

  test('range selection follows visual order and handles stale anchors', () {
    expect(
      inclusiveSelectionRange(
        orderedIds: const ['a', 'b', 'c', 'd'],
        anchorId: 'd',
        currentId: 'b',
      ),
      {'b', 'c', 'd'},
    );
    expect(
      inclusiveSelectionRange(
        orderedIds: const ['a', 'b'],
        anchorId: 'missing',
        currentId: 'b',
      ),
      {'b'},
    );
  });

  test('completion actions are platform appropriate', () {
    expect(completionActionsFor(TargetPlatform.android), [
      PlatformCompletionAction.share,
      PlatformCompletionAction.openFile,
    ]);
    expect(completionActionsFor(TargetPlatform.windows), [
      PlatformCompletionAction.openFolder,
      PlatformCompletionAction.copyPath,
    ]);
  });
}
