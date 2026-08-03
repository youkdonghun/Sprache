import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/adaptive_study_session.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_runtime_modes.dart';

void main() {
  final now = DateTime.utc(2026, 8, 3, 12);

  group('response metrics and five-skill mastery', () {
    test(
      'optional response metrics round-trip without breaking legacy summary',
      () {
        final legacy = StudySessionSummary.fromJson({
          'sessionId': 'legacy',
          'courseId': 'ko-en',
          'startedAt': now
              .subtract(const Duration(minutes: 2))
              .toIso8601String(),
          'endedAt': now.toIso8601String(),
          'correctCount': 1,
          'wrongCount': 0,
          'earnedXp': 10,
          'itemIds': ['word-1'],
        });
        expect(legacy.attemptMetrics, isEmpty);

        final metric = StudyAttemptMetric(
          itemId: 'word-1',
          skill: StudySkill.writing,
          errorType: StudyErrorType.slowResponse,
          correct: true,
          responseTimeMs: 14250,
          recordedAt: now,
          usedHint: true,
        );
        final summary = StudySessionSummary(
          sessionId: 'measured',
          courseId: 'ko-en',
          startedAt: now.subtract(const Duration(minutes: 1)),
          endedAt: now,
          correctCount: 1,
          wrongCount: 0,
          earnedXp: 8,
          itemIds: const ['word-1'],
          finalCorrectItemIds: const {'word-1'},
          attemptMetrics: [metric],
        );
        final restored = StudySessionSummary.fromJson(summary.toJson());

        expect(restored.attemptMetrics.single.responseTimeMs, 14250);
        expect(restored.attemptMetrics.single.skill, StudySkill.writing);
        expect(restored.attemptMetrics.single.usedHint, isTrue);
      },
    );

    test('mixed adaptive sessions select the weakest supported skill', () {
      final item = _word('multi-skill', 'multi skill');
      final recommendation = const AdaptiveStudySessionEngine().recommend(
        items: [item],
        mode: StudyMode.mixed,
        strategy: StudySessionStrategy.adaptive,
        progress: const {},
        attemptHistory: [
          StudyAttemptMetric(
            itemId: 'multi-skill',
            skill: StudySkill.meaning,
            errorType: StudyErrorType.none,
            correct: true,
            responseTimeMs: 2000,
            recordedAt: now,
          ),
          StudyAttemptMetric(
            itemId: 'multi-skill',
            skill: StudySkill.listening,
            errorType: StudyErrorType.listeningRecognition,
            correct: false,
            responseTimeMs: 17000,
            recordedAt: now,
          ),
        ],
        now: now,
      );

      expect(recommendation.skillByItemId['multi-skill'], StudySkill.listening);
      expect(recommendation.reasonByItemId['multi-skill'], contains('듣기 숙련도'));
    });

    test(
      'aggregates meaning, writing, listening, sentence and pronunciation',
      () {
        final attempts = <StudyAttemptMetric>[
          for (final skill in StudySkill.values)
            StudyAttemptMetric(
              itemId: 'item-${skill.name}',
              skill: skill,
              errorType: skill == StudySkill.listening
                  ? StudyErrorType.listeningRecognition
                  : StudyErrorType.none,
              correct: skill != StudySkill.listening,
              responseTimeMs: skill == StudySkill.writing ? 18000 : 4000,
              recordedAt: now,
            ),
        ];
        final snapshot = StudyMasterySnapshot.fromAttempts(attempts);

        expect(snapshot.bySkill.keys, containsAll(StudySkill.values));
        expect(snapshot.bySkill[StudySkill.listening]!.score, lessThan(0.3));
        expect(snapshot.weakestSkill, StudySkill.listening);
        expect(
          snapshot
              .masteryFor('item-writing', StudySkill.writing)
              .averageResponseTimeMs,
          18000,
        );
      },
    );

    test('challenge score combines accuracy speed and hint independence', () {
      final score = PracticeChallengeScore.calculate(
        correctCount: 3,
        wrongCount: 1,
        elapsed: const Duration(seconds: 40),
        attemptMetrics: [
          for (var index = 0; index < 4; index++)
            StudyAttemptMetric(
              itemId: 'score-$index',
              skill: StudySkill.meaning,
              errorType: index == 3
                  ? StudyErrorType.meaningRecall
                  : StudyErrorType.none,
              correct: index != 3,
              responseTimeMs: 8000,
              recordedAt: now,
              usedHint: index == 2,
            ),
        ],
      );

      expect(score.accuracyPoints, 53);
      expect(score.speedPoints, 15);
      expect(score.hintPoints, 8);
      expect(score.total, 76);
      expect(score.averageResponseTimeMs, 8000);
      expect(score.hintCount, 1);
    });
  });

  group('adaptive queue and answer-safe preview', () {
    test(
      'prioritizes recent errors, response time and low mastery with a reason',
      () {
        final items = [
          _word('steady', 'visible steady'),
          _word('weak', 'secret answer'),
        ];
        final metrics = [
          StudyAttemptMetric(
            itemId: 'weak',
            skill: StudySkill.meaning,
            errorType: StudyErrorType.meaningRecall,
            correct: false,
            responseTimeMs: 22000,
            recordedAt: now,
          ),
        ];
        final recommendation = const AdaptiveStudySessionEngine().recommend(
          items: items,
          mode: StudyMode.meaning,
          strategy: StudySessionStrategy.adaptive,
          progress: {
            'steady': const ProgressRecord(
              itemId: 'steady',
              correctCount: 5,
              lastResult: ReviewRating.good,
            ),
            'weak': const ProgressRecord(
              itemId: 'weak',
              wrongCount: 2,
              lastResult: ReviewRating.again,
            ),
          },
          attemptHistory: metrics,
          now: now,
        );

        expect(recommendation.items.first.id, 'weak');
        expect(recommendation.reasonByItemId['weak'], '최근 오답 우선');
      },
    );

    test(
      'custom order stays intact and preview exposes only type, ratio and reason',
      () {
        final items = [
          _word('first', 'TOP SECRET ANSWER'),
          _sentence('second', 'DO NOT REVEAL'),
        ];
        final recommendation = const AdaptiveStudySessionEngine().recommend(
          items: items,
          mode: StudyMode.mixed,
          strategy: StudySessionStrategy.custom,
          progress: const {},
          now: now,
        );
        final preview = StudyQueuePreview.fromRecommendation(recommendation);

        expect(recommendation.items.map((item) => item.id), [
          'first',
          'second',
        ]);
        expect(preview.wordCount, 1);
        expect(preview.sentenceCount, 1);
        expect(preview.sentencePercent, 50);
        expect(preview.entries.first.reason, '사용자가 정한 순서');
        expect(
          preview.entries
              .map((entry) => '${entry.skill.koreanLabel}:${entry.reason}')
              .join(),
          isNot(contains('TOP SECRET ANSWER')),
        );
        expect(
          preview.entries.map((entry) => entry.reason).join(),
          isNot(contains('DO NOT REVEAL')),
        );
      },
    );
  });

  group('session-only settings, breaks and draft checkpoint', () {
    test(
      'runtime settings support 10, 20, 30 minute breaks and strict parsing',
      () {
        for (final minutes in [10, 20, 30]) {
          final options = StudySessionRuntimeOptions(
            strategy: StudySessionStrategy.balanced,
            breakReminderMinutes: minutes,
            showKoreanReading: false,
            showNativeReading: true,
            ttsRate: 0.7,
            liveDifficultyLock: LiveDifficultyLevel.challenge,
            practiceActivityId: 'listening-discrimination',
            examConfiguration: const ExamConfiguration(
              questionCount: 20,
              timeLimit: Duration(minutes: 30),
              passScore: 90,
            ),
            examDeadline: DateTime.utc(2026, 8, 3, 12, 30),
          );
          final restored = StudySessionRuntimeOptions.fromJson(
            options.toJson(),
          );
          expect(restored.breakReminderMinutes, minutes);
          expect(restored.ttsRate, 0.7);
          expect(restored.liveDifficultyLock, LiveDifficultyLevel.challenge);
          expect(restored.practiceActivityId, 'listening-discrimination');
          expect(restored.examConfiguration?.questionCount, 20);
          expect(restored.examConfiguration?.passScore, 90);
          expect(restored.examDeadline, DateTime.utc(2026, 8, 3, 12, 30));
        }
        expect(
          () => StudySessionRuntimeOptions.fromJson({
            'strategy': 'adaptive',
            'breakReminderMinutes': 15,
            'showKoreanReading': true,
            'showNativeReading': true,
            'ttsRate': 0.45,
          }),
          throwsFormatException,
        );
        expect(
          () => StudySessionRuntimeOptions.fromJson({
            'strategy': 'adaptive',
            'breakReminderMinutes': 20,
            'showKoreanReading': true,
            'showNativeReading': true,
            'ttsRate': 0.45,
            'practiceActivityId': '../unsafe',
          }),
          throwsFormatException,
        );
      },
    );

    test('pending exam setup is persisted and cannot carry a deadline', () {
      const pending = StudySessionRuntimeOptions(
        practiceActivityId: 'exam-simulator',
        examSetupPending: true,
      );
      final restored = StudySessionRuntimeOptions.fromJson(pending.toJson());

      expect(restored.examSetupPending, isTrue);
      expect(restored.examConfiguration, isNull);
      expect(restored.examDeadline, isNull);
      expect(
        () => StudySessionRuntimeOptions.fromJson({
          ...pending.toJson(),
          'examConfiguration': const ExamConfiguration().toJson(),
          'examDeadline': DateTime.utc(2026, 8, 3, 12, 10).toIso8601String(),
        }),
        throwsFormatException,
      );
      expect(
        () => StudySessionRuntimeOptions.fromJson({
          ...pending.toJson(),
          'examSetupPending': 'true',
        }),
        throwsFormatException,
      );
    });

    test('break schedule advances safely after each shown reminder', () {
      const schedule = StudyBreakSchedule(10);
      final started = DateTime.utc(2026, 8, 3, 10);
      expect(
        schedule.delayUntilNext(
          startedAt: started,
          now: started.add(const Duration(minutes: 4)),
        ),
        const Duration(minutes: 6),
      );
      expect(
        schedule.delayUntilNext(
          startedAt: started,
          now: started.add(const Duration(minutes: 11)),
        ),
        Duration.zero,
      );
      expect(
        schedule.delayUntilNext(
          startedAt: started,
          now: started.add(const Duration(minutes: 11)),
          remindersShown: 1,
        ),
        const Duration(minutes: 9),
      );
    });

    test(
      'active session restores a bounded unfinished answer and token order',
      () {
        final checkpoint = StudyInputCheckpoint(
          itemId: 'sentence-1',
          exerciseType: 'sentenceOrder',
          answerText: 'unfinished text',
          selectedChoice: 'choice',
          orderedTokens: const ['I', 'am'],
          savedAt: now,
        );
        final active = ActiveStudySession.started(
          sessionId: 'active',
          courseId: 'ko-en',
          mode: StudyMode.sentenceOrder,
          unitIndex: null,
          itemIds: const ['sentence-1'],
          startedAt: now,
          runtimeOptions: const StudySessionRuntimeOptions(
            strategy: StudySessionStrategy.balanced,
            breakReminderMinutes: 30,
            showKoreanReading: false,
            ttsRate: 0.65,
          ),
        ).copyWith(inputCheckpoint: checkpoint);
        final restored = ActiveStudySession.fromJson(active.toJson());

        expect(restored.inputCheckpoint?.answerText, 'unfinished text');
        expect(restored.inputCheckpoint?.orderedTokens, ['I', 'am']);
        expect(restored.runtimeOptions.showKoreanReading, isFalse);
        expect(restored.runtimeOptions.ttsRate, 0.65);

        final legacyJson = Map<String, Object?>.from(active.toJson())
          ..remove('runtimeOptions')
          ..remove('inputCheckpoint')
          ..remove('attemptMetrics');
        final legacy = ActiveStudySession.fromJson(legacyJson);
        expect(legacy.inputCheckpoint, isNull);
        expect(legacy.runtimeOptions.strategy, StudySessionStrategy.adaptive);
      },
    );
  });
}

LearningItem _word(String id, String text) => LearningItem(
  id: id,
  kind: LearningItemKind.word,
  learningLanguage: LanguageTag.english,
  text: text,
  translations: const ['뜻'],
  acceptedAnswers: const ['뜻'],
  capabilities: const {
    ExerciseCapability.recognition,
    ExerciseCapability.production,
    ExerciseCapability.listening,
  },
);

LearningItem _sentence(String id, String text) => LearningItem(
  id: id,
  kind: LearningItemKind.sentence,
  learningLanguage: LanguageTag.english,
  text: text,
  translations: const ['문장 뜻'],
  acceptedAnswers: const ['문장 뜻'],
  sentenceTokens: const ['I', 'learn'],
  capabilities: const {
    ExerciseCapability.recognition,
    ExerciseCapability.production,
    ExerciseCapability.listening,
    ExerciseCapability.cloze,
    ExerciseCapability.sentenceOrder,
  },
);
