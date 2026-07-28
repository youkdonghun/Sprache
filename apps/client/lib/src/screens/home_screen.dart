import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/active_study_session.dart';
import '../domain/course_path.dart';
import '../domain/language.dart';
import '../domain/progress.dart';
import '../domain/study_preferences.dart';
import '../services/window_workspace_service.dart';
import '../services/app_clock.dart';
import '../state/app_state.dart';
import '../state/connection_state.dart';
import '../theme/app_theme.dart';
import '../widgets/course_picker.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final now = ref.watch(appClockProvider)();
    final coursePath = controller.coursePath;
    final recommendedUnit = coursePath.recommendedUnit;
    final today = DateUtils.dateOnly(now);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final weeklyActiveDays = state.recentSessions
        .where(
          (session) =>
              session.courseId == state.selectedLanguage.courseId &&
              !session.endedAt.isBefore(weekStart) &&
              session.endedAt.isBefore(weekEnd),
        )
        .map((session) => session.endedAt.weekday)
        .toSet();
    final lastStudyDate = state.lastStudyDate;
    if (lastStudyDate != null &&
        !lastStudyDate.isBefore(weekStart) &&
        lastStudyDate.isBefore(weekEnd)) {
      weeklyActiveDays.add(lastStudyDate.weekday);
    }
    final queue = controller.queue(now);
    final selectedItems = controller.selectedItems;
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    final windowWorkspace = ref.watch(windowWorkspaceControllerProvider);
    if (isWindows) {
      ref.listen(windowWorkspaceControllerProvider, (previous, next) {
        if (next.errorMessage != null &&
            next.errorMessage != previous?.errorMessage) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(next.errorMessage!)));
        }
      });
    }
    final forecast = controller.reviewForecast(now);
    final reviewCount = forecast.dueNow;
    final newCount = min(
      state.preferences.newItemLimit,
      selectedItems
          .where(
            (item) =>
                state.progress[item.id] == null ||
                state.progress[item.id]!.status == LearningStatus.newItem,
          )
          .length,
    );
    final weakCount = state.progress.values.where((progress) {
      return progress.attempts > 0 &&
          progress.accuracy < 0.7 &&
          selectedItems.any((item) => item.id == progress.itemId);
    }).length;
    final masteredCount = state.progress.values.where((progress) {
      return progress.status == LearningStatus.mastered &&
          selectedItems.any((item) => item.id == progress.itemId);
    }).length;
    final attempts = state.progress.values.fold<int>(
      0,
      (sum, progress) => sum + progress.attempts,
    );
    final correct = state.progress.values.fold<int>(
      0,
      (sum, progress) => sum + progress.correctCount,
    );
    final accuracy = attempts == 0 ? 0 : (correct / attempts * 100).round();
    final coverage = selectedItems.isEmpty
        ? 0
        : (state.progress.keys
                      .where((id) => selectedItems.any((item) => item.id == id))
                      .length /
                  selectedItems.length *
                  100)
              .round();

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final officeCompact = isWindows && constraints.maxWidth < 560;
          final mobile = constraints.maxWidth < 720;
          final wide = constraints.maxWidth >= 1020;
          final padding = officeCompact
              ? 14.0
              : mobile
              ? 18.0
              : 28.0;
          return CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  officeCompact ? 14 : 22,
                  padding,
                  32,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _HomeHeader(
                            compact: officeCompact,
                            now: now,
                            language: state.selectedLanguage,
                            streakDays: state.streakDays,
                            connected: state.driveConnected,
                            windowWorkspace: isWindows ? windowWorkspace : null,
                            onToggleCompact: isWindows
                                ? () => unawaited(
                                    ref
                                        .read(
                                          windowWorkspaceControllerProvider
                                              .notifier,
                                        )
                                        .toggleCompact(),
                                  )
                                : null,
                            onMinimize: isWindows
                                ? () => unawaited(
                                    ref
                                        .read(
                                          windowWorkspaceControllerProvider
                                              .notifier,
                                        )
                                        .minimize(),
                                  )
                                : null,
                            onSettings: () => context.go('/settings'),
                          ),
                          if (!officeCompact) ...[
                            const SizedBox(height: 18),
                            const CoursePicker(),
                          ],
                          if (state.activeStudySession case final active?) ...[
                            SizedBox(height: officeCompact ? 14 : 18),
                            _ResumeSessionCard(
                              session: active,
                              cloudConnected: state.driveConnected,
                              language: LanguageTag.values.firstWhere(
                                (language) =>
                                    language.courseId == active.courseId,
                                orElse: () => state.selectedLanguage,
                              ),
                              onResume: () {
                                final language = LanguageTag.values.firstWhere(
                                  (language) =>
                                      language.courseId == active.courseId,
                                  orElse: () => state.selectedLanguage,
                                );
                                controller.selectLanguage(language);
                                context.push('/study?resume=true');
                              },
                              onDiscard: () {
                                controller.clearActiveStudySession();
                                if (state.driveConnected) {
                                  unawaited(
                                    ref
                                        .read(
                                          connectionControllerProvider.notifier,
                                        )
                                        .syncNow(),
                                  );
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '중단한 세션을 종료했습니다. 학습 진도는 유지됩니다.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                          SizedBox(height: officeCompact ? 14 : 20),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _DailyHero(
                                    compact: false,
                                    language: state.selectedLanguage,
                                    queueCount: queue.length,
                                    dailyXp: state.dailyXp,
                                    dailyGoal: state.dailyGoal,
                                    level: state.level,
                                    unitTitle:
                                        'Unit ${recommendedUnit.index + 1} · ${recommendedUnit.title}',
                                    nextLessonLabel:
                                        recommendedUnit.nextLesson.label,
                                    onStart: () => context.push(
                                      courseLessonRoute(
                                        recommendedUnit.nextLesson,
                                        recommendedUnit.index,
                                      ),
                                    ),
                                    onPath: () => context.go('/path'),
                                    onPractice: () => context.go('/learn'),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 4,
                                  child: _TodayPlan(
                                    reviewCount: reviewCount,
                                    newCount: newCount,
                                    weakCount: weakCount,
                                    onMode: (mode) => context.push(
                                      '/study?mode=${mode.name}',
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else ...[
                            _DailyHero(
                              compact: officeCompact,
                              language: state.selectedLanguage,
                              queueCount: queue.length,
                              dailyXp: state.dailyXp,
                              dailyGoal: state.dailyGoal,
                              level: state.level,
                              unitTitle:
                                  'Unit ${recommendedUnit.index + 1} · ${recommendedUnit.title}',
                              nextLessonLabel: recommendedUnit.nextLesson.label,
                              onStart: () => context.push(
                                courseLessonRoute(
                                  recommendedUnit.nextLesson,
                                  recommendedUnit.index,
                                ),
                              ),
                              onPath: () => context.go('/path'),
                              onPractice: () => context.go('/learn'),
                            ),
                            SizedBox(height: officeCompact ? 12 : 16),
                            _TodayPlan(
                              compact: officeCompact,
                              reviewCount: reviewCount,
                              newCount: newCount,
                              weakCount: weakCount,
                              onMode: (mode) =>
                                  context.push('/study?mode=${mode.name}'),
                            ),
                          ],
                          if (!officeCompact) ...[
                            const SizedBox(height: 22),
                            LayoutBuilder(
                              builder: (context, panelConstraints) {
                                final mission = _MissionSpotlight(
                                  unit: recommendedUnit,
                                  onStart: () => context.go(
                                    '/mission/${recommendedUnit.index}',
                                  ),
                                  onAll: () => context.go('/missions'),
                                );
                                final rhythm = _WeeklyRhythm(
                                  activeWeekdays: weeklyActiveDays,
                                  todayWeekday: today.weekday,
                                  onReport: () => context.go('/stats'),
                                );
                                if (panelConstraints.maxWidth >= 760) {
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(flex: 5, child: mission),
                                      const SizedBox(width: 14),
                                      Expanded(flex: 4, child: rhythm),
                                    ],
                                  );
                                }
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    mission,
                                    const SizedBox(height: 12),
                                    rhythm,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 22),
                            _SectionHeading(
                              title: '학습 방식',
                              caption: '익히기·문제·말하기를 골고루 사용하세요.',
                              onAll: () => context.go('/learn'),
                            ),
                            const SizedBox(height: 10),
                            _PracticeGrid(onSelected: context.push),
                            const SizedBox(height: 22),
                            _CourseSummary(
                              coverage: coverage,
                              accuracy: accuracy,
                              masteredCount: masteredCount,
                              connected: state.driveConnected,
                              onLibrary: () => context.go('/library'),
                              onSettings: () => context.go('/settings'),
                            ),
                          ] else ...[
                            const SizedBox(height: 10),
                            _OfficeQuickActions(
                              onCourse: () => context.go('/path'),
                              onPractice: () => context.go('/learn'),
                              onMission: () => context.go(
                                '/mission/${recommendedUnit.index}',
                              ),
                            ),
                          ],
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

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.compact,
    required this.now,
    required this.language,
    required this.streakDays,
    required this.connected,
    required this.onSettings,
    this.windowWorkspace,
    this.onToggleCompact,
    this.onMinimize,
  });

  final bool compact;
  final DateTime now;
  final LanguageTag language;
  final int streakDays;
  final bool connected;
  final VoidCallback onSettings;
  final WindowWorkspaceState? windowWorkspace;
  final VoidCallback? onToggleCompact;
  final VoidCallback? onMinimize;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final date = '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                compact ? '오늘 체크리스트' : '오늘의 ${language.koreanName}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 3),
              Text(
                compact ? '${language.nativeName} · 빠른 복습' : date,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        _HeaderBadge(
          icon: Icons.local_fire_department_rounded,
          label: '$streakDays일',
          color: AppTheme.warning,
          tooltip: '연속 학습 $streakDays일',
        ),
        if (windowWorkspace != null && onToggleCompact != null) ...[
          const SizedBox(width: 8),
          _HeaderBadge(
            key: const Key('window-compact-toggle'),
            icon: windowWorkspace!.compact
                ? Icons.open_in_full_rounded
                : Icons.picture_in_picture_alt_rounded,
            label: windowWorkspace!.compact ? '확장' : '집중',
            color: Theme.of(context).colorScheme.primary,
            tooltip: windowWorkspace!.compact
                ? '기본 창으로 복원 (Ctrl+Shift+F)'
                : '집중 창으로 전환 (Ctrl+Shift+F)',
            showLabel: !compact,
            onTap: windowWorkspace!.busy ? null : onToggleCompact,
          ),
        ],
        if (windowWorkspace != null && onMinimize != null) ...[
          const SizedBox(width: 8),
          _HeaderBadge(
            key: const Key('window-quick-minimize'),
            icon: Icons.minimize_rounded,
            label: '최소화',
            color: Theme.of(context).colorScheme.outline,
            tooltip: '빠르게 최소화 (Ctrl+Shift+M)',
            showLabel: false,
            onTap: windowWorkspace!.busy ? null : onMinimize,
          ),
        ],
        const SizedBox(width: 8),
        _HeaderBadge(
          key: const Key('home-settings'),
          icon: connected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
          label: connected ? '저장됨' : '설정',
          color: connected
              ? AppTheme.success
              : Theme.of(context).colorScheme.outline,
          tooltip: connected ? 'Google Drive 및 설정 열기' : '로컬 저장 및 설정 열기',
          showLabel: !compact,
          onTap: onSettings,
        ),
      ],
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.tooltip,
    this.showLabel = true,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;
  final bool showLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.symmetric(horizontal: showLabel ? 11 : 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: color),
          if (showLabel) ...[
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
    return Tooltip(
      message: tooltip,
      child: onTap == null
          ? badge
          : Semantics(
              button: true,
              label: tooltip,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(14),
                  child: badge,
                ),
              ),
            ),
    );
  }
}

