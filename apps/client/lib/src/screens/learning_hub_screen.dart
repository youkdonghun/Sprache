import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/course_path.dart';
import '../domain/learning_item.dart';
import '../domain/study_preferences.dart';
import '../services/app_clock.dart';
import '../state/app_state.dart';
import '../widgets/course_picker.dart';

class LearningHubScreen extends ConsumerWidget {
  const LearningHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final items = controller.selectedItems;
    final coursePath = controller.coursePath;
    final recommendedUnit = coursePath.recommendedUnit;
    final wordCount = items
        .where((item) => item.kind == LearningItemKind.word)
        .length;
    final sentenceCount = items.length - wordCount;
    final favoriteCount = items
        .where((item) => state.preferences.isFavorite(item.id))
        .length;
    final sessionPlan = state.preferences.sessionPlan;
    final sessionPreview = controller.previewSessionPlan(
      sessionPlan,
      ref.read(appClockProvider)(),
    );

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final padding = compact ? 18.0 : 28.0;
          return CustomScrollView(
            key: const Key('learning-hub-scroll'),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 22, padding, 36),
                sliver: SliverToBoxAdapter(
                  child: Center(
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
                                      '${state.selectedLanguage.koreanName} 학습실',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '먼저 익히고, 문제로 확인하고, 소리 내어 말해 보세요.',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _CountBadge(
                                label: '단어 $wordCount · 문장 $sentenceCount',
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const CoursePicker(),
                          const SizedBox(height: 18),
                          _SessionBuilderBanner(
                            plan: sessionPlan,
                            itemCount: sessionPreview.items.length,
                            wordCount: sessionPreview.selectedWordCount,
                            sentenceCount: sessionPreview.selectedSentenceCount,
                            onOpen: () => context.push('/session-builder'),
                          ),
                          const SizedBox(height: 14),
                          _RecommendedRoutine(
                            languageName: state.selectedLanguage.nativeName,
                            unitTitle:
                                'Unit ${recommendedUnit.index + 1} · ${recommendedUnit.title}',
                            lesson: recommendedUnit.nextLesson,
                            onStart: () => context.push(
                              courseLessonRoute(
                                recommendedUnit.nextLesson,
                                recommendedUnit.index,
                              ),
                            ),
                            onPath: () => context.go('/path'),
                          ),
                          const SizedBox(height: 26),
                          _ActivitySection(
                            eyebrow: '1 · 기본 공부',
                            title: '카드로 먼저 익히기',
                            caption: '정답을 맞히기 전에 표현과 뜻, 읽는 법을 차분히 살펴봅니다.',
                            activities: [
                              const _Activity(
                                icon: Icons.style_rounded,
                                title: '단어 카드',
                                description: '표현을 보고 뜻과 읽는 법 익히기',
                                route: '/cards?kind=words',
                                badge: '기초',
                              ),
                              const _Activity(
                                icon: Icons.menu_book_rounded,
                                title: '문장 카드',
                                description: '문장 전체를 듣고 의미와 구조 익히기',
                                route: '/cards?kind=sentences',
                                badge: '기초',
                              ),
                              _Activity(
                                icon: Icons.auto_stories_rounded,
                                title: '단원 표현 노트',
                                description: '문장 구조와 상황별 사용 팁을 예문으로 이해',
                                route: '/notes/${recommendedUnit.index}',
                                badge: '문법',
                              ),
                              _Activity(
                                icon: Icons.star_rounded,
                                title: '저장한 표현',
                                description: favoriteCount == 0
                                    ? '단어장에서 별표를 눌러 나만의 복습 묶음 만들기'
                                    : '별표로 모은 표현만 바로 다시 연습',
                                route: '/study?mode=favorites',
                                badge: '저장 $favoriteCount',
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          _ActivitySection(
                            eyebrow: '2 · 문제 연습',
                            title: '기억을 꺼내 확인하기',
                            caption: '한 방식만 반복하지 않고 기억의 방향을 바꿔 연습합니다.',
                            activities: const [
                              _Activity(
                                icon: Icons.touch_app_rounded,
                                title: '뜻 고르기',
                                description: '외국어 표현에 맞는 한국어 뜻 선택',
                                route: '/study?mode=meaning',
                                badge: '선택',
                              ),
                              _Activity(
                                icon: Icons.keyboard_rounded,
                                title: '직접 쓰기',
                                description: '뜻을 보고 외국어 표현 직접 입력',
                                route: '/study?mode=production',
                                badge: '쓰기',
                              ),
                              _Activity(
                                icon: Icons.space_bar_rounded,
                                title: '문장 빈칸',
                                description: '문맥에 맞는 표현을 문장 안에 넣기',
                                route: '/study?mode=cloze',
                                badge: '문장',
                              ),
                              _Activity(
                                icon: Icons.reorder_rounded,
                                title: '문장 배열',
                                description: '흩어진 단어를 순서대로 조립하기',
                                route: '/study?mode=sentenceOrder',
                                badge: '문장',
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          _ActivitySection(
                            eyebrow: '3 · 소리 연습',
                            title: '듣고 말하기',
                            caption: '목표 발음을 들은 뒤 받아쓰거나 직접 말해 봅니다.',
                            activities: const [
                              _Activity(
                                icon: Icons.headphones_rounded,
                                title: '듣고 쓰기',
                                description: '소리만 듣고 단어와 문장을 받아쓰기',
                                route: '/study?mode=listening',
                                badge: '듣기',
                              ),
                              _Activity(
                                icon: Icons.mic_rounded,
                                title: '발음 따라하기',
                                description: '마이크로 말하고 인식 문장과 일치도 확인',
                                route: '/pronunciation',
                                badge: '말하기',
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          _ActivitySection(
                            eyebrow: '4 · 실전과 복습',
                            title: '상황에서 꺼내 쓰기',
                            caption: '짧은 상황 대화로 연결하거나 취약한 표현만 모아 다시 연습합니다.',
                            activities: const [
                              _Activity(
                                icon: Icons.forum_rounded,
                                title: '실전 상황 미션',
                                description: '듣기·뜻 확인·말하기를 상황별로 연결',
                                route: '/missions',
                                badge: '실전',
                              ),
                              _Activity(
                                icon: Icons.shuffle_rounded,
                                title: '5분 혼합 루틴',
                                description: '단어와 문장, 듣기를 고르게 복습',
                                route: '/study?mode=mixed',
                                badge: '추천',
                              ),
                              _Activity(
                                icon: Icons.bolt_rounded,
                                title: '취약 표현 집중',
                                description: '정확도 70% 미만 표현만 다시 확인',
                                route: '/study?mode=weak',
                                badge: '복습',
                              ),
                            ],
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

class _SessionBuilderBanner extends StatelessWidget {
  const _SessionBuilderBanner({
    required this.plan,
    required this.itemCount,
    required this.wordCount,
    required this.sentenceCount,
    required this.onOpen,
  });

  final StudySessionPlan plan;
  final int itemCount;
  final int wordCount;
  final int sentenceCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('open-session-builder'),
      color: colors.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final icon = Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.onTertiaryContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: colors.onTertiaryContainer,
                ),
              );
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '나만의 학습 세션',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plan.deck.label} · ${plan.difficulty.label} · '
                    '$itemCount문제',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onTertiaryContainer.withValues(alpha: 0.78),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _SessionPill(label: plan.mode.label),
                      _SessionPill(label: '단어 $wordCount'),
                      _SessionPill(label: '문장 $sentenceCount'),
                    ],
                  ),
                ],
              );
              final action = FilledButton.icon(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(150, 48),
                  backgroundColor: colors.onTertiaryContainer,
                  foregroundColor: colors.tertiaryContainer,
                ),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('세션 설계'),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        icon,
                        const SizedBox(width: 13),
                        Expanded(child: copy),
                      ],
                    ),
                    const SizedBox(height: 14),
                    action,
                  ],
                );
              }
              return Row(
                children: [
                  icon,
                  const SizedBox(width: 14),
                  Expanded(child: copy),
                  const SizedBox(width: 18),
                  action,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SessionPill extends StatelessWidget {
  const _SessionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onTertiaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _RecommendedRoutine extends StatelessWidget {
  const _RecommendedRoutine({
    required this.languageName,
    required this.unitTitle,
    required this.lesson,
    required this.onStart,
    required this.onPath,
  });

  final String languageName;
  final String unitTitle;
  final CourseLessonKind lesson;
  final VoidCallback onStart;
  final VoidCallback onPath;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 추천 시작',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$languageName · $unitTitle',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  lesson.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('start-flashcards'),
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.onPrimaryContainer,
                    foregroundColor: colors.primaryContainer,
                    minimumSize: const Size(160, 48),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(lesson.label),
                ),
                TextButton.icon(
                  key: const Key('open-course-path'),
                  onPressed: onPath,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onPrimaryContainer,
                    minimumSize: const Size(0, 48),
                  ),
                  icon: const Icon(Icons.route_rounded),
                  label: const Text('코스 여정'),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 18), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 24),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({
    required this.eyebrow,
    required this.title,
    required this.caption,
    required this.activities,
  });

  final String eyebrow;
  final String title;
  final String caption;
  final List<_Activity> activities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          eyebrow,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 3),
        Text(caption, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 3 : 2;
            final actualColumns = constraints.maxWidth < 620 ? 1 : columns;
            final width =
                (constraints.maxWidth - (actualColumns - 1) * 10) /
                actualColumns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final activity in activities)
                  SizedBox(
                    width: width,
                    child: _ActivityCard(activity: activity),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final _Activity activity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: () => context.push(activity.route),
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 104),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    activity.icon,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              activity.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _MiniBadge(label: activity.badge),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label});

  final String label;

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
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.onPrimaryContainer,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Activity {
  const _Activity({
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
    required this.badge,
  });

  final IconData icon;
  final String title;
  final String description;
  final String route;
  final String badge;
}
