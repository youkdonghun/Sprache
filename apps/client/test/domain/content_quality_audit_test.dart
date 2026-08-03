import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/content_management.dart';
import 'package:sprache/src/domain/content_quality_audit.dart';
import 'package:sprache/src/domain/exercise_readiness.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';

void main() {
  test('scores completeness without blocking an incomplete item', () {
    final item = _item(
      id: 'incomplete',
      text: 'こんにちは',
      language: LanguageTag.japanese,
      translations: const [''],
      accepted: const [],
      capabilities: const {},
    );
    final report = const ContentQualityAuditor().audit([item]);
    final result = report.results.single;

    expect(result.score, 45);
    expect(result.hasIssue(ContentQualityIssueKind.missingMeaning), isTrue);
    expect(result.hasIssue(ContentQualityIssueKind.missingReading), isTrue);
    expect(result.hasIssue(ContentQualityIssueKind.exerciseNotReady), isTrue);
    expect(report.averageScore, result.score);
  });

  test('detects NFKC answer ambiguity only inside the same subject', () {
    final first = _item(
      id: 'one',
      text: 'alpha',
      translations: const ['ＡＢＣ'],
      accepted: const ['ＡＢＣ'],
    );
    final second = _item(
      id: 'two',
      text: 'beta',
      translations: const ['abc'],
      accepted: const ['abc'],
    );
    final otherSubject = _item(
      id: 'three',
      text: 'gamma',
      subjectId: 'language:ja',
      translations: const ['abc'],
      accepted: const ['abc'],
    );
    final report = const ContentQualityAuditor().audit([
      first,
      second,
      otherSubject,
    ]);

    expect(
      report.results[0].hasIssue(ContentQualityIssueKind.ambiguousAnswer),
      isTrue,
    );
    expect(
      report.results[1].hasIssue(ContentQualityIssueKind.ambiguousAnswer),
      isTrue,
    );
    expect(
      report.results[2].hasIssue(ContentQualityIssueKind.ambiguousAnswer),
      isFalse,
    );
  });

  test('shows explicit exercise reasons and unresolved correction', () {
    final sentence = _item(
      id: 'sentence',
      text: 'I am ready.',
      kind: LearningItemKind.sentence,
      translations: const ['준비됐어요'],
      accepted: const ['준비됐어요'],
      capabilities: const {
        ExerciseCapability.recognition,
        ExerciseCapability.production,
      },
    );
    final report = const ContentQualityAuditor().audit(
      [sentence],
      corrections: [
        ContentCorrection(
          itemId: 'sentence',
          field: 'text',
          note: '표현 확인',
          updatedAt: DateTime.utc(2026, 8, 2),
        ),
      ],
    );
    final result = report.results.single;

    expect(result.hasIssue(ContentQualityIssueKind.sentenceTokens), isTrue);
    expect(
      result.hasIssue(ContentQualityIssueKind.unresolvedCorrection),
      isTrue,
    );
    expect(
      result.exerciseReadiness
          .singleWhere((value) => value.kind == ExerciseReadinessKind.cloze)
          .reason,
      contains('토큰'),
    );
  });
}

LearningItem _item({
  required String id,
  required String text,
  LearningItemKind kind = LearningItemKind.word,
  LanguageTag language = LanguageTag.english,
  String subjectId = 'language:en',
  List<String> translations = const ['뜻'],
  List<String> accepted = const ['뜻'],
  Set<ExerciseCapability> capabilities = const {
    ExerciseCapability.recognition,
    ExerciseCapability.production,
    ExerciseCapability.listening,
  },
}) => LearningItem(
  id: id,
  kind: kind,
  learningLanguage: language,
  subjectId: subjectId,
  text: text,
  translations: translations,
  acceptedAnswers: accepted,
  example: 'example',
  exampleTranslation: '예문',
  capabilities: capabilities,
  source: ContentSource.userCreated,
);