class _ResumeSessionCard extends StatelessWidget {
  const _ResumeSessionCard({
    required this.session,
    required this.language,
    required this.cloudConnected,
    required this.onResume,
    required this.onDiscard,
  });

  final ActiveStudySession session;
  final LanguageTag language;
  final bool cloudConnected;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progressLabel =
        '${session.completedCount}/${session.itemIds.length}문제';
    final accuracy = (session.accuracy * 100).round();
    return Card(
      key: const Key('resume-study-card'),
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.restore_rounded, color: colors.tertiary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.phase == ActiveStudySessionPhase.paused
                            ? '일시정지한 학습 이어하기'
                            : '진행 중인 학습 이어하기',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      progressLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  '${language.symbol} ${language.koreanName} · ${session.mode.label}'
                  '${session.unitIndex == null ? '' : ' · Unit ${session.unitIndex! + 1}'}'
                  ' · ${session.origin.label}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  session.attempts == 0
                      ? '아직 푼 문제는 없습니다. 같은 문제 순서로 다시 시작합니다.'
                      : '정답 ${session.correctCount} · 오답 ${session.wrongCount} · 정확도 $accuracy% · +${session.earnedXp} XP',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (session.pauseCount + session.resumeCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '일시정지 ${session.pauseCount}회 · 이어하기 ${session.resumeCount}회'
                    '${session.generation == 0 ? '' : ' · ${session.generation}단계 분기'}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    Icon(
                      cloudConnected
                          ? Icons.cloud_sync_rounded
                          : Icons.save_outlined,
                      size: 16,
                      color: colors.onTertiaryContainer.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cloudConnected
                            ? 'Drive 연결 시 Android·Windows에서 같은 지점을 이어갑니다.'
                            : '현재 이 기기에 자동 저장 중입니다.',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: session.progress,
                    minHeight: 7,
                    backgroundColor: colors.surface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  key: const Key('discard-active-session'),
                  onPressed: onDiscard,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(78, 48),
                  ),
                  child: const Text('종료'),
                ),
                FilledButton.icon(
                  key: const Key('resume-active-session'),
                  onPressed: onResume,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(126, 48),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(session.remainingCount == 0 ? '결과 보기' : '이어하기'),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  copy,
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 18),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DailyHero extends StatelessWidget {
  const _DailyHero({
    required this.compact,
    required this.language,
    required this.queueCount,
    required this.dailyXp,
    required this.dailyGoal,
    required this.level,
    required this.unitTitle,
    required this.nextLessonLabel,
    required this.onStart,
    required this.onPath,
    required this.onPractice,
  });

  final bool compact;
  final LanguageTag language;
  final int queueCount;
  final int dailyXp;
  final int dailyGoal;
  final int level;
  final String unitTitle;
  final String nextLessonLabel;
  final VoidCallback onStart;
  final VoidCallback onPath;
  final VoidCallback onPractice;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = dailyGoal == 0 ? 0.0 : min(1.0, dailyXp / dailyGoal);
    return Card(
      color: colors.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(compact ? 14 : 20),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 22),
        child: Row(
          children: [
            if (!compact) ...[
              _ProgressDial(progress: progress, xp: dailyXp, goal: dailyGoal),
              const SizedBox(width: 20),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    queueCount == 0
                        ? '오늘 루틴을 완료했어요'
                        : '${language.nativeName} · Level $level',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    queueCount == 0
                        ? '가볍게 자유 연습을 이어가세요.'
                        : '$unitTitle\n$nextLessonLabel부터 이어서',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      height: 1.18,
                    ),
                  ),
                  if (compact) ...[
                    const SizedBox(height: 5),
                    Text(
                      '$dailyXp / $dailyGoal XP',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onPrimaryContainer.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: onStart,
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.onPrimaryContainer,
                          foregroundColor: colors.primaryContainer,
                          minimumSize: Size(
                            compact ? 0 : 150,
                            compact ? 44 : 48,
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(compact ? '다음 학습' : '다음 레슨'),
                      ),
                      if (!compact)
                        TextButton.icon(
                          onPressed: onPath,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.onPrimaryContainer,
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.route_rounded),
                          label: const Text('코스 여정'),
                        ),
                      if (!compact)
                        TextButton.icon(
                          onPressed: onPractice,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.onPrimaryContainer,
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.grid_view_rounded),
                          label: const Text('자유 학습'),
                        ),
                    ],
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

class _ProgressDial extends StatelessWidget {
  const _ProgressDial({
    required this.progress,
    required this.xp,
    required this.goal,
  });

  final double progress;
  final int xp;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: 88,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: colors.onPrimaryContainer.withValues(
                alpha: 0.14,
              ),
              color: colors.onPrimaryContainer,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$xp',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                ),
              ),
              Text(
                '/ $goal XP',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onPrimaryContainer.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayPlan extends StatelessWidget {
  const _TodayPlan({
    required this.reviewCount,
    required this.newCount,
    required this.weakCount,
    required this.onMode,
    this.compact = false,
  });

  final int reviewCount;
  final int newCount;
  final int weakCount;
  final ValueChanged<StudyMode> onMode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!compact) ...[
              Text('오늘의 학습', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '복습을 먼저 끝내고 새 표현을 만나세요.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            _PlanRow(
              icon: Icons.replay_rounded,
              label: '복습 예정',
              count: reviewCount,
              color: AppTheme.desktopPrimary,
              onTap: () => onMode(StudyMode.review),
            ),
            if (!compact) const Divider(height: 16),
            _PlanRow(
              icon: Icons.auto_awesome_rounded,
              label: '새 표현',
              count: newCount,
              color: AppTheme.mobilePrimary,
              onTap: () => onMode(StudyMode.newItems),
            ),
            if (!compact) const Divider(height: 16),
            _PlanRow(
              icon: Icons.bolt_rounded,
              label: '집중 필요',
              count: weakCount,
              color: AppTheme.warning,
              onTap: () => onMode(StudyMode.weak),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionSpotlight extends StatelessWidget {
  const _MissionSpotlight({
    required this.unit,
    required this.onStart,
    required this.onAll,
  });

  final CourseUnitSnapshot unit;
  final VoidCallback onStart;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.onSecondaryContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.forum_rounded,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘의 실전 미션',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                      Text(
                        'Unit ${unit.index + 1} · ${unit.title}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: colors.onSecondaryContainer),
                      ),
                    ],
                  ),
                ),
                _CompactPill(label: '약 3분'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              unit.goal,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSecondaryContainer.withValues(alpha: 0.82),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('home-start-mission'),
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.onSecondaryContainer,
                    foregroundColor: colors.secondaryContainer,
                    minimumSize: const Size(146, 48),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('상황 연습 시작'),
                ),
                TextButton(
                  onPressed: onAll,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onSecondaryContainer,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('6개 미션 보기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyRhythm extends StatelessWidget {
  const _WeeklyRhythm({
    required this.activeWeekdays,
    required this.todayWeekday,
    required this.onReport,
  });

  final Set<int> activeWeekdays;
  final int todayWeekday;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const labels = ['월', '화', '수', '목', '금', '토', '일'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                        '이번 주 학습 리듬',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeWeekdays.isEmpty
                            ? '오늘 첫 기록을 만들어 보세요.'
                            : '${activeWeekdays.length}일 학습 · 흐름을 이어가세요.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onReport,
                  tooltip: '학습 리포트 열기',
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var index = 0; index < labels.length; index++)
                  _WeekdayDot(
                    label: labels[index],
                    active: activeWeekdays.contains(index + 1),
                    today: todayWeekday == index + 1,
                    activeColor: colors.primary,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: activeWeekdays.length / 7,
              minHeight: 7,
              borderRadius: BorderRadius.circular(7),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayDot extends StatelessWidget {
  const _WeekdayDot({
    required this.label,
    required this.active,
    required this.today,
    required this.activeColor,
  });

  final String label;
  final bool active;
  final bool today;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? activeColor : colors.surfaceContainerLow,
            shape: BoxShape.circle,
            border: Border.all(
              color: today ? activeColor : colors.outlineVariant,
              width: today ? 2 : 1,
            ),
          ),
          child: active
              ? Icon(Icons.check_rounded, size: 17, color: colors.onPrimary)
              : Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: today ? FontWeight.w900 : FontWeight.w700,
                    color: today ? activeColor : colors.onSurfaceVariant,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _OfficeQuickActions extends StatelessWidget {
  const _OfficeQuickActions({
    required this.onCourse,
    required this.onPractice,
    required this.onMission,
  });

  final VoidCallback onCourse;
  final VoidCallback onPractice;
  final VoidCallback onMission;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        OutlinedButton.icon(
          onPressed: onCourse,
          icon: const Icon(Icons.route_rounded, size: 18),
          label: const Text('코스'),
        ),
        OutlinedButton.icon(
          onPressed: onPractice,
          icon: const Icon(Icons.grid_view_rounded, size: 18),
          label: const Text('연습'),
        ),
        OutlinedButton.icon(
          onPressed: onMission,
          icon: const Icon(Icons.forum_rounded, size: 18),
          label: const Text('실전'),
        ),
      ],
    );
  }
}

class _CompactPill extends StatelessWidget {
  const _CompactPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.onSecondaryContainer,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: color),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$count',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 5),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.caption,
    this.onAll,
  });

  final String title;
  final String caption;
  final VoidCallback? onAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (onAll != null)
          TextButton(onPressed: onAll, child: const Text('전체 보기')),
      ],
    );
  }
}

