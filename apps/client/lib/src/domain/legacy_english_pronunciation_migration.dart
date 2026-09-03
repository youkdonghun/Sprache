import 'language.dart';
import 'learning_item.dart';

/// Result of removing untrusted Hangul readings from managed English packs.
class LegacyEnglishPronunciationMigration {
  const LegacyEnglishPronunciationMigration({
    required this.items,
    required this.changedItems,
  });

  final List<LearningItem> items;
  final List<LearningItem> changedItems;

  bool get changed => changedItems.isNotEmpty;
}

const _languagePackSourcePrefix = 'language-pack:';

/// Removes every Hangul reading supplied by a managed English language pack.
///
/// English spelling is not phonetic, so a pack version or sync timestamp is
/// not enough evidence that a Korean transcription is correct. Direct user
/// entries are outside this rule and remain untouched.
LegacyEnglishPronunciationMigration migrateLegacyEnglishPronunciations(
  Iterable<LearningItem> source,
) {
  final items = <LearningItem>[];
  final changedItems = <LearningItem>[];
  for (final item in source) {
    final migrated = _migrateItem(item);
    items.add(migrated);
    if (!identical(migrated, item)) changedItems.add(migrated);
  }
  return LegacyEnglishPronunciationMigration(
    items: List.unmodifiable(items),
    changedItems: List.unmodifiable(changedItems),
  );
}

LearningItem _migrateItem(LearningItem item) {
  final sourceId = item.source.sourceId?.trim().toLowerCase() ?? '';
  final taggedAsLanguagePack = item.tags.any(
    (tag) => tag.trim().toLowerCase().startsWith(_languagePackSourcePrefix),
  );
  final isManagedEnglishPack =
      item.learningLanguage == LanguageTag.english &&
      (sourceId.startsWith(_languagePackSourcePrefix) || taggedAsLanguagePack);
  if (!isManagedEnglishPack ||
      !item.readings.any((reading) => reading.scheme == ReadingScheme.hangul)) {
    return item;
  }
  return item.copyWith(
    readings: List.unmodifiable(
      item.readings.where((reading) => reading.scheme != ReadingScheme.hangul),
    ),
    source: item.source.copyWith(
      contentVersion: item.source.contentVersion + 1,
    ),
  );
}
