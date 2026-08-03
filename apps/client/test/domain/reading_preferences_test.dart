import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';

void main() {
  const item = LearningItem(
    id: 'reading-preferences',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.japanese,
    text: '駅',
    translations: ['station'],
    acceptedAnswers: ['station'],
    readings: [
      Reading(scheme: ReadingScheme.kana, value: 'えき'),
      Reading(scheme: ReadingScheme.romaji, value: 'eki'),
      Reading(scheme: ReadingScheme.hangul, value: '에키'),
    ],
  );

  test('Korean and native reading aids can be controlled independently', () {
    expect(
      item.readingAidsLabelFor(
        showKoreanReading: true,
        showNativeReading: false,
      ),
      '에키',
    );
    expect(
      item.readingAidsLabelFor(
        showKoreanReading: false,
        showNativeReading: true,
      ),
      '가나 えき\n로마자 eki',
    );
    expect(
      item.readingAidsLabelFor(
        showKoreanReading: false,
        showNativeReading: false,
      ),
      isEmpty,
    );
  });
}
