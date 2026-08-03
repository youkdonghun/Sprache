import 'course_path.dart';
import 'learning_item.dart';
import 'progress.dart';

enum MissionBranch { fluent, coached }

enum MissionCheckpointDecision { fluentChoice, coachedChoice, coachedHelp }

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
    required this.mainStepIndex,
    this.coachedFollowUp = false,
  });

  final String id;
  final String situationPrompt;
  final LearningItem target;
  final List<MissionOption> options;
  final int mainStepIndex;
  final bool coachedFollowUp;

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

class MissionProgressCheckpoint {
  const MissionProgressCheckpoint({
    required this.courseId,
    required this.unitIndex,
    required this.phraseIndex,
    required this.sceneId,
    required this.coachedTurns,
    required this.updatedAt,
    this.decision,
    this.selectedOptionId,
  });

  final String courseId;
  final int unitIndex;
  final int phraseIndex;
  final String sceneId;
  final int coachedTurns;
  final MissionCheckpointDecision? decision;
  final String? selectedOptionId;
  final DateTime updatedAt;

  String get storageKey => '$courseId:$unitIndex';

  MissionDecision? restoreDecision(MissionScene scene) {
    final savedDecision = decision;
    if (savedDecision == null) return null;
    if (savedDecision == MissionCheckpointDecision.coachedHelp) {
      return scene.requestCoaching();
    }
    final optionId = selectedOptionId;
    if (optionId == null || optionId.isEmpty) return null;
    try {
      final restored = scene.choose(optionId);
      final expectedBranch =
          savedDecision == MissionCheckpointDecision.fluentChoice
          ? MissionBranch.fluent
          : MissionBranch.coached;
      return restored.branch == expectedBranch ? restored : null;
    } on ArgumentError {
      return null;
    }
  }

  Map<String, Object?> toJson() => {
    'courseId': courseId,
    'unitIndex': unitIndex,
    'phraseIndex': phraseIndex,
    'sceneId': sceneId,
    'coachedTurns': coachedTurns,
    if (decision != null) 'decision': decision!.name,
    if (selectedOptionId != null) 'selectedOptionId': selectedOptionId,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory MissionProgressCheckpoint.fromJson(Map<String, Object?> json) {
    final courseId = json['courseId'];
    final unitIndex = _exactMissionInteger(json['unitIndex']);
    final phraseIndex = _exactMissionInteger(json['phraseIndex']);
    final sceneId = json['sceneId'];
    final coachedTurns = _exactMissionInteger(json['coachedTurns']);
    final updatedAt = switch (json['updatedAt']) {
      final String value => DateTime.tryParse(value)?.toUtc(),
      _ => null,
    };
    final rawDecision = json['decision'];
    final decision = rawDecision == null
        ? null
        : MissionCheckpointDecision.values
              .cast<MissionCheckpointDecision?>()
              .firstWhere(
                (value) => value?.name == rawDecision,
                orElse: () => null,
              );
    final selectedOptionId = switch (json['selectedOptionId']) {
      final String value when value.trim().isNotEmpty => value.trim(),
      _ => null,
    };
    final validChoice =
        decision != MissionCheckpointDecision.fluentChoice &&
            decision != MissionCheckpointDecision.coachedChoice ||
        selectedOptionId != null;
    if (courseId is! String ||
        courseId.trim().isEmpty ||
        courseId.runes.length > 80 ||
        unitIndex == null ||
        unitIndex < 0 ||
        unitIndex > 100 ||
        phraseIndex == null ||
        phraseIndex < 0 ||
        phraseIndex > 1000 ||
        sceneId is! String ||
        sceneId.trim().isEmpty ||
        sceneId.runes.length > 160 ||
        coachedTurns == null ||
        coachedTurns < 0 ||
        coachedTurns > 1000 ||
        updatedAt == null ||
        (rawDecision != null && decision == null) ||
        !validChoice ||
        (selectedOptionId?.runes.length ?? 0) > 240) {
      throw const FormatException('미션 진행 체크포인트가 올바르지 않습니다.');
    }
    return MissionProgressCheckpoint(
      courseId: courseId.trim(),
      unitIndex: unitIndex,
      phraseIndex: phraseIndex,
      sceneId: sceneId.trim(),
      coachedTurns: coachedTurns,
      decision: decision,
      selectedOptionId: selectedOptionId,
      updatedAt: updatedAt,
    );
  }
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
  int get mainSceneCount =>
      scenes.where((scene) => !scene.coachedFollowUp).length;

  int? nextSceneIndex({
    required int currentIndex,
    required MissionBranch branch,
  }) {
    if (currentIndex < 0 || currentIndex >= scenes.length) return null;
    final current = scenes[currentIndex];
    final nextIndex = current.coachedFollowUp
        ? currentIndex + 1
        : branch == MissionBranch.coached
        ? currentIndex + 1
        : currentIndex + 2;
    return nextIndex < scenes.length ? nextIndex : null;
  }

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
      final immutableChoices = List<MissionOption>.unmodifiable(choices);
      scenes
        ..add(
          MissionScene(
            id: 'unit-${unit.index}-scene-$index',
            situationPrompt:
                '$setting에서 “${target.primaryTranslation}”라고 전할 차례예요. '
                '상황에 맞는 표현을 골라 보세요.',
            target: target,
            options: immutableChoices,
            mainStepIndex: index,
          ),
        )
        ..add(
          MissionScene(
            id: 'unit-${unit.index}-scene-$index-coached',
            situationPrompt:
                '방금 막힌 “${target.primaryTranslation}” 표현을 단서 없이 '
                '한 번 더 골라 대화를 이어 보세요.',
            target: target,
            options: immutableChoices,
            mainStepIndex: index,
            coachedFollowUp: true,
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

int? _exactMissionInteger(Object? raw) {
  if (raw is! num || !raw.isFinite || raw != raw.round()) return null;
  return raw.toInt();
}
