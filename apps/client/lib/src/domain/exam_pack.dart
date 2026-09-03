enum ExamPart { part1, part2, part3, part4, part5, part6, part7 }

extension ExamPartInfo on ExamPart {
  int get number => index + 1;

  String get label => 'Part $number';

  String get koreanTitle => switch (this) {
    ExamPart.part1 => '사진 묘사',
    ExamPart.part2 => '질문과 응답',
    ExamPart.part3 => '대화',
    ExamPart.part4 => '담화',
    ExamPart.part5 => '문장 빈칸',
    ExamPart.part6 => '문서 완성',
    ExamPart.part7 => '독해',
  };

  bool get isListening => number <= 4;

  int get officialQuestionCount => switch (this) {
    ExamPart.part1 => 6,
    ExamPart.part2 => 25,
    ExamPart.part3 => 39,
    ExamPart.part4 => 30,
    ExamPart.part5 => 30,
    ExamPart.part6 => 16,
    ExamPart.part7 => 54,
  };
}

enum ExamStimulusKind {
  none,
  photo,
  questionResponse,
  conversation,
  talk,
  document,
}

enum ExamDifficulty { foundation, intermediate, advanced }

class ExamStimulus {
  const ExamStimulus({
    required this.id,
    required this.kind,
    this.title,
    this.body,
    this.audioScript,
    this.visualDescription,
  });

  final String id;
  final ExamStimulusKind kind;
  final String? title;
  final String? body;
  final String? audioScript;
  final String? visualDescription;

  bool get hasAudio => audioScript?.trim().isNotEmpty ?? false;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    if (title != null) 'title': title,
    if (body != null) 'body': body,
    if (audioScript != null) 'audioScript': audioScript,
    if (visualDescription != null) 'visualDescription': visualDescription,
  };

  factory ExamStimulus.fromJson(Map<String, Object?> json) {
    final id = _requiredString(json, 'id', 160);
    final kind = _enumByName(
      ExamStimulusKind.values,
      _requiredString(json, 'kind', 40),
      'stimulus.kind',
    );
    final title = _optionalString(json, 'title', 200);
    final body = _optionalString(json, 'body', 12000);
    final audioScript = _optionalString(json, 'audioScript', 12000);
    final visualDescription = _optionalString(json, 'visualDescription', 2000);
    if (kind == ExamStimulusKind.photo && visualDescription == null) {
      throw const FormatException('사진 문제에는 visualDescription이 필요합니다.');
    }
    if ({
          ExamStimulusKind.questionResponse,
          ExamStimulusKind.conversation,
          ExamStimulusKind.talk,
        }.contains(kind) &&
        audioScript == null) {
      throw const FormatException('듣기 문제에는 audioScript가 필요합니다.');
    }
    if (kind == ExamStimulusKind.document && body == null) {
      throw const FormatException('독해 문제에는 body가 필요합니다.');
    }
    return ExamStimulus(
      id: id,
      kind: kind,
      title: title,
      body: body,
      audioScript: audioScript,
      visualDescription: visualDescription,
    );
  }
}

class ExamQuestion {
  const ExamQuestion({
    required this.id,
    required this.part,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    required this.explanation,
    required this.choiceExplanations,
    required this.skill,
    required this.difficulty,
    this.stimulusId,
  });

  final String id;
  final ExamPart part;
  final String prompt;
  final List<String> choices;
  final int correctIndex;
  final String explanation;
  final List<String> choiceExplanations;
  final String skill;
  final ExamDifficulty difficulty;
  final String? stimulusId;

  String get correctAnswer => choices[correctIndex];

  Map<String, Object?> toJson() => {
    'id': id,
    'part': part.number,
    'prompt': prompt,
    'choices': choices,
    'correctIndex': correctIndex,
    'explanation': explanation,
    'choiceExplanations': choiceExplanations,
    'skill': skill,
    'difficulty': difficulty.name,
    if (stimulusId != null) 'stimulusId': stimulusId,
  };

