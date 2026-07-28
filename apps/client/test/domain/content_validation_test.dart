import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/domain/content_validation.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';

void main() {
  const validator = LearningContentValidator();

  test('normalizes NFKC whitespace and removes duplicate answers', () {
    const item = LearningItem(
      id: ' custom-1 ',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: ' Ｈｅｌｌｏ   world ',
      translations: [' 인사  말 '],
      acceptedAnswers: ['인사 말', '  안녕  '],
    );

    final result = validator.inspect(item);

    expect(result.isValid, isTrue);
    expect(result.item.id, 'custom-1');
    expect(result.item.text, 'Hello world');
    expect(result.item.translations, ['인사 말']);
    expect(result.item.acceptedAnswers, ['인사 말', '안녕']);
  });

  test('rejects a reading scheme that does not belong to the language', () {
    const item = LearningItem(
      id: 'en-invalid-reading',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'water',
      translations: ['물'],
      acceptedAnswers: ['물'],
      readings: [Reading(scheme: ReadingScheme.pinyin, value: 'shuǐ')],
    );

    final result = validator.inspect(item);

    expect(result.isValid, isFalse);
    expect(
      result.errors.map((issue) => issue.code),
      contains('reading_scheme'),
    );
  });

  test(
    'rejects sentence-order tokens that do not reconstruct the sentence',
    () {
      const item = LearningItem(
        id: 'en-broken-sentence',
        kind: LearningItemKind.sentence,
        learningLanguage: LanguageTag.english,
        text: 'How are you?',
        translations: ['잘 지내세요?'],
        acceptedAnswers: ['잘 지내세요?'],
        sentenceTokens: ['How', 'is', 'you?'],
        capabilities: {
          ExerciseCapability.recognition,
          ExerciseCapability.sentenceOrder,
        },
      );

      final result = validator.inspect(item);

      expect(result.isValid, isFalse);
      expect(
        result.errors.map((issue) => issue.code),
        contains('sentence_tokens_mismatch'),
      );
    },
  );

  test('all bundled items pass structural content validation', () {
    final invalid = [
      for (final item in sampleContent)
        if (!validator.inspect(item).isValid)
          '${item.id}: ${validator.inspect(item).errors.map((issue) => issue.code).join(',')}',
    ];

    expect(sampleContent, hasLength(600));
    expect(invalid, isEmpty, reason: invalid.take(20).join('\n'));
  });

  test('word identity distinguishes the same spelling by part of speech', () {
    const noun = LearningItem(
      id: 'record-noun',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'record',
      translations: ['기록'],
      acceptedAnswers: ['기록'],
      partOfSpeech: PartOfSpeech.noun,
    );
    const verb = LearningItem(
      id: 'record-verb',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'record',
      translations: ['기록'],
      acceptedAnswers: ['기록'],
      partOfSpeech: PartOfSpeech.verb,
    );

    expect(validator.duplicateKey(noun), isNot(validator.duplicateKey(verb)));
  });

  test('rejects part of speech on sentences and invalid content versions', () {
    const item = LearningItem(
      id: 'invalid-metadata',
      kind: LearningItemKind.sentence,
      learningLanguage: LanguageTag.english,
      text: 'I keep a record.',
      translations: ['저는 기록을 남겨요.'],
      acceptedAnswers: ['저는 기록을 남겨요.'],
      partOfSpeech: PartOfSpeech.noun,
      source: ContentSource(
        name: 'Notebook',
        license: 'private',
        sourceVersion: '1',
        contentVersion: 0,
      ),
    );

    final issues = validator.inspect(item).errors.map((issue) => issue.code);

    expect(issues, contains('sentence_part_of_speech'));
    expect(issues, contains('content_version_range'));
  });

  test('bundled catalog has explicit provenance and word classifications', () {
    expect(
      sampleContent.every(
        (item) =>
            item.source.name == ContentSource.starterCatalog.name &&
            item.source.license == 'project-internal' &&
            item.source.contentVersion == 1,
      ),
      isTrue,
    );
    expect(
      sampleContent
          .where((item) => item.kind == LearningItemKind.word)
          .every((item) => item.partOfSpeech != null),
      isTrue,
    );
  });
}
