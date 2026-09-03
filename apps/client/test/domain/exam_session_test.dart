import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/exam_library.dart';
import 'package:sprache/src/domain/exam_pack.dart';
import 'package:sprache/src/domain/exam_session.dart';

void main() {
  test('parses explanations and builds a ten-question quick session', () {
    final pack = _pack(questionsPerPart: 5);
    final session = const ExamSessionBuilder().build(
      pack: pack,
      mode: ExamSessionMode.quick,
      now: DateTime.utc(2026, 9, 3),
    );

    expect(session.questionIds, hasLength(10));
    expect(session.questionIds.toSet(), hasLength(10));
    expect(session.durationMinutes, 0);
    expect(pack.questions.first.explanation, isNotEmpty);
    expect(pack.questions.first.choiceExplanations, hasLength(4));
  });

  test('full mock keeps the official 200-question part distribution', () {
    final pack = _pack(questionsPerPart: 60);
    final session = const ExamSessionBuilder().build(
      pack: pack,
      mode: ExamSessionMode.mock,
      now: DateTime.utc(2026, 9, 3),
    );
    final byId = {for (final question in pack.questions) question.id: question};

    expect(session.questionIds, hasLength(200));
    for (final part in ExamPart.values) {
      expect(
        session.questionIds.where((id) => byId[id]!.part == part).length,
        part.officialQuestionCount,
      );
    }
  });

  test('wrong-answer library keeps only each question latest result', () {
    ExamAttemptSummary attempt(String id, DateTime completedAt, bool correct) =>
        ExamAttemptSummary(
          id: id,
          packId: 'pack',
          mode: ExamSessionMode.quick,
          startedAt: completedAt.subtract(const Duration(minutes: 1)),
          completedAt: completedAt,
          questionIds: const ['q1'],
          answers: {
            'q1': ExamAnswerRecord(
              questionId: 'q1',
              selectedIndex: correct ? 0 : 1,
              correct: correct,
              answeredAt: completedAt,
            ),
          },
        );

    final corrected = ExamLibrary(
      attempts: [
        attempt('new', DateTime.utc(2026, 9, 3, 11), true),
        attempt('old', DateTime.utc(2026, 9, 3, 10), false),
      ],
    );
    final stillWrong = ExamLibrary(
      attempts: [
        attempt('new', DateTime.utc(2026, 9, 3, 11), false),
        attempt('old', DateTime.utc(2026, 9, 3, 10), true),
      ],
    );

    expect(corrected.wrongQuestionIds, isEmpty);
    expect(stillWrong.wrongQuestionIds, {'q1'});
  });

  test('unanswered questions stay in the retry list', () {
    final completedAt = DateTime.utc(2026, 9, 3, 12);
    final library = ExamLibrary(
      attempts: [
        ExamAttemptSummary(
          id: 'attempt',
          packId: 'pack',
          mode: ExamSessionMode.mock,
          startedAt: completedAt.subtract(const Duration(minutes: 10)),
          completedAt: completedAt,
          questionIds: const ['answered', 'unanswered'],
          answers: {
            'answered': ExamAnswerRecord(
              questionId: 'answered',
              selectedIndex: 0,
              correct: true,
              answeredAt: completedAt,
            ),
          },
        ),
      ],
    );

    expect(library.wrongQuestionIds, {'unanswered'});
  });

  test('part practice has no time limit', () {
    final session = const ExamSessionBuilder().build(
      pack: _pack(questionsPerPart: 5),
      mode: ExamSessionMode.part,
      part: ExamPart.part3,
      now: DateTime.utc(2026, 9, 3),
    );

    expect(session.durationMinutes, 0);
  });

  test('rejects a question whose explanation list is incomplete', () {
    final json = _questionJson(ExamPart.part5, 1);
    json['choiceExplanations'] = ['하나뿐인 풀이'];

    expect(() => ExamQuestion.fromJson(json), throwsA(isA<FormatException>()));
  });
}

ExamPack _pack({required int questionsPerPart}) {
  final questions = <ExamQuestion>[];
  final stimuli = <String, ExamStimulus>{};
  for (final part in ExamPart.values) {
    for (var index = 1; index <= questionsPerPart; index++) {
      final raw = _questionJson(part, index);
      if (part != ExamPart.part5) {
        final stimulus = _stimulus(part, index);
        stimuli[stimulus.id] = stimulus;
        raw['stimulusId'] = stimulus.id;
      }
      questions.add(ExamQuestion.fromJson(raw));
    }
  }
  return ExamPack(
    id: 'pack',
    title: '시험팩',
    description: '세션 테스트',
    version: '1.0.0',
    revision: 1,
    publishedAt: DateTime.utc(2026, 9, 3),
    license: 'test',
    attribution: 'test',
    disclaimer: 'test only',
    stimuli: Map.unmodifiable(stimuli),
    questions: List.unmodifiable(questions),
  );
}

Map<String, Object?> _questionJson(ExamPart part, int index) => {
  'id': 'p${part.number}-q$index',
  'part': part.number,
  'prompt': '정답을 고르세요.',
  'choices': part == ExamPart.part2
      ? ['정답', '오답1', '오답2']
      : ['정답', '오답1', '오답2', '오답3'],
  'correctIndex': 0,
  'explanation': '지문의 근거에 따라 정답입니다.',
  'choiceExplanations': part == ExamPart.part2
      ? ['정답 근거', '오답 근거 1', '오답 근거 2']
      : ['정답 근거', '오답 근거 1', '오답 근거 2', '오답 근거 3'],
  'skill': '핵심 근거',
  'difficulty': 'intermediate',
};

ExamStimulus _stimulus(ExamPart part, int index) {
  final id = 'p${part.number}-s$index';
  if (part == ExamPart.part1) {
    return ExamStimulus(
      id: id,
      kind: ExamStimulusKind.photo,
      visualDescription: '사진 설명',
    );
  }
  if (part.isListening) {
    return ExamStimulus(
      id: id,
      kind: part == ExamPart.part2
          ? ExamStimulusKind.questionResponse
          : part == ExamPart.part3
          ? ExamStimulusKind.conversation
          : ExamStimulusKind.talk,
      audioScript: 'Test audio script.',
    );
  }
  return ExamStimulus(
    id: id,
    kind: ExamStimulusKind.document,
    body: 'Test reading passage.',
  );
}
