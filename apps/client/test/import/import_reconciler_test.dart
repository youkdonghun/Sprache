import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/import/import_reconciler.dart';

void main() {
  const reconciler = ImportReconciler();

  test('classifies new, unchanged, changed, and bundled meaning merges', () {
    const custom = LearningItem(
      id: 'custom-water',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'water',
      translations: ['물'],
      acceptedAnswers: ['물'],
      partOfSpeech: PartOfSpeech.noun,
    );
    const bundled = LearningItem(
      id: 'bundled-coffee',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'coffee',
      translations: ['커피'],
      acceptedAnswers: ['커피'],
      partOfSpeech: PartOfSpeech.noun,
      source: ContentSource.starterCatalog,
    );
    const preview = ImportPreview(
      entries: [
        ParsedImportEntry(
          row: 2,
          item: LearningItem(
            id: 'new-tea',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.english,
            text: 'tea',
            translations: ['차'],
            acceptedAnswers: ['차'],
            partOfSpeech: PartOfSpeech.noun,
          ),
        ),
        ParsedImportEntry(
          row: 3,
          item: LearningItem(
            id: 'foreign-water',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.english,
            text: 'water',
            translations: ['물'],
            acceptedAnswers: ['물'],
            partOfSpeech: PartOfSpeech.noun,
            source: ContentSource(
              name: '사용자 직접 입력',
              license: 'private',
              sourceVersion: '1',
              contentVersion: 99,
            ),
          ),
        ),
        ParsedImportEntry(
          row: 4,
          item: LearningItem(
            id: 'custom-water',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.english,
            text: 'water',
            translations: ['물', '물결'],
            acceptedAnswers: ['물', '물결'],
            partOfSpeech: PartOfSpeech.noun,
          ),
        ),
        ParsedImportEntry(
          row: 5,
          item: LearningItem(
            id: 'bundled-coffee',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.english,
            text: 'coffee',
            translations: ['커피'],
            acceptedAnswers: ['커피', '커피 한 잔'],
            partOfSpeech: PartOfSpeech.noun,
          ),
        ),
      ],
      issues: [],
      duplicates: [],
    );

    final review = reconciler.review(
      preview: preview,
      existingItems: const [custom, bundled],
      replaceableItemIds: const {'custom-water'},
    );

    expect(review.entries.map((entry) => entry.status), [
      ImportReviewStatus.newItem,
      ImportReviewStatus.unchanged,
      ImportReviewStatus.changed,
      ImportReviewStatus.changed,
    ]);
    expect(review.entries[2].differences.map((value) => value.field), [
      'translations',
      'acceptedAnswers',
    ]);
    expect(review.entries[3].mergeOnly, isTrue);
    expect(review.entries[3].defaultAction, ImportReviewAction.replace);
    expect(review.entries[3].incoming.acceptedAnswers, contains('커피 한 잔'));
  });

  test('blocks an ID match that points at another semantic item', () {
    const first = LearningItem(
      id: 'first',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'alpha',
      translations: ['알파'],
      acceptedAnswers: ['알파'],
      partOfSpeech: PartOfSpeech.noun,
    );
    const second = LearningItem(
      id: 'second',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'beta',
      translations: ['베타'],
      acceptedAnswers: ['베타'],
      partOfSpeech: PartOfSpeech.noun,
    );
    const preview = ImportPreview(
      entries: [
        ParsedImportEntry(
          row: 1,
          item: LearningItem(
            id: 'first',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.english,
            text: 'beta',
            translations: ['베타'],
            acceptedAnswers: ['베타'],
            partOfSpeech: PartOfSpeech.noun,
          ),
        ),
      ],
      issues: [],
      duplicates: [],
    );

    final entry = reconciler
        .review(
          preview: preview,
          existingItems: const [first, second],
          replaceableItemIds: const {'first', 'second'},
        )
        .entries
        .single;

    expect(entry.status, ImportReviewStatus.blocked);
    expect(
      entry.resolve(ImportReviewAction.replace).action,
      ImportReviewAction.skip,
    );
  });

  test('treats a stable-id pack revision as a replaceable update', () {
    const current = LearningItem(
      id: 'pack-word-1',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'beef',
      translations: ['쇠고기'],
      acceptedAnswers: ['쇠고기'],
      readings: [Reading(scheme: ReadingScheme.hangul, value: '비')],
      source: ContentSource(
        name: '영어 생활 핵심 어휘',
        license: 'CC-BY-4.0',
        sourceVersion: '2026.09.1',
        contentVersion: 1,
      ),
    );
    const incoming = LearningItem(
      id: 'pack-word-1',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'beef',
      translations: ['쇠고기'],
      acceptedAnswers: ['쇠고기'],
      readings: [Reading(scheme: ReadingScheme.hangul, value: '비프')],
      source: ContentSource(
        name: '영어 생활 핵심 어휘',
        license: 'CC-BY-4.0',
        sourceVersion: '2026.09.2',
        contentVersion: 2,
      ),
    );
    const preview = ImportPreview(
      entries: [ParsedImportEntry(row: 1, item: incoming)],
      issues: [],
      duplicates: [],
    );

    final entry = reconciler
        .review(
          preview: preview,
          existingItems: const [current],
          replaceableItemIds: const {'pack-word-1'},
        )
        .entries
        .single;

    expect(entry.status, ImportReviewStatus.changed);
    expect(entry.mergeOnly, isFalse);
    expect(entry.incoming.reading(ReadingScheme.hangul), '비프');
    expect(entry.incoming.source.sourceVersion, '2026.09.2');
  });
}
