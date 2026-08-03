class DailyPracticeQuest {
  const DailyPracticeQuest({required this.slot, required this.activityId});

  final int slot;
  final String activityId;
}

List<DailyPracticeQuest> buildDailyPracticeQuests({
  required DateTime day,
  required String subjectId,
  required Iterable<String> activityIds,
  int questCount = 3,
}) {
  if (questCount <= 0) return const [];
  final candidates =
      activityIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false)
        ..sort();
  if (candidates.isEmpty) return const [];

  final localDay = day.toLocal();
  final seed =
      '${localDay.year}-${localDay.month}-${localDay.day}|'
      '${subjectId.trim()}|${candidates.join('|')}';
  final start = _stableQuestHash(seed) % candidates.length;
  final take = questCount.clamp(0, candidates.length);
  return List.generate(
    take,
    (slot) => DailyPracticeQuest(
      slot: slot,
      activityId: candidates[(start + slot) % candidates.length],
    ),
    growable: false,
  );
}

int _stableQuestHash(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}
