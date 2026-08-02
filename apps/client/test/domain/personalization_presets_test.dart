import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/personalization_presets.dart';

void main() {
  test('theme presets only replace visual preferences', () {
    const original = AppExperiencePreferences(
      showRecentAdditions: false,
      quickAddFavoriteDefault: true,
      quickAddPriorityDefault: 4,
    );

    final focused = PersonalizationPreset.focus.applyTo(original);

    expect(focused.accentPalette, AppAccentPalette.ocean);
    expect(focused.contentWidth, AppContentWidth.focused);
    expect(focused.motionLevel, AppMotionLevel.reduced);
    expect(focused.showRecentAdditions, isFalse);
    expect(focused.quickAddFavoriteDefault, isTrue);
    expect(focused.quickAddPriorityDefault, 4);
  });

  test('OLED preset chooses black-screen compatible settings', () {
    final oled = PersonalizationPreset.oledNight.applyTo(
      const AppExperiencePreferences(),
    );

    expect(oled.colorMode, AppColorMode.oled);
    expect(oled.accentPalette, AppAccentPalette.mono);
    expect(oled.cardStyle, AppCardStyle.flat);
    expect(oled.motionLevel, AppMotionLevel.off);
    expect(oled.celebrationLevel, AppCelebrationLevel.off);
    expect(oled.highContrast, isTrue);
  });
}
