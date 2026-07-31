import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/app_state_view.dart';

void main() {
  test('daily XP is hidden after the local calendar day changes', () {
    final state = AppState.initial().copyWith(
      selectedLanguage: LanguageTag.english,
      dailyXp: 30,
      dailyXpByCourse: const {'ko-en': 30},
      lastStudyDate: DateTime(2026, 7, 30, 23, 55),
    );

    expect(state.activeCourseDailyXpAt(DateTime(2026, 7, 30, 23, 59)), 30);
    expect(state.activeCourseDailyXpAt(DateTime(2026, 7, 31, 0, 1)), 0);
  });

  test('legacy profiles without a study date preserve their visible XP', () {
    final state = AppState.initial().copyWith(
      dailyXp: 10,
      dailyXpByCourse: const {'ko-en': 10},
    );

    expect(state.activeCourseDailyXpAt(DateTime(2026, 7, 31)), 10);
  });
}
