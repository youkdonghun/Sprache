import 'exam_pack.dart';

enum ExamSessionMode { quick, part, mock, wrongAnswers }

class ExamAnswerRecord {
  const ExamAnswerRecord({
    required this.questionId,
    required this.selectedIndex,
    required this.correct,
    required this.answeredAt,
  });

  final String questionId;
  final int selectedIndex;
  final bool correct;
  final DateTime answeredAt;

  Map<String, Object?> toJson() => {
    'questionId': questionId,
    'selectedIndex': selectedIndex,
    'correct': correct,
    'answeredAt': answeredAt.toUtc().toIso8601String(),
  };

  factory ExamAnswerRecord.fromJson(Map<String, Object?> json) {
    final answeredAt = DateTime.tryParse(json['answeredAt']?.toString() ?? '');
    final selectedIndex = json['selectedIndex'];
    if (json['questionId'] is! String ||
        (json['questionId']! as String).isEmpty ||
        selectedIndex is! int ||
        selectedIndex < 0 ||
        selectedIndex > 3 ||
        json['correct'] is! bool ||
        answeredAt == null) {
      throw const FormatException('시험 답안 기록이 올바르지 않습니다.');
    }
    return ExamAnswerRecord(
      questionId: json['questionId']! as String,
      selectedIndex: selectedIndex,
      correct: json['correct']! as bool,
      answeredAt: answeredAt.toUtc(),
    );
  }
}

class ExamAttemptSummary {
  const ExamAttemptSummary({
    required this.id,
    required this.packId,
    required this.mode,
    required this.startedAt,
    required this.completedAt,
    required this.questionIds,
    required this.answers,
  });

  final String id;
  final String packId;
  final ExamSessionMode mode;
  final DateTime startedAt;
  final DateTime completedAt;
  final List<String> questionIds;
  final Map<String, ExamAnswerRecord> answers;

  int get correctCount =>
      answers.values.where((answer) => answer.correct).length;
  int get totalCount => questionIds.length;
  double get accuracy => totalCount == 0 ? 0 : correctCount / totalCount;

  Map<String, Object?> toJson() => {
    'id': id,
    'packId': packId,
    'mode': mode.name,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'completedAt': completedAt.toUtc().toIso8601String(),
    'questionIds': questionIds,
    'answers': {
      for (final entry in answers.entries) entry.key: entry.value.toJson(),
    },
  };

  factory ExamAttemptSummary.fromJson(Map<String, Object?> json) {
    final modeName = json['mode'];
    final startedAt = DateTime.tryParse(json['startedAt']?.toString() ?? '');
    final completedAt = DateTime.tryParse(
      json['completedAt']?.toString() ?? '',
    );
    final rawIds = json['questionIds'];
    final rawAnswers = json['answers'];
    if (json['id'] is! String ||
        json['packId'] is! String ||
        modeName is! String ||
        startedAt == null ||
        completedAt == null ||
        rawIds is! List<Object?> ||
        rawAnswers is! Map) {
      throw const FormatException('시험 결과가 올바르지 않습니다.');
    }
    final mode = ExamSessionMode.values
        .where((value) => value.name == modeName)
        .firstOrNull;
    if (mode == null || rawIds.any((id) => id is! String)) {
      throw const FormatException('시험 결과가 올바르지 않습니다.');
    }
    final answers = <String, ExamAnswerRecord>{};
    for (final entry in rawAnswers.entries) {
      if (entry.key is! String || entry.value is! Map) {
        throw const FormatException('시험 답안이 올바르지 않습니다.');
      }
      answers[entry.key as String] = ExamAnswerRecord.fromJson(
        Map<String, Object?>.from(entry.value as Map),
      );
    }
    return ExamAttemptSummary(
      id: json['id']! as String,
      packId: json['packId']! as String,
      mode: mode,
      startedAt: startedAt.toUtc(),
      completedAt: completedAt.toUtc(),
      questionIds: List.unmodifiable(rawIds.cast<String>()),
      answers: Map.unmodifiable(answers),
    );
  }
}

class ActiveExamSession {
  const ActiveExamSession({
    required this.id,
    required this.packId,
    required this.mode,
    required this.questionIds,
    required this.currentIndex,
    required this.answers,
    required this.flaggedQuestionIds,
    required this.startedAt,
    required this.durationMinutes,
    this.part,
  });

  final String id;
  final String packId;
  final ExamSessionMode mode;
  final ExamPart? part;
  final List<String> questionIds;
  final int currentIndex;
  final Map<String, ExamAnswerRecord> answers;
  final Set<String> flaggedQuestionIds;
  final DateTime startedAt;
  final int durationMinutes;

  bool get completed => answers.length >= questionIds.length;
  int get remainingCount => questionIds.length - answers.length;

  ActiveExamSession copyWith({
    int? currentIndex,
    Map<String, ExamAnswerRecord>? answers,
    Set<String>? flaggedQuestionIds,
  }) => ActiveExamSession(
    id: id,
    packId: packId,
    mode: mode,
    part: part,
    questionIds: questionIds,
    currentIndex: currentIndex ?? this.currentIndex,
    answers: answers ?? this.answers,
    flaggedQuestionIds: flaggedQuestionIds ?? this.flaggedQuestionIds,
    startedAt: startedAt,
    durationMinutes: durationMinutes,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'packId': packId,
    'mode': mode.name,
    if (part != null) 'part': part!.number,
    'questionIds': questionIds,
    'currentIndex': currentIndex,
    'answers': {
      for (final entry in answers.entries) entry.key: entry.value.toJson(),
    },
    'flaggedQuestionIds': flaggedQuestionIds.toList()..sort(),
    'startedAt': startedAt.toUtc().toIso8601String(),
    'durationMinutes': durationMinutes,
  };

