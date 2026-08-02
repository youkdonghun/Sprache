import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/learning_item.dart';
import '../domain/learning_item_codec.dart';
import '../domain/learning_group.dart';
import '../domain/library_search.dart';
import '../domain/content_management.dart';
import '../domain/duplicate_repair.dart';
import '../domain/import_distribution.dart';
import '../domain/progress.dart';
import '../domain/smart_collection.dart';
import '../domain/study_limits.dart';
import '../domain/study_preferences.dart';
import '../state/app_state.dart';
import '../state/connection_state.dart';
import '../state/local_storage_state.dart';
import '../theme/app_theme.dart';
import '../widgets/content_selection_action_bar.dart';
import '../widgets/learning_data_flow_card.dart';
import '../widgets/quick_content_sheet.dart';

enum _LibraryFilter { all, favorites, word, sentence, weak, wrong }

enum _AddContentAction { quickWord, quickSentence, fullEditor, importFile }

String _librarySyncLabel(AppState state, ConnectionState connection) {
  if (!state.driveConnected) return '이 기기에 저장';
  if (connection.phase == ConnectionPhase.syncing) return 'Drive 동기화 중';
  if (connection.phase == ConnectionPhase.failed) {
    return '로컬 저장됨 · Drive 재시도 필요';
  }
  if (state.pendingSync != null) return '로컬 저장됨 · Drive 반영 대기';
  final syncedAt = connection.lastSyncedAt?.toLocal();
  if (syncedAt == null) return 'Drive 첫 동기화 대기';
  final hour = syncedAt.hour.toString().padLeft(2, '0');
  final minute = syncedAt.minute.toString().padLeft(2, '0');
  return 'Drive $hour:$minute 동기화';
}

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({
    this.initialSubjectId,
    this.initialGroup,
    this.initialQuery,
    super.key,
  });

  final String? initialSubjectId;
  final String? initialGroup;
  final String? initialQuery;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  static const _searchDebounceDuration = Duration(milliseconds: 200);

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _workspaceScrollController = ScrollController();
  Timer? _searchDebounce;
  late String _activeSubjectId;
  var _query = '';
  var _filter = _LibraryFilter.all;
  var _advancedCriteria = const LibrarySearchCriteria();
  String? _groupFilter;
  var _groupSelectionMode = false;
  final _selectedForGroup = <String>{};

  @override
  void initState() {
    super.initState();
    _activeSubjectId = ref.read(appControllerProvider).activeSubjectId;
    _groupFilter = _normalizedRouteValue(widget.initialGroup);
    final initialQuery = _normalizedRouteValue(widget.initialQuery);
    if (initialQuery != null) {
      _searchController.text = initialQuery;
      _query = initialQuery;
    }
    _selectRouteSubject();
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubjectId != widget.initialSubjectId) {
      _selectRouteSubject();
    }
    if (oldWidget.initialGroup != widget.initialGroup) {
      _groupFilter = _normalizedRouteValue(widget.initialGroup);
      _selectedForGroup.clear();
      _groupSelectionMode = false;
    }
    if (oldWidget.initialQuery != widget.initialQuery) {
      final query = _normalizedRouteValue(widget.initialQuery) ?? '';
      _searchDebounce?.cancel();
      _searchController.text = query;
      _query = query;
    }
  }

  String? _normalizedRouteValue(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  void _selectRouteSubject() {
    final subjectId = _normalizedRouteValue(widget.initialSubjectId);
    if (subjectId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(appControllerProvider.notifier).selectSubject(subjectId);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _workspaceScrollController.dispose();
    super.dispose();
  }

  void _focusSearch() {
    _searchFocus.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    if (_query.isNotEmpty || _searchController.text.isNotEmpty) {
      _searchController.clear();
      setState(() => _query = '');
      _searchFocus.requestFocus();
      return;
    }
    _searchFocus.unfocus();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      if (!mounted) return;
      final query = value.trim();
      if (_query == query) return;
      setState(() => _query = query);
      if (query.isNotEmpty) _revealSearchResults();
    });
  }

  void _revealSearchResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_workspaceScrollController.hasClients) return;
      final target = _workspaceScrollController.position.maxScrollExtent;
      if (target <= 0) return;
      _workspaceScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _handleActiveSubjectChange(String subjectId) {
    if (_activeSubjectId == subjectId) return;
    final routeSubjectId = _normalizedRouteValue(widget.initialSubjectId);
    final nextGroupFilter = routeSubjectId == subjectId
        ? _normalizedRouteValue(widget.initialGroup)
        : null;
    final nextQuery = routeSubjectId == subjectId
        ? _normalizedRouteValue(widget.initialQuery) ?? ''
        : '';
    final clearedVisibleState =
        _searchController.text.isNotEmpty ||
        _query.isNotEmpty ||
        _filter != _LibraryFilter.all ||
        _advancedCriteria.hasFacets ||
        _advancedCriteria.sortOrder != LibrarySortOrder.catalog ||
        _groupFilter != nextGroupFilter ||
        _groupSelectionMode ||
        _selectedForGroup.isNotEmpty;

    _searchDebounce?.cancel();
    setState(() {
      _activeSubjectId = subjectId;
      _searchController.text = nextQuery;
      _query = nextQuery;
      _filter = _LibraryFilter.all;
      _advancedCriteria = const LibrarySearchCriteria();
      _groupFilter = nextGroupFilter;
      _groupSelectionMode = false;
      _selectedForGroup.clear();
    });

    if (!clearedVisibleState) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('학습 주제가 바뀌어 검색·필터·선택을 초기화했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    ref.listen<String>(
      appControllerProvider.select((value) => value.activeSubjectId),
      (_, next) => _handleActiveSubjectChange(next),
    );
    final connection = ref.watch(connectionControllerProvider);
    final localStorage = ref.watch(localStorageControllerProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final mobile = screenWidth < 600;
    final narrow = screenWidth < 360;
    final controller = ref.read(appControllerProvider.notifier);
    final activeSubject = controller.activeSubject;
    final items = controller.courseItems;
    final groups = controller.availableLearningGroups;
    final weakItems = controller.weakItems;
    final recentWrongItems = controller.recentWrongItems;
    final smartCollections = controller.smartCollections;
    final trashEntries = controller.listTrash(subjectId: activeSubject.id);
    final selectedGroupSummary = _groupFilter == null
        ? null
        : controller.learningGroupSummary(_groupFilter!);
    final customItemIds = state.customItems.map((item) => item.id).toSet();
    final localCopyCount = state.customItems
        .where((item) => item.effectiveSubjectId == activeSubject.id)
        .length;
    final basicFiltered = items.where((item) {
      final progress = state.progress[item.id];
      final matchesFilter = switch (_filter) {
        _LibraryFilter.all => true,
        _LibraryFilter.favorites => state.preferences.isFavorite(item.id),
        _LibraryFilter.word => item.kind == LearningItemKind.word,
        _LibraryFilter.sentence => item.kind == LearningItemKind.sentence,
        _LibraryFilter.weak =>
          progress != null && progress.attempts > 0 && progress.accuracy < 0.7,
        _LibraryFilter.wrong => progress?.lastResult == ReviewRating.again,
      };
      if (!matchesFilter) return false;
      if (_groupFilter != null &&
          !learningGroupsOf(item).contains(_groupFilter)) {
        return false;
      }
      return true;
    });
    final filtered = filterAndSortLibraryItems(
      items: basicFiltered,
      progressById: state.progress,
      criteria: _advancedCriteria.copyWith(query: _query),
      now: DateTime.now().toUtc(),
      excludedItemIds: state.preferences.excludedItemIds,
    );
    final availablePartsOfSpeech = items
        .map((item) => item.partOfSpeech)
        .whereType<PartOfSpeech>()
        .toSet();
    final availableTags = items
        .expand((item) => item.tags)
        .where(
          (tag) =>
              !tag.startsWith(learningGroupTagPrefix) &&
              !tag.startsWith(importDistributionTagPrefix) &&
              !tag.startsWith('unit-'),
        )
        .toSet();
    final availableSources = items.map((item) => item.source.name).toSet();
    final duplicateCatalog = controller.duplicateRepairCatalog(
      subjectId: activeSubject.id,
    );
    final filteredIds = filtered.map((item) => item.id).toSet();
    final hiddenSelectedCount =
        _selectedForGroup.length -
        _selectedForGroup.intersection(filteredIds).length;
    final studiedCount = items
        .where((item) => state.progress.containsKey(item.id))
        .length;
    final favoriteCount = items
        .where((item) => state.preferences.isFavorite(item.id))
        .length;

    final searchAndFilters = LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final search = TextField(
          key: const Key('library-search-field'),
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: mobile
                ? '단어, 뜻, 읽기, 품사 검색'
                : '단어, 뜻, 읽기, 품사, 출처 검색 · Ctrl+F',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '검색어 지우기',
                  ),
          ),
        );
        final filters = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: '전체',
                selected: _filter == _LibraryFilter.all,
                onSelected: () => setState(() => _filter = _LibraryFilter.all),
              ),
              const SizedBox(width: 7),
              _FilterChip(
                label: '저장됨',
                selected: _filter == _LibraryFilter.favorites,
                onSelected: () =>
                    setState(() => _filter = _LibraryFilter.favorites),
              ),
              const SizedBox(width: 7),
              _FilterChip(
                label: '단어',
                selected: _filter == _LibraryFilter.word,
                onSelected: () => setState(() => _filter = _LibraryFilter.word),
              ),
              const SizedBox(width: 7),
              _FilterChip(
                label: '문장',
                selected: _filter == _LibraryFilter.sentence,
                onSelected: () =>
                    setState(() => _filter = _LibraryFilter.sentence),
              ),
              const SizedBox(width: 7),
              Badge(
                isLabelVisible: _advancedCriteria.facetCount > 0,
                label: Text('${_advancedCriteria.facetCount}'),
                child: OutlinedButton.icon(
                  key: const Key('library-advanced-filter-button'),
                  onPressed: () => _openAdvancedFilters(
                    partsOfSpeech: availablePartsOfSpeech,
                    tags: availableTags,
                    sources: availableSources,
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('상세 필터'),
                ),
              ),
            ],
          ),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [search, const SizedBox(height: 8), filters],
          );
        }
        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 12),
            filters,
          ],
        );
      },
    );

    final controls = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LibraryHeader(
          subjectName: activeSubject.name,
          subjectSymbol: activeSubject.symbol,
          generalTopic: !activeSubject.isLanguage,
          totalCount: items.length,
          studiedCount: studiedCount,
          favoriteCount: favoriteCount,
          trashCount: trashEntries.length,
          onAdd: _openAddMenu,
          onTrash: _openTrash,
        ),
        SizedBox(
          height: narrow
              ? 8
              : mobile
              ? 10
              : 16,
        ),
        if (!mobile ||
            items.isEmpty ||
            (!state.driveConnected && !localStorage.configured)) ...[
          LearningDataFlowCard(
            totalCount: items.length,
            localCopyCount: localCopyCount,
            groupCount: groups.length,
            driveConnected: state.driveConnected,
            currentStep: localCopyCount == 0
                ? LearningDataStep.add
                : groups.isEmpty
                ? LearningDataStep.organize
                : LearningDataStep.learn,
            onAdd: _openAddMenu,
            onOrganize: () => context.go('/library/groups'),
            onLearn: () => context.go('/learn'),
            syncLabel: _librarySyncLabel(state, connection),
            syncBusy: connection.busy,
            onSync: state.driveConnected
                ? () => unawaited(
                    ref
                        .read(connectionControllerProvider.notifier)
                        .syncOrRestore(manual: true),
                  )
                : null,
          ),
          SizedBox(
            height: narrow
                ? 8
                : mobile
                ? 10
                : 16,
          ),
        ],
        searchAndFilters,
        if (_query.isNotEmpty ||
            _filter != _LibraryFilter.all ||
            _groupFilter != null ||
            _advancedCriteria.hasFacets ||
            _advancedCriteria.sortOrder != LibrarySortOrder.catalog) ...[
          const SizedBox(height: 8),
          _ActiveLibraryFilters(
            query: _query,
            filter: _filter,
            group: _groupFilter,
            advancedCriteria: _advancedCriteria,
            resultCount: filtered.length,
            onClear: () {
              _searchDebounce?.cancel();
              _searchController.clear();
              setState(() {
                _query = '';
                _filter = _LibraryFilter.all;
                _groupFilter = null;
                _advancedCriteria = const LibrarySearchCriteria();
              });
            },
          ),
          if (filtered.isNotEmpty) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('study-current-filter-results'),
                onPressed: () => _startFilteredResults(filtered),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('이 결과 ${filtered.length}개 학습'),
              ),
            ),
          ],
        ],
        if (_groupFilter == null) ...[
          const SizedBox(height: 8),
          _SmartCollectionsBar(
            weakCount: weakItems.length,
            wrongCount: recentWrongItems.length,
            selectedFilter: _filter,
            onSelectWeak: () => setState(() => _filter = _LibraryFilter.weak),
            onSelectWrong: () => setState(() => _filter = _LibraryFilter.wrong),
            onStart:
                _filter == _LibraryFilter.weak ||
                    _filter == _LibraryFilter.wrong
                ? _startSmartCollection
                : null,
          ),
        ],
        if (smartCollections.isNotEmpty ||
            _query.isNotEmpty ||
            _groupFilter != null ||
            _advancedCriteria.hasFacets ||
            _advancedCriteria.sortOrder != LibrarySortOrder.catalog ||
            _filter == _LibraryFilter.word ||
            _filter == _LibraryFilter.sentence) ...[
          const SizedBox(height: 8),
          _SavedSmartCollectionsBar(
            collections: smartCollections,
            itemCountFor: (collection) =>
                controller.itemsForSmartCollection(collection).length,
            canSaveCurrent:
                _query.isNotEmpty ||
                _groupFilter != null ||
                _advancedCriteria.hasFacets ||
                _advancedCriteria.sortOrder != LibrarySortOrder.catalog ||
                _filter == _LibraryFilter.word ||
                _filter == _LibraryFilter.sentence,
            onSaveCurrent: _saveCurrentSmartCollection,
            onSelect: _applySmartCollection,
            onDelete: _deleteSmartCollection,
            onTogglePin: _toggleSmartCollectionPin,
          ),
        ],
        if (!duplicateCatalog.isEmpty) ...[
          const SizedBox(height: 8),
          _DuplicateRepairCard(
            exactGroupCount: duplicateCatalog.exactGroups.length,
            suggestionCount: duplicateCatalog.similarSuggestions.length,
            itemCount: duplicateCatalog.exactGroups.fold(
              0,
              (count, group) => count + group.items.length,
            ),
            onOpen: () => _openDuplicateRepair(duplicateCatalog),
          ),
        ],
        const SizedBox(height: 8),
        _GroupToolbar(
          groups: groups,
          summaries: controller.learningGroupSummaries,
          selectedGroup: _groupFilter,
          summary: selectedGroupSummary,
          selectionMode: _groupSelectionMode,
          onGroupChanged: (group) => setState(() {
            _groupFilter = group;
            if (!_groupSelectionMode) {
              _selectedForGroup.clear();
            }
          }),
          onToggleSelectionMode: () => setState(() {
            _groupSelectionMode = !_groupSelectionMode;
            if (!_groupSelectionMode) {
              _selectedForGroup.clear();
            }
          }),
          onOpenOrganizer: () => context.go('/library/groups'),
          onMemorize: _groupFilter == null
              ? null
              : () => _startGroup(_groupFilter!, memorize: true),
          onQuiz: _groupFilter == null
              ? null
              : () => _startGroup(_groupFilter!, memorize: false),
          onRename: _groupFilter == null ? null : _renameSelectedGroup,
          onDelete: _groupFilter == null ? null : _deleteSelectedGroup,
        ),
        if (_groupSelectionMode) ...[
          const SizedBox(height: 8),
          if (_selectedForGroup.isEmpty)
            Container(
              key: const Key('library-selection-hint'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: const Text(
                '목록에서 정리하거나 학습할 자료를 선택하세요.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ContentSelectionActionBar(
              selectedCount: _selectedForGroup.length,
              hiddenSelectedCount: hiddenSelectedCount,
              keyPrefix: 'library-selection',
              onAddToGroup: () => _organizeGroup(copy: true),
              onMoveToGroup: () => _organizeGroup(copy: false),
              onMemorize: () => _startSelected(memorize: true),
              onQuiz: () => _startSelected(memorize: false),
              onMoveToSubject: _moveSelectedToSubject,
              onToggleFavorite: _toggleSelectedFavorites,
              onEditTags: _editSelectedTags,
              onExport: _exportSelected,
              onToggleVisibility: _toggleSelectedVisibility,
              onDelete: _deleteSelected,
              onClear: () => setState(_selectedForGroup.clear),
            ),
        ],
      ],
    );

    final results = Card(
      child: filtered.isEmpty
          ? _EmptyLibrary(query: _query, filter: _filter)
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = filtered[index];
                final progress = state.progress[item.id];
                return _LibraryRow(
                  item: item,
                  progress: progress,
                  selected: state.preferences.includes(item),
                  favorite: state.preferences.isFavorite(item.id),
                  isCustom: customItemIds.contains(item.id),
                  onToggle: () => controller.toggleItemSelection(item.id),
                  onFavorite: () => controller.toggleFavorite(item.id),
                  onEdit: () => context.go('/library/edit/${item.id}'),
                  onCorrect: () => _openCorrection(item),
                  onDelete: () => _confirmDelete(context, item),
                  selectionMode: _groupSelectionMode,
                  bulkSelected: _selectedForGroup.contains(item.id),
                  onBulkSelect: () => setState(() {
                    if (!_selectedForGroup.add(item.id)) {
                      _selectedForGroup.remove(item.id);
                    }
                  }),
                  onTap: _groupSelectionMode
                      ? () => setState(() {
                          if (!_selectedForGroup.add(item.id)) {
                            _selectedForGroup.remove(item.id);
                          }
                        })
                      : () => _showDetails(
                          context,
                          item: item,
                          progress: progress,
                        ),
                );
              },
            ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _focusSearch,
        const SingleActivator(LogicalKeyboardKey.escape): _clearSearch,
      },
      child: Focus(
        autofocus: true,
        child: SafeArea(
          child: _LibraryWorkspace(
            mobile: mobile,
            narrow: narrow,
            scrollController: _workspaceScrollController,
            controls: controls,
            results: results,
          ),
        ),
      ),
    );
  }

  Future<void> _saveCurrentSmartCollection() async {
    final controller = ref.read(appControllerProvider.notifier);
    final rawName = await showDialog<String>(
      context: context,
      builder: (context) => const _LearningGroupNameDialog(
        title: '현재 필터를 스마트 컬렉션으로 저장',
        initialValue: '',
        confirmLabel: '저장',
        hintText: '예: 여행 명사 복습',
        helperText: '자료가 바뀌면 조건에 맞는 목록도 자동으로 갱신됩니다.',
      ),
    );
    final name = rawName?.trim() ?? '';
    if (name.isEmpty || !mounted) return;
    final kind = switch (_filter) {
      _LibraryFilter.word => const {LearningItemKind.word},
      _LibraryFilter.sentence => const {LearningItemKind.sentence},
      _ => _advancedCriteria.kinds,
    };
    final selectedSourceNames = _advancedCriteria.sources;
    final sourceIds = controller.courseItems
        .where((item) => selectedSourceNames.contains(item.source.name))
        .map((item) => item.source.sourceId ?? item.source.name)
        .toSet();
    final now = DateTime.now().toUtc();
    final definition = _advancedCriteria
        .copyWith(query: _query, kinds: kind, sources: sourceIds)
        .toSmartCollection(
          id: 'smart-${now.microsecondsSinceEpoch}',
          subjectId: controller.activeSubject.id,
          name: name,
          updatedAt: now,
        )
        .copyWith(
          groupIds: _groupFilter == null
              ? const {}
              : {
                  learningGroupDefinitionId(
                    controller.activeSubject.id,
                    _groupFilter!,
                  ),
                },
        );
    await controller.upsertSmartCollection(definition);
    if (mounted) _showLibraryMessage('“$name” 스마트 컬렉션을 저장했습니다.');
  }

  Future<void> _openDuplicateRepair(DuplicateRepairCatalog catalog) async {
    final state = ref.read(appControllerProvider);
    final request = await showModalBottomSheet<DuplicateMergeRequest>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _DuplicateRepairSheet(catalog: catalog, progress: state.progress),
    );
    if (request == null || !mounted) return;
    final controller = ref.read(appControllerProvider.notifier);
    late final DuplicateRepairResult result;
    try {
      result = await controller.mergeDuplicateCustomItems(request);
    } on Object {
      if (mounted) {
        _showLibraryMessage('자료가 변경되어 합치지 못했습니다. 목록을 다시 확인해 주세요.');
      }
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '“${result.canonicalItem.text}” 자료를 하나로 정리하고 '
          '학습 기록 ${result.removedItemIds.length}건을 대표 자료에 연결했습니다.',
        ),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () =>
              unawaited(_undoDuplicateRepair(controller, result.undoToken)),
        ),
      ),
    );
  }

  Future<void> _undoDuplicateRepair(
    AppController controller,
    DuplicateRepairUndoToken token,
  ) async {
    final result = await controller.undoDuplicateRepair(token);
    if (!mounted) return;
    _showLibraryMessage(switch (result.status) {
      DuplicateRepairUndoStatus.restored => '중복 자료와 학습 기록을 모두 복원했습니다.',
      DuplicateRepairUndoStatus.conflict =>
        '합친 뒤 자료나 학습 기록이 변경되어 자동으로 되돌릴 수 없습니다.',
      DuplicateRepairUndoStatus.alreadyUndone => '이미 되돌린 중복 수선입니다.',
    });
  }

  void _applySmartCollection(SmartCollectionDefinition collection) {
    final controller = ref.read(appControllerProvider.notifier);
    final sourceNames = controller.courseItems
        .where(
          (item) => collection.sourceIds.contains(
            item.source.sourceId ?? item.source.name,
          ),
        )
        .map((item) => item.source.name)
        .toSet();
    final criteria = LibrarySearchCriteriaSmartCollection.fromSmartCollection(
      collection,
    ).copyWith(sources: sourceNames, kinds: const {});
    String? group;
    for (final candidate in controller.availableLearningGroups) {
      if (collection.groupIds.contains(
        learningGroupDefinitionId(collection.subjectId, candidate),
      )) {
        group = candidate;
        break;
      }
    }
    final nextFilter = collection.kinds.length == 1
        ? collection.kinds.single == LearningItemKind.word
              ? _LibraryFilter.word
              : _LibraryFilter.sentence
        : _LibraryFilter.all;
    _searchDebounce?.cancel();
    _searchController.text = collection.query;
    setState(() {
      _query = collection.query;
      _filter = nextFilter;
      _groupFilter = group;
      _advancedCriteria = criteria;
      _selectedForGroup.clear();
      _groupSelectionMode = false;
    });
    if (collection.query.trim().isNotEmpty) _revealSearchResults();
  }

  Future<void> _deleteSmartCollection(
    SmartCollectionDefinition collection,
  ) async {
    await ref
        .read(appControllerProvider.notifier)
        .deleteSmartCollection(collection.id);
    if (mounted) _showLibraryMessage('“${collection.name}” 컬렉션을 삭제했습니다.');
  }

  Future<void> _toggleSmartCollectionPin(
    SmartCollectionDefinition collection,
  ) async {
    await ref
        .read(appControllerProvider.notifier)
        .upsertSmartCollection(collection.copyWith(pinned: !collection.pinned));
  }

  Future<void> _openTrash() async {
    final controller = ref.read(appControllerProvider.notifier);
    final entries = controller.listTrash(
      subjectId: controller.activeSubject.id,
    );
    if (entries.isEmpty) {
      _showLibraryMessage('이 주제의 휴지통이 비어 있습니다.');
      return;
    }
    final action = await showModalBottomSheet<_TrashSheetAction>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _TrashSheet(entries: entries),
    );
    if (action == null || !mounted) return;
    switch (action.type) {
      case _TrashActionType.restore:
        final restored = await controller.restoreTrashEntry(action.entryId!);
        if (mounted) _showLibraryMessage('$restored개 자료를 복원했습니다.');
      case _TrashActionType.restoreAll:
        var restored = 0;
        for (final entry in entries) {
          restored += await controller.restoreTrashEntry(entry.entryId);
        }
        if (mounted) _showLibraryMessage('$restored개 자료를 복원했습니다.');
      case _TrashActionType.empty:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('휴지통 비우기'),
            content: const Text(
              '모든 학습 주제의 휴지통 자료를 영구 삭제합니다. 이 작업은 되돌릴 수 없습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                key: const Key('confirm-empty-library-trash'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('전체 영구 삭제'),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        await controller.emptyTrash();
        if (mounted) _showLibraryMessage('휴지통을 비웠습니다.');
    }
  }

  Future<void> _openCorrection(LearningItem item) async {
    final controller = ref.read(appControllerProvider.notifier);
    final current = controller.contentCorrectionFor(item.id);
    final correction = await showDialog<ContentCorrection>(
      context: context,
      builder: (context) =>
          _ContentCorrectionDialog(item: item, current: current),
    );
    if (correction == null || !mounted) return;
    await controller.upsertContentCorrection(correction);
    if (mounted) {
      _showLibraryMessage('원본은 유지하고 이 기기의 교정 메모를 저장했습니다.');
    }
  }

  Future<void> _openAdvancedFilters({
    required Set<PartOfSpeech> partsOfSpeech,
    required Set<String> tags,
    required Set<String> sources,
  }) async {
    final result = await showModalBottomSheet<LibrarySearchCriteria>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AdvancedLibraryFiltersSheet(
        initialValue: _advancedCriteria,
        partsOfSpeech: partsOfSpeech,
        tags: tags,
        sources: sources,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _advancedCriteria = result);
  }

  void _startFilteredResults(List<LearningItem> items) {
    if (items.isEmpty) return;
    final ids = items
        .take(StudyLimits.maxSessionItems)
        .map((item) => item.id)
        .toSet();
    final controller = ref.read(appControllerProvider.notifier);
    final current = ref.read(appControllerProvider).preferences.sessionPlan;
    controller.updateSessionPlan(
      current.copyWith(
        title: _query.isEmpty ? '필터 결과 학습' : '“$_query” 검색 결과 학습',
        mode: StudyMode.mixed,
        deck: StudyDeckScope.selected,
        difficulty: StudyDifficulty.all,
        tags: {},
        levels: {},
        selectedItemIds: ids,
        includeWords: true,
        includeSentences: true,
        itemLimit: ids.length.clamp(
          StudyLimits.minSessionItems,
          StudyLimits.maxSessionItems,
        ),
        scheduledAt: null,
      ),
    );
    context.push('/session-builder');
  }

  List<LearningItem> _selectedItems() {
    final selected = _selectedForGroup;
    return ref
        .read(appControllerProvider.notifier)
        .courseItems
        .where((item) => selected.contains(item.id))
        .toList(growable: false);
  }

  Future<void> _toggleSelectedFavorites() async {
    final items = _selectedItems();
    if (items.isEmpty) return;
    final controller = ref.read(appControllerProvider.notifier);
    final preferences = ref.read(appControllerProvider).preferences;
    final makeFavorite = items.any((item) => !preferences.isFavorite(item.id));
    for (final item in items) {
      final favorite = ref
          .read(appControllerProvider)
          .preferences
          .isFavorite(item.id);
      if (favorite != makeFavorite) controller.toggleFavorite(item.id);
    }
    _showLibraryMessage(
      makeFavorite
          ? '${items.length}개 자료를 저장한 표현에 추가했습니다.'
          : '${items.length}개 자료의 저장 표시를 해제했습니다.',
    );
  }

  Future<void> _toggleSelectedVisibility() async {
    final items = _selectedItems();
    if (items.isEmpty) return;
    final controller = ref.read(appControllerProvider.notifier);
    final preferences = ref.read(appControllerProvider).preferences;
    final include = items.every((item) => !preferences.includes(item));
    for (final item in items) {
      final currentlyIncluded = ref
          .read(appControllerProvider)
          .preferences
          .includes(item);
      if (currentlyIncluded != include) controller.toggleItemSelection(item.id);
    }
    _showLibraryMessage(
      include
          ? '${items.length}개 자료를 학습에 다시 포함했습니다.'
          : '${items.length}개 자료를 학습에서 잠시 제외했습니다.',
    );
  }

  Future<void> _editSelectedTags() async {
    final allSelected = _selectedItems();
    final customIds = ref
        .read(appControllerProvider)
        .customItems
        .map((item) => item.id)
        .toSet();
    final items = allSelected
        .where((item) => customIds.contains(item.id))
        .toList(growable: false);
    if (items.isEmpty) {
      _showLibraryMessage('태그는 내가 추가한 자료에서만 일괄 변경할 수 있습니다.');
      return;
    }
    final edit = await showDialog<_BulkTagEdit>(
      context: context,
      builder: (context) => const _BulkTagDialog(),
    );
    if (edit == null || !mounted) return;
    final safeTags = edit.tags
        .where(
          (tag) =>
              tag.runes.length <= 40 &&
              !tag.startsWith(learningGroupTagPrefix) &&
              !tag.startsWith(importDistributionTagPrefix) &&
              !tag.startsWith('unit-'),
        )
        .toSet();
    if (safeTags.isEmpty) {
      _showLibraryMessage('추가하거나 제거할 일반 태그를 입력해 주세요.');
      return;
    }
    final controller = ref.read(appControllerProvider.notifier);
    for (final item in items) {
      final nextTags = edit.remove
          ? item.tags.where((tag) => !safeTags.contains(tag)).toList()
          : <String>{
              ...item.tags,
              ...safeTags,
            }.take(24).toList(growable: false);
      await controller.upsertCustomItem(item.copyWith(tags: nextTags));
    }
    if (!mounted) return;
    _showLibraryMessage(
      '${items.length}개 사용자 자료에서 태그를 ${edit.remove ? '제거' : '추가'}했습니다.'
      '${items.length == allSelected.length ? '' : ' 기본 언어팩은 변경하지 않았습니다.'}',
    );
  }

  Future<void> _exportSelected() async {
    final items = _selectedItems();
    if (items.isEmpty) return;
    final content = const JsonEncoder.withIndent('  ').convert({
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'items': [
        for (final item in items) const LearningItemCodec().toJson(item),
      ],
    });
    final now = DateTime.now();
    final date =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '선택 자료 내보내기',
        fileName: 'Sprache-selected-$date.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
      if (path != null && mounted) {
        _showLibraryMessage('${items.length}개 자료를 내보냈습니다.');
      }
    } catch (_) {
      if (mounted) {
        _showLibraryMessage('내보내지 못했습니다. 저장 위치 권한을 확인해 주세요.');
      }
    }
  }

  Future<void> _deleteSelected() async {
    final state = ref.read(appControllerProvider);
    final customIds = state.customItems
        .where((item) => _selectedForGroup.contains(item.id))
        .map((item) => item.id)
        .toSet();
    if (customIds.isEmpty) {
      _showLibraryMessage('삭제할 수 있는 사용자 자료가 선택되지 않았습니다.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('선택한 사용자 자료 삭제'),
        content: Text(
          '${customIds.length}개 자료를 휴지통으로 이동합니다.\n'
          '기본 언어팩과 학습 통계는 삭제하지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('confirm-bulk-delete-content'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final controller = ref.read(appControllerProvider.notifier);
    final batch = await controller.trashCustomItems(customIds);
    if (!mounted) return;
    setState(() {
      _selectedForGroup.removeAll(customIds);
      if (_selectedForGroup.isEmpty) _groupSelectionMode = false;
    });
    _showDeleteUndo(batch);
  }

  void _showDeleteUndo(
    TrashBatch batch, {
    String? message,
    Future<void> Function()? onUndo,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message ?? '${batch.entries.length}개 사용자 자료를 휴지통으로 옮겼습니다.',
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: '되돌리기',
          onPressed: () => unawaited(onUndo?.call() ?? _restoreDeleted(batch)),
        ),
      ),
    );
  }

  Future<void> _restoreDeleted(TrashBatch batch) async {
    final restored = await ref
        .read(appControllerProvider.notifier)
        .restoreTrashBatch(batch.id);
    if (mounted) {
      _showLibraryMessage('$restored개 자료를 복원했습니다.');
    }
  }

  Future<void> _openAddMenu() async {
    final action = await showModalBottomSheet<_AddContentAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _AddContentMenu(),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _AddContentAction.quickWord:
        await _openQuickContent(LearningItemKind.word);
      case _AddContentAction.quickSentence:
        await _openQuickContent(LearningItemKind.sentence);
      case _AddContentAction.fullEditor:
        context.go('/library/new');
      case _AddContentAction.importFile:
        context.go('/import');
    }
  }

  Future<void> _openQuickContent(LearningItemKind kind) async {
    final result = await showQuickContentSheet(
      context: context,
      initialKind: kind,
    );
    if (result == null || !mounted) return;
    final mergedMessage = result.addedMeaningCount > 0
        ? '기존 표현에 새 뜻 ${result.addedMeaningCount}개를 추가했습니다.'
        : '같은 표현과 뜻이 이미 있어 중복 저장하지 않았습니다.';
    final message = result.mergedWithExisting
        ? mergedMessage
        : '“${result.item.text}” 자료를 저장했습니다.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: '실행 취소',
          onPressed: () => unawaited(_undoQuickContent(result)),
        ),
      ),
    );
    if (result.studyNow) {
      final controller = ref.read(appControllerProvider.notifier);
      final current = ref.read(appControllerProvider).preferences.sessionPlan;
      controller.updateSessionPlan(
        current.copyWith(
          title: '방금 등록한 자료 학습',
          mode: StudyMode.mixed,
          deck: StudyDeckScope.selected,
          difficulty: StudyDifficulty.all,
          tags: {},
          levels: {},
          selectedItemIds: {result.item.id},
          includeWords: result.item.kind == LearningItemKind.word,
          includeSentences: result.item.kind == LearningItemKind.sentence,
          itemLimit: StudyLimits.minSessionItems,
          scheduledAt: null,
        ),
      );
      context.push('/session-builder');
      return;
    }
    final nextAction = await showModalBottomSheet<_SavedNextAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _SavedContentActions(message: message),
    );
    if (!mounted) return;
    switch (nextAction) {
      case _SavedNextAction.addMore:
        await _openQuickContent(kind);
      case _SavedNextAction.organize:
        context.go('/library/groups');
      case _SavedNextAction.learn:
        context.go('/learn');
      case null:
        return;
    }
  }

  Future<void> _undoQuickContent(QuickContentSaveResult result) async {
    final controller = ref.read(appControllerProvider.notifier);
    final status = await controller.undoQuickContentSave(result.undoToken);
    if (!mounted) return;
    if (status == QuickContentUndoStatus.restored &&
        result.favoriteAdded &&
        ref
            .read(appControllerProvider)
            .preferences
            .isFavorite(result.item.id)) {
      controller.toggleFavorite(result.item.id);
    }
    final message = switch (status) {
      QuickContentUndoStatus.restored => '마지막 저장을 되돌렸습니다.',
      QuickContentUndoStatus.conflict => '이후 수정된 자료라 안전하게 되돌리지 않았습니다.',
      QuickContentUndoStatus.alreadyUndone => '이미 되돌린 저장입니다.',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _organizeGroup({required bool copy}) async {
    final group = await _askGroupName(copy: copy);
    if (group == null || !mounted) return;
    await ref
        .read(appControllerProvider.notifier)
        .organizeItemsInLearningGroup(_selectedForGroup, group, copy: copy);
    if (!mounted) return;
    if (ref.read(appControllerProvider).driveConnected) {
      unawaited(
        ref.read(connectionControllerProvider.notifier).syncAutomatically(),
      );
    }
    setState(() {
      _groupFilter = group;
      if (!copy) {
        _selectedForGroup.clear();
        _groupSelectionMode = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('선택한 표현을 “$group” 그룹에 ${copy ? '복사' : '이동'}했습니다.'),
      ),
    );
  }

  void _startSelected({required bool memorize}) {
    if (_selectedForGroup.isEmpty) return;
    final controller = ref.read(appControllerProvider.notifier);
    final ids = Set<String>.from(_selectedForGroup);
    final current = ref.read(appControllerProvider).preferences.sessionPlan;
    controller.updateSessionPlan(
      current.copyWith(
        title: '선택 자료 ${memorize ? '암기' : '퀴즈'}',
        mode: StudyMode.mixed,
        deck: StudyDeckScope.selected,
        difficulty: StudyDifficulty.all,
        tags: {},
        levels: {},
        selectedItemIds: ids,
        includeWords: true,
        includeSentences: true,
        itemLimit: ids.length.clamp(
          StudyLimits.minSessionItems,
          StudyLimits.maxSessionItems,
        ),
        scheduledAt: null,
      ),
    );
    context.push(memorize ? '/cards?custom=true' : '/session-builder');
  }

  Future<void> _moveSelectedToSubject() async {
    final controller = ref.read(appControllerProvider.notifier);
    final targets = controller.availableSubjects
        .where((subject) => subject.id != controller.activeSubject.id)
        .toList(growable: false);
    if (targets.isEmpty) {
      _showLibraryMessage('먼저 위의 “새 주제”에서 이동할 학습 주제를 만들어 주세요.');
      return;
    }
    final target = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('다른 학습 주제로 이동'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text('선택한 ${_selectedForGroup.length}개 자료와 학습 기록을 함께 옮깁니다.'),
          ),
          for (final subject in targets)
            SimpleDialogOption(
              key: Key('move-to-subject-${subject.id}'),
              onPressed: () => Navigator.pop(dialogContext, subject.id),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  subject.symbol,
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(subject.name),
                subtitle: Text(subject.description),
              ),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    final moved = await controller.moveItemsToStudySubject(
      _selectedForGroup,
      target,
    );
    if (!mounted) return;
    controller.selectSubject(target);
    setState(() {
      _groupFilter = null;
      _selectedForGroup.clear();
      _groupSelectionMode = false;
    });
    final subject = controller.activeSubject;
    _showLibraryMessage('$moved개 자료를 “${subject.name}” 주제로 이동했습니다.');
  }

  void _showLibraryMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _askGroupName({required bool copy}) async {
    final groups = ref
        .read(appControllerProvider.notifier)
        .availableLearningGroups;
    final rawName = await showDialog<String>(
      context: context,
      builder: (context) => _LearningGroupNameDialog(
        title: copy ? '학습 그룹에 복사' : '학습 그룹으로 이동',
        initialValue: _groupFilter ?? '',
        hintText: '예: 이번 주 여행 표현',
        groups: groups,
        confirmLabel: copy ? '복사' : '이동',
      ),
    );
    if (rawName == null || !mounted) return null;
    try {
      return normalizeLearningGroupName(rawName);
    } on FormatException catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
      return null;
    }
  }

  Future<void> _renameSelectedGroup() async {
    final current = _groupFilter;
    if (current == null) return;
    final rawName = await showDialog<String>(
      context: context,
      builder: (context) => _LearningGroupNameDialog(
        title: '학습 그룹 이름 변경',
        initialValue: current,
        inputKey: const Key('rename-learning-group-input'),
        confirmKey: const Key('confirm-rename-learning-group'),
        confirmLabel: '이름 변경',
        helperText: '이미 있는 이름을 입력하면 두 그룹이 하나로 합쳐집니다.',
      ),
    );
    if (rawName == null || !mounted) return;
    late final String nextName;
    try {
      nextName = normalizeLearningGroupName(rawName);
    } on FormatException catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message.toString())));
      return;
    }
    final changed = await ref
        .read(appControllerProvider.notifier)
        .renameLearningGroup(current, nextName);
    if (!mounted) return;
    if (ref.read(appControllerProvider).driveConnected) {
      unawaited(
        ref.read(connectionControllerProvider.notifier).syncAutomatically(),
      );
    }
    setState(() => _groupFilter = nextName);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$changed개 항목의 그룹 이름을 바꿨습니다.')));
  }

  Future<void> _deleteSelectedGroup() async {
    final current = _groupFilter;
    if (current == null) return;
    final itemCount = ref
        .read(appControllerProvider.notifier)
        .itemsForLearningGroup(current)
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('‘$current’ 그룹 삭제'),
        content: Text(
          '$itemCount개 단어·문장에서 이 그룹 표시만 제거합니다.\n'
          '학습 항목과 진도는 삭제되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('confirm-delete-learning-group'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('그룹 삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final changed = await ref
        .read(appControllerProvider.notifier)
        .deleteLearningGroup(current);
    if (!mounted) return;
    if (ref.read(appControllerProvider).driveConnected) {
      unawaited(
        ref.read(connectionControllerProvider.notifier).syncAutomatically(),
      );
    }
    setState(() {
      _groupFilter = null;
      _selectedForGroup.clear();
      _groupSelectionMode = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$changed개 항목에서 그룹 표시를 제거했습니다.')));
  }

  Future<void> _startGroup(String group, {required bool memorize}) async {
    final controller = ref.read(appControllerProvider.notifier);
    final ids = controller
        .itemsForLearningGroup(group)
        .map((item) => item.id)
        .toSet();
    if (ids.isEmpty) return;
    final preset = memorize
        ? const _GroupQuizPreset(mode: StudyMode.mixed, itemLimit: 0)
        : await showModalBottomSheet<_GroupQuizPreset>(
            context: context,
            useSafeArea: true,
            showDragHandle: true,
            builder: (context) =>
                _GroupQuizPresetSheet(group: group, itemCount: ids.length),
          );
    if (preset == null || !mounted) return;
    final customize = preset.itemLimit < 0;
    final itemLimit = preset.itemLimit <= 0
        ? ids.length.clamp(
            StudyLimits.minSessionItems,
            StudyLimits.maxSessionItems,
          )
        : preset.itemLimit.clamp(1, ids.length);
    final current = ref.read(appControllerProvider).preferences.sessionPlan;
    controller.updateSessionPlan(
      current.copyWith(
        title: '$group ${memorize ? '암기' : '퀴즈'}',
        mode: preset.mode,
        deck: StudyDeckScope.selected,
        difficulty: StudyDifficulty.all,
        tags: {},
        levels: {},
        selectedItemIds: ids,
        includeWords: true,
        includeSentences: true,
        itemLimit: itemLimit,
        scheduledAt: null,
      ),
    );
    if (customize) {
      context.push('/session-builder');
      return;
    }
    context.push(
      memorize
          ? '/cards?custom=true'
          : '/study?mode=${preset.mode.name}&custom=true',
    );
  }

  void _startSmartCollection() {
    final controller = ref.read(appControllerProvider.notifier);
    final items = _filter == _LibraryFilter.wrong
        ? controller.recentWrongItems
        : controller.weakItems;
    if (items.isEmpty) return;
    final title = _filter == _LibraryFilter.wrong ? '최근 오답 복습' : '취약 표현 집중';
    final current = ref.read(appControllerProvider).preferences.sessionPlan;
    controller.updateSessionPlan(
      current.copyWith(
        planId: '',
        title: title,
        mode: StudyMode.mixed,
        deck: StudyDeckScope.selected,
        difficulty: StudyDifficulty.all,
        tags: {},
        levels: {},
        selectedItemIds: items.map((item) => item.id).toSet(),
        includeWords: true,
        includeSentences: true,
        itemLimit: items.length.clamp(
          StudyLimits.minSessionItems,
          StudyLimits.maxSessionItems,
        ),
        scheduledAt: null,
      ),
    );
    context.push('/session-builder');
  }

  void _showDetails(
    BuildContext context, {
    required LearningItem item,
    required ProgressRecord? progress,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ItemDetails(item: item, progress: progress),
    );
  }

  Future<void> _confirmDelete(BuildContext context, LearningItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('사용자 표현 삭제'),
        content: Text('“${item.text}” 항목을 삭제할까요?\n학습 기록은 통계 보존을 위해 남겨둡니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final batch = await ref
        .read(appControllerProvider.notifier)
        .trashCustomItems({item.id});
    if (!context.mounted) return;
    _showDeleteUndo(batch);
  }
}

class _BulkTagEdit {
  const _BulkTagEdit({required this.tags, required this.remove});

  final Set<String> tags;
  final bool remove;
}

class _AdvancedLibraryFiltersSheet extends StatefulWidget {
  const _AdvancedLibraryFiltersSheet({
    required this.initialValue,
    required this.partsOfSpeech,
    required this.tags,
    required this.sources,
  });

  final LibrarySearchCriteria initialValue;
  final Set<PartOfSpeech> partsOfSpeech;
  final Set<String> tags;
  final Set<String> sources;

  @override
  State<_AdvancedLibraryFiltersSheet> createState() =>
      _AdvancedLibraryFiltersSheetState();
}

class _AdvancedLibraryFiltersSheetState
    extends State<_AdvancedLibraryFiltersSheet> {
  late Set<PartOfSpeech> _partsOfSpeech;
  late Set<String> _tags;
  late Set<String> _sources;
  late LibraryLearningStateFilter _learningState;
  late LibrarySortOrder _sortOrder;

  @override
  void initState() {
    super.initState();
    _load(widget.initialValue);
  }

  void _load(LibrarySearchCriteria value) {
    _partsOfSpeech = {...value.partsOfSpeech};
    _tags = {...value.tags};
    _sources = {...value.sources};
    _learningState = value.learningState;
    _sortOrder = value.sortOrder;
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.partsOfSpeech.toList()
      ..sort((left, right) => left.koreanLabel.compareTo(right.koreanLabel));
    final tags = widget.tags.toList()..sort();
    final sources = widget.sources.toList()..sort();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '상세 필터와 정렬',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  key: const Key('reset-library-advanced-filters'),
                  onPressed: () =>
                      setState(() => _load(const LibrarySearchCriteria())),
                  child: const Text('초기화'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  DropdownButtonFormField<LibraryLearningStateFilter>(
                    key: const Key('library-learning-state-filter'),
                    initialValue: _learningState,
                    decoration: const InputDecoration(
                      labelText: '학습 상태',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    items: [
                      for (final value in LibraryLearningStateFilter.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.koreanLabel),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _learningState = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<LibrarySortOrder>(
                    key: const Key('library-sort-order'),
                    initialValue: _sortOrder,
                    decoration: const InputDecoration(
                      labelText: '정렬',
                      prefixIcon: Icon(Icons.sort_rounded),
                    ),
                    items: [
                      for (final value in LibrarySortOrder.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(value.koreanLabel),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _sortOrder = value);
                    },
                  ),
                  if (parts.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const _FilterSectionTitle(
                      icon: Icons.category_outlined,
                      title: '품사',
                      helper: '여러 개를 고르면 그중 하나와 일치',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final part in parts)
                          FilterChip(
                            label: Text(part.koreanLabel),
                            selected: _partsOfSpeech.contains(part),
                            onSelected: (selected) => setState(() {
                              selected
                                  ? _partsOfSpeech.add(part)
                                  : _partsOfSpeech.remove(part);
                            }),
                          ),
                      ],
                    ),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const _FilterSectionTitle(
                      icon: Icons.sell_outlined,
                      title: '태그',
                      helper: '여러 개를 고르면 모두 포함된 자료',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final tag in tags)
                          FilterChip(
                            label: Text(tag),
                            selected: _tags.contains(tag),
                            onSelected: (selected) => setState(() {
                              selected ? _tags.add(tag) : _tags.remove(tag);
                            }),
                          ),
                      ],
                    ),
                  ],
                  if (sources.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const _FilterSectionTitle(
                      icon: Icons.source_outlined,
                      title: '출처',
                      helper: '기본 언어팩과 내 자료를 구분',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final source in sources)
                          FilterChip(
                            label: Text(source),
                            selected: _sources.contains(source),
                            onSelected: (selected) => setState(() {
                              selected
                                  ? _sources.add(source)
                                  : _sources.remove(source);
                            }),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('apply-library-advanced-filters'),
              onPressed: () => Navigator.pop(
                context,
                LibrarySearchCriteria(
                  partsOfSpeech: _partsOfSpeech,
                  tags: _tags,
                  sources: _sources,
                  learningState: _learningState,
                  sortOrder: _sortOrder,
                ),
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('필터 적용'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle({
    required this.icon,
    required this.title,
    required this.helper,
  });

  final IconData icon;
  final String title;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(helper, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _BulkTagDialog extends StatefulWidget {
  const _BulkTagDialog();

  @override
  State<_BulkTagDialog> createState() => _BulkTagDialogState();
}

class _BulkTagDialogState extends State<_BulkTagDialog> {
  final _controller = TextEditingController();
  var _remove = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = _controller.text
        .split(RegExp(r'[,;\n]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    return AlertDialog(
      title: const Text('선택 자료 태그 변경'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('태그 추가')),
              ButtonSegment(value: true, label: Text('태그 제거')),
            ],
            selected: {_remove},
            onSelectionChanged: (value) =>
                setState(() => _remove = value.single),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('bulk-tag-input'),
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '태그',
              hintText: '여행, 이번 주, 중요',
              helperText: '쉼표·세미콜론·줄바꿈으로 구분',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('confirm-bulk-tag-edit'),
          onPressed: tags.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _BulkTagEdit(tags: tags, remove: _remove),
                ),
          child: Text(_remove ? '제거' : '추가'),
        ),
      ],
    );
  }
}

class _ContentCorrectionDialog extends StatefulWidget {
  const _ContentCorrectionDialog({required this.item, this.current});

  final LearningItem item;
  final ContentCorrection? current;

  @override
  State<_ContentCorrectionDialog> createState() =>
      _ContentCorrectionDialogState();
}

class _ContentCorrectionDialogState extends State<_ContentCorrectionDialog> {
  late final TextEditingController _noteController;
  late final TextEditingController _valueController;
  late String _field;

  static const _fields = {
    'text': '문제·표현',
    'translation': '뜻·정답',
    'reading': '읽기·발음',
    'example': '예문',
    'other': '기타',
  };

  @override
  void initState() {
    super.initState();
    _field = _fields.containsKey(widget.current?.field)
        ? widget.current!.field
        : 'translation';
    _noteController = TextEditingController(text: widget.current?.note ?? '');
    _valueController = TextEditingController(
      text: widget.current?.proposedValue ?? '',
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = _noteController.text.trim();
    return AlertDialog(
      key: const Key('content-correction-dialog'),
      title: Text('“${widget.item.text}” 교정 메모'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '기본 언어팩 원본은 바꾸지 않습니다. 내 기기와 Drive 동기화 데이터에 교정 메모만 저장합니다.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const Key('content-correction-field'),
              initialValue: _field,
              decoration: const InputDecoration(labelText: '수정이 필요한 부분'),
              items: [
                for (final entry in _fields.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _field = value);
              },
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('content-correction-value'),
              controller: _valueController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '제안 값 (선택)',
                hintText: '바꾸면 좋을 표현이나 뜻',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('content-correction-note'),
              controller: _noteController,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: '메모',
                hintText: '어떤 점을 확인해야 하는지 적어 주세요.',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('save-content-correction'),
          onPressed: note.isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  ContentCorrection(
                    itemId: widget.item.id,
                    field: _field,
                    note: note,
                    proposedValue: _valueController.text.trim().isEmpty
                        ? null
                        : _valueController.text.trim(),
                    updatedAt: DateTime.now().toUtc(),
                  ),
                ),
          child: const Text('메모 저장'),
        ),
      ],
    );
  }
}

class _LearningGroupNameDialog extends StatefulWidget {
  const _LearningGroupNameDialog({
    required this.title,
    required this.initialValue,
    required this.confirmLabel,
    this.hintText,
    this.helperText,
    this.groups = const [],
    this.inputKey,
    this.confirmKey,
  });

  final String title;
  final String initialValue;
  final String confirmLabel;
  final String? hintText;
  final String? helperText;
  final List<String> groups;
  final Key? inputKey;
  final Key? confirmKey;

  @override
  State<_LearningGroupNameDialog> createState() =>
      _LearningGroupNameDialogState();
}

class _LearningGroupNameDialogState extends State<_LearningGroupNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: widget.inputKey,
              controller: _controller,
              autofocus: true,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) => Navigator.pop(context, value),
              decoration: InputDecoration(
                labelText: '그룹 이름',
                hintText: widget.hintText,
                helperText: widget.helperText,
              ),
            ),
            if (widget.groups.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final group in widget.groups)
                    ActionChip(
                      label: Text(group),
                      onPressed: () {
                        _controller
                          ..text = group
                          ..selection = TextSelection.collapsed(
                            offset: group.length,
                          );
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: widget.confirmKey,
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

enum _SavedNextAction { addMore, organize, learn }

class _GroupQuizPreset {
  const _GroupQuizPreset({required this.mode, required this.itemLimit});

  final StudyMode mode;
  final int itemLimit;
}

class _GroupQuizPresetSheet extends StatelessWidget {
  const _GroupQuizPresetSheet({required this.group, required this.itemCount});

  final String group;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 620,
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '“$group” 퀴즈 시작',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '$itemCount개 자료 중 원하는 길이와 방식을 고르면 바로 시작합니다.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              _QuizPresetChoice(
                key: const Key('group-quiz-quick-5'),
                icon: Icons.bolt_rounded,
                title: '빠르게 5문제',
                detail: '뜻·쓰기·문장을 섞은 짧은 퀴즈',
                onTap: () => Navigator.pop(
                  context,
                  const _GroupQuizPreset(mode: StudyMode.mixed, itemLimit: 5),
                ),
              ),
              const SizedBox(height: 8),
              _QuizPresetChoice(
                key: const Key('group-quiz-standard-10'),
                icon: Icons.quiz_outlined,
                title: '표준 10문제',
                detail: '부담 없이 한 세트를 완료',
                onTap: () => Navigator.pop(
                  context,
                  const _GroupQuizPreset(mode: StudyMode.mixed, itemLimit: 10),
                ),
              ),
              const SizedBox(height: 8),
              _QuizPresetChoice(
                key: const Key('group-quiz-meaning'),
                icon: Icons.touch_app_rounded,
                title: '뜻 고르기 10문제',
                detail: '키보드 입력 없이 빠르게 확인',
                onTap: () => Navigator.pop(
                  context,
                  const _GroupQuizPreset(
                    mode: StudyMode.meaning,
                    itemLimit: 10,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _QuizPresetChoice(
                key: const Key('group-quiz-all'),
                icon: Icons.select_all_rounded,
                title: '전체 자료',
                detail: '최대 30문제로 그룹 전체 점검',
                onTap: () => Navigator.pop(
                  context,
                  const _GroupQuizPreset(mode: StudyMode.mixed, itemLimit: 0),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('group-quiz-customize'),
                onPressed: () => Navigator.pop(
                  context,
                  const _GroupQuizPreset(mode: StudyMode.mixed, itemLimit: -1),
                ),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('세부 조건 직접 설정'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizPresetChoice extends StatelessWidget {
  const _QuizPresetChoice({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        leading: Icon(icon, color: colors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(detail),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _AddContentMenu extends StatelessWidget {
  const _AddContentMenu();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
        child: SingleChildScrollView(
          key: const Key('add-content-menu-scroll'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '어떻게 추가할까요?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '한두 개는 빠른 추가, 여러 개는 파일 가져오기가 편합니다.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              _AddContentChoice(
                key: const Key('add-quick-word'),
                icon: Icons.text_fields_rounded,
                title: '단어 빠른 추가',
                description: '단어와 뜻만 입력하고 바로 저장',
                onTap: () =>
                    Navigator.pop(context, _AddContentAction.quickWord),
              ),
              const SizedBox(height: 8),
              _AddContentChoice(
                key: const Key('add-quick-sentence'),
                icon: Icons.notes_rounded,
                title: '문장 빠른 추가',
                description: '문장과 뜻, 예문 단서를 간단히 저장',
                onTap: () =>
                    Navigator.pop(context, _AddContentAction.quickSentence),
              ),
              const SizedBox(height: 8),
              _AddContentChoice(
                key: const Key('add-import-file'),
                icon: Icons.upload_file_rounded,
                title: 'Excel·CSV 파일 가져오기',
                description: '템플릿으로 단어, 문장, 그룹을 한 번에 추가',
                onTap: () =>
                    Navigator.pop(context, _AddContentAction.importFile),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('add-full-editor'),
                onPressed: () =>
                    Navigator.pop(context, _AddContentAction.fullEditor),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('출처·품사까지 자세히 입력'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddContentChoice extends StatelessWidget {
  const _AddContentChoice({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedContentActions extends StatelessWidget {
  const _SavedContentActions({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: SingleChildScrollView(
        key: const Key('saved-content-actions-scroll'),
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '다음에 할 일을 바로 선택할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const Key('saved-content-add-more'),
              onPressed: () => Navigator.pop(context, _SavedNextAction.addMore),
              icon: const Icon(Icons.add_rounded),
              label: const Text('같은 방식으로 계속 추가'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('saved-content-organize'),
              onPressed: () =>
                  Navigator.pop(context, _SavedNextAction.organize),
              icon: const Icon(Icons.folder_copy_outlined),
              label: const Text('그룹 정리하기'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('saved-content-learn'),
              onPressed: () => Navigator.pop(context, _SavedNextAction.learn),
              icon: const Icon(Icons.school_outlined),
              label: const Text('암기·퀴즈로 이동'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveLibraryFilters extends StatelessWidget {
  const _ActiveLibraryFilters({
    required this.query,
    required this.filter,
    required this.group,
    required this.advancedCriteria,
    required this.resultCount,
    required this.onClear,
  });

  final String query;
  final _LibraryFilter filter;
  final String? group;
  final LibrarySearchCriteria advancedCriteria;
  final int resultCount;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      if (query.isNotEmpty) '검색 “$query”',
      if (filter != _LibraryFilter.all)
        switch (filter) {
          _LibraryFilter.favorites => '저장됨',
          _LibraryFilter.word => '단어',
          _LibraryFilter.sentence => '문장',
          _LibraryFilter.weak => '취약',
          _LibraryFilter.wrong => '최근 오답',
          _LibraryFilter.all => '',
        },
      if (group != null) '그룹 $group',
      if (advancedCriteria.partsOfSpeech.isNotEmpty)
        '품사 ${advancedCriteria.partsOfSpeech.map((value) => value.koreanLabel).join(', ')}',
      if (advancedCriteria.tags.isNotEmpty)
        '태그 ${advancedCriteria.tags.join(', ')}',
      if (advancedCriteria.sources.isNotEmpty)
        '출처 ${advancedCriteria.sources.join(', ')}',
      if (advancedCriteria.learningState != LibraryLearningStateFilter.all)
        advancedCriteria.learningState.koreanLabel,
      if (advancedCriteria.sortOrder != LibrarySortOrder.catalog)
        advancedCriteria.sortOrder.koreanLabel,
    ];
    return Container(
      key: const Key('active-library-filters'),
      padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${labels.join(' · ')} · $resultCount개 표시',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            key: const Key('clear-library-filters'),
            onPressed: onClear,
            child: const Text('전체 보기'),
          ),
        ],
      ),
    );
  }
}

class _LibraryWorkspace extends StatelessWidget {
  const _LibraryWorkspace({
    required this.mobile,
    required this.narrow,
    required this.scrollController,
    required this.controls,
    required this.results,
  });

  final bool mobile;
  final bool narrow;
  final ScrollController scrollController;
  final Widget controls;
  final Widget results;

  @override
  Widget build(BuildContext context) {
    const maxWidth = 1120.0;
    final horizontal = narrow
        ? 12.0
        : mobile
        ? 16.0
        : 20.0;
    final footer = Text(
      'Excel · CSV · JSON · JSONL로 단어, 예문, 학습 그룹을 추가할 수 있습니다.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );

    if (mobile) {
      return NestedScrollView(
        key: const Key('mobile-library-scroll'),
        controller: scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    narrow ? 12 : 16,
                    horizontal,
                    0,
                  ),
                  child: controls,
                ),
              ),
            ),
          ),
        ],
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                8,
                horizontal,
                narrow ? 10 : 14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Expanded(child: results)],
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              controls,
              const SizedBox(height: 10),
              Expanded(child: results),
              const SizedBox(height: 8),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label 필터',
      child: Material(
        color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onSelected,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: colors.onPrimaryContainer,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? colors.onPrimaryContainer
                          : colors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmartCollectionsBar extends StatelessWidget {
  const _SmartCollectionsBar({
    required this.weakCount,
    required this.wrongCount,
    required this.selectedFilter,
    required this.onSelectWeak,
    required this.onSelectWrong,
    required this.onStart,
  });

  final int weakCount;
  final int wrongCount;
  final _LibraryFilter selectedFilter;
  final VoidCallback onSelectWeak;
  final VoidCallback onSelectWrong;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            key: const Key('smart-weak-collection'),
            selected: selectedFilter == _LibraryFilter.weak,
            onSelected: (_) => onSelectWeak(),
            avatar: const Icon(Icons.fitness_center_rounded, size: 17),
            label: Text('취약 $weakCount'),
          ),
          const SizedBox(width: 7),
          ChoiceChip(
            key: const Key('smart-wrong-collection'),
            selected: selectedFilter == _LibraryFilter.wrong,
            onSelected: (_) => onSelectWrong(),
            avatar: const Icon(Icons.replay_rounded, size: 17),
            label: Text('오답 $wrongCount'),
          ),
        ],
      ),
    );
    final start = FilledButton.tonalIcon(
      key: const Key('start-smart-collection'),
      onPressed: onStart,
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text('학습'),
    );
    return Container(
      key: const Key('smart-learning-collections'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: colors.tertiary),
              const SizedBox(width: 7),
              Text('자동 모음', style: Theme.of(context).textTheme.labelLarge),
            ],
          );
          if (constraints.maxWidth < 520) {
            final compactLabel = constraints.maxWidth < 380
                ? Tooltip(
                    message: '자동 모음',
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.tertiary,
                    ),
                  )
                : label;
            return Row(
              children: [
                compactLabel,
                const SizedBox(width: 8),
                Expanded(child: chips),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  key: const Key('start-smart-collection-compact'),
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  tooltip: '선택한 자동 모음 학습',
                ),
              ],
            );
          }
          return Row(
            children: [
              label,
              const SizedBox(width: 10),
              Expanded(child: chips),
              const SizedBox(width: 8),
              start,
            ],
          );
        },
      ),
    );
  }
}

class _SavedSmartCollectionsBar extends StatelessWidget {
  const _SavedSmartCollectionsBar({
    required this.collections,
    required this.itemCountFor,
    required this.canSaveCurrent,
    required this.onSaveCurrent,
    required this.onSelect,
    required this.onDelete,
    required this.onTogglePin,
  });

  final List<SmartCollectionDefinition> collections;
  final int Function(SmartCollectionDefinition) itemCountFor;
  final bool canSaveCurrent;
  final VoidCallback onSaveCurrent;
  final ValueChanged<SmartCollectionDefinition> onSelect;
  final ValueChanged<SmartCollectionDefinition> onDelete;
  final ValueChanged<SmartCollectionDefinition> onTogglePin;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('saved-smart-collections'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_rounded, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: collections.isEmpty
                ? const Text('현재 조건을 저장하면 자료가 늘어도 자동으로 갱신됩니다.', maxLines: 2)
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final collection in collections) ...[
                          InputChip(
                            key: Key('saved-smart-${collection.id}'),
                            avatar: Icon(
                              collection.pinned
                                  ? Icons.push_pin_rounded
                                  : Icons.filter_alt_outlined,
                              size: 17,
                            ),
                            label: Text(
                              '${collection.name} ${itemCountFor(collection)}',
                            ),
                            onPressed: () => onSelect(collection),
                          ),
                          PopupMenuButton<_SavedCollectionAction>(
                            tooltip: '${collection.name} 관리',
                            icon: const Icon(Icons.more_vert_rounded, size: 19),
                            onSelected: (action) {
                              switch (action) {
                                case _SavedCollectionAction.pin:
                                  onTogglePin(collection);
                                case _SavedCollectionAction.delete:
                                  onDelete(collection);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: _SavedCollectionAction.pin,
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(
                                    collection.pinned
                                        ? Icons.push_pin_outlined
                                        : Icons.push_pin_rounded,
                                  ),
                                  title: Text(
                                    collection.pinned ? '고정 해제' : '상단에 고정',
                                  ),
                                ),
                              ),
                              const PopupMenuItem(
                                value: _SavedCollectionAction.delete,
                                child: ListTile(
                                  dense: true,
                                  leading: Icon(Icons.delete_outline_rounded),
                                  title: Text('컬렉션 삭제'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            key: const Key('save-current-smart-collection'),
            onPressed: canSaveCurrent ? onSaveCurrent : null,
            icon: const Icon(Icons.add_rounded),
            tooltip: '현재 필터 저장',
          ),
        ],
      ),
    );
  }
}

class _DuplicateRepairCard extends StatelessWidget {
  const _DuplicateRepairCard({
    required this.exactGroupCount,
    required this.suggestionCount,
    required this.itemCount,
    required this.onOpen,
  });

  final int exactGroupCount;
  final int suggestionCount;
  final int itemCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('duplicate-repair-card'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.merge_type_rounded),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              exactGroupCount == 0
                  ? '비슷한 자료 후보 $suggestionCount쌍을 찾았습니다. '
                        '자동으로 합치지 않으며 직접 비교할 수 있습니다.'
                  : '같은 표현 $itemCount개가 $exactGroupCount묶음 있습니다. '
                        '유사 후보 $suggestionCount쌍도 별도로 검토할 수 있습니다.',
              maxLines: 3,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: const Key('open-duplicate-repair'),
            onPressed: onOpen,
            child: const Text('검토'),
          ),
        ],
      ),
    );
  }
}

class _DuplicateRepairSheet extends StatelessWidget {
  const _DuplicateRepairSheet({required this.catalog, required this.progress});

  final DuplicateRepairCatalog catalog;
  final Map<String, ProgressRecord> progress;

  @override
  Widget build(BuildContext context) {
    final groups = [...catalog.exactGroups, ...catalog.similarSuggestions];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('중복 자료 수선', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '남길 대표 자료와 합칠 필드를 직접 고르세요. 진도와 세션 기록은 '
              '대표 자료에 합쳐지며, 유사 후보는 확인 없이 합쳐지지 않습니다.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _DuplicateGroupEditor(
                    key: Key('duplicate-group-$index'),
                    group: group,
                    progress: progress,
                    onMerge: (request) async {
                      if (group.kind == DuplicateMatchKind.similar) {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('유사 자료를 직접 합칠까요?'),
                            content: Text(
                              '“${group.items[0].text}”와 '
                              '“${group.items[1].text}”는 같은 표현이 아니라 '
                              '비슷한 후보입니다. 선택한 대표 자료로 합치면 '
                              '나머지 자료 ID와 학습 기록이 통합됩니다.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('취소'),
                              ),
                              FilledButton(
                                key: const Key(
                                  'confirm-similar-duplicate-merge',
                                ),
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('확인하고 합치기'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !context.mounted) return;
                      }
                      Navigator.pop(context, request);
                    },
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

class _DuplicateGroupEditor extends StatefulWidget {
  const _DuplicateGroupEditor({
    required this.group,
    required this.progress,
    required this.onMerge,
    super.key,
  });

  final DuplicateRepairGroup group;
  final Map<String, ProgressRecord> progress;
  final Future<void> Function(DuplicateMergeRequest request) onMerge;

  @override
  State<_DuplicateGroupEditor> createState() => _DuplicateGroupEditorState();
}

class _DuplicateGroupEditorState extends State<_DuplicateGroupEditor> {
  late String _canonicalItemId;
  final Set<DuplicateMergeField> _fields = {
    DuplicateMergeField.meanings,
    DuplicateMergeField.readings,
    DuplicateMergeField.examples,
    DuplicateMergeField.tags,
  };

  @override
  void initState() {
    super.initState();
    _canonicalItemId = const DuplicateRepairAnalyzer()
        .recommendCanonical(widget.group.items, widget.progress)
        .id;
  }

  @override
  Widget build(BuildContext context) {
    final similar = widget.group.kind == DuplicateMatchKind.similar;
    final meanings = widget.group.items
        .expand((item) => item.translations)
        .toSet()
        .join(' · ');
    final readings = widget.group.items
        .expand((item) => item.readingAidLabels)
        .toSet()
        .join(' · ');
    final examples = widget.group.items
        .map((item) => item.example)
        .whereType<String>()
        .toSet()
        .join('\n');
    final tags = widget.group.items
        .expand((item) => item.tags)
        .toSet()
        .join(' · ');
    return Card(
      color: similar
          ? Theme.of(
              context,
            ).colorScheme.tertiaryContainer.withValues(alpha: 0.28)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    similar
                        ? '유사 후보 · ${(widget.group.similarity * 100).round()}%'
                        : widget.group.items.first.text,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(
                    similar ? '자동 병합 안 함' : '${widget.group.items.length}개',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              similar
                  ? '${widget.group.items[0].text}  ↔  '
                        '${widget.group.items[1].text}'
                  : '같은 표현·언어·주제로 묶였습니다.',
            ),
            const SizedBox(height: 8),
            Text('남길 대표 자료', style: Theme.of(context).textTheme.labelLarge),
            RadioGroup<String>(
              groupValue: _canonicalItemId,
              onChanged: (value) {
                if (value != null) {
                  setState(() => _canonicalItemId = value);
                }
              },
              child: Column(
                children: [
                  for (final item in widget.group.items)
                    RadioListTile<String>(
                      key: Key('duplicate-canonical-${item.id}'),
                      value: item.id,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.text),
                      subtitle: Text(
                        '${item.translations.join(' · ')}'
                        ' · 학습 ${widget.progress[item.id]?.attempts ?? 0}회',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text('합칠 필드', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _fieldChip(DuplicateMergeField.meanings, '뜻', meanings),
                _fieldChip(DuplicateMergeField.readings, '읽기', readings),
                _fieldChip(DuplicateMergeField.examples, '예문', examples),
                _fieldChip(DuplicateMergeField.tags, '태그', tags),
              ],
            ),
            if (_fields.isEmpty) ...[
              const SizedBox(height: 7),
              Text(
                '최소 한 필드를 선택해야 자료 손실 없이 합칠 수 있습니다.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                key: Key('merge-duplicate-group-${widget.group.id}'),
                onPressed: _fields.isEmpty
                    ? null
                    : () => widget.onMerge(
                        DuplicateMergeRequest(
                          canonicalItemId: _canonicalItemId,
                          duplicateItemIds: widget.group.items
                              .map((item) => item.id)
                              .where((itemId) => itemId != _canonicalItemId)
                              .toSet(),
                          fields: Set.unmodifiable(_fields),
                          confirmedSimilarSuggestion: similar,
                        ),
                      ),
                icon: const Icon(Icons.merge_type_rounded),
                label: Text(similar ? '선택 병합 검토' : '이 묶음 합치기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldChip(DuplicateMergeField field, String label, String preview) =>
      FilterChip(
        key: Key('duplicate-field-${field.name}'),
        selected: _fields.contains(field),
        onSelected: (selected) => setState(() {
          if (selected) {
            _fields.add(field);
          } else {
            _fields.remove(field);
          }
        }),
        label: Tooltip(
          message: preview.isEmpty ? '$label 정보 없음' : preview,
          child: Text(label),
        ),
      );
}

enum _SavedCollectionAction { pin, delete }

enum _TrashActionType { restore, restoreAll, empty }

class _TrashSheetAction {
  const _TrashSheetAction(this.type, {this.entryId});

  final _TrashActionType type;
  final String? entryId;
}

class _TrashSheet extends StatelessWidget {
  const _TrashSheet({required this.entries});

  final List<TrashEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
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
                        '휴지통',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${entries.length}개 · 직접 비우기 전까지 보관',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const Key('restore-all-trash'),
                  onPressed: () => Navigator.pop(
                    context,
                    const _TrashSheetAction(_TrashActionType.restoreAll),
                  ),
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('모두 복원'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final text = entry.item['text'] as String? ?? entry.itemId;
                  final translations =
                      (entry.item['translations'] as List<Object?>?)
                          ?.whereType<String>()
                          .join(' · ') ??
                      '';
                  final deleted = entry.deletedAt.toLocal();
                  return ListTile(
                    key: Key('trash-entry-${entry.entryId}'),
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: Text(text),
                    subtitle: Text(
                      [
                        if (translations.isNotEmpty) translations,
                        '${deleted.month}/${deleted.day} '
                            '${deleted.hour.toString().padLeft(2, '0')}:'
                            '${deleted.minute.toString().padLeft(2, '0')} 삭제',
                      ].join('\n'),
                    ),
                    isThreeLine: translations.isNotEmpty,
                    trailing: IconButton(
                      onPressed: () => Navigator.pop(
                        context,
                        _TrashSheetAction(
                          _TrashActionType.restore,
                          entryId: entry.entryId,
                        ),
                      ),
                      icon: const Icon(Icons.restore_rounded),
                      tooltip: '복원',
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('empty-library-trash'),
              onPressed: () => Navigator.pop(
                context,
                const _TrashSheetAction(_TrashActionType.empty),
              ),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('전체 휴지통 비우기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupToolbar extends StatelessWidget {
  const _GroupToolbar({
    required this.groups,
    required this.summaries,
    required this.selectedGroup,
    required this.summary,
    required this.selectionMode,
    required this.onGroupChanged,
    required this.onToggleSelectionMode,
    required this.onOpenOrganizer,
    required this.onMemorize,
    required this.onQuiz,
    required this.onRename,
    required this.onDelete,
  });

  final List<String> groups;
  final List<LearningGroupSummary> summaries;
  final String? selectedGroup;
  final LearningGroupSummary? summary;
  final bool selectionMode;
  final ValueChanged<String?> onGroupChanged;
  final VoidCallback onToggleSelectionMode;
  final VoidCallback onOpenOrganizer;
  final VoidCallback? onMemorize;
  final VoidCallback? onQuiz;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    int groupCount(String group) {
      for (final item in summaries) {
        if (item.name == group) return item.totalCount;
      }
      return 0;
    }

    final toolbarItems = <Widget>[
      const Icon(Icons.folder_copy_outlined, size: 20),
      Text('학습 그룹', style: Theme.of(context).textTheme.titleSmall),
      OutlinedButton.icon(
        key: const Key('library-select-materials'),
        onPressed: onToggleSelectionMode,
        icon: Icon(
          selectionMode
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded,
        ),
        label: Text(selectionMode ? '선택 종료' : '자료 선택'),
      ),
      OutlinedButton.icon(
        key: const Key('library-group-selection'),
        onPressed: onOpenOrganizer,
        icon: const Icon(Icons.view_week_outlined),
        label: const Text('그룹 작업판'),
      ),
      ChoiceChip(
        label: const Text('전체'),
        selected: selectedGroup == null,
        onSelected: (_) => onGroupChanged(null),
      ),
      for (final group in groups)
        ChoiceChip(
          label: Text('$group ${groupCount(group)}'),
          selected: selectedGroup == group,
          onSelected: (_) => onGroupChanged(group),
        ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.folder_copy_outlined, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '학습 그룹',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('library-select-materials'),
                              onPressed: onToggleSelectionMode,
                              icon: Icon(
                                selectionMode
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                              ),
                              label: Text(selectionMode ? '선택 종료' : '자료 선택'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const Key('library-group-selection'),
                              onPressed: onOpenOrganizer,
                              icon: const Icon(Icons.view_week_outlined),
                              label: const Text('작업판'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        key: const Key('mobile-learning-group-scroll'),
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              key: const ValueKey('mobile-learning-group-all'),
                              label: const Text('전체'),
                              selected: selectedGroup == null,
                              onSelected: (_) => onGroupChanged(null),
                            ),
                            for (final group in groups) ...[
                              const SizedBox(width: 7),
                              ChoiceChip(
                                key: ValueKey('mobile-learning-group-$group'),
                                label: Text('$group ${groupCount(group)}'),
                                selected: selectedGroup == group,
                                onSelected: (_) => onGroupChanged(group),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: toolbarItems,
                );
              },
            ),
            if (summary != null && !selectionMode) ...[
              const Divider(height: 22),
              _LearningGroupSummaryPanel(
                summary: summary!,
                onMemorize: onMemorize,
                onQuiz: onQuiz,
                onRename: onRename,
                onDelete: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LearningGroupSummaryPanel extends StatelessWidget {
  const _LearningGroupSummaryPanel({
    required this.summary,
    required this.onMemorize,
    required this.onQuiz,
    required this.onRename,
    required this.onDelete,
  });

  final LearningGroupSummary summary;
  final VoidCallback? onMemorize;
  final VoidCallback? onQuiz;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final accuracy = summary.attempts == 0
        ? '아직 없음'
        : '${(summary.accuracy * 100).round()}%';
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          summary.name,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '전체 ${summary.totalCount}개 · 단어 ${summary.wordCount} · '
          '문장 ${summary.sentenceCount} · 학습 ${summary.studiedCount} · '
          '완료 ${summary.masteredCount} · 정확도 $accuracy',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Semantics(
          label: '${summary.name} 학습률 ${(summary.studyRate * 100).round()}퍼센트',
          child: LinearProgressIndicator(
            value: summary.studyRate,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        FilledButton.tonalIcon(
          onPressed: onMemorize,
          icon: const Icon(Icons.style_rounded),
          label: const Text('암기'),
        ),
        FilledButton.icon(
          onPressed: onQuiz,
          icon: const Icon(Icons.quiz_outlined),
          label: const Text('퀴즈'),
        ),
        IconButton.outlined(
          key: const Key('rename-learning-group'),
          onPressed: onRename,
          icon: const Icon(Icons.edit_outlined),
          tooltip: '그룹 이름 변경',
        ),
        IconButton.outlined(
          key: const Key('delete-learning-group'),
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
          tooltip: '그룹 삭제',
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [copy, const SizedBox(height: 10), actions],
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
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.subjectName,
    required this.subjectSymbol,
    required this.generalTopic,
    required this.totalCount,
    required this.studiedCount,
    required this.favoriteCount,
    required this.trashCount,
    required this.onAdd,
    required this.onTrash,
  });

  final String subjectName;
  final String subjectSymbol;
  final bool generalTopic;
  final int totalCount;
  final int studiedCount;
  final int favoriteCount;
  final int trashCount;
  final VoidCallback onAdd;
  final VoidCallback onTrash;

  @override
  Widget build(BuildContext context) {
    Widget copy({required bool veryNarrow}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${generalTopic ? '$subjectSymbol ' : ''}$subjectName '
          '자료실',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          veryNarrow
              ? '전체 $totalCount · 학습 $studiedCount · 저장 $favoriteCount'
              : '학습 주제 > 그룹 > 자료 · 전체 $totalCount개 · '
                    '학습 $studiedCount개 · 저장 $favoriteCount개',
          maxLines: veryNarrow ? 1 : null,
          overflow: veryNarrow ? TextOverflow.ellipsis : null,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
    final addButton = FilledButton.icon(
      key: const Key('library-add-button'),
      onPressed: onAdd,
      icon: const Icon(Icons.add_rounded),
      label: const Text('자료 추가'),
    );
    final compactAddButton = FilledButton.icon(
      key: const Key('library-add-button'),
      onPressed: onAdd,
      icon: const Icon(Icons.add_rounded),
      label: const Text('자료 추가'),
    );
    final iconAddButton = IconButton.filled(
      key: const Key('library-add-button'),
      onPressed: onAdd,
      icon: const Icon(Icons.add_rounded),
      tooltip: '자료 추가 방식 선택',
    );
    final trashButton = Badge(
      isLabelVisible: trashCount > 0,
      label: Text('$trashCount'),
      child: IconButton.outlined(
        key: const Key('open-library-trash'),
        onPressed: onTrash,
        icon: const Icon(Icons.delete_outline_rounded),
        tooltip: '휴지통 열기',
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: copy(veryNarrow: constraints.maxWidth < 360)),
              const SizedBox(width: 8),
              trashButton,
              const SizedBox(width: 6),
              if (constraints.maxWidth < 420)
                iconAddButton
              else
                compactAddButton,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: copy(veryNarrow: false)),
            const SizedBox(width: 18),
            trashButton,
            const SizedBox(width: 8),
            addButton,
          ],
        );
      },
    );
  }
}

class _LibraryRow extends ConsumerWidget {
  const _LibraryRow({
    required this.item,
    required this.progress,
    required this.selected,
    required this.favorite,
    required this.isCustom,
    required this.onToggle,
    required this.onFavorite,
    required this.onEdit,
    required this.onCorrect,
    required this.onDelete,
    required this.onTap,
    required this.selectionMode,
    required this.bulkSelected,
    required this.onBulkSelect,
  });

  final LearningItem item;
  final ProgressRecord? progress;
  final bool selected;
  final bool favorite;
  final bool isCustom;
  final VoidCallback onToggle;
  final VoidCallback onFavorite;
  final VoidCallback onEdit;
  final VoidCallback onCorrect;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool bulkSelected;
  final VoidCallback onBulkSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = _statusFor(progress);
    final colors = Theme.of(context).colorScheme;
    final interaction = ref.watch(
      appControllerProvider.select((state) => state.preferences.interaction),
    );
    final readingLabel = item.readingAidsLabelFor(
      showKoreanReading: interaction.showKoreanReading,
      showNativeReading: interaction.showNativeReading,
    );
    return Semantics(
      button: true,
      label: '${item.text}, ${item.primaryTranslation}, ${status.$1}',
      child: InkWell(
        key: Key('library-item-${item.id}'),
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 11 : 14,
                compact ? 9 : 11,
                8,
                compact ? 9 : 11,
              ),
              child: Row(
                children: [
                  if (selectionMode) ...[
                    Checkbox(
                      value: bulkSelected,
                      onChanged: (_) => onBulkSelect(),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.primaryContainer
                              : colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SizedBox.square(
                          dimension: compact ? 40 : 46,
                          child: Center(
                            child: Text(
                              item.learningLanguage.symbol,
                              style: TextStyle(
                                color: selected
                                    ? colors.onPrimaryContainer
                                    : colors.outline,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -3,
                        bottom: -3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.success : colors.outline,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.surface, width: 2),
                          ),
                          child: SizedBox.square(
                            dimension: 17,
                            child: Icon(
                              selected
                                  ? Icons.check_rounded
                                  : Icons.remove_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: compact ? 10 : 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (isCustom) ...[
                              const SizedBox(width: 7),
                              Icon(
                                Icons.person_outline_rounded,
                                size: 15,
                                color: colors.primary,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            item.primaryTranslation,
                            if (readingLabel.isNotEmpty)
                              readingLabel.replaceAll('\n', ' · '),
                            if (item.partOfSpeech != null)
                              item.partOfSpeech!.koreanLabel,
                            item.kind == LearningItemKind.word ? '단어' : '문장',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    _ProgressStatus(label: status.$1, color: status.$2),
                  ],
                  if (!selectionMode) ...[
                    IconButton(
                      key: Key('favorite-${item.id}'),
                      onPressed: onFavorite,
                      tooltip: favorite ? '저장 해제' : '표현 저장',
                      icon: Icon(
                        favorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: favorite ? AppTheme.warning : colors.outline,
                      ),
                    ),
                    PopupMenuButton<_ItemAction>(
                      tooltip: '표현 관리',
                      onSelected: (action) {
                        switch (action) {
                          case _ItemAction.toggle:
                            onToggle();
                          case _ItemAction.edit:
                            onEdit();
                          case _ItemAction.correct:
                            onCorrect();
                          case _ItemAction.delete:
                            onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: _ItemAction.toggle,
                          child: ListTile(
                            dense: true,
                            leading: Icon(
                              selected
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            title: Text(selected ? '학습에서 제외' : '학습에 포함'),
                          ),
                        ),
                        if (isCustom) ...[
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: _ItemAction.edit,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.edit_rounded),
                              title: Text('수정'),
                            ),
                          ),
                          const PopupMenuItem(
                            value: _ItemAction.delete,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.delete_outline_rounded),
                              title: Text('삭제'),
                            ),
                          ),
                        ] else ...[
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: _ItemAction.correct,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.rate_review_outlined),
                              title: Text('교정 메모'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _ItemAction { toggle, edit, correct, delete }

class _ProgressStatus extends StatelessWidget {
  const _ProgressStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

(String, Color) _statusFor(ProgressRecord? progress) {
  if (progress == null || progress.attempts == 0) {
    return ('새 항목', const Color(0xFF64748B));
  }
  if (progress.accuracy < 0.7) {
    return ('집중 필요', AppTheme.warning);
  }
  return switch (progress.status) {
    LearningStatus.mastered => ('익힘', AppTheme.success),
    LearningStatus.review => ('복습 중', const Color(0xFF365F7B)),
    LearningStatus.learning => ('학습 중', const Color(0xFF2E7D78)),
    LearningStatus.suspended => ('보류', const Color(0xFF64748B)),
    LearningStatus.newItem => ('새 항목', const Color(0xFF64748B)),
  };
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.query, required this.filter});

  final String query;
  final _LibraryFilter filter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.hasBoundedHeight && constraints.maxHeight < 190;
        final padding = compact ? 16.0 : 28.0;
        final minimumHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - padding * 2).clamp(0.0, double.infinity)
            : 0.0;
        return SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minimumHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  query.isEmpty
                      ? Icons.auto_awesome_rounded
                      : Icons.search_off_rounded,
                  size: compact ? 36 : 44,
                  color: Theme.of(context).colorScheme.outline,
                ),
                SizedBox(height: compact ? 8 : 12),
                Text(
                  query.isEmpty && filter == _LibraryFilter.weak
                      ? '집중이 필요한 항목이 없어요'
                      : query.isEmpty && filter == _LibraryFilter.wrong
                      ? '최근에 틀린 항목이 없어요'
                      : query.isEmpty && filter == _LibraryFilter.favorites
                      ? '아직 저장한 표현이 없어요'
                      : '조건에 맞는 표현이 없어요',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  query.isEmpty && filter == _LibraryFilter.weak
                      ? '정확도가 낮아지면 이곳에 자동으로 모아드려요.'
                      : query.isEmpty && filter == _LibraryFilter.wrong
                      ? '마지막 답이 오답인 표현은 이곳에 자동으로 모아드려요.'
                      : query.isEmpty && filter == _LibraryFilter.favorites
                      ? '외우고 싶은 표현의 별표를 눌러 따로 모아 보세요.'
                      : '검색어나 필터를 바꿔 다시 찾아보세요.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ItemDetails extends ConsumerWidget {
  const _ItemDetails({required this.item, required this.progress});

  final LearningItem item;
  final ProgressRecord? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = _statusFor(progress);
    final interaction = ref.watch(
      appControllerProvider.select((state) => state.preferences.interaction),
    );
    final readingLabel = item.readingAidsLabelFor(
      showKoreanReading: interaction.showKoreanReading,
      showNativeReading: interaction.showNativeReading,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _ProgressStatus(label: status.$1, color: status.$2),
                    const Spacer(),
                    Text(
                      '${item.learningLanguage.koreanName} · ${item.level}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  item.text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                if (readingLabel.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    key: const Key('item-reading-aids'),
                    readingLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  item.translations.join(' · '),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                Container(
                  key: const Key('item-source-metadata'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '콘텐츠 정보',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          if (item.partOfSpeech != null)
                            _ContentMetadataChip(
                              icon: Icons.category_outlined,
                              label: item.partOfSpeech!.koreanLabel,
                            ),
                          for (final group in learningGroupsOf(item))
                            _ContentMetadataChip(
                              icon: Icons.folder_outlined,
                              label: group,
                            ),
                          _ContentMetadataChip(
                            icon: Icons.source_outlined,
                            label: item.source.name,
                          ),
                          _ContentMetadataChip(
                            icon: Icons.verified_user_outlined,
                            label: item.source.license,
                          ),
                          _ContentMetadataChip(
                            icon: Icons.history_rounded,
                            label:
                                '출처 ${item.source.sourceVersion} · 콘텐츠 v${item.source.contentVersion}',
                          ),
                          if (item.source.sourceId case final sourceId?)
                            _ContentMetadataChip(
                              icon: Icons.tag_rounded,
                              label: sourceId,
                            ),
                          if (item.source.author case final author?)
                            _ContentMetadataChip(
                              icon: Icons.person_outline_rounded,
                              label: author,
                            ),
                        ],
                      ),
                      if (item.source.attribution case final attribution?) ...[
                        const SizedBox(height: 10),
                        SelectableText(
                          attribution,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (item.source.sourceUrl case final sourceUrl?) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const Key('item-source-url-button'),
                            onPressed: () => _openSource(context, sourceUrl),
                            icon: const Icon(Icons.open_in_new_rounded),
                            label: const Text('원문 열기'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (item.example != null) ...[
                  const SizedBox(height: 22),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '예문',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(item.example!),
                          if (item.exampleTranslation != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              item.exampleTranslation!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                if (progress != null) ...[
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _DetailMetric(
                          label: '정확도',
                          value: '${(progress!.accuracy * 100).round()}%',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DetailMetric(
                          label: '시도',
                          value: '${progress!.attempts}회',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DetailMetric(
                          label: '복습 간격',
                          value: '${progress!.currentIntervalDays}일',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openSource(BuildContext context, String sourceUrl) async {
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(sourceUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('원문 주소를 열지 못했습니다.')));
    }
  }
}

class _ContentMetadataChip extends StatelessWidget {
  const _ContentMetadataChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  const _DetailMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
