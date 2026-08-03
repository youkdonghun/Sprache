import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/learning_item_codec.dart';
import 'package:sprache/src/domain/study_subject.dart';

void main() {
  const codec = LearningItemCodec();

  test('part of speech and attribution survive a JSON round trip', () {
    const item = LearningItem(
      id: 'run-verb',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: 'run',
      translations: ['달리다'],
      acceptedAnswers: ['달리다'],
      partOfSpeech: PartOfSpeech.verb,
      source: ContentSource(
        name: 'Personal notebook',
        license: 'private',
        sourceVersion: '3rd edition',
        contentVersion: 7,
        sourceId: 'entry-42',
        sourceUrl: 'https://example.com/entries/42',
        author: 'Example Author',
        attribution: 'Example Author · Personal notebook · private',
        pageNumber: 7,
        excerpt: 'run - 달리다',
      ),
    );

    final restored = codec.fromJson(codec.toJson(item));

    expect(restored.partOfSpeech, PartOfSpeech.verb);
    expect(restored.source.name, 'Personal notebook');
    expect(restored.source.license, 'private');
    expect(restored.source.sourceVersion, '3rd edition');
    expect(restored.source.contentVersion, 7);
    expect(restored.source.sourceId, 'entry-42');
    expect(restored.source.sourceUrl, 'https://example.com/entries/42');
    expect(restored.source.author, 'Example Author');
    expect(restored.source.pageNumber, 7);
    expect(restored.source.excerpt, 'run - 달리다');
    expect(
      restored.source.attribution,
      'Example Author · Personal notebook · private',
    );
  });

  test('legacy custom item JSON receives safe private source defaults', () {
    final restored = codec.fromJson({
      'id': 'legacy-item',
      'kind': 'word',
      'language': 'en',
      'text': 'legacy',
      'translations': ['기존'],
      'acceptedAnswers': ['기존'],
    });

    expect(restored.partOfSpeech, isNull);
    expect(restored.source.name, ContentSource.userCreated.name);
    expect(restored.source.license, 'private');
    expect(restored.source.contentVersion, 1);
    expect(restored.effectiveSubjectId, languageSubjectId(LanguageTag.english));
  });

  test(
    'general-topic items keep their subject and Korean content language',
    () {
      const item = LearningItem(
        id: 'baseball-era',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.korean,
        subjectId: 'general:baseball',
        text: 'ERA',
        translations: ['평균자책점'],
        acceptedAnswers: ['평균자책점', '방어율'],
        example: '투수의 ERA는 2.50이다.',
      );

      final restored = codec.fromJson(codec.toJson(item));

      expect(restored.subjectId, 'general:baseball');
      expect(restored.learningLanguage, LanguageTag.korean);
      expect(restored.courseId, 'subject:general:baseball');
    },
  );

  test('part of speech parser accepts stable codes and Korean labels', () {
    expect(parsePartOfSpeech('noun'), PartOfSpeech.noun);
    expect(parsePartOfSpeech('명사'), PartOfSpeech.noun);
    expect(parsePartOfSpeech('adj'), PartOfSpeech.adjective);
    expect(parsePartOfSpeech('양사'), PartOfSpeech.classifier);
    expect(() => parsePartOfSpeech('unknown-pos'), throwsFormatException);
  });

  test('display label omits the redundant Korean pronunciation prefix', () {
    const item = LearningItem(
      id: 'ja-reading',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.japanese,
      text: 'おはよう',
      translations: ['좋은 아침'],
      acceptedAnswers: ['좋은 아침'],
      readings: [
        Reading(scheme: ReadingScheme.hangul, value: '오하요'),
        Reading(scheme: ReadingScheme.kana, value: 'おはよう'),
        Reading(scheme: ReadingScheme.romaji, value: 'ohayou'),
      ],
    );

    expect(item.readingAidLabels, ['오하요', '가나 おはよう', '로마자 ohayou']);
    expect(item.readingAidsLabel, '오하요\n가나 おはよう\n로마자 ohayou');
    expect(item.readingAidsLabel, isNot(contains('한국어 발음')));
  });
}
