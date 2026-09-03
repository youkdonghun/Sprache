import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/exam_pack.dart';
import '../domain/exam_session.dart';
import '../domain/language.dart';
import '../state/device_preferences_state.dart';
import '../state/exam_state.dart';

class ExamSessionScreen extends ConsumerStatefulWidget {
  const ExamSessionScreen({super.key});

  @override
  ConsumerState<ExamSessionScreen> createState() => _ExamSessionScreenState();
}

class _ExamSessionScreenState extends ConsumerState<ExamSessionScreen> {
  Timer? _timer;
  ExamAttemptSummary? _result;
  bool _finishing = false;
  bool _speaking = false;

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(ref.read(deviceTtsServiceProvider).stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(examStudyControllerProvider);
    final session = state.library.activeSession;
    final pack = state.activePack;
    if (_result case final result?) {
      return _ExamResultView(
        result: result,
        pack: pack,
        onDone: () => context.go('/exam'),
      );
    }
    if (state.loading && session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (session == null || pack == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/exam'),
            child: const Text('시험 연습으로 돌아가기'),
          ),
        ),
      );
    }
    _startTimerIfNeeded(session);
    final questionId = session.questionIds[session.currentIndex];
    final question = pack.questions.firstWhere(
      (value) => value.id == questionId,
    );
    final stimulus = question.stimulusId == null
        ? null
        : pack.stimuli[question.stimulusId];
    final answer = session.answers[question.id];
    final showFeedback = session.mode != ExamSessionMode.mock && answer != null;
    final remaining = _remaining(session);
    if (remaining == Duration.zero &&
        session.durationMinutes > 0 &&
        !_finishing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finish(force: true));
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${question.part.label} · ${session.currentIndex + 1}/${session.questionIds.length}',
          ),
          actions: [
            if (session.durationMinutes > 0)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _durationLabel(remaining),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            IconButton(
              key: const Key('toggle-exam-flag'),
              tooltip: '다시 볼 문제 표시',
              onPressed: () => unawaited(
                ref.read(examStudyControllerProvider.notifier).toggleFlag(),
              ),
              icon: Icon(
                session.flaggedQuestionIds.contains(question.id)
                    ? Icons.flag_rounded
                    : Icons.outlined_flag_rounded,
              ),
            ),
            IconButton(
              key: const Key('open-exam-answer-sheet'),
              tooltip: '답안지',
              onPressed: () => _showAnswerSheet(session),
              icon: const Icon(Icons.grid_view_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  LinearProgressIndicator(
                    value:
                        (session.currentIndex + 1) / session.questionIds.length,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          '${question.part.label} · ${question.part.koreanTitle}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(label: Text(_difficultyLabel(question.difficulty))),
                    ],
                  ),
                  if (stimulus != null) ...[
                    const SizedBox(height: 12),
                    _StimulusCard(
                      stimulus: stimulus,
                      revealTranscript: showFeedback,
                      speaking: _speaking,
                      onSpeak: stimulus.hasAudio
                          ? () => _speak(stimulus.audioScript!)
                          : null,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    question.prompt,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final (index, choice) in question.choices.indexed) ...[
                    _ChoiceTile(
                      index: index,
                      text: choice,
                      selected: answer?.selectedIndex == index,
                      correct: showFeedback && index == question.correctIndex,
                      wrong:
                          showFeedback &&
                          answer.selectedIndex == index &&
                          !answer.correct,
                      enabled:
                          answer == null ||
                          session.mode == ExamSessionMode.mock,
                      onTap: () => unawaited(
                        ref
                            .read(examStudyControllerProvider.notifier)
                            .answerCurrent(index),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (showFeedback) ...[
                    const SizedBox(height: 12),
                    _ExplanationCard(
                      question: question,
                      selectedIndex: answer.selectedIndex,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: session.currentIndex == 0
                      ? null
                      : () => unawaited(
                          ref
                              .read(examStudyControllerProvider.notifier)
                              .goToQuestion(session.currentIndex - 1),
                        ),
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: const Text('이전'),
                ),
                const Spacer(),
                FilledButton.icon(
                  key: const Key('next-exam-question'),
                  onPressed:
                      answer == null && session.mode != ExamSessionMode.mock
                      ? null
                      : session.currentIndex == session.questionIds.length - 1
                      ? () => _finish()
                      : () => unawaited(
                          ref
                              .read(examStudyControllerProvider.notifier)
                              .goToQuestion(session.currentIndex + 1),
                        ),
                  icon: Icon(
                    session.currentIndex == session.questionIds.length - 1
                        ? Icons.check_rounded
                        : Icons.chevron_right_rounded,
                  ),
                  label: Text(
                    session.currentIndex == session.questionIds.length - 1
                        ? '채점하기'
                        : '다음',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Duration _remaining(ActiveExamSession session) {
    if (session.durationMinutes <= 0) return const Duration(days: 1);
    final total = Duration(minutes: session.durationMinutes);
    final elapsed = DateTime.now().toUtc().difference(session.startedAt);
    return elapsed >= total ? Duration.zero : total - elapsed;
  }

  void _startTimerIfNeeded(ActiveExamSession session) {
    if (session.durationMinutes <= 0 || _timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _speak(String text) async {
    if (_speaking) return;
    setState(() => _speaking = true);
    try {
      await ref
          .read(deviceTtsServiceProvider)
          .speak(
            language: LanguageTag.english,
            text: text,
            rate: 0.42,
            preferOfflineVoice: false,
          );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('영어 음성을 재생하지 못했습니다. 기기 음성을 확인해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _finish({bool force = false}) async {
    if (_finishing) return;
    final active = ref.read(examStudyControllerProvider).library.activeSession;
    if (!force && active != null && active.remainingCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('지금 채점할까요?'),
          content: Text(
            '아직 ${active.remainingCount}문제가 비어 있어요. '
            '미응답은 오답으로 처리됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('더 풀기'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('채점하기'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _finishing = true);
    final result = await ref
        .read(examStudyControllerProvider.notifier)
        .finish();
    if (!mounted) return;
    _timer?.cancel();
    _timer = null;
    setState(() {
      _result = result;
      _finishing = false;
    });
  }

  Future<void> _showAnswerSheet(ActiveExamSession session) async {
    final index = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '답안지',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (questionIndex, id)
                          in session.questionIds.indexed)
                        ActionChip(
                          avatar: session.flaggedQuestionIds.contains(id)
                              ? const Icon(Icons.flag_rounded, size: 15)
                              : null,
                          backgroundColor: session.answers.containsKey(id)
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          label: Text('${questionIndex + 1}'),
                          onPressed: () =>
                              Navigator.pop(context, questionIndex),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => _finish(),
                child: Text('현재 답안 ${session.answers.length}개 채점하기'),
              ),
            ],
          ),
        ),
      ),
    );
    if (index != null && mounted) {
      await ref.read(examStudyControllerProvider.notifier).goToQuestion(index);
    }
  }
}

class _StimulusCard extends StatelessWidget {
  const _StimulusCard({
    required this.stimulus,
    required this.revealTranscript,
    required this.speaking,
    this.onSpeak,
  });

  final ExamStimulus stimulus;
  final bool revealTranscript;
  final bool speaking;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final isPhoto = stimulus.kind == ExamStimulusKind.photo;
    final visibleText = isPhoto ? stimulus.visualDescription : stimulus.body;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stimulus.title != null) ...[
              Text(
                stimulus.title!,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
            ],
            if (isPhoto) ...[
              const Icon(Icons.photo_camera_back_rounded, size: 54),
              const SizedBox(height: 12),
            ],
            if (visibleText != null) SelectableText(visibleText),
            if (onSpeak != null) ...[
              FilledButton.tonalIcon(
                key: const Key('play-exam-audio'),
                onPressed: speaking ? null : onSpeak,
                icon: Icon(
                  speaking ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                ),
                label: Text(speaking ? '재생 중' : '듣기 재생'),
              ),
              if (revealTranscript) ...[
                const SizedBox(height: 10),
                Text('듣기 원문', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                SelectableText(stimulus.audioScript!),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.index,
    required this.text,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final String text;
  final bool selected;
  final bool correct;
  final bool wrong;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = correct
        ? colors.primaryContainer
        : wrong
        ? colors.errorContainer
        : selected
        ? colors.secondaryContainer
        : null;
    return Card(
      color: color,
      child: ListTile(
        leading: CircleAvatar(child: Text(String.fromCharCode(65 + index))),
        title: Text(text),
        trailing: correct
            ? const Icon(Icons.check_circle_rounded)
            : wrong
            ? const Icon(Icons.cancel_rounded)
            : null,
        onTap: enabled ? onTap : null,
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.question, required this.selectedIndex});

  final ExamQuestion question;
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.tertiaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            selectedIndex == null
                ? '미응답 풀이'
                : selectedIndex == question.correctIndex
                ? '정답입니다'
                : '풀이',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(question.explanation),
          const SizedBox(height: 12),
          for (final (index, explanation)
              in question.choiceExplanations.indexed) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  index == question.correctIndex
                      ? Icons.check_circle_rounded
                      : index == selectedIndex
                      ? Icons.cancel_rounded
                      : Icons.circle_outlined,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${String.fromCharCode(65 + index)}. '
                    '${question.choices[index]}\n$explanation',
                  ),
                ),
              ],
            ),
            if (index != question.choiceExplanations.length - 1)
              const SizedBox(height: 6),
          ],
          const SizedBox(height: 8),
          Text(
            '출제 포인트 · ${question.skill}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    ),
  );
}

class _ExamResultView extends StatefulWidget {
  const _ExamResultView({
    required this.result,
    required this.pack,
    required this.onDone,
  });

  final ExamAttemptSummary result;
  final ExamPack? pack;
  final VoidCallback onDone;

  @override
  State<_ExamResultView> createState() => _ExamResultViewState();
}

class _ExamResultViewState extends State<_ExamResultView> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final questions = widget.pack?.questions ?? const <ExamQuestion>[];
    final byId = {for (final question in questions) question.id: question};
    final allReviews = <({ExamQuestion question, ExamAnswerRecord? answer})>[
      for (final questionId in widget.result.questionIds)
        if (byId[questionId] case final question?)
          (question: question, answer: widget.result.answers[questionId]),
    ];
    final wrongReviews = allReviews
        .where((entry) => entry.answer?.correct != true)
        .toList(growable: false);
    final reviewed = _showAll ? allReviews : wrongReviews;
    return Scaffold(
      appBar: AppBar(
        title: const Text('시험 결과'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          '${(widget.result.accuracy * 100).round()}%',
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '${widget.result.correctCount}개 정답 · '
                          '${widget.result.totalCount}문제',
                        ),
                        if (widget.result.answers.length <
                            widget.result.totalCount)
                          Text(
                            '미응답 '
                            '${widget.result.totalCount - widget.result.answers.length}개는 '
                            '오답으로 처리됐습니다.',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '문제 풀이',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    ChoiceChip(
                      label: Text('오답 ${wrongReviews.length}'),
                      selected: !_showAll,
                      onSelected: (_) => setState(() => _showAll = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('전체 ${allReviews.length}'),
                      selected: _showAll,
                      onSelected: (_) => setState(() => _showAll = true),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (reviewed.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.emoji_events_rounded),
                      title: Text('모두 맞혔습니다! 전체 풀이도 다시 볼 수 있어요.'),
                    ),
                  )
                else
                  for (final entry in reviewed)
                    Card(
                      child: ExpansionTile(
                        title: Text(
                          '${entry.question.part.label} · ${entry.question.prompt}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_resultAnswerLabel(entry.question, entry.answer)} · '
                          '정답 ${String.fromCharCode(65 + entry.question.correctIndex)} · '
                          '${entry.question.correctAnswer}',
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          18,
                          0,
                          18,
                          18,
                        ),
                        children: [
                          if (entry.question.stimulusId case final stimulusId?)
                            if (widget.pack?.stimuli[stimulusId]
                                case final stimulus?) ...[
                              _ReviewStimulus(stimulus: stimulus),
                              const SizedBox(height: 10),
                            ],
                          _ExplanationCard(
                            question: entry.question,
                            selectedIndex: entry.answer?.selectedIndex,
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: widget.onDone,
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('시험 연습으로 돌아가기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewStimulus extends StatelessWidget {
  const _ReviewStimulus({required this.stimulus});

  final ExamStimulus stimulus;

  @override
  Widget build(BuildContext context) {
    final text =
        stimulus.audioScript ?? stimulus.body ?? stimulus.visualDescription;
    if (text == null) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              stimulus.hasAudio
                  ? '듣기 원문'
                  : stimulus.kind == ExamStimulusKind.photo
                  ? '장면 설명'
                  : '지문',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            SelectableText(text),
          ],
        ),
      ),
    );
  }
}

String _resultAnswerLabel(ExamQuestion question, ExamAnswerRecord? answer) {
  if (answer == null) return '미응답';
  if (answer.correct) return '정답';
  return '선택 ${String.fromCharCode(65 + answer.selectedIndex)}';
}

String _durationLabel(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _difficultyLabel(ExamDifficulty value) => switch (value) {
  ExamDifficulty.foundation => '기초',
  ExamDifficulty.intermediate => '중급',
  ExamDifficulty.advanced => '고급',
};
