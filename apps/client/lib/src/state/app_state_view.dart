import 'app_state.dart';

extension AppStateDailyView on AppState {
  int activeCourseDailyXpAt(DateTime localDate) {
    final lastDate = lastStudyDate;
    if (lastDate != null &&
        (lastDate.year != localDate.year ||
            lastDate.month != localDate.month ||
            lastDate.day != localDate.day)) {
      return 0;
    }
    return activeCourseDailyXp;
  }
}
