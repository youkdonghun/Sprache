import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/course_path.dart';
import '../domain/learning_item.dart';
import '../domain/mission_script.dart';
import '../services/media_lifecycle_coordinator.dart';
import '../services/tts_service.dart';
import '../state/app_state.dart';
import '../state/device_preferences_state.dart';

class MissionCatalogScreen extends ConsumerWidget {
  const MissionCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final path = controller.coursePath;
    final recommended = path.recommendedUnit;
    final otherUnits = path.units
        .where((unit) => unit.index != recommended.index)
        .toList(growable: false);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final padding = compact ? 18.0 : 28.0;
          return CustomScrollView(
            key: const Key('mission-catalog-scroll'),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 22, padding, 36),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${state.selectedLanguage.koreanName} 실전 미션',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '익힌 표현을 실제 상황처럼 듣고 말해 보세요.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _MissionCountBadge(
                                completed: controller.completedMissionCount,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _RecommendedMission(
                            unit: recommended,
                            definition: missionDefinitions[recommended.index],
                            completed: controller.hasCompletedMission(
                              recommended.index,
                            ),
                            onStart: () =>
                                context.push('/mission/${recommended.index}'),
                          ),
                          const SizedBox(height: 26),
                          Text(
                            '상황별 3분 미션',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '추천 미션부터 시작하거나, 원하는 상황을 골라 연습하세요.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, gridConstraints) {
                              final columns = gridConstraints.maxWidth >= 760
                                  ? 2
                                  : 1;
                              final width =
                                  (gridConstraints.maxWidth -
                                      (columns - 1) * 12) /
                                  columns;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (final unit in otherUnits)
                                    SizedBox(
                                      width: width,
                                      child: _MissionCard(
                                        unit: unit,
                                        definition:
                                            missionDefinitions[unit.index],
                                        completed: controller
                                            .hasCompletedMission(unit.index),
                                        onTap: () => context.push(
                                          '/mission/${unit.index}',
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MissionPracticeScreen extends ConsumerStatefulWidget {
  const MissionPracticeScreen({
    required this.unitIndex,
    this.ttsService,
    super.key,
  });

  final int unitIndex;
  final TtsService? ttsService;

  @override
  ConsumerState<MissionPracticeScreen> createState() =>
      _MissionPracticeScreenState();
}

class _MissionPracticeScreenState extends ConsumerState<MissionPracticeScreen> {
  late final MediaLifecycleRegistry _mediaLifecycleRegistry;
  late final TtsService _tts;
  var _phraseIndex = 0;
  var _completed = false;
  var _coachedTurns = 0;
  MissionDecision? _decision;
  String? _lastAutoPlayedQuestionId;
  var _checkpointRestored = false;

  @override
  void initState() {
    super.initState();
    _tts = widget.ttsService ?? TtsService.device();
    _mediaLifecycleRegistry = ref.read(mediaLifecycleRegistryProvider);
    _mediaLifecycleRegistry.register(
      this,
      MediaLifecycleRegistration(stopTextToSpeech: _stopTts),
    );
  }

  @override
  void dispose() {
    _mediaLifecycleRegistry.unregister(this);
    unawaited(_stopTts());
    super.dispose();
  }

  Future<void> _stopTts() async {
    try {
      await _tts.stop();
    } catch (_) {
      // The platform channel is absent in widget tests and headless runs.
    }
  }

  Future<void> _speak(LearningItem item) async {
    final preferences = ref.read(appControllerProvider).preferences;
    final voice = ref
        .read(devicePreferencesControllerProvider)
        .preferences
        .voice;
    try {
      await _tts.speak(
        language: item.learningLanguage,
        text: item.text,
        rate: preferences.ttsRate,
        preferOfflineVoice: preferences.interaction.preferOfflineVoice,
        repeatCount: preferences.interaction.audioRepeatCount,
        preferredVoiceId: voice.voiceIdByLanguage[item.learningLanguage.code],
        pitch: voice.pitch,
      );
    } catch (_) {
      // A missing voice must not block mission practice.
    }
  }

  void _scheduleQuestionAudio(LearningItem item) {
    final interaction = ref.read(appControllerProvider).preferences.interaction;
    if (!interaction.autoPlayQuestionAudio ||
        _lastAutoPlayedQuestionId == item.id) {
      return;
    }
    _lastAutoPlayedQuestionId = item.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _completed ||
          _lastAutoPlayedQuestionId != item.id ||
          !ref
              .read(appControllerProvider)
              .preferences
              .interaction
              .autoPlayQuestionAudio) {
        return;
      }
      unawaited(_speak(item));
    });
  }

  void _choose({
    required MissionScript script,
    required MissionDecision decision,
    required MissionCheckpointDecision checkpointDecision,
    String? selectedOptionId,
  }) {
    if (_decision != null) return;
    setState(() {
      _decision = decision;
      if (decision.usedCoaching) _coachedTurns++;
    });
    _saveCheckpoint(
      script,
      decision: checkpointDecision,
      selectedOptionId: selectedOptionId,
    );
    if (ref
        .read(appControllerProvider)
        .preferences
        .interaction
        .autoPlayAnswerAudio) {
      unawaited(_speak(decision.target));
    }
  }

  void _saveCheckpoint(
    MissionScript script, {
    MissionCheckpointDecision? decision,
    String? selectedOptionId,
  }) {
    final scene = script.scenes[_phraseIndex];
    final state = ref.read(appControllerProvider);
    ref
        .read(appControllerProvider.notifier)
        .saveMissionProgress(
          MissionProgressCheckpoint(
            courseId: state.activeCourseId,
            unitIndex: widget.unitIndex,
            phraseIndex: _phraseIndex,
            sceneId: scene.id,
            coachedTurns: _coachedTurns,
            decision: decision,
            selectedOptionId: selectedOptionId,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  void _nextPhrase(MissionScript script) {
    final decision = _decision;
    if (decision == null) return;
    final nextIndex = script.nextSceneIndex(
      currentIndex: _phraseIndex,
      branch: decision.branch,
    );
    if (nextIndex == null) {
      ref
          .read(appControllerProvider.notifier)
          .completeMission(widget.unitIndex);
      setState(() {
        _completed = true;
        _decision = null;
      });
      return;
    }
    setState(() {
      _phraseIndex = nextIndex;
      _decision = null;
    });
    _saveCheckpoint(script);
  }

  void _restoreCheckpoint(MissionScript script, AppController controller) {
    if (_checkpointRestored) return;
    _checkpointRestored = true;
    final checkpoint = controller.missionProgressFor(widget.unitIndex);
    if (checkpoint == null) return;
    final validIndex =
        checkpoint.phraseIndex >= 0 &&
        checkpoint.phraseIndex < script.scenes.length;
    if (!validIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.clearMissionProgress(widget.unitIndex);
      });
      return;
    }
    final scene = script.scenes[checkpoint.phraseIndex];
    final restoredDecision = checkpoint.restoreDecision(scene);
    final validDecision =
        checkpoint.decision == null || restoredDecision != null;
    if (scene.id != checkpoint.sceneId || !validDecision) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.clearMissionProgress(widget.unitIndex);
      });
      return;
    }
    _phraseIndex = checkpoint.phraseIndex;
    _coachedTurns = checkpoint.coachedTurns;
    _decision = restoredDecision;
  }

  void _restart() {
    ref
        .read(appControllerProvider.notifier)
        .clearMissionProgress(widget.unitIndex);
    setState(() {
      _phraseIndex = 0;
      _completed = false;
      _coachedTurns = 0;
      _decision = null;
      _lastAutoPlayedQuestionId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final path = controller.coursePath;
    if (widget.unitIndex < 0 || widget.unitIndex >= path.units.length) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/missions'),
            child: const Text('미션 목록으로 돌아가기'),
          ),
        ),
      );
    }

