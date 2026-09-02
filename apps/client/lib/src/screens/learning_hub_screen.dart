import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
import '../domain/study_runtime_modes.dart';
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
          const SnackBar(content: Text('최근 학습 자료가 바뀌어 기본 설정으로 열었어요.')),
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
          final padding = compact ? 12.0 : 24.0;
          return CustomScrollView(
            key: const Key('learning-hub-scroll'),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  compact ? 12 : 18,
                  padding,
                  compact ? 20 : 30,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (compact) ...[
                            Row(
                              key: const Key('compact-learning-header'),
                              children: [
                                Expanded(
                                  child: Text(
                                    activeSubject.isLanguage
                                        ? '${activeSubject.name} 학습'
                                        : '${activeSubject.symbol} ${activeSubject.name} 학습',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                ),
                                _CourseShortcut(
                                  onPressed: () => context.go('/path'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _CountBadge(
                                compact: true,
                                label: activeSubject.isLanguage
                                    ? '단어 $wordCount · 문장 $sentenceCount'
                                    : '개념 $wordCount · 사실 $sentenceCount',
                              ),
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
                                        '익힌 뒤 문제를 풀고, 소리 내어 말해 보세요.',
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
                          SizedBox(height: compact ? 9 : 15),
                          if (recentSession case final session?) ...[
                            _RecentSubjectSessionCard(
                              session: session,
                              onPressed: () => reopenRecentSession(session),
                            ),
                            SizedBox(height: compact ? 9 : 15),
                          ],
                          if (pinnedCollections.isNotEmpty) ...[
                            _PinnedCollectionsRow(
                              collections: pinnedCollections,
                              itemCountFor: (collection) => controller
                                  .itemsForSmartCollection(collection)
                                  .length,
                              onOpen: openPinnedCollection,
                            ),
                            SizedBox(height: compact ? 9 : 15),
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
    return Semantics(
      key: const Key('learning-hub-pinned-collections'),
      container: true,
      label: '고정한 컬렉션 ${collections.length}개',
      child: SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: collections.length,
          separatorBuilder: (_, _) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            final collection = collections[index];
            final count = itemCountFor(collection);
            return ActionChip(
              key: Key('pinned-collection-${collection.id}'),
              avatar: const Icon(Icons.push_pin_rounded, size: 17),
              label: Text('${collection.name} · $count'),
              onPressed: count == 0 ? null : () => onOpen(collection),
            );
          },
        ),
      ),
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
          padding: const EdgeInsets.fromLTRB(11, 7, 6, 7),
          child: Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 20,
                color: colors.onSecondaryContainer,
              ),
              const SizedBox(width: 8),
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
              TextButton.icon(
                key: const Key('reopen-recent-subject-session'),
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('다시 학습'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PracticeCategory { quiz, memorize, apply }

enum _PracticeHubTab { recommended, games, missions }

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
  final _playlistSelection = <String>[];
  var _query = '';
  var _selectedTab = _PracticeHubTab.recommended;
  String? _handledPlaylistToken;
  String? _handledLaunchToken;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = GoRouterState.of(context).uri;
    final launchId = uri.queryParameters['launch']?.trim();
    if (launchId != null && launchId.isNotEmpty) {
      final launchToken = '$launchId|${uri.queryParameters['request'] ?? ''}';
      if (_handledLaunchToken != launchToken) {
        _handledLaunchToken = launchToken;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final activity = _allActivities.cast<_Activity?>().firstWhere(
            (candidate) => candidate?.id == launchId,
            orElse: () => null,
          );
          final hidden = _catalog.hiddenActivityIds.contains(launchId);
          final availability = activity == null
              ? null
              : _availabilityFor(activity);
          if (activity == null || hidden || !(availability?.enabled ?? false)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  hidden
                      ? '숨긴 학습 방식입니다. 전체 게임에서 다시 표시한 뒤 시작해 주세요.'
                      : availability?.disabledReason ??
                            '이 학습 방식을 지금 시작할 수 없어요.',
                ),
              ),
            );
            context.go('/learn');
            return;
          }
          unawaited(_openActivity(activity, useSavedRules: true));
        });
      }
    }
    final rawIds = uri.queryParameters['playlist'];
    final index = int.tryParse(uri.queryParameters['playlistIndex'] ?? '');
    if (rawIds == null || index == null) return;
    final token = '$rawIds|$index';
    if (_handledPlaylistToken == token) return;
    _handledPlaylistToken = token;
    final ids = rawIds
        .split(',')
        .where(isPlaylistCompatiblePracticeActivity)
        .take(5)
        .toList(growable: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index < 0 || index >= ids.length) {
        if (mounted) context.go('/learn');
        return;
      }
      final activity = _allActivities.cast<_Activity?>().firstWhere(
        (candidate) => candidate?.id == ids[index],
        orElse: () => null,
      );
      if (activity == null || !_availabilityFor(activity).enabled) {
        context.go('/learn');
        return;
      }
      unawaited(
        _openActivity(
          activity,
          useSavedRules: true,
          playlistIds: ids,
          playlistIndex: index,
        ),
      );
    });
  }

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

  void _moveFavorite(_Activity activity, int offset) {
    final catalog = _catalog;
    final ordered = _orderedFavorites(catalog);
    final current = ordered.indexWhere((value) => value.id == activity.id);
    if (current < 0) return;
    final target = (current + offset).clamp(0, ordered.length - 1);
    if (target == current) return;
    final moved = [...ordered];
    final value = moved.removeAt(current);
    moved.insert(target, value);
    _updateCatalog(
      catalog.copyWith(
        favoriteActivityOrder: moved.map((value) => value.id).toList(),
      ),
    );
  }

  void _toggleQuickLaunch(_Activity activity) {
    final catalog = _catalog;
    final quickLaunchIds = {...catalog.quickLaunchActivityIds};
    if (!quickLaunchIds.remove(activity.id)) quickLaunchIds.add(activity.id);
    _updateCatalog(catalog.copyWith(quickLaunchActivityIds: quickLaunchIds));
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

  void _togglePlaylistSelection(_Activity activity) {
    if (!isPlaylistCompatiblePracticeActivity(activity.id)) return;
    setState(() {
      if (_playlistSelection.remove(activity.id)) return;
      if (_playlistSelection.length == 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('플레이리스트에는 게임을 최대 5개까지 담을 수 있어요.')),
        );
        return;
      }
      _playlistSelection.add(activity.id);
    });
  }

  void _savePlaylist() {
    if (_playlistSelection.length < 2 || _playlistSelection.length > 5) return;
    final catalog = _catalog;
    final nextNumber = catalog.playlists.length + 1;
    final now = ref.read(appClockProvider)().toUtc();
    final playlist = PracticePlaylist(
      id: 'playlist-${now.microsecondsSinceEpoch}',
      name: '내 게임 묶음 $nextNumber',
      activityIds: List.unmodifiable(_playlistSelection),
    );
    _updateCatalog(catalog.savePlaylist(playlist));
    setState(_playlistSelection.clear);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${playlist.name}을 저장했어요.')));
  }

  void _removePlaylist(PracticePlaylist playlist) {
    _updateCatalog(_catalog.removePlaylist(playlist.id));
  }

  Future<void> _startPlaylist(PracticePlaylist playlist) async {
    if (playlist.activityIds.length < 2) return;
    final byId = {for (final activity in _allActivities) activity.id: activity};
    final first = byId[playlist.activityIds.first];
    if (first == null || !_availabilityFor(first).enabled) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('첫 게임을 시작할 자료가 부족해요.')));
      return;
    }
    await _openActivity(
      first,
      useSavedRules: true,
      playlistIds: playlist.activityIds,
      playlistIndex: 0,
    );
  }

  void _snoozeRecommendation(_Activity activity, Duration duration) {
    final until = ref.read(appClockProvider)().toUtc().add(duration);
    _updateCatalog(_catalog.snoozeRecommendation(activity.id, until));
  }

  void _adjustRecommendationWeight(_Activity activity, int delta) {
    _updateCatalog(_catalog.adjustRecommendationWeight(activity.id, delta));
  }

  bool _matchesQuery(_Activity activity) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return '${activity.title} ${activity.description} ${activity.badge}'
        .toLowerCase()
        .contains(query);
  }

  PracticeDurationFilter _durationFor(_Activity activity) {
    final saved = _catalog.launchByActivityId[activity.id]?.length;
    if (saved != null) {
      return switch (saved) {
        PracticeSessionLength.threeMinutes =>
          PracticeDurationFilter.threeMinutes,
        PracticeSessionLength.fiveMinutes => PracticeDurationFilter.fiveMinutes,
        PracticeSessionLength.tenMinutes => PracticeDurationFilter.tenMinutes,
        PracticeSessionLength.fifteenMinutes =>
          PracticeDurationFilter.tenMinutes,
        PracticeSessionLength.allItems => PracticeDurationFilter.unlimited,
        PracticeSessionLength.fiveItems => PracticeDurationFilter.threeMinutes,
        PracticeSessionLength.tenItems => PracticeDurationFilter.fiveMinutes,
        PracticeSessionLength.twentyItems => PracticeDurationFilter.tenMinutes,
      };
    }
    if (activity.id == 'match-sprint' ||
        activity.id == 'meaning-choice' ||
        activity.id == 'word-cards') {
      return PracticeDurationFilter.threeMinutes;
    }
    if (activity.id == 'pronunciation' || activity.id == 'situation-missions') {
      return PracticeDurationFilter.tenMinutes;
    }
    if (!activity.route.startsWith('/study')) {
      return PracticeDurationFilter.unlimited;
    }
    return PracticeDurationFilter.fiveMinutes;
  }

  Set<PracticeSkillFilter> _skillsFor(_Activity activity) {
    final id = activity.id;
    return {
      if ({
        'mixed-quiz',
        'exam-simulator',
        'meaning-choice',
        'match-sprint',
        'word-cards',
        'due-review',
        'recent-wrong',
        'weak-review',
        'favorites-review',
        'words-review',
      }.contains(id))
        PracticeSkillFilter.recognition,
      if ({
        'mixed-quiz',
        'exam-simulator',
        'production-writing',
        'sentence-cloze',
        'sentence-order',
        'due-review',
        'recent-wrong',
        'weak-review',
      }.contains(id))
        PracticeSkillFilter.recall,
      if ({
        'listening-dictation',
        'listening-discrimination',
        'pronunciation',
        'situation-missions',
      }.contains(id))
        PracticeSkillFilter.listening,
      if ({'pronunciation', 'situation-missions'}.contains(id))
        PracticeSkillFilter.speaking,
      if ({
        'sentence-cloze',
        'sentence-order',
        'sentence-cards',
        'situation-missions',
      }.contains(id))
        PracticeSkillFilter.sentence,
      if ({
        'word-cards',
        'sentence-cards',
        'unit-notes',
        'due-review',
        'favorites-review',
        'weak-review',
      }.contains(id))
        PracticeSkillFilter.memory,
    };
  }

  bool _matchesDiscoveryFilters(
    _Activity activity,
    PracticeCatalogPreferences catalog,
  ) {
    final durationMatches =
        catalog.durationFilter == PracticeDurationFilter.any ||
        _durationFor(activity) == catalog.durationFilter;
    final skillMatches =
        catalog.skillFilter == PracticeSkillFilter.all ||
        _skillsFor(activity).contains(catalog.skillFilter);
    return durationMatches && skillMatches;
  }

  List<_Activity> _sortActivities(
    List<_Activity> activities,
    PracticeCatalogPreferences catalog,
  ) {
    final recentRank = {
      for (final (index, id) in catalog.recentActivityIds.indexed) id: index,
    };
    final recommendationRank = {
      for (final (index, recommendation) in _practiceRecommendations(
        _recommendationBasis(),
        catalog,
      ).indexed)
        recommendation.activity.id: index,
    };
    int compare(_Activity left, _Activity right) {
      final result = switch (catalog.sortOrder) {
        PracticeCatalogSort.recommended =>
          (recommendationRank[left.id] ?? 999).compareTo(
            recommendationRank[right.id] ?? 999,
          ),
        PracticeCatalogSort.recent => (recentRank[left.id] ?? 999).compareTo(
          recentRank[right.id] ?? 999,
        ),
        PracticeCatalogSort.launchCount =>
          (catalog.launchCountByActivityId[right.id] ?? 0).compareTo(
            catalog.launchCountByActivityId[left.id] ?? 0,
          ),
        PracticeCatalogSort.name => left.title.compareTo(right.title),
      };
      return result != 0 ? result : left.title.compareTo(right.title);
    }

    return [...activities]..sort(compare);
  }

  List<_Activity> get _allActivities => [
    for (final category in _PracticeCategory.values)
      ..._activitiesFor(category),
  ];

  List<_Activity> _orderedFavorites(PracticeCatalogPreferences catalog) {
    final favorites = _allActivities
        .where((activity) => catalog.favoriteActivityIds.contains(activity.id))
        .where((activity) => !catalog.hiddenActivityIds.contains(activity.id))
        .toList(growable: false);
    if (catalog.favoriteActivityOrder.isEmpty) return favorites;
    final rank = <String, int>{
      for (final (index, id) in catalog.favoriteActivityOrder.indexed)
        id: index,
    };
    final naturalRank = <String, int>{
      for (final (index, activity) in favorites.indexed) activity.id: index,
    };
    return [...favorites]..sort((left, right) {
      final leftRank = rank[left.id];
      final rightRank = rank[right.id];
      if (leftRank != null && rightRank != null) {
        return leftRank.compareTo(rightRank);
      }
      if (leftRank != null) return -1;
      if (rightRank != null) return 1;
      return naturalRank[left.id]!.compareTo(naturalRank[right.id]!);
    });
  }

  List<_Activity> _recentActivities(
    PracticeCatalogPreferences catalog,
    Iterable<_PracticeRecommendation> recommendations,
  ) {
    final byId = {
      for (final recommendation in recommendations)
        recommendation.activity.id: recommendation.activity,
      for (final activity in _allActivities) activity.id: activity,
    };
    return [
      for (final id in catalog.recentActivityIds)
        if (byId[id] case final activity?)
          if (!catalog.hiddenActivityIds.contains(id) &&
              _availabilityFor(activity).enabled)
            activity,
    ];
  }

  List<_Activity> _dailyChallenges(PracticeCatalogPreferences catalog) {
    final candidates =
        _allActivities
            .where(
              (activity) => !catalog.hiddenActivityIds.contains(activity.id),
            )
            .where((activity) => activity.route.startsWith('/study'))
            .where((activity) => _availabilityFor(activity).enabled)
            .toList(growable: false)
          ..sort((left, right) => left.id.compareTo(right.id));
    if (candidates.isEmpty) return const [];
    final now = ref.read(appClockProvider)().toLocal();
    final subjectId = ref.read(appControllerProvider).activeSubjectId;
    final assigned = catalog.ensureDailyQuestAssignment(
      day: now,
      subjectId: subjectId,
      activityIds: candidates.map((activity) => activity.id),
    );
    if (!catalog.hasDailyQuestAssignment(day: now, subjectId: subjectId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final current = _catalog;
        _updateCatalog(
          current.ensureDailyQuestAssignment(
            day: now,
            subjectId: subjectId,
            activityIds: candidates.map((activity) => activity.id),
          ),
        );
      });
    }
    final byId = {for (final activity in _allActivities) activity.id: activity};
    return [
      for (final activityId in assigned.dailyQuestActivityIds(
        day: now,
        subjectId: subjectId,
        activityIds: candidates.map((activity) => activity.id),
      ))
        ?byId[activityId],
    ];
  }

  Future<void> _openDailyChallenge(_Activity activity) async {
    final catalog = _catalog;
    final hidden = catalog.hiddenActivityIds.contains(activity.id);
    final availability = _availabilityFor(activity);
    if (hidden || !availability.enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hidden
                ? '오늘 배정된 게임을 숨김 해제하면 이어서 완료할 수 있어요.'
                : availability.disabledReason ?? '이 도전은 지금 시작할 수 없어요.',
          ),
        ),
      );
      return;
    }
    await _openActivity(activity);
  }

  _PracticeRecommendationBasis _recommendationBasis() {
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
    StudySessionSummary? recentSession;
    for (final session in state.recentSessions) {
      if (session.courseId == state.activeCourseId) {
        recentSession = session;
        break;
      }
    }
    return _PracticeRecommendationBasis(
      dueCount: dueCount,
      wrongCount: wrongCount,
      recentAccuracy: recentSession == null || recentSession.attempts == 0
          ? null
          : (recentSession.accuracy * 100).round(),
    );
  }

  List<_PracticeRecommendation> _practiceRecommendations(
    _PracticeRecommendationBasis basis,
    PracticeCatalogPreferences catalog,
  ) {
    final state = ref.read(appControllerProvider);
    final dueCount = basis.dueCount;
    final wrongCount = basis.wrongCount;
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
          id: 'due-review',
          icon: Icons.event_repeat_rounded,
          title: '오늘 복습',
          description: '복습할 표현부터 정리해요',
          route: '/study?mode=review',
          badge: '복습',
        ),
        count: dueCount,
        reason: dueCount > 0 ? '복습 기한이 된 표현 $dueCount개' : '예정된 복습은 모두 끝냈어요',
        basisLabel: '복습 $dueCount',
        priority: dueCount > 0 ? 500 + dueCount : 20,
      ),
      _PracticeRecommendation(
        activity: const _Activity(
          id: 'recent-wrong',
          icon: Icons.history_toggle_off_rounded,
          title: '최근 오답',
          description: '최근 틀린 표현만 다시 봐요',
          route: '/study?mode=weak&historyFilter=wrongOnly',
          badge: '오답',
        ),
        count: wrongCount,
        reason: wrongCount > 0
            ? '최근 세션에서 놓친 표현 $wrongCount개'
            : '해결하지 못한 최근 오답이 없어요',
        basisLabel: '오답 $wrongCount',
        priority: wrongCount > 0 ? 400 + wrongCount : 10,
      ),
      _PracticeRecommendation(
        activity: const _Activity(
          id: 'words-review',
          icon: Icons.abc_rounded,
          title: '단어',
          description: '새 단어와 복습 단어를 짧게 익혀요',
          route: '/study?mode=words',
          badge: '단어',
        ),
        count: wordCount,
        reason: unstudiedWords > 0
            ? '아직 보지 않은 단어 $unstudiedWords개'
            : '등록된 단어 $wordCount개를 다시 다져요',
        basisLabel: unstudiedWords > 0
            ? '미학습 $unstudiedWords'
            : '단어 $wordCount',
        priority: unstudiedWords > 0 ? 300 + unstudiedWords : 60,
      ),
      _PracticeRecommendation(
        activity: const _Activity(
          id: 'listening-dictation',
          icon: Icons.headphones_rounded,
          title: '듣기',
          description: '소리를 듣고 표현을 확인해요',
          route: '/study?mode=listening',
          badge: '듣기',
        ),
        count: listeningCount,
        reason: '소리로 연습할 수 있는 표현 $listeningCount개',
        basisLabel: '듣기 $listeningCount',
        priority: listeningCount > 0 ? 120 + listeningCount : 0,
      ),
      _PracticeRecommendation(
        activity: const _Activity(
          id: 'pronunciation',
          icon: Icons.record_voice_over_rounded,
          title: '말하기',
          description: '듣고 따라 하며 발음을 확인해요',
          route: '/pronunciation',
          badge: '말하기',
        ),
        count: listeningCount,
        reason: '따라 말할 수 있는 표현 $listeningCount개',
        basisLabel: '말하기 $listeningCount',
        priority: listeningCount > 0 ? 110 + listeningCount : 0,
      ),
    ];
    final now = ref.read(appClockProvider)().toUtc();
    values.removeWhere((recommendation) {
      final hiddenUntil = catalog
          .recommendationSnoozedUntilByActivityId[recommendation.activity.id];
      return hiddenUntil != null && hiddenUntil.isAfter(now);
    });
    values.sort((left, right) {
      final leftPriority =
          left.priority +
          (catalog.recommendationWeightByActivityId[left.activity.id] ?? 0) *
              100;
      final rightPriority =
          right.priority +
          (catalog.recommendationWeightByActivityId[right.activity.id] ?? 0) *
              100;
      final priority = rightPriority.compareTo(leftPriority);
      if (priority != 0) return priority;
      return left.activity.title.compareTo(right.activity.title);
    });
    return values;
  }

  _ActivityAvailability _availabilityFor(_Activity activity) {
    final items = widget.items;
    if (activity.id == 'listening-discrimination') {
      final readiness = ListeningDiscriminationReadiness.evaluate(items);
      return _ActivityAvailability(
        availableCount: readiness.canStart ? readiness.eligibleTargetCount : 0,
        disabledReason: readiness.canStart ? null : readiness.reason,
      );
    }
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

  Future<void> _openActivity(
    _Activity activity, {
    bool forceConfigure = false,
    bool useSavedRules = false,
    List<String> playlistIds = const [],
    int playlistIndex = 0,
  }) async {
    if (!activity.route.startsWith('/study')) {
      _updateCatalog(_catalog.recordActivity(activity.id));
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
    final currentCatalog = _catalog;
    final routeHistoryFilter = switch (uri.queryParameters['historyFilter']) {
      'excludeCorrect' => StudyHistoryFilter.excludeCorrect,
      'wrongOnly' => StudyHistoryFilter.wrongOnly,
      _ => StudyHistoryFilter.all,
    };
    final savedLaunch = currentCatalog.launchFor(activity.id);
    final initialLaunch =
        !currentCatalog.launchByActivityId.containsKey(activity.id) &&
            uri.queryParameters['historyFilter'] == 'wrongOnly'
        ? savedLaunch.copyWith(historyScope: PracticeHistoryScope.wrongOnly)
        : savedLaunch;
    final initialHistoryFilter = switch (initialLaunch.historyScope) {
      PracticeHistoryScope.all => StudyHistoryFilter.all,
      PracticeHistoryScope.excludeCorrect => StudyHistoryFilter.excludeCorrect,
      PracticeHistoryScope.wrongOnly => StudyHistoryFilter.wrongOnly,
    };
    final intrinsicItems = controller.queue(
      now,
      mode: mode,
      itemLimit: StudyLimits.maxSessionItems,
      historyFilter: routeHistoryFilter,
    );
    final catalogPlan = controller.activeSessionPlan.copyWith(
      planId: '',
      subjectId: controller.activeSubject.id,
      title: activity.title,
      mode: mode,
      deck: StudyDeckScope.selected,
      unitIndex: null,
      difficulty: StudyDifficulty.all,
      queuePriority: StudyQueuePriority.dueFirst,
      historyFilter: initialHistoryFilter,
      groupIds: {},
      tags: {},
      levels: {},
      selectedItemIds: intrinsicItems.map((item) => item.id).toSet(),
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
    final quickLaunch =
        !forceConfigure &&
        preview.isNotEmpty &&
        (useSavedRules ||
            currentCatalog.quickLaunchActivityIds.contains(activity.id));
    final launch = quickLaunch
        ? _resolvePracticeLaunch(initialLaunch, preview.length)
        : await showModalBottomSheet<_PracticeLaunchResult>(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (context) => _PracticeLaunchSheet(
              activity: activity,
              mode: mode,
              availableCount: preview.length,
              newCount: newCount,
              dueCount: dueCount,
              initialPreferences: initialLaunch,
            ),
          );
    if (launch == null || !mounted) return;
    final catalog = _catalog;
    _updateCatalog(
      catalog
          .copyWith(
            launchByActivityId: {...catalog.launchByActivityId}
              ..[activity.id] = launch.preferences,
          )
          .recordActivity(activity.id),
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
    final playlistQuery = playlistIds.length >= 2
        ? '&playlist=${Uri.encodeQueryComponent(playlistIds.join(','))}'
              '&playlistIndex=$playlistIndex'
        : '';
    await context.push(
      '${activity.route}${separator}limit=${launch.itemLimit}'
      '&queuePriority=${launch.queuePriority.name}'
      '&historyFilter=${launch.historyFilter.name}'
      '&custom=true'
      '&practiceActivityId=${Uri.encodeQueryComponent(activity.id)}'
      '$playlistQuery',
    );
  }

  List<_Activity> _activitiesFor(_PracticeCategory category) {
    return switch (category) {
      _PracticeCategory.quiz => const [
        _Activity(
          id: 'mixed-quiz',
          icon: Icons.shuffle_rounded,
          title: '혼합 퀴즈',
          description: '여러 문제를 섞어 짧게 풀어요',
          route: '/study?mode=mixed',
          badge: '혼합',
        ),
        _Activity(
          id: 'meaning-choice',
          icon: Icons.touch_app_rounded,
          title: '뜻 고르기',
          description: '표현에 맞는 뜻을 골라요',
          route: '/study?mode=meaning',
          badge: '선택',
        ),
        _Activity(
          id: 'production-writing',
          icon: Icons.keyboard_rounded,
          title: '직접 쓰기',
          description: '뜻을 보고 표현을 써요',
          route: '/study?mode=production',
          badge: '쓰기',
        ),
        _Activity(
          id: 'sentence-cloze',
          icon: Icons.space_bar_rounded,
          title: '문장 빈칸',
          description: '문맥에 맞는 표현을 넣어요',
          route: '/study?mode=cloze',
          badge: '문장',
        ),
        _Activity(
          id: 'sentence-order',
          icon: Icons.reorder_rounded,
          title: '문장 배열',
          description: '단어를 올바른 순서로 놓아요',
          route: '/study?mode=sentenceOrder',
          badge: '문장',
        ),
        _Activity(
          id: 'listening-dictation',
          icon: Icons.headphones_rounded,
          title: '듣고 쓰기',
          description: '소리를 듣고 받아써요',
          route: '/study?mode=listening',
          badge: '듣기',
        ),
        _Activity(
          id: 'listening-discrimination',
          icon: Icons.hearing_rounded,
          title: '소리 구별',
          description: '소리를 듣고 가장 가까운 표현을 골라요',
          route:
              '/study?mode=listening&practiceActivityId=listening-discrimination',
          badge: '듣기',
        ),
        _Activity(
          id: 'match-sprint',
          icon: Icons.grid_view_rounded,
          title: '매치 스프린트',
          description: '표현과 뜻을 빠르게 연결해요',
          route: '/study?mode=mixed&match=true',
          badge: '매치',
        ),
        _Activity(
          id: 'exam-simulator',
          icon: Icons.assignment_turned_in_rounded,
          title: '시험 시뮬레이터',
          description: '시간과 합격 점수를 정해 실전처럼 풀어요',
          route: '/study?mode=mixed&exam=true',
          badge: '시험',
        ),
      ],
      _PracticeCategory.memorize => [
        const _Activity(
          id: 'word-cards',
          icon: Icons.style_rounded,
          title: '단어 카드',
          description: '표현과 뜻을 차분히 익혀요',
          route: '/cards?kind=words',
          badge: '암기',
        ),
        const _Activity(
          id: 'sentence-cards',
          icon: Icons.menu_book_rounded,
          title: '문장 카드',
          description: '문장의 뜻과 구조를 익혀요',
          route: '/cards?kind=sentences',
          badge: '암기',
        ),
        _Activity(
          id: 'unit-notes',
          icon: Icons.auto_stories_rounded,
          title: '단원 노트',
          description: '문형과 사용법을 살펴봐요',
          route: '/notes/${widget.recommendedUnitIndex}',
          badge: '노트',
        ),
        _Activity(
          id: 'favorites-review',
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
          id: 'pronunciation',
          icon: Icons.mic_rounded,
          title: '발음 따라하기',
          description: '직접 말하고 발음을 확인해요',
          route: '/pronunciation',
          badge: '발음',
        ),
        _Activity(
          id: 'situation-missions',
          icon: Icons.forum_rounded,
          title: '실전 상황 미션',
          description: '상황에 맞춰 듣고 말해요',
          route: '/missions',
          badge: '실전',
        ),
        _Activity(
          id: 'weak-review',
          icon: Icons.bolt_rounded,
          title: '취약 복습',
          description: '자주 틀린 표현을 집중해서 봐요',
          route: '/study?mode=weak',
          badge: '복습',
        ),
        _Activity(
          id: 'course-path',
          icon: Icons.route_rounded,
          title: '코스 여정',
          description: '단원별 학습 순서를 확인해요',
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
  ) => _sortActivities(
    _activitiesFor(category)
        .where((activity) => !catalog.hiddenActivityIds.contains(activity.id))
        .where(_matchesQuery)
        .where((activity) => _matchesDiscoveryFilters(activity, catalog))
        .toList(growable: false),
    catalog,
  );

  Future<void> _openSurpriseGame() async {
    final catalog = _catalog;
    final available = _allActivities
        .where((activity) => !catalog.hiddenActivityIds.contains(activity.id))
        .where((activity) => _availabilityFor(activity).enabled)
        .where(
          (activity) =>
              catalog.surpriseDurationFilter == PracticeDurationFilter.any ||
              _durationFor(activity) == catalog.surpriseDurationFilter,
        )
        .where(
          (activity) =>
              catalog.surpriseSkillFilter == PracticeSkillFilter.all ||
              _skillsFor(activity).contains(catalog.surpriseSkillFilter),
        )
        .where(
          (activity) =>
              !catalog.surpriseFavoritesOnly ||
              catalog.favoriteActivityIds.contains(activity.id),
        )
        .where(
          (activity) =>
              !catalog.surpriseAvoidRecent ||
              !catalog.recentActivityIds.take(3).contains(activity.id),
        )
        .toList(growable: false);
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('이 조건으로 시작할 수 있는 게임이 없어요.'),
          action: SnackBarAction(
            label: '조건 초기화',
            onPressed: () => _updateCatalog(
              catalog.copyWith(
                surpriseDurationFilter: PracticeDurationFilter.any,
                surpriseSkillFilter: PracticeSkillFilter.all,
                surpriseFavoritesOnly: false,
                surpriseAvoidRecent: false,
              ),
            ),
          ),
        ),
      );
      return;
    }
    final now = ref.read(appClockProvider)().microsecondsSinceEpoch;
    await _openActivity(available[now.abs() % available.length]);
  }

  Future<void> _showSurpriseSettings() async {
    final updated = await showModalBottomSheet<PracticeCatalogPreferences>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _SurpriseSettingsSheet(initial: _catalog),
    );
    if (updated != null) _updateCatalog(updated);
  }

  Widget _activityCard(_Activity activity, double width) {
    final availability = _availabilityFor(activity);
    final catalog = _catalog;
    final orderedFavorites = _orderedFavorites(catalog);
    final favoriteIndex = orderedFavorites.indexWhere(
      (value) => value.id == activity.id,
    );
    Widget card = SizedBox(
      width: width,
      child: _ActivityCard(
        activity: activity,
        disabledReason: availability.disabledReason,
        onPressed: availability.enabled ? () => _openActivity(activity) : null,
        favorite: catalog.favoriteActivityIds.contains(activity.id),
        quickLaunch: catalog.quickLaunchActivityIds.contains(activity.id),
        inPlaylist: _playlistSelection.contains(activity.id),
        supportsPlaylist: isPlaylistCompatiblePracticeActivity(activity.id),
        launchCount: catalog.launchCountByActivityId[activity.id] ?? 0,
        bestRecord: catalog.bestRecordsByActivityId[activity.id],
        supportsQuickLaunch: activity.route.startsWith('/study'),
        canMoveFavoriteEarlier: favoriteIndex > 0,
        canMoveFavoriteLater:
            favoriteIndex >= 0 && favoriteIndex < orderedFavorites.length - 1,
        onToggleFavorite: () => _toggleFavorite(activity),
        onMoveFavoriteEarlier: () => _moveFavorite(activity, -1),
        onMoveFavoriteLater: () => _moveFavorite(activity, 1),
        onToggleQuickLaunch: () => _toggleQuickLaunch(activity),
        onTogglePlaylist: () => _togglePlaylistSelection(activity),
        onConfigure: () => _openActivity(activity, forceConfigure: true),
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
    final favorites = _orderedFavorites(
      catalog,
    ).where(_matchesQuery).toList(growable: false);
    final recommendationBasis = _recommendationBasis();
    final recommendations = _practiceRecommendations(
      recommendationBasis,
      catalog,
    );
    final recentActivities = _recentActivities(catalog, recommendations);
    final dailyChallenges = _dailyChallenges(catalog);
    final dailyChallengeDay = ref.read(appClockProvider)().toLocal();
    final dailyChallengeSubjectId = ref.read(
      appControllerProvider.select((state) => state.activeSubjectId),
    );
    final completedDailyChallengeIds = catalog.completedDailyQuestActivityIds(
      day: dailyChallengeDay,
      subjectId: dailyChallengeSubjectId,
      activityIds: dailyChallenges.map((activity) => activity.id),
    );
    final hidden = _allActivities
        .where((activity) => catalog.hiddenActivityIds.contains(activity.id))
        .toList(growable: false);
    final activeDiscoveryFilterCount = [
      catalog.durationFilter != PracticeDurationFilter.any,
      catalog.skillFilter != PracticeSkillFilter.all,
      catalog.sortOrder != PracticeCatalogSort.recommended,
    ].where((active) => active).length;
    final visibleResultCount = _PracticeCategory.values
        .expand((category) => _visibleActivities(category, catalog))
        .map((activity) => activity.id)
        .toSet()
        .length;
    final planTitle = widget.plan.title.trim();
    final planSummary = planTitle.isEmpty
        ? '맞춤 ${widget.itemCount}문제'
        : '$planTitle · ${widget.itemCount}문제';

    Widget? categorySection(_PracticeCategory category) {
      final activities = _visibleActivities(category, catalog);
      if (activities.isEmpty) return null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  for (final activity in activities)
                    _activityCard(activity, width),
                ],
              );
            },
          ),
        ],
      );
    }

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
                    '퀴즈, 암기, 실전 연습 중 원하는 방식을 고르세요.',
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
        const SizedBox(height: 10),
        SegmentedButton<_PracticeHubTab>(
          key: const Key('practice-hub-tabs'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: _PracticeHubTab.recommended,
              icon: Icon(Icons.auto_awesome_outlined),
              label: Text('추천'),
            ),
            ButtonSegment(
              value: _PracticeHubTab.games,
              icon: Icon(Icons.sports_esports_outlined),
              label: Text('전체 게임'),
            ),
            ButtonSegment(
              value: _PracticeHubTab.missions,
              icon: Icon(Icons.explore_outlined),
              label: Text('미션'),
            ),
          ],
          selected: {_selectedTab},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              setState(() => _selectedTab = selection.first);
            }
          },
        ),
        const SizedBox(height: 10),
        if (_selectedTab == _PracticeHubTab.recommended &&
            _hasMissingMaterialCapability &&
            widget.items.isEmpty) ...[
          _MissingMaterialNotice(
            isEmpty: true,
            onAdd: () => context.go('/library/new'),
          ),
          const SizedBox(height: 10),
        ],
        if (_selectedTab == _PracticeHubTab.recommended)
          _PersonalizedPracticeHub(
            recommendations: recommendations,
            basis: recommendationBasis,
            recommendationWeights: catalog.recommendationWeightByActivityId,
            availabilityFor: _availabilityFor,
            onPressed: (activity) =>
                _openActivity(activity, useSavedRules: true),
            onConfigure: (activity) =>
                _openActivity(activity, forceConfigure: true),
            onSeeMore: (activity) => _adjustRecommendationWeight(activity, 1),
            onSeeLess: (activity) => _adjustRecommendationWeight(activity, -1),
            onHideToday: (activity) =>
                _snoozeRecommendation(activity, const Duration(days: 1)),
            onHideSevenDays: (activity) =>
                _snoozeRecommendation(activity, const Duration(days: 7)),
          ),
        if (_selectedTab == _PracticeHubTab.recommended &&
            dailyChallenges.isNotEmpty) ...[
          const SizedBox(height: 8),
          _DailyQuestBoard(
            activities: dailyChallenges,
            completedActivityIds: completedDailyChallengeIds,
            quickLaunchActivityIds: catalog.quickLaunchActivityIds,
            onPressed: _openDailyChallenge,
          ),
        ],
        if (_selectedTab != _PracticeHubTab.missions &&
            recentActivities.isNotEmpty) ...[
          const SizedBox(height: 10),
          _RecentPracticeRow(
            activities: recentActivities,
            launchCounts: catalog.launchCountByActivityId,
            onPressed: (activity) =>
                _openActivity(activity, useSavedRules: true),
          ),
        ],
        if (_selectedTab != _PracticeHubTab.missions &&
            favorites.isNotEmpty) ...[
          const SizedBox(height: 8),
          _FavoritePracticeRow(
            activities: favorites,
            onPressed: (activity) =>
                _openActivity(activity, useSavedRules: true),
          ),
        ],
        if (_selectedTab == _PracticeHubTab.missions)
          _MissionHubPanel(
            recommendedUnitIndex: widget.recommendedUnitIndex,
            onOpenMissions: () => context.go('/missions'),
            onOpenPath: () => context.go('/path'),
          ),
        if (_selectedTab == _PracticeHubTab.games) ...[
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final search = TextField(
                key: const Key('practice-game-search'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  isDense: true,
                  constraints: const BoxConstraints(minHeight: 44),
                  hintText: '게임 검색 · 쓰기, 듣기, 문장…',
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
              final surprise = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.tonalIcon(
                    key: const Key('practice-surprise-game'),
                    onPressed: _openSurpriseGame,
                    icon: const Icon(Icons.casino_outlined),
                    label: const Text('깜짝 게임'),
                  ),
                  IconButton(
                    key: const Key('practice-surprise-settings'),
                    tooltip: '깜짝 게임 조건',
                    onPressed: _showSurpriseSettings,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
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
          const SizedBox(height: 6),
          _PracticeDiscoveryControls(
            catalog: catalog,
            activeFilterCount: activeDiscoveryFilterCount,
            onDurationChanged: (value) =>
                _updateCatalog(catalog.copyWith(durationFilter: value)),
            onSkillChanged: (value) =>
                _updateCatalog(catalog.copyWith(skillFilter: value)),
            onSortChanged: (value) =>
                _updateCatalog(catalog.copyWith(sortOrder: value)),
            onReset: activeDiscoveryFilterCount == 0
                ? null
                : () => _updateCatalog(
                    catalog.copyWith(
                      durationFilter: PracticeDurationFilter.any,
                      skillFilter: PracticeSkillFilter.all,
                      sortOrder: PracticeCatalogSort.recommended,
                    ),
                  ),
            onClearRecommendationSnoozes:
                catalog.recommendationSnoozedUntilByActivityId.isEmpty
                ? null
                : () => _updateCatalog(catalog.clearRecommendationSnoozes()),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Semantics(
              key: const Key('practice-search-result-summary'),
              liveRegion: true,
              label: '현재 조건에 맞는 게임 $visibleResultCount개',
              child: Text(
                '${_query.trim().isEmpty && activeDiscoveryFilterCount == 0 ? '전체' : '현재 조건'} · '
                '$visibleResultCount개 게임',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          if (_playlistSelection.isNotEmpty ||
              catalog.playlists.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PracticePlaylistPanel(
              selectedIds: _playlistSelection,
              titleForId: (id) => _allActivities
                  .cast<_Activity?>()
                  .firstWhere(
                    (activity) => activity?.id == id,
                    orElse: () => null,
                  )
                  ?.title,
              playlists: catalog.playlists,
              onSave: _savePlaylist,
              onStart: _startPlaylist,
              onRemove: _removePlaylist,
              onClearSelection: () => setState(_playlistSelection.clear),
            ),
          ],
          const SizedBox(height: 12),
          if (categorySection(_PracticeCategory.quiz)
              case final quizSection?) ...[
            quizSection,
            const SizedBox(height: 10),
          ],
          if (_hasMissingMaterialCapability && widget.items.isNotEmpty) ...[
            _MissingMaterialNotice(
              isEmpty: false,
              onAdd: () => context.go('/library/new'),
            ),
            const SizedBox(height: 12),
          ],
          for (final category in _PracticeCategory.values)
            if (category != _PracticeCategory.quiz)
              if (categorySection(category) case final section?) ...[
                const SizedBox(height: 12),
                section,
              ],
          if (_query.trim().isNotEmpty &&
              _PracticeCategory.values.every(
                (category) => _visibleActivities(category, catalog).isEmpty,
              )) ...[
            const SizedBox(height: 18),
            const Center(child: Text('조건에 맞는 게임이 없어요.')),
          ],
          if (hidden.isNotEmpty) ...[
            const SizedBox(height: 18),
            ExpansionTile(
              key: const Key('hidden-practice-games'),
              tilePadding: EdgeInsets.zero,
              title: Text('숨긴 게임 ${hidden.length}개'),
              subtitle: const Text('언제든 다시 표시할 수 있어요.'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final activity in hidden)
                        ActionChip(
                          avatar: const Icon(
                            Icons.visibility_outlined,
                            size: 18,
                          ),
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
      ],
    );
  }
}

class _MissionHubPanel extends StatelessWidget {
  const _MissionHubPanel({
    required this.recommendedUnitIndex,
    required this.onOpenMissions,
    required this.onOpenPath,
  });

  final int recommendedUnitIndex;
  final VoidCallback onOpenMissions;
  final VoidCallback onOpenPath;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('practice-mission-hub'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.tertiaryContainer,
                  foregroundColor: colors.onTertiaryContainer,
                  child: const Icon(Icons.explore_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '상황 미션',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Unit ${recommendedUnitIndex + 1} 추천 · 선택에 따라 대화가 달라져요.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('open-course-path-from-missions'),
                  onPressed: onOpenPath,
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('학습 경로'),
                ),
                FilledButton.icon(
                  key: const Key('open-situation-missions'),
                  onPressed: onOpenMissions,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('미션 선택'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeRecommendation {
  const _PracticeRecommendation({
    required this.activity,
    required this.count,
    required this.reason,
    required this.basisLabel,
    required this.priority,
  });

  final _Activity activity;
  final int count;
  final String reason;
  final String basisLabel;
  final int priority;
}

class _PracticeRecommendationBasis {
  const _PracticeRecommendationBasis({
    required this.dueCount,
    required this.wrongCount,
    required this.recentAccuracy,
  });

  final int dueCount;
  final int wrongCount;
  final int? recentAccuracy;
}

class _PersonalizedPracticeHub extends StatefulWidget {
  const _PersonalizedPracticeHub({
    required this.recommendations,
    required this.basis,
    required this.recommendationWeights,
    required this.availabilityFor,
    required this.onPressed,
    required this.onConfigure,
    required this.onSeeMore,
    required this.onSeeLess,
    required this.onHideToday,
    required this.onHideSevenDays,
  });

  final List<_PracticeRecommendation> recommendations;
  final _PracticeRecommendationBasis basis;
  final Map<String, int> recommendationWeights;
  final _ActivityAvailability Function(_Activity) availabilityFor;
  final Future<void> Function(_Activity) onPressed;
  final Future<void> Function(_Activity) onConfigure;
  final ValueChanged<_Activity> onSeeMore;
  final ValueChanged<_Activity> onSeeLess;
  final ValueChanged<_Activity> onHideToday;
  final ValueChanged<_Activity> onHideSevenDays;

  @override
  State<_PersonalizedPracticeHub> createState() =>
      _PersonalizedPracticeHubState();
}

class _PersonalizedPracticeHubState extends State<_PersonalizedPracticeHub> {
  static const _cardWidth = 180.0;
  static const _cardGap = 8.0;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _scrollFocusNode = FocusNode(
    debugLabel: 'Practice Hub recommendations',
  );
  bool _canScrollBackward = false;
  bool _canScrollForward = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_refreshNavigationState);
    _queueNavigationRefresh();
  }

  @override
  void didUpdateWidget(covariant _PersonalizedPracticeHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.recommendations.length != widget.recommendations.length) {
      _queueNavigationRefresh();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_refreshNavigationState)
      ..dispose();
    _scrollFocusNode.dispose();
    super.dispose();
  }

  void _queueNavigationRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshNavigationState();
    });
  }

  void _refreshNavigationState() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final canScrollBackward = position.pixels > position.minScrollExtent + 0.5;
    final canScrollForward = position.pixels < position.maxScrollExtent - 0.5;
    if (canScrollBackward == _canScrollBackward &&
        canScrollForward == _canScrollForward) {
      return;
    }
    setState(() {
      _canScrollBackward = canScrollBackward;
      _canScrollForward = canScrollForward;
    });
  }

  double get _navigationStep {
    if (!_scrollController.hasClients) return _cardWidth + _cardGap;
    return (_scrollController.position.viewportDimension * 0.82)
        .clamp(_cardWidth + _cardGap, (_cardWidth + _cardGap) * 2)
        .toDouble();
  }

  Future<void> _scrollBy(double delta) async {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = (position.pixels + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    await _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _jumpBy(double delta) {
    if (!_scrollController.hasClients || delta == 0) return;
    final position = _scrollController.position;
    _scrollController.jumpTo(
      (position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble(),
    );
  }

  KeyEventResult _handleScrollKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _scrollBy(-_navigationStep);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _scrollBy(_navigationStep);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _scrollBy(-_navigationStep * 2);
    } else if (key == LogicalKeyboardKey.pageDown) {
      _scrollBy(_navigationStep * 2);
    } else if (key == LogicalKeyboardKey.home) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else if (key == LogicalKeyboardKey.end) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    final showPagingButtons =
        defaultTargetPlatform == TargetPlatform.windows ||
        MediaQuery.sizeOf(context).width >= 600;
    _PracticeRecommendation? primary;
    for (final recommendation in widget.recommendations) {
      if (widget.availabilityFor(recommendation.activity).enabled) {
        primary = recommendation;
        break;
      }
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '오늘 바로 학습',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (primary case final recommendation?) ...[
                  IconButton(
                    key: const Key('configure-recommended-practice'),
                    onPressed: () =>
                        widget.onConfigure(recommendation.activity),
                    tooltip: '바로 학습 설정',
                    icon: const Icon(Icons.tune_rounded),
                  ),
                  const SizedBox(width: 2),
                  FilledButton.tonalIcon(
                    key: const Key('start-recommended-practice'),
                    onPressed: () => widget.onPressed(recommendation.activity),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('바로 시작'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Wrap(
              key: const Key('practice-recommendation-basis'),
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniBadge(label: '복습 ${widget.basis.dueCount}'),
                _MiniBadge(label: '오답 ${widget.basis.wrongCount}'),
                _MiniBadge(
                  label: widget.basis.recentAccuracy == null
                      ? '최근 정확도 -'
                      : '최근 정확도 ${widget.basis.recentAccuracy}%',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '추천 ${widget.recommendations.length}개 · 카드를 누르면 바로 시작해요',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (showPagingButtons) ...[
                  const SizedBox(width: 6),
                  IconButton.outlined(
                    key: const Key('practice-hub-scroll-previous'),
                    onPressed: _canScrollBackward
                        ? () => _scrollBy(-_navigationStep)
                        : null,
                    tooltip: '이전 추천 카드',
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    key: const Key('practice-hub-scroll-next'),
                    onPressed: _canScrollForward
                        ? () => _scrollBy(_navigationStep)
                        : null,
                    tooltip: '다음 추천 카드',
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 100,
              child: Focus(
                key: const Key('practice-hub-scroll-focus'),
                focusNode: _scrollFocusNode,
                onKeyEvent: _handleScrollKey,
                child: Listener(
                  onPointerDown: (_) => _scrollFocusNode.requestFocus(),
                  onPointerSignal: (event) {
                    if (event is! PointerScrollEvent) return;
                    final delta =
                        event.scrollDelta.dx.abs() > event.scrollDelta.dy.abs()
                        ? event.scrollDelta.dx
                        : event.scrollDelta.dy;
                    _jumpBy(delta);
                  },
                  child: ScrollConfiguration(
                    behavior: const _PracticeHubScrollBehavior(),
                    child: Scrollbar(
                      key: const Key('practice-hub-scrollbar'),
                      controller: _scrollController,
                      thumbVisibility: true,
                      trackVisibility:
                          defaultTargetPlatform == TargetPlatform.windows,
                      interactive: true,
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      child: ListView.separated(
                        key: const Key('personalized-practice-hub'),
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 12),
                        scrollDirection: Axis.horizontal,
                        itemCount: widget.recommendations.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final recommendation = widget.recommendations[index];
                          final availability = widget.availabilityFor(
                            recommendation.activity,
                          );
                          return SizedBox(
                            key: Key(
                              'practice-recommendation-${recommendation.activity.id}',
                            ),
                            width: 180,
                            child: KeyedSubtree(
                              key: Key(
                                'practice-recommendation-compact-card-'
                                '${recommendation.activity.id}',
                              ),
                              child: Material(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(14),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: availability.enabled
                                      ? () => widget.onPressed(
                                          recommendation.activity,
                                        )
                                      : null,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      9,
                                      3,
                                      4,
                                      5,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              recommendation.activity.icon,
                                              size: 19,
                                            ),
                                            const SizedBox(width: 6),
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
                                            if (!largeText)
                                              _MiniBadge(
                                                label:
                                                    recommendation.basisLabel,
                                              ),
                                            SizedBox.square(
                                              dimension: 44,
                                              child: PopupMenuButton<String>(
                                                key: Key(
                                                  'practice-recommendation-menu-'
                                                  '${recommendation.activity.id}',
                                                ),
                                                tooltip: '추천 조정',
                                                padding: EdgeInsets.zero,
                                                onSelected: (value) {
                                                  if (value == 'more') {
                                                    widget.onSeeMore(
                                                      recommendation.activity,
                                                    );
                                                  }
                                                  if (value == 'less') {
                                                    widget.onSeeLess(
                                                      recommendation.activity,
                                                    );
                                                  }
                                                  if (value == 'today') {
                                                    widget.onHideToday(
                                                      recommendation.activity,
                                                    );
                                                  }
                                                  if (value == 'week') {
                                                    widget.onHideSevenDays(
                                                      recommendation.activity,
                                                    );
                                                  }
                                                },
                                                itemBuilder: (context) =>
                                                    const [
                                                      PopupMenuItem(
                                                        value: 'more',
                                                        child: Text(
                                                          '이런 게임 더 보기',
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'less',
                                                        child: Text(
                                                          '이런 게임 덜 보기',
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'today',
                                                        child: Text(
                                                          '오늘 추천에서 숨기기',
                                                        ),
                                                      ),
                                                      PopupMenuItem(
                                                        value: 'week',
                                                        child: Text(
                                                          '7일 동안 숨기기',
                                                        ),
                                                      ),
                                                    ],
                                                icon: const Icon(
                                                  Icons.more_vert_rounded,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  availability.enabled
                                                      ? largeText
                                                            ? '${recommendation.basisLabel} · ${recommendation.reason}'
                                                            : recommendation
                                                                  .reason
                                                      : availability
                                                                .disabledReason ??
                                                            recommendation
                                                                .reason,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.bodySmall,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                (widget.recommendationWeights[recommendation
                                                                .activity
                                                                .id] ??
                                                            0) !=
                                                        0
                                                    ? '${widget.recommendationWeights[recommendation.activity.id]! > 0 ? '+' : ''}'
                                                          '${widget.recommendationWeights[recommendation.activity.id]}'
                                                    : index == 0 &&
                                                          availability.enabled
                                                    ? '지금 먼저 하기'
                                                    : availability.enabled
                                                    ? '바로 시작'
                                                    : '자료 필요',
                                                style: TextStyle(
                                                  color: availability.enabled
                                                      ? colors.primary
                                                      : colors.onSurfaceVariant,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeHubScrollBehavior extends MaterialScrollBehavior {
  const _PracticeHubScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
  };
}

class _DailyQuestBoard extends StatelessWidget {
  const _DailyQuestBoard({
    required this.activities,
    required this.completedActivityIds,
    required this.quickLaunchActivityIds,
    required this.onPressed,
  });

  final List<_Activity> activities;
  final Set<String> completedActivityIds;
  final Set<String> quickLaunchActivityIds;
  final ValueChanged<_Activity> onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('practice-daily-challenge'),
      color: colors.tertiaryContainer.withValues(alpha: 0.42),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: colors.tertiary,
                  size: 20,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '오늘의 3가지 도전',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  '${completedActivityIds.length}/${activities.length} 완료',
                  key: const Key('practice-daily-quest-progress'),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final (index, activity) in activities.indexed) ...[
              if (index == 0) ...[
                Text(
                  '서로 다른 방식으로 하나씩 완료해 보세요. XP와 학습 결과는 그대로 기록돼요.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
              ],
              if (index > 0) const SizedBox(height: 5),
              Material(
                key: Key('practice-daily-quest-$index'),
                color: colors.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(11),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onPressed(activity),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(9, 7, 7, 7),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: colors.tertiaryContainer,
                          foregroundColor: colors.onTertiaryContainer,
                          child: completedActivityIds.contains(activity.id)
                              ? const Icon(Icons.check_rounded, size: 17)
                              : Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${completedActivityIds.contains(activity.id) ? '완료' : '오늘의 도전'} · ${activity.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                completedActivityIds.contains(activity.id)
                                    ? '완료됨 · 다시 연습할 수 있어요'
                                    : quickLaunchActivityIds.contains(
                                        activity.id,
                                      )
                                    ? '저장한 설정으로 바로 시작'
                                    : switch (index) {
                                        0 => '가볍게 몸풀기',
                                        1 => '다른 방식으로 집중 훈련',
                                        _ => '새 게임으로 마무리',
                                      },
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          completedActivityIds.contains(activity.id)
                              ? Icons.replay_rounded
                              : Icons.play_arrow_rounded,
                          color: colors.tertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PracticeDiscoveryControls extends StatelessWidget {
  const _PracticeDiscoveryControls({
    required this.catalog,
    required this.activeFilterCount,
    required this.onDurationChanged,
    required this.onSkillChanged,
    required this.onSortChanged,
    required this.onReset,
    required this.onClearRecommendationSnoozes,
  });

  final PracticeCatalogPreferences catalog;
  final int activeFilterCount;
  final ValueChanged<PracticeDurationFilter> onDurationChanged;
  final ValueChanged<PracticeSkillFilter> onSkillChanged;
  final ValueChanged<PracticeCatalogSort> onSortChanged;
  final VoidCallback? onReset;
  final VoidCallback? onClearRecommendationSnoozes;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        key: const Key('practice-discovery-controls'),
        title: Row(
          children: [
            const Expanded(child: Text('필터·정렬')),
            if (activeFilterCount > 0)
              _MiniBadge(label: '$activeFilterCount개 적용'),
          ],
        ),
        subtitle: Text(
          '${_durationLabel(catalog.durationFilter)} · '
          '${_skillLabel(catalog.skillFilter)} · '
          '${_sortLabel(catalog.sortOrder)}',
        ),
        trailing: onReset == null
            ? null
            : IconButton(
                key: const Key('reset-practice-filters'),
                tooltip: '필터와 정렬 초기화',
                onPressed: onReset,
                icon: const Icon(Icons.filter_alt_off_outlined),
              ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('예상 시간', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in PracticeDurationFilter.values)
                  ChoiceChip(
                    key: Key('practice-duration-filter-${value.name}'),
                    label: Text(_durationLabel(value)),
                    selected: catalog.durationFilter == value,
                    onSelected: (_) => onDurationChanged(value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('기술', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in PracticeSkillFilter.values)
                  ChoiceChip(
                    key: Key('practice-skill-filter-${value.name}'),
                    label: Text(_skillLabel(value)),
                    selected: catalog.skillFilter == value,
                    onSelected: (_) => onSkillChanged(value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('정렬', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in PracticeCatalogSort.values)
                  ChoiceChip(
                    key: Key('practice-sort-${value.name}'),
                    label: Text(_sortLabel(value)),
                    selected: catalog.sortOrder == value,
                    onSelected: (_) => onSortChanged(value),
                  ),
              ],
            ),
          ),
          if (onClearRecommendationSnoozes != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('clear-practice-recommendation-snoozes'),
                onPressed: onClearRecommendationSnoozes,
                icon: const Icon(Icons.visibility_rounded),
                label: Text(
                  '숨긴 추천 ${catalog.recommendationSnoozedUntilByActivityId.length}개 복원',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SurpriseSettingsSheet extends StatefulWidget {
  const _SurpriseSettingsSheet({required this.initial});

  final PracticeCatalogPreferences initial;

  @override
  State<_SurpriseSettingsSheet> createState() => _SurpriseSettingsSheetState();
}

class _SurpriseSettingsSheetState extends State<_SurpriseSettingsSheet> {
  late PracticeDurationFilter _duration;
  late PracticeSkillFilter _skill;
  late bool _favoritesOnly;
  late bool _avoidRecent;

  @override
  void initState() {
    super.initState();
    _duration = widget.initial.surpriseDurationFilter;
    _skill = widget.initial.surpriseSkillFilter;
    _favoritesOnly = widget.initial.surpriseFavoritesOnly;
    _avoidRecent = widget.initial.surpriseAvoidRecent;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          0,
          18,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('깜짝 게임 조건', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('이 조건으로 시작할 수 있는 게임 하나를 골라 드려요.'),
            const SizedBox(height: 14),
            const Text('예상 시간', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in PracticeDurationFilter.values)
                  ChoiceChip(
                    key: Key('surprise-duration-${value.name}'),
                    selected: _duration == value,
                    label: Text(_durationLabel(value)),
                    onSelected: (_) => setState(() => _duration = value),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('기술', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in PracticeSkillFilter.values)
                  ChoiceChip(
                    key: Key('surprise-skill-${value.name}'),
                    selected: _skill == value,
                    label: Text(_skillLabel(value)),
                    onSelected: (_) => setState(() => _skill = value),
                  ),
              ],
            ),
            SwitchListTile.adaptive(
              key: const Key('surprise-favorites-only'),
              contentPadding: EdgeInsets.zero,
              value: _favoritesOnly,
              title: const Text('즐겨찾는 게임만'),
              onChanged: (value) => setState(() => _favoritesOnly = value),
            ),
            SwitchListTile.adaptive(
              key: const Key('surprise-avoid-recent'),
              contentPadding: EdgeInsets.zero,
              value: _avoidRecent,
              title: const Text('최근 3개 게임 피하기'),
              onChanged: (value) => setState(() => _avoidRecent = value),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const Key('save-surprise-settings'),
              onPressed: () => Navigator.pop(
                context,
                widget.initial.copyWith(
                  surpriseDurationFilter: _duration,
                  surpriseSkillFilter: _skill,
                  surpriseFavoritesOnly: _favoritesOnly,
                  surpriseAvoidRecent: _avoidRecent,
                ),
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('조건 저장'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticePlaylistPanel extends StatelessWidget {
  const _PracticePlaylistPanel({
    required this.selectedIds,
    required this.titleForId,
    required this.playlists,
    required this.onSave,
    required this.onStart,
    required this.onRemove,
    required this.onClearSelection,
  });

  final List<String> selectedIds;
  final String? Function(String) titleForId;
  final List<PracticePlaylist> playlists;
  final VoidCallback onSave;
  final Future<void> Function(PracticePlaylist) onStart;
  final ValueChanged<PracticePlaylist> onRemove;
  final VoidCallback onClearSelection;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('practice-playlist-panel'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.playlist_play_rounded),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '게임 플레이리스트',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (selectedIds.isNotEmpty)
                  TextButton(
                    onPressed: onClearSelection,
                    child: const Text('선택 해제'),
                  ),
              ],
            ),
            if (selectedIds.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (index, id) in selectedIds.indexed)
                    Chip(label: Text('${index + 1}. ${titleForId(id) ?? id}')),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                key: const Key('save-practice-playlist'),
                onPressed: selectedIds.length >= 2 && selectedIds.length <= 5
                    ? onSave
                    : null,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  selectedIds.length < 2
                      ? '게임을 ${2 - selectedIds.length}개 더 골라 주세요'
                      : '${selectedIds.length}개 게임 묶음 저장',
                ),
              ),
            ],
            if (playlists.isNotEmpty) ...[
              const Divider(height: 22),
              for (final playlist in playlists)
                ListTile(
                  key: Key('practice-playlist-${playlist.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.queue_play_next_rounded),
                  title: Text(playlist.name),
                  subtitle: Text(
                    playlist.activityIds
                        .map((id) => titleForId(id) ?? id)
                        .join(' → '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('start-practice-playlist-${playlist.id}'),
                        tooltip: '순차 실행',
                        onPressed: () => onStart(playlist),
                        icon: const Icon(Icons.play_arrow_rounded),
                      ),
                      IconButton(
                        tooltip: '삭제',
                        onPressed: () => onRemove(playlist),
                        icon: const Icon(Icons.delete_outline_rounded),
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
}

String _durationLabel(PracticeDurationFilter value) => switch (value) {
  PracticeDurationFilter.any => '전체 시간',
  PracticeDurationFilter.threeMinutes => '약 3분',
  PracticeDurationFilter.fiveMinutes => '약 5분',
  PracticeDurationFilter.tenMinutes => '약 10분',
  PracticeDurationFilter.unlimited => '무제한',
};

String _skillLabel(PracticeSkillFilter value) => switch (value) {
  PracticeSkillFilter.all => '전체 기술',
  PracticeSkillFilter.recognition => '뜻 알아보기',
  PracticeSkillFilter.recall => '직접 떠올리기',
  PracticeSkillFilter.listening => '듣기',
  PracticeSkillFilter.speaking => '말하기',
  PracticeSkillFilter.sentence => '문장',
  PracticeSkillFilter.memory => '암기·복습',
};

String _sortLabel(PracticeCatalogSort value) => switch (value) {
  PracticeCatalogSort.recommended => '추천순',
  PracticeCatalogSort.recent => '최근 실행순',
  PracticeCatalogSort.launchCount => '자주 실행순',
  PracticeCatalogSort.name => '이름순',
};

class _RecentPracticeRow extends StatelessWidget {
  const _RecentPracticeRow({
    required this.activities,
    required this.launchCounts,
    required this.onPressed,
  });

  final List<_Activity> activities;
  final Map<String, int> launchCounts;
  final Future<void> Function(_Activity) onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('recent-practice-games'),
      children: [
        const Icon(Icons.history_rounded, size: 19),
        const SizedBox(width: 6),
        Text(
          '최근',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: activities.length,
              separatorBuilder: (_, _) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final activity = activities[index];
                return ActionChip(
                  key: Key('recent-practice-${activity.id}'),
                  avatar: Icon(activity.icon, size: 17),
                  label: Text(
                    '${activity.title} · ${launchCounts[activity.id] ?? 0}',
                  ),
                  onPressed: () => onPressed(activity),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FavoritePracticeRow extends StatelessWidget {
  const _FavoritePracticeRow({
    required this.activities,
    required this.onPressed,
  });

  final List<_Activity> activities;
  final Future<void> Function(_Activity) onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('favorite-practice-games'),
      container: true,
      label: '즐겨찾는 게임 ${activities.length}개. 저장한 규칙으로 바로 시작합니다.',
      child: Row(
        children: [
          const Icon(Icons.star_rounded, size: 19),
          const SizedBox(width: 6),
          Text(
            '즐겨찾는 게임',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: activities.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return ActionChip(
                    key: Key('favorite-practice-${activity.id}'),
                    avatar: Icon(activity.icon, size: 17),
                    label: Text(activity.title),
                    onPressed: () => onPressed(activity),
                  );
                },
              ),
            ),
          ),
        ],
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
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 32 : 36,
          height: compact ? 32 : 36,
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
              if (!compact) ...[
                const SizedBox(height: 2),
                Text(
                  description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
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
    required this.quickLaunch,
    required this.inPlaylist,
    required this.supportsPlaylist,
    required this.launchCount,
    required this.bestRecord,
    required this.supportsQuickLaunch,
    required this.canMoveFavoriteEarlier,
    required this.canMoveFavoriteLater,
    required this.onToggleFavorite,
    required this.onMoveFavoriteEarlier,
    required this.onMoveFavoriteLater,
    required this.onToggleQuickLaunch,
    required this.onTogglePlaylist,
    required this.onConfigure,
    required this.onHide,
  });

  final _Activity activity;
  final String? disabledReason;
  final VoidCallback? onPressed;
  final bool favorite;
  final bool quickLaunch;
  final bool inPlaylist;
  final bool supportsPlaylist;
  final int launchCount;
  final PracticeBestRecord? bestRecord;
  final bool supportsQuickLaunch;
  final bool canMoveFavoriteEarlier;
  final bool canMoveFavoriteLater;
  final VoidCallback onToggleFavorite;
  final VoidCallback onMoveFavoriteEarlier;
  final VoidCallback onMoveFavoriteLater;
  final VoidCallback onToggleQuickLaunch;
  final VoidCallback onTogglePlaylist;
  final VoidCallback onConfigure;
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
            ? (enabled ? 100.0 : 120.0) + (scaleDelta * 46)
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
            if (value == 'move-earlier') onMoveFavoriteEarlier();
            if (value == 'move-later') onMoveFavoriteLater();
            if (value == 'quick-launch') onToggleQuickLaunch();
            if (value == 'playlist') onTogglePlaylist();
            if (value == 'configure') onConfigure();
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
            if (favorite && canMoveFavoriteEarlier)
              PopupMenuItem(
                key: Key('practice-move-earlier-${activity.id}'),
                value: 'move-earlier',
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.arrow_back_rounded),
                  title: Text('즐겨찾기에서 앞으로'),
                ),
              ),
            if (favorite && canMoveFavoriteLater)
              PopupMenuItem(
                key: Key('practice-move-later-${activity.id}'),
                value: 'move-later',
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.arrow_forward_rounded),
                  title: Text('즐겨찾기에서 뒤로'),
                ),
              ),
            if (supportsQuickLaunch && enabled)
              PopupMenuItem(
                key: Key('practice-quick-launch-${activity.id}'),
                value: 'quick-launch',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    quickLaunch
                        ? Icons.rocket_launch_rounded
                        : Icons.rocket_launch_outlined,
                  ),
                  title: Text(quickLaunch ? '바로 시작 사용 안 함' : '저장 설정으로 바로 시작'),
                ),
              ),
            if (supportsQuickLaunch && enabled && quickLaunch)
              PopupMenuItem(
                key: Key('practice-configure-${activity.id}'),
                value: 'configure',
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.tune_rounded),
                  title: Text('저장 설정 변경'),
                ),
              ),
            if (supportsPlaylist && enabled)
              PopupMenuItem(
                key: Key('practice-playlist-${activity.id}'),
                value: 'playlist',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    inPlaylist
                        ? Icons.playlist_remove_rounded
                        : Icons.playlist_add_rounded,
                  ),
                  title: Text(inPlaylist ? '플레이리스트에서 빼기' : '플레이리스트에 담기'),
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
            quickLaunch
                ? Icons.rocket_launch_rounded
                : favorite
                ? Icons.star_rounded
                : Icons.more_horiz_rounded,
            color: favorite || quickLaunch
                ? colors.primary
                : colors.onSurfaceVariant,
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
                    padding: EdgeInsets.all(compact ? 8 : 11),
                    child: compact
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  icon,
                                  const Spacer(),
                                  _MiniBadge(
                                    label: enabled
                                        ? bestRecord != null
                                              ? '최고 ${bestRecord!.bestScore}점'
                                              : launchCount > 0
                                              ? '${activity.badge} · $launchCount회'
                                              : activity.badge
                                        : '사용 불가',
                                    muted: !enabled,
                                  ),
                                  menu,
                                ],
                              ),
                              const SizedBox(height: 4),
                              copy,
                            ],
                          )
                        : Row(
                            children: [
                              icon,
                              const SizedBox(width: 11),
                              Expanded(child: copy),
                              _MiniBadge(
                                label: enabled
                                    ? bestRecord != null
                                          ? _bestRecordLabel(bestRecord!)
                                          : launchCount > 0
                                          ? '$launchCount회'
                                          : activity.badge
                                    : '사용 불가',
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

String _bestRecordLabel(PracticeBestRecord record) {
  final elapsed = record.bestElapsedMs;
  if (elapsed == null) return '최고 ${record.bestScore}점';
  final seconds = (elapsed / 1000).ceil();
  final time = seconds < 60
      ? '$seconds초'
      : '${seconds ~/ 60}분 ${seconds % 60}초';
  return '최고 ${record.bestScore}점 · $time';
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

_PracticeLaunchResult _resolvePracticeLaunch(
  PracticeLaunchPreferences preferences,
  int availableCount,
) {
  final safeAvailable = availableCount.clamp(
    StudyLimits.minSessionItems,
    StudyLimits.maxSessionItems,
  );
  final requested = switch (preferences.length) {
    PracticeSessionLength.fiveItems ||
    PracticeSessionLength.tenItems ||
    PracticeSessionLength.twentyItems => preferences.itemCount,
    PracticeSessionLength.allItems => safeAvailable,
    PracticeSessionLength.threeMinutes => 7,
    PracticeSessionLength.fiveMinutes => 12,
    PracticeSessionLength.tenMinutes => 24,
    PracticeSessionLength.fifteenMinutes => 36,
  };
  final itemLimit = requested.clamp(StudyLimits.minSessionItems, safeAvailable);
  final usesTimeBudget = switch (preferences.length) {
    PracticeSessionLength.threeMinutes ||
    PracticeSessionLength.fiveMinutes ||
    PracticeSessionLength.tenMinutes ||
    PracticeSessionLength.fifteenMinutes => true,
    _ => false,
  };
  final timeBudgetMinutes = switch (preferences.length) {
    PracticeSessionLength.threeMinutes => 3,
    PracticeSessionLength.fiveMinutes => 5,
    PracticeSessionLength.tenMinutes => 10,
    PracticeSessionLength.fifteenMinutes => 15,
    _ => 5,
  };
  return _PracticeLaunchResult(
    itemLimit: itemLimit,
    queuePriority: switch (preferences.queueOrder) {
      PracticeQueueOrder.dueFirst => StudyQueuePriority.dueFirst,
      PracticeQueueOrder.newFirst => StudyQueuePriority.newFirst,
    },
    historyFilter: switch (preferences.historyScope) {
      PracticeHistoryScope.all => StudyHistoryFilter.all,
      PracticeHistoryScope.excludeCorrect => StudyHistoryFilter.excludeCorrect,
      PracticeHistoryScope.wrongOnly => StudyHistoryFilter.wrongOnly,
    },
    lengthMode: usesTimeBudget
        ? StudySessionLengthMode.timeBudget
        : StudySessionLengthMode.itemCount,
    timeBudgetMinutes: timeBudgetMinutes,
    preferences: preferences.copyWith(itemCount: itemLimit),
  );
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
      PracticeSessionLength.fifteenMinutes => 36,
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
      PracticeSessionLength.fifteenMinutes => 36,
    };
    setState(() => _preferences = _preferences.copyWith(length: length));
    _setCount(count);
    setState(() => _preferences = _preferences.copyWith(length: length));
  }

  int get _timeBudgetMinutes => switch (_preferences.length) {
    PracticeSessionLength.threeMinutes => 3,
    PracticeSessionLength.fiveMinutes => 5,
    PracticeSessionLength.tenMinutes => 10,
    PracticeSessionLength.fifteenMinutes => 15,
    _ => 5,
  };

  bool get _usesTimeBudget => switch (_preferences.length) {
    PracticeSessionLength.threeMinutes ||
    PracticeSessionLength.fiveMinutes ||
    PracticeSessionLength.tenMinutes ||
    PracticeSessionLength.fifteenMinutes => true,
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
    final maximumSelectableCount = widget.availableCount.clamp(
      StudyLimits.minSessionItems,
      StudyLimits.maxSessionItems,
    );
    final options = <int>{
      for (final count in const [5, 10, 20, 50, 100, 250, 500, 1000])
        if (count <= maximumSelectableCount) count,
      widget.availableCount < 5 ? widget.availableCount : 5,
      if (widget.availableCount > 5 && widget.availableCount < 10)
        widget.availableCount,
      if (widget.availableCount > 10 && widget.availableCount < 20)
        widget.availableCount,
    }.toList()..sort();
    return options;
  }

  void _resetRules() {
    setState(() {
      _queuePriority = StudyQueuePriority.dueFirst;
      _historyFilter = StudyHistoryFilter.all;
      _preferences = _preferences.copyWith(
        difficulty: PracticeDifficultyPreset.balanced,
        historyScope: PracticeHistoryScope.all,
        queueOrder: PracticeQueueOrder.dueFirst,
        answerDirection: StudyAnswerDirection.mixed,
        gradingStrictness: StudyGradingStrictness.balanced,
        choiceCount: 4,
        recordProgress: true,
        hintsEnabled: true,
        autoAdvance: false,
        soundEnabled: false,
        largeControls: false,
        challengeScoringEnabled: false,
      );
    });
  }

  void _finish() {
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
            StudyHistoryFilter.all => PracticeHistoryScope.all,
            StudyHistoryFilter.excludeCorrect =>
              PracticeHistoryScope.excludeCorrect,
            StudyHistoryFilter.wrongOnly => PracticeHistoryScope.wrongOnly,
          },
          queueOrder: _queuePriority == StudyQueuePriority.dueFirst
              ? PracticeQueueOrder.dueFirst
              : PracticeQueueOrder.newFirst,
        ),
      ),
    );
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.activity.icon,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
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
                    if (widget.availableCount > 0)
                      TextButton.icon(
                        key: const Key('practice-launch-use-current-rules'),
                        onPressed: _finish,
                        icon: const Icon(Icons.bolt_rounded, size: 18),
                        label: const Text('바로 시작'),
                      ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                      '자료실에서 필요한 표현을 추가하거나 설정을 확인해 주세요.',
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
                    label: const Text('자료 추가하기'),
                  ),
                ] else ...[
                  SizedBox(
                    key: const Key('practice-launch-inventory-strip'),
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _LaunchInfoChip(
                          icon: Icons.inventory_2_outlined,
                          label: '전체 ${widget.availableCount}',
                        ),
                        const SizedBox(width: 6),
                        _LaunchInfoChip(
                          icon: Icons.notifications_active_outlined,
                          label: '복습 ${widget.dueCount}',
                        ),
                        const SizedBox(width: 6),
                        _LaunchInfoChip(
                          icon: Icons.fiber_new_rounded,
                          label: '새 자료 ${widget.newCount}',
                        ),
                        const SizedBox(width: 6),
                        _LaunchInfoChip(
                          icon: Icons.check_circle_outline_rounded,
                          label: '학습함 $studiedCount',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '세션 길이',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '시간을 고르거나 문제 수를 직접 정하세요.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    key: const Key('practice-time-options'),
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final option in const [
                        PracticeSessionLength.threeMinutes,
                        PracticeSessionLength.fiveMinutes,
                        PracticeSessionLength.tenMinutes,
                        PracticeSessionLength.fifteenMinutes,
                      ])
                        ChoiceChip(
                          key: Key('practice-time-${option.name}'),
                          selected: _preferences.length == option,
                          avatar: const Icon(Icons.timer_outlined, size: 17),
                          label: Text(switch (option) {
                            PracticeSessionLength.threeMinutes => '3분',
                            PracticeSessionLength.fiveMinutes => '5분 · 추천',
                            PracticeSessionLength.tenMinutes => '10분',
                            _ => '15분',
                          }),
                          onSelected: (_) => _setLength(option),
                        ),
                    ],
                  ),
                  if (_usesTimeBudget) ...[
                    const SizedBox(height: 5),
                    Semantics(
                      key: const Key('practice-time-selected-estimate'),
                      liveRegion: true,
                      label: '학습 시간 $_timeBudgetMinutes분, 예상 $_selectedCount문제',
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '선택 · $_timeBudgetMinutes분 · 예상 $_selectedCount문제',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  SingleChildScrollView(
                    key: const Key('practice-count-options'),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final count in _countOptions) ...[
                          ChoiceChip(
                            key: Key('practice-count-$count'),
                            selected:
                                !_usesTimeBudget && _selectedCount == count,
                            label: Text('$count문제'),
                            onSelected: (_) => _setCount(count),
                          ),
                          const SizedBox(width: 7),
                        ],
                        ChoiceChip(
                          key: const Key('practice-count-all'),
                          selected:
                              _preferences.length ==
                              PracticeSessionLength.allItems,
                          label: Text(
                            widget.availableCount <= StudyLimits.maxSessionItems
                                ? '전체 ${widget.availableCount}개'
                                : '최대 ${StudyLimits.maxSessionItems}개',
                          ),
                          onSelected: (_) =>
                              _setLength(PracticeSessionLength.allItems),
                        ),
                      ],
                    ),
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
                            LengthLimitingTextInputFormatter(
                              StudyLimits.maxSessionItems.toString().length,
                            ),
                          ],
                          decoration: const InputDecoration(
                            isDense: true,
                            helperText:
                                '${StudyLimits.minSessionItems}~${StudyLimits.maxSessionItems}',
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
                  Text('난이도', style: Theme.of(context).textTheme.titleSmall),
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
                  const SizedBox(height: 8),
                  ExpansionTile(
                    key: const Key('practice-advanced-settings'),
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: const Text('고급 설정'),
                    trailing: TextButton(
                      key: const Key('reset-practice-rules'),
                      onPressed: _resetRules,
                      child: const Text('기본값'),
                    ),
                    subtitle: Text(
                      '${_preferences.recordProgress ? '진도 기록' : '자유 연습'} · '
                      '${_preferences.choiceCount}지선다 · '
                      '${_preferences.gradingStrictness.koreanLabel} 채점 · '
                      '${_preferences.hintsEnabled ? '힌트 켬' : '힌트 끔'}',
                    ),
                    children: [
                      KeyedSubtree(
                        key: const Key('practice-advanced-history-and-order'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '학습 기록',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
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
                            Text(
                              '출제 순서',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                for (final priority
                                    in StudyQueuePriority.values)
                                  ChoiceChip(
                                    key: Key(
                                      'practice-priority-${priority.name}',
                                    ),
                                    label: Text(priority.label),
                                    selected: _queuePriority == priority,
                                    onSelected: (_) => setState(() {
                                      _queuePriority = priority;
                                      _preferences = _preferences.copyWith(
                                        queueOrder:
                                            priority ==
                                                StudyQueuePriority.dueFirst
                                            ? PracticeQueueOrder.dueFirst
                                            : PracticeQueueOrder.newFirst,
                                      );
                                    }),
                                  ),
                              ],
                            ),
                            const Divider(height: 20),
                          ],
                        ),
                      ),
                      KeyedSubtree(
                        key: const Key('practice-quick-rules'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
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
                            SwitchListTile.adaptive(
                              key: const Key('practice-challenge-scoring'),
                              contentPadding: EdgeInsets.zero,
                              value: _preferences.challengeScoringEnabled,
                              title: const Text('도전 점수 기록'),
                              subtitle: const Text(
                                '정확도와 완료 시간을 개인 최고 기록에만 저장합니다.',
                              ),
                              onChanged: (value) => setState(
                                () => _preferences = _preferences.copyWith(
                                  challengeScoringEnabled: value,
                                ),
                              ),
                            ),
                            const Divider(height: 20),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('출제 방향'),
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                for (final direction
                                    in StudyAnswerDirection.values)
                                  ChoiceChip(
                                    key: Key(
                                      'practice-direction-${direction.name}',
                                    ),
                                    selected:
                                        _preferences.answerDirection ==
                                        direction,
                                    label: Text(switch (direction) {
                                      StudyAnswerDirection.learningToMeaning =>
                                        '학습어 → 뜻',
                                      StudyAnswerDirection.meaningToLearning =>
                                        '뜻 → 학습어',
                                      StudyAnswerDirection.mixed => '혼합',
                                    }),
                                    onSelected: (_) => setState(
                                      () => _preferences = _preferences
                                          .copyWith(answerDirection: direction),
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
                                    key: Key(
                                      'practice-grading-${strictness.name}',
                                    ),
                                    selected:
                                        _preferences.gradingStrictness ==
                                        strictness,
                                    label: Text(strictness.koreanLabel),
                                    onSelected: (_) => setState(
                                      () =>
                                          _preferences = _preferences.copyWith(
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
                              runSpacing: 7,
                              children: [
                                for (final count in const [2, 4, 6])
                                  ChoiceChip(
                                    key: Key('practice-choice-count-$count'),
                                    selected: _preferences.choiceCount == count,
                                    label: Text('$count개'),
                                    onSelected: (_) => setState(
                                      () => _preferences = _preferences
                                          .copyWith(choiceCount: count),
                                    ),
                                  ),
                              ],
                            ),
                            SwitchListTile.adaptive(
                              key: const Key('practice-time-budget-toggle'),
                              contentPadding: EdgeInsets.zero,
                              value: _usesTimeBudget,
                              title: const Text('시간으로 정하기'),
                              subtitle: const Text('문제 수 대신 학습 시간을 먼저 정해요.'),
                              onChanged: (value) {
                                if (value) {
                                  _setLength(PracticeSessionLength.fiveMinutes);
                                } else {
                                  _setCount(_selectedCount);
                                }
                              },
                            ),
                            SwitchListTile.adaptive(
                              key: const Key('practice-hints-toggle'),
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
                              key: const Key('practice-auto-advance-toggle'),
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
                              key: const Key('practice-sound-toggle'),
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
                              key: const Key('practice-large-controls-toggle'),
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    key: const Key('practice-session-estimate'),
                    liveRegion: true,
                    label: _usesTimeBudget
                        ? '$_timeBudgetMinutes분, 예상 $_selectedCount문제, 즉시 피드백'
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
                              '${_usesTimeBudget ? '$_timeBudgetMinutes분 · 약 $_selectedCount문제' : '$_selectedCount문제 · 약 $estimatedMinutes분'} · '
                              '문제마다 바로 채점 · '
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
                    onPressed: _finish,
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
  const _CountBadge({required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 36 : 44),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
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
                  isEmpty ? '학습할 자료가 없어요' : '일부 게임을 시작할 자료가 부족해요',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  isEmpty
                      ? '첫 단어나 문장을 추가하면 바로 학습할 수 있어요.'
                      : '사용할 수 없는 게임에서 필요한 자료를 확인하고 표현을 추가해 주세요.',
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
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.route,
    required this.badge,
  });

  final String id;
  final IconData icon;
  final String title;
  final String description;
  final String route;
  final String badge;
}
