import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/learning_item_codec.dart';

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
      ),
    );

    final restored = codec.fromJson(codec.toJson(item));

    expect(restored.partOfSpeech, PartOfSpeech.verb);
    expect(restored.source.name, 'Personal notebook');
    expect(restored.source.license, 'private');
    expect(restored.source.sourceVersion, '3rd edition');
    expect(restored.source.contentVersion, 7);
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
  });

  test('part of speech parser accepts stable codes and Korean labels', () {
    expect(parsePartOfSpeech('noun'), PartOfSpeech.noun);
    expect(parsePartOfSpeech('명사'), PartOfSpeech.noun);
    expect(parsePartOfSpeech('adj'), PartOfSpeech.adjective);
    expect(parsePartOfSpeech('양사'), PartOfSpeech.classifier);
    expect(() => parsePartOfSpeech('unknown-pos'), throwsFormatException);
  });
}