    final unit = path.units[widget.unitIndex];
    final definition = missionDefinitions[widget.unitIndex];
    final script = const MissionScriptBuilder().build(
      unit: unit,
      setting: definition.setting,
      goal: definition.briefing,
      progress: state.progress,
    );
    if (state.isHydrated && !script.isEmpty) {
      _restoreCheckpoint(script, controller);
    }
    if (script.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forum_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '이 미션에 쓸 표현이 없어요',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '자료실에서 이 단원의 표현을 다시 포함해 주세요.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => context.go('/library'),
                          icon: const Icon(Icons.menu_book_rounded),
                          label: const Text('자료실로 이동'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final scene =
        script.scenes[_phraseIndex.clamp(0, script.scenes.length - 1)];
    if (!_completed) _scheduleQuestionAudio(scene.target);
    final interaction = ref.watch(
      appControllerProvider.select((state) => state.preferences.interaction),
    );
    final readingAidsLabel = scene.target.readingAidsLabelFor(
      showKoreanReading: interaction.showKoreanReading,
      showNativeReading: interaction.showNativeReading,
    );

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final padding = compact ? 18.0 : 28.0;
            return CustomScrollView(
              key: const Key('mission-practice-scroll'),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(padding, 14, padding, 36),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _MissionPracticeHeader(
                              unitIndex: unit.index,
                              title: definition.title,
                              onBack: () => context.go('/missions'),
                            ),
                            const SizedBox(height: 18),
                            _MissionBriefing(
                              definition: definition,
                              phraseCount: script.mainSceneCount,
                              unitIndex: unit.index,
                              onGuide: () =>
                                  context.push('/unit/${unit.index}'),
                            ),
                            const SizedBox(height: 18),
                            if (_completed)
                              _MissionCompleteCard(
                                definition: definition,
                                phraseCount: script.mainSceneCount,
                                ending: script.endingFor(
                                  coachedTurns: _coachedTurns,
                                ),
                                onRestart: _restart,
                                onPronunciation: () => context.push(
                                  '/pronunciation?unit=${unit.index}',
                                ),
                                onSentence: () => context.push(
                                  '/study?mode=cloze&unit=${unit.index}',
                                ),
                              )
                            else
                              _BranchingMissionCard(
                                scene: scene,
                                stepIndex: scene.mainStepIndex,
                                stepCount: script.mainSceneCount,
                                coachedFollowUp: scene.coachedFollowUp,
                                readingAidsLabel: readingAidsLabel,
                                decision: _decision,
                                onSpeak: () => _speak(scene.target),
                                onChoose: (option) => _choose(
                                  script: script,
                                  decision: scene.choose(option.id),
                                  checkpointDecision: option.isGoal
                                      ? MissionCheckpointDecision.fluentChoice
                                      : MissionCheckpointDecision.coachedChoice,
                                  selectedOptionId: option.id,
                                ),
                                onCoach: () => _choose(
                                  script: script,
                                  decision: scene.requestCoaching(),
                                  checkpointDecision:
                                      MissionCheckpointDecision.coachedHelp,
                                ),
                                onNext: () => _nextPhrase(script),
                                completesAfterDecision:
                                    _decision != null &&
                                    script.nextSceneIndex(
                                          currentIndex: _phraseIndex,
                                          branch: _decision!.branch,
                                        ) ==
                                        null,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RecommendedMission extends StatelessWidget {
  const _RecommendedMission({
    required this.unit,
    required this.definition,
    required this.completed,
    required this.onStart,
  });

  final CourseUnitSnapshot unit;
  final MissionDefinition definition;
  final bool completed;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '지금 추천하는 미션',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  definition.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  definition.briefing,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSecondaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            );
            final button = FilledButton.icon(
              key: const Key('start-recommended-mission'),
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: colors.onSecondaryContainer,
                foregroundColor: colors.secondaryContainer,
                minimumSize: const Size(156, 48),
              ),
              icon: const Icon(Icons.forum_rounded),
              label: Text(completed ? '다시 연습' : '미션 시작'),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 16), button],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 20),
                button,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.unit,
    required this.definition,
    required this.completed,
    required this.onTap,
  });

  final CourseUnitSnapshot unit;
  final MissionDefinition definition;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = completed ? const Color(0xFF2E7D78) : colors.primary;
    return Material(
      key: Key('mission-card-${unit.index}'),
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(
          color: completed ? accent : colors.outlineVariant,
          width: completed ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(definition.icon, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            definition.setting,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: colors.primary),
                          ),
                        ),
                        if (completed)
                          const _MissionPill(
                            label: '완료',
                            icon: Icons.check_rounded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      definition.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${missionPhrasesFor(unit).length}개 표현 · 약 3분',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 11),
                    Semantics(
                      label: '${definition.title} 미션 준비 진행률',
                      value: completed ? '완료' : '${unit.progressPercent}퍼센트',
                      child: ExcludeSemantics(
                        child: LinearProgressIndicator(
                          value: completed ? 1 : unit.progress,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(6),
                          color: completed ? accent : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionPracticeHeader extends StatelessWidget {
  const _MissionPracticeHeader({
    required this.unitIndex,
    required this.title,
    required this.onBack,
  });

  final int unitIndex;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Row(
          children: [
            IconButton(
              onPressed: onBack,
              tooltip: '미션 목록으로',
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    compact
                        ? 'Unit ${unitIndex + 1} · 실전 연습 · 약 3분'
                        : 'Unit ${unitIndex + 1} · 실전 연습',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              const _MissionPill(label: '약 3분'),
            ],
          ],
        );
      },
    );
  }
}

class _MissionBriefing extends StatelessWidget {
  const _MissionBriefing({
    required this.definition,
    required this.phraseCount,
    required this.unitIndex,
    required this.onGuide,
  });

  final MissionDefinition definition;
  final int phraseCount;
  final int unitIndex;
  final VoidCallback onGuide;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('mission-briefing-disclosure'),
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.onPrimaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(definition.icon, color: colors.onPrimaryContainer),
          ),
          title: Text(
            definition.briefing,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '${definition.setting} · 표현 $phraseCount개',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onPrimaryContainer.withValues(alpha: 0.78),
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '표현을 듣고 뜻을 확인한 뒤 직접 말해 보세요. 막히면 단원 가이드에서 다시 볼 수 있어요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onPrimaryContainer.withValues(alpha: 0.85),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('mission-open-unit-guide'),
                onPressed: onGuide,
                icon: const Icon(Icons.menu_book_rounded),
                label: Text('Unit ${unitIndex + 1} 가이드'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchingMissionCard extends StatelessWidget {
  const _BranchingMissionCard({
    required this.scene,
    required this.stepIndex,
    required this.stepCount,
    required this.coachedFollowUp,
    required this.readingAidsLabel,
    required this.decision,
    required this.onSpeak,
    required this.onChoose,
    required this.onCoach,
    required this.onNext,
    required this.completesAfterDecision,
  });

  final MissionScene scene;
  final int stepIndex;
  final int stepCount;
  final bool coachedFollowUp;
  final String readingAidsLabel;
  final MissionDecision? decision;
  final VoidCallback onSpeak;
  final ValueChanged<MissionOption> onChoose;
  final VoidCallback onCoach;
  final VoidCallback onNext;
  final bool completesAfterDecision;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    coachedFollowUp
                        ? '보강 · 표현 ${stepIndex + 1} / $stepCount'
                        : '표현 ${stepIndex + 1} / $stepCount',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: colors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '상황 → 선택 → 말하기',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Semantics(
              label: '실전 미션 표현 진행률',
              value: '${stepIndex + 1} / $stepCount',
              child: ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: (stepIndex + 1) / stepCount,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '지금 장면',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    scene.situationPrompt,
                    key: const Key('mission-scene-prompt'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onPrimaryContainer,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (decision == null) ...[
              for (final (index, option) in scene.options.indexed) ...[
                OutlinedButton(
                  key: Key('mission-choice-$index'),
                  onPressed: () => onChoose(option),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    option.item.text,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (index + 1 < scene.options.length) const SizedBox(height: 8),
              ],
              const SizedBox(height: 10),
              TextButton.icon(
                key: const Key('mission-reveal'),
                onPressed: onCoach,
                icon: const Icon(Icons.lightbulb_outline_rounded),
                label: const Text('힌트 보고 계속'),
              ),
            ] else ...[
              Semantics(
                liveRegion: true,
                label: decision!.usedCoaching ? '힌트 사용' : '혼자 해결',
                child: Container(
                  key: const Key('mission-branch-feedback'),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: decision!.usedCoaching
                        ? colors.tertiaryContainer
                        : colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        decision!.usedCoaching ? '힌트를 사용했어요' : '대화가 이어졌어요',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(decision!.feedback),
                      const SizedBox(height: 12),
                      Text(
                        scene.target.text,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (readingAidsLabel.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          readingAidsLabel,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        scene.target.primaryTranslation,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            OutlinedButton.icon(
              key: const Key('mission-listen'),
              onPressed: onSpeak,
              icon: const Icon(Icons.volume_up_rounded),
              label: const Text('표현 듣기'),
            ),
            if (decision != null) const SizedBox(height: 10),
            FilledButton.icon(
              key: const Key('mission-next-phrase'),
              onPressed: decision == null ? null : onNext,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.record_voice_over_rounded),
              label: Text(
                completesAfterDecision ? '잘했어요 · 미션 완료' : '잘했어요 · 다음 장면',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionCompleteCard extends StatelessWidget {
  const _MissionCompleteCard({
    required this.definition,
    required this.phraseCount,
    required this.ending,
    required this.onRestart,
    required this.onPronunciation,
    required this.onSentence,
  });

  final MissionDefinition definition;
  final int phraseCount;
  final MissionEnding ending;
  final VoidCallback onRestart;
  final VoidCallback onPronunciation;
  final VoidCallback onSentence;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.onSecondaryContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 34,
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '실전 미션 완료',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ending.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colors.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${definition.setting}에서 $phraseCount개 장면을 끝냈어요. ${ending.description}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSecondaryContainer.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('다시 연습'),
                ),
                FilledButton.icon(
                  onPressed: onPronunciation,
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('발음 연습'),
                ),
                TextButton.icon(
                  onPressed: onSentence,
                  icon: const Icon(Icons.space_bar_rounded),
                  label: const Text('문장 문제 풀기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionCountBadge extends StatelessWidget {
  const _MissionCountBadge({required this.completed});

  final int completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        '$completed / 6 완료',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MissionPill extends StatelessWidget {
  const _MissionPill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: colors.onPrimaryContainer),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class MissionDefinition {
  const MissionDefinition({
    required this.setting,
    required this.title,
    required this.briefing,
    required this.icon,
  });

  final String setting;
  final String title;
  final String briefing;
  final IconData icon;
}

const missionDefinitions = [
  MissionDefinition(
    setting: '첫 만남',
    title: '처음 만난 사람과 인사하기',
    briefing: '인사하고 이름을 소개한 뒤 반갑다는 말을 건네 보세요.',
    icon: Icons.waving_hand_rounded,
  ),
  MissionDefinition(
    setting: '친구와 일상',
    title: '나와 주변 사람 소개하기',
    briefing: '내가 하는 일과 가까운 사람을 짧은 문장으로 소개해 보세요.',
    icon: Icons.people_alt_rounded,
  ),
  MissionDefinition(
    setting: '하루 계획',
    title: '시간과 오늘 일정 말하기',
    briefing: '시간을 묻고 오늘과 내일의 계획을 이어서 말해 보세요.',
    icon: Icons.schedule_rounded,
  ),
  MissionDefinition(
    setting: '카페와 식당',
    title: '원하는 음식 주문하기',
    briefing: '원하는 메뉴를 부탁하고 가격이나 예약을 확인해 보세요.',
    icon: Icons.restaurant_rounded,
  ),
  MissionDefinition(
    setting: '역과 거리',
    title: '목적지와 이동 방법 묻기',
    briefing: '역의 위치를 묻고 버스나 기차로 이동할 준비를 해 보세요.',
    icon: Icons.train_rounded,
  ),
  MissionDefinition(
    setting: '도움이 필요한 순간',
    title: '이해하지 못했을 때 도움 요청하기',
    briefing: '천천히 말해 달라고 부탁하고 필요한 도움을 구해 보세요.',
    icon: Icons.support_agent_rounded,
  ),
];

List<LearningItem> missionPhrasesFor(CourseUnitSnapshot unit) {
  return const MissionScriptBuilder().selectItems(unit);
}
