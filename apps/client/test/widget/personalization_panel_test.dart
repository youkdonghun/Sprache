import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/screens/personalization_screen.dart';

void main() {
  late AppExperiencePreferences preferences;

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(980, 4000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PersonalizationPanel(
              preferences: preferences,
              subjectId: 'language:en',
              subjectName: '영어',
              onChanged: (value) => setState(() => preferences = value),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> collapseTheme(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('personalization-theme-section')));
    await tester.pumpAndSettle();
  }

  Future<void> openSection(WidgetTester tester, String keyName) async {
    final section = find.byKey(Key(keyName));
    await tester.ensureVisible(section);
    await tester.tap(section);
    await tester.pumpAndSettle();
  }

  Future<void> tapControl(WidgetTester tester, String keyName) async {
    final control = find.byKey(Key(keyName));
    await tester.ensureVisible(control);
    await tester.tap(control);
    await tester.pumpAndSettle();
  }

  setUp(() {
    preferences = const AppExperiencePreferences();
  });

  testWidgets('live preview and one-touch presets keep non-visual defaults', (
    tester,
  ) async {
    preferences = const AppExperiencePreferences(
      quickAddFavoriteDefault: true,
      showStreak: true,
    );
    await pumpPanel(tester);

    final preview = find.byKey(const Key('personalization-live-preview'));
    expect(preview, findsOneWidget);
    expect(
      find.descendant(of: preview, matching: find.byType(Chip)),
      findsOneWidget,
    );
    for (final name in ['sprache', 'focus', 'paper', 'oledNight']) {
      expect(find.byKey(Key('personalization-preset-$name')), findsOneWidget);
    }

    await tester.tap(find.byKey(const Key('personalization-preset-oledNight')));
    await tester.pumpAndSettle();

    expect(preferences.colorMode, AppColorMode.oled);
    expect(preferences.accentPalette, AppAccentPalette.mono);
    expect(preferences.motionLevel, AppMotionLevel.off);
    expect(preferences.quickAddFavoriteDefault, isTrue);
    expect(preferences.showStreak, isTrue);
  });

  testWidgets('home visibility, ordering, reset, and preview update together', (
    tester,
  ) async {
    await pumpPanel(tester);
    await collapseTheme(tester);
    await openSection(tester, 'personalization-home-section');

    await tapControl(tester, 'home-show-header');
    await tapControl(tester, 'home-show-xp');
    await tapControl(tester, 'home-show-streak');
    await tapControl(tester, 'home-section-visible-pinnedCollections');
    await tapControl(tester, 'home-section-down-pinnedCollections');

    expect(preferences.showHomeHeader, isFalse);
    expect(preferences.showXp, isFalse);
    expect(preferences.showStreak, isFalse);
    expect(preferences.showPinnedCollections, isFalse);
    expect(preferences.homeSectionOrder.take(2), const [
      AppHomeSection.recentAdditions,
      AppHomeSection.pinnedCollections,
    ]);

    await tester.fling(
      find.byKey(const Key('personalization-panel')),
      const Offset(0, 5000),
      3000,
    );
    await tester.pumpAndSettle();
    final preview = find.byKey(const Key('personalization-live-preview'));
    expect(preview, findsOneWidget);
    expect(
      find.descendant(of: preview, matching: find.byType(Chip)),
      findsNothing,
    );

    await tester.fling(
      find.byKey(const Key('personalization-panel')),
      const Offset(0, -5000),
      3000,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('reset-home-personalization')),
    );
    await tester.tap(find.byKey(const Key('reset-home-personalization')));
    await tester.pumpAndSettle();

    expect(preferences.showHomeHeader, isTrue);
    expect(preferences.showXp, isTrue);
    expect(preferences.showStreak, isTrue);
    expect(preferences.showPinnedCollections, isTrue);
    expect(preferences.homeSectionOrder, AppHomeSection.values);
  });

  testWidgets('quick-add controls deliver complete preference callbacks', (
    tester,
  ) async {
    await pumpPanel(tester);
    await collapseTheme(tester);
    await openSection(tester, 'personalization-quick-add-section');

    await tapControl(tester, 'personalization-AppQuickAddKind-sentence');
    await tapControl(tester, 'quick-default-details');
    await tapControl(tester, 'quick-default-favorite');
    await tapControl(tester, 'quick-auto-normalize');
    await tapControl(tester, 'quick-default-keep-adding');
    await tapControl(tester, 'quick-remember-tags');

    final prioritySlider = tester.widget<Slider>(
      find.descendant(
        of: find.byKey(const Key('quick-default-priority')),
        matching: find.byType(Slider),
      ),
    );
    prioritySlider.onChanged!(4);
    await tester.pump();

    final delaySlider = tester.widget<Slider>(
      find.descendant(
        of: find.byKey(const Key('quick-draft-delay')),
        matching: find.byType(Slider),
      ),
    );
    delaySlider.onChanged!(1200);
    await tester.pump();

    expect(find.text('느리게 · 1.2초'), findsOneWidget);

    expect(preferences.quickAddKind, AppQuickAddKind.sentence);
    expect(preferences.quickAddOpenDetails, isTrue);
    expect(preferences.quickAddFavoriteDefault, isTrue);
    expect(preferences.quickAddAutoNormalize, isTrue);
    expect(preferences.quickAddKeepAddingDefault, isTrue);
    expect(preferences.quickAddRememberTags, isTrue);
    expect(preferences.quickAddPriorityDefault, 4);
    expect(preferences.quickAddDraftDelayMs, 1200);
  });
}
