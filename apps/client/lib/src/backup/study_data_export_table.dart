import '../domain/import_distribution.dart';
import '../domain/language.dart';
import '../domain/learning_group.dart';
import '../domain/learning_item.dart';

class StudyDataExportTable {
  const StudyDataExportTable();

  static const headers = <String>[
    'language',
    'type',
    'term',
    'meaning',
    'group',
    'distribution_key',
    'pos',
    'accepted_answers',
    'kana',
    'romaji',
    'pinyin',
    'korean_pronunciation',
    'example',
    'example_translation',
    'sentence_tokens',
    'tags',
    'level',
    'priority',
    'source_name',
    'license',
    'source_version',
    'source_id',
    'source_url',
    'author',
    'attribution',
    'content_version',
    'id',
    'subject_id',
  ];

  List<List<String>> rows(Iterable<LearningItem> items) => [
    headers,
    for (final item in items) row(item),
  ];

  List<String> row(LearningItem item) {
    final groups = learningGroupsOf(item).toList()..sort();
    final tags =
        item.tags
            .where(
              (tag) =>
                  !tag.startsWith(learningGroupTagPrefix) &&
                  !tag.startsWith(importDistributionTagPrefix),
            )
            .toList()
          ..sort();
    return [
      item.learningLanguage.code,
      item.kind.name,
      item.text,
      item.translations.join('|'),
      groups.join('|'),
      importDistributionKeyOf(item) ?? '',
      item.partOfSpeech?.name ?? '',
      item.acceptedAnswers.join('|'),
      item.reading(ReadingScheme.kana) ?? '',
      item.reading(ReadingScheme.romaji) ?? '',
      item.reading(ReadingScheme.pinyin) ?? '',
      item.reading(ReadingScheme.hangul) ?? '',
      item.example ?? '',
      item.exampleTranslation ?? '',
      item.sentenceTokens.join('|'),
      tags.join('|'),
      item.level,
      item.priority.toString(),
      item.source.name,
      item.source.license,
      item.source.sourceVersion,
      item.source.sourceId ?? '',
      item.source.sourceUrl ?? '',
      item.source.author ?? '',
      item.source.attribution ?? '',
      item.source.contentVersion.toString(),
      item.id,
      item.effectiveSubjectId,
    ];
  }
}
