import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/quiz_session_support.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';

void main() {
  test('explicit exercise modes expose a fixed, explained direction', () {
    expect(StudyMode.meaning.allowsAnswerDirectionOverride, isFalse);
    expect(
      StudyMode.meaning.effectiveFixedAnswerDirection,
      StudyAnswerDirection.learningToMeaning,
    );
    expect(StudyMode.production.allowsAnswerDirectionOverride, isFalse);
    expect(
      StudyMode.production.effectiveFixedAnswerDirection,
      StudyAnswerDirection.meaningToLearning,
    );
    expect(StudyMode.mixed.allowsAnswerDirectionOverride, isTrue);
    expect(StudyMode.meaning.answerDirectionExplanation, isNotEmpty);
  });

  test('grading strength maps to increasingly strict answer policies', () {
    expect(
      StudyGradingStrictness.lenient
          .answerPolicy(typedResponse: false)
          .allowTypo,
      isTrue,
    );
    expect(
      StudyGradingStrictness.balanced
          .answerPolicy(typedResponse: false)
          .allowTypo,
      isFalse,
    );
    final strict = StudyGradingStrictness.strict.answerPolicy(
      typedResponse: true,
    );
    expect(strict.caseSensitive, isTrue);
    expect(strict.ignorePunctuation, isFalse);
  });

  test('review corrections preserve the immutable attempt details', () {
    const attempt = QuizAttemptReview(
      sequence: 1,
      itemId: 'item-1',
      prompt: 'hello',
      expectedAnswer: '안녕',
      userAnswer: '안령',
      exerciseType: 'recognition',
      correct: false,
      rating: ReviewRating.again,
      usedHint: false,
    );

    final corrected = attempt.copyWith(
      correct: true,
      rating: ReviewRating.hard,
      correctionLabel: '오타였음',
    );

    expect(corrected.prompt, attempt.prompt);
    expect(corrected.correct, isTrue);
    expect(corrected.earnedXp, 8);
    expect(corrected.correctionLabel, '오타였음');
  });

  test('match deck removes ambiguous duplicate sides', () {
    final deck = MatchSprintDeck.fromItems([
      _item('one', 'hello', '안녕'),
      _item('two', 'hi', '안녕'),
      _item('three', 'thanks', '고마워'),
      _item('four', 'bye', '잘 가'),
    ]);

    expect(deck.pairs.map((pair) => pair.itemId), ['one', 'three', 'four']);
    expect(deck.canStart, isTrue);
  });

  test('repair advisor waits until the configured repeated failure', () {
    const advisor = QuizRepairAdvisor();
    expect(advisor.shouldOfferRepair(1), isFalse);
    expect(advisor.shouldOfferRepair(2), isTrue);
  });
}

LearningItem _item(String id, String text, String translation) => LearningItem(
  id: id,
  kind: LearningItemKind.word,
  learningLanguage: LanguageTag.english,
  text: text,
  translations: [translation],
  acceptedAnswers: [translation],
);