  factory ExamQuestion.fromJson(Map<String, Object?> json) {
    final id = _requiredString(json, 'id', 160);
    final rawPart = _requiredInt(json, 'part');
    if (rawPart < 1 || rawPart > 7) {
      throw const FormatException('문제 part는 1~7이어야 합니다.');
    }
    final part = ExamPart.values[rawPart - 1];
    final choices = _requiredStringList(
      json,
      'choices',
      minimum: 3,
      maximum: 4,
    );
    final expectedChoiceCount = part == ExamPart.part2 ? 3 : 4;
    if (choices.length != expectedChoiceCount) {
      throw FormatException('${part.label} 선택지는 $expectedChoiceCount개여야 합니다.');
    }
    final correctIndex = _requiredInt(json, 'correctIndex');
    if (correctIndex < 0 || correctIndex >= choices.length) {
      throw const FormatException('정답 번호가 선택지 범위를 벗어났습니다.');
    }
    final choiceExplanations = _requiredStringList(
      json,
      'choiceExplanations',
      minimum: choices.length,
      maximum: choices.length,
      maxStringLength: 1200,
    );
    final stimulusId = _optionalString(json, 'stimulusId', 160);
    if (part != ExamPart.part5 && stimulusId == null) {
      throw FormatException('${part.label} 문제에는 stimulusId가 필요합니다.');
    }
    return ExamQuestion(
      id: id,
      part: part,
      prompt: _requiredString(json, 'prompt', 2000),
      choices: List.unmodifiable(choices),
      correctIndex: correctIndex,
      explanation: _requiredString(json, 'explanation', 3000),
      choiceExplanations: List.unmodifiable(choiceExplanations),
      skill: _requiredString(json, 'skill', 120),
      difficulty: _enumByName(
        ExamDifficulty.values,
        _requiredString(json, 'difficulty', 40),
        'difficulty',
      ),
      stimulusId: stimulusId,
    );
  }
}

class ExamPack {
  const ExamPack({
    required this.id,
    required this.title,
    required this.description,
    required this.version,
    required this.revision,
    required this.publishedAt,
    required this.license,
    required this.attribution,
    required this.disclaimer,
    required this.stimuli,
    required this.questions,
  });

  final String id;
  final String title;
  final String description;
  final String version;
  final int revision;
  final DateTime publishedAt;
  final String license;
  final String attribution;
  final String disclaimer;
  final Map<String, ExamStimulus> stimuli;
  final List<ExamQuestion> questions;

  int questionCountFor(ExamPart part) =>
      questions.where((question) => question.part == part).length;

  bool get supportsFullMock => ExamPart.values.every(
    (part) => questionCountFor(part) >= part.officialQuestionCount,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'title': title,
    'description': description,
    'language': 'en',
    'version': version,
    'revision': revision,
    'publishedAt': publishedAt.toUtc().toIso8601String(),
    'license': license,
    'attribution': attribution,
    'disclaimer': disclaimer,
    'stimuli': [for (final stimulus in stimuli.values) stimulus.toJson()],
    'questions': [for (final question in questions) question.toJson()],
  };

