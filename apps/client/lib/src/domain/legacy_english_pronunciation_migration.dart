import 'language.dart';
import 'learning_item.dart';

/// Result of removing Hangul readings generated from English spelling by the
/// legacy 2026.09.1 language-pack importer.
class LegacyEnglishPronunciationMigration {
  const LegacyEnglishPronunciationMigration({
    required this.items,
    required this.changedItems,
  });

  final List<LearningItem> items;
  final List<LearningItem> changedItems;

  bool get changed => changedItems.isNotEmpty;
}

const _affectedEnglishPackSourceIds = <String>{
  'language-pack:sprache-en-tufs-core-2026-09',
  'language-pack:sprache-en-toeic-service-core-2026-09',
  'language-pack:sprache-en-toss-speaking-core-2026-09',
};

/// Removes only unedited readings from the affected first-generation packs.
///
/// Version 1 generated Hangul directly from English spelling. A user edit
/// increments [ContentSource.contentVersion], so version 2 or newer is left
/// untouched. The current 2026.09.2 packs are also left intact, including the
/// explicitly reviewed `beef → 비프` aid.
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
  final isAffected =
      item.learningLanguage == LanguageTag.english &&
      _affectedEnglishPackSourceIds.contains(item.source.sourceId) &&
      item.source.sourceVersion == '2026.09.1' &&
      item.source.contentVersion <= 1;
  if (!isAffected ||
      !item.readings.any((reading) => reading.scheme == ReadingScheme.hangul)) {
    return item;
  }
  return item.copyWith(
    readings: List.unmodifiable(
      item.readings.where((reading) => reading.scheme != ReadingScheme.hangul),
    ),
    source: item.source.copyWith(contentVersion: 2),
  );
}
