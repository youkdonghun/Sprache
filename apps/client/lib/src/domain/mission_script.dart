import 'course_path.dart';
import 'learning_item.dart';
import 'progress.dart';

enum MissionBranch { fluent, coached }

class MissionOption {
  const MissionOption({
    required this.id,
    required this.item,
    required this.isGoal,
  });

  final String id;
  final LearningItem item;
  final bool isGoal;
}

class MissionDecision {
  const MissionDecision({
    required this.branch,
    required this.target,
    required this.feedback,
  });

  final MissionBranch branch;
  final LearningItem target;
  final String feedback;

  bool get usedCoaching => branch == MissionBranch.coached;
}

class MissionScene {
  const MissionScene({
    required this.id,
    required this.situationPrompt,
    required this.target,
    required this.options,
  });

  final String id;
  final String situationPrompt;
  final LearningItem target;
  final List<MissionOption> options;

  MissionDecision choose(String optionId) {
    final option = options.where((value) => value.id == optionId).firstOrNull;
    if (option == null) {
      throw ArgumentError.value(optionId, 'optionId', '장면에 없는 선택지입니다.');
    }
    return option.isGoal
        ? MissionDecision(
            branch: MissionBranch.fluent,
            target: target,
            feedback: '상대가 바로 이해했어요. 선택한 표현을 소리 내어 말해 보세요.',
          )
        : MissionDecision(
            branch: MissionBranch.coached,
            target: target,
            feedback: '상대가 뜻을 다시 확인해 줬어요. 목표 표현을 듣고 따라 말하면 대화를 이어갈 수 있어요.',
          );
  }

  MissionDecision requestCoaching() => MissionDecision(
    branch: MissionBranch.coached,
    target: target,
    feedback: '도움 경로를 골랐어요. 표현을 한 번 듣고 직접 말한 뒤 다음 장면으로 이어 가세요.',
  );
}

class MissionEnding {
  const MissionEnding({required this.title, required this.description});

  final String title;
  final String description;
}

class MissionScript {
  const MissionScript({
    required this.setting,
    required this.goal,
    required this.scenes,
  });

  final String setting;
  final String goal;
  final List<MissionScene> scenes;

  bool get isEmpty => scenes.isEmpty;

  MissionEnding endingFor({required int coachedTurns}) => coachedTurns == 0
      ? const MissionEnding(
          title: '막힘없이 목표 달성',
          description: '모든 장면에서 상황에 맞는 표현을 바로 골랐어요.',
        )
      : MissionEnding(
          title: '도움을 활용해 목표 달성',
          description: '$coachedTurns개 장면에서 단서를 활용해 대화를 끝까지 이어갔어요.',
        );
}

class MissionScriptBuilder {
  const MissionScriptBuilder();

  MissionScript build({
    required CourseUnitSnapshot unit,
    required String setting,
    required String goal,
    Map<String, ProgressRecord> progress = const {},
  }) {
    final items = selectItems(unit, progress: progress);
    final scenes = <MissionScene>[];
    for (final (index, target) in items.indexed) {
      final alternatives = [
        for (var offset = 1; offset < items.length; offset++)
          items[(index + offset) % items.length],
      ].where((item) => item.text.trim() != target.text.trim()).take(1);
      final choices = <MissionOption>[
        MissionOption(id: '${target.id}:goal', item: target, isGoal: true),
        for (final alternative in alternatives)
          MissionOption(
            id: '${target.id}:${alternative.id}',
            item: alternative,
            isGoal: false,
          ),
      ];
      if (_stableHash('${unit.index}|${target.id}').isOdd) {
        choices.setAll(0, choices.reversed.toList(growable: false));
      }
      scenes.add(
        MissionScene(
          id: 'unit-${unit.index}-scene-$index',
          situationPrompt:
              '$setting에서 “${target.primaryTranslation}”라고 전할 차례예요. '
              '상황에 맞는 표현을 골라 보세요.',
          target: target,
          options: List.unmodifiable(choices),
        ),
      );
    }
    return MissionScript(
      setting: setting,
      goal: goal,
      scenes: List.unmodifiable(scenes),
    );
  }

  List<LearningItem> selectItems(
    CourseUnitSnapshot unit, {
    Map<String, ProgressRecord> progress = const {},
  }) {
    final candidates = unit.sentences.take(4).toList(growable: true);
    if (candidates.length < 3) {
      candidates.addAll(unit.words.take(3 - candidates.length));
    }
    final originalOrder = {
      for (final (index, item) in candidates.indexed) item.id: index,
    };
    candidates.sort((left, right) {
      final priority = _practicePriority(
        progress[left.id],
      ).compareTo(_practicePriority(progress[right.id]));
      if (priority != 0) return priority;
      return originalOrder[left.id]!.compareTo(originalOrder[right.id]!);
    });
    return List.unmodifiable(candidates);
  }

  int _practicePriority(ProgressRecord? record) {
    if (record?.lastResult == ReviewRating.again) return 0;
    if (record != null && record.attempts > 0 && record.accuracy < 0.7) {
      return 1;
    }
    if (record == null || record.attempts == 0) return 2;
    return 3;
  }
}

int _stableHash(String value) {
  var hash = 17;
  for (final codeUnit in value.codeUnits) {
    hash = (37 * hash + codeUnit) & 0x7fffffff;
  }
  return hash;
}