  factory ExamPack.fromJson(Map<String, Object?> json) {
    if (_requiredInt(json, 'schemaVersion') != 1) {
      throw const FormatException('지원하지 않는 시험팩 형식입니다.');
    }
    if (_requiredString(json, 'language', 16) != 'en') {
      throw const FormatException('현재 시험팩은 영어만 지원합니다.');
    }
    final publishedAt = DateTime.tryParse(
      _requiredString(json, 'publishedAt', 80),
    );
    if (publishedAt == null) {
      throw const FormatException('시험팩 게시일이 올바르지 않습니다.');
    }
    final rawStimuli = json['stimuli'];
    final rawQuestions = json['questions'];
    if (rawStimuli is! List<Object?> || rawStimuli.length > 2000) {
      throw const FormatException('시험팩 지문 목록이 올바르지 않습니다.');
    }
    if (rawQuestions is! List<Object?> ||
        rawQuestions.isEmpty ||
        rawQuestions.length > 5000) {
      throw const FormatException('시험팩 문제는 1~5,000개여야 합니다.');
    }
    final stimuli = <String, ExamStimulus>{};
    for (final raw in rawStimuli) {
      if (raw is! Map) throw const FormatException('시험팩 지문이 올바르지 않습니다.');
      final stimulus = ExamStimulus.fromJson(Map<String, Object?>.from(raw));
      if (stimuli.containsKey(stimulus.id)) {
        throw FormatException('중복된 지문 ID입니다: ${stimulus.id}');
      }
      stimuli[stimulus.id] = stimulus;
    }
    final ids = <String>{};
    final questions = <ExamQuestion>[];
    for (final raw in rawQuestions) {
      if (raw is! Map) throw const FormatException('시험팩 문제가 올바르지 않습니다.');
      final question = ExamQuestion.fromJson(Map<String, Object?>.from(raw));
      if (!ids.add(question.id)) {
        throw FormatException('중복된 문제 ID입니다: ${question.id}');
      }
      if (question.stimulusId case final stimulusId?) {
        if (!stimuli.containsKey(stimulusId)) {
          throw FormatException('문제 ${question.id}의 지문을 찾을 수 없습니다.');
        }
      }
      questions.add(question);
    }
    final revision = _requiredInt(json, 'revision');
    if (revision < 1) throw const FormatException('시험팩 revision은 1 이상이어야 합니다.');
    return ExamPack(
      id: _packId(json, 'id'),
      title: _requiredString(json, 'title', 100),
      description: _requiredString(json, 'description', 300),
      version: _requiredString(json, 'version', 40),
      revision: revision,
      publishedAt: publishedAt.toUtc(),
      license: _requiredString(json, 'license', 120),
      attribution: _requiredString(json, 'attribution', 500),
      disclaimer: _requiredString(json, 'disclaimer', 800),
      stimuli: Map.unmodifiable(stimuli),
      questions: List.unmodifiable(questions),
    );
  }
}

String _packId(Map<String, Object?> json, String field) {
  final value = _requiredString(json, field, 80);
  if (!RegExp(r'^[a-z0-9][a-z0-9._-]{0,79}$').hasMatch(value)) {
    throw const FormatException('시험팩 ID 형식이 올바르지 않습니다.');
  }
  return value;
}

String _requiredString(Map<String, Object?> json, String field, int maximum) {
  final value = json[field];
  if (value is! String ||
      value.trim().isEmpty ||
      value.runes.length > maximum) {
    throw FormatException('$field 값이 없거나 너무 깁니다.');
  }
  return value.trim();
}

String? _optionalString(Map<String, Object?> json, String field, int maximum) {
  final value = json[field];
  if (value == null) return null;
  if (value is! String ||
      value.trim().isEmpty ||
      value.runes.length > maximum) {
    throw FormatException('$field 값이 올바르지 않습니다.');
  }
  return value.trim();
}

int _requiredInt(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! num || !value.isFinite || value != value.roundToDouble()) {
    throw FormatException('$field 값은 정수여야 합니다.');
  }
  return value.toInt();
}

List<String> _requiredStringList(
  Map<String, Object?> json,
  String field, {
  required int minimum,
  required int maximum,
  int maxStringLength = 2000,
}) {
  final value = json[field];
  if (value is! List<Object?> ||
      value.length < minimum ||
      value.length > maximum ||
      value.any(
        (entry) =>
            entry is! String ||
            entry.trim().isEmpty ||
            entry.runes.length > maxStringLength,
      )) {
    throw FormatException('$field 목록이 올바르지 않습니다.');
  }
  final result = value.cast<String>().map((entry) => entry.trim()).toList();
  if (result.toSet().length != result.length) {
    throw FormatException('$field 목록에 중복이 있습니다.');
  }
  return result;
}

T _enumByName<T extends Enum>(List<T> values, String name, String field) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  throw FormatException('$field 값이 올바르지 않습니다.');
}
