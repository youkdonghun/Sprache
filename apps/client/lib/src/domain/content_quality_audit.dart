import 'answer_normalizer.dart';
import 'content_management.dart';
import 'exercise_readiness.dart';
import 'language.dart';
import 'learning_item.dart';

enum ContentQualityIssueKind {
  missingMeaning,
  missingReading,
  missingContext,
  missingSourceDetail,
  exerciseNotReady,
  sentenceTokens,
  ambiguousAnswer,
  unresolvedCorrection,
}

extension ContentQualityIssueKindLabel on ContentQualityIssueKind {
  String get label => switch (this) {
    ContentQualityIssueKind.missingMeaning => '뜻',
    ContentQualityIssueKind.missingReading => '읽기',
    ContentQualityIssueKind.missingContext => '문맥',
    ContentQualityIssueKind.missingSourceDetail => '출처',
    ContentQualityIssueKind.exerciseNotReady => '연습 준비',
    ContentQualityIssueKind.sentenceTokens => '문장 토큰',
    ContentQualityIssueKind.ambiguousAnswer => '모호한 정답',
    ContentQualityIssueKind.unresolvedCorrection => '교정 메모',
  };
}

class ContentQualityIssue {
  const ContentQualityIssue({
    required this.kind,
    required this.message,
    required this.deduction,
  });

  final ContentQualityIssueKind kind;
  final String message;
  final int deduction;
}

class ContentQualityResult {
  const ContentQualityResult({
    required this.item,
    required this.score,
    required this.issues,
    required this.exerciseReadiness,
  });

  final LearningItem item;
  final int score;
  final List<ContentQualityIssue> issues;
  final List<ExerciseReadinessStatus> exerciseReadiness;

  bool get ready => issues.isEmpty;
  bool hasIssue(ContentQualityIssueKind kind) =>
      issues.any((issue) => issue.kind == kind);
}

class ContentQualityReport {
  const ContentQualityReport({required this.results});

  final List<ContentQualityResult> results;

  int get averageScore => results.isEmpty
      ? 100
      : (results.fold<int>(0, (sum, value) => sum + value.score) /
                results.length)
            .round();

  int count(ContentQualityIssueKind kind) =>
      results.where((result) => result.hasIssue(kind)).length;
}

class ContentQualityAuditor {
  const ContentQualityAuditor({
    this.answerNormalizer = const AnswerNormalizer(),
    this.readinessInspector = const ExerciseReadinessInspector(),
  });

  final AnswerNormalizer answerNormalizer;
  final ExerciseReadinessInspector readinessInspector;

  ContentQualityReport audit(
    Iterable<LearningItem> items, {
    Iterable<ContentCorrection> corrections = const [],
  }) {
    final values = items.toList(growable: false);
    final ambiguousIds = _ambiguousItemIds(values);
    final correctionIds = {
      for (final correction in corrections)
        if (!correction.resolved) correction.itemId,
    };
    return ContentQualityReport(
      results: List.unmodifiable([
        for (final item in values)
          _inspect(
            item,
            ambiguous: ambiguousIds.contains(item.id),
            unresolvedCorrection: correctionIds.contains(item.id),
          ),
      ]),
    );
  }

  ContentQualityResult _inspect(
    LearningItem item, {
    required bool ambiguous,
    required bool unresolvedCorrection,
  }) {
    final issues = <ContentQualityIssue>[];
    void add(ContentQualityIssueKind kind, String message, int deduction) {
      issues.add(
        ContentQualityIssue(kind: kind, message: message, deduction: deduction),
      );
    }

    if (!item.translations.any((value) => value.trim().isNotEmpty)) {
      add(ContentQualityIssueKind.missingMeaning, '학습할 뜻을 추가해 주세요.', 30);
    }
    final nativeReadingNeeded =
        item.learningLanguage == LanguageTag.japanese ||
        item.learningLanguage == LanguageTag.simplifiedChinese;
    if (nativeReadingNeeded && item.readings.isEmpty) {
      add(
        ContentQualityIssueKind.missingReading,
        '가나·로마자 또는 병음 읽기를 추가하면 발음 확인이 쉬워져요.',
        10,
      );
    }
    if ((item.example ?? '').trim().isEmpty ||
        (item.exampleTranslation ?? '').trim().isEmpty) {
      add(
        ContentQualityIssueKind.missingContext,
        '예문과 예문 뜻을 함께 넣으면 문맥 학습이 가능해요.',
        10,
      );
    }
    if (item.source.name.trim().isEmpty ||
        item.source.license.trim().isEmpty ||
        (item.source.license != ContentSource.userCreated.license &&
            (item.source.attribution ?? '').trim().isEmpty)) {
      add(
        ContentQualityIssueKind.missingSourceDetail,
        '출처·라이선스·표시 정보를 확인해 주세요.',
        10,
      );
    }
    final readiness = readinessInspector.inspect(item);
    if (readiness.where((status) => status.ready).length < 2) {
      add(
        ContentQualityIssueKind.exerciseNotReady,
        '사용할 수 있는 연습 방식이 너무 적어요.',
        15,
      );
    }
    if (item.kind == LearningItemKind.sentence &&
        item.sentenceTokens.length < 2) {
      add(
        ContentQualityIssueKind.sentenceTokens,
        '문장 배열·빈칸용 토큰을 2개 이상 명시해 주세요.',
        15,
      );
    }
    if (ambiguous) {
      add(
        ContentQualityIssueKind.ambiguousAnswer,
        '같은 허용 답이 다른 학습 표현에도 연결돼 있어요.',
        20,
      );
    }
    if (unresolvedCorrection) {
      add(
        ContentQualityIssueKind.unresolvedCorrection,
        '확인하지 않은 교정 메모가 있어요.',
        10,
      );
    }
    final deduction = issues.fold<int>(
      0,
      (sum, issue) => sum + issue.deduction,
    );
    return ContentQualityResult(
      item: item,
      score: (100 - deduction).clamp(0, 100).toInt(),
      issues: List.unmodifiable(issues),
      exerciseReadiness: List.unmodifiable(readiness),
    );
  }

  Set<String> _ambiguousItemIds(List<LearningItem> items) {
    final byAnswer = <String, Set<String>>{};
    for (final item in items) {
      final subject = item.effectiveSubjectId;
      final answers = <String>{...item.acceptedAnswers, ...item.translations};
      for (final answer in answers) {
        final normalized = answerNormalizer.normalize(
          answer,
          language: LanguageTag.korean,
        );
        if (normalized.isEmpty) continue;
        byAnswer
            .putIfAbsent('$subject\u001f$normalized', () => <String>{})
            .add(item.id);
      }
    }
    return {
      for (final ids in byAnswer.values)
        if (ids.length > 1) ...ids,
    };
  }
}
