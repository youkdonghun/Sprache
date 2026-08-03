abstract final class StudyLimits {
  static const minSessionItems = 1;
  static const maxSessionItems = 1000;
  static const maxAttemptsPerItem = 3;
  static const maxActiveQueueEntries = maxSessionItems * maxAttemptsPerItem;
}
