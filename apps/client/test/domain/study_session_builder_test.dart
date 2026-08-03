import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/study_limits.dart';
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

  test('can place unseen expressions before review and weak items', () {
    final due = _word('due');
    final weak = _word('weak');
    final fresh = _word('fresh');
    final result = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: [due, weak, fresh],
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
      plan: const StudySessionPlan(
        itemLimit: 5,
        queuePriority: StudyQueuePriority.newFirst,
      ),
    );

    expect(result.items.map((item) => item.id), ['fresh', 'due', 'weak']);
  });

  test('filters cumulative correct history and unresolved recent mistakes', () {
    final fresh = _word('fresh');
    final correct = _word('correct');
    final wrong = _word('wrong');
    final recovered = _word('recovered');
    final progress = {
      correct.id: ProgressRecord(
        itemId: correct.id,
        status: LearningStatus.learning,
        correctCount: 1,
        lastResult: ReviewRating.good,
      ),
      wrong.id: ProgressRecord(
        itemId: wrong.id,
        status: LearningStatus.learning,
        wrongCount: 1,
        lastResult: ReviewRating.again,
      ),
      recovered.id: ProgressRecord(
        itemId: recovered.id,
        status: LearningStatus.learning,
        correctCount: 1,
        wrongCount: 1,
        lastResult: ReviewRating.good,
      ),
    };

    final withoutCorrect = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: [fresh, correct, wrong, recovered],
      progress: progress,
      plan: const StudySessionPlan(
        historyFilter: StudyHistoryFilter.excludeCorrect,
      ),
    );
    final wrongOnly = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: [fresh, correct, wrong, recovered],
      progress: progress,
      plan: const StudySessionPlan(historyFilter: StudyHistoryFilter.wrongOnly),
    );

    expect(withoutCorrect.items.map((item) => item.id).toSet(), {
      'fresh',
      'wrong',
    });
    expect(wrongOnly.items.single.id, 'wrong');
  });

  test('supports a one-to-one-thousand item session boundary', () {
    final items = [
      for (var index = 0; index < 1200; index++) _word('w-$index'),
    ];

    final one = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: items,
      progress: const {},
      plan: const StudySessionPlan(itemLimit: 1),
    );
    final thousand = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: items,
      progress: const {},
      plan: const StudySessionPlan(itemLimit: StudyLimits.maxSessionItems),
    );

    expect(one.items, hasLength(1));
    expect(thousand.items, hasLength(StudyLimits.maxSessionItems));
  });

  test(
    'combines multiple groups from the same subject without duplication',
    () {
      const subjectId = 'language:en';
      final travel = _word(
        'travel',
      ).copyWith(tags: ['unit-0', learningGroupTag('여행')]);
      final work = _word(
        'work',
      ).copyWith(tags: ['unit-0', learningGroupTag('업무')]);
      final both = _word('both').copyWith(
        tags: ['unit-0', learningGroupTag('여행'), learningGroupTag('업무')],
      );
      final other = _word('other');

      final result = builder.build(
        courseId: 'ko-en',
        localDate: now,
        items: [travel, work, both, other],
        progress: const {},
        plan: StudySessionPlan(
          subjectId: subjectId,
          groupIds: {
            learningGroupDefinitionId(subjectId, '여행'),
            learningGroupDefinitionId(subjectId, '업무'),
          },
          itemLimit: 10,
        ),
      );

      expect(result.items.map((item) => item.id).toSet(), {
        'travel',
        'work',
        'both',
      });
      expect(result.items.map((item) => item.id), hasLength(3));
    },
  );

  test('uses recent speed for timed sessions and never exceeds 1000 items', () {
    final items = [
      for (var index = 0; index < 1200; index++) _word('w-$index'),
    ];

    final fiveMinutes = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: items,
      progress: const {},
      plan: const StudySessionPlan(
        lengthMode: StudySessionLengthMode.timeBudget,
        timeBudgetMinutes: 5,
      ),
      averageSecondsPerItem: 30,
    );
    final fastFifteenMinutes = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: items,
      progress: const {},
      plan: const StudySessionPlan(
        lengthMode: StudySessionLengthMode.timeBudget,
        timeBudgetMinutes: 15,
      ),
      averageSecondsPerItem: 5,
    );
    final oversizedItemCount = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: items,
      progress: const {},
      plan: const StudySessionPlan(itemLimit: 1200),
    );

    expect(fiveMinutes.items, hasLength(10));
    expect(fastFifteenMinutes.items, hasLength(180));
    expect(oversizedItemCount.items, hasLength(StudyLimits.maxSessionItems));
  });

  test('recovery mode caps the queue and ranks overdue weak items first', () {
    final oldWeak = _word('old-weak');
    final recentStrong = _word('recent-strong');
    final fresh = _word('fresh');
    final result = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: [fresh, recentStrong, oldWeak],
      progress: {
        oldWeak.id: ProgressRecord(
          itemId: oldWeak.id,
          status: LearningStatus.review,
          correctCount: 1,
          wrongCount: 4,
          lastResult: ReviewRating.again,
          nextReviewAt: now.subtract(const Duration(days: 20)),
        ),
        recentStrong.id: ProgressRecord(
          itemId: recentStrong.id,
          status: LearningStatus.review,
          correctCount: 9,
          wrongCount: 1,
          lastResult: ReviewRating.good,
          nextReviewAt: now.subtract(const Duration(days: 1)),
        ),
      },
      plan: const StudySessionPlan(
        itemLimit: 100,
        backlogRecovery: BacklogRecoverySettings(enabled: true, dailyLimit: 2),
      ),
    );

    expect(result.items, hasLength(2));
    expect(result.items.first.id, 'old-weak');
    expect(result.items.last.id, 'recent-strong');
  });

  test('recovery mode enforces the remaining cumulative daily allowance', () {
    final result = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: [_word('one'), _word('two'), _word('three')],
      progress: const {},
      plan: const StudySessionPlan(
        itemLimit: 100,
        backlogRecovery: BacklogRecoverySettings(enabled: true, dailyLimit: 3),
      ),
      recoveryItemsStudiedToday: 2,
    );
    final exhausted = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: [_word('one'), _word('two'), _word('three')],
      progress: const {},
      plan: const StudySessionPlan(
        itemLimit: 100,
        backlogRecovery: BacklogRecoverySettings(enabled: true, dailyLimit: 3),
      ),
      recoveryItemsStudiedToday: 3,
    );

    expect(result.items, hasLength(1));
    expect(exhausted.items, isEmpty);
    expect(exhausted.matchingCount, 3);
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

  test('pronunciation mode keeps only items that can be spoken', () {
    final speakable = _word('speakable').copyWith(
      capabilities: const {
        ExerciseCapability.recognition,
        ExerciseCapability.listening,
      },
    );
    final silent = _word(
      'silent',
    ).copyWith(capabilities: const {ExerciseCapability.recognition});
    final result = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: [silent, speakable],
      progress: const {},
      plan: const StudySessionPlan(mode: StudyMode.pronunciation),
    );

    expect(result.items.single.id, speakable.id);
  });

  test('builds a session from exactly selected item IDs', () {
    final first = _word('first');
    final second = _word('second');
    final third = _sentence('third');
    final result = builder.build(
      courseId: 'ko-en',
      localDate: now,
      items: [first, second, third],
      progress: const {},
      plan: const StudySessionPlan(
        deck: StudyDeckScope.selected,
        selectedItemIds: {'first', 'third'},
        itemLimit: 10,
      ),
    );

    expect(result.items.map((item) => item.id).toSet(), {'first', 'third'});
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
