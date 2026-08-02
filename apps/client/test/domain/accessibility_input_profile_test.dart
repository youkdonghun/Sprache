import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/accessibility_input_profile.dart';
import 'package:sprache/src/domain/local_storage.dart';

void main() {
  group('AccessibilityInputProfile', () {
    test('round-trips through device-local storage JSON', () {
      final profile = const AccessibilityInputProfile(
        largeRatingControls: true,
        cardScale: AccessibilityCardScale.extraLarge,
        highContrast: true,
        reduceMotion: true,
        reduceTransparency: true,
        disableTimedChallenges: true,
        androidSelectionGesture: AndroidSelectionGesture.swipeAndButtons,
      ).remapShortcut(StudyShortcutAction.playAudio, StudyShortcutKey.keyA);
      final settings = LocalStorageSettings(
        locationId: 'device-folder',
        displayName: 'Sprache',
        accessibilityInputProfile: profile,
      );

      final restored = LocalStorageSettings.fromJson(settings.toJson());
      final actual = restored.accessibilityInputProfile;

      expect(actual.largeRatingControls, isTrue);
      expect(actual.cardScale, AccessibilityCardScale.extraLarge);
      expect(actual.cardScaleFactor, 1.28);
      expect(actual.highContrast, isTrue);
      expect(actual.reduceMotion, isTrue);
      expect(actual.reduceTransparency, isTrue);
      expect(actual.disableTimedChallenges, isTrue);
      expect(actual.allowsTimedChallenges, isFalse);
      expect(
        actual.androidSelectionGesture,
        AndroidSelectionGesture.swipeAndButtons,
      );
      expect(
        actual.shortcutFor(StudyShortcutAction.playAudio),
        StudyShortcutKey.keyA,
      );
      expect(actual.requiresVisibleSelectionControls, isTrue);
    });

    test('legacy and malformed data retain safe accessible defaults', () {
      final legacy = LocalStorageSettings.fromJson(const {});
      final malformed = AccessibilityInputProfile.fromJson({
        'largeRatingControls': 'yes',
        'cardScale': 'huge',
        'highContrast': 1,
        'reduceMotion': null,
        'androidSelectionGesture': 'gestureOnly',
        'windowsShortcuts': {'revealAnswer': 'space', 'playAudio': 'space'},
      });

      expect(
        legacy.accessibilityInputProfile.cardScale,
        AccessibilityCardScale.standard,
      );
      expect(malformed.largeRatingControls, isFalse);
      expect(malformed.highContrast, isFalse);
      expect(malformed.reduceMotion, isFalse);
      expect(
        malformed.androidSelectionGesture,
        AndroidSelectionGesture.tapAndButtons,
      );
      expect(
        malformed.shortcutFor(StudyShortcutAction.revealAnswer),
        StudyShortcutKey.space,
      );
      expect(
        malformed.shortcutFor(StudyShortcutAction.playAudio),
        StudyShortcutKey.none,
        reason: 'duplicate keys must never trigger two actions',
      );
    });

    test('remapping removes conflicts without removing visible controls', () {
      final remapped = const AccessibilityInputProfile().remapShortcut(
        StudyShortcutAction.nextItem,
        StudyShortcutKey.space,
      );

      expect(
        remapped.shortcutFor(StudyShortcutAction.nextItem),
        StudyShortcutKey.space,
      );
      expect(
        remapped.shortcutFor(StudyShortcutAction.revealAnswer),
        StudyShortcutKey.none,
      );
      expect(remapped.requiresVisibleSelectionControls, isTrue);
      expect(remapped.minimumRatingControlHeight, 48);
    });

    test('reports displaced study and global shortcut conflicts', () {
      final studyResult = const AccessibilityInputProfile().remapStudyShortcut(
        StudyShortcutAction.dontKnow,
        StudyShortcutKey.controlH,
      );
      final globalResult = studyResult.profile.remapGlobalShortcut(
        GlobalShortcutAction.quickAdd,
        StudyShortcutKey.controlK,
      );

      expect(studyResult.displacedAction, StudyShortcutAction.showHint);
      expect(
        studyResult.profile.shortcutFor(StudyShortcutAction.showHint),
        StudyShortcutKey.none,
      );
      expect(globalResult.displacedAction, GlobalShortcutAction.openSearch);
      expect(
        globalResult.profile.globalShortcutFor(GlobalShortcutAction.openSearch),
        StudyShortcutKey.none,
      );
      expect(
        globalResult.profile.globalShortcutFor(GlobalShortcutAction.quickAdd),
        StudyShortcutKey.controlK,
      );
    });

    test('legacy JSON receives the new accessible shortcut defaults', () {
      final profile = AccessibilityInputProfile.fromJson(const {});

      expect(
        profile.shortcutFor(StudyShortcutAction.showHint),
        StudyShortcutKey.controlH,
      );
      expect(
        profile.shortcutFor(StudyShortcutAction.pause),
        StudyShortcutKey.escape,
      );
      expect(
        profile.globalShortcutFor(GlobalShortcutAction.keyboardHelp),
        StudyShortcutKey.controlSlash,
      );
    });
  });
}
