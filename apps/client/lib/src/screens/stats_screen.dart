import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../backup/study_summary_exporter.dart';
import '../domain/active_study_session.dart';
import '../domain/learning_insights.dart';
import '../domain/progress.dart';
import '../domain/study_history.dart';
import '../domain/study_limits.dart';
import '../domain/study_preferences.dart';
import '../services/app_clock.dart';
import '../state/app_state.dart';
import '../state/app_state_view.dart';
import '../theme/app_theme.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  var _range = LearningInsightRange.thirtyDays;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final state = ref.watch(appControllerProvider);
    final calendarDay = ref.watch(calendarDayProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final activeSubject = controller.activeSubject;
    final items = controller.selectedItems;
    final itemIds = items.map((item) => item.id).toSet();
    final courseProgress = state.progress.values
        .where((progress) => itemIds.contains(progress.itemId))
        .toList(growable: false);
    final learned = courseProgress.length;
    final correct = courseProgress.fold<int>(
      0,
      (sum, item) => sum + item.correctCount,
    );
    final wrong = courseProgress.fold<int>(
      0,
      (sum, item) => sum + item.wrongCount,
    );
    final attempts = correct + wrong;
    final accuracy = attempts == 0 ? 0 : (correct / attempts * 100).round();
    final coverage = items.isEmpty ? 0 : (learned / items.length * 100).round();
    final learning = courseProgress
        .where((item) => item.status == LearningStatus.learning)
        .length;
    final review = courseProgress
        .where((item) => item.status == LearningStatus.review)
        .length;
    final mastered = courseProgress
        .where((item) => item.status == LearningStatus.mastered)
        .length;
    final newItems = items.length - learned;
    final sessions = state.recentSessions
        .where((session) => session.courseId == state.activeCourseId)
        .take(8)
        .toList(growable: false);
    final insights = LearningInsights.build(
      sessions: state.recentSessions,
      items: items,
      progress: state.progress,
      now: ref.read(appClockProvider)(),
      range: _range,
      courseId: state.activeCourseId,
    );
    final allSubjectInsights = LearningInsights.build(
      sessions: state.recentSessions,
      items: const [],
      progress: const {},
      now: ref.read(appClockProvider)(),
      range: _range,
    );
    final forecast = ref
        .read(appControllerProvider.notifier)
        .reviewForecast(DateTime.now());

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          narrow ? 12 : 20,
          narrow ? 12 : 24,
          narrow ? 12 : 20,
          narrow ? 20 : 28,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '학습 리포트',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              activeSubject.isLanguage
                                  ? '${activeSubject.name} 코스의 학습 기록을 확인하세요.'
                                  : '${activeSubject.symbol} ${activeSubject.name} 학습 기록을 확인하세요.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton.filledTonal(
                            key: const Key('export-private-summary'),
                            onPressed: () => _exportSummary(insights),
                            tooltip: '개인정보 제외 CSV 저장',
                            icon: const Icon(Icons.download_outlined),
                          ),
                          const SizedBox(width: 6),
                          IconButton.filledTonal(
                            key: const Key('report-settings'),
                            onPressed: () => context.go('/settings'),
                            tooltip: '설정',
                            icon: const Icon(Icons.tune_rounded),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<LearningInsightRange>(
                      key: const Key('stats-range-filter'),
                      segments: [
                        for (final range in LearningInsightRange.values)
                          ButtonSegment(value: range, label: Text(range.label)),
                      ],
                      selected: {_range},
                      onSelectionChanged: (value) =>
                          setState(() => _range = value.single),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _LearningTrendCard(
                    insights: insights,
                    dailyGoal: state.dailyGoal,
                    weeklyTargetDays: state.preferences.weeklyTargetDays,
                    weeklyTargetMinutes: state.preferences.weeklyTargetMinutes,
                    onWeeklyTargetDaysChanged: (value) =>
                        controller.updateWeeklyLearningTarget(
                          studyDays: value,
                          studyMinutes: ref
                              .read(appControllerProvider)
                              .preferences
                              .weeklyTargetMinutes,
                        ),
                    onWeeklyTargetMinutesChanged: (value) =>
                        controller.updateWeeklyLearningTarget(
                          studyDays: ref
                              .read(appControllerProvider)
                              .preferences
                              .weeklyTargetDays,
                          studyMinutes: value,
                        ),
                  ),
                  if (insights.skills.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _SkillInsightsCard(skills: insights.skills),
                  ],
                  if (allSubjectInsights.subjects.length > 1) ...[
                    const SizedBox(height: 14),
                    _SubjectInsightsCard(subjects: allSubjectInsights.subjects),
                  ],
                  if (insights.hardestItems.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _HardestItemsCard(
                      items: insights.hardestItems,
                      onReview: (item) => _reviewHardItem(item.itemId),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _ReviewForecastCard(
                    dueNow: forecast.dueNow,
                    laterToday: forecast.laterToday,
                    tomorrow: forecast.tomorrow,
                    nextSevenDays: forecast.nextSevenDays,
                    nextReviewAt: forecast.nextReviewAt,
                    onReview: forecast.dueNow == 0
                        ? null
                        : () => context.push('/study?mode=review'),
                  ),
                  const SizedBox(height: 16),
                  _LevelHero(
                    subjectName: activeSubject.name,
                    level: state.level,
                    levelXp: state.levelXp,
                    totalXp: state.totalXp,
                    streakDays: state.streakDays,
                    dailyXp: state.activeCourseDailyXpAt(calendarDay),
                    dailyGoal: state.dailyGoal,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 820 ? 4 : 2;
                      final metrics = [
                        (
                          '코스 범위',
                          '$coverage%',
                          '$learned / ${items.length}',
                          Icons.donut_large_rounded,
                          AppTheme.desktopPrimary,
                        ),
                        (
                          '정확도',
                          '$accuracy%',
                          '$attempts회 풀이',
                          Icons.track_changes_rounded,
                          AppTheme.desktopAccent,
                        ),
                        (
                          '정답',
                          '$correct',
                          '맞힌 횟수',
                          Icons.check_circle_rounded,
                          AppTheme.success,
                        ),
                        (
                          '오답',
                          '$wrong',
                          '틀린 횟수',
                          Icons.replay_rounded,
                          AppTheme.warning,
                        ),
                      ];
                      return GridView.count(
                        crossAxisCount: columns,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: columns == 4
                            ? 1.85
                            : constraints.maxWidth < 336
                            ? 1
                            : constraints.maxWidth < 500
                            ? 1.15
                            : 1.6,
                        children: [
                          for (final metric in metrics)
                            _StatCard(
                              label: metric.$1,
                              value: metric.$2,
                              caption: metric.$3,
                              icon: metric.$4,
                              color: metric.$5,
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 850;
                      final distribution = _DistributionCard(
                        total: items.length,
                        newItems: newItems,
                        learning: learning,
                        review: review,
                        mastered: mastered,
                      );
                      final badges = _BadgeCard(badges: state.badges);
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: distribution),
                            const SizedBox(width: 14),
                            Expanded(flex: 2, child: badges),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          distribution,
                          const SizedBox(height: 14),
                          badges,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  _RecentSessionsCard(
                    sessions: sessions,
                    onRepeat: (session) => _reuseSession(context, ref, session),
                    onExcludeCorrect: (session) => _reuseSession(
                      context,
                      ref,
                      session,
                      historyFilter: StudyHistoryFilter.excludeCorrect,
                    ),
                    onWrongAnswers: (session) => _reuseSession(
                      context,
                      ref,
                      session,
                      historyFilter: StudyHistoryFilter.wrongOnly,
                    ),
                    onNewFirst: (session) => _reuseSession(
                      context,
                      ref,
                      session,
                      queuePriority: StudyQueuePriority.newFirst,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _reuseSession(
    BuildContext context,
    WidgetRef ref,
    StudySessionSummary session, {
    StudyHistoryFilter historyFilter = StudyHistoryFilter.all,
    StudyQueuePriority queuePriority = StudyQueuePriority.dueFirst,
  }) {
    final controller = ref.read(appControllerProvider.notifier);
    final availableIds = controller.courseItems.map((item) => item.id).toSet();
    final sourceIds = switch (historyFilter) {
      StudyHistoryFilter.all => session.itemIds.toSet(),
      StudyHistoryFilter.excludeCorrect => session.notCorrectItemIds,
      StudyHistoryFilter.wrongOnly => session.unresolvedWrongItemIds,
    };
    final selectedIds = sourceIds.intersection(availableIds);
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            historyFilter == StudyHistoryFilter.wrongOnly
                ? '이 세션에는 아직 다시 풀 오답이 없습니다.'
                : historyFilter == StudyHistoryFilter.excludeCorrect
                ? '이 세션에는 맞히지 못한 항목이 없습니다.'
                : '이전 세션의 항목 정보가 없거나 현재 코스에서 사용할 수 없습니다.',
          ),
        ),
      );
      return;
    }
    final local = session.startedAt.toLocal();
    final current = ref.read(appControllerProvider).preferences.sessionPlan;
    controller.updateSessionPlan(
      current.copyWith(
        planId: '',
        title: historyFilter == StudyHistoryFilter.wrongOnly
            ? '${local.month}/${local.day} 오답 다시 풀기'
            : historyFilter == StudyHistoryFilter.excludeCorrect
            ? '${local.month}/${local.day} 맞힌 항목 제외'
            : queuePriority == StudyQueuePriority.newFirst
            ? '${local.month}/${local.day} 새 자료 우선'
            : '${local.month}/${local.day} 세션 다시 학습',
        mode: StudyMode.mixed,
        deck: StudyDeckScope.selected,
        difficulty: StudyDifficulty.all,
        queuePriority: queuePriority,
        historyFilter: StudyHistoryFilter.all,
        tags: {},
        levels: {},
        selectedItemIds: selectedIds,
        includeWords: true,
        includeSentences: true,
        itemLimit: selectedIds.length.clamp(
          StudyLimits.minSessionItems,
          StudyLimits.maxSessionItems,
        ),
        scheduledAt: null,
      ),
    );
    context.push('/session-builder');
  }

  void _reviewHardItem(String itemId) {
    final controller = ref.read(appControllerProvider.notifier);
    controller.updateSessionPlan(
      controller.activeSessionPlan.copyWith(
        planId: '',
        title: '어려운 항목 바로 복습',
        mode: StudyMode.mixed,
        deck: StudyDeckScope.selected,
        difficulty: StudyDifficulty.all,
        historyFilter: StudyHistoryFilter.all,
        selectedItemIds: {itemId},
        groupIds: {},
        tags: {},
        levels: {},
        includeWords: true,
        includeSentences: true,
        itemLimit: 1,
        scheduledAt: null,
      ),
    );
    context.push('/study?mode=mixed&limit=1&custom=true');
  }

  Future<void> _exportSummary(LearningInsights insights) async {
    try {
      final csv = const StudySummaryExporter().exportCsv(insights);
      final now = ref.read(appClockProvider)().toLocal();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '개인정보 제외 학습 요약 저장',
        fileName: 'sprache-learning-summary-$stamp.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csv)),
        lockParentWindow: true,
      );
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('학습 원문을 뺀 요약을 저장했어요: $path')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요약 CSV를 저장하지 못했습니다. 학습 데이터는 그대로 유지됩니다.')),
      );
    }
  }
}

class _LearningTrendCard extends StatelessWidget {
  const _LearningTrendCard({
    required this.insights,
    required this.dailyGoal,
    required this.weeklyTargetDays,
    required this.weeklyTargetMinutes,
    required this.onWeeklyTargetDaysChanged,
    required this.onWeeklyTargetMinutesChanged,
  });

  final LearningInsights insights;
  final int dailyGoal;
  final int weeklyTargetDays;
  final int weeklyTargetMinutes;
  final ValueChanged<int> onWeeklyTargetDaysChanged;
  final ValueChanged<int> onWeeklyTargetMinutesChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final recent = insights.days.reversed.take(35).toList().reversed.toList();
    final accuracy = insights.accuracy;
    final weeklyDayProgress = insights.weeklySessionGoalProgress(
      weeklyTargetDays,
    );
    final weeklyMinuteProgress = insights.weeklyDurationGoalProgress(
      weeklyTargetMinutes,
    );
    final weeklyProgress = insights.weeklyCombinedGoalProgress(
      targetDays: weeklyTargetDays,
      targetMinutes: weeklyTargetMinutes,
    );
    return Card(
      key: const Key('learning-trend-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${insights.range.label} 학습 흐름',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text('${insights.sessionCount}세션'),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InsightMetric(label: 'XP', value: '${insights.earnedXp}'),
                _InsightMetric(
                  label: '정확도',
                  value: accuracy == null
                      ? '-'
                      : '${(accuracy * 100).round()}%',
                  caption: '${insights.attempts}문제',
                ),
                _InsightMetric(
                  label: '학습 시간',
                  value: '${insights.duration.inMinutes}분',
                  caption: '시작부터 종료까지',
                ),
                _InsightMetric(
                  label: '최근 7일',
                  value: '${insights.studiedDaysInLastSeven()}일',
                  caption: '목표 $weeklyTargetDays일 · $weeklyTargetMinutes분',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('학습 캘린더', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 7),
            Wrap(
              key: const Key('accessible-study-calendar'),
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final day in recent)
                  Semantics(
                    label:
                        '${day.date.month}월 ${day.date.day}일, '
                        '${day.sessionCount}세션, ${day.earnedXp} XP, '
                        '${day.attempts}문제',
                    child: Tooltip(
                      message:
                          '${day.date.month}/${day.date.day} · '
                          '${day.earnedXp} XP · ${day.attempts}문제',
                      child: Container(
                        key: Key(
                          'study-calendar-${day.date.year}-'
                          '${day.date.month}-${day.date.day}',
                        ),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _calendarColor(
                            colors,
                            day.intensityFor(dailyGoal: dailyGoal),
                          ),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('주간 학습 목표', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final value in const [3, 5, 7])
                  ChoiceChip(
                    key: Key('weekly-target-$value'),
                    label: Text('주 $value일'),
                    selected: weeklyTargetDays == value,
                    onSelected: (_) => onWeeklyTargetDaysChanged(value),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final value in const [30, 60, 90, 150])
                  ChoiceChip(
                    key: Key('weekly-minute-target-$value'),
                    label: Text('$value분'),
                    selected: weeklyTargetMinutes == value,
                    onSelected: (_) => onWeeklyTargetMinutesChanged(value),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _WeeklyProgressRow(
              label: '학습일',
              progress: weeklyDayProgress,
              detail: '${insights.studiedDaysInLastSeven()}/$weeklyTargetDays일',
            ),
            const SizedBox(height: 7),
            _WeeklyProgressRow(
              label: '학습 분량',
              progress: weeklyMinuteProgress,
              detail:
                  '${insights.durationInLastSeven().inMinutes}/$weeklyTargetMinutes분',
            ),
            const SizedBox(height: 7),
            _WeeklyProgressRow(
              key: const Key('weekly-combined-progress'),
              label: '종합 달성',
              progress: weeklyProgress,
              detail: '${(weeklyProgress * 100).round()}%',
            ),
            if (insights.days.where((day) => day.studied).isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('최근 추세', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              for (final day
                  in insights.days.reversed.where((day) => day.studied).take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text('${day.date.month}/${day.date.day}'),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: dailyGoal <= 0
                              ? null
                              : (day.earnedXp / dailyGoal).clamp(0, 1),
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${day.earnedXp} XP · '
                        '${day.accuracy == null ? '-' : '${(day.accuracy! * 100).round()}%'} '
                        '(${day.attempts})',
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Color _calendarColor(ColorScheme colors, int level) => switch (level) {
    0 => colors.surfaceContainerHighest,
    1 => colors.primaryContainer.withValues(alpha: 0.45),
    2 => colors.primaryContainer,
    3 => colors.primary.withValues(alpha: 0.75),
    _ => colors.primary,
  };
}

class _WeeklyProgressRow extends StatelessWidget {
  const _WeeklyProgressRow({
    required this.label,
    required this.progress,
    required this.detail,
    super.key,
  });

  final String label;
  final double progress;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 70, child: Text(label)),
      Expanded(
        child: LinearProgressIndicator(
          semanticsLabel: '$label 목표 달성률',
          semanticsValue: '${(progress * 100).round()}%',
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(width: 78, child: Text(detail, textAlign: TextAlign.end)),
    ],
  );
}

class _InsightMetric extends StatelessWidget {
  const _InsightMetric({
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 126),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (caption != null)
          Text(caption!, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _SkillInsightsCard extends StatelessWidget {
  const _SkillInsightsCard({required this.skills});

  final List<SkillLearningInsight> skills;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('skill-insights-card'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '문제 유형별 숙련도',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final skill in skills)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.school_outlined),
              title: Text(skill.skill),
              subtitle: Text(
                '${skill.sessionCount}세션 · ${skill.attempts}문제 · '
                '최근 변화 ${_accuracyChangeLabel(skill.recentAccuracyChange)}',
              ),
              trailing: Text(
                skill.accuracy == null
                    ? '-'
                    : '${(skill.accuracy! * 100).round()}%',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    ),
  );
}

class _SubjectInsightsCard extends StatelessWidget {
  const _SubjectInsightsCard({required this.subjects});

  final List<SubjectLearningInsight> subjects;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('subject-insights-card'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '주제 비교',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final subject in subjects)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(subject.courseId),
              subtitle: Text(
                '${subject.sessionCount}세션 · ${subject.duration.inMinutes}분 · '
                '${subject.attempts}문제 · 복습 ${subject.reviewSessionCount}회',
              ),
              trailing: Text(
                '${subject.earnedXp} XP\n'
                '${subject.accuracy == null ? '-' : '${(subject.accuracy! * 100).round()}%'}',
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    ),
  );
}

String _accuracyChangeLabel(double? change) {
  if (change == null) return '측정 중';
  final points = (change * 100).round();
  if (points == 0) return '0%p';
  return '${points > 0 ? '+' : ''}$points%p';
}

class _HardestItemsCard extends StatelessWidget {
  const _HardestItemsCard({required this.items, required this.onReview});

  final List<HardestLearningItem> items;
  final ValueChanged<HardestLearningItem> onReview;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('hardest-items-card'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '어려운 항목',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '틀린 이유와 마지막 학습일을 보고 바로 복습하세요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final item in items.take(6))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.priority_high_rounded),
              title: Text(
                item.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${item.reason} · 정확도 ${(item.accuracy * 100).round()}% · '
                '${_shortDate(item.lastStudiedAt)}',
              ),
              trailing: TextButton(
                key: Key('review-hard-item-${item.itemId}'),
                onPressed: () => onReview(item),
                child: const Text('복습'),
              ),
            ),
        ],
      ),
    ),
  );

  static String _shortDate(DateTime? value) {
    if (value == null) return '학습일 없음';
    final local = value.toLocal();
    return '${local.month}/${local.day} 학습';
  }
}

class _ReviewForecastCard extends StatelessWidget {
  const _ReviewForecastCard({
    required this.dueNow,
    required this.laterToday,
    required this.tomorrow,
    required this.nextSevenDays,
    required this.nextReviewAt,
    required this.onReview,
  });

  final int dueNow;
  final int laterToday;
  final int tomorrow;
  final int nextSevenDays;
  final DateTime? nextReviewAt;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = [
      ('지금 복습', dueNow, Icons.notifications_active_rounded),
      ('오늘 나중', laterToday, Icons.schedule_rounded),
      ('내일', tomorrow, Icons.wb_sunny_outlined),
      ('향후 2~7일', nextSevenDays, Icons.date_range_rounded),
    ];
    return Card(
      key: const Key('review-forecast-card'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '복습 일정',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _nextReviewLabel(nextReviewAt, DateTime.now()),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                );
                final button = FilledButton.icon(
                  key: const Key('start-due-review'),
                  onPressed: onReview,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(112, 48),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(dueNow == 0 ? '복습 없음' : '$dueNow개 시작'),
                );
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      copy,
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerRight, child: button),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 16),
                    button,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < 620
                    ? (constraints.maxWidth - 10) / 2
                    : (constraints.maxWidth - 30) / 4;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in entries)
                      Container(
                        width: width,
                        constraints: const BoxConstraints(minHeight: 82),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(entry.$3, color: colors.primary, size: 21),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${entry.$2}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    entry.$1,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _nextReviewLabel(DateTime? reviewAt, DateTime now) {
  if (reviewAt == null) return '카드를 학습하면 다음 복습 시점이 여기에 표시됩니다.';
  if (!reviewAt.isAfter(now)) return '지금 복습할 카드가 있어요.';
  final local = reviewAt.toLocal();
  final difference = reviewAt.difference(now);
  if (difference.inHours < 24) {
    return '다음 복습: 오늘 ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }
  return '다음 복습: ${local.month}월 ${local.day}일 ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

class _RecentSessionsCard extends StatelessWidget {
  const _RecentSessionsCard({
    required this.sessions,
    required this.onRepeat,
    required this.onExcludeCorrect,
    required this.onWrongAnswers,
    required this.onNewFirst,
  });

  final List<StudySessionSummary> sessions;
  final ValueChanged<StudySessionSummary> onRepeat;
  final ValueChanged<StudySessionSummary> onExcludeCorrect;
  final ValueChanged<StudySessionSummary> onWrongAnswers;
  final ValueChanged<StudySessionSummary> onNewFirst;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '최근 학습 세션',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '완료한 세션만 표시해요. 중단한 퀴즈는 홈에서 이어갈 수 있어요.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.history_rounded, color: colors.primary),
              ],
            ),
            const SizedBox(height: 16),
            if (sessions.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.query_stats_rounded, size: 34),
                    SizedBox(height: 8),
                    Text('학습을 한 번 마치면 세션 기록이 표시됩니다.'),
                  ],
                ),
              )
            else
              for (final (index, session) in sessions.indexed) ...[
                if (index > 0) const Divider(height: 1),
                _SessionRow(
                  session: session,
                  onRepeat: session.itemIds.isEmpty
                      ? null
                      : () => onRepeat(session),
                  onExcludeCorrect: session.notCorrectItemIds.isEmpty
                      ? null
                      : () => onExcludeCorrect(session),
                  onWrongAnswers: session.unresolvedWrongItemIds.isEmpty
                      ? null
                      : () => onWrongAnswers(session),
                  onNewFirst: session.itemIds.isEmpty
                      ? null
                      : () => onNewFirst(session),
                ),
              ],
          ],
        ),
      ),
    );
  }
}