  factory ActiveExamSession.fromJson(Map<String, Object?> json) {
    final rawPart = json['part'];
    final modeName = json['mode'];
    final rawIds = json['questionIds'];
    final rawAnswers = json['answers'];
    final rawFlags = json['flaggedQuestionIds'];
    final startedAt = DateTime.tryParse(json['startedAt']?.toString() ?? '');
    final currentIndex = json['currentIndex'];
    final durationMinutes = json['durationMinutes'];
    final mode = modeName is String
        ? ExamSessionMode.values
              .where((value) => value.name == modeName)
              .firstOrNull
        : null;
    if (json['id'] is! String ||
        json['packId'] is! String ||
        mode == null ||
        rawIds is! List<Object?> ||
        rawIds.any((id) => id is! String) ||
        rawAnswers is! Map ||
        rawFlags is! List<Object?> ||
        rawFlags.any((id) => id is! String) ||
        startedAt == null ||
        currentIndex is! int ||
        durationMinutes is! int ||
        durationMinutes < 0) {
      throw const FormatException('진행 중인 시험이 올바르지 않습니다.');
    }
    final ids = rawIds.cast<String>();
    if (ids.isEmpty || currentIndex < 0 || currentIndex >= ids.length) {
      throw const FormatException('진행 중인 시험 위치가 올바르지 않습니다.');
    }
    final answers = <String, ExamAnswerRecord>{};
    for (final entry in rawAnswers.entries) {
      if (entry.key is! String || entry.value is! Map) {
        throw const FormatException('진행 중인 시험 답안이 올바르지 않습니다.');
      }
      answers[entry.key as String] = ExamAnswerRecord.fromJson(
        Map<String, Object?>.from(entry.value as Map),
      );
    }
    final part = rawPart is int && rawPart >= 1 && rawPart <= 7
        ? ExamPart.values[rawPart - 1]
        : null;
    return ActiveExamSession(
      id: json['id']! as String,
      packId: json['packId']! as String,
      mode: mode,
      part: part,
      questionIds: List.unmodifiable(ids),
      currentIndex: currentIndex,
      answers: Map.unmodifiable(answers),
      flaggedQuestionIds: Set.unmodifiable(rawFlags.cast<String>()),
      startedAt: startedAt.toUtc(),
      durationMinutes: durationMinutes,
    );
  }
}

class ExamSessionBuilder {
  const ExamSessionBuilder();

  ActiveExamSession build({
    required ExamPack pack,
    required ExamSessionMode mode,
    required DateTime now,
    ExamPart? part,
    int quickCount = 10,
    Iterable<String> wrongQuestionIds = const [],
  }) {
    final pool = switch (mode) {
      ExamSessionMode.part =>
        pack.questions.where((question) => question.part == part).toList(),
      ExamSessionMode.wrongAnswers =>
        pack.questions
            .where((question) => wrongQuestionIds.contains(question.id))
            .toList(),
      ExamSessionMode.quick || ExamSessionMode.mock => [...pack.questions],
    };
    if (pool.isEmpty) throw StateError('선택한 시험 문제가 없습니다.');
    final seeded = [...pool]
      ..sort(
        (left, right) =>
            _stableHash(
              '${now.toUtc().toIso8601String()}|${left.id}',
            ).compareTo(
              _stableHash('${now.toUtc().toIso8601String()}|${right.id}'),
            ),
      );
    final selected = switch (mode) {
      ExamSessionMode.quick => seeded.take(quickCount.clamp(1, 100)).toList(),
      ExamSessionMode.part => seeded.take(1000).toList(),
      ExamSessionMode.wrongAnswers => seeded.take(1000).toList(),
      ExamSessionMode.mock => _mockQuestions(pack),
    };
    final duration = switch (mode) {
      ExamSessionMode.quick ||
      ExamSessionMode.part ||
      ExamSessionMode.wrongAnswers => 0,
      ExamSessionMode.mock => 120,
    };
    return ActiveExamSession(
      id: 'exam-${now.toUtc().microsecondsSinceEpoch}',
      packId: pack.id,
      mode: mode,
      part: part,
      questionIds: List.unmodifiable(selected.map((question) => question.id)),
      currentIndex: 0,
      answers: const {},
      flaggedQuestionIds: const {},
      startedAt: now.toUtc(),
      durationMinutes: duration,
    );
  }

  List<ExamQuestion> _mockQuestions(ExamPack pack) {
    if (!pack.supportsFullMock) {
      throw StateError('이 문제팩은 200문제 모의고사를 지원하지 않습니다.');
    }
    return [
      for (final part in ExamPart.values)
        ...pack.questions
            .where((question) => question.part == part)
            .take(part.officialQuestionCount),
    ];
  }
}

int _stableHash(String value) {
  var hash = 17;
  for (final codeUnit in value.codeUnits) {
    hash = (hash * 37 + codeUnit) & 0x7fffffff;
  }
  return hash;
}
