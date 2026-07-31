import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/course_path.dart';
import '../domain/progress.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class CoursePathScreen extends ConsumerWidget {
  const CoursePathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final activeSubject = controller.activeSubject;
    if (!activeSubject.isLanguage) {
      final items = controller.selectedItems;
      final studiedCount = items
          .where((item) => state.progress.containsKey(item.id))
          .length;
      final masteredCount = items
          .where(
            (item) =>
                state.progress[item.id]?.status == LearningStatus.mastered,
          )
          .length;
      return _GeneralSubjectWorkspace(
        subjectName: activeSubject.name,
        symbol: activeSubject.symbol,
        itemCount: items.length,
        studiedCount: studiedCount,
        masteredCount: masteredCount,
      );
    }
    final path = controller.coursePath;
    final recommendedIndex = path.recommendedUnit.index;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final padding = compact ? 18.0 : 28.0;
          return CustomScrollView(
            key: const Key('course-path-scroll'),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 22, padding, 36),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 820),
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
                                      '${state.selectedLanguage.koreanName} 코스 여정',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '단원마다 익히기·쓰기·문장·듣기·말하기를 순서대로 연습합니다.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _PathProgressBadge(percent: path.progressPercent),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _PathOverview(
                            unit: path.recommendedUnit,
                            totalProgress: path.progress,
                            onContinue: () => context.push(
                              courseLessonRoute(
                                path.recommendedUnit.nextLesson,
                                path.recommendedUnit.index,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '입문 코스 · 6개 단원',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '추천 순서로 배우되, 모든 단원을 자유롭게 미리 볼 수 있어요.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (final unit in path.units) ...[
                            _CourseUnitCard(
                              unit: unit,
                              current: unit.index == recommendedIndex,
                              onGuide: () =>
                                  context.push('/unit/${unit.index}'),
                              onStart: () => context.push(
                                courseLessonRoute(unit.nextLesson, unit.index),
                              ),
                            ),
                            if (unit.index != path.units.last.index)
                              _PathConnector(completed: unit.completed),
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

class _GeneralSubjectWorkspace extends StatelessWidget {
  const _GeneralSubjectWorkspace({
    required this.subjectName,
    required this.symbol,
    required this.itemCount,
    required this.studiedCount,
    required this.masteredCount,
  });

  final String subjectName;
  final String symbol;
  final int itemCount;
  final int studiedCount;
  final int masteredCount;

  @override
  Widget build(BuildContext context) {
    final progress = itemCount == 0 ? 0.0 : studiedCount / itemCount;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '$symbol $subjectName 학습 보드',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '자료를 모으고, 암기 카드와 퀴즈를 반복하며 내 일정에 맞춰 복습합니다.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  itemCount == 0
                                      ? '첫 자료를 추가해 보세요'
                                      : '학습 $studiedCount / $itemCount · 완전 암기 $masteredCount',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              Text(
                                '${(progress * 100).round()}%',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Semantics(
                            label: '$subjectName 학습 진행률',
                            value:
                                '$studiedCount / $itemCount, ${(progress * 100).round()}퍼센트',
                            child: ExcludeSemantics(
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 9,
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton.icon(
                                onPressed: () => context.go('/library/new'),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('직접 추가'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => context.go('/import'),
                                icon: const Icon(Icons.upload_file_rounded),
                                label: const Text('파일 가져오기'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth < 620
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 12) / 2;
                      final actions = [
                        (
                          Icons.style_rounded,
                          '암기 카드',
                          '개념과 설명을 차분히 익힌 뒤 기억 정도를 표시합니다.',
                          '/cards?kind=mixed',
                        ),
                        (
                          Icons.quiz_rounded,
                          '혼합 퀴즈',
                          '뜻 고르기와 직접 쓰기를 섞어 기억을 확인합니다.',
                          '/study?mode=mixed',
                        ),
                        (
                          Icons.event_note_rounded,
                          '학습 일정 만들기',
                          '원하는 자료만 골라 분량과 시간을 정합니다.',
                          '/session-builder',
                        ),
                        (
                          Icons.folder_copy_rounded,
                          '자료·그룹 관리',
                          '태그와 그룹으로 묶고 다른 학습 묶음으로 옮깁니다.',
                          '/library',
                        ),
                      ];
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final action in actions)
                            SizedBox(
                              width: width,
                              child: Card(
                                margin: EdgeInsets.zero,
                                child: InkWell(
                                  onTap: () => context.go(action.$4),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.all(18),
                                    child: Row(
                                      children: [
                                        Icon(action.$1, size: 30),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                action.$2,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.titleMedium,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                action.$3,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right_rounded),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathOverview extends StatelessWidget {
  const _PathOverview({
    required this.unit,
    required this.totalProgress,
    required this.onContinue,
  });

  final CourseUnitSnapshot unit;
  final double totalProgress;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 580;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '지금 이어서 할 학습',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Unit ${unit.index + 1} · ${unit.title}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unit.nextLesson.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 14),
                Semantics(
                  label: '${unit.title}까지의 코스 전체 진행률',
                  value: '${(totalProgress * 100).round()}퍼센트',
                  child: ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: totalProgress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                      color: colors.onPrimaryContainer,
                      backgroundColor: colors.onPrimaryContainer.withValues(
                        alpha: 0.15,
                      ),
                    ),
                  ),
                ),
              ],
            );
            final button = FilledButton.icon(
              key: const Key('continue-course-lesson'),
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                backgroundColor: colors.onPrimaryContainer,
                foregroundColor: colors.primaryContainer,
                minimumSize: const Size(170, 48),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(unit.nextLesson.label),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 18), button],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 24),
                button,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CourseUnitCard extends StatelessWidget {
  const _CourseUnitCard({
    required this.unit,
    required this.current,
    required this.onGuide,
    required this.onStart,
  });

  final CourseUnitSnapshot unit;
  final bool current;
  final VoidCallback onGuide;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = unit.completed
        ? AppTheme.success
        : current
        ? colors.primary
        : colors.outline;
    return Card(
      key: Key('course-unit-${unit.index}'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: current ? accent : colors.outlineVariant,
          width: current ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: unit.completed
                      ? Icon(Icons.check_rounded, color: accent)
                      : Text(
                          '${unit.index + 1}',
                          style: TextStyle(
                            color: accent,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
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
                              unit.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (current)
                            _StatusPill(label: '현재 단원', color: accent)
                          else if (unit.completed)
                            _StatusPill(label: '완료', color: accent),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unit.goal,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Unit ${unit.index + 1} ${unit.title} 학습 진행률',
                    value:
                        '${unit.studiedCount} / ${unit.items.length}, ${unit.progressPercent}퍼센트',
                    child: ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: unit.progress,
                          minHeight: 8,
                          color: accent,
                          backgroundColor: accent.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${unit.progressPercent}%',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '표현 ${unit.items.length}개 · 학습 ${unit.studiedCount}개 · 다음: ${unit.nextLesson.label}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onGuide,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('단원 가이드'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onStart,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('학습 시작'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PathConnector extends StatelessWidget {
  const _PathConnector({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: 3,
        height: 18,
        margin: const EdgeInsets.only(left: 41),
        color: completed
            ? AppTheme.success.withValues(alpha: 0.5)
            : Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class _PathProgressBadge extends StatelessWidget {
  const _PathProgressBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 58, minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Text(
        '$percent%',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
