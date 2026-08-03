import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/pronunciation_ladder.dart';

void main() {
  test('shadowing ladder keeps every practice stage in a stable order', () {
    final stages = PronunciationLadder.stagesFor(_item);

    expect(stages, ShadowingStage.values);
    expect(stages.map((stage) => stage.label).toSet(), hasLength(stages.length));
  });

  test('context stage uses the uploaded example when available', () {
    expect(PronunciationLadder.contextPrompt(_item), contains('How are you?'));
    expect(PronunciationLadder.contextPrompt(_item), contains('잘 지내?'));
  });
}

const _item = LearningItem(
  id: 'sentence-1',
  kind: LearningItemKind.sentence,
  learningLanguage: LanguageTag.english,
  text: 'How are you?',
  translations: ['잘 지내?'],
  acceptedAnswers: ['잘 지내?'],
  example: 'How are you?',
  exampleTranslation: '잘 지내?',
);
