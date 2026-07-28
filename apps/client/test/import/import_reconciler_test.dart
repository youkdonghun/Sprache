import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/import/import_reconciler.dart';

void main() {
  const reconciler = ImportReconciler();

  test('classifies new, unchanged, changed, and blocked entries', () {
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
      ImportReviewStatus.blocked,
    ]);
    expect(review.entries[2].differences.map((value) => value.field), [
      'translations',
      'acceptedAnswers',
    ]);
    expect(review.entries[3].blockReason, contains('기본 콘텐츠'));
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
}