enum _RecentSessionAction { repeat, excludeCorrect, wrongAnswers, newFirst }

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.onRepeat,
    required this.onExcludeCorrect,
    required this.onWrongAnswers,
    required this.onNewFirst,
  });

  final StudySessionSummary session;
  final VoidCallback? onRepeat;
  final VoidCallback? onExcludeCorrect;
  final VoidCallback? onWrongAnswers;
  final VoidCallback? onNewFirst;

  @override
  Widget build(BuildContext context) {
    final local = session.startedAt.toLocal();
    final elapsed = session.endedAt.difference(session.startedAt);
    final duration = elapsed.inMinutes > 0
        ? '${elapsed.inMinutes}분'
        : '${elapsed.inSeconds.clamp(1, 59)}초';
    final accuracy = (session.accuracy * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox.square(
              dimension: 42,
              child: Center(
                child: Text(
                  '${local.month}/${local.day}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_twoDigits(local.hour)}:${_twoDigits(local.minute)} · ${session.attempts}문제'
                  '${session.isDerived ? ' · ${session.origin.label}' : ''}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '정답 ${session.correctCount} · 오답 ${session.wrongCount} · $duration'
                  '${session.pauseCount + session.resumeCount == 0 ? '' : ' · 멈춤 ${session.pauseCount}/재개 ${session.resumeCount}'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$accuracy%',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                '+${session.earnedXp} XP',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          PopupMenuButton<_RecentSessionAction>(
            key: Key('recent-session-actions-${session.sessionId}'),
            tooltip: '이 세션 다시 시작',
            onSelected: (action) {
              switch (action) {
                case _RecentSessionAction.repeat:
                  onRepeat?.call();
                case _RecentSessionAction.excludeCorrect:
                  onExcludeCorrect?.call();
                case _RecentSessionAction.wrongAnswers:
                  onWrongAnswers?.call();
                case _RecentSessionAction.newFirst:
                  onNewFirst?.call();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _RecentSessionAction.repeat,
                enabled: onRepeat != null,
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.restart_alt_rounded),
                  title: Text('같은 문제 다시 풀기'),
                ),
              ),
              PopupMenuItem(
                value: _RecentSessionAction.excludeCorrect,
                enabled: onExcludeCorrect != null,
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.filter_alt_off_rounded),
                  title: Text('맞힌 항목 빼고 풀기'),
                ),
              ),
              PopupMenuItem(
                value: _RecentSessionAction.wrongAnswers,
                enabled: onWrongAnswers != null,
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.replay_rounded),
                  title: Text('틀린 문제만 다시 풀기'),
                ),
              ),
              PopupMenuItem(
                value: _RecentSessionAction.newFirst,
                enabled: onNewFirst != null,
                child: const ListTile(
                  dense: true,
                  leading: Icon(Icons.fiber_new_rounded),
                  title: Text('새 자료부터 풀기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class _LevelHero extends StatelessWidget {
  const _LevelHero({
    required this.subjectName,
    required this.level,
    required this.levelXp,
    required this.totalXp,
    required this.streakDays,
    required this.dailyXp,
    required this.dailyGoal,
  });

  final String subjectName;
  final int level;
  final int levelXp;
  final int totalXp;
  final int streakDays;
  final int dailyXp;
  final int dailyGoal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withValues(alpha: 0.32)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final levelCopy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ACCOUNT LEVEL $level',
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '계정 전체에서 지금까지 $totalXp XP를 쌓았어요',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: '계정 레벨 $level 진행률',
                value: '${(levelXp / 5).round()}퍼센트',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: levelXp / 500,
                    minHeight: 8,
                    backgroundColor: colors.onPrimaryContainer.withValues(
                      alpha: 0.18,
                    ),
                    valueColor: AlwaysStoppedAnimation(
                      colors.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '다음 레벨까지 ${500 - levelXp} XP',
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontSize: 12,
                ),
              ),
            ],
          );
          final summary = Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(
                icon: Icons.local_fire_department_rounded,
                value: '$streakDays일',
                label: '연속 학습',
              ),
              _HeroMetric(
                icon: Icons.bolt_rounded,
                value: '$dailyXp/$dailyGoal',
                label: '$subjectName 오늘 XP',
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [levelCopy, const SizedBox(height: 18), summary],
            );
          }
          return Row(
            children: [
              Expanded(child: levelCopy),
              const SizedBox(width: 24),
              summary,
            ],
          );
        },
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: colors.primary, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurface, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: SizedBox.square(
                    dimension: 36,
                    child: Icon(icon, color: color, size: 19),
                  ),
                ),
                const Spacer(),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 9),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(caption, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({
    required this.total,
    required this.newItems,
    required this.learning,
    required this.review,
    required this.mastered,
  });

  final int total;
  final int newItems;
  final int learning;
  final int review;
  final int mastered;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('학습 단계', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '표현별 학습 상태를 확인하세요.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _DistributionRow(
              label: '새 항목',
              value: newItems,
              total: total,
              color: const Color(0xFF94A3B8),
            ),
            const SizedBox(height: 13),
            _DistributionRow(
              label: '학습 중',
              value: learning,
              total: total,
              color: AppTheme.desktopAccent,
            ),
            const SizedBox(height: 13),
            _DistributionRow(
              label: '복습 중',
              value: review,
              total: total,
              color: AppTheme.desktopPrimary,
            ),
            const SizedBox(height: 13),
            _DistributionRow(
              label: '완전히 익힘',
              value: mastered,
              total: total,
              color: AppTheme.success,
            ),
          ],
        ),
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  const _DistributionRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  final String label;
  final int value;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : value / total;
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 9,
              color: color,
              backgroundColor: color.withValues(alpha: 0.1),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 30,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badges});

  final Set<String> badges;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('획득한 배지', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              badges.isEmpty
                  ? '첫 학습을 마치면 배지를 받을 수 있어요.'
                  : '${badges.length}개를 획득했어요.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (badges.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    children: [
                      Icon(
                        Icons.workspace_premium_outlined,
                        size: 42,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '아직 획득한 배지가 없습니다.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final badge in badges)
                    Chip(
                      avatar: const Icon(
                        Icons.workspace_premium_rounded,
                        size: 18,
                        color: AppTheme.warning,
                      ),
                      label: Text(badge),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
