import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_limits.dart';
import 'package:sprache/src/domain/study_runtime_modes.dart';

void main() {
  group('ExamReport', () {
    test('configuration round-trips with strict integer values', () {
      const configuration = ExamConfiguration(
        questionCount: 20,
        timeLimit: Duration(minutes: 30),
        passScore: 90,
      );

      final restored = ExamConfiguration.fromJson(configuration.toJson());

      expect(restored.questionCount, 20);
      expect(restored.timeLimit, const Duration(minutes: 30));
      expect(restored.passScore, 90);
      expect(
        () => ExamConfiguration.fromJson({
          ...configuration.toJson(),
          'questionCount': 2.5,
        }),
        throwsFormatException,
      );
      final boundary = ExamConfiguration.fromJson({
        ...configuration.toJson(),
        'questionCount': StudyLimits.maxSessionItems,
      });
      expect(boundary.questionCount, StudyLimits.maxSessionItems);
      expect(
        () => ExamConfiguration.fromJson({
          ...configuration.toJson(),
          'questionCount': StudyLimits.maxSessionItems + 1,
        }),
        throwsFormatException,
      );
      expect(
        boundary.normalizedFor(StudyLimits.maxSessionItems + 500).questionCount,
        StudyLimits.maxSessionItems,
      );
    });

    test('scores unanswered timeout questions against the planned count', () {
      const configuration = ExamConfiguration(
        questionCount: 10,
        timeLimit: Duration(minutes: 5),
        passScore: 80,
      );

      final report = ExamReport.evaluate(
        configuration: configuration,
        correctCount: 4,
        answeredCount: 5,
        timedOut: true,
      );

      expect(report.score, 40);
      expect(report.unansweredCount, 5);
      expect(report.passed, isFalse);
      expect(report.timedOut, isTrue);
    });
  });

  group('LiveDifficultyEngine', () {
    const engine = LiveDifficultyEngine();

    test('low rolling accuracy moves to supportive mode', () {
      final decision = engine.decide(
        attempts: const [
          LiveDifficultyAttempt(
            correct: false,
            responseTime: Duration(seconds: 15),
          ),
          LiveDifficultyAttempt(
            correct: true,
            responseTime: Duration(seconds: 12),
          ),
          LiveDifficultyAttempt(
            correct: false,
            responseTime: Duration(seconds: 16),
          ),
          LiveDifficultyAttempt(
            correct: false,
            responseTime: Duration(seconds: 18),
          ),
        ],
      );

      expect(decision.level, LiveDifficultyLevel.supportive);
      expect(decision.reason, contains('정확도'));
    });

    test('fast hint-free success moves to challenge mode', () {
      final decision = engine.decide(
        attempts: List.generate(
          5,
          (_) => const LiveDifficultyAttempt(
            correct: true,
            responseTime: Duration(seconds: 4),
          ),
        ),
      );

      expect(decision.level, LiveDifficultyLevel.challenge);
      expect(decision.level.choiceCountFor(4), 6);
    });

    test('manual lock takes precedence over session results', () {
      final decision = engine.decide(
        attempts: List.generate(
          5,
          (_) => const LiveDifficultyAttempt(
            correct: false,
            responseTime: Duration(seconds: 20),
          ),
        ),
        manualLock: LiveDifficultyLevel.challenge,
      );

      expect(decision.level, LiveDifficultyLevel.challenge);
      expect(decision.reason, contains('고정'));
    });
  });

  group('ListeningDiscriminationBuilder', () {
    test(
      'chooses closest unique local spellings with honest fallback copy',
      () {
        final question = const ListeningDiscriminationBuilder().build(
          target: _item('ship', '배'),
          candidates: [
            _item('sheep', '양', id: 'sheep'),
            _item('shop', '가게', id: 'shop'),
            _item('banana', '바나나', id: 'banana'),
            _item('ship', '배', id: 'duplicate'),
          ],
          choiceCount: 3,
        );

        expect(question.spokenText, 'ship');
        expect(question.fallbackClue, '배');
        expect(question.choices, hasLength(3));
        expect(question.choices, containsAll(['ship', 'sheep', 'shop']));
        expect(question.selectionBasisLabel, contains('철자'));
      },
    );

    test('requires a target plus two distinct candidates before launch', () {
      final twoItems = [_item('ship', '배'), _item('sheep', '양')];
      final threeItems = [...twoItems, _item('shop', '가게')];

      final insufficient = ListeningDiscriminationReadiness.evaluate(twoItems);
      final ready = ListeningDiscriminationReadiness.evaluate(threeItems);

      expect(insufficient.canStart, isFalse);
      expect(insufficient.maximumChoiceCount, 2);
      expect(insufficient.reason, contains('최소 3개'));
      expect(ready.canStart, isTrue);
      expect(ready.eligibleTargetCount, 3);
    });

    test('uses one reading scheme and excludes homophone duplicates', () {
      final target = _item(
        '橋',
        '다리',
        language: LanguageTag.japanese,
        readings: const [Reading(scheme: ReadingScheme.kana, value: 'はし')],
      );
      final question = const ListeningDiscriminationBuilder().build(
        target: target,
        candidates: [
          _item(
            '箸',
            '젓가락',
            id: 'chopsticks',
            language: LanguageTag.japanese,
            readings: const [Reading(scheme: ReadingScheme.kana, value: 'はし')],
          ),
          _item(
            '端',
            '끝',
            id: 'edge',
            language: LanguageTag.japanese,
            readings: const [Reading(scheme: ReadingScheme.kana, value: 'はじ')],
          ),
          _item(
            '星',
            '별',
            id: 'star',
            language: LanguageTag.japanese,
            readings: const [Reading(scheme: ReadingScheme.kana, value: 'ほし')],
          ),
          _item('春', '봄', id: 'spring-no-kana', language: LanguageTag.japanese),
        ],
        choiceCount: 3,
      );

      expect(question.choices, containsAll(['橋', '端', '星']));
      expect(question.choices, isNot(contains('箸')));
      expect(question.choices, isNot(contains('春')));
      expect(question.selectionBasisLabel, contains('가나'));
    });
  });

  group('SequentialMatchState', () {
    test('requires learning selection before meaning selection', () {
      const initial = SequentialMatchState();

      final ignored = initial.selectMeaning('a');
      final selected = ignored.state.selectLearning('a');
      final matched = selected.state.selectMeaning('a');

      expect(ignored.outcome, SequentialMatchOutcome.ignored);
      expect(selected.outcome, SequentialMatchOutcome.learningSelected);
      expect(matched.outcome, SequentialMatchOutcome.matched);
      expect(matched.state.matchedIds, {'a'});
      expect(matched.state.awaitingMeaning, isFalse);
    });

    test('mismatch clears the sequence and counts one error', () {
      final selected = const SequentialMatchState().selectLearning('a');
      final mismatch = selected.state.selectMeaning('b');

      expect(mismatch.outcome, SequentialMatchOutcome.mismatch);
      expect(mismatch.state.awaitingMeaning, isFalse);
      expect(mismatch.state.mistakes, 1);
    });
  });
}

LearningItem _item(
  String text,
  String meaning, {
  String? id,
  LanguageTag language = LanguageTag.english,
  List<Reading> readings = const [],
}) => LearningItem(
  id: id ?? text,
  kind: LearningItemKind.word,
  learningLanguage: language,
  text: text,
  translations: [meaning],
  acceptedAnswers: [meaning],
  readings: readings,
  capabilities: const {
    ExerciseCapability.recognition,
    ExerciseCapability.production,
    ExerciseCapability.listening,
  },
);
