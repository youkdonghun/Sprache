import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/quiz_support.dart';

void main() {
  const choiceBuilder = QuizChoiceBuilder();
  const hintBuilder = QuizHintBuilder();

  test('recognition choices prefer similar items and stay deterministic', () {
    final target = _item(
      id: 'target',
      text: 'run',
      translation: '달리다',
      partOfSpeech: PartOfSpeech.verb,
      tags: const ['운동'],
    );
    final candidates = [
      _item(
        id: 'similar-1',
        text: 'walk',
        translation: '걷다',
        partOfSpeech: PartOfSpeech.verb,
        tags: const ['운동'],
      ),
      _item(
        id: 'similar-2',
        text: 'jump',
        translation: '뛰어오르다',
        partOfSpeech: PartOfSpeech.verb,
        tags: const ['운동'],
      ),
      _item(
        id: 'similar-3',
        text: 'stop',
        translation: '멈추다',
        partOfSpeech: PartOfSpeech.verb,
        tags: const ['운동'],
      ),
      _item(
        id: 'duplicate',
        text: 'sprint',
        translation: ' 달리다 ',
        partOfSpeech: PartOfSpeech.verb,
      ),
      _item(
        id: 'irrelevant',
        text: 'beautiful weather today',
        translation: '오늘은 날씨가 아주 아름답습니다',
        kind: LearningItemKind.sentence,
        level: '고급',
        partOfSpeech: PartOfSpeech.phrase,
      ),
    ];

    final first = choiceBuilder.recognitionChoices(
      target: target,
      candidates: candidates,
    );
    final second = choiceBuilder.recognitionChoices(
      target: target,
      candidates: candidates.reversed,
    );

    expect(first, hasLength(4));
    expect(first.toSet(), hasLength(4));
    expect(first, contains('달리다'));
    expect(first, isNot(contains('오늘은 날씨가 아주 아름답습니다')));
    expect(second, first);
  });

  test('cloze choices exclude punctuation and duplicate tokens', () {
    final target = _item(
      id: 'sentence-target',
      text: 'I study every day.',
      translation: '저는 매일 공부해요.',
      kind: LearningItemKind.sentence,
      tokens: const ['I', 'study', 'every', 'day'],
    );
    final candidates = [
      _item(
        id: 'sentence-1',
        text: 'I practice every morning.',
        translation: '저는 매일 아침 연습해요.',
        kind: LearningItemKind.sentence,
        tokens: const ['I', 'practice', 'every', 'morning', '.'],
      ),
      _item(
        id: 'sentence-2',
        text: 'We review at night.',
        translation: '우리는 밤에 복습해요.',
        kind: LearningItemKind.sentence,
        tokens: const ['We', 'review', 'at', 'night', '!'],
      ),
    ];

    final choices = choiceBuilder.clozeChoices(
      target: target,
      answer: 'study',
      candidates: candidates,
    );

    expect(choices, hasLength(4));
    expect(choices.toSet(), hasLength(4));
    expect(choices, contains('study'));
    expect(choices, isNot(contains('.')));
    expect(choices, isNot(contains('!')));
  });

  test('progressive hints expose reading first and a bounded clue second', () {
    final item = _item(
      id: 'ja-1',
      text: '勉強',
      translation: '공부',
      language: LanguageTag.japanese,
      readings: const [Reading(scheme: ReadingScheme.hangul, value: '벤쿄오')],
    );

    final first = hintBuilder.build(
      item: item,
      mode: QuizHintMode.production,
      level: 1,
    );
    final second = hintBuilder.build(
      item: item,
      mode: QuizHintMode.production,
      level: 2,
    );

    expect(first, contains('벤쿄오'));
    expect(second, contains('“勉”'));
    expect(second, contains('2글자'));
  });

  test('a filtered or hidden reading label is honored by hints', () {
    final item = _item(
      id: 'ja-filtered',
      text: '駅',
      translation: '역',
      language: LanguageTag.japanese,
      readings: const [
        Reading(scheme: ReadingScheme.hangul, value: '에키'),
        Reading(scheme: ReadingScheme.kana, value: 'えき'),
      ],
    );

    final nativeOnly = hintBuilder.build(
      item: item,
      mode: QuizHintMode.recognition,
      level: 1,
      readingAidsLabel: '가나 えき',
    );
    final hidden = hintBuilder.build(
      item: item,
      mode: QuizHintMode.recognition,
      level: 1,
      readingAidsLabel: '',
    );

    expect(nativeOnly, contains('가나 えき'));
    expect(nativeOnly, isNot(contains('에키')));
    expect(hidden, isNot(contains('에키')));
    expect(hidden, isNot(contains('えき')));
    expect(hidden, contains('단어'));
  });

  test('sentence-order hint follows the next explicit content token', () {
    final item = _item(
      id: 'sentence-order',
      text: 'I study languages',
      translation: '저는 언어를 공부해요',
      kind: LearningItemKind.sentence,
      tokens: const ['I', 'study', 'languages'],
    );

    expect(
      hintBuilder.build(
        item: item,
        mode: QuizHintMode.sentenceOrder,
        level: 2,
        orderedTokenCount: 1,
      ),
      contains('study'),
    );
  });
}

LearningItem _item({
  required String id,
  required String text,
  required String translation,
  LearningItemKind kind = LearningItemKind.word,
  LanguageTag language = LanguageTag.english,
  String level = '입문',
  PartOfSpeech? partOfSpeech,
  List<String> tags = const [],
  List<String> tokens = const [],
  List<Reading> readings = const [],
}) {
  return LearningItem(
    id: id,
    kind: kind,
    learningLanguage: language,
    text: text,
    translations: [translation],
    acceptedAnswers: [translation],
    level: level,
    partOfSpeech: partOfSpeech,
    tags: tags,
    sentenceTokens: tokens,
    readings: readings,
    capabilities: const {
      ExerciseCapability.recognition,
      ExerciseCapability.production,
      ExerciseCapability.cloze,
      ExerciseCapability.listening,
      ExerciseCapability.sentenceOrder,
    },
  );
}
