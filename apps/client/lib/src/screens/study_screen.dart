import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../domain/active_study_session.dart';
import '../domain/answer_normalizer.dart';
import '../domain/language.dart';
import '../domain/learning_item.dart';
import '../domain/study_history.dart';
import '../domain/study_preferences.dart';
import '../services/app_clock.dart';
import '../state/app_state.dart';
import '../state/connection_state.dart';

enum _ExerciseMode { recognition, production, cloze, sentenceOrder, listening }

enum _SessionManagementAction { restart, wrongAnswers, remaining, finish }

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({
    this.mode = StudyMode.mixed,
    this.unitIndex,
    this.resume = false,
    this.customPlan = false,
    super.key,
  });

  final StudyMode mode;
  final int? unitIndex;
  final bool resume;
  final bool customPlan;

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  final _answerController = TextEditingController();
  final _answerFocus = FocusNode();
  final _normalizer = const AnswerNormalizer();
  final _uuid = const Uuid();
  DateTime get _now => ref.read(appClockProvider)();
  final _tts = FlutterTts();

  late List<LearningItem> _queue;
  late int _plannedCount;
  late DateTime _sessionStartedAt;
  late String _sessionId;
  late ActiveStudySession _activeSession;
  var _sessionSaved = false;
  var _index = 0;
  var _sessionCorrect = 0;
  var _sessionWrong = 0;
  var _sessionXp = 0;
  var _completed = false;
  bool? _correct;
  String? _selectedChoice;
  var _remainingTokens = <String>[];
  var _orderedTokens = <String>[];
  final _wrongItemIds = <String>{};

  LearningItem get _item => _queue[_index];
  String get _returnRoute => widget.customPlan
      ? '/session-builder'
      : widget.unitIndex == null
      ? '/learn'
      : '/path';

  _ExerciseMode get _mode {
    switch (widget.mode) {
      case StudyMode.meaning:
        return _ExerciseMode.recognition;
      case StudyMode.production:
        return _ExerciseMode.production;
      case StudyMode.cloze:
        return _ExerciseMode.cloze;
      case StudyMode.sentenceOrder:
        return _ExerciseMode.sentenceOrder;
      case StudyMode.listening:
        return _ExerciseMode.listening;
      case StudyMode.mixed:
      case StudyMode.review:
      case StudyMode.weak:
      case StudyMode.favorites:
      case StudyMode.newItems:
      case StudyMode.words:
      case StudyMode.sentences:
        break;
    }
    final modes = <_ExerciseMode>[
      _ExerciseMode.recognition,
      _ExerciseMode.production,
      if (_item.kind == LearningItemKind.sentence &&
          _item.sentenceTokens.length >= 2 &&
          _item.capabilities.contains(ExerciseCapability.cloze))
        _ExerciseMode.cloze,
      if (_item.kind == LearningItemKind.sentence &&
          _item.sentenceTokens.length >= 2 &&
          _item.capabilities.contains(ExerciseCapability.sentenceOrder))
        _ExerciseMode.sentenceOrder,
    ];
    return modes[_index % modes.length];
  }

  bool get _isChoiceMode =>
      _mode == _ExerciseMode.recognition || _mode == _ExerciseMode.cloze;

  String get _clozeAnswer =>
      _item.sentenceTokens[_item.sentenceTokens.length ~/ 2];

  String get _expectedAnswer => switch (_mode) {
    _ExerciseMode.recognition => _item.primaryTranslation,
    _ExerciseMode.production => _item.text,
    _ExerciseMode.cloze => _clozeAnswer,
    _ExerciseMode.sentenceOrder => _item.text,
    _ExerciseMode.listening => _item.text,
  };

  @override
  void initState() {
    super.initState();
    final controller = ref.read(appControllerProvider.notifier);
    final active = widget.resume
        ? ref.read(appControllerProvider).activeStudySession
        : null;
    if (active != null) {
      _activeSession = active;
      final byId = {for (final item in controller.courseItems) item.id: item};
      _queue = active.itemIds
          .map((id) => byId[id])
          .whereType<LearningItem>()
          .toList(growable: true);
      _plannedCount = _queue.length;
      _sessionStartedAt = active.startedAt;
      _sessionId = active.sessionId;
      _sessionCorrect = active.correctCount;
      _sessionWrong = active.wrongCount;
      _sessionXp = active.earnedXp;
      _wrongItemIds.addAll(active.wrongItemIds);
      if (_queue.isNotEmpty) {
        if (active.currentIndex >= _queue.length) {
          _index = _queue.length - 1;
          _completed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            controller.clearActiveStudySession();
            unawaited(_saveSession());
          });
        } else {
          _index = active.currentIndex;
          _prepareExercise();
          if (active.phase == ActiveStudySessionPhase.paused) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final resumed = controller.resumeActiveStudySession(_now);
              if (resumed != null && mounted) {
                setState(() => _activeSession = resumed);
              }
            });
          }
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) controller.clearActiveStudySession();
        });
      }
    } else {
      _queue = List<LearningItem>.of(
        controller.queue(
          _now,
          mode: widget.mode,
          unitIndex: widget.unitIndex,
          sessionPlan: widget.customPlan
              ? ref
                    .read(appControllerProvider)
                    .preferences
                    .sessionPlan
                    .copyWith(mode: widget.mode)
              : null,
        ),
        growable: true,
      );
      if (_queue.isEmpty &&
          widget.mode == StudyMode.mixed &&
          !widget.customPlan) {
        _queue = widget.unitIndex == null
            ? controller.selectedItems
            : controller.itemsForUnit(widget.unitIndex!);
        _queue = _queue
            .take(ref.read(appControllerProvider).preferences.sessionItemLimit)
            .toList(growable: true);
      }
      _plannedCount = _queue.length;
      _sessionStartedAt = _now;
      _sessionId = _newSessionId();
      if (_queue.isNotEmpty) {
        _activeSession = ActiveStudySession.started(
          sessionId: _sessionId,
          courseId: ref.read(appControllerProvider).selectedLanguage.courseId,
          mode: widget.mode,
          unitIndex: widget.unitIndex,
          itemIds: _queue.map((item) => item.id).toList(growable: false),
          startedAt: _sessionStartedAt,
        );
        _prepareExercise();
        final initialItemIds = _queue
            .map((item) => item.id)
            .toList(growable: false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          controller.beginActiveStudySession(
            sessionId: _sessionId,
            mode: widget.mode,
            unitIndex: widget.unitIndex,
            itemIds: initialItemIds,
            startedAt: _sessionStartedAt,
          );
        });
      }
    }
    if (_queue.isNotEmpty &&
        !_completed &&
        widget.mode == StudyMode.listening) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    _answerFocus.dispose();
    unawaited(_tts.stop());
    super.dispose();
  }

  void _prepareExercise() {
    _selectedChoice = null;
    _answerController.clear();
    _orderedTokens = [];
    _remainingTokens = [..._item.sentenceTokens];
    _remainingTokens.shuffle(Random(_stableSeed(_item.id)));
  }

  int _stableSeed(String value) {
    var hash = 17;
    for (final codeUnit in value.codeUnits) {
      hash = 37 * hash + codeUnit;
    }
    return hash;
  }

  Future<void> _speak() async {
    await _tts.setLanguage(_item.learningLanguage.ttsLocale);
    await _tts.setSpeechRate(
      ref.read(appControllerProvider).preferences.ttsRate,
    );
    await _tts.speak(_item.text);
  }

  String _newSessionId() => 'session-${_uuid.v4()}';

  List<String> _choices() {
    final controller = ref.read(appControllerProvider.notifier);
    if (_mode == _ExerciseMode.cloze) {
      final alternatives = controller.selectedItems
          .where((candidate) => candidate.id != _item.id)
          .expand((candidate) => candidate.sentenceTokens)
          .where((token) => token != _clozeAnswer)
          .take(12)
          .toList();
      return <String>{_clozeAnswer, ...alternatives}.take(4).toList()..sort();
    }
    final alternatives = controller.selectedItems
        .where((candidate) => candidate.id != _item.id)
        .map((candidate) => candidate.primaryTranslation)
        .take(3)
        .toList();
    return <String>{_item.primaryTranslation, ...alternatives}.toList()..sort();
  }

  void _selectChoiceAt(int index) {
    if (_correct != null || !_isChoiceMode) return;
    final choices = _choices();
    if (index >= choices.length) return;
    setState(() => _selectedChoice = choices[index]);
  }

  void _appendToken(int index) {
    if (_correct != null || index >= _remainingTokens.length) return;
    setState(() {
      _orderedTokens.add(_remainingTokens.removeAt(index));
    });
  }

  void _removeOrderedToken(int index) {
    if (_correct != null || index >= _orderedTokens.length) return;
    setState(() {
      _remainingTokens.add(_orderedTokens.removeAt(index));
    });
  }

  void _submit() {
    if (_correct != null) {
      _next();
      return;
    }

    final answer = switch (_mode) {
      _ExerciseMode.recognition || _ExerciseMode.cloze => _selectedChoice ?? '',
      _ExerciseMode.production ||
      _ExerciseMode.listening => _answerController.text,
      _ExerciseMode.sentenceOrder => _joinTokens(
        _orderedTokens,
        _item.learningLanguage,
      ),
    };
    if (answer.trim().isEmpty) {
      if (_mode == _ExerciseMode.production ||
          _mode == _ExerciseMode.listening) {
        _answerFocus.requestFocus();
      }
      return;
    }
    final accepted = switch (_mode) {
      _ExerciseMode.recognition => _item.acceptedAnswers,
      _ExerciseMode.production => <String>[_item.text],
      _ExerciseMode.cloze => <String>[_clozeAnswer],
      _ExerciseMode.sentenceOrder => <String>[_item.text],
      _ExerciseMode.listening => <String>[_item.text],
    };
    final correct = _normalizer.matches(
      input: answer,
      acceptedAnswers: accepted,
      language: _mode == _ExerciseMode.recognition
          ? ref.read(appControllerProvider).selectedLanguage
          : _item.learningLanguage,
      policy: AnswerPolicy(
        allowTypo:
            _mode == _ExerciseMode.production ||
            _mode == _ExerciseMode.recognition ||
            _mode == _ExerciseMode.listening,
      ),
    );
    ref
        .read(appControllerProvider.notifier)
        .recordAnswer(
          item: _item,
          correct: correct,
          studiedAt: _now,
          exerciseType: _mode.name,
        );
    if (correct) {
      _sessionCorrect++;
      _sessionXp += 10;
    } else {
      _sessionWrong++;
      _sessionXp += 5;
      _wrongItemIds.add(_item.id);
    }
    if (!correct &&
        _queue.where((candidate) => candidate.id == _item.id).length < 2) {
      _queue.add(_item);
    }
    _persistActiveSession((_index + 1).clamp(0, _queue.length));
    setState(() => _correct = correct);
  }

  void _next() {
    if (_index + 1 >= _queue.length) {
      ref.read(appControllerProvider.notifier).clearActiveStudySession();
      unawaited(_saveSession());
      final connected = ref.read(appControllerProvider).driveConnected;
      if (connected) {
        unawaited(ref.read(connectionControllerProvider.notifier).syncNow());
      }
      setState(() => _completed = true);
      return;
    }
    setState(() {
      _index++;
      _correct = null;
      _prepareExercise();
    });
    _persistActiveSession(_index);
    if (_mode == _ExerciseMode.production) {
      _answerFocus.requestFocus();
    } else if (_mode == _ExerciseMode.listening) {
      unawaited(_speak());
    }
  }

  Future<void> _saveSession() async {
    if (_sessionSaved || _sessionCorrect + _sessionWrong == 0) return;
    _sessionSaved = true;
    await ref
        .read(appControllerProvider.notifier)
        .finishSession(
          StudySessionSummary(
            sessionId: _sessionId,
            courseId: ref.read(appControllerProvider).selectedLanguage.courseId,
            startedAt: _sessionStartedAt,
            endedAt: _now,
            correctCount: _sessionCorrect,
            wrongCount: _sessionWrong,
            earnedXp: _sessionXp,
            origin: _activeSession.origin,
            rootSessionId: _activeSession.lineageRootId,
            parentSessionId: _activeSession.parentSessionId,
            generation: _activeSession.generation,
            pauseCount: _activeSession.pauseCount,
            resumeCount: _activeSession.resumeCount,
            journey: _activeSession.journey,
          ),
        );
  }

  void _pauseAndExit() {
    final nextIndex = _correct == null ? _index : _index + 1;
    final paused = ref
        .read(appControllerProvider.notifier)
        .pauseActiveStudySession(
          _now,
          itemIds: _queue.map((item) => item.id).toList(growable: false),
          currentIndex: nextIndex.clamp(0, _queue.length),
          correctCount: _sessionCorrect,
          wrongCount: _sessionWrong,
          earnedXp: _sessionXp,
          wrongItemIds: _wrongItemIds,
        );
    if (paused != null) _activeSession = paused;
    if (ref.read(appControllerProvider).driveConnected) {
      unawaited(ref.read(connectionControllerProvider.notifier).syncNow());
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _persistActiveSession(int currentIndex) {
    if (_queue.isEmpty || _completed) return;
    final next = ref
        .read(appControllerProvider.notifier)
        .updateActiveStudySession(
          itemIds: _queue.map((item) => item.id).toList(growable: false),
          currentIndex: currentIndex,
          correctCount: _sessionCorrect,
          wrongCount: _sessionWrong,
          earnedXp: _sessionXp,
          wrongItemIds: _wrongItemIds,
          updatedAt: _now,
        );
    if (next != null) _activeSession = next;
  }

  Future<void> _retryMistakes() async {
    final mistakeIds = _orderedUnique([
      for (final item in _queue)
        if (_wrongItemIds.contains(item.id)) item.id,
    ]);
    if (mistakeIds.isEmpty) return;
    await _deriveSession(StudySessionOrigin.wrongAnswers, mistakeIds);
  }

  Future<void> _deriveSession(
    StudySessionOrigin origin,
    List<String> itemIds,
  ) async {
    final uniqueItemIds = _orderedUnique(itemIds);
    if (uniqueItemIds.isEmpty) return;
    final byId = {
      for (final item in ref.read(appControllerProvider.notifier).courseItems)
        item.id: item,
    };
    final nextQueue = uniqueItemIds
        .map((id) => byId[id])
        .whereType<LearningItem>()
        .toList(growable: true);
    if (nextQueue.isEmpty) return;
    await _saveSession();
    if (!mounted) return;
    final startedAt = _now;
    final newSessionId = _newSessionId();
    final next = ref
        .read(appControllerProvider.notifier)
        .deriveActiveStudySession(
          source: _activeSession,
          sessionId: newSessionId,
          origin: origin,
          itemIds: nextQueue.map((item) => item.id).toList(growable: false),
          startedAt: startedAt,
        );
    setState(() {
      _activeSession = next;
      _queue = nextQueue;
      _plannedCount = _queue.length;
      _index = 0;
      _sessionCorrect = 0;
      _sessionWrong = 0;
      _sessionXp = 0;
      _completed = false;
      _correct = null;
      _wrongItemIds.clear();
      _sessionStartedAt = startedAt;
      _sessionId = newSessionId;
      _sessionSaved = false;
      _prepareExercise();
    });
    if (_mode == _ExerciseMode.listening) unawaited(_speak());
  }

  Future<void> _finishCurrentSession() async {
    final nextIndex = _correct == null ? _index : _index + 1;
    _persistActiveSession(nextIndex.clamp(0, _queue.length));
    await _saveSession();
    if (!mounted) return;
    ref.read(appControllerProvider.notifier).clearActiveStudySession();
    if (ref.read(appControllerProvider).driveConnected) {
      unawaited(ref.read(connectionControllerProvider.notifier).syncNow());
    }
    context.go('/home');
  }

  Future<void> _showSessionManager() async {
    final nextIndex = (_correct == null ? _index : _index + 1).clamp(
      0,
      _queue.length,
    );
    final remainingIds = _orderedUnique([
      for (final item in _queue.skip(nextIndex)) item.id,
    ]);
    final wrongIds = _orderedUnique([
      for (final item in _queue)
        if (_wrongItemIds.contains(item.id)) item.id,
    ]);
    final action = await showModalBottomSheet<_SessionManagementAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _SessionManagementSheet(
        session: _activeSession,
        wrongCount: wrongIds.length,
        remainingCount: remainingIds.length,
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _SessionManagementAction.restart:
        await _deriveSession(
          StudySessionOrigin.restarted,
          _activeSession.originalItemIds,
        );
      case _SessionManagementAction.wrongAnswers:
        await _deriveSession(StudySessionOrigin.wrongAnswers, wrongIds);
      case _SessionManagementAction.remaining:
        await _deriveSession(StudySessionOrigin.remaining, remainingIds);
      case _SessionManagementAction.finish:
        await _finishCurrentSession();
    }
  }

  List<String> _orderedUnique(Iterable<String> values) {
    final seen = <String>{};
    return [
      for (final value in values)
        if (seen.add(value)) value,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.go(_returnRoute),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  size: 54,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  widget.customPlan
                      ? '조건에 맞는 표현이 없어요'
                      : widget.mode == StudyMode.favorites
                      ? '아직 저장한 표현이 없어요'
                      : '오늘 학습을 모두 마쳤어요',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.customPlan
                      ? '세션 빌더에서 덱·난이도·태그 조건을 조금 넓혀 보세요.'
                      : widget.mode == StudyMode.favorites
                      ? '단어장에서 외우고 싶은 표현의 별표를 누르면 이곳에 모입니다.'
                      : '새 콘텐츠를 가져오거나 다른 언어 코스를 선택해 보세요.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.go(
                    widget.mode == StudyMode.favorites
                        ? '/library'
                        : _returnRoute,
                  ),
                  icon: Icon(
                    widget.mode == StudyMode.favorites
                        ? Icons.star_border_rounded
                        : Icons.arrow_back_rounded,
                  ),
                  label: Text(
                    widget.mode == StudyMode.favorites
                        ? '단어장에서 표현 저장'
                        : widget.customPlan
                        ? '세션 빌더로 돌아가기'
                        : widget.unitIndex == null
                        ? '학습실로 돌아가기'
                        : '코스 여정으로',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_completed) {
      final attempts = _sessionCorrect + _sessionWrong;
      final accuracy = attempts == 0
          ? 0
          : (_sessionCorrect / attempts * 100).round();
      final elapsed = max(1, _now.difference(_sessionStartedAt).inMinutes);
      return _CompletionScreen(
        correct: _sessionCorrect,
        wrong: _sessionWrong,
        xp: _sessionXp,
        accuracy: accuracy,
        minutes: elapsed,
        plannedCount: _plannedCount,
        hasMistakes: _wrongItemIds.isNotEmpty,
        onRetryMistakes: _retryMistakes,
        onHome: () => context.go(_returnRoute),
        returnLabel: widget.customPlan
            ? '세션 빌더로 돌아가기'
            : widget.unitIndex == null
            ? '학습실로 돌아가기'
            : '코스 여정으로',
        returnIcon: widget.customPlan
            ? Icons.tune_rounded
            : widget.unitIndex == null
            ? Icons.grid_view_rounded
            : Icons.route_rounded,
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _submit,
        const SingleActivator(LogicalKeyboardKey.space): _speak,
        const SingleActivator(LogicalKeyboardKey.escape): _pauseAndExit,
        const SingleActivator(LogicalKeyboardKey.digit1): () =>
            _selectChoiceAt(0),
        const SingleActivator(LogicalKeyboardKey.digit2): () =>
            _selectChoiceAt(1),
        const SingleActivator(LogicalKeyboardKey.digit3): () =>
            _selectChoiceAt(2),
        const SingleActivator(LogicalKeyboardKey.digit4): () =>
            _selectChoiceAt(3),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _answerFocus.requestFocus(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              key: const Key('pause-study-session'),
              onPressed: _pauseAndExit,
              icon: const Icon(Icons.pause_rounded),
              tooltip: '일시정지하고 홈으로 (Esc)',
            ),
            titleSpacing: 4,
            title: Semantics(
              label: '학습 진행 ${_index + 1}/${_queue.length}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_index + 1) / _queue.length,
                  minHeight: 9,
                ),
              ),
            ),
            actions: [
              IconButton(
                key: const Key('open-session-management'),
                onPressed: _showSessionManager,
                icon: const Icon(Icons.more_horiz_rounded),
                tooltip: '세션 관리',
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 18),
                child: Center(
                  child: Text(
                    '${_index + 1} / ${_queue.length}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth < 600 ? 16 : 24,
                    12,
                    constraints.maxWidth < 600 ? 16 : 24,
                    24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              _ExercisePill(
                                icon: _modeIcon,
                                label: _instruction,
                              ),
                              const Spacer(),
                              Text(
                                '${_item.learningLanguage.symbol} · ${_item.kind == LearningItemKind.word ? '단어' : '문장'}',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Card(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: constraints.maxWidth < 600
                                    ? 18
                                    : 30,
                                vertical: constraints.maxWidth < 600 ? 24 : 34,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _prompt,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.displaySmall,
                                  ),
                                  if (ref
                                          .watch(appControllerProvider)
                                          .preferences
                                          .showReadingAids &&
                                      _mode == _ExerciseMode.recognition &&
                                      _item.readings.isNotEmpty) ...[
                                    const SizedBox(height: 9),
                                    Text(
                                      _item.readings
                                          .map((value) => value.value)
                                          .join(' · '),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                    onPressed: _speak,
                                    icon: const Icon(
                                      Icons.volume_up_rounded,
                                      size: 20,
                                    ),
                                    label: const Text('발음 듣기'),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Space',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outline,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _exerciseInput(),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: _StudyActionBar(
            correct: _correct,
            answer: _expectedAnswer,
            onPressed: _submit,
          ),
        ),
      ),
    );
  }

  String get _instruction => switch (_mode) {
    _ExerciseMode.recognition => '알맞은 뜻을 고르세요',
    _ExerciseMode.production => '외국어로 입력하세요',
    _ExerciseMode.cloze => '빈칸에 들어갈 표현을 고르세요',
    _ExerciseMode.sentenceOrder => '단어를 순서대로 배열하세요',
    _ExerciseMode.listening => '소리를 듣고 받아쓰세요',
  };

  IconData get _modeIcon => switch (_mode) {
    _ExerciseMode.recognition => Icons.touch_app_rounded,
    _ExerciseMode.production => Icons.keyboard_rounded,
    _ExerciseMode.cloze => Icons.space_bar_rounded,
    _ExerciseMode.sentenceOrder => Icons.reorder_rounded,
    _ExerciseMode.listening => Icons.headphones_rounded,
  };

  String get _prompt => switch (_mode) {
    _ExerciseMode.recognition => _item.text,
    _ExerciseMode.production ||
    _ExerciseMode.sentenceOrder => _item.primaryTranslation,
    _ExerciseMode.listening => '재생 버튼을 눌러 듣고 입력하세요',
    _ExerciseMode.cloze => _joinTokens([
      for (var index = 0; index < _item.sentenceTokens.length; index++)
        index == _item.sentenceTokens.length ~/ 2
            ? '_____'
            : _item.sentenceTokens[index],
    ], _item.learningLanguage),
  };

  Widget _exerciseInput() {
    if (_isChoiceMode) {
      return Column(
        children: [
          for (final (index, choice) in _choices().indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChoiceButton(
                shortcut: '${index + 1}',
                label: choice,
                selected: _selectedChoice == choice,
                submitted: _correct != null,
                correctAnswer: choice == _expectedAnswer,
                onPressed: _correct == null
                    ? () => setState(() => _selectedChoice = choice)
                    : null,
              ),
            ),
        ],
      );
    }
    if (_mode == _ExerciseMode.sentenceOrder) {
      return _SentenceOrderInput(
        selected: _orderedTokens,
        remaining: _remainingTokens,
        enabled: _correct == null,
        onSelectedTap: _removeOrderedToken,
        onRemainingTap: _appendToken,
      );
    }
    return TextField(
      controller: _answerController,
      focusNode: _answerFocus,
      enabled: _correct == null,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.edit_rounded),
        labelText: '${_item.learningLanguage.koreanName} 답안',
        hintText: '정답을 입력하세요',
        helperText: '철자와 띄어쓰기를 확인한 뒤 Enter를 누르세요.',
      ),
    );
  }
}

class _SessionManagementSheet extends StatelessWidget {
  const _SessionManagementSheet({
    required this.session,
    required this.wrongCount,
    required this.remainingCount,
  });

  final ActiveStudySession session;
  final int wrongCount;
  final int remainingCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('세션 관리', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 5),
                Text(
                  '${session.origin.label} · ${session.completedCount}/${session.itemIds.length}문제'
                  '${session.generation == 0 ? '' : ' · ${session.generation}단계 분기'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (session.pauseCount + session.resumeCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '일시정지 ${session.pauseCount}회 · 이어하기 ${session.resumeCount}회',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                _SessionManagementTile(
                  key: const Key('restart-study-session'),
                  icon: Icons.restart_alt_rounded,
                  title: '처음 문제 묶음으로 다시 시작',
                  subtitle: '현재 시도는 기록하고 최초 문제 순서로 새 세션을 만듭니다.',
                  onTap: () =>
                      Navigator.pop(context, _SessionManagementAction.restart),
                ),
                const SizedBox(height: 8),
                _SessionManagementTile(
                  key: const Key('branch-wrong-session'),
                  icon: Icons.error_outline_rounded,
                  title: '오답 $wrongCount개만 집중',
                  subtitle: wrongCount == 0
                      ? '아직 틀린 문제가 없습니다.'
                      : '지금까지 틀린 표현만 모아 짧은 분기 세션을 만듭니다.',
                  onTap: wrongCount == 0
                      ? null
                      : () => Navigator.pop(
                          context,
                          _SessionManagementAction.wrongAnswers,
                        ),
                ),
                const SizedBox(height: 8),
                _SessionManagementTile(
                  key: const Key('branch-remaining-session'),
                  icon: Icons.call_split_rounded,
                  title: '남은 문제 $remainingCount개로 분기',
                  subtitle: remainingCount == 0
                      ? '남은 문제가 없습니다.'
                      : '이미 푼 문제는 빼고 남은 표현으로 새 세션을 만듭니다.',
                  onTap: remainingCount == 0
                      ? null
                      : () => Navigator.pop(
                          context,
                          _SessionManagementAction.remaining,
                        ),
                ),
                const SizedBox(height: 8),
                _SessionManagementTile(
                  key: const Key('finish-study-session'),
                  icon: Icons.stop_circle_outlined,
                  title: '현재 세션 종료',
                  subtitle: '푼 문제는 최근 기록에 남기고 이어하기 목록에서 제거합니다.',
                  color: colors.error,
                  onTap: () =>
                      Navigator.pop(context, _SessionManagementAction.finish),
                ),
                const SizedBox(height: 12),
                Text(
                  '그냥 쉬려면 이 창을 닫고 왼쪽 위 일시정지를 누르세요. 현재 위치는 로컬에 즉시 저장됩니다.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionManagementTile extends StatelessWidget {
  const _SessionManagementTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final tone = enabled
        ? color ?? Theme.of(context).colorScheme.primary
        : Theme.of(context).disabledColor;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: enabled ? null : Theme.of(context).disabledColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: enabled ? null : Theme.of(context).disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: tone),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudyActionBar extends StatelessWidget {
  const _StudyActionBar({
    required this.correct,
    required this.answer,
    required this.onPressed,
  });

  final bool? correct;
  final String answer;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        color: colors.surface,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final feedback = AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: correct == null
                        ? Text(
                            '답을 고른 뒤 확인하세요.',
                            key: const ValueKey('study-hint'),
                            style: Theme.of(context).textTheme.bodySmall,
                          )
                        : _FeedbackCard(
                            key: ValueKey(correct),
                            correct: correct!,
                            answer: answer,
                          ),
                  );
                  final button = FilledButton.icon(
                    onPressed: onPressed,
                    icon: Icon(
                      correct == null
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(correct == null ? '정답 확인' : '다음 문제'),
                  );
                  if (constraints.maxWidth < 620) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (correct != null) ...[
                          feedback,
                          const SizedBox(height: 10),
                        ],
                        button,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: feedback),
                      const SizedBox(width: 16),
                      SizedBox(width: 190, child: button),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _joinTokens(List<String> tokens, LanguageTag language) {
  final separator = LanguageProfile.of(language).usesSpaces ? ' ' : '';
  return tokens.join(separator);
}

class _ExercisePill extends StatelessWidget {
  const _ExercisePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: colors.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionScreen extends StatelessWidget {
  const _CompletionScreen({
    required this.correct,
    required this.wrong,
    required this.xp,
    required this.accuracy,
    required this.minutes,
    required this.plannedCount,
    required this.hasMistakes,
    required this.onRetryMistakes,
    required this.onHome,
    required this.returnLabel,
    required this.returnIcon,
  });

  final int correct;
  final int wrong;
  final int xp;
  final int accuracy;
  final int minutes;
  final int plannedCount;
  final bool hasMistakes;
  final VoidCallback onRetryMistakes;
  final VoidCallback onHome;
  final String returnLabel;
  final IconData returnIcon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final excellent = accuracy >= 80;
    final accent = excellent
        ? const Color(0xFF238B57)
        : const Color(0xFFD97706);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(constraints.maxWidth < 600 ? 18 : 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 720,
                    minHeight: max(0, constraints.maxHeight - 56),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox.square(
                          dimension: 104,
                          child: Icon(
                            excellent
                                ? Icons.emoji_events_rounded
                                : Icons.auto_awesome_rounded,
                            size: 52,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        excellent ? '오늘 학습, 멋지게 완료!' : '한 걸음 더 기억했어요',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '$plannedCount개로 시작한 세션의 결과예요. '
                        '${hasMistakes ? '틀린 표현은 바로 다시 다질 수 있어요.' : '모든 표현을 정확히 기억했어요.'}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 26),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: LayoutBuilder(
                            builder: (context, cardConstraints) {
                              final compact = cardConstraints.maxWidth < 520;
                              final metrics = [
                                (
                                  '정확도',
                                  '$accuracy%',
                                  Icons.track_changes_rounded,
                                ),
                                ('정답', '$correct', Icons.check_circle_rounded),
                                ('획득 XP', '+$xp', Icons.bolt_rounded),
                                ('소요 시간', '$minutes분', Icons.timer_outlined),
                              ];
                              return GridView.count(
                                crossAxisCount: compact ? 2 : 4,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: compact ? 1.55 : 1.15,
                                children: [
                                  for (final metric in metrics)
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: colors.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              metric.$3,
                                              color: colors.primary,
                                              size: 21,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              metric.$2,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                            ),
                                            Text(
                                              metric.$1,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      if (wrong > 0) ...[
                        const SizedBox(height: 12),
                        Text(
                          '오답 $wrong회는 복습 일정에 자동 반영됐습니다.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: onHome,
                          icon: Icon(returnIcon),
                          label: Text(returnLabel),
                        ),
                      ),
                      if (hasMistakes) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: onRetryMistakes,
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('틀린 문제만 다시 풀기'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SentenceOrderInput extends StatelessWidget {
  const _SentenceOrderInput({
    required this.selected,
    required this.remaining,
    required this.enabled,
    required this.onSelectedTap,
    required this.onRemainingTap,
  });

  final List<String> selected;
  final List<String> remaining;
  final bool enabled;
  final ValueChanged<int> onSelectedTap;
  final ValueChanged<int> onRemainingTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: selected.isEmpty
              ? const Center(child: Text('아래 단어를 눌러 문장을 만드세요'))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (index, token) in selected.indexed)
                      ActionChip(
                        onPressed: enabled ? () => onSelectedTap(index) : null,
                        label: Text(token),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final (index, token) in remaining.indexed)
              ActionChip(
                onPressed: enabled ? () => onRemainingTap(index) : null,
                label: Text(token),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.shortcut,
    required this.label,
    required this.selected,
    required this.submitted,
    required this.correctAnswer,
    required this.onPressed,
  });

  final String shortcut;
  final String label;
  final bool selected;
  final bool submitted;
  final bool correctAnswer;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final showCorrect = submitted && correctAnswer;
    final showWrong = submitted && selected && !correctAnswer;
    final accent = showCorrect
        ? const Color(0xFF238B57)
        : showWrong
        ? const Color(0xFFC2414B)
        : selected
        ? colors.primary
        : colors.outline;
    final background = showCorrect
        ? const Color(0xFFE8F5ED)
        : showWrong
        ? const Color(0xFFFFECEE)
        : selected
        ? colors.primaryContainer
        : colors.surface;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        alignment: Alignment.centerLeft,
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        disabledForegroundColor: colors.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        side: BorderSide(color: accent, width: selected || showCorrect ? 2 : 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              shortcut,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (showCorrect)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF238B57))
          else if (showWrong)
            const Icon(Icons.cancel_rounded, color: Color(0xFFC2414B))
          else if (selected)
            Icon(Icons.radio_button_checked_rounded, color: colors.primary),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.correct, required this.answer, super.key});

  final bool correct;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final color = correct ? const Color(0xFF238B57) : const Color(0xFFC2414B);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 36,
                child: Icon(
                  correct ? Icons.check_rounded : Icons.refresh_rounded,
                  color: color,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    correct ? '정답이에요 · +10 XP' : '한 번 더 기억해 볼까요?',
                    style: TextStyle(color: color, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    correct ? '좋아요. 다음 복습 간격이 늘어났어요.' : '정답: $answer',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
