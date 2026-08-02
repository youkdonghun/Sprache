import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/screens/personalization_screen.dart';

void main() {
  late AppExperiencePreferences preferences;

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 5200);
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

  Future<void> tapByKey(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapChoice(
    WidgetTester tester,
    String groupKey,
    String label,
  ) async {
    final labelFinder = find.descendant(
      of: find.byKey(Key(groupKey)),
      matching: find.text(label),
    );
    final finder = find.ancestor(
      of: labelFinder,
      matching: find.byType(ChoiceChip),
    );
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  setUp(() => preferences = const AppExperiencePreferences());

  testWidgets('theme expansion controls are directly operable and persistent', (
    tester,
  ) async {
    await pumpPanel(tester);

    await tapByKey(tester, 'theme-separate-accents');
    await tapChoice(tester, 'theme-light-accent-group', '선라이즈');
    await tapChoice(tester, 'theme-dark-accent-group', '민트');
    expect(preferences.separateBrightnessAccents, isTrue);
    expect(preferences.lightAccentPalette, AppAccentPalette.sunrise);
    expect(preferences.darkAccentPalette, AppAccentPalette.mint);

    await tapByKey(tester, 'theme-custom-accent-enabled');
    final hexField = find.byKey(const Key('theme-custom-accent-hex'));
    await tester.ensureVisible(hexField);
    await tester.enterText(hexField, 'FFFFFF');
    await tester.pumpAndSettle();
    expect(preferences.customAccentEnabled, isTrue);
    expect(preferences.customAccentRgb, 0xFFFFFF);

    await tapChoice(tester, 'theme-schedule-group', '직접 지정');
    final darkSlider = tester.widget<Slider>(
      find.descendant(
        of: find.byKey(const Key('theme-dark-start-hour')),
        matching: find.byType(Slider),
      ),
    );
    darkSlider.onChanged!(22);
    await tester.pump();
    final lightSlider = tester.widget<Slider>(
      find.descendant(
        of: find.byKey(const Key('theme-light-start-hour')),
        matching: find.byType(Slider),
      ),
    );
    lightSlider.onChanged!(5);
    await tester.pump();
    expect(preferences.themeScheduleMode, AppThemeScheduleMode.custom);
    expect(preferences.themeDarkStartHour, 22);
    expect(preferences.themeLightStartHour, 5);
    expect(find.byKey(const Key('theme-schedule-preview')), findsOneWidget);

    await tapChoice(tester, 'theme-font-family-group', '시스템 산세리프');
    expect(preferences.fontFamily, AppFontFamily.system);
    await tapChoice(tester, 'theme-font-family-group', '플랫폼 세리프');
    expect(preferences.fontFamily, AppFontFamily.serif);
    await tapChoice(tester, 'theme-font-family-group', '고정폭');
    await tapChoice(tester, 'theme-study-text-scale-group', '30% 크게');
    await tapChoice(tester, 'theme-card-alignment-group', '왼쪽 정렬');
    await tapChoice(tester, 'theme-decoration-group', '생동감');
    expect(preferences.fontFamily, AppFontFamily.monospace);
    expect(preferences.studyTextScale, AppStudyTextScale.extraLarge);
    expect(preferences.cardAlignment, AppCardAlignment.leading);
    expect(preferences.decorationIntensity, AppDecorationIntensity.vivid);
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation icon style and theme profiles support management', (
    tester,
  ) async {
    await pumpPanel(tester);

    final nameField = find.byKey(const Key('theme-profile-name'));
    await tester.ensureVisible(nameField);
    await tester.enterText(nameField, '야간 집중');
    await tapByKey(tester, 'save-theme-profile');
    expect(preferences.themeProfiles, hasLength(1));
    expect(preferences.activeThemeProfileId, isNotNull);

    await tapByKey(tester, 'theme-separate-accents');
    expect(preferences.separateBrightnessAccents, isTrue);
    expect(preferences.activeThemeProfileId, isNull);

    final savedProfile = find.text('야간 집중');
    await tester.ensureVisible(savedProfile);
    await tester.tap(savedProfile);
    await tester.pumpAndSettle();
    expect(preferences.separateBrightnessAccents, isFalse);
    expect(
      preferences.activeThemeProfileId,
      preferences.themeProfiles.single.id,
    );

    await tapByKey(tester, 'personalization-theme-section');
    final navSection = find.byKey(
      const Key('personalization-navigation-section'),
    );
    await tester.ensureVisible(navSection);
    await tester.tap(navSection);
    await tester.pumpAndSettle();
    await tapChoice(tester, 'navigation-icon-style-group', '윤곽선');
    expect(preferences.navigationIconStyle, AppNavigationIconStyle.outlined);

    final originalId = preferences.themeProfiles.single.id;
    await tapByKey(tester, 'theme-profile-menu-$originalId');
    await tester.tap(find.text('이름 변경'));
    await tester.pumpAndSettle();
    final renameField = find.byKey(const Key('rename-theme-profile-name'));
    await tester.enterText(renameField, '밤 집중');
    await tapByKey(tester, 'confirm-rename-theme-profile');
    expect(preferences.themeProfiles.single.name, '밤 집중');

    await tapByKey(tester, 'theme-profile-menu-$originalId');
    await tester.tap(find.text('복제'));
    await tester.pumpAndSettle();
    expect(preferences.themeProfiles, hasLength(2));
    final duplicateId = preferences.themeProfiles.last.id;
    expect(preferences.themeProfiles.last.name, '밤 집중 복사본');

    await tapByKey(tester, 'move-up-theme-profile-$duplicateId');
    expect(preferences.themeProfiles.first.id, duplicateId);

    await tapByKey(tester, 'theme-profile-menu-$originalId');
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(preferences.themeProfiles, hasLength(1));
    expect(preferences.activeThemeProfileId, isNull);

    await tapByKey(tester, 'theme-profile-menu-$duplicateId');
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(preferences.themeProfiles, isEmpty);
    expect(preferences.activeThemeProfileId, isNull);
    expect(tester.takeException(), isNull);
  });
}
