import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/pronunciation_ladder.dart';
import 'package:sprache/src/domain/pronunciation_score.dart';
import 'package:sprache/src/domain/pronunciation_signal.dart';
import 'package:sprache/src/domain/study_history.dart';

void main() {
  test('token alignment explains missing, added and substituted words', () {
    final assessment = const PronunciationScorer().assess(
      expected: 'I really like apples',
      recognized: 'I love green apples',
      language: LanguageTag.english,
      expectedTokens: const ['I', 'really', 'like', 'apples'],
    );

    expect(assessment.tokenDiffs.first.kind, PronunciationTokenDiffKind.match);
    expect(
      assessment.tokenDiffs.map((value) => value.kind),
      contains(PronunciationTokenDiffKind.substituted),
    );
    expect(
      assessment.tokenDiffs.map((value) => value.spokenLabel).join(' '),
      contains('대신'),
    );
  });

  test('CJK alignment stays useful without runtime whitespace tokens', () {
    final assessment = const PronunciationScorer().assess(
      expected: '你好世界',
      recognized: '你好世',
      language: LanguageTag.simplifiedChinese,
    );
    expect(assessment.tokenDiffs, hasLength(4));
    expect(assessment.tokenDiffs.last.kind, PronunciationTokenDiffKind.missing);
    expect(assessment.tokenDiffs.last.expected, '界');
  });

  test('shadowing segments prefer explicit sentence tokens', () {
    final item = _sentence(
      text: 'I would like a cup of coffee please',
      tokens: const [
        'I',
        'would',
        'like',
        'a',
        'cup',
        'of',
        'coffee',
        'please',
      ],
    );
    expect(PronunciationLadder.segmentsFor(item), [
      'I would like a',
      'cup of coffee please',
    ]);
    expect(PronunciationLadder.segmentsFor(item, maxTokensPerSegment: 3), [
      'I would like',
      'a cup of',
      'coffee please',
    ]);
  });

  test(
    'signal inspection avoids false failure for no input, noise and locale',
    () {
      const inspector = PronunciationSignalInspector();
      expect(
        inspector
            .inspect(
              transcript: '',
              soundLevels: const [],
              requestedLocale: 'en-US',
            )
            .issue,
        PronunciationSignalIssue.noInput,
      );
      expect(
        inspector
            .inspect(
              transcript: 'a',
              soundLevels: const [9, 9.2, 9.1, 9.3],
              requestedLocale: 'en-US',
            )
            .issue,
        PronunciationSignalIssue.backgroundNoise,
      );
      expect(
        inspector
            .inspect(
              transcript: 'hello',
              soundLevels: const [1, 3, 6, 2],
              requestedLocale: 'ja-JP',
              availableLocales: const ['en-US', 'ko-KR'],
            )
            .issue,
        PronunciationSignalIssue.wrongLocale,
      );
    },
  );

  test('session metric round-trip stores no original text or transcript', () {
    final session = StudySessionSummary(
      sessionId: 'voice-safe',
      courseId: 'ko-en',
      startedAt: DateTime.utc(2026, 8, 2),
      endedAt: DateTime.utc(2026, 8, 2, 0, 2),
      correctCount: 1,
      wrongCount: 0,
      earnedXp: 10,
      pronunciationMetrics: [
        PronunciationAttemptMetric(
          score: 88,
          recordedAt: DateTime.utc(2026, 8, 2, 0, 1),
          method: PronunciationEvaluationMethod.speechRecognition,
        ),
      ],
    );
    final json = session.toJson();
    final restored = StudySessionSummary.fromJson(json);

    expect(restored.pronunciationMetrics.single.score, 88);
    expect(json.toString(), isNot(contains('expected')));
    expect(json.toString(), isNot(contains('recognized')));
    expect(json.toString(), isNot(contains('audio')));
  });
}

LearningItem _sentence({required String text, required List<String> tokens}) =>
    LearningItem(
      id: 'sentence',
      kind: LearningItemKind.sentence,
      learningLanguage: LanguageTag.english,
      subjectId: 'language:en',
      text: text,
      translations: const ['뜻'],
      acceptedAnswers: const ['뜻'],
      sentenceTokens: tokens,
      capabilities: const {
        ExerciseCapability.recognition,
        ExerciseCapability.production,
        ExerciseCapability.listening,
        ExerciseCapability.cloze,
        ExerciseCapability.sentenceOrder,
      },
    );
