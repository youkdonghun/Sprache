import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_session_builder.dart';

void main() {
  const builder = StudySessionBuilder();
  final now = DateTime(2026, 7, 28, 10);

  test('filters a session by deck, tags, level, and content kind', () {
    final items = [
      _word('unit0-travel-word', unit: 0, tag: '여행', level: 'A1'),
      _sentence('unit0-travel-sentence', unit: 0, tag: '여행', level: 'A1'),
      _word('unit0-work-word', unit: 0, tag: '업무', level: 'A1'),
      _word('unit1-travel-word', unit: 1, tag: '여행', level: 'A1'),
      _word('unit0-travel-b1', unit: 0, tag: '여행', level: 'B1'),
    ];

    final result = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: items,
      progress: const {},
      plan: const StudySessionPlan(
        deck: StudyDeckScope.unit,
        unitIndex: 0,
        tags: {'여행'},
        levels: {'A1'},
        includeSentences: false,
        itemLimit: 10,
      ),
    );

    expect(result.matchingCount, 1);
    expect(result.items.single.id, 'unit0-travel-word');
    expect(result.matchingWordCount, 1);
    expect(result.matchingSentenceCount, 0);
  });

  test('honors the requested sentence ratio and remains deterministic', () {
    final items = [
      for (var index = 0; index < 8; index++) _word('word-$index'),
      for (var index = 0; index < 8; index++) _sentence('sentence-$index'),
    ];
    const plan = StudySessionPlan(itemLimit: 10, sentenceRatio: 0.4);

    final first = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: items,
      progress: const {},
      plan: plan,
    );
    final second = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: items.reversed.toList(),
      progress: const {},
      plan: plan,
    );

    expect(first.items, hasLength(10));
    expect(first.selectedSentenceCount, 4);
    expect(first.selectedWordCount, 6);
    expect(
      first.items.map((item) => item.id),
      second.items.map((item) => item.id),
    );
  });

  test('supports favorites, personal decks, and progress difficulty', () {
    final favorite = _word('favorite');
    final personalWeak = _word('personal-weak');
    final personalMastered = _word('personal-mastered');
    final progress = {
      personalWeak.id: ProgressRecord(
        itemId: personalWeak.id,
        status: LearningStatus.learning,
        correctCount: 1,
        wrongCount: 3,
      ),
      personalMastered.id: ProgressRecord(
        itemId: personalMastered.id,
        status: LearningStatus.mastered,
        correctCount: 10,
      ),
    };

    final favorites = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: [favorite, personalWeak, personalMastered],
      progress: progress,
      plan: const StudySessionPlan(deck: StudyDeckScope.favorites),
      favoriteItemIds: {favorite.id},
    );
    final personalWeakOnly = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: [favorite, personalWeak, personalMastered],
      progress: progress,
      plan: const StudySessionPlan(
        deck: StudyDeckScope.personal,
        difficulty: StudyDifficulty.weak,
      ),
      personalItemIds: {personalWeak.id, personalMastered.id},
    );

    expect(favorites.items.single.id, favorite.id);
    expect(personalWeakOnly.items.single.id, personalWeak.id);
  });

  test('places overdue and weak items before unseen expressions', () {
    final due = _word('due');
    final weak = _word('weak');
    final fresh = _word('fresh');
    final result = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: [fresh, weak, due],
      progress: {
        due.id: ProgressRecord(
          itemId: due.id,
          status: LearningStatus.review,
          nextReviewAt: now.subtract(const Duration(days: 1)),
        ),
        weak.id: ProgressRecord(
          itemId: weak.id,
          status: LearningStatus.learning,
          correctCount: 1,
          wrongCount: 2,
        ),
      },
      plan: const StudySessionPlan(itemLimit: 5),
    );

    expect(result.items.map((item) => item.id), ['due', 'weak', 'fresh']);
  });

  test('exercise mode removes items that cannot produce that problem', () {
    final word = _word('word');
    final sentence = _sentence('sentence');
    final result = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: [word, sentence],
      progress: const {},
      plan: const StudySessionPlan(mode: StudyMode.sentenceOrder),
    );

    expect(result.items.single.id, sentence.id);
  });
}

LearningItem _word(
  String id, {
  int unit = 0,
  String tag = '기초',
  String level = '입문',
}) {
  return LearningItem(
    id: id,
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.english,
    text: id,
    translations: ['뜻 $id'],
    acceptedAnswers: ['뜻 $id'],
    tags: [tag, 'unit-$unit'],
    level: level,
  );
}

LearningItem _sentence(
  String id, {
  int unit = 0,
  String tag = '기초',
  String level = '입문',
}) {
  return LearningItem(
    id: id,
    kind: LearningItemKind.sentence,
    learningLanguage: LanguageTag.english,
    text: 'This is $id.',
    translations: ['$id 문장입니다.'],
    acceptedAnswers: ['$id 문장입니다.'],
    sentenceTokens: ['This', 'is', '$id.'],
    tags: [tag, 'unit-$unit'],
    level: level,
    capabilities: const {
      ExerciseCapability.recognition,
      ExerciseCapability.production,
      ExerciseCapability.cloze,
      ExerciseCapability.sentenceOrder,
      ExerciseCapability.listening,
    },
  );
}
