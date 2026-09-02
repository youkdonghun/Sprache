import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/accessibility_input_profile.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/local_storage.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/settings_screen.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/theme/app_theme.dart';
import 'package:sprache/src/theme/study_accessibility_theme.dart';
import 'package:sprache/src/widgets/accessibility_input_profile_card.dart';

void main() {
  testWidgets('Android profile remains usable at 375px and 1.6x text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 900);
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.6;
    var profile = const AccessibilityInputProfile();

    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.mobileFor(
            const AppExperiencePreferences(),
            brightness: Brightness.light,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return AccessibilityInputProfileCard(
                    profile: profile,
                    isWindows: false,
                    isAndroid: true,
                    onChanged: (next) => setState(() => profile = next),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final keyName in [
        'accessibility-large-rating-controls',
        'accessibility-high-contrast',
        'accessibility-reduce-motion',
        'accessibility-reduce-transparency',
        'accessibility-disable-timed-challenges',
        'accessibility-card-scale-standard',
        'accessibility-card-scale-large',
        'accessibility-card-scale-extraLarge',
        'accessibility-android-gesture-buttonsOnly',
        'accessibility-android-gesture-tapAndButtons',
        'accessibility-android-gesture-swipeAndButtons',
      ]) {
        final finder = find.byKey(Key(keyName));
        expect(finder, findsOneWidget);
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(44), reason: keyName);
        expect(size.height, greaterThanOrEqualTo(44), reason: keyName);
      }

      await tester.ensureVisible(
        find.byKey(const Key('accessibility-high-contrast')),
      );
      await tester.tap(find.byKey(const Key('accessibility-high-contrast')));
      await tester.pump();
      expect(profile.highContrast, isTrue);

      await tester.ensureVisible(
        find.byKey(const Key('accessibility-android-gesture-swipeAndButtons')),
      );
      await tester.tap(
        find.byKey(const Key('accessibility-android-gesture-swipeAndButtons')),
      );
      await tester.pump();
      expect(
        profile.androidSelectionGesture,
        AndroidSelectionGesture.swipeAndButtons,
      );
      expect(profile.requiresVisibleSelectionControls, isTrue);
      expect(tester.takeException(), isNull);
    } finally {
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.reset();
    }
  });

  testWidgets('Settings exposes the device-local profile', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 800);
    final store = MemoryStudyStore(
      preferences: const StudyPreferences(onboardingCompleted: true),
      localStorageSettings: const LocalStorageSettings(
        accessibilityInputProfile: AccessibilityInputProfile(
          highContrast: true,
          largeRatingControls: true,
        ),
      ),
    );

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('settings-overview-display')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('accessibility-input-profile-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('accessibility-shortcut-revealAnswer')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });

  testWidgets('Windows remapping exposes global actions and conflict status', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1800);
    var profile = const AccessibilityInputProfile();

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => AccessibilityInputProfileCard(
                  profile: profile,
                  isWindows: true,
                  isAndroid: false,
                  onChanged: (value) => setState(() => profile = value),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('accessibility-shortcut-global-keyboardHelp')),
        findsOneWidget,
      );
      final dontKnow = find.byKey(const Key('accessibility-shortcut-dontKnow'));
      await tester.ensureVisible(dontKnow);
      await tester.tap(dontKnow);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ctrl+H').last);
      await tester.pumpAndSettle();

      expect(
        profile.shortcutFor(StudyShortcutAction.showHint),
        StudyShortcutKey.none,
      );
      expect(
        profile.shortcutFor(StudyShortcutAction.dontKnow),
        StudyShortcutKey.controlH,
      );
      expect(
        find.byKey(const Key('accessibility-shortcut-conflict')),
        findsOneWidget,
      );
      expect(find.textContaining('힌트 단축키가 중복'), findsOneWidget);
    } finally {
      tester.view.reset();
    }
  });

  test('high contrast theme publishes shared study tokens', () {
    const profile = AccessibilityInputProfile(
      highContrast: true,
      reduceMotion: true,
      reduceTransparency: true,
      largeRatingControls: true,
      cardScale: AccessibilityCardScale.extraLarge,
    );
    final regular = AppTheme.mobileFor(
      const AppExperiencePreferences(),
      brightness: Brightness.light,
    );
    final accessible = AppTheme.mobileFor(
      const AppExperiencePreferences(),
      brightness: Brightness.light,
      accessibilityProfile: profile,
    );
    final tokens = accessible.extension<StudyAccessibilityTheme>()!;

    expect(accessible.colorScheme.outline, isNot(regular.colorScheme.outline));
    expect(tokens.highContrast, isTrue);
    expect(tokens.reduceMotion, isTrue);
    expect(tokens.reduceTransparency, isTrue);
    expect(tokens.minimumRatingControlHeight, 64);
    expect(tokens.cardScaleFactor, 1.28);
    expect(tokens.visibleSelectionControls, isTrue);
    expect(accessible.cardTheme.elevation, 0);
    expect(accessible.snackBarTheme.behavior, SnackBarBehavior.fixed);
  });
}
