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

  test('accepts standard kana, romaji, pinyin, and Hangul formats', () {
    expect(inspectReadingFormat(ReadingScheme.kana, 'コーヒーを おねがいします。'), isNull);
    expect(inspectReadingFormat(ReadingScheme.kana, 'べんきょう?'), isNull);
    expect(
      inspectReadingFormat(ReadingScheme.romaji, "Tōkyō e ikimasu."),
      isNull,
    );
    expect(
      inspectReadingFormat(ReadingScheme.pinyin, "Xi'an hěn hǎo."),
      isNull,
    );
    expect(
      inspectReadingFormat(ReadingScheme.pinyin, 'xi1 an1 hen3 hao3'),
      isNull,
    );
    expect(inspectReadingFormat(ReadingScheme.hangul, '니 하오 · 헬로우'), isNull);
  });

  test('rejects scripts and malformed tones in reading helpers', () {
    expect(
      inspectReadingFormat(ReadingScheme.kana, '水 みず')?.code,
      'kana_format',
    );
    expect(
      inspectReadingFormat(ReadingScheme.romaji, 'みず')?.code,
      'romaji_format',
    );
    expect(
      inspectReadingFormat(ReadingScheme.pinyin, '水 shuǐ')?.code,
      'pinyin_format',
    );
    expect(
      inspectReadingFormat(ReadingScheme.pinyin, 'shuǐ3')?.code,
      'pinyin_mixed_tone',
    );
    expect(
      inspectReadingFormat(ReadingScheme.pinyin, 'ni3hao3')?.code,
      'pinyin_tone_number',
    );
    expect(inspectReadingFormat(ReadingScheme.pinyin, 'lu:4')?.code, isNull);
    expect(
      inspectReadingFormat(ReadingScheme.hangul, 'hello 헬로우')?.code,
      'hangul_reading_format',
    );
  });

  test('supports Korean pronunciation readings for every target language', () {
    for (final language in LanguageTag.values.where(
      (value) => value.available,
    )) {
      final result = validator.inspect(
        LearningItem(
          id: '${language.code}-hangul-reading',
          kind: LearningItemKind.word,
          learningLanguage: language,
          text: 'sample',
          translations: const ['예시'],
          acceptedAnswers: const ['예시'],
          readings: const [Reading(scheme: ReadingScheme.hangul, value: '샘플')],
        ),
      );

      expect(result.isValid, isTrue, reason: language.code);
    }
  });

  test('reading format errors block invalid learning items', () {
    const item = LearningItem(
      id: 'ja-invalid-kana',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.japanese,
      text: '水',
      translations: ['물'],
      acceptedAnswers: ['물'],
      readings: [
        Reading(scheme: ReadingScheme.kana, value: 'mizu'),
        Reading(scheme: ReadingScheme.romaji, value: 'みず'),
      ],
    );

    final errors = validator.inspect(item).errors.map((issue) => issue.code);

    expect(errors, containsAll(['kana_format', 'romaji_format']));
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

  test(
    'rejects incomplete explicit tokens even without token capabilities',
    () {
      const item = LearningItem(
        id: 'en-incomplete-explicit-tokens',
        kind: LearningItemKind.sentence,
        learningLanguage: LanguageTag.english,
        text: 'How are you?',
        translations: ['잘 지내세요?'],
        acceptedAnswers: ['잘 지내세요?'],
        sentenceTokens: ['How are you?'],
        capabilities: {
          ExerciseCapability.recognition,
          ExerciseCapability.production,
        },
      );

      final result = validator.inspect(item);

      expect(result.isValid, isFalse);
      expect(
        result.errors.map((issue) => issue.code),
        contains('sentence_tokens_required'),
      );
    },
  );

  test('all bundled items pass structural content validation', () {
    final invalid = [
      for (final item in sampleContent)
        if (!validator.inspect(item).isValid)
          '${item.id}: ${validator.inspect(item).errors.map((issue) => issue.code).join(',')}',
    ];

    expect(sampleContent, hasLength(1080));
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

  test('normalizes optional attribution and rejects unsafe source URLs', () {
    const item = LearningItem(
      id: 'web-source',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'source',
      translations: ['출처'],
      acceptedAnswers: ['출처'],
      partOfSpeech: PartOfSpeech.noun,
      source: ContentSource(
        name: 'Web corpus',
        license: 'CC BY 2.0 FR',
        sourceVersion: '2026-07-28',
        contentVersion: 1,
        sourceId: '  sentence-1  ',
        sourceUrl: 'javascript:alert(1)',
        author: '  Example   Author ',
      ),
    );

    final result = validator.inspect(item);

    expect(
      result.errors.map((issue) => issue.code),
      contains('source_url_format'),
    );
    expect(result.item.source.sourceId, 'sentence-1');
    expect(result.item.source.author, 'Example Author');
  });

  test('bundled catalog has explicit provenance and word classifications', () {
    expect(
      sampleContent.every(
        (item) =>
            item.source.name == ContentSource.starterCatalog.name &&
            item.source.license == 'project-internal' &&
            item.source.sourceVersion == '2026.09' &&
            item.source.contentVersion == 4,
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
