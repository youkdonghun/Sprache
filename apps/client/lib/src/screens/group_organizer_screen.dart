import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../domain/learning_group.dart';
import '../domain/learning_item.dart';
import '../domain/study_limits.dart';
import '../domain/study_preferences.dart';
import '../state/app_state.dart';
import '../state/connection_state.dart';
import '../widgets/content_selection_action_bar.dart';
import '../widgets/learning_data_flow_card.dart';

enum _GroupTransferMode { add, move }

enum _GroupSort { manual, name, itemCount }

extension on _GroupSort {
  String get label => switch (this) {
    _GroupSort.manual => '내 순서',
    _GroupSort.name => '이름순',
    _GroupSort.itemCount => '자료 많은 순',
  };
}

String _groupOrganizerSyncLabel(AppState state, ConnectionState connection) {
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

Color _learningGroupColor(ColorScheme colors, String key) => switch (key) {
  'blue' => colors.primary,
  'purple' => colors.tertiary,
  'orange' => const Color(0xFFC66A12),
  'rose' => colors.error,
  'gray' => colors.outline,
  _ => colors.secondary,
};

class _GroupDragPayload {
  const _GroupDragPayload(this.itemIds);

  final Set<String> itemIds;
}

class GroupOrganizerScreen extends ConsumerStatefulWidget {
  const GroupOrganizerScreen({super.key});

  @override
  ConsumerState<GroupOrganizerScreen> createState() =>
      _GroupOrganizerScreenState();
}

class _GroupOrganizerScreenState extends ConsumerState<GroupOrganizerScreen> {
  static const _allSource = '__all__';
  static const _ungroupedSource = '__ungrouped__';

  final _searchController = TextEditingController();
  final _groupSearchController = TextEditingController();
  final _boardFocusNode = FocusNode(debugLabel: 'group-organizer-board');
  final _selectedIds = <String>{};
  String _query = '';
  String _groupQuery = '';
  String _source = _allSource;
  _GroupTransferMode _transferMode = _GroupTransferMode.add;
  _GroupSort _groupSort = _GroupSort.manual;
  String? _lastSelectedId;
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    _groupSearchController.dispose();
    _boardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final connection = ref.watch(connectionControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final subject = controller.activeSubject;
    final items = controller.courseItems;
    final groupDefinitions = controller.availableLearningGroupDefinitions;
    final groups = groupDefinitions.map((group) => group.name).toList();
    final customIds = state.customItems.map((item) => item.id).toSet();
    final localCopyCount = state.customItems
        .where((item) => item.effectiveSubjectId == subject.id)
        .length;
    final visibleItems = items
        .where((item) {
          final itemGroups = learningGroupsOf(item);
          if (_source == _ungroupedSource && itemGroups.isNotEmpty) {
            return false;
          }
          if (_source != _allSource &&
              _source != _ungroupedSource &&
              !itemGroups.contains(_source)) {
            return false;
          }
          if (_query.isEmpty) return true;
          final haystack = [
            item.text,
            ...item.translations,
            ...item.readings.map((reading) => reading.value),
            ...itemGroups,
          ].join(' ').toLowerCase();
          return haystack.contains(_query.toLowerCase());
        })
        .toList(growable: false);
    final ungroupedCount = items
        .where((item) => learningGroupsOf(item).isEmpty)
        .length;
    final visibleIds = visibleItems.map((item) => item.id).toSet();
    final visibleSelectedCount = _selectedIds.intersection(visibleIds).length;
    final hiddenSelectedCount = _selectedIds.length - visibleSelectedCount;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () =>
            _toggleVisible(visibleItems),
        const SingleActivator(LogicalKeyboardKey.escape): _clearSelection,
      },
      child: Focus(
        focusNode: _boardFocusNode,
        autofocus: true,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desktopPointer =
                  defaultTargetPlatform == TargetPlatform.windows ||
                  defaultTargetPlatform == TargetPlatform.macOS ||
                  defaultTargetPlatform == TargetPlatform.linux;
              final split =
                  constraints.maxWidth >= (desktopPointer ? 660 : 760);
              final horizontal = constraints.maxWidth < 430 ? 12.0 : 20.0;
              final selectionBar = _selectedIds.isEmpty
                  ? null
                  : ContentSelectionActionBar(
                      selectedCount: _selectedIds.length,
                      hiddenSelectedCount: hiddenSelectedCount,
                      busy: _saving,
                      keyPrefix: 'organizer-selection',
                      addKey: const Key('open-mobile-group-targets'),
                      onAddToGroup: () => _openGroupTargetPicker(
                        mode: _GroupTransferMode.add,
                        groups: groupDefinitions,
                        controller: controller,
                        ungroupedCount: ungroupedCount,
                      ),
                      onMoveToGroup: () => _openGroupTargetPicker(
                        mode: _GroupTransferMode.move,
                        groups: groupDefinitions,
                        controller: controller,
                        ungroupedCount: ungroupedCount,
                      ),
                      onMemorize: () => _startSelected(memorize: true),
                      onQuiz: () => _startSelected(memorize: false),
                      onMoveToSubject: _moveToSubject,
                      onClear: _clearSelection,
                    );
              return Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OrganizerHeader(
                      subjectName: subject.name,
                      subjectSymbol: subject.symbol,
                      split: split,
                      onBack: () => context.go('/library'),
                    ),
                    const SizedBox(height: 12),
                    LearningDataFlowCard(
                      totalCount: items.length,
                      localCopyCount: localCopyCount,
                      groupCount: groups.length,
                      driveConnected: state.driveConnected,
                      currentStep: LearningDataStep.organize,
                      onAdd: () => context.go('/import'),
                      onOrganize: () {},
                      onLearn: () => context.go('/learn'),
                      syncLabel: _groupOrganizerSyncLabel(state, connection),
                      syncBusy: connection.busy,
                      onSync: state.driveConnected
                          ? () => unawaited(
                              ref
                                  .read(connectionControllerProvider.notifier)
                                  .syncOrRestore(manual: true),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    if (split && selectionBar != null) ...[
                      selectionBar,
                      const SizedBox(height: 10),
                    ],
                    Expanded(
                      child: split
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 11,
                                  child: _SourcePanel(
                                    items: visibleItems,
                                    groups: groups,
                                    customIds: customIds,
                                    selectedIds: _selectedIds,
                                    hiddenSelectedCount: hiddenSelectedCount,
                                    source: _source,
                                    queryController: _searchController,
                                    enableDrag: true,
                                    onQueryChanged: (value) =>
                                        setState(() => _query = value.trim()),
                                    onSourceChanged: (value) =>
                                        setState(() => _source = value),
                                    onToggleItem: (itemId) =>
                                        _toggleItem(itemId, visibleItems),
                                    onSelectVisible: () =>
                                        _toggleVisible(visibleItems),
                                    onClearSelection: _clearSelection,
                                    dragPayloadFor: _dragPayloadFor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 9,
                                  child: _TargetPanel(
                                    groups: groupDefinitions,
                                    controller: controller,
                                    ungroupedCount: ungroupedCount,
                                    selectedIds: _selectedIds,
                                    mode: _transferMode,
                                    queryController: _groupSearchController,
                                    groupQuery: _groupQuery,
                                    sort: _groupSort,
                                    saving: _saving,
                                    onModeChanged: (value) =>
                                        setState(() => _transferMode = value),
                                    onDropGroup: _applyToGroup,
                                    onDropUngrouped: _removeFromGroups,
                                    onCreateGroup: _createGroup,
                                    onMoveSubject: _moveToSubject,
                                    onRenameGroup: _renameGroup,
                                    onDeleteGroup: _deleteGroup,
                                    onGroupQueryChanged: (value) => setState(
                                      () => _groupQuery = value.trim(),
                                    ),
                                    onSortChanged: (value) =>
                                        setState(() => _groupSort = value),
                                    onPinGroup: _togglePinnedGroup,
                                    onReorderGroups: _reorderGroups,
                                    onStartGroup: _startGroup,
                                  ),
                                ),
                              ],
                            )
                          : _MobileOrganizer(
                              items: visibleItems,
                              groups: groups,
                              customIds: customIds,
                              selectedIds: _selectedIds,
                              hiddenSelectedCount: hiddenSelectedCount,
                              source: _source,
                              queryController: _searchController,
                              onQueryChanged: (value) =>
                                  setState(() => _query = value.trim()),
                              onSourceChanged: (value) =>
                                  setState(() => _source = value),
                              onToggleItem: (itemId) =>
                                  _toggleItem(itemId, visibleItems),
                              onSelectVisible: () =>
                                  _toggleVisible(visibleItems),
                              onClearSelection: _clearSelection,
                              onManageGroups: _showMobileGroupManager,
                              selectionBar: selectionBar,
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _toggleItem(String itemId, List<LearningItem> visibleItems) {
    _boardFocusNode.requestFocus();
    final shiftPressed = HardwareKeyboard.instance.isShiftPressed;
    setState(() {
      if (shiftPressed && _lastSelectedId != null) {
        final start = visibleItems.indexWhere(
          (item) => item.id == _lastSelectedId,
        );
        final end = visibleItems.indexWhere((item) => item.id == itemId);
        if (start >= 0 && end >= 0) {
          final lower = start < end ? start : end;
          final upper = start < end ? end : start;
          _selectedIds.addAll(
            visibleItems.sublist(lower, upper + 1).map((item) => item.id),
          );
        }
      } else if (!_selectedIds.add(itemId)) {
        _selectedIds.remove(itemId);
      }
      _lastSelectedId = itemId;
    });
  }

  void _clearSelection() {
    if (_selectedIds.isEmpty) return;
    setState(() {
      _selectedIds.clear();
      _lastSelectedId = null;
    });
  }

  void _toggleVisible(List<LearningItem> items) {
    final visibleIds = items.map((item) => item.id).toSet();
    final allSelected =
        visibleIds.isNotEmpty && visibleIds.every(_selectedIds.contains);
    setState(() {
      if (allSelected) {
        _selectedIds.removeAll(visibleIds);
      } else {
        _selectedIds.addAll(visibleIds);
      }
    });
  }

  _GroupDragPayload _dragPayloadFor(String itemId) {
    final ids = _selectedIds.contains(itemId)
        ? Set<String>.from(_selectedIds)
        : <String>{itemId};
    return _GroupDragPayload(ids);
  }

  Future<void> _applyToGroup(
    Set<String> itemIds,
    String group, {
    LearningGroupWorkspaceSnapshot? undoSnapshot,
  }) async {
    if (_saving || itemIds.isEmpty) return;
    final moving = _transferMode == _GroupTransferMode.move;
    if ((moving || itemIds.length >= 10) &&
        !await _confirmGroupChange(
          itemIds: itemIds,
          title: moving ? '선택 자료의 그룹을 이동할까요?' : '여러 자료를 그룹에 추가할까요?',
          target: group,
          destructive: moving,
        )) {
      return;
    }
    final controller = ref.read(appControllerProvider.notifier);
    final snapshot =
        undoSnapshot ?? controller.captureLearningGroupWorkspace(itemIds);
    setState(() => _saving = true);
    try {
      await controller.organizeItemsInLearningGroup(
        itemIds,
        group,
        copy: !moving,
      );
      if (!mounted) return;
      _syncAfterLocalChange();
      if (moving) {
        setState(() => _selectedIds.removeAll(itemIds));
      }
      _showUndoMessage(
        '${itemIds.length}개 자료를 “$group” 그룹에 '
        '${moving ? '이동' : '추가'}했습니다.',
        snapshot,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeFromGroups(Set<String> itemIds) async {
    if (_saving || itemIds.isEmpty) return;
    if (!await _confirmGroupChange(
      itemIds: itemIds,
      title: '선택 자료의 그룹 연결을 해제할까요?',
      target: '그룹 연결 해제',
      destructive: true,
    )) {
      return;
    }
    final controller = ref.read(appControllerProvider.notifier);
    final snapshot = controller.captureLearningGroupWorkspace(itemIds);
    setState(() => _saving = true);
    try {
      await controller.removeItemsFromLearningGroups(itemIds);
      if (!mounted) return;
      _syncAfterLocalChange();
      setState(() => _selectedIds.removeAll(itemIds));
      _showUndoMessage('${itemIds.length}개 자료의 모든 그룹 연결을 해제했습니다.', snapshot);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _createGroup([Set<String>? draggedIds]) async {
    final itemIds = draggedIds ?? Set<String>.from(_selectedIds);
    final controller = ref.read(appControllerProvider.notifier);
    final snapshot = controller.captureLearningGroupWorkspace(itemIds);
    final result = await showDialog<_GroupEditorResult>(
      context: context,
      builder: (context) => const _GroupNameDialog(),
    );
    if (result == null || !mounted) return;
    await controller.createLearningGroup(
      name: result.name,
      description: result.description,
      colorKey: result.colorKey,
    );
    if (!mounted) return;
    if (itemIds.isEmpty) {
      _showUndoMessage('빈 학습 그룹 “${result.name}”을 만들었습니다.', snapshot);
      _syncAfterLocalChange();
      return;
    }
    await _applyToGroup(itemIds, result.name, undoSnapshot: snapshot);
  }

  Future<void> _renameGroup(String group) async {
    final controller = ref.read(appControllerProvider.notifier);
    final definition = controller.learningGroupDefinition(group);
    final snapshot = controller.captureLearningGroupWorkspace(
      controller.itemsForLearningGroup(group).map((item) => item.id),
    );
    final result = await showDialog<_GroupEditorResult>(
      context: context,
      builder: (context) => _GroupNameDialog(
        title: '학습 그룹 편집',
        initialValue: group,
        initialDescription: definition?.description ?? '',
        initialColorKey: definition?.colorKey ?? 'teal',
        confirmLabel: '저장',
      ),
    );
    if (result == null || !mounted) return;
    final changed = result.name == group
        ? controller.itemsForLearningGroup(group).length
        : await controller.renameLearningGroup(group, result.name);
    final renamed = controller.learningGroupDefinition(result.name);
    if (renamed != null) {
      await controller.updateLearningGroupDefinition(
        renamed.copyWith(
          description: result.description,
          colorKey: result.colorKey,
        ),
      );
    }
    if (!mounted) return;
    if (_source == group) setState(() => _source = result.name);
    _showUndoMessage('$changed개 자료와 “${result.name}” 그룹 정보를 저장했습니다.', snapshot);
    _syncAfterLocalChange();
  }

  Future<void> _moveToSubject() async {
    if (_selectedIds.isEmpty || _saving) return;
    final controller = ref.read(appControllerProvider.notifier);
    final targets = controller.availableSubjects
        .where((subject) => subject.id != controller.activeSubject.id)
        .toList(growable: false);
    if (targets.isEmpty) {
      _showMessage('먼저 자료실에서 이동할 학습 주제를 만들어 주세요.');
      return;
    }
    final target = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('${_selectedIds.length}개 자료를 다른 주제로 이동'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text('자료와 연결된 학습 기록을 함께 옮깁니다.'),
          ),
          for (final subject in targets)
            SimpleDialogOption(
              key: Key('organizer-move-to-subject-${subject.id}'),
              onPressed: () => Navigator.pop(context, subject.id),
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
    final selectedIds = Set<String>.from(_selectedIds);
    final snapshot = controller.captureLearningGroupWorkspace(selectedIds);
    final targetSubject = targets.firstWhere((subject) => subject.id == target);
    setState(() => _saving = true);
    try {
      final moved = await controller.moveItemsToStudySubject(
        selectedIds,
        target,
      );
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
      });
      _showUndoMessage(
        '$moved개 자료를 “${targetSubject.name}” 주제로 이동했습니다. 현재 주제는 유지합니다.',
        snapshot,
        openSubjectId: target,
        openSubjectName: targetSubject.name,
      );
      _syncAfterLocalChange();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteGroup(String group) async {
    final controller = ref.read(appControllerProvider.notifier);
    final items = controller.itemsForLearningGroup(group);
    final count = items.length;
    final snapshot = controller.captureLearningGroupWorkspace(
      items.map((item) => item.id),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('“$group” 그룹을 삭제할까요?'),
        content: Text(
          '$count개 자료에서 그룹 표시만 제거합니다. '
          '자료와 학습 진도는 삭제되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('그룹만 삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final changed = await controller.deleteLearningGroup(group);
    if (!mounted) return;
    if (_source == group) setState(() => _source = _allSource);
    _showUndoMessage('$changed개 자료에서 “$group” 그룹 표시를 제거했습니다.', snapshot);
    _syncAfterLocalChange();
  }

  Future<bool> _confirmGroupChange({
    required Set<String> itemIds,
    required String title,
    required String target,
    required bool destructive,
  }) async {
    final controller = ref.read(appControllerProvider.notifier);
    final byId = {for (final item in controller.courseItems) item.id: item};
    final existingGroups = <String>{};
    var groupLinks = 0;
    for (final itemId in itemIds) {
      final item = byId[itemId];
      if (item == null) continue;
      final groups = learningGroupsOf(item);
      existingGroups.addAll(groups);
      groupLinks += groups.length;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ImpactRow(label: '선택 자료', value: '${itemIds.length}개'),
            _ImpactRow(
              label: '현재 그룹 연결',
              value: groupLinks == 0
                  ? '없음'
                  : '$groupLinks개 · ${existingGroups.length}개 그룹',
            ),
            _ImpactRow(label: '작업 결과', value: target),
            const SizedBox(height: 10),
            Text(
              destructive
                  ? '기존 그룹 연결이 바뀝니다. 원본 자료와 학습 진도는 유지됩니다.'
                  : '기존 그룹은 유지됩니다. 작업 후 실행 취소할 수 있습니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('confirm-group-impact'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(destructive ? '변경 적용' : '추가'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _showUndoMessage(
    String message,
    LearningGroupWorkspaceSnapshot snapshot, {
    String? openSubjectId,
    String? openSubjectName,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final keepBatchActionsVisible =
        MediaQuery.sizeOf(context).width < 760 && _selectedIds.isNotEmpty;
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          keepBatchActionsVisible ? 154 : 16,
        ),
        content: openSubjectId == null
            ? Text(message)
            : Row(
                children: [
                  Expanded(child: Text(message)),
                  TextButton(
                    key: const Key('open-moved-subject'),
                    onPressed: () {
                      messenger.hideCurrentSnackBar();
                      ref
                          .read(appControllerProvider.notifier)
                          .selectSubject(openSubjectId);
                      context.go('/library');
                    },
                    child: Text('${openSubjectName ?? '대상 주제'} 열기'),
                  ),
                ],
              ),
        action: SnackBarAction(
          label: '실행 취소',
          onPressed: () => unawaited(_undoGroupChange(snapshot)),
        ),
      ),
    );
  }

  Future<void> _undoGroupChange(LearningGroupWorkspaceSnapshot snapshot) async {
    await ref
        .read(appControllerProvider.notifier)
        .restoreLearningGroupWorkspace(snapshot);
    if (!mounted) return;
    setState(() {
      _selectedIds.addAll(snapshot.items.map((item) => item.id));
      _source = _allSource;
    });
    _syncAfterLocalChange();
    _showMessage('이전 그룹 상태로 되돌렸습니다.');
  }

  Future<void> _togglePinnedGroup(String group, bool pinned) async {
    final controller = ref.read(appControllerProvider.notifier);
    final snapshot = controller.captureLearningGroupWorkspace(const []);
    await controller.setLearningGroupPinned(group, pinned);
    if (!mounted) return;
    _showUndoMessage(
      pinned ? '“$group” 그룹을 위에 고정했습니다.' : '“$group” 그룹 고정을 해제했습니다.',
      snapshot,
    );
    _syncAfterLocalChange();
  }

  Future<void> _reorderGroups(int oldIndex, int newIndex) async {
    final definitions = ref
        .read(appControllerProvider.notifier)
        .availableLearningGroupDefinitions;
    if (oldIndex < 0 || oldIndex >= definitions.length) return;
    final targetIndex = newIndex.clamp(0, definitions.length - 1);
    final reordered = [...definitions];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(targetIndex, moved);
    final controller = ref.read(appControllerProvider.notifier);
    final snapshot = controller.captureLearningGroupWorkspace(const []);
    await controller.reorderLearningGroups([
      for (final group in reordered) group.name,
    ]);
    if (!mounted) return;
    _showUndoMessage('학습 그룹 순서를 변경했습니다.', snapshot);
    _syncAfterLocalChange();
  }

  void _startGroup(String group, {required bool memorize}) {
    final controller = ref.read(appControllerProvider.notifier);
    final ids = controller
        .itemsForLearningGroup(group)
        .map((item) => item.id)
        .toSet();
    if (ids.isEmpty) {
      _showMessage('“$group” 그룹에 학습할 자료가 없습니다.');
      return;
    }
    final current = ref.read(appControllerProvider).preferences.sessionPlan;
    controller.updateSessionPlan(
      current.copyWith(
        title: '$group ${memorize ? '암기' : '퀴즈'}',
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

  void _startSelected({required bool memorize}) {
    if (_selectedIds.isEmpty) return;
    final ids = Set<String>.from(_selectedIds);
    final controller = ref.read(appControllerProvider.notifier);
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

  void _openGroupTargetPicker({
    required _GroupTransferMode mode,
    required List<LearningGroupDefinition> groups,
    required AppController controller,
    required int ungroupedCount,
  }) {
    setState(() => _transferMode = mode);
    unawaited(
      _showMobileTargets(
        groups: groups,
        controller: controller,
        ungroupedCount: ungroupedCount,
      ),
    );
  }

  void _syncAfterLocalChange() {
    if (!ref.read(appControllerProvider).driveConnected) return;
    unawaited(ref.read(connectionControllerProvider.notifier).syncOrRestore());
  }

  void _showMobileGroupManager() {
    var query = '';
    var sort = _GroupSort.manual;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.82,
              child: Consumer(
                builder: (context, ref, child) {
                  ref.watch(appControllerProvider);
                  final controller = ref.read(appControllerProvider.notifier);
                  final allGroups =
                      controller.availableLearningGroupDefinitions;
                  final visible = allGroups
                      .where((group) {
                        if (query.isEmpty) return true;
                        return '${group.name} ${group.description}'
                            .toLowerCase()
                            .contains(query.toLowerCase());
                      })
                      .toList(growable: true);
                  if (sort == _GroupSort.name) {
                    visible.sort((left, right) {
                      final pinned = (right.pinned ? 1 : 0).compareTo(
                        left.pinned ? 1 : 0,
                      );
                      return pinned != 0
                          ? pinned
                          : left.name.compareTo(right.name);
                    });
                  } else if (sort == _GroupSort.itemCount) {
                    visible.sort((left, right) {
                      final leftCount = controller
                          .itemsForLearningGroup(left.name)
                          .length;
                      final rightCount = controller
                          .itemsForLearningGroup(right.name)
                          .length;
                      return rightCount.compareTo(leftCount);
                    });
                  }
                  Widget tile(LearningGroupDefinition group, int index) {
                    final count = controller
                        .itemsForLearningGroup(group.name)
                        .length;
                    return ListTile(
                      key: ValueKey('mobile-manage-${group.id}'),
                      minTileHeight: 56,
                      leading: Icon(
                        group.pinned
                            ? Icons.push_pin_rounded
                            : Icons.folder_outlined,
                        color: _learningGroupColor(
                          Theme.of(context).colorScheme,
                          group.colorKey,
                        ),
                      ),
                      title: Text(group.name),
                      subtitle: Text(
                        group.description.isEmpty
                            ? '$count개 자료'
                            : '${group.description} · $count개',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (sort == _GroupSort.manual && query.isEmpty)
                            ReorderableDragStartListener(
                              index: index,
                              child: const SizedBox.square(
                                dimension: 44,
                                child: Icon(Icons.drag_indicator_rounded),
                              ),
                            ),
                          PopupMenuButton<String>(
                            tooltip: '${group.name} 그룹 관리',
                            onSelected: (value) {
                              if (value == 'memorize') {
                                Navigator.pop(sheetContext);
                                _startGroup(group.name, memorize: true);
                              }
                              if (value == 'quiz') {
                                Navigator.pop(sheetContext);
                                _startGroup(group.name, memorize: false);
                              }
                              if (value == 'pin') {
                                unawaited(
                                  _togglePinnedGroup(group.name, !group.pinned),
                                );
                              }
                              if (value == 'edit') {
                                Navigator.pop(sheetContext);
                                unawaited(_renameGroup(group.name));
                              }
                              if (value == 'delete') {
                                Navigator.pop(sheetContext);
                                unawaited(_deleteGroup(group.name));
                              }
                            },
                            itemBuilder: (context) => [
                              if (count > 0) ...[
                                const PopupMenuItem(
                                  value: 'memorize',
                                  child: Text('바로 암기'),
                                ),
                                const PopupMenuItem(
                                  value: 'quiz',
                                  child: Text('바로 퀴즈'),
                                ),
                              ],
                              PopupMenuItem(
                                value: 'pin',
                                child: Text(group.pinned ? '고정 해제' : '위에 고정'),
                              ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('이름·설명 변경'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('그룹 삭제'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }

                  final list = visible.isEmpty
                      ? const _OrganizerEmpty(
                          icon: Icons.search_off_rounded,
                          title: '표시할 학습 그룹이 없습니다',
                          detail: '검색어를 바꾸거나 새 그룹을 만들어 보세요.',
                        )
                      : sort == _GroupSort.manual && query.isEmpty
                      ? ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: visible.length,
                          onReorderItem: (oldIndex, newIndex) {
                            unawaited(_reorderGroups(oldIndex, newIndex));
                          },
                          itemBuilder: (context, index) =>
                              tile(visible[index], index),
                        )
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) =>
                              tile(visible[index], index),
                        );
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '학습 그룹 관리',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            FilledButton.tonalIcon(
                              key: const Key('mobile-create-empty-group'),
                              onPressed: () {
                                Navigator.pop(sheetContext);
                                unawaited(_createGroup());
                              },
                              icon: const Icon(
                                Icons.create_new_folder_outlined,
                              ),
                              label: const Text('새 그룹'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('mobile-manage-group-search'),
                                onChanged: (value) {
                                  query = value.trim();
                                  setSheetState(() {});
                                },
                                decoration: const InputDecoration(
                                  hintText: '그룹 이름·설명 검색',
                                  prefixIcon: Icon(Icons.search_rounded),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<_GroupSort>(
                              value: sort,
                              items: [
                                for (final value in _GroupSort.values)
                                  DropdownMenuItem(
                                    value: value,
                                    child: Text(value.label),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                sort = value;
                                setSheetState(() {});
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(child: list),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMobileTargets({
    required List<LearningGroupDefinition> groups,
    required AppController controller,
    required int ungroupedCount,
  }) async {
    // The previous batch operation can leave an undo snackbar above the fixed
    // action bar. Clear it before opening the target sheet so no group row is
    // covered or unable to receive taps during a continuous add workflow.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    var mobileMode = _transferMode;
    var mobileQuery = '';
    final target = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_selectedIds.length}개 자료를 어디에 넣을까요?',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mobileMode == _GroupTransferMode.add
                            ? '기존 그룹을 유지하고 선택한 그룹을 추가합니다.'
                            : '기존 그룹을 해제하고 선택한 그룹으로 이동합니다.',
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<_GroupTransferMode>(
                        segments: const [
                          ButtonSegment(
                            value: _GroupTransferMode.add,
                            icon: Icon(Icons.add_rounded),
                            label: Text('그룹 추가'),
                          ),
                          ButtonSegment(
                            value: _GroupTransferMode.move,
                            icon: Icon(Icons.drive_file_move_outline),
                            label: Text('그룹 이동'),
                          ),
                        ],
                        selected: {mobileMode},
                        onSelectionChanged: (value) {
                          mobileMode = value.first;
                          _transferMode = mobileMode;
                          setSheetState(() {});
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const Key('mobile-group-search'),
                        onChanged: (value) {
                          mobileQuery = value.trim();
                          setSheetState(() {});
                        },
                        decoration: const InputDecoration(
                          hintText: '그룹 이름·설명 검색',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final group in groups.where((group) {
                        if (mobileQuery.isEmpty) return true;
                        return '${group.name} ${group.description}'
                            .toLowerCase()
                            .contains(mobileQuery.toLowerCase());
                      }))
                        ListTile(
                          key: Key('mobile-group-target-${group.name}'),
                          leading: Icon(
                            group.pinned
                                ? Icons.push_pin_rounded
                                : Icons.folder_outlined,
                            color: _learningGroupColor(
                              Theme.of(context).colorScheme,
                              group.colorKey,
                            ),
                          ),
                          title: Text(group.name),
                          subtitle: Text(
                            group.description.isEmpty
                                ? '${controller.itemsForLearningGroup(group.name).length}개 자료'
                                : '${group.description} · '
                                      '${controller.itemsForLearningGroup(group.name).length}개',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.pop(context, group.name),
                        ),
                      ListTile(
                        key: const Key('mobile-ungrouped-target'),
                        leading: const Icon(Icons.folder_off_outlined),
                        title: const Text('그룹 없음'),
                        subtitle: Text('$ungroupedCount개 자료'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pop(context, _ungroupedSource),
                      ),
                      ListTile(
                        key: const Key('mobile-create-group'),
                        leading: const Icon(Icons.create_new_folder_outlined),
                        title: const Text('새 그룹 만들기'),
                        trailing: const Icon(Icons.add_rounded),
                        onTap: () => Navigator.pop(context, '__create__'),
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
    if (target == null || !mounted) return;
    if (target == _ungroupedSource) {
      await _removeFromGroups(Set<String>.from(_selectedIds));
    } else if (target == '__create__') {
      await _createGroup(Set<String>.from(_selectedIds));
    } else {
      await _applyToGroup(Set<String>.from(_selectedIds), target);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _OrganizerHeader extends StatelessWidget {
  const _OrganizerHeader({
    required this.subjectName,
    required this.subjectSymbol,
    required this.split,
    required this.onBack,
  });

  final String subjectName;
  final String subjectSymbol;
  final bool split;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.outlined(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '자료실로 돌아가기',
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$subjectSymbol $subjectName 그룹 작업판',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 2),
              Text(
                split
                    ? '왼쪽 자료를 선택하거나 끌어서 오른쪽 그룹에 놓으세요.'
                    : '자료를 고른 다음 아래 버튼에서 그룹을 선택하세요.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourcePanel extends StatelessWidget {
  const _SourcePanel({
    required this.items,
    required this.groups,
    required this.customIds,
    required this.selectedIds,
    required this.hiddenSelectedCount,
    required this.source,
    required this.queryController,
    required this.enableDrag,
    required this.onQueryChanged,
    required this.onSourceChanged,
    required this.onToggleItem,
    required this.onSelectVisible,
    required this.onClearSelection,
    required this.dragPayloadFor,
  });

  final List<LearningItem> items;
  final List<String> groups;
  final Set<String> customIds;
  final Set<String> selectedIds;
  final int hiddenSelectedCount;
  final String source;
  final TextEditingController queryController;
  final bool enableDrag;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onToggleItem;
  final VoidCallback onSelectVisible;
  final VoidCallback onClearSelection;
  final _GroupDragPayload Function(String itemId) dragPayloadFor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visibleIds = items.map((item) => item.id).toSet();
    final allVisibleSelected =
        visibleIds.isNotEmpty && visibleIds.every(selectedIds.contains);
    return Card(
      key: const Key('group-organizer-source-panel'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.view_list_rounded, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '1. 옮길 자료',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (selectedIds.isNotEmpty) ...[
                      Text(
                        hiddenSelectedCount == 0
                            ? '${selectedIds.length}개 선택'
                            : '${selectedIds.length}개 선택 · 숨김 $hiddenSelectedCount',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      IconButton(
                        key: const Key('clear-group-selection'),
                        onPressed: onClearSelection,
                        icon: const Icon(Icons.close_rounded),
                        tooltip: '선택 모두 해제 (Esc)',
                      ),
                    ] else
                      Tooltip(
                        message: 'Ctrl+A 전체 선택 · Shift+클릭 범위 선택',
                        child: Icon(
                          Icons.keyboard_outlined,
                          color: colors.outline,
                          size: 20,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('group-organizer-search'),
                  controller: queryController,
                  onChanged: onQueryChanged,
                  decoration: const InputDecoration(
                    hintText: '단어, 뜻, 그룹 검색',
                    prefixIcon: Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: const Key('group-organizer-source-filter'),
                        initialValue: source,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '보여줄 자료',
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: _GroupOrganizerScreenState._allSource,
                            child: Text('모든 자료'),
                          ),
                          const DropdownMenuItem(
                            value: _GroupOrganizerScreenState._ungroupedSource,
                            child: Text('그룹 없는 자료'),
                          ),
                          for (final group in groups)
                            DropdownMenuItem(value: group, child: Text(group)),
                        ],
                        onChanged: (value) {
                          if (value != null) onSourceChanged(value);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      key: const Key('select-visible-group-items'),
                      onPressed: items.isEmpty ? null : onSelectVisible,
                      icon: Icon(
                        allVisibleSelected
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                      ),
                      label: Text(allVisibleSelected ? '현재 결과 해제' : '현재 결과 선택'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? const _OrganizerEmpty(
                    icon: Icons.search_off_rounded,
                    title: '조건에 맞는 자료가 없습니다',
                    detail: '검색어나 왼쪽 필터를 바꿔 보세요.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final tile = _OrganizerItemTile(
                        key: Key('group-organizer-item-${item.id}'),
                        item: item,
                        custom: customIds.contains(item.id),
                        selected: selectedIds.contains(item.id),
                        onToggle: () => onToggleItem(item.id),
                        showDragHandle: enableDrag,
                      );
                      if (!enableDrag) return tile;
                      final payload = dragPayloadFor(item.id);
                      return Draggable<_GroupDragPayload>(
                        data: payload,
                        feedback: _DragFeedback(
                          count: payload.itemIds.length,
                          label: item.text,
                        ),
                        childWhenDragging: Opacity(opacity: 0.35, child: tile),
                        child: tile,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MobileOrganizer extends StatelessWidget {
  const _MobileOrganizer({
    required this.items,
    required this.groups,
    required this.customIds,
    required this.selectedIds,
    required this.hiddenSelectedCount,
    required this.source,
    required this.queryController,
    required this.onQueryChanged,
    required this.onSourceChanged,
    required this.onToggleItem,
    required this.onSelectVisible,
    required this.onClearSelection,
    required this.onManageGroups,
    required this.selectionBar,
  });

  final List<LearningItem> items;
  final List<String> groups;
  final Set<String> customIds;
  final Set<String> selectedIds;
  final int hiddenSelectedCount;
  final String source;
  final TextEditingController queryController;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSourceChanged;
  final ValueChanged<String> onToggleItem;
  final VoidCallback onSelectVisible;
  final VoidCallback onClearSelection;
  final VoidCallback onManageGroups;
  final Widget? selectionBar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _SourcePanel(
            items: items,
            groups: groups,
            customIds: customIds,
            selectedIds: selectedIds,
            hiddenSelectedCount: hiddenSelectedCount,
            source: source,
            queryController: queryController,
            enableDrag: false,
            onQueryChanged: onQueryChanged,
            onSourceChanged: onSourceChanged,
            onToggleItem: onToggleItem,
            onSelectVisible: onSelectVisible,
            onClearSelection: onClearSelection,
            dragPayloadFor: (_) => const _GroupDragPayload({}),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 120),
          child: selectionBar == null
              ? Container(
                  key: const Key('mobile-group-selection-hint'),
                  constraints: const BoxConstraints(minHeight: 48),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Expanded(child: Text('목록에서 정리할 자료를 선택하세요')),
                      TextButton.icon(
                        key: const Key('mobile-manage-groups'),
                        onPressed: onManageGroups,
                        icon: const Icon(Icons.folder_copy_outlined),
                        label: const Text('그룹 관리'),
                      ),
                    ],
                  ),
                )
              : KeyedSubtree(
                  key: const Key('mobile-group-selection-bar'),
                  child: selectionBar!,
                ),
        ),
      ],
    );
  }
}

class _TargetPanel extends StatelessWidget {
  const _TargetPanel({
    required this.groups,
    required this.controller,
    required this.ungroupedCount,
    required this.selectedIds,
    required this.mode,
    required this.queryController,
    required this.groupQuery,
    required this.sort,
    required this.saving,
    required this.onModeChanged,
    required this.onDropGroup,
    required this.onDropUngrouped,
    required this.onCreateGroup,
    required this.onMoveSubject,
    required this.onRenameGroup,
    required this.onDeleteGroup,
    required this.onGroupQueryChanged,
    required this.onSortChanged,
    required this.onPinGroup,
    required this.onReorderGroups,
    required this.onStartGroup,
  });

  final List<LearningGroupDefinition> groups;
  final AppController controller;
  final int ungroupedCount;
  final Set<String> selectedIds;
  final _GroupTransferMode mode;
  final TextEditingController queryController;
  final String groupQuery;
  final _GroupSort sort;
  final bool saving;
  final ValueChanged<_GroupTransferMode> onModeChanged;
  final Future<void> Function(Set<String> itemIds, String group) onDropGroup;
  final Future<void> Function(Set<String> itemIds) onDropUngrouped;
  final Future<void> Function([Set<String>? itemIds]) onCreateGroup;
  final VoidCallback onMoveSubject;
  final Future<void> Function(String group) onRenameGroup;
  final Future<void> Function(String group) onDeleteGroup;
  final ValueChanged<String> onGroupQueryChanged;
  final ValueChanged<_GroupSort> onSortChanged;
  final Future<void> Function(String group, bool pinned) onPinGroup;
  final Future<void> Function(int oldIndex, int newIndex) onReorderGroups;
  final void Function(String group, {required bool memorize}) onStartGroup;

  @override
  Widget build(BuildContext context) {
    final visibleGroups = groups
        .where((group) {
          if (groupQuery.isEmpty) return true;
          final haystack = '${group.name} ${group.description}'.toLowerCase();
          return haystack.contains(groupQuery.toLowerCase());
        })
        .toList(growable: true);
    int comparePinned(
      LearningGroupDefinition left,
      LearningGroupDefinition right,
    ) {
      return (right.pinned ? 1 : 0).compareTo(left.pinned ? 1 : 0);
    }

    switch (sort) {
      case _GroupSort.manual:
        break;
      case _GroupSort.name:
        visibleGroups.sort((left, right) {
          final pinned = comparePinned(left, right);
          return pinned != 0 ? pinned : left.name.compareTo(right.name);
        });
      case _GroupSort.itemCount:
        visibleGroups.sort((left, right) {
          final pinned = comparePinned(left, right);
          if (pinned != 0) return pinned;
          final leftCount =
              controller.learningGroupSummary(left.name)?.totalCount ?? 0;
          final rightCount =
              controller.learningGroupSummary(right.name)?.totalCount ?? 0;
          final countOrder = rightCount.compareTo(leftCount);
          return countOrder != 0 ? countOrder : left.name.compareTo(right.name);
        });
    }
    Widget groupCard(LearningGroupDefinition group, {int? reorderIndex}) {
      final summary = controller.learningGroupSummary(group.name);
      final count = summary?.totalCount ?? 0;
      final detail = group.description.isEmpty
          ? '$count개 · 단어 ${summary?.wordCount ?? 0} · '
                '문장 ${summary?.sentenceCount ?? 0}'
          : '${group.description} · $count개';
      return Padding(
        key: ValueKey('group-definition-${group.id}'),
        padding: const EdgeInsets.only(bottom: 8),
        child: _DropGroupCard(
          key: Key('group-organizer-target-${group.name}'),
          icon: group.pinned ? Icons.push_pin_rounded : Icons.folder_outlined,
          title: group.name,
          detail: detail,
          colorKey: group.colorKey,
          pinned: group.pinned,
          selectedItemIds: selectedIds,
          saving: saving,
          onDrop: (ids) => onDropGroup(ids, group.name),
          onRename: () => onRenameGroup(group.name),
          onDelete: () => onDeleteGroup(group.name),
          onPin: () => onPinGroup(group.name, !group.pinned),
          onMemorize: count == 0
              ? null
              : () => onStartGroup(group.name, memorize: true),
          onQuiz: count == 0
              ? null
              : () => onStartGroup(group.name, memorize: false),
          reorderIndex: reorderIndex,
        ),
      );
    }

    final allowManualReorder = sort == _GroupSort.manual && groupQuery.isEmpty;
    final groupSliver = visibleGroups.isEmpty
        ? SliverFillRemaining(
            hasScrollBody: false,
            child: _OrganizerEmpty(
              icon: groups.isEmpty
                  ? Icons.create_new_folder_outlined
                  : Icons.search_off_rounded,
              title: groups.isEmpty ? '아직 만든 그룹이 없습니다' : '검색 결과가 없습니다',
              detail: groups.isEmpty
                  ? '빈 그룹을 먼저 만들거나 자료를 선택해 바로 넣어 보세요.'
                  : '다른 그룹 이름이나 설명을 검색해 보세요.',
            ),
          )
        : allowManualReorder
        ? SliverReorderableList(
            itemCount: visibleGroups.length,
            onReorderItem: onReorderGroups,
            itemBuilder: (context, index) =>
                groupCard(visibleGroups[index], reorderIndex: index),
          )
        : SliverList.builder(
            itemCount: visibleGroups.length,
            itemBuilder: (context, index) => groupCard(visibleGroups[index]),
          );

    return Card(
      key: const Key('group-organizer-target-panel'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder_copy_outlined,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '2. 넣을 그룹',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton.filledTonal(
                  key: const Key('organizer-move-items-to-subject'),
                  onPressed: selectedIds.isEmpty || saving
                      ? null
                      : onMoveSubject,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  tooltip: '선택 자료를 다른 학습 주제로 이동',
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  key: const Key('create-learning-group'),
                  onPressed: saving ? null : () => onCreateGroup(),
                  icon: const Icon(Icons.create_new_folder_outlined),
                  tooltip: selectedIds.isEmpty
                      ? '빈 학습 그룹 만들기'
                      : '선택한 자료로 새 학습 그룹 만들기',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CustomScrollView(
                key: const Key('group-organizer-target-scroll'),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<_GroupTransferMode>(
                          key: const Key('group-transfer-mode'),
                          segments: const [
                            ButtonSegment(
                              value: _GroupTransferMode.add,
                              icon: Icon(Icons.add_rounded),
                              label: Text('추가'),
                              tooltip: '기존 그룹을 유지합니다.',
                            ),
                            ButtonSegment(
                              value: _GroupTransferMode.move,
                              icon: Icon(Icons.drive_file_move_outline),
                              label: Text('이동'),
                              tooltip: '기존 그룹을 해제합니다.',
                            ),
                          ],
                          selected: {mode},
                          onSelectionChanged: saving
                              ? null
                              : (value) => onModeChanged(value.first),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          mode == _GroupTransferMode.add
                              ? '기존 그룹을 유지하고 새 그룹을 하나 더 붙입니다.'
                              : '기존 그룹을 모두 해제하고 선택한 그룹으로 옮깁니다.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                key: const Key('group-organizer-group-search'),
                                controller: queryController,
                                onChanged: onGroupQueryChanged,
                                decoration: const InputDecoration(
                                  hintText: '그룹 이름·설명 검색',
                                  prefixIcon: Icon(Icons.search_rounded),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: '그룹 정렬',
                              child: DropdownButton<_GroupSort>(
                                key: const Key('group-organizer-sort'),
                                value: sort,
                                items: [
                                  for (final value in _GroupSort.values)
                                    DropdownMenuItem(
                                      value: value,
                                      child: Text(value.label),
                                    ),
                                ],
                                onChanged: saving
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          onSortChanged(value);
                                        }
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer
                                .withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          child: _DropGroupCard(
                            key: const Key('group-organizer-ungrouped-target'),
                            icon: Icons.folder_off_outlined,
                            title: '그룹 연결 해제',
                            detail: '$ungroupedCount개 자료가 현재 그룹 없음',
                            selectedItemIds: selectedIds,
                            saving: saving,
                            destructive: true,
                            onDrop: onDropUngrouped,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
                          child: Text(
                            '학습 그룹 ${groups.length}개',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                  groupSliver,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropGroupCard extends StatefulWidget {
  const _DropGroupCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.selectedItemIds,
    required this.saving,
    required this.onDrop,
    this.colorKey = 'teal',
    this.pinned = false,
    this.destructive = false,
    this.onRename,
    this.onDelete,
    this.onPin,
    this.onMemorize,
    this.onQuiz,
    this.reorderIndex,
    super.key,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Set<String> selectedItemIds;
  final bool saving;
  final Future<void> Function(Set<String> itemIds) onDrop;
  final String colorKey;
  final bool pinned;
  final bool destructive;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final VoidCallback? onPin;
  final VoidCallback? onMemorize;
  final VoidCallback? onQuiz;
  final int? reorderIndex;

  @override
  State<_DropGroupCard> createState() => _DropGroupCardState();
}

class _DropGroupCardState extends State<_DropGroupCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final groupColor = _learningGroupColor(colors, widget.colorKey);
    return DragTarget<_GroupDragPayload>(
      onWillAcceptWithDetails: (details) {
        if (widget.saving || details.data.itemIds.isEmpty) return false;
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        unawaited(widget.onDrop(details.data.itemIds));
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: _hovering
                ? colors.primaryContainer
                : widget.destructive
                ? colors.errorContainer.withValues(alpha: 0.18)
                : groupColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovering
                  ? colors.primary
                  : widget.destructive
                  ? colors.error.withValues(alpha: 0.5)
                  : colors.outlineVariant,
              width: _hovering ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 6, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      _hovering ? Icons.move_to_inbox_rounded : widget.icon,
                      color: _hovering
                          ? colors.primary
                          : widget.destructive
                          ? colors.error
                          : groupColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hovering
                                ? '${candidateData.isEmpty ? 0 : candidateData.first?.itemIds.length ?? 0}개 놓기'
                                : widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (widget.reorderIndex case final index?)
                      ReorderableDragStartListener(
                        index: index,
                        child: const Tooltip(
                          message: '그룹 순서 바꾸기',
                          child: SizedBox.square(
                            dimension: 44,
                            child: Icon(Icons.drag_indicator_rounded),
                          ),
                        ),
                      ),
                    if (widget.onRename != null ||
                        widget.onDelete != null ||
                        widget.onPin != null)
                      PopupMenuButton<String>(
                        tooltip: '${widget.title} 그룹 관리',
                        onSelected: (value) {
                          if (value == 'memorize') widget.onMemorize?.call();
                          if (value == 'quiz') widget.onQuiz?.call();
                          if (value == 'pin') widget.onPin?.call();
                          if (value == 'rename') widget.onRename?.call();
                          if (value == 'delete') widget.onDelete?.call();
                        },
                        itemBuilder: (context) => [
                          if (widget.onMemorize != null)
                            const PopupMenuItem(
                              value: 'memorize',
                              child: Text('바로 암기'),
                            ),
                          if (widget.onQuiz != null)
                            const PopupMenuItem(
                              value: 'quiz',
                              child: Text('바로 퀴즈'),
                            ),
                          if (widget.onPin != null)
                            PopupMenuItem(
                              value: 'pin',
                              child: Text(widget.pinned ? '고정 해제' : '위에 고정'),
                            ),
                          if (widget.onRename != null)
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('이름·설명 변경'),
                            ),
                          if (widget.onDelete != null)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('그룹 삭제'),
                            ),
                        ],
                      ),
                  ],
                ),
                if (widget.selectedItemIds.isNotEmpty ||
                    widget.onMemorize != null ||
                    widget.onQuiz != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    alignment: WrapAlignment.end,
                    children: [
                      if (widget.onMemorize != null)
                        TextButton.icon(
                          onPressed: widget.saving ? null : widget.onMemorize,
                          icon: const Icon(Icons.style_rounded, size: 17),
                          label: const Text('암기'),
                        ),
                      if (widget.onQuiz != null)
                        TextButton.icon(
                          onPressed: widget.saving ? null : widget.onQuiz,
                          icon: const Icon(Icons.quiz_outlined, size: 17),
                          label: const Text('퀴즈'),
                        ),
                      if (widget.selectedItemIds.isNotEmpty)
                        FilledButton.tonalIcon(
                          onPressed: widget.saving
                              ? null
                              : () => widget.onDrop(
                                  Set<String>.from(widget.selectedItemIds),
                                ),
                          icon: Icon(
                            widget.destructive
                                ? Icons.link_off_rounded
                                : Icons.move_to_inbox_rounded,
                            size: 17,
                          ),
                          label: Text(widget.destructive ? '연결 해제' : '여기에 넣기'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrganizerItemTile extends StatelessWidget {
  const _OrganizerItemTile({
    required this.item,
    required this.custom,
    required this.selected,
    required this.onToggle,
    required this.showDragHandle,
    super.key,
  });

  final LearningItem item;
  final bool custom;
  final bool selected;
  final VoidCallback onToggle;
  final bool showDragHandle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final groups = learningGroupsOf(item).toList()..sort();
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: 0.55)
          : Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
            child: Row(
              children: [
                Checkbox(value: selected, onChanged: (_) => onToggle()),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: custom
                                  ? colors.tertiaryContainer
                                  : colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              custom ? '내 저장본' : '기본팩',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          item.primaryTranslation,
                          if (groups.isEmpty)
                            '그룹 없음'
                          else
                            groups.take(2).join(', '),
                          if (groups.length > 2) '+${groups.length - 2}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (showDragHandle) ...[
                  const SizedBox(width: 7),
                  Tooltip(
                    message: '오른쪽 그룹으로 끌기',
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: colors.outline,
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

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.drag_indicator_rounded),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  count > 1 ? '$count개 자료' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupEditorResult {
  const _GroupEditorResult({
    required this.name,
    required this.description,
    required this.colorKey,
  });

  final String name;
  final String description;
  final String colorKey;
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupNameDialog extends StatefulWidget {
  const _GroupNameDialog({
    this.title = '새 그룹 만들기',
    this.initialValue = '',
    this.initialDescription = '',
    this.initialColorKey = 'teal',
    this.confirmLabel = '만들기',
  });

  final String title;
  final String initialValue;
  final String initialDescription;
  final String initialColorKey;
  final String confirmLabel;

  @override
  State<_GroupNameDialog> createState() => _GroupNameDialogState();
}

class _GroupNameDialogState extends State<_GroupNameDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String _colorKey;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialValue);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _colorKey = learningGroupColorKeys.contains(widget.initialColorKey)
        ? widget.initialColorKey
        : 'teal';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final name = normalizeLearningGroupName(_nameController.text);
      final description = _descriptionController.text.trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      if (description.runes.length > 120) {
        throw const FormatException('학습 그룹 설명은 120자 이하여야 합니다.');
      }
      Navigator.pop(
        context,
        _GroupEditorResult(
          name: name,
          description: description,
          colorKey: _colorKey,
        ),
      );
    } on FormatException catch (error) {
      setState(() => _error = error.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('group-organizer-name-input'),
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: '그룹 이름',
                hintText: '예: 이번 주 여행 표현',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('group-organizer-description-input'),
              controller: _descriptionController,
              maxLength: 120,
              maxLines: 2,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: '설명',
                hintText: '언제, 무엇을 공부할 그룹인지 적어 보세요',
              ),
            ),
            const SizedBox(height: 8),
            Text('색상', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in learningGroupColorKeys)
                  Semantics(
                    label: '그룹 색상 $key',
                    selected: _colorKey == key,
                    child: InkWell(
                      onTap: () => setState(() => _colorKey = key),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _learningGroupColor(
                            Theme.of(context).colorScheme,
                            key,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _colorKey == key
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: _colorKey == key
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
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
          key: const Key('confirm-group-organizer-name'),
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _OrganizerEmpty extends StatelessWidget {
  const _OrganizerEmpty({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 38, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 3),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
