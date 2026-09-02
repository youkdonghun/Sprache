import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../domain/course_path.dart';
import '../domain/learning_item.dart';
import '../domain/learning_group.dart';
import '../domain/quiz_session_support.dart';
import '../domain/session_enhancements.dart';
import '../domain/study_interaction_preferences.dart';
import '../domain/study_limits.dart';
import '../domain/study_preferences.dart';
import '../domain/study_routines.dart';
import '../domain/study_session_builder.dart';
import '../services/app_clock.dart';
import '../services/study_notification_service.dart';
import '../state/app_state.dart';

enum _SessionContentKind { mixed, words, sentences }

enum _BuilderHeaderAction { reset }

enum _BottomSessionAction { save, schedule }

enum _SavedPlanAction { load, moveEarlier, moveLater, delete }

enum _ManualSelectionAction { selectVisible, clear }

class _SelectionOption<T> {
  const _SelectionOption({
    required this.value,
    required this.label,
    this.icon,
    this.key,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Key? key;
}

class SessionBuilderScreen extends ConsumerStatefulWidget {
  const SessionBuilderScreen({super.key});

  @override
  ConsumerState<SessionBuilderScreen> createState() =>
      _SessionBuilderScreenState();
}

class _SessionBuilderScreenState extends ConsumerState<SessionBuilderScreen> {
  static const _exerciseModes = [
    StudyMode.mixed,
    StudyMode.meaning,
    StudyMode.production,
    StudyMode.cloze,
    StudyMode.sentenceOrder,
    StudyMode.listening,
    StudyMode.pronunciation,
  ];
  final _titleController = TextEditingController();
  var _plan = const StudySessionPlan();
  var _initialized = false;

  void _setPlan(StudySessionPlan plan, {bool syncTitle = false}) {
    final normalized =
        !plan.mode.allowsAnswerDirectionOverride &&
            plan.answerDirectionOverride != null
        ? plan.copyWith(answerDirectionOverride: null)
        : plan;
    if (syncTitle && _titleController.text != normalized.title) {
      _titleController.text = normalized.title;
    }
    setState(() => _plan = normalized);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _resetAdvancedSettings() {
    _setPlan(
      _plan.copyWith(
        difficulty: StudyDifficulty.all,
        queuePriority: StudyQueuePriority.dueFirst,
        historyFilter: StudyHistoryFilter.all,
        groupIds: {},
        tags: {},
        levels: {},
        sentenceRatio: _defaultSentenceRatio(_plan),
        recordProgress: true,
        answerDirectionOverride: null,
        gradingStrictness: StudyGradingStrictness.balanced,
        choiceCount: 4,
        hintsEnabled: true,
        autoAdvanceOverride: null,
        soundEffectsOverride: null,
        largeControls: false,
        backlogRecovery: const BacklogRecoverySettings(),
        examSchedule: null,
      ),
    );
  }

  Future<void> _savePlan() async {
    final controller = ref.read(appControllerProvider.notifier);
    final saved = controller.saveSessionPlan(_plan);
    final hasFutureSchedule =
        saved.scheduledAt?.isAfter(DateTime.now().toUtc()) ?? false;
    final permission = hasFutureSchedule
        ? await controller.requestStudyNotificationPermission()
        : StudyNotificationPermission.unavailable;
    if (!mounted) return;
    _setPlan(saved, syncTitle: true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    final message = !hasFutureSchedule
        ? '“${saved.title}” 학습 설정을 저장했습니다.'
        : switch (permission) {
            StudyNotificationPermission.granted =>
              '“${saved.title}” 일정과 기기 알림을 저장했습니다.',
            StudyNotificationPermission.denied =>
              '“${saved.title}” 일정은 저장했습니다. 알림 권한을 켜면 시간에 맞춰 알려드려요.',
            StudyNotificationPermission.unavailable =>
              '“${saved.title}” 일정은 저장했습니다. 이 기기에서는 알림을 예약하지 못했습니다.',
          };
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.sizeOf(context).width < 900 ? 148 : 16,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _loadSavedPlan(StudySessionPlan plan) {
    final loaded = ref
        .read(appControllerProvider.notifier)
        .useSavedSessionPlan(plan);
    if (loaded == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 학습 주제에서는 사용할 수 없는 일정이에요.')),
      );
      return;
    }
    _setPlan(loaded, syncTitle: true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('“${loaded.title}” 설정을 불러왔어요.')));
  }

  Future<void> _deleteSavedPlan(StudySessionPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('저장한 일정 삭제'),
        content: Text('“${plan.title}” 일정을 삭제할까요?\n학습 기록과 자료는 그대로 남아요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('confirm-delete-session-plan'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('일정 삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    ref
        .read(appControllerProvider.notifier)
        .deleteSavedSessionPlan(plan.planId);
    if (_plan.planId == plan.planId) {
      _setPlan(_plan.copyWith(planId: ''), syncTitle: true);
    }
  }

  void _start(StudySessionBuildResult preview) {
    if (preview.isEmpty) return;
    final controller = ref.read(appControllerProvider.notifier);
    if (_plan.planId.isNotEmpty && _plan.scheduledAt != null) {
      final consumed = controller.consumeScheduledSessionPlan(_plan.planId);
      if (consumed != null) {
        _setPlan(consumed);
      } else {
        controller.updateSessionPlan(_plan);
      }
    } else {
      controller.updateSessionPlan(_plan);
    }
    context.push(
      _plan.mode == StudyMode.pronunciation
          ? '/pronunciation?custom=true'
          : '/study?mode=${_plan.mode.name}&custom=true',
    );
  }

  Future<void> _saveForLater() async {
    final hasFutureSchedule =
        _plan.scheduledAt?.isAfter(DateTime.now().toUtc()) ?? false;
    if (!hasFutureSchedule && !await _pickSchedule()) return;
    await _savePlan();
  }

  Future<bool> _pickSchedule() async {
    final now = DateTime.now();
    final initial =
        _plan.scheduledAt?.toLocal() ?? now.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return false;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return false;
    _setPlan(
      _plan.copyWith(
        scheduledAt: DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ).toUtc(),
      ),
    );
    return true;
  }

  Future<void> _configureRoutine() async {
    final nameController = TextEditingController(
      text: _plan.routineName.isEmpty ? '나의 학습 루틴' : _plan.routineName,
    );
    var weekdays = _plan.routineWeekdays.isEmpty
        ? <int>{DateTime.monday, DateTime.wednesday, DateTime.friday}
        : {..._plan.routineWeekdays};
    final scheduled = _plan.scheduledAt?.toLocal();
    var minuteOfDay =
        _plan.routineMinuteOfDay ??
        (scheduled == null ? 19 * 60 : scheduled.hour * 60 + scheduled.minute);
    final result = await showDialog<StudySessionPlan>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('주간 학습 루틴'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('routine-name-field'),
                  controller: nameController,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: '루틴 이름',
                    hintText: '예: 출근 전 회화',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final day in const [
                      (DateTime.monday, '월'),
                      (DateTime.tuesday, '화'),
                      (DateTime.wednesday, '수'),
                      (DateTime.thursday, '목'),
                      (DateTime.friday, '금'),
                      (DateTime.saturday, '토'),
                      (DateTime.sunday, '일'),
                    ])
                      FilterChip(
                        key: Key('routine-weekday-${day.$1}'),
                        label: Text(day.$2),
                        selected: weekdays.contains(day.$1),
                        onSelected: (selected) => setDialogState(() {
                          if (selected) {
                            weekdays.add(day.$1);
                          } else if (weekdays.length > 1) {
                            weekdays.remove(day.$1);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('routine-time-picker'),
                  onPressed: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: minuteOfDay ~/ 60,
                        minute: minuteOfDay % 60,
                      ),
                    );
                    if (selected != null) {
                      setDialogState(
                        () =>
                            minuteOfDay = selected.hour * 60 + selected.minute,
                      );
                    }
                  },
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(
                    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
                    '${(minuteOfDay % 60).toString().padLeft(2, '0')}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (_plan.routineName.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _plan.copyWith(
                    routineName: '',
                    routineWeekdays: {},
                    routineMinuteOfDay: null,
                    routineOrder: 0,
                  ),
                ),
                child: const Text('루틴 끄기'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            FilledButton(
              key: const Key('apply-routine'),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty || weekdays.isEmpty) return;
                final candidate = _plan.copyWith(
                  routineName: name,
                  routineWeekdays: weekdays,
                  routineMinuteOfDay: minuteOfDay,
                );
                Navigator.pop(
                  dialogContext,
                  candidate.copyWith(
                    scheduledAt: nextRoutineOccurrence(
                      candidate,
                      after: DateTime.now(),
                    ),
                  ),
                );
              },
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    if (result != null && mounted) _setPlan(result);
  }

  void _moveRoutinePlan(StudySessionPlan plan, int delta) {
    final routine = groupStudyRoutines(
      ref.read(appControllerProvider.notifier).activeSubjectSavedSessionPlans,
    ).where((group) => group.name == plan.routineName).firstOrNull;
    if (routine == null) return;
    final ids = routine.plans.map((entry) => entry.planId).toList();
    final index = ids.indexOf(plan.planId);
    final target = (index + delta).clamp(0, ids.length - 1);
    if (index < 0 || target == index) return;
    final moved = ids.removeAt(index);
    ids.insert(target, moved);
    ref
        .read(appControllerProvider.notifier)
        .reorderRoutineSessionPlans(plan.routineName, ids);
  }

  Future<void> _pickExamTargetDate() async {
    final now = DateTime.now();
    final initial =
        _plan.examSchedule?.targetDate.toLocal() ??
        now.add(const Duration(days: 30));
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 3650)),
      helpText: '목표일 선택',
    );
    if (date == null || !mounted) return;
    final previous = _plan.examSchedule;
    _setPlan(
      _plan.copyWith(
        examSchedule:
            (previous ??
                    ExamSchedule(
                      targetDate: date.toUtc(),
                      startDate: now.toUtc(),
                    ))
                .copyWith(
                  targetDate: date.toUtc(),
                  startDate: previous?.startDate ?? now.toUtc(),
                  updatedAt: now.toUtc(),
                ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final activeSubject = controller.activeSubject;
    final subjectChanged =
        _initialized && _plan.subjectId != appState.activeSubjectId;
    if ((!_initialized || subjectChanged) && appState.isHydrated) {
      _plan = controller.activeSessionPlan;
      _titleController.text = _plan.title;
      _initialized = true;
    }
    final now = ref.read(appClockProvider)();
    final preview = controller.previewSessionPlan(_plan, now);
    final units = controller.coursePath.units;
    final tags = controller.availableSessionTags;
    final levels = controller.availableSessionLevels;
    final learningGroups = controller.availableLearningGroupDefinitions;
    final averageSecondsPerItem = controller.averageSecondsPerStudyItem;
    final selectableItems = controller.selectedItems;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          final padding = constraints.maxWidth < 620 ? 18.0 : 28.0;
          final editor = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QuickSessionPresets(
                onSelected: (preset) => _setPlan(
                  preset.copyWith(
                    subjectId: appState.activeSubjectId,
                    planId: '',
                    title: '',
                    scheduledAt: null,
                  ),
                  syncTitle: true,
                ),
              ),
              const SizedBox(height: 14),
              _BuilderSection(
                number: '1',
                title: '어떤 방식으로 풀까요?',
                description: '이번 세션에서 풀 문제 방식을 하나 골라 주세요.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CompactSelectionField<StudyMode>(
                      fieldKey: const Key('session-mode-select'),
                      label: '풀 방식',
                      value: _plan.mode,
                      helperText: _plan.mode.description,
                      prefixIcon: Icons.quiz_outlined,
                      options: [
                        if (!_exerciseModes.contains(_plan.mode))
                          _SelectionOption(
                            key: Key('session-mode-${_plan.mode.name}'),
                            value: _plan.mode,
                            label: _plan.mode.label,
                          ),
                        for (final mode in _exerciseModes)
                          _SelectionOption(
                            key: Key('session-mode-${mode.name}'),
                            value: mode,
                            label: mode.label,
                          ),
                      ],
                      onChanged: (mode) => _setPlan(_plan.copyWith(mode: mode)),
                    ),
                    const SizedBox(height: 14),
                    _AnswerDirectionEditor(plan: _plan, onChanged: _setPlan),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _BuilderSection(
                number: '2',
                title: '어떤 자료로 연습할까요?',
                description: '코스, 단원, 별표, 직접 추가한 표현 중에서 골라요.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CompactSelectionField<StudyDeckScope>(
                      fieldKey: const Key('session-deck-select'),
                      label: '학습할 자료',
                      value: _plan.deck,
                      helperText: _plan.deck.description,
                      prefixIcon: Icons.folder_open_rounded,
                      options: [
                        for (final deck in StudyDeckScope.values)
                          _SelectionOption(
                            key: Key('session-deck-${deck.name}'),
                            value: deck,
                            label: deck.label,
                            icon: switch (deck) {
                              StudyDeckScope.course => Icons.language_rounded,
                              StudyDeckScope.unit => Icons.view_module_rounded,
                              StudyDeckScope.favorites => Icons.star_rounded,
                              StudyDeckScope.personal => Icons.person_rounded,
                              StudyDeckScope.selected =>
                                Icons.checklist_rounded,
                            },
                          ),
                      ],
                      onChanged: (deck) => _setPlan(_plan.copyWith(deck: deck)),
                    ),
                    if (_plan.deck == StudyDeckScope.unit) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        key: ValueKey('session-unit-${_plan.unitIndex}'),
                        initialValue: _plan.unitIndex ?? 0,
                        decoration: const InputDecoration(
                          labelText: '단원 덱',
                          prefixIcon: Icon(Icons.route_rounded),
                        ),
                        items: [
                          for (final unit in units)
                            DropdownMenuItem(
                              value: unit.index,
                              child: Text(
                                'Unit ${unit.index + 1} · ${unit.title}',
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            _setPlan(_plan.copyWith(unitIndex: value));
                          }
                        },
                      ),
                    ],
                    if (_plan.deck == StudyDeckScope.selected) ...[
                      const SizedBox(height: 14),
                      _ManualItemPicker(
                        items: selectableItems,
                        selectedIds: _plan.selectedItemIds,
                        onChanged: (selectedIds) => _setPlan(
                          _plan.copyWith(selectedItemIds: selectedIds),
                        ),
                      ),
                    ],
                    if (learningGroups.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _LearningGroupSelector(
                        groups: learningGroups,
                        selectedIds: _plan.groupIds,
                        onChanged: (groupIds) =>
                            _setPlan(_plan.copyWith(groupIds: groupIds)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _BuilderSection(
                number: '3',
                title: '어떤 난이도로 풀까요?',
                description: '학습 기록을 바탕으로 필요한 난이도만 골라요.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CompactSelectionField<StudyDifficulty>(
                      fieldKey: const Key('session-difficulty-select'),
                      label: '현재 기억 단계',
                      value: _plan.difficulty,
                      options: [
                        for (final difficulty in StudyDifficulty.values)
                          _SelectionOption(
                            key: Key('session-difficulty-${difficulty.name}'),
                            value: difficulty,
                            label: difficulty.label,
                          ),
                      ],
                      onChanged: (difficulty) =>
                          _setPlan(_plan.copyWith(difficulty: difficulty)),
                    ),
                    const SizedBox(height: 14),
                    _CompactSelectionField<StudyHistoryFilter>(
                      fieldKey: const Key('session-history-select'),
                      label: '학습 기록',
                      value: _plan.historyFilter,
                      options: [
                        for (final filter in StudyHistoryFilter.values)
                          _SelectionOption(
                            key: Key('session-history-${filter.name}'),
                            value: filter,
                            label: filter.label,
                          ),
                      ],
                      onChanged: (filter) =>
                          _setPlan(_plan.copyWith(historyFilter: filter)),
                    ),
                    const SizedBox(height: 14),
                    _CompactSelectionField<StudyQueuePriority>(
                      fieldKey: const Key('session-priority-select'),
                      label: '출제 순서',
                      value: _plan.queuePriority,
                      options: [
                        for (final priority in StudyQueuePriority.values)
                          _SelectionOption(
                            key: Key('session-priority-${priority.name}'),
                            value: priority,
                            label: priority.label,
                          ),
                      ],
                      onChanged: (priority) =>
                          _setPlan(_plan.copyWith(queuePriority: priority)),
                    ),
                    const SizedBox(height: 18),
                    _BacklogRecoveryEditor(
                      settings: _plan.backlogRecovery,
                      missedItems: preview.matchingCount,
                      remainingStudyDays: _plan.routineWeekdays.isEmpty
                          ? appState
                                .preferences
                                .onboardingProfile
                                .normalizedStudyWeekdays
                                .length
                          : _plan.routineWeekdays.length,
                      onChanged: (settings) =>
                          _setPlan(_plan.copyWith(backlogRecovery: settings)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _BuilderSection(
                number: '4',
                title: '단어와 문장 비율',
                description: '문제 수와 문장 비율을 정해 주세요.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ContentKindField(plan: _plan, onChanged: _setPlan),
                    const SizedBox(height: 18),
                    _SessionLengthEditor(
                      plan: _plan,
                      averageSecondsPerItem: averageSecondsPerItem,
                      onChanged: _setPlan,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '문장 문제 비율',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          _plan.includeWords && _plan.includeSentences
                              ? '${(_plan.sentenceRatio * 100).round()}%'
                              : _plan.includeSentences
                              ? '문장만'
                              : '단어만',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                    Slider(
                      key: const Key('session-sentence-ratio'),
                      value: _plan.sentenceRatio,
                      divisions: 10,
                      label: '${(_plan.sentenceRatio * 100).round()}%',
                      onChanged: _plan.includeWords && _plan.includeSentences
                          ? (value) =>
                                _setPlan(_plan.copyWith(sentenceRatio: value))
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _BuilderSection(
                number: '5',
                title: '레벨과 태그',
                description: '고르지 않으면 모든 레벨과 태그가 들어가요.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilterChoices(
                      label: '자료 레벨',
                      emptyLabel: '현재 코스에 레벨 정보가 없습니다.',
                      values: levels,
                      selected: _plan.levels,
                      keyPrefix: 'session-level',
                      onChanged: (selected) =>
                          _setPlan(_plan.copyWith(levels: selected)),
                    ),
                    const SizedBox(height: 18),
                    _FilterChoices(
                      label: '태그 · 여러 개 선택 시 하나라도 일치',
                      emptyLabel: '현재 코스에 선택할 태그가 없습니다.',
                      values: tags,
                      selected: _plan.tags,
                      keyPrefix: 'session-tag',
                      onChanged: (selected) =>
                          _setPlan(_plan.copyWith(tags: selected)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _BuilderSection(
                number: '6',
                title: '학습 일정 저장',
                description: '이름과 다음 학습 시간을 정해 기기와 Drive에 저장해요.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      key: const Key('session-title'),
                      controller: _titleController,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: '퀴즈·학습 이름',
                        hintText: '예: 금요일 여행 표현 복습',
                        prefixIcon: Icon(Icons.edit_calendar_rounded),
                      ),
                      onChanged: (value) =>
                          _setPlan(_plan.copyWith(title: value)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('session-pick-schedule'),
                          onPressed: _pickSchedule,
                          icon: const Icon(Icons.event_rounded),
                          label: Text(
                            _plan.scheduledAt == null
                                ? '날짜와 시간 선택'
                                : _formatSchedule(_plan.scheduledAt!),
                          ),
                        ),
                        if (_plan.scheduledAt != null)
                          TextButton.icon(
                            onPressed: () =>
                                _setPlan(_plan.copyWith(scheduledAt: null)),
                            icon: const Icon(Icons.event_busy_rounded),
                            label: const Text('일정 지우기'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('configure-study-routine'),
                      onPressed: _configureRoutine,
                      icon: const Icon(Icons.repeat_rounded),
                      label: Text(
                        _plan.routineName.isEmpty
                            ? '요일·시간 루틴으로 묶기'
                            : '${_plan.routineName} · '
                                  '${_plan.routineWeekdays.length}일 · '
                                  '${((_plan.routineMinuteOfDay ?? 0) ~/ 60).toString().padLeft(2, '0')}:'
                                  '${((_plan.routineMinuteOfDay ?? 0) % 60).toString().padLeft(2, '0')}',
                      ),
                    ),
                    const Divider(height: 28),
                    SwitchListTile.adaptive(
                      key: const Key('session-record-progress'),
                      contentPadding: EdgeInsets.zero,
                      value: _plan.recordProgress,
                      onChanged: (value) =>
                          _setPlan(_plan.copyWith(recordProgress: value)),
                      title: const Text('진도 기록'),
                      subtitle: const Text(
                        '끄면 XP·연속 학습일·SRS·정오답 통계를 바꾸지 않습니다.',
                      ),
                    ),
                    const Divider(height: 28),
                    _ExamScheduleEditor(
                      schedule: _plan.examSchedule,
                      remainingItems: preview.matchingCount,
                      now: now,
                      onPickTargetDate: _pickExamTargetDate,
                      onChanged: (schedule) =>
                          _setPlan(_plan.copyWith(examSchedule: schedule)),
                      onClear: () =>
                          _setPlan(_plan.copyWith(examSchedule: null)),
                    ),
                  ],
                ),
              ),
            ],
          );

          final header = _Header(
            languageName: activeSubject.name,
            subjectKey: appState.activeSubjectId,
            generalTopic: !activeSubject.isLanguage,
            onBack: () => context.go('/learn'),
            onReset: () => _setPlan(
              StudySessionPlan(subjectId: appState.activeSubjectId),
              syncTitle: true,
            ),
          );
          final savedPlans = _SavedPlansCard(
            plans: controller.activeSubjectSavedSessionPlans,
            activePlanId: _plan.planId,
            onLoad: _loadSavedPlan,
            onDelete: _deleteSavedPlan,
            onMoveEarlier: (plan) => _moveRoutinePlan(plan, -1),
            onMoveLater: (plan) => _moveRoutinePlan(plan, 1),
          );
          final hasSavedPlans =
              controller.activeSubjectSavedSessionPlans.isNotEmpty;
          if (desktop) {
            return SingleChildScrollView(
              key: const Key('session-builder-scroll'),
              padding: EdgeInsets.fromLTRB(padding, 20, padding, 36),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      if (hasSavedPlans) ...[
                        const SizedBox(height: 18),
                        savedPlans,
                      ],
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: editor),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: 340,
                            child: _PreviewCard(
                              plan: _plan,
                              preview: preview,
                              units: units,
                              averageSecondsPerItem: averageSecondsPerItem,
                              onSave: _savePlan,
                              onStart: () => _start(preview),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: const Key('session-builder-scroll'),
                  padding: EdgeInsets.fromLTRB(padding, 16, padding, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 12),
                      _MobileSessionSummary(
                        plan: _plan,
                        preview: preview,
                        averageSecondsPerItem: averageSecondsPerItem,
                      ),
                      const SizedBox(height: 12),
                      _QuickSessionPresets(
                        onSelected: (preset) => _setPlan(
                          preset.copyWith(
                            subjectId: appState.activeSubjectId,
                            planId: '',
                            title: '',
                            scheduledAt: null,
                          ),
                          syncTitle: true,
                        ),
                      ),
                      if (hasSavedPlans) ...[
                        const SizedBox(height: 12),
                        savedPlans,
                      ],
                      const SizedBox(height: 12),
                      _MobileSessionEditor(
                        plan: _plan,
                        modes: _exerciseModes,
                        units: units,
                        tags: tags,
                        levels: levels,
                        learningGroups: learningGroups,
                        selectableItems: selectableItems,
                        averageSecondsPerItem: averageSecondsPerItem,
                        now: now,
                        matchingCount: preview.matchingCount,
                        titleController: _titleController,
                        onChanged: _setPlan,
                        onResetAdvanced: _resetAdvancedSettings,
                        onPickSchedule: _pickSchedule,
                        onPickExamTargetDate: _pickExamTargetDate,
                      ),
                    ],
                  ),
                ),
              ),
              _BottomActions(
                preview: preview,
                scheduledAt: _plan.scheduledAt,
                onSave: _savePlan,
                onSchedule: _saveForLater,
                onStart: () => _start(preview),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MobileSessionSummary extends StatelessWidget {
  const _MobileSessionSummary({
    required this.plan,
    required this.preview,
    required this.averageSecondsPerItem,
  });

  final StudySessionPlan plan;
  final StudySessionBuildResult preview;
  final double averageSecondsPerItem;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final minutes = math.max(
      1,
      (preview.items.length * averageSecondsPerItem / 60).ceil(),
    );
    return Card(
      key: const Key('mobile-session-summary'),
      margin: EdgeInsets.zero,
      color: colors.primaryContainer.withValues(alpha: 0.72),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              preview.isEmpty ? Icons.tune_rounded : Icons.check_circle_rounded,
              size: 21,
              color: colors.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: preview.isEmpty
                          ? '조건에 맞는 자료가 없어요'
                          : '${preview.items.length}문제 · 약 $minutes분',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    TextSpan(
                      text: preview.isEmpty
                          ? '\n범위나 문제 수를 조정해 보세요.'
                          : '\n${plan.mode.label} · ${plan.deck.label} · '
                                '후보 ${preview.matchingCount}'
                                '${plan.recordProgress ? '' : ' · 자유 연습'}',
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileSessionEditor extends StatelessWidget {
  const _MobileSessionEditor({
    required this.plan,
    required this.modes,
    required this.units,
    required this.tags,
    required this.levels,
    required this.learningGroups,
    required this.selectableItems,
    required this.averageSecondsPerItem,
    required this.now,
    required this.matchingCount,
    required this.titleController,
    required this.onChanged,
    required this.onResetAdvanced,
    required this.onPickSchedule,
    required this.onPickExamTargetDate,
  });

  final StudySessionPlan plan;
  final List<StudyMode> modes;
  final List<CourseUnitSnapshot> units;
  final List<String> tags;
  final List<String> levels;
  final List<LearningGroupDefinition> learningGroups;
  final List<LearningItem> selectableItems;
  final double averageSecondsPerItem;
  final DateTime now;
  final int matchingCount;
  final TextEditingController titleController;
  final ValueChanged<StudySessionPlan> onChanged;
  final VoidCallback onResetAdvanced;
  final Future<bool> Function() onPickSchedule;
  final Future<void> Function() onPickExamTargetDate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final advancedCount = [
      plan.difficulty != StudyDifficulty.all,
      plan.historyFilter != StudyHistoryFilter.all,
      plan.queuePriority != StudyQueuePriority.dueFirst,
      plan.groupIds.isNotEmpty,
      plan.tags.isNotEmpty,
      plan.levels.isNotEmpty,
      plan.includeWords &&
          plan.includeSentences &&
          (plan.sentenceRatio - _defaultSentenceRatio(plan)).abs() > 0.001,
      plan.backlogRecovery.enabled,
      !plan.recordProgress,
      plan.answerDirectionOverride != null,
      plan.gradingStrictness != StudyGradingStrictness.balanced,
      plan.choiceCount != 4,
      !plan.hintsEnabled,
      plan.autoAdvanceOverride != null,
      plan.soundEffectsOverride != null,
      plan.largeControls,
      plan.examSchedule != null,
    ].where((active) => active).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          key: const Key('mobile-session-core-settings'),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '핵심 설정',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '방식, 자료 범위, 문제 수만 고르면 바로 시작할 수 있어요.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MobileSettingLabel(number: '1', label: '문제 방식'),
                const SizedBox(height: 8),
                _CompactSelectionField<StudyMode>(
                  fieldKey: const Key('session-mode-select'),
                  label: '풀 방식',
                  value: plan.mode,
                  helperText: plan.mode.description,
                  prefixIcon: Icons.quiz_outlined,
                  options: [
                    if (!modes.contains(plan.mode))
                      _SelectionOption(
                        key: Key('session-mode-${plan.mode.name}'),
                        value: plan.mode,
                        label: plan.mode.label,
                      ),
                    for (final mode in modes)
                      _SelectionOption(
                        key: Key('session-mode-${mode.name}'),
                        value: mode,
                        label: mode.label,
                      ),
                  ],
                  onChanged: (mode) => onChanged(plan.copyWith(mode: mode)),
                ),
                const SizedBox(height: 12),
                _AnswerDirectionEditor(
                  plan: plan,
                  compact: true,
                  onChanged: onChanged,
                ),
                const Divider(height: 26),
                _MobileSettingLabel(number: '2', label: '자료 범위'),
                const SizedBox(height: 8),
                _CompactSelectionField<StudyDeckScope>(
                  fieldKey: const Key('session-deck-select'),
                  label: '학습할 자료',
                  value: plan.deck,
                  helperText: plan.deck.description,
                  prefixIcon: Icons.folder_open_rounded,
                  options: [
                    for (final deck in StudyDeckScope.values)
                      _SelectionOption(
                        key: Key('session-deck-${deck.name}'),
                        value: deck,
                        label: deck.label,
                        icon: switch (deck) {
                          StudyDeckScope.course => Icons.language_rounded,
                          StudyDeckScope.unit => Icons.view_module_rounded,
                          StudyDeckScope.favorites => Icons.star_rounded,
                          StudyDeckScope.personal => Icons.person_rounded,
                          StudyDeckScope.selected => Icons.checklist_rounded,
                        },
                      ),
                  ],
                  onChanged: (deck) => onChanged(plan.copyWith(deck: deck)),
                ),
                if (plan.deck == StudyDeckScope.unit) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    key: ValueKey('session-unit-${plan.unitIndex}'),
                    initialValue: plan.unitIndex ?? 0,
                    decoration: const InputDecoration(
                      labelText: '학습할 단원',
                      isDense: true,
                    ),
                    items: [
                      for (final unit in units)
                        DropdownMenuItem(
                          value: unit.index,
                          child: Text('Unit ${unit.index + 1} · ${unit.title}'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onChanged(plan.copyWith(unitIndex: value));
                      }
                    },
                  ),
                ],
                if (plan.deck == StudyDeckScope.selected) ...[
                  const SizedBox(height: 10),
                  _ManualItemPicker(
                    items: selectableItems,
                    selectedIds: plan.selectedItemIds,
                    onChanged: (selectedIds) =>
                        onChanged(plan.copyWith(selectedItemIds: selectedIds)),
                  ),
                ],
                if (learningGroups.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _LearningGroupSelector(
                    groups: learningGroups,
                    selectedIds: plan.groupIds,
                    compact: true,
                    onChanged: (groupIds) =>
                        onChanged(plan.copyWith(groupIds: groupIds)),
                  ),
                ],
                const SizedBox(height: 12),
                _ContentKindField(plan: plan, onChanged: onChanged),
                const Divider(height: 26),
                _MobileSettingLabel(number: '3', label: '세션 길이'),
                const SizedBox(height: 8),
                _SessionLengthEditor(
                  plan: plan,
                  averageSecondsPerItem: averageSecondsPerItem,
                  compact: true,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: const Key('session-advanced-settings'),
            leading: const Icon(Icons.tune_rounded),
            title: Text(
              advancedCount == 0 ? '세부 조건' : '세부 조건 · $advancedCount개 적용',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              advancedCount == 0
                  ? '기본값 사용 · 필요할 때만 펼치세요'
                  : '난이도 · 회복 · 필터 · 진도 설정을 사용 중',
            ),
            trailing: advancedCount == 0
                ? null
                : TextButton(
                    key: const Key('reset-session-advanced-settings'),
                    onPressed: onResetAdvanced,
                    child: const Text('초기화'),
                  ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            children: [
              _CompactSelectionField<StudyDifficulty>(
                fieldKey: const Key('session-difficulty-select'),
                label: '현재 기억 단계',
                value: plan.difficulty,
                options: [
                  for (final difficulty in StudyDifficulty.values)
                    _SelectionOption(
                      key: Key('session-difficulty-${difficulty.name}'),
                      value: difficulty,
                      label: difficulty.label,
                    ),
                ],
                onChanged: (difficulty) =>
                    onChanged(plan.copyWith(difficulty: difficulty)),
              ),
              const SizedBox(height: 16),
              _CompactSelectionField<StudyHistoryFilter>(
                fieldKey: const Key('session-history-select'),
                label: '학습 기록',
                value: plan.historyFilter,
                options: [
                  for (final filter in StudyHistoryFilter.values)
                    _SelectionOption(
                      key: Key('session-history-${filter.name}'),
                      value: filter,
                      label: filter.label,
                    ),
                ],
                onChanged: (filter) =>
                    onChanged(plan.copyWith(historyFilter: filter)),
              ),
              const SizedBox(height: 16),
              _CompactSelectionField<StudyQueuePriority>(
                fieldKey: const Key('session-priority-select'),
                label: '출제 순서',
                value: plan.queuePriority,
                options: [
                  for (final priority in StudyQueuePriority.values)
                    _SelectionOption(
                      key: Key('session-priority-${priority.name}'),
                      value: priority,
                      label: priority.label,
                    ),
                ],
                onChanged: (priority) =>
                    onChanged(plan.copyWith(queuePriority: priority)),
              ),
              const SizedBox(height: 16),
              _BacklogRecoveryEditor(
                settings: plan.backlogRecovery,
                onChanged: (settings) =>
                    onChanged(plan.copyWith(backlogRecovery: settings)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '문장 문제 비율',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(
                    plan.includeWords && plan.includeSentences
                        ? '${(plan.sentenceRatio * 100).round()}%'
                        : plan.includeSentences
                        ? '문장만'
                        : '단어만',
                  ),
                ],
              ),
              Slider(
                key: const Key('session-sentence-ratio'),
                value: plan.sentenceRatio,
                divisions: 10,
                onChanged: plan.includeWords && plan.includeSentences
                    ? (value) => onChanged(plan.copyWith(sentenceRatio: value))
                    : null,
              ),
              _FilterChoices(
                label: '자료 레벨',
                emptyLabel: '현재 주제에 레벨 정보가 없습니다.',
                values: levels,
                selected: plan.levels,
                keyPrefix: 'session-level',
                onChanged: (selected) =>
                    onChanged(plan.copyWith(levels: selected)),
              ),
              const SizedBox(height: 14),
              _FilterChoices(
                label: '태그 · 하나라도 일치',
                emptyLabel: '현재 주제에 태그 정보가 없습니다.',
                values: tags,
                selected: plan.tags,
                keyPrefix: 'session-tag',
                onChanged: (selected) =>
                    onChanged(plan.copyWith(tags: selected)),
              ),
              const Divider(height: 28),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '학습 설정 이름과 일정',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('session-title'),
                controller: titleController,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: '학습 이름',
                  hintText: '예: 금요일 여행 표현 복습',
                  prefixIcon: Icon(Icons.edit_calendar_rounded),
                ),
                onChanged: (value) => onChanged(plan.copyWith(title: value)),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    key: const Key('session-pick-schedule'),
                    onPressed: () => onPickSchedule(),
                    icon: const Icon(Icons.event_rounded),
                    label: Text(
                      plan.scheduledAt == null
                          ? '날짜와 시간 선택'
                          : _formatSchedule(plan.scheduledAt!),
                    ),
                  ),
                  if (plan.scheduledAt != null)
                    TextButton.icon(
                      onPressed: () =>
                          onChanged(plan.copyWith(scheduledAt: null)),
                      icon: const Icon(Icons.event_busy_rounded),
                      label: const Text('일정 지우기'),
                    ),
                ],
              ),
              const Divider(height: 28),
              SwitchListTile.adaptive(
                key: const Key('session-record-progress'),
                contentPadding: EdgeInsets.zero,
                value: plan.recordProgress,
                onChanged: (value) =>
                    onChanged(plan.copyWith(recordProgress: value)),
                title: const Text('진도 기록'),
                subtitle: const Text('끄면 XP·연속일·복습 기록이 바뀌지 않습니다.'),
              ),
              const Divider(height: 28),
              _ExamScheduleEditor(
                schedule: plan.examSchedule,
                remainingItems: matchingCount,
                now: now,
                onPickTargetDate: onPickExamTargetDate,
                onChanged: (schedule) =>
                    onChanged(plan.copyWith(examSchedule: schedule)),
                onClear: () => onChanged(plan.copyWith(examSchedule: null)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnswerDirectionEditor extends StatelessWidget {
  const _AnswerDirectionEditor({
    required this.plan,
    required this.onChanged,
    this.compact = false,
  });

  final StudySessionPlan plan;
  final ValueChanged<StudySessionPlan> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final canChoose = plan.mode.allowsAnswerDirectionOverride;
    return Semantics(
      container: true,
      label: '출제 방향. ${plan.mode.answerDirectionExplanation}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    canChoose
                        ? Icons.swap_horiz_rounded
                        : Icons.lock_outline_rounded,
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Text('출제 방향', style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                plan.mode.answerDirectionExplanation,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (canChoose)
                _CompactSelectionField<StudyAnswerDirection>(
                  fieldKey: const Key('builder-direction-select'),
                  label: '질문과 답의 방향',
                  value:
                      plan.answerDirectionOverride ??
                      StudyAnswerDirection.mixed,
                  prefixIcon: Icons.swap_horiz_rounded,
                  options: [
                    for (final direction in StudyAnswerDirection.values)
                      _SelectionOption(
                        key: Key('builder-direction-${direction.name}'),
                        value: direction,
                        label: _sessionDirectionLabel(direction),
                      ),
                  ],
                  onChanged: (direction) => onChanged(
                    plan.copyWith(answerDirectionOverride: direction),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    key: const Key('builder-direction-locked'),
                    avatar: const Icon(Icons.lock_rounded, size: 17),
                    label: Text(
                      _sessionDirectionLabel(
                        plan.mode.effectiveFixedAnswerDirection,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileSettingLabel extends StatelessWidget {
  const _MobileSettingLabel({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            number,
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _CompactSelectionField<T> extends StatelessWidget {
  const _CompactSelectionField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.helperText,
    this.prefixIcon,
  });

  final Key fieldKey;
  final String label;
  final T value;
  final List<_SelectionOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? helperText;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      key: fieldKey,
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 2,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem<T>(
            key: option.key,
            value: option.value,
            child: Row(
              children: [
                if (option.icon != null) ...[
                  Icon(option.icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(option.label, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
      onChanged: (selected) {
        if (selected != null && selected != value) onChanged(selected);
      },
    );
  }
}

class _ContentKindField extends StatelessWidget {
  const _ContentKindField({required this.plan, required this.onChanged});

  final StudySessionPlan plan;
  final ValueChanged<StudySessionPlan> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = switch ((plan.includeWords, plan.includeSentences)) {
      (true, false) => _SessionContentKind.words,
      (false, true) => _SessionContentKind.sentences,
      _ => _SessionContentKind.mixed,
    };
    return _CompactSelectionField<_SessionContentKind>(
      fieldKey: const Key('session-content-kind-select'),
      label: '자료 유형',
      value: value,
      helperText: switch (value) {
        _SessionContentKind.mixed => '단어와 문장을 현재 비율에 맞춰 섞습니다.',
        _SessionContentKind.words => '단어 자료만 문제에 사용합니다.',
        _SessionContentKind.sentences => '문장 자료만 문제에 사용합니다.',
      },
      prefixIcon: Icons.text_snippet_outlined,
      options: const [
        _SelectionOption(
          value: _SessionContentKind.mixed,
          label: '단어 + 문장',
          icon: Icons.join_inner_rounded,
          key: Key('session-include-mixed'),
        ),
        _SelectionOption(
          value: _SessionContentKind.words,
          label: '단어만',
          icon: Icons.text_fields_rounded,
          key: Key('session-include-words'),
        ),
        _SelectionOption(
          value: _SessionContentKind.sentences,
          label: '문장만',
          icon: Icons.notes_rounded,
          key: Key('session-include-sentences'),
        ),
      ],
      onChanged: (selected) {
        onChanged(switch (selected) {
          _SessionContentKind.mixed => plan.copyWith(
            includeWords: true,
            includeSentences: true,
            sentenceRatio: plan.sentenceRatio <= 0 || plan.sentenceRatio >= 1
                ? 0.3
                : plan.sentenceRatio,
          ),
          _SessionContentKind.words => plan.copyWith(
            includeWords: true,
            includeSentences: false,
            sentenceRatio: 0,
          ),
          _SessionContentKind.sentences => plan.copyWith(
            includeWords: false,
            includeSentences: true,
            sentenceRatio: 1,
          ),
        });
      },
    );
  }
}

class _QuickSessionPresets extends StatelessWidget {
  const _QuickSessionPresets({required this.onSelected});

  final ValueChanged<StudySessionPlan> onSelected;

  @override
  Widget build(BuildContext context) {
    final presets = <({String label, IconData icon, StudySessionPlan plan})>[
      (
        label: '빠른 5문제',
        icon: Icons.bolt_rounded,
        plan: const StudySessionPlan(
          mode: StudyMode.mixed,
          deck: StudyDeckScope.course,
          itemLimit: 5,
        ),
      ),
      (
        label: '뜻 고르기 10',
        icon: Icons.touch_app_rounded,
        plan: const StudySessionPlan(
          mode: StudyMode.meaning,
          deck: StudyDeckScope.course,
          itemLimit: 10,
        ),
      ),
      (
        label: '취약 복습 10',
        icon: Icons.fitness_center_rounded,
        plan: const StudySessionPlan(
          mode: StudyMode.mixed,
          deck: StudyDeckScope.course,
          difficulty: StudyDifficulty.weak,
          itemLimit: 10,
        ),
      ),
      (
        label: '문장만 10',
        icon: Icons.notes_rounded,
        plan: const StudySessionPlan(
          mode: StudyMode.mixed,
          deck: StudyDeckScope.course,
          includeWords: false,
          includeSentences: true,
          sentenceRatio: 1,
          itemLimit: 10,
        ),
      ),
    ];
    return Card(
      key: const Key('quick-session-presets'),
      margin: EdgeInsets.zero,
      child: PopupMenuButton<int>(
        key: const Key('quick-session-preset-menu'),
        tooltip: '간단한 학습 설정 고르기',
        onSelected: (index) => onSelected(presets[index].plan),
        itemBuilder: (context) => [
          for (final (index, preset) in presets.indexed)
            PopupMenuItem<int>(
              key: Key('quick-session-preset-$index'),
              value: index,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(preset.icon),
                title: Text(preset.label),
                subtitle: Text(
                  '${preset.plan.mode.label} · ${preset.plan.itemLimit}문제',
                ),
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '빠른 설정',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '자주 쓰는 구성을 한 번에 적용',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatSchedule(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}.$month.$day $hour:$minute';
}

double _defaultSentenceRatio(StudySessionPlan plan) =>
    switch ((plan.includeWords, plan.includeSentences)) {
      (true, false) => 0,
      (false, true) => 1,
      _ => 0.3,
    };

String _sessionDirectionLabel(StudyAnswerDirection direction) =>
    switch (direction) {
      StudyAnswerDirection.learningToMeaning => '외국어 → 한국어',
      StudyAnswerDirection.meaningToLearning => '한국어 → 외국어',
      StudyAnswerDirection.mixed => '양방향',
    };

class _SavedPlansCard extends StatelessWidget {
  const _SavedPlansCard({
    required this.plans,
    required this.activePlanId,
    required this.onLoad,
    required this.onDelete,
    required this.onMoveEarlier,
    required this.onMoveLater,
  });

  final List<StudySessionPlan> plans;
  final String activePlanId;
  final ValueChanged<StudySessionPlan> onLoad;
  final Future<void> Function(StudySessionPlan) onDelete;
  final ValueChanged<StudySessionPlan> onMoveEarlier;
  final ValueChanged<StudySessionPlan> onMoveLater;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ordered = [...plans]
      ..sort((left, right) {
        if (left.routineName.isNotEmpty &&
            left.routineName == right.routineName) {
          final routineOrder = left.routineOrder.compareTo(right.routineOrder);
          if (routineOrder != 0) return routineOrder;
        }
        final routineName = left.routineName.compareTo(right.routineName);
        if (routineName != 0) return routineName;
        final leftSchedule = left.scheduledAt;
        final rightSchedule = right.scheduledAt;
        if (leftSchedule != null && rightSchedule != null) {
          final order = leftSchedule.compareTo(rightSchedule);
          if (order != 0) return order;
        } else if (leftSchedule != null) {
          return -1;
        } else if (rightSchedule != null) {
          return 1;
        }
        return right.updatedAt?.compareTo(left.updatedAt ?? DateTime(0)) ?? 0;
      });
    return Card(
      key: const Key('saved-session-plans'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.event_repeat_rounded, color: colors.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '저장한 학습 일정',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        plans.isEmpty
                            ? '아래에서 퀴즈 조건과 시간을 정한 뒤 저장하세요.'
                            : '${plans.length}개 · 누르면 편집기에 불러옵니다.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (ordered.isNotEmpty) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (index, plan) in ordered.indexed) ...[
                      if (index > 0) const SizedBox(width: 10),
                      Container(
                        width: 280,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: plan.planId == activePlanId
                              ? colors.primaryContainer
                              : colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: plan.planId == activePlanId
                                ? colors.primary
                                : colors.outlineVariant,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              plan.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              plan.scheduledAt == null
                                  ? plan.lengthMode ==
                                            StudySessionLengthMode.timeBudget
                                        ? '${plan.timeBudgetMinutes}분 · 일정 없음'
                                        : '${plan.itemLimit}문제 · 일정 없음'
                                  : _formatSchedule(plan.scheduledAt!),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (plan.routineName.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${plan.routineName} · 순서 ${plan.routineOrder + 1}',
                                key: Key('routine-label-${plan.planId}'),
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: colors.primary),
                              ),
                            ],
                            const SizedBox(height: 10),
                            PopupMenuButton<_SavedPlanAction>(
                              key: Key('saved-plan-actions-${plan.planId}'),
                              tooltip: '저장한 학습 설정 열기 및 관리',
                              onSelected: (action) {
                                switch (action) {
                                  case _SavedPlanAction.load:
                                    onLoad(plan);
                                    break;
                                  case _SavedPlanAction.moveEarlier:
                                    onMoveEarlier(plan);
                                    break;
                                  case _SavedPlanAction.moveLater:
                                    onMoveLater(plan);
                                    break;
                                  case _SavedPlanAction.delete:
                                    onDelete(plan);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  key: Key('load-session-plan-${plan.planId}'),
                                  value: _SavedPlanAction.load,
                                  child: const ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.edit_note_rounded),
                                    title: Text('불러와서 편집'),
                                  ),
                                ),
                                if (plan.routineName.isNotEmpty) ...[
                                  PopupMenuItem(
                                    key: Key('routine-earlier-${plan.planId}'),
                                    value: _SavedPlanAction.moveEarlier,
                                    child: const ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.arrow_back_rounded),
                                      title: Text('루틴에서 앞 순서'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    key: Key('routine-later-${plan.planId}'),
                                    value: _SavedPlanAction.moveLater,
                                    child: const ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(
                                        Icons.arrow_forward_rounded,
                                      ),
                                      title: Text('루틴에서 뒤 순서'),
                                    ),
                                  ),
                                ],
                                PopupMenuItem(
                                  key: Key(
                                    'delete-session-plan-${plan.planId}',
                                  ),
                                  value: _SavedPlanAction.delete,
                                  child: const ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.delete_outline_rounded),
                                    title: Text('저장한 일정 삭제'),
                                  ),
                                ),
                              ],
                              child: Container(
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: colors.outlineVariant,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.edit_note_rounded, size: 19),
                                    SizedBox(width: 7),
                                    Text('불러오기 · 관리'),
                                    SizedBox(width: 4),
                                    Icon(Icons.expand_more_rounded, size: 19),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LearningGroupSelector extends StatelessWidget {
  const _LearningGroupSelector({
    required this.groups,
    required this.selectedIds,
    required this.onChanged,
    this.compact = false,
  });

  final List<LearningGroupDefinition> groups;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '학습 그룹 함께 선택',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (selectedIds.isNotEmpty)
              TextButton(
                key: const Key('session-groups-clear'),
                onPressed: () => onChanged(const {}),
                child: const Text('모두 해제'),
              ),
          ],
        ),
        Text(
          selectedIds.isEmpty
              ? '선택하지 않으면 현재 범위의 모든 자료를 사용합니다.'
              : '${selectedIds.length}개 그룹을 복제 없이 이번 세션에 합칩니다.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        SizedBox(height: compact ? 7 : 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final group in groups)
              FilterChip(
                key: Key('session-group-${group.id}'),
                label: Text(group.name),
                selected: selectedIds.contains(group.id),
                onSelected: (selected) {
                  final next = {...selectedIds};
                  if (selected) {
                    next.add(group.id);
                  } else {
                    next.remove(group.id);
                  }
                  onChanged(Set.unmodifiable(next));
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _SessionLengthEditor extends StatelessWidget {
  const _SessionLengthEditor({
    required this.plan,
    required this.averageSecondsPerItem,
    required this.onChanged,
    this.compact = false,
  });

  final StudySessionPlan plan;
  final double averageSecondsPerItem;
  final ValueChanged<StudySessionPlan> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final estimatedItems = plan.effectiveItemLimit(
      averageSecondsPerItem: averageSecondsPerItem,
    );
    final roundedSeconds = averageSecondsPerItem.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('세션 길이', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _CompactSelectionField<StudySessionLengthMode>(
          fieldKey: const Key('session-length-select'),
          label: '길이 기준',
          value: plan.lengthMode,
          prefixIcon: Icons.straighten_rounded,
          options: const [
            _SelectionOption(
              key: Key('session-length-item-count'),
              value: StudySessionLengthMode.itemCount,
              label: '문제 수로 정하기',
              icon: Icons.format_list_numbered_rounded,
            ),
            _SelectionOption(
              key: Key('session-length-time-budget'),
              value: StudySessionLengthMode.timeBudget,
              label: '학습 시간으로 정하기',
              icon: Icons.timer_outlined,
            ),
          ],
          onChanged: (mode) => onChanged(plan.copyWith(lengthMode: mode)),
        ),
        const SizedBox(height: 10),
        if (plan.lengthMode == StudySessionLengthMode.itemCount)
          _SessionCountInput(
            value: plan.itemLimit,
            compact: compact,
            onChanged: (value) => onChanged(plan.copyWith(itemLimit: value)),
          )
        else ...[
          _CompactSelectionField<int>(
            fieldKey: const Key('session-time-select'),
            label: '학습 시간',
            value: plan.timeBudgetMinutes,
            prefixIcon: Icons.timer_rounded,
            options: [
              if (!const [2, 3, 5, 10, 15].contains(plan.timeBudgetMinutes))
                _SelectionOption(
                  value: plan.timeBudgetMinutes,
                  label: '${plan.timeBudgetMinutes}분',
                ),
              for (final minutes in const [2, 3, 5, 10, 15])
                _SelectionOption(
                  key: Key('session-time-$minutes'),
                  value: minutes,
                  label: '$minutes분',
                ),
            ],
            onChanged: (minutes) =>
                onChanged(plan.copyWith(timeBudgetMinutes: minutes)),
          ),
          const SizedBox(height: 8),
          Text(
            '최근 속도 문제당 약 $roundedSeconds초 · '
            '예상 $estimatedItems문제 (최대 ${StudyLimits.maxSessionItems})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _BacklogRecoveryEditor extends StatelessWidget {
  const _BacklogRecoveryEditor({
    required this.settings,
    required this.onChanged,
    this.missedItems = 0,
    this.remainingStudyDays = 5,
  });

  final BacklogRecoverySettings settings;
  final ValueChanged<BacklogRecoverySettings> onChanged;
  final int missedItems;
  final int remainingStudyDays;

  @override
  Widget build(BuildContext context) {
    final redistribution = redistributeMissedStudy(
      missedItems: missedItems,
      remainingStudyDays: remainingStudyDays,
      dailyCap: settings.dailyLimit,
    );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile.adaptive(
              key: const Key('session-backlog-recovery'),
              contentPadding: EdgeInsets.zero,
              value: settings.enabled,
              onChanged: (enabled) => onChanged(
                BacklogRecoverySettings(
                  enabled: enabled,
                  dailyLimit: settings.dailyLimit,
                ),
              ),
              title: const Text('밀린 복습 따라잡기'),
              subtitle: const Text('오래 밀렸거나 어려웠던 항목을 하루 분량만 보여줘요.'),
            ),
            if (settings.enabled) ...[
              const SizedBox(height: 4),
              _CompactSelectionField<int>(
                fieldKey: const Key('session-backlog-limit-select'),
                label: '오늘 최대 복습량',
                value: settings.dailyLimit,
                prefixIcon: Icons.inventory_2_outlined,
                options: [
                  if (!const [
                    10,
                    20,
                    30,
                    50,
                    100,
                  ].contains(settings.dailyLimit))
                    _SelectionOption(
                      value: settings.dailyLimit,
                      label: '${settings.dailyLimit}문제',
                    ),
                  for (final limit in const [10, 20, 30, 50, 100])
                    _SelectionOption(
                      key: Key('session-backlog-limit-$limit'),
                      value: limit,
                      label: '$limit문제',
                    ),
                ],
                onChanged: (limit) => onChanged(
                  BacklogRecoverySettings(enabled: true, dailyLimit: limit),
                ),
              ),
              if (missedItems > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '남은 ${redistribution.dailyItems.length}일 재분배 · '
                  '${redistribution.dailyItems.join(' · ')}문제'
                  '${redistribution.remainingBacklog > 0 ? ' · 상한 밖 ${redistribution.remainingBacklog}개 보류' : ''}',
                  key: const Key('backlog-redistribution-preview'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ExamScheduleEditor extends StatelessWidget {
  const _ExamScheduleEditor({
    required this.schedule,
    required this.remainingItems,
    required this.now,
    required this.onPickTargetDate,
    required this.onChanged,
    required this.onClear,
  });

  final ExamSchedule? schedule;
  final int remainingItems;
  final DateTime now;
  final Future<void> Function() onPickTargetDate;
  final ValueChanged<ExamSchedule> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final current = schedule;
    final recommended = current?.recommendedDailyItems(
      remainingItems: remainingItems,
      now: now,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('목표일까지 학습 계획', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          '현재 필터와 그룹의 남은 자료가 바뀌면 하루 권장량도 자동으로 다시 계산됩니다.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const Key('session-exam-target-date'),
              onPressed: onPickTargetDate,
              icon: const Icon(Icons.flag_outlined),
              label: Text(
                current == null
                    ? '목표일 선택'
                    : '목표 ${_formatDate(current.targetDate)}',
              ),
            ),
            if (current != null)
              TextButton.icon(
                key: const Key('session-exam-clear'),
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
                label: const Text('목표 해제'),
              ),
          ],
        ),
        if (current != null) ...[
          const SizedBox(height: 10),
          Semantics(
            label: '하루 최대 ${current.dailyCap}문제',
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '하루 최대 ${current.dailyCap}문제',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Text(
                  '권장 ${recommended ?? 0}문제',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
          Slider(
            key: const Key('session-exam-daily-cap'),
            min: 1,
            max: 100,
            divisions: 99,
            value: current.dailyCap.toDouble().clamp(1, 100),
            label: '${current.dailyCap}',
            onChanged: (value) => onChanged(
              current.copyWith(
                dailyCap: value.round(),
                updatedAt: DateTime.now().toUtc(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}.$month.$day';
}

class _ManualItemPicker extends StatefulWidget {
  const _ManualItemPicker({
    required this.items,
    required this.selectedIds,
    required this.onChanged,
  });

  final List<LearningItem> items;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_ManualItemPicker> createState() => _ManualItemPickerState();
}

class _ManualItemPickerState extends State<_ManualItemPicker> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase();
    final visible = widget.items
        .where((item) {
          if (query.isEmpty) return true;
          return [
            item.text,
            ...item.translations,
            ...item.tags,
          ].join(' ').toLowerCase().contains(query);
        })
        .toList(growable: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '직접 선택 ${widget.selectedIds.length}개',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                PopupMenuButton<_ManualSelectionAction>(
                  key: const Key('session-manual-selection-menu'),
                  tooltip: '직접 선택 관리',
                  onSelected: (action) {
                    switch (action) {
                      case _ManualSelectionAction.selectVisible:
                        widget.onChanged({
                          ...widget.selectedIds,
                          ...visible.map((item) => item.id),
                        });
                        break;
                      case _ManualSelectionAction.clear:
                        widget.onChanged({});
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      key: const Key('session-select-visible-items'),
                      value: _ManualSelectionAction.selectVisible,
                      enabled: visible.isNotEmpty,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.select_all_rounded),
                        title: Text('보이는 항목 모두 선택'),
                      ),
                    ),
                    PopupMenuItem(
                      key: const Key('session-clear-selected-items'),
                      value: _ManualSelectionAction.clear,
                      enabled: widget.selectedIds.isNotEmpty,
                      child: const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.deselect_rounded),
                        title: Text('선택 모두 해제'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('session-item-search'),
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: const InputDecoration(
                isDense: true,
                hintText: '단어·뜻·문장 검색',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: visible.isEmpty
                  ? const Center(child: Text('조건에 맞는 표현이 없습니다.'))
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        final selected = widget.selectedIds.contains(item.id);
                        return Material(
                          type: MaterialType.transparency,
                          child: CheckboxListTile(
                            key: Key('session-item-${item.id}'),
                            value: selected,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              item.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${item.translations.join(' · ')} · '
                              '${item.kind == LearningItemKind.word ? '단어' : '문장'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onChanged: (_) {
                              final next = {...widget.selectedIds};
                              if (!next.add(item.id)) next.remove(item.id);
                              widget.onChanged(next);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.languageName,
    required this.subjectKey,
    required this.generalTopic,
    required this.onBack,
    required this.onReset,
  });

  final String languageName;
  final String subjectKey;
  final bool generalTopic;
  final VoidCallback onBack;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final keyLabel = subjectKey.contains(':')
        ? subjectKey.substring(subjectKey.indexOf(':') + 1)
        : subjectKey;
    return LayoutBuilder(
      builder: (context, _) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconButton(
              key: const Key('session-builder-back'),
              onPressed: onBack,
              tooltip: '학습실로 돌아가기',
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$languageName 학습 세션',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    generalTopic
                        ? '이 설정과 퀴즈 기록은 $languageName 주제에만 적용됩니다.'
                        : '이 설정과 퀴즈 기록은 $languageName 코스에만 적용됩니다.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 5),
                  Semantics(
                    label: '현재 학습 키 $subjectKey',
                    child: Text(
                      '${generalTopic ? '주제키' : '언어키'} · $keyLabel',
                      key: const Key('session-subject-key'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<_BuilderHeaderAction>(
              key: const Key('session-builder-menu'),
              tooltip: '세션 설정 메뉴',
              onSelected: (action) {
                if (action == _BuilderHeaderAction.reset) onReset();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  key: Key('session-builder-reset'),
                  value: _BuilderHeaderAction.reset,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.restart_alt_rounded),
                    title: Text('기본값으로 초기화'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _BuilderSection extends StatelessWidget {
  const _BuilderSection({
    required this.number,
    required this.title,
    required this.description,
    required this.child,
  });

  final String number;
  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    number,
                    style: TextStyle(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _FilterChoices extends StatelessWidget {
  const _FilterChoices({
    required this.label,
    required this.emptyLabel,
    required this.values,
    required this.selected,
    required this.keyPrefix,
    required this.onChanged,
  });

  final String label;
  final String emptyLabel;
  final List<String> values;
  final Set<String> selected;
  final String keyPrefix;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (values.isEmpty)
          Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                FilterChip(
                  key: Key('$keyPrefix-$value'),
                  label: Text(value),
                  selected: selected.contains(value),
                  onSelected: (isSelected) {
                    final next = {...selected};
                    if (isSelected) {
                      next.add(value);
                    } else {
                      next.remove(value);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.plan,
    required this.preview,
    required this.units,
    required this.averageSecondsPerItem,
    required this.onSave,
    required this.onStart,
  });

  final StudySessionPlan plan;
  final StudySessionBuildResult preview;
  final List<CourseUnitSnapshot> units;
  final double averageSecondsPerItem;
  final VoidCallback onSave;
  final VoidCallback onStart;

  String get _deckLabel {
    if (plan.deck != StudyDeckScope.unit) return plan.deck.label;
    final index = plan.unitIndex ?? 0;
    final unit = units.where((value) => value.index == index).firstOrNull;
    return unit == null ? '단원 덱' : 'Unit ${unit.index + 1} · ${unit.title}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final minutes = math.max(
      1,
      (preview.items.length * averageSecondsPerItem / 60).ceil(),
    );
    return Card(
      key: const Key('session-preview'),
      margin: EdgeInsets.zero,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              preview.isEmpty ? '조건에 맞는 표현이 없어요' : '이 설정으로 바로 시작',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              preview.isEmpty
                  ? '덱·난이도·태그 또는 단어/문장 조건을 하나씩 넓혀 보세요.'
                  : '후보 ${preview.matchingCount}개 중 ${preview.items.length}개를 학습합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onPrimaryContainer.withValues(alpha: 0.78),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _PreviewMetric(
                    value: '${preview.items.length}',
                    label: '문제',
                  ),
                ),
                Expanded(
                  child: _PreviewMetric(
                    value: '${preview.selectedWordCount}',
                    label: '단어',
                  ),
                ),
                Expanded(
                  child: _PreviewMetric(
                    value: '${preview.selectedSentenceCount}',
                    label: '문장',
                  ),
                ),
                Expanded(
                  child: _PreviewMetric(value: '$minutes분', label: '예상'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _PreviewPill(label: _deckLabel),
                _PreviewPill(label: plan.mode.label),
                _PreviewPill(label: plan.difficulty.label),
                if (plan.groupIds.isNotEmpty)
                  _PreviewPill(label: '그룹 ${plan.groupIds.length}개'),
                if (plan.lengthMode == StudySessionLengthMode.timeBudget)
                  _PreviewPill(label: '${plan.timeBudgetMinutes}분 세션'),
                if (!plan.recordProgress) const _PreviewPill(label: '기록 안 함'),
                if (plan.backlogRecovery.enabled)
                  _PreviewPill(
                    label: '회복 최대 ${plan.backlogRecovery.dailyLimit}',
                  ),
                if (plan.tags.isNotEmpty)
                  _PreviewPill(label: '태그 ${plan.tags.length}개'),
                if (plan.levels.isNotEmpty)
                  _PreviewPill(label: '레벨 ${plan.levels.length}개'),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('session-start'),
              onPressed: preview.isEmpty ? null : onStart,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: colors.onPrimaryContainer,
                foregroundColor: colors.primaryContainer,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('${preview.items.length}문제 시작'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('session-save'),
              onPressed: onSave,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                foregroundColor: colors.onPrimaryContainer,
                side: BorderSide(
                  color: colors.onPrimaryContainer.withValues(alpha: 0.5),
                ),
              ),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('설정 저장'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.preview,
    required this.scheduledAt,
    required this.onSave,
    required this.onSchedule,
    required this.onStart,
  });

  final StudySessionBuildResult preview;
  final DateTime? scheduledAt;
  final VoidCallback onSave;
  final VoidCallback onSchedule;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('session-actions-bottom'),
      elevation: 1,
      color: colors.surface,
      child: DecoratedBox(
        key: const Key('session-actions-border'),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      preview.isEmpty
                          ? '조건을 조정해 주세요'
                          : '준비 완료 · ${preview.items.length}문제',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: FilledButton.icon(
                      key: const Key('session-start-bottom'),
                      onPressed: preview.isEmpty ? null : onStart,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text('${preview.items.length}문제 시작'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<_BottomSessionAction>(
                    key: const Key('session-save-menu-bottom'),
                    tooltip: '현재 설정 저장 또는 예약',
                    onSelected: (action) {
                      switch (action) {
                        case _BottomSessionAction.save:
                          onSave();
                          break;
                        case _BottomSessionAction.schedule:
                          onSchedule();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        key: Key('session-save-bottom'),
                        value: _BottomSessionAction.save,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.bookmark_add_outlined),
                          title: Text('현재 설정만 저장'),
                        ),
                      ),
                      PopupMenuItem(
                        key: const Key('session-schedule-bottom'),
                        value: _BottomSessionAction.schedule,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_rounded),
                          title: Text(scheduledAt == null ? '나중에 학습' : '일정 저장'),
                        ),
                      ),
                    ],
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.outlineVariant),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_add_outlined, size: 19),
                          SizedBox(width: 6),
                          Text('저장'),
                          Icon(Icons.expand_more_rounded, size: 19),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewMetric extends StatelessWidget {
  const _PreviewMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color.withValues(alpha: 0.7)),
        ),
      ],
    );
  }
}

class _SessionCountInput extends StatefulWidget {
  const _SessionCountInput({
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final bool compact;

  @override
  State<_SessionCountInput> createState() => _SessionCountInputState();
}

class _SessionCountInputState extends State<_SessionCountInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focusNode = FocusNode()..addListener(_handleFocus);
  }

  @override
  void didUpdateWidget(covariant _SessionCountInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus &&
        oldWidget.value != widget.value &&
        _controller.text != '${widget.value}') {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocus)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (!_focusNode.hasFocus) _commit();
  }

  void _commit() {
    final parsed = int.tryParse(_controller.text);
    final next = (parsed ?? widget.value).clamp(
      StudyLimits.minSessionItems,
      StudyLimits.maxSessionItems,
    );
    _setValue(next);
  }

  void _setValue(int value) {
    final next = value.clamp(
      StudyLimits.minSessionItems,
      StudyLimits.maxSessionItems,
    );
    _controller.value = TextEditingValue(
      text: '$next',
      selection: TextSelection.collapsed(offset: '$next'.length),
    );
    if (next != widget.value) widget.onChanged(next);
  }

  void _handleChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null ||
        parsed < StudyLimits.minSessionItems ||
        parsed > StudyLimits.maxSessionItems ||
        parsed == widget.value) {
      return;
    }
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final input = SizedBox(
      width: widget.compact ? 116 : 140,
      child: TextField(
        key: const Key('session-limit-input'),
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(
            StudyLimits.maxSessionItems.toString().length,
          ),
        ],
        decoration: const InputDecoration(
          isDense: true,
          labelText: '문제 수',
          suffixText: '개',
          helperText:
              '${StudyLimits.minSessionItems}~${StudyLimits.maxSessionItems}',
        ),
        onChanged: _handleChanged,
        onEditingComplete: () {
          _commit();
          _focusNode.unfocus();
        },
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        input,
        const SizedBox(width: 8),
        PopupMenuButton<int>(
          key: const Key('session-limit-presets'),
          tooltip: '자주 쓰는 문제 수',
          onSelected: _setValue,
          itemBuilder: (context) => [
            for (final value in const [5, 10, 20, 50, 100])
              PopupMenuItem(
                key: Key('session-limit-preset-$value'),
                value: value,
                child: Text('$value문제'),
              ),
          ],
          icon: const Icon(Icons.tune_rounded),
        ),
      ],
    );
  }
}

class _PreviewPill extends StatelessWidget {
  const _PreviewPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
