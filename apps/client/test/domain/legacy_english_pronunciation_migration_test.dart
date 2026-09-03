import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/legacy_english_pronunciation_migration.dart';
import 'package:sprache/src/domain/learning_item.dart';

void main() {
  test('removes Hangul from every managed English pack version', () {
    final result = migrateLegacyEnglishPronunciations([
      _packItem('adult', '아둘트', 'sprache-en-tufs-core-2026-09'),
      _packItem(
        'appointment',
        '아포인트멘트',
        'sprache-en-toeic-service-core-2026-09',
      ),
      _packItem(
        'presentation',
        '프레센타티온',
        'sprache-en-toss-speaking-core-2026-09',
        sourceVersion: '2099.01.9',
        contentVersion: 27,
      ),
    ]);

    expect(result.changedItems, hasLength(3));
    expect(
      result.items.every((item) => item.reading(ReadingScheme.hangul) == null),
      isTrue,
    );
    expect(result.items.map((item) => item.source.contentVersion), [2, 2, 28]);
  });

  test('removes pack edits but preserves direct user entries', () {
    final packEdited = _packItem(
      'adult',
      '어덜트',
      'sprache-en-tufs-core-2026-09',
      contentVersion: 2,
    );
    final direct = _item(
      text: 'answer',
      pronunciation: '앤서',
      source: ContentSource.userCreated,
    );
    final result = migrateLegacyEnglishPronunciations([packEdited, direct]);

    expect(result.changed, isTrue);
    expect(result.items[0].koreanPronunciation, isNull);
    expect(result.items[0].source.contentVersion, 3);
    expect(result.items[1].koreanPronunciation, '앤서');
  });

  test('migration is idempotent', () {
    final first = migrateLegacyEnglishPronunciations([
      _packItem('baggage', '바그각', 'sprache-en-tufs-core-2026-09'),
    ]);
    final second = migrateLegacyEnglishPronunciations(first.items);

    expect(first.changed, isTrue);
    expect(second.changed, isFalse);
    expect(second.items.single.koreanPronunciation, isNull);
  });
}

LearningItem _packItem(
  String text,
  String pronunciation,
  String packId, {
  String sourceVersion = '2026.09.1',
  int contentVersion = 1,
}) => _item(
  text: text,
  pronunciation: pronunciation,
  source: ContentSource(
    name: '구버전 영어팩',
    license: 'CC-BY-4.0',
    sourceVersion: sourceVersion,
    contentVersion: contentVersion,
    sourceId: 'language-pack:$packId',
  ),
);

LearningItem _item({
  required String text,
  required String pronunciation,
  required ContentSource source,
}) => LearningItem(
  id: 'item-$text',
  kind: LearningItemKind.word,
  learningLanguage: LanguageTag.english,
  text: text,
  translations: const ['뜻'],
  acceptedAnswers: const ['뜻'],
  readings: [Reading(scheme: ReadingScheme.hangul, value: pronunciation)],
  source: source,
);