class _PracticeGrid extends StatelessWidget {
  const _PracticeGrid({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const activities = [
    _HomeActivity(
      icon: Icons.style_rounded,
      title: '단어 카드',
      description: '뜻과 읽는 법 익히기',
      route: '/cards?kind=words',
    ),
    _HomeActivity(
      icon: Icons.menu_book_rounded,
      title: '문장 카드',
      description: '문장 전체를 먼저 익히기',
      route: '/cards?kind=sentences',
    ),
    _HomeActivity(
      icon: Icons.touch_app_rounded,
      title: '뜻 고르기',
      description: '기억을 가볍게 확인하기',
      route: '/study?mode=meaning',
    ),
    _HomeActivity(
      icon: Icons.space_bar_rounded,
      title: '문장 빈칸',
      description: '문맥에 알맞은 표현 넣기',
      route: '/study?mode=cloze',
    ),
    _HomeActivity(
      icon: Icons.headphones_rounded,
      title: '듣고 쓰기',
      description: '소리만 듣고 받아쓰기',
      route: '/study?mode=listening',
    ),
    _HomeActivity(
      icon: Icons.mic_rounded,
      title: '발음 따라하기',
      description: '마이크로 말하고 확인하기',
      route: '/pronunciation',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final activity in activities)
              SizedBox(
                width: width,
                child: _ActivityTile(
                  activity: activity,
                  onTap: () => onSelected(activity.route),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.activity, required this.onTap});

  final _HomeActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 76),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    activity.icon,
                    size: 20,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activity.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeActivity {
  const _HomeActivity({
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String description;
  final String route;
}

class _CourseSummary extends StatelessWidget {
  const _CourseSummary({
    required this.coverage,
    required this.accuracy,
    required this.masteredCount,
    required this.connected,
    required this.onLibrary,
    required this.onSettings,
  });

  final int coverage;
  final int accuracy;
  final int masteredCount;
  final bool connected;
  final VoidCallback onLibrary;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = Row(
              children: [
                Expanded(
                  child: _SummaryMetric(label: '학습 범위', value: '$coverage%'),
                ),
                const _MetricDivider(),
                Expanded(
                  child: _SummaryMetric(label: '정확도', value: '$accuracy%'),
                ),
                const _MetricDivider(),
                Expanded(
                  child: _SummaryMetric(
                    label: '완전 학습',
                    value: '$masteredCount',
                  ),
                ),
              ],
            );
            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton.icon(
                  onPressed: onLibrary,
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('단어장'),
                ),
                TextButton.icon(
                  onPressed: onSettings,
                  icon: Icon(
                    connected
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_off_rounded,
                  ),
                  label: Text(connected ? '동기화됨' : '백업 설정'),
                ),
              ],
            );
            if (constraints.maxWidth < 650) {
              return Column(
                children: [
                  metrics,
                  const Divider(height: 24),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: metrics),
                const SizedBox(width: 18),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 34,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}
