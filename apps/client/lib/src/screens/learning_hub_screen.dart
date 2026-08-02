import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../domain/learning_item.dart';
import '../domain/quiz_session_support.dart';
import '../domain/session_enhancements.dart';
import '../domain/smart_collection.dart';
import '../domain/study_history.dart';
import '../domain/study_interaction_preferences.dart';
import '../domain/study_limits.dart';
import '../domain/study_preferences.dart';
import '../services/app_clock.dart';
import '../state/app_state.dart';

class LearningHubScreen extends ConsumerWidget {
  const LearningHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final activeSubject = controller.activeSubject;
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
    final sessionPlan = controller.activeSessionPlan;
    final pinnedCollections = controller.smartCollections
        .where((collection) => collection.pinned)
        .toList(growable: false);
    final sessionPreview = controller.previewSessionPlan(
      sessionPlan,
      ref.read(appClockProvider)(),
    );
    StudySessionSummary? recentSession;
    for (final session in state.recentSessions) {
      if (session.courseId == state.activeCourseId) {
        recentSession = session;
        break;
      }
    }

    void reopenRecentSession(StudySessionSummary session) {
      final availableIds = items.map((item) => item.id).toSet();
      final selectedIds = session.itemIds.where(availableIds.contains).toSet();
      if (selectedIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('최근 학습 자료가 변경되어 기본 맞춤 설정을 엽니다.')),
        );
        context.push('/session-builder');
        return;
      }
      final local = session.endedAt.toLocal();
      controller.updateSessionPlan(
        sessionPlan.copyWith(
          planId: '',
          subjectId: activeSubject.id,
          title: '${local.month}/${local.day} 최근 학습 다시 보기',
          mode: session.mode,
          deck: StudyDeckScope.selected,
          difficulty: StudyDifficulty.all,
          historyFilter: session.historyFilter,
          groupIds: {},
          tags: {},
          levels: {},
          selectedItemIds: selectedIds,
          includeWords: true,
          includeSentences: true,
          itemLimit: selectedIds.length.clamp(
            StudyLimits.minSessionItems,
            StudyLimits.maxSessionItems,
          ),
          lengthMode: StudySessionLengthMode.itemCount,
          recordProgress: session.recordProgress,
          scheduledAt: null,
        ),
      );
      context.push('/session-builder');
    }

    void openPinnedCollection(SmartCollectionDefinition collection) {
      final collectionItems = controller.itemsForSmartCollection(collection);
      if (collectionItems.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('현재 조건에 맞는 자료가 없어요.')));
        return;
      }
      controller.updateSessionPlan(
        sessionPlan.copyWith(
          planId: '',
          subjectId: activeSubject.id,
          title: collection.name,
          deck: StudyDeckScope.selected,
          difficulty: StudyDifficulty.all,
          historyFilter: StudyHistoryFilter.all,
          groupIds: {},
          tags: {},
          levels: {},
          selectedItemIds: collectionItems.map((item) => item.id).toSet(),
          includeWords: true,
          includeSentences: true,
          itemLimit: collectionItems.length.clamp(
            StudyLimits.minSessionItems,
            StudyLimits.maxSessionItems,
          ),
          lengthMode: StudySessionLengthMode.itemCount,
          scheduledAt: null,
        ),
      );
      context.push('/session-builder');
    }

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final padding = compact ? 16.0 : 28.0;
          return CustomScrollView(
            key: const Key('learning-hub-scroll'),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  compact ? 16 : 22,
                  padding,
                  compact ? 24 : 36,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (compact) ...[
                            Text(
                              activeSubject.isLanguage
                                  ? '${activeSubject.name} 학습실'
                                  : '${activeSubject.symbol} ${activeSubject.name} 학습실',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '익히기 · 문제 · 듣기 · 발음을 한곳에서 연습합니다.',
                              maxLines: 2,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Flexible(
                                  child: _CountBadge(
                                    label: activeSubject.isLanguage
                                        ? '단어 $wordCount · 문장 $sentenceCount'
                                        : '개념 $wordCount · 사실 $sentenceCount',
                                  ),
                                ),
                                const Spacer(),
                                _CourseShortcut(
                                  onPressed: () => context.go('/path'),
                                ),
                              ],
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activeSubject.isLanguage
                                            ? '${activeSubject.name} 학습실'
                                            : '${activeSubject.symbol} ${activeSubject.name} 학습실',
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
                                  label: activeSubject.isLanguage
                                      ? '단어 $wordCount · 문장 $sentenceCount'
                                      : '개념 $wordCount · 사실 $sentenceCount',
                                ),
                                const SizedBox(width: 8),
                                _CourseShortcut(
                                  onPressed: () => context.go('/path'),
                                ),
                              ],
                            ),
                          SizedBox(height: compact ? 12 : 18),
                          if (recentSession case final session?) ...[
                            _RecentSubjectSessionCard(
                              session: session,
                              onPressed: () => reopenRecentSession(session),
                            ),
                            SizedBox(height: compact ? 12 : 18),
                          ],
                          if (pinnedCollections.isNotEmpty) ...[
                            _PinnedCollectionsRow(
                              collections: pinnedCollections,
                              itemCountFor: (collection) => controller
                                  .itemsForSmartCollection(collection)
                                  .length,
                              onOpen: openPinnedCollection,
                            ),
                            SizedBox(height: compact ? 12 : 18),
                          ],
                          _PracticeCatalog(
                            items: items,
                            favoriteCount: favoriteCount,
                            recommendedUnitIndex: recommendedUnit.index,
                            plan: sessionPlan,
                            itemCount: sessionPreview.items.length,
                            onConfigure: () => context.push('/session-builder'),
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

class _PinnedCollectionsRow extends StatelessWidget {
  const _PinnedCollectionsRow({
    required this.collections,
    required this.itemCountFor,
    required this.onOpen,
  });

  final List<SmartCollectionDefinition> collections;
  final int Function(SmartCollectionDefinition) itemCountFor;
  final ValueChanged<SmartCollectionDefinition> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('learning-hub-pinned-collections'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '고정한 컬렉션',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: collections.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final collection = collections[index];
              final count = itemCountFor(collection);
              return ActionChip(
                key: Key('pinned-collection-${collection.id}'),
                avatar: const Icon(Icons.push_pin_rounded, size: 18),
                label: Text('${collection.name} · $count개'),
                onPressed: count == 0 ? null : () => onOpen(collection),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentSubjectSessionCard extends StatelessWidget {
  const _RecentSubjectSessionCard({
    required this.session,
    required this.onPressed,
  });

  final StudySessionSummary session;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final local = session.endedAt.toLocal();
    final accuracy = (session.accuracy * 100).round();
    return Material(
      key: const Key('recent-subject-session-card'),
      color: colors.secondaryContainer.withValues(alpha: 0.34),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: colors.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '최근 학습 · ${local.month}/${local.day} · ${session.itemIds.length}문제 · 정답률 $accuracy%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.mode.label} · ${session.historyFilter.label}'
                      '${session.recordProgress ? '' : ' · 진도 비기록'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                key: const Key('reopen-recent-subject-session'),
                tooltip: '최근 문제로 맞춤 설정 열기',
                onPressed: onPressed,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PracticeCategory { quiz, memorize, apply }

class _PracticeCatalog extends ConsumerStatefulWidget {
  const _PracticeCatalog({
    required this.items,
    required this.favoriteCount,
    required this.recommendedUnitIndex,
    required this.plan,
    required this.itemCount,
    required this.onConfigure,
  });

  final List<LearningItem> items;
  final int favoriteCount;
  final int recommendedUnitIndex;
  final StudySessionPlan plan;
  final int itemCount;
  final VoidCallback onConfigure;

  @override
  ConsumerState<_PracticeCatalog> createState() => _PracticeCatalogState();
}

class _PracticeCatalogState extends ConsumerState<_PracticeCatalog> {
  final _searchController = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  PracticeCatalogPreferences get _catalog =>
      ref.read(appControllerProvider).preferences.interaction.practiceCatalog;

  void _updateCatalog(PracticeCatalogPreferences catalog) {
    final state = ref.read(appControllerProvider);
    ref
        .read(appControllerProvider.notifier)
        .updateInteractionPreferences(
          state.preferences.interaction.copyWith(practiceCatalog: catalog),
        );
  }

  void _toggleFavorite(_Activity activity) {
    final catalog = _catalog;
    final favorites = {...catalog.favoriteActivityIds};
    if (!favorites.remove(activity.id)) favorites.add(activity.id);
    _updateCatalog(catalog.copyWith(favoriteActivityIds: favorites));
  }

  void _hideActivity(_Activity activity) {
    final catalog = _catalog;
    _updateCatalog(
      catalog.copyWith(
        favoriteActivityIds: {...catalog.favoriteActivityIds}
          ..remove(activity.id),
        hiddenActivityIds: {...catalog.hiddenActivityIds}..add(activity.id),
      ),
    );
  }

  void _restoreActivity(_Activity activity) {
    final catalog = _catalog;
    _updateCatalog(
      catalog.copyWith(
        hiddenActivityIds: {...catalog.hiddenActivityIds}..remove(activity.id),
      ),
    );
  }

  bool _matchesQuery(_Activity activity) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return '${activity.title} ${activity.description} ${activity.badge}'
        .toLowerCase()
        .contains(query);
  }

  List<_Activity> get _allActivities => [
    for (final category in _PracticeCategory.values)
      ..._activitiesFor(category),
  ];

  List<_PracticeRecommendation> _practiceRecommendations() {
    final state = ref.read(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final now = ref.read(appClockProvider)().toUtc();
    final itemIds = widget.items.map((item) => item.id).toSet();
    final dueCount = widget.items.where((item) {
      final dueAt = state.progress[item.id]?.nextReviewAt;
      return dueAt != null && !dueAt.toUtc().isAfter(now);
    }).length;
    final wrongCount = controller.recentWrongItems
        .where((item) => itemIds.contains(item.id))
        .length;
    final wordCount = widget.items
        .where((item) => item.kind == LearningItemKind.word)
        .length;
    final listeningCount = widget.items
        .where(
          (item) => item.capabilities.contains(ExerciseCapability.listening),
        )
        .length;
    final unstudiedWords = widget.items.where((item) {
      return item.kind == LearningItemKind.word &&
          (state.progress[item.id]?.attempts ?? 0) == 0;
    }).length;

    final values = <_PracticeRecommendation>[
      _PracticeRecommendation(
        activity: const _Activity(
          icon: Icons.event_repeat_rounded,
          title: '오늘 복습',
          description: '복습 기한이 온 표현부터 정리',
          route: '/study?mode=review',
          badge: '복습',
        ),
        count: dueCount,
        reason: dueCount > 0 ? '복습 기한이 된 표현 $dueCount개' : '예정된 복습은 모두 끝냈어요',
        priority: dueCount > 0 ? 500 + dueCount : 20,
      ),
      _PracticeRecommendation(
        activity: const _Activity(
          icon: Icons.history_toggle_off_rounded,
          title: '최근 오답',
          description: '최근 놓친 표현만 다시 확인',
          route: '/study?mode=weak&historyFilter=wrongOnly',
          badge: '오답',
        ),
        count: wrongCount,
        reason: wrongCount > 0
            ? '최근 세션에서 놓친 표현 $wrongCount개'
            : '해결하지 못한 최근 오답이 없어요',
        priority: wrongCount > 0 ? 400 + wrongCount : 10,
      ),
      _PracticeRecommendation(
        activity: const _Activity(
          icon: Icons.abc_rounded,
          title: '단어',
          description: '새 단어와 복습 단어를 짧게 학습',
          route: '/study?mode=words',
          badge: '단어',
        ),
        count: wordCount,
        reason: unstudiedWords > 0
            ? '아직 보지 않은 단어 $unstudiedWords개'
            : '등록된 단어 $wordCount개를 다시 다져요',
        priority: unstudiedWords > 0 ? 300 + unstudiedWords : 60,
      ),
      _PracticeRecommendation(
        activity: const _Activity(
          icon: Icons.headphones_rounded,
          title: '듣기',
          description: '소리를 듣고 표현을 확인',
          route: '/study?mode=listening',
          badge: '듣기',
        ),
        count: listeningCount,
        reason: '소리로 연습할 수 있는 표현 $listeningCount개',
        priority: listeningCount > 0 ? 120 + listeningCount : 0,
      ),
      _PracticeRecommendation(
        activity: const _Activity(
          icon: Icons.record_voice_over_rounded,
          title: '말하기',
          description: '듣고 따라 하며 발음 확인',
          route: '/pronunciation',
          badge: '말하기',
        ),
        count: listeningCount,
        reason: '따라 말할 수 있는 표현 $listeningCount개',
        priority: listeningCount > 0 ? 110 + listeningCount : 0,
      ),
    ];
    values.sort((left, right) {
      final priority = right.priority.compareTo(left.priority);
      if (priority != 0) return priority;
      return left.activity.title.compareTo(right.activity.title);
    });
    return values;
  }

  _ActivityAvailability _availabilityFor(_Activity activity) {
    final items = widget.items;
    if (activity.route.contains('match=true')) {
      final learning = <String>{};
      final meanings = <String>{};
      var pairs = 0;
      for (final item in items) {
        final term = item.text.trim().toLowerCase();
        final meaning = item.primaryTranslation.trim().toLowerCase();
        if (term.isEmpty || meaning.isEmpty) continue;
        if (!learning.add(term) || !meanings.add(meaning)) continue;
        pairs++;
      }
      return _ActivityAvailability(
        availableCount: pairs >= 2 ? pairs.clamp(2, 10) : 0,
        disabledReason: pairs >= 2 ? null : '서로 다른 표현과 뜻이 2쌍 이상 필요해요.',
      );
    }
    final uri = Uri.parse(activity.route);
    final modeName = uri.queryParameters['mode'];
    final progress = ref.read(appControllerProvider).progress;
    late final int availableCount;

    if (modeName != null) {
      final mode = StudyMode.values.firstWhere(
        (value) => value.name == modeName,
        orElse: () => StudyMode.mixed,
      );
      availableCount = items.where((item) {
        return switch (mode) {
          StudyMode.mixed || StudyMode.review || StudyMode.newItems => true,
          StudyMode.weak =>
            progress[item.id] != null &&
                progress[item.id]!.attempts > 0 &&
                progress[item.id]!.accuracy < 0.7,
          StudyMode.favorites =>
            widget.favoriteCount > 0 &&
                ref.read(appControllerProvider).preferences.isFavorite(item.id),
          StudyMode.words => item.kind == LearningItemKind.word,
          StudyMode.sentences => item.kind == LearningItemKind.sentence,
          StudyMode.meaning => item.capabilities.contains(
            ExerciseCapability.recognition,
          ),
          StudyMode.production => item.capabilities.contains(
            ExerciseCapability.production,
          ),
          StudyMode.cloze =>
            item.kind == LearningItemKind.sentence &&
                item.sentenceTokens.length >= 2 &&
                item.capabilities.contains(ExerciseCapability.cloze),
          StudyMode.sentenceOrder =>
            item.kind == LearningItemKind.sentence &&
                item.sentenceTokens.length >= 2 &&
                item.capabilities.contains(ExerciseCapability.sentenceOrder),
          StudyMode.listening || StudyMode.pronunciation =>
            item.capabilities.contains(ExerciseCapability.listening),
        };
      }).length;
    } else if (activity.route.startsWith('/cards')) {
      final kind = uri.queryParameters['kind'];
      availableCount = items.where((item) {
        return switch (kind) {
          'words' => item.kind == LearningItemKind.word,
          'sentences' => item.kind == LearningItemKind.sentence,
          _ => true,
        };
      }).length;
    } else if (activity.route == '/pronunciation') {
      availableCount = items
          .where(
            (item) => item.capabilities.contains(ExerciseCapability.listening),
          )
          .length;
    } else {
      availableCount = items.length;
    }

    if (availableCount > 0) {
      return _ActivityAvailability(availableCount: availableCount);
    }
    if (items.isEmpty) {
      return const _ActivityAvailability(
        availableCount: 0,
        disabledReason: '이 주제에 학습 자료가 없어요.',
      );
    }

    final reason = switch (modeName) {
      'meaning' => '뜻 고르기를 지원하는 자료가 없어요.',
      'production' => '직접 쓰기를 지원하는 자료가 없어요.',
      'cloze' => '빈칸과 토큰이 준비된 문장이 없어요.',
      'sentenceOrder' => '배열 토큰이 준비된 문장이 없어요.',
      'listening' => '듣기를 지원하는 자료가 없어요.',
      'favorites' => '별표로 저장한 표현이 없어요.',
      'weak' => '아직 취약 표현으로 분류된 자료가 없어요.',
      _ when activity.route == '/pronunciation' => '듣기를 지원하는 발음 자료가 없어요.',
      _ when activity.route.contains('kind=words') => '단어 카드로 볼 자료가 없어요.',
      _ when activity.route.contains('kind=sentences') => '문장 카드로 볼 자료가 없어요.',
      _ => '이 학습 방식에 사용할 자료가 없어요.',
    };
    return _ActivityAvailability(availableCount: 0, disabledReason: reason);
  }

  bool get _hasMissingMaterialCapability {
    const materialActivities = {
      '뜻 고르기',
      '직접 쓰기',
      '문장 빈칸',
      '문장 배열',
      '듣고 쓰기',
      '단어 카드',
      '문장 카드',
      '발음 따라하기',
    };
    return _PracticeCategory.values
        .expand(_activitiesFor)
        .where((activity) => materialActivities.contains(activity.title))
        .any((activity) => !_availabilityFor(activity).enabled);
  }

  Future<void> _openActivity(_Activity activity) async {
    if (!activity.route.startsWith('/study')) {
      await context.push(activity.route);
      return;
    }
    final uri = Uri.parse(activity.route);
    final modeName = uri.queryParameters['mode'];
    final mode = StudyMode.values.firstWhere(
      (value) => value.name == modeName,
      orElse: () => StudyMode.mixed,
    );
    final controller = ref.read(appControllerProvider.notifier);
    final now = ref.read(appClockProvider)();
    final catalogPlan = controller.activeSessionPlan.copyWith(
      planId: '',
      subjectId: controller.activeSubject.id,
      title: activity.title,
      mode: mode,
      deck: StudyDeckScope.course,
      unitIndex: null,
      difficulty: StudyDifficulty.all,
      queuePriority: StudyQueuePriority.dueFirst,
      historyFilter: StudyHistoryFilter.all,
      groupIds: {},
      tags: {},
      levels: {},
      selectedItemIds: {},
      includeWords: true,
      includeSentences: true,
      sentenceRatio: ref.read(appControllerProvider).preferences.sentenceRatio,
      itemLimit: StudyLimits.maxSessionItems,
      lengthMode: StudySessionLengthMode.itemCount,
      backlogRecovery: const BacklogRecoverySettings(),
      examSchedule: null,
      scheduledAt: null,
    );
    final preview = controller.queue(
      now,
      sessionPlan: catalogPlan,
      itemLimit: StudyLimits.maxSessionItems,
    );
    final newCount = preview
        .where(
          (item) =>
              !ref.read(appControllerProvider).progress.containsKey(item.id),
        )
        .length;
    final dueCount = preview.where((item) {
      final progress = ref.read(appControllerProvider).progress[item.id];
      final nextReviewAt = progress?.nextReviewAt;
      return nextReviewAt != null && !nextReviewAt.isAfter(now);
    }).length;
    if (!mounted) return;
    final launch = await showModalBottomSheet<_PracticeLaunchResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PracticeLaunchSheet(
        activity: activity,
        mode: mode,
        availableCount: preview.length,
        newCount: newCount,
        dueCount: dueCount,
        initialPreferences: _catalog.launchFor(activity.id),
      ),
    );
    if (launch == null || !mounted) return;
    final catalog = _catalog;
    _updateCatalog(
      catalog.copyWith(
        launchByActivityId: {...catalog.launchByActivityId}
          ..[activity.id] = launch.preferences,
      ),
    );
    controller.updateSessionPlan(
      catalogPlan.copyWith(
        queuePriority: launch.queuePriority,
        historyFilter: launch.historyFilter,
        itemLimit: launch.itemLimit,
        lengthMode: launch.lengthMode,
        timeBudgetMinutes: launch.timeBudgetMinutes,
        recordProgress: launch.preferences.recordProgress,
        answerDirectionOverride: launch.preferences.answerDirection,
        gradingStrictness: launch.preferences.gradingStrictness,
        choiceCount: launch.preferences.choiceCount,
        hintsEnabled: launch.preferences.hintsEnabled,
        autoAdvanceOverride: launch.preferences.autoAdvance,
        soundEffectsOverride: launch.preferences.soundEnabled,
        largeControls: launch.preferences.largeControls,
        scheduledAt: null,
      ),
    );
    final separator = activity.route.contains('?') ? '&' : '?';
    await context.push(
      '${activity.route}${separator}limit=${launch.itemLimit}'
      '&queuePriority=${launch.queuePriority.name}'
      '&historyFilter=${launch.historyFilter.name}'
      '&custom=true',
    );
  }

  List<_Activity> _activitiesFor(_PracticeCategory category) {
    return switch (category) {
      _PracticeCategory.quiz => const [
        _Activity(
          icon: Icons.shuffle_rounded,
          title: '혼합 퀴즈',
          description: '여러 문제를 짧게 섞어 풀기',
          route: '/study?mode=mixed',
          badge: '혼합',
        ),
        _Activity(
          icon: Icons.touch_app_rounded,
          title: '뜻 고르기',
          description: '표현에 맞는 뜻 선택',
          route: '/study?mode=meaning',
          badge: '선택',
        ),
        _Activity(
          icon: Icons.keyboard_rounded,
          title: '직접 쓰기',
          description: '뜻을 보고 표현 입력',
          route: '/study?mode=production',
          badge: '쓰기',
        ),
        _Activity(
          icon: Icons.space_bar_rounded,
          title: '문장 빈칸',
          description: '문맥에 맞는 표현 넣기',
          route: '/study?mode=cloze',
          badge: '문장',
        ),
        _Activity(
          icon: Icons.reorder_rounded,
          title: '문장 배열',
          description: '토큰을 순서대로 조립',
          route: '/study?mode=sentenceOrder',
          badge: '문장',
        ),
        _Activity(
          icon: Icons.headphones_rounded,
          title: '듣고 쓰기',
          description: '소리를 듣고 받아쓰기',
          route: '/study?mode=listening',
          badge: '듣기',
        ),
        _Activity(
          icon: Icons.grid_view_rounded,
          title: '매치 스프린트',
          description: '표현과 뜻을 빠르게 연결',
          route: '/study?mode=mixed&match=true',
          badge: '매치',
        ),
      ],
      _PracticeCategory.memorize => [
        const _Activity(
          icon: Icons.style_rounded,
          title: '단어 카드',
          description: '표현과 뜻을 차분히 익히기',
          route: '/cards?kind=words',
          badge: '암기',
        ),
        const _Activity(
          icon: Icons.menu_book_rounded,
          title: '문장 카드',
          description: '문장 의미와 구조 익히기',
          route: '/cards?kind=sentences',
          badge: '암기',
        ),
        _Activity(
          icon: Icons.auto_stories_rounded,
          title: '단원 노트',
          description: '문형과 사용 팁 확인',
          route: '/notes/${widget.recommendedUnitIndex}',
          badge: '노트',
        ),
        _Activity(
          icon: Icons.star_rounded,
          title: '저장한 표현',
          description: widget.favoriteCount == 0
              ? '자료실에서 별표로 모으기'
              : '${widget.favoriteCount}개만 다시 학습',
          route: '/study?mode=favorites',
          badge: '저장 ${widget.favoriteCount}',
        ),
      ],
      _PracticeCategory.apply => const [
        _Activity(
          icon: Icons.mic_rounded,
          title: '발음 따라하기',
          description: '말하고 일치도 확인',
          route: '/pronunciation',
          badge: '발음',
        ),
        _Activity(
          icon: Icons.forum_rounded,
          title: '실전 상황 미션',
          description: '듣기·뜻·말하기 연결',
          route: '/missions',
          badge: '실전',
        ),
        _Activity(
          icon: Icons.bolt_rounded,
          title: '취약 복습',
          description: '정확도 낮은 표현 집중',
          route: '/study?mode=weak',
          badge: '복습',
        ),
        _Activity(
          icon: Icons.route_rounded,
          title: '코스 여정',
          description: '단원별 학습 순서 보기',
          route: '/path',
          badge: '코스',
        ),
      ],
    };
  }

  String _categoryTitle(_PracticeCategory category) => switch (category) {
    _PracticeCategory.quiz => '퀴즈',
    _PracticeCategory.memorize => '암기',
    _PracticeCategory.apply => '실전',
  };

  String _categoryDescription(_PracticeCategory category) => switch (category) {
    _PracticeCategory.quiz => '짧게 풀고 바로 피드백을 받아요.',
    _PracticeCategory.memorize => '카드와 노트로 표현을 차분히 익혀요.',
    _PracticeCategory.apply => '발음·상황·취약 표현을 실제처럼 연습해요.',
  };

  IconData _categoryIcon(_PracticeCategory category) => switch (category) {
    _PracticeCategory.quiz => Icons.sports_esports_rounded,
    _PracticeCategory.memorize => Icons.style_rounded,
    _PracticeCategory.apply => Icons.mic_rounded,
  };

  List<_Activity> _visibleActivities(
    _PracticeCategory category,
    PracticeCatalogPreferences catalog,
  ) => _activitiesFor(category)
      .where((activity) => !catalog.hiddenActivityIds.contains(activity.id))
      .where(_matchesQuery)
      .toList(growable: false);

  Future<void> _openSurpriseGame() async {
    final catalog = _catalog;
    final available = _allActivities
        .where((activity) => !catalog.hiddenActivityIds.contains(activity.id))
        .where((activity) => _availabilityFor(activity).enabled)
        .toList(growable: false);
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지금 시작할 수 있는 게임이 없습니다. 자료를 먼저 추가해 주세요.')),
      );
      return;
    }
    final now = ref.read(appClockProvider)().microsecondsSinceEpoch;
    await _openActivity(available[now.abs() % available.length]);
  }

  Widget _activityCard(_Activity activity, double width) {
    final availability = _availabilityFor(activity);
    final catalog = _catalog;
    Widget card = SizedBox(
      width: width,
      child: _ActivityCard(
        activity: activity,
        disabledReason: availability.disabledReason,
        onPressed: availability.enabled ? () => _openActivity(activity) : null,
        favorite: catalog.favoriteActivityIds.contains(activity.id),
        onToggleFavorite: () => _toggleFavorite(activity),
        onHide: () => _hideActivity(activity),
      ),
    );
    if (activity.title == '혼합 퀴즈') {
      card = KeyedSubtree(key: const Key('quick-practice-quiz'), child: card);
    } else if (activity.title == '단어 카드') {
      card = KeyedSubtree(key: const Key('start-flashcards'), child: card);
      card = KeyedSubtree(key: const Key('quick-practice-cards'), child: card);
    } else if (activity.title == '발음 따라하기') {
      card = KeyedSubtree(
        key: const Key('quick-practice-pronunciation'),
        child: card,
      );
    }
    return card;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(
      appControllerProvider.select(
        (state) => state.preferences.interaction.practiceCatalog,
      ),
    );
    final favorites = _allActivities
        .where((activity) => catalog.favoriteActivityIds.contains(activity.id))
        .where((activity) => !catalog.hiddenActivityIds.contains(activity.id))
        .where(_matchesQuery)
        .toList(growable: false);
    final hidden = _allActivities
        .where((activity) => catalog.hiddenActivityIds.contains(activity.id))
        .toList(growable: false);
    final planTitle = widget.plan.title.trim();
    final planSummary = planTitle.isEmpty
        ? '맞춤 ${widget.itemCount}문제'
        : '$planTitle · ${widget.itemCount}문제';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('학습 방식', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 3),
                  Text(
                    '퀴즈·암기·실전 중 원하는 방식을 바로 선택하세요.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Tooltip(
              message: planSummary,
              child: OutlinedButton.icon(
                key: const Key('open-session-builder'),
                onPressed: widget.onConfigure,
                icon: const Icon(Icons.tune_rounded, size: 19),
                label: const Text('맞춤 설정'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _PersonalizedPracticeHub(
          recommendations: _practiceRecommendations(),
          availabilityFor: _availabilityFor,
          onPressed: _openActivity,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final search = TextField(
              key: const Key('practice-game-search'),
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                labelText: '게임 검색',
                hintText: '쓰기, 듣기, 문장, 매치…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '검색 지우기',
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            );
            final surprise = FilledButton.tonalIcon(
              key: const Key('practice-surprise-game'),
              onPressed: _openSurpriseGame,
              icon: const Icon(Icons.casino_outlined),
              label: const Text('깜짝 게임'),
            );
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [search, const SizedBox(height: 8), surprise],
              );
            }
            return Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 10),
                surprise,
              ],
            );
          },
        ),
        if (favorites.isNotEmpty) ...[
          const SizedBox(height: 18),
          const _PracticeSectionHeader(
            icon: Icons.star_rounded,
            title: '즐겨찾는 게임',
            description: '자주 쓰는 게임을 위에 고정했습니다.',
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 620
                  ? (constraints.maxWidth - 20) / 3
                  : constraints.maxWidth >= 350
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final activity in favorites)
                    _activityCard(activity, width),
                ],
              );
            },
          ),
        ],
        const SizedBox(height: 18),
        if (_hasMissingMaterialCapability) ...[
          _MissingMaterialNotice(
            isEmpty: widget.items.isEmpty,
            onAdd: () => context.go('/library/new'),
          ),
          const SizedBox(height: 18),
        ],
        for (final category in _PracticeCategory.values) ...[
          if (_visibleActivities(category, catalog).isNotEmpty) ...[
            if (category != _PracticeCategory.quiz) const SizedBox(height: 20),
            _PracticeSectionHeader(
              key: Key('practice-category-${_categoryTitle(category)}'),
              icon: _categoryIcon(category),
              title: _categoryTitle(category),
              description: _categoryDescription(category),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 4
                    : defaultTargetPlatform == TargetPlatform.windows &&
                          constraints.maxWidth >= 620
                    ? 3
                    : constraints.maxWidth >= 350
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final activity in _visibleActivities(
                      category,
                      catalog,
                    ))
                      _activityCard(activity, width),
                  ],
                );
              },
            ),
          ],
        ],
        if (_query.trim().isNotEmpty &&
            _PracticeCategory.values.every(
              (category) => _visibleActivities(category, catalog).isEmpty,
            )) ...[
          const SizedBox(height: 18),
          const Center(child: Text('검색 조건에 맞는 게임이 없습니다.')),
        ],
        if (hidden.isNotEmpty) ...[
          const SizedBox(height: 18),
          ExpansionTile(
            key: const Key('hidden-practice-games'),
            tilePadding: EdgeInsets.zero,
            title: Text('숨긴 게임 ${hidden.length}개'),
            subtitle: const Text('원할 때 언제든 다시 표시할 수 있습니다.'),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final activity in hidden)
                      ActionChip(
                        avatar: const Icon(Icons.visibility_outlined, size: 18),
                        label: Text('${activity.title} 복원'),
                        onPressed: () => _restoreActivity(activity),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PracticeRecommendation {
  const _PracticeRecommendation({
    required this.activity,
    required this.count,
    required this.reason,
    required this.priority,
  });

  final _Activity activity;
  final int count;
  final String reason;
  final int priority;
}

class _PersonalizedPracticeHub extends StatelessWidget {
  const _PersonalizedPracticeHub({
    required this.recommendations,
    required this.availabilityFor,
    required this.onPressed,
  });

  final List<_PracticeRecommendation> recommendations;
  final _ActivityAvailability Function(_Activity) availabilityFor;
  final Future<void> Function(_Activity) onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    _PracticeRecommendation? primary;
    for (final recommendation in recommendations) {
      if (availabilityFor(recommendation.activity).enabled) {
        primary = recommendation;
        break;
      }
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
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
                    '오늘의 Practice Hub',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (primary case final recommendation?)
                  FilledButton.tonalIcon(
                    key: const Key('start-recommended-practice'),
                    onPressed: () => onPressed(recommendation.activity),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('알아서 추천'),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '복습 기한·최근 오답·새 자료를 기준으로 순서를 정했어요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 118,
              child: ListView.separated(
                key: const Key('personalized-practice-hub'),
                scrollDirection: Axis.horizontal,
                itemCount: recommendations.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final recommendation = recommendations[index];
                  final availability = availabilityFor(recommendation.activity);
                  return SizedBox(
                    width: 194,
                    child: Material(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: availability.enabled
                            ? () => onPressed(recommendation.activity)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(recommendation.activity.icon, size: 20),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      recommendation.activity.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${recommendation.count}',
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  availability.enabled
                                      ? recommendation.reason
                                      : availability.disabledReason ??
                                            recommendation.reason,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              Text(
                                index == 0 && availability.enabled
                                    ? '지금 먼저 하기'
                                    : availability.enabled
                                    ? '바로 시작'
                                    : '자료 필요',
                                style: TextStyle(
                                  color: availability.enabled
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _PracticeSectionHeader extends StatelessWidget {
  const _PracticeSectionHeader({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 20, color: colors.onSecondaryContainer),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.disabledReason,
    required this.onPressed,
    required this.favorite,
    required this.onToggleFavorite,
    required this.onHide,
  });

  final _Activity activity;
  final String? disabledReason;
  final VoidCallback? onPressed;
  final bool favorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 240;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final scaleDelta = (textScale - 1).clamp(0.0, 2.0).toDouble();
        final cardHeight = compact
            ? (enabled ? 108.0 : 128.0) + (scaleDelta * 46)
            : 72.0 + (scaleDelta * 32);
        final icon = Container(
          width: compact ? 36 : 44,
          height: compact ? 36 : 44,
          decoration: BoxDecoration(
            color: enabled
                ? colors.secondaryContainer
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            activity.icon,
            size: compact ? 20 : 24,
            color: enabled
                ? colors.onSecondaryContainer
                : colors.onSurfaceVariant,
          ),
        );
        final copy = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activity.title,
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            if (!enabled && disabledReason != null) ...[
              const SizedBox(height: 2),
              Text(
                disabledReason!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );
        final menu = PopupMenuButton<String>(
          key: Key('practice-menu-${activity.id}'),
          tooltip: '${activity.title} 관리',
          onSelected: (value) {
            if (value == 'favorite') onToggleFavorite();
            if (value == 'hide') onHide();
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'favorite',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded,
                ),
                title: Text(favorite ? '즐겨찾기 해제' : '즐겨찾기에 고정'),
              ),
            ),
            const PopupMenuItem(
              value: 'hide',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.visibility_off_outlined),
                title: Text('이 게임 숨기기'),
              ),
            ),
          ],
          icon: Icon(
            favorite ? Icons.star_rounded : Icons.more_horiz_rounded,
            color: favorite ? colors.primary : colors.onSurfaceVariant,
          ),
        );
        return Semantics(
          button: true,
          enabled: enabled,
          label: enabled
              ? '${activity.title}. ${activity.description}'
              : '${activity.title}. 사용 불가. $disabledReason',
          child: Tooltip(
            message: disabledReason ?? activity.description,
            child: Material(
              key: Key('practice-activity-${activity.title}'),
              color: enabled ? colors.surface : colors.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: colors.outlineVariant),
              ),
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: cardHeight,
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  icon,
                                  const Spacer(),
                                  _MiniBadge(
                                    label: enabled ? activity.badge : '사용 불가',
                                    muted: !enabled,
                                  ),
                                  menu,
                                ],
                              ),
                              const SizedBox(height: 7),
                              copy,
                            ],
                          )
                        : Row(
                            children: [
                              icon,
                              const SizedBox(width: 11),
                              Expanded(child: copy),
                              _MiniBadge(
                                label: enabled ? activity.badge : '사용 불가',
                                muted: !enabled,
                              ),
                              menu,
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PracticeLaunchResult {
  const _PracticeLaunchResult({
    required this.itemLimit,
    required this.queuePriority,
    required this.historyFilter,
    required this.lengthMode,
    required this.timeBudgetMinutes,
    required this.preferences,
  });

  final int itemLimit;
  final StudyQueuePriority queuePriority;
  final StudyHistoryFilter historyFilter;
  final StudySessionLengthMode lengthMode;
  final int timeBudgetMinutes;
  final PracticeLaunchPreferences preferences;
}

class _PracticeLaunchSheet extends StatefulWidget {
  const _PracticeLaunchSheet({
    required this.activity,
    required this.mode,
    required this.availableCount,
    required this.newCount,
    required this.dueCount,
    required this.initialPreferences,
  });

  final _Activity activity;
  final StudyMode mode;
  final int availableCount;
  final int newCount;
  final int dueCount;
  final PracticeLaunchPreferences initialPreferences;

  @override
  State<_PracticeLaunchSheet> createState() => _PracticeLaunchSheetState();
}

class _PracticeLaunchSheetState extends State<_PracticeLaunchSheet> {
  late int _selectedCount;
  late final TextEditingController _countController;
  var _queuePriority = StudyQueuePriority.dueFirst;
  var _historyFilter = StudyHistoryFilter.all;
  late PracticeLaunchPreferences _preferences;

  @override
  void initState() {
    super.initState();
    _preferences = widget.initialPreferences;
    _selectedCount = _initialItemCount();
    _queuePriority = switch (_preferences.queueOrder) {
      PracticeQueueOrder.dueFirst => StudyQueuePriority.dueFirst,
      PracticeQueueOrder.newFirst => StudyQueuePriority.newFirst,
    };
    _historyFilter = switch (_preferences.historyScope) {
      PracticeHistoryScope.all => StudyHistoryFilter.all,
      PracticeHistoryScope.excludeCorrect => StudyHistoryFilter.excludeCorrect,
      PracticeHistoryScope.wrongOnly => StudyHistoryFilter.wrongOnly,
    };
    _countController = TextEditingController(text: '$_selectedCount');
  }

  int _initialItemCount() {
    if (widget.availableCount <= 0) return 0;
    final requested = switch (_preferences.length) {
      PracticeSessionLength.fiveItems ||
      PracticeSessionLength.tenItems ||
      PracticeSessionLength.twentyItems => _preferences.itemCount,
      PracticeSessionLength.allItems => widget.availableCount,
      PracticeSessionLength.threeMinutes => 7,
      PracticeSessionLength.fiveMinutes => 12,
      PracticeSessionLength.tenMinutes => 24,
    };
    return requested.clamp(1, widget.availableCount);
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  void _setCount(int value) {
    final next = value.clamp(
      StudyLimits.minSessionItems,
      widget.availableCount.clamp(
        StudyLimits.minSessionItems,
        StudyLimits.maxSessionItems,
      ),
    );
    setState(() {
      _selectedCount = next;
      _preferences = _preferences.copyWith(
        itemCount: next,
        length: _itemLengthForCount(next),
      );
    });
    _countController.value = TextEditingValue(
      text: '$next',
      selection: TextSelection.collapsed(offset: '$next'.length),
    );
  }

  void _commitCount() {
    final parsed = int.tryParse(_countController.text) ?? _selectedCount;
    if (parsed == _selectedCount) return;
    _setCount(parsed);
  }

  PracticeSessionLength _itemLengthForCount(int count) => switch (count) {
    5 => PracticeSessionLength.fiveItems,
    10 => PracticeSessionLength.tenItems,
    20 => PracticeSessionLength.twentyItems,
    _ when count == widget.availableCount => PracticeSessionLength.allItems,
    _ => PracticeSessionLength.tenItems,
  };

  void _setLength(PracticeSessionLength length) {
    final count = switch (length) {
      PracticeSessionLength.fiveItems => 5,
      PracticeSessionLength.tenItems => 10,
      PracticeSessionLength.twentyItems => 20,
      PracticeSessionLength.allItems => widget.availableCount,
      PracticeSessionLength.threeMinutes => 7,
      PracticeSessionLength.fiveMinutes => 12,
      PracticeSessionLength.tenMinutes => 24,
    };
    setState(() => _preferences = _preferences.copyWith(length: length));
    _setCount(count);
    setState(() => _preferences = _preferences.copyWith(length: length));
  }

  int get _timeBudgetMinutes => switch (_preferences.length) {
    PracticeSessionLength.threeMinutes => 3,
    PracticeSessionLength.fiveMinutes => 5,
    PracticeSessionLength.tenMinutes => 10,
    _ => 5,
  };

  bool get _usesTimeBudget => switch (_preferences.length) {
    PracticeSessionLength.threeMinutes ||
    PracticeSessionLength.fiveMinutes ||
    PracticeSessionLength.tenMinutes => true,
    _ => false,
  };

  void _applyDifficulty(PracticeDifficultyPreset difficulty) {
    setState(() {
      _preferences = switch (difficulty) {
        PracticeDifficultyPreset.relaxed => _preferences.copyWith(
          difficulty: difficulty,
          gradingStrictness: StudyGradingStrictness.lenient,
          choiceCount: 2,
          hintsEnabled: true,
          autoAdvance: false,
          largeControls: true,
        ),
        PracticeDifficultyPreset.balanced => _preferences.copyWith(
          difficulty: difficulty,
          gradingStrictness: StudyGradingStrictness.balanced,
          choiceCount: 4,
          hintsEnabled: true,
          autoAdvance: false,
          largeControls: false,
        ),
        PracticeDifficultyPreset.challenge => _preferences.copyWith(
          difficulty: difficulty,
          gradingStrictness: StudyGradingStrictness.strict,
          choiceCount: 6,
          hintsEnabled: false,
          autoAdvance: true,
          largeControls: false,
        ),
      };
    });
  }

  List<int> get _countOptions {
    if (widget.availableCount <= 0) return const [];
    final options = <int>{
      for (final count in const [5, 10, 20])
        if (count <= widget.availableCount) count,
      widget.availableCount < 5 ? widget.availableCount : 5,
      if (widget.availableCount > 5 && widget.availableCount < 10)
        widget.availableCount,
      if (widget.availableCount > 10 && widget.availableCount < 20)
        widget.availableCount,
    }.toList()..sort();
    return options;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final estimatedMinutes = ((_selectedCount * 25) + 59) ~/ 60;
    final studiedCount = widget.availableCount - widget.newCount;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.activity.icon,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.activity.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.mode.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (widget.availableCount == 0) ...[
                  Container(
                    key: const Key('practice-launch-empty'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${widget.activity.title}에 사용할 수 있는 자료가 없습니다. '
                      '자료실에서 별표·문장 토큰·듣기 자료를 확인해 주세요.',
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () {
                      final router = GoRouter.of(context);
                      Navigator.pop(context);
                      router.go('/library');
                    },
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('자료실에서 준비하기'),
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _LaunchInfoChip(
                        icon: Icons.inventory_2_outlined,
                        label: '사용 가능 ${widget.availableCount}개',
                      ),
                      _LaunchInfoChip(
                        icon: Icons.notifications_active_outlined,
                        label: '복습 예정 ${widget.dueCount}개',
                      ),
                      _LaunchInfoChip(
                        icon: Icons.fiber_new_rounded,
                        label: '새 자료 ${widget.newCount}개',
                      ),
                      _LaunchInfoChip(
                        icon: Icons.check_circle_outline_rounded,
                        label: '학습 이력 $studiedCount개',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '이번에 풀 문제 수',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '문제 수 또는 3·5·10분 시간 예산을 선택하세요.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    key: const Key('practice-count-options'),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final count in _countOptions)
                        ChoiceChip(
                          key: Key('practice-count-$count'),
                          selected: _selectedCount == count,
                          label: Text('$count문제'),
                          onSelected: (_) => _setCount(count),
                        ),
                      ChoiceChip(
                        key: const Key('practice-count-all'),
                        selected:
                            _preferences.length ==
                            PracticeSessionLength.allItems,
                        label: Text('전체 ${widget.availableCount}개'),
                        onSelected: (_) =>
                            _setLength(PracticeSessionLength.allItems),
                      ),
                      for (final option in const [
                        PracticeSessionLength.threeMinutes,
                        PracticeSessionLength.fiveMinutes,
                        PracticeSessionLength.tenMinutes,
                      ])
                        ChoiceChip(
                          key: Key('practice-time-${option.name}'),
                          selected: _preferences.length == option,
                          avatar: const Icon(Icons.timer_outlined, size: 17),
                          label: Text(switch (option) {
                            PracticeSessionLength.threeMinutes => '3분',
                            PracticeSessionLength.fiveMinutes => '5분',
                            _ => '10분',
                          }),
                          onSelected: (_) => _setLength(option),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      IconButton.outlined(
                        key: const Key('practice-count-decrease'),
                        tooltip: '문제 수 줄이기',
                        onPressed: _selectedCount <= StudyLimits.minSessionItems
                            ? null
                            : () => _setCount(_selectedCount - 1),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 92,
                        child: TextField(
                          key: const Key('practice-count-input'),
                          controller: _countController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            helperText: '1~100',
                          ),
                          onChanged: (value) {
                            final parsed = int.tryParse(value);
                            if (parsed != null &&
                                parsed >= StudyLimits.minSessionItems &&
                                parsed <= StudyLimits.maxSessionItems) {
                              final next = parsed.clamp(
                                StudyLimits.minSessionItems,
                                widget.availableCount.clamp(
                                  StudyLimits.minSessionItems,
                                  StudyLimits.maxSessionItems,
                                ),
                              );
                              setState(() {
                                _selectedCount = next;
                                _preferences = _preferences.copyWith(
                                  itemCount: next,
                                  length: _itemLengthForCount(next),
                                );
                              });
                            }
                          },
                          onEditingComplete: _commitCount,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        key: const Key('practice-count-increase'),
                        tooltip: '문제 수 늘리기',
                        onPressed: _selectedCount >= StudyLimits.maxSessionItems
                            ? null
                            : () => _setCount(_selectedCount + 1),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '난이도 프리셋',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final difficulty in PracticeDifficultyPreset.values)
                        ChoiceChip(
                          key: Key('practice-difficulty-${difficulty.name}'),
                          selected: _preferences.difficulty == difficulty,
                          label: Text(switch (difficulty) {
                            PracticeDifficultyPreset.relaxed => '편안함',
                            PracticeDifficultyPreset.balanced => '기본',
                            PracticeDifficultyPreset.challenge => '도전',
                          }),
                          onSelected: (_) => _applyDifficulty(difficulty),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('학습 기록', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final filter in StudyHistoryFilter.values)
                        ChoiceChip(
                          key: Key('practice-history-${filter.name}'),
                          label: Text(filter.label),
                          selected: _historyFilter == filter,
                          onSelected: (_) => setState(() {
                            _historyFilter = filter;
                            _preferences = _preferences.copyWith(
                              historyScope: switch (filter) {
                                StudyHistoryFilter.all =>
                                  PracticeHistoryScope.all,
                                StudyHistoryFilter.excludeCorrect =>
                                  PracticeHistoryScope.excludeCorrect,
                                StudyHistoryFilter.wrongOnly =>
                                  PracticeHistoryScope.wrongOnly,
                              },
                            );
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('출제 순서', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final priority in StudyQueuePriority.values)
                        ChoiceChip(
                          key: Key('practice-priority-${priority.name}'),
                          label: Text(priority.label),
                          selected: _queuePriority == priority,
                          onSelected: (_) => setState(() {
                            _queuePriority = priority;
                            _preferences = _preferences.copyWith(
                              queueOrder:
                                  priority == StudyQueuePriority.dueFirst
                                  ? PracticeQueueOrder.dueFirst
                                  : PracticeQueueOrder.newFirst,
                            );
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    key: const Key('practice-record-progress'),
                    contentPadding: EdgeInsets.zero,
                    value: _preferences.recordProgress,
                    title: const Text('XP·복습 진도 기록'),
                    subtitle: Text(
                      _preferences.recordProgress
                          ? '학습 결과를 로컬 진도에 반영합니다.'
                          : '자유 연습: XP와 복습 일정을 바꾸지 않습니다.',
                    ),
                    onChanged: (value) => setState(
                      () => _preferences = _preferences.copyWith(
                        recordProgress: value,
                      ),
                    ),
                  ),
                  ExpansionTile(
                    key: const Key('practice-quick-rules'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: const Text('빠른 게임 규칙'),
                    subtitle: Text(
                      '${_preferences.choiceCount}지선다 · '
                      '${_preferences.gradingStrictness.koreanLabel} 채점 · '
                      '${_preferences.hintsEnabled ? '힌트 켬' : '힌트 끔'}',
                    ),
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('출제 방향'),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final direction in StudyAnswerDirection.values)
                            ChoiceChip(
                              key: Key('practice-direction-${direction.name}'),
                              selected:
                                  _preferences.answerDirection == direction,
                              label: Text(switch (direction) {
                                StudyAnswerDirection.learningToMeaning =>
                                  '학습어 → 뜻',
                                StudyAnswerDirection.meaningToLearning =>
                                  '뜻 → 학습어',
                                StudyAnswerDirection.mixed => '혼합',
                              }),
                              onSelected: (_) => setState(
                                () => _preferences = _preferences.copyWith(
                                  answerDirection: direction,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('채점'),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (final strictness
                              in StudyGradingStrictness.values)
                            ChoiceChip(
                              key: Key('practice-grading-${strictness.name}'),
                              selected:
                                  _preferences.gradingStrictness == strictness,
                              label: Text(strictness.koreanLabel),
                              onSelected: (_) => setState(
                                () => _preferences = _preferences.copyWith(
                                  gradingStrictness: strictness,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('객관식 선택지'),
                      ),
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 7,
                        children: [
                          for (final count in const [2, 4, 6])
                            ChoiceChip(
                              key: Key('practice-choice-count-$count'),
                              selected: _preferences.choiceCount == count,
                              label: Text('$count개'),
                              onSelected: (_) => setState(
                                () => _preferences = _preferences.copyWith(
                                  choiceCount: count,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SwitchListTile.adaptive(
                        key: const Key('practice-time-budget-toggle'),
                        contentPadding: EdgeInsets.zero,
                        value: _usesTimeBudget,
                        title: const Text('시간 예산 모드'),
                        subtitle: const Text(
                          '문제 수 대신 3·5·10분 프리셋으로 학습량을 맞춥니다.',
                        ),
                        onChanged: (value) {
                          if (value) {
                            _setLength(PracticeSessionLength.fiveMinutes);
                          } else {
                            _setCount(_selectedCount);
                          }
                        },
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _preferences.hintsEnabled,
                        title: const Text('힌트 허용'),
                        onChanged: (value) => setState(
                          () => _preferences = _preferences.copyWith(
                            hintsEnabled: value,
                          ),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _preferences.autoAdvance,
                        title: const Text('정답 뒤 자동 진행'),
                        onChanged: (value) => setState(
                          () => _preferences = _preferences.copyWith(
                            autoAdvance: value,
                          ),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _preferences.soundEnabled,
                        title: const Text('게임 효과음'),
                        onChanged: (value) => setState(
                          () => _preferences = _preferences.copyWith(
                            soundEnabled: value,
                          ),
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _preferences.largeControls,
                        title: const Text('큰 조작 버튼'),
                        onChanged: (value) => setState(
                          () => _preferences = _preferences.copyWith(
                            largeControls: value,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    liveRegion: true,
                    label: _usesTimeBudget
                        ? '$_timeBudgetMinutes분 자유 학습, 즉시 피드백'
                        : '$_selectedCount문제, 예상 $estimatedMinutes분, 즉시 피드백',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 19),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_usesTimeBudget ? '약 $_timeBudgetMinutes분' : '약 $estimatedMinutes분'} · '
                              '매 문제 즉시 피드백 · '
                              '${_preferences.recordProgress ? '오답은 세션 안에서 다시 출제' : '진도 비기록 자유 연습'}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    key: const Key('start-practice-session'),
                    onPressed: () {
                      _commitCount();
                      Navigator.pop(
                        context,
                        _PracticeLaunchResult(
                          itemLimit: _selectedCount,
                          queuePriority: _queuePriority,
                          historyFilter: _historyFilter,
                          lengthMode: _usesTimeBudget
                              ? StudySessionLengthMode.timeBudget
                              : StudySessionLengthMode.itemCount,
                          timeBudgetMinutes: _timeBudgetMinutes,
                          preferences: _preferences.copyWith(
                            itemCount: _selectedCount,
                            historyScope: switch (_historyFilter) {
                              StudyHistoryFilter.all =>
                                PracticeHistoryScope.all,
                              StudyHistoryFilter.excludeCorrect =>
                                PracticeHistoryScope.excludeCorrect,
                              StudyHistoryFilter.wrongOnly =>
                                PracticeHistoryScope.wrongOnly,
                            },
                            queueOrder:
                                _queuePriority == StudyQueuePriority.dueFirst
                                ? PracticeQueueOrder.dueFirst
                                : PracticeQueueOrder.newFirst,
                          ),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      _usesTimeBudget
                          ? '$_timeBudgetMinutes분 시작'
                          : '$_selectedCount문제 시작',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LaunchInfoChip extends StatelessWidget {
  const _LaunchInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 5), Text(label)],
      ),
    );
  }
}

class _CourseShortcut extends StatelessWidget {
  const _CourseShortcut({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const Key('open-course-path'),
      onPressed: onPressed,
      icon: const Icon(Icons.route_rounded, size: 18),
      label: const Text('코스'),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 9),
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
  const _MiniBadge({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: muted ? colors.surfaceContainerHighest : colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: muted ? colors.onSurfaceVariant : colors.onPrimaryContainer,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MissingMaterialNotice extends StatelessWidget {
  const _MissingMaterialNotice({required this.isEmpty, required this.onAdd});

  final bool isEmpty;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('learning-hub-missing-material-notice'),
      color: colors.primaryContainer.withValues(alpha: 0.38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.primary.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEmpty ? '학습을 시작할 자료가 없어요' : '일부 학습 방식에 필요한 자료가 부족해요',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  isEmpty
                      ? '첫 단어나 문장을 추가하면 사용할 수 있는 학습 방식이 바로 열려요.'
                      : '비활성 카드에서 필요한 자료 유형을 확인한 뒤 알맞은 표현을 추가해 주세요.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
            final button = FilledButton.icon(
              key: const Key('learning-hub-add-content'),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: Text(isEmpty ? '첫 자료 추가' : '지원 자료 추가'),
            );
            if (constraints.maxWidth < 560) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 12), button],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 14),
                button,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActivityAvailability {
  const _ActivityAvailability({
    required this.availableCount,
    this.disabledReason,
  });

  final int availableCount;
  final String? disabledReason;

  bool get enabled => availableCount > 0;
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

  String get id => route;
}
