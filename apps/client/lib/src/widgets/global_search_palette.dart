import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/global_search.dart';
import '../domain/content_management.dart';
import '../domain/learning_item.dart';
import '../domain/local_search_query.dart';
import '../domain/search_preferences.dart';
import '../domain/study_preferences.dart';
import '../state/app_state.dart';
import 'highlighted_search_text.dart';

enum _GlobalSearchAction { open, edit, addToGroup, studyNow }

class _GlobalSearchCommand {
  const _GlobalSearchCommand(this.result, this.action);

  final GlobalSearchResult result;
  final _GlobalSearchAction action;
}

Future<void> showGlobalSearchPalette(
  BuildContext context,
  WidgetRef ref,
) async {
  final command = await showDialog<_GlobalSearchCommand>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => const _GlobalSearchDialog(),
  );
  if (command == null || !context.mounted) return;
  final controller = ref.read(appControllerProvider.notifier);
  controller.selectSubject(command.result.subject.id);
  final item = switch (command.result) {
    GlobalItemSearchResult(:final item) => item,
    GlobalSubjectSearchResult() => null,
  };
  switch (command.action) {
    case _GlobalSearchAction.open:
      final query = item == null
          ? ''
          : '&q=${Uri.encodeQueryComponent(item.text)}';
      context.go(
        '/library?subject=${Uri.encodeQueryComponent(command.result.subject.id)}$query',
      );
    case _GlobalSearchAction.edit:
      if (item == null) return;
      if (controller.customItemById(item.id) != null) {
        context.go('/library/edit/${Uri.encodeComponent(item.id)}');
      } else {
        await _editStarterCorrection(context, ref, item);
      }
    case _GlobalSearchAction.addToGroup:
      if (item == null) return;
      final group = await _chooseGroup(context, ref);
      if (group == null || !context.mounted) return;
      await controller.organizeItemsInLearningGroup(
        [item.id],
        group,
        copy: true,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('“${item.text}”을 $group 그룹에 추가했어요.')),
      );
    case _GlobalSearchAction.studyNow:
      if (item == null) return;
      controller.updateSessionPlan(
        StudySessionPlan(
          subjectId: command.result.subject.id,
          title: '${item.text} 바로 학습',
          deck: StudyDeckScope.selected,
          selectedItemIds: {item.id},
          itemLimit: 1,
        ),
      );
      context.go('/study?custom=true&limit=1');
  }
}

Future<void> _editStarterCorrection(
  BuildContext context,
  WidgetRef ref,
  LearningItem item,
) async {
  final controller = ref.read(appControllerProvider.notifier);
  final current = controller.contentCorrectionFor(item.id);
  final noteController = TextEditingController(text: current?.note ?? '');
  final valueController = TextEditingController(
    text: current?.proposedValue ?? '',
  );
  try {
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('“${item.text}” 교정 메모'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('기본 언어팩 원본은 유지하고 이 메모만 로컬·Drive에 저장합니다.'),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: '무엇을 고쳐야 하나요?'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueController,
                  maxLength: 300,
                  decoration: const InputDecoration(labelText: '제안 값 (선택)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('메모 저장'),
          ),
        ],
      ),
    );
    if (save != true || !context.mounted) return;
    final note = noteController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('교정 내용을 입력해 주세요.')));
      return;
    }
    await controller.upsertContentCorrection(
      ContentCorrection(
        itemId: item.id,
        field: current?.field ?? 'content',
        note: note,
        proposedValue: valueController.text.trim().isEmpty
            ? null
            : valueController.text.trim(),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('교정 메모를 저장했어요.')));
  } finally {
    noteController.dispose();
    valueController.dispose();
  }
}

Future<String?> _chooseGroup(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(appControllerProvider.notifier);
  final existing = controller.availableLearningGroups;
  final newGroupController = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('그룹에 추가'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final group in existing)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(group),
                    onTap: () => Navigator.pop(context, group),
                  ),
                if (existing.isNotEmpty) const Divider(),
                TextField(
                  controller: newGroupController,
                  autofocus: existing.isEmpty,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: '새 그룹 이름',
                    hintText: '예: 출장 회화',
                  ),
                  onSubmitted: (value) {
                    final normalized = value.trim();
                    if (normalized.isNotEmpty) {
                      Navigator.pop(context, normalized);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final normalized = newGroupController.text.trim();
              if (normalized.isNotEmpty) Navigator.pop(context, normalized);
            },
            child: const Text('새 그룹에 추가'),
          ),
        ],
      ),
    );
  } finally {
    newGroupController.dispose();
  }
}

class _GlobalSearchDialog extends ConsumerStatefulWidget {
  const _GlobalSearchDialog();

  @override
  ConsumerState<_GlobalSearchDialog> createState() =>
      _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends ConsumerState<_GlobalSearchDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  var _query = '';
  var _searchPreferences = const SearchLocalPreferences();

  @override
  void initState() {
    super.initState();
    _loadSearchPreferences();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _return(GlobalSearchResult result, _GlobalSearchAction action) {
    unawaited(_rememberQuery(_query));
    Navigator.of(context).pop(_GlobalSearchCommand(result, action));
  }

  Future<void> _loadSearchPreferences() async {
    final preferences = await ref
        .read(studyStoreProvider)
        .loadSearchLocalPreferences();
    if (!mounted) return;
    setState(() => _searchPreferences = preferences);
  }

  Future<void> _rememberQuery(String query) async {
    final next = _searchPreferences.rememberGlobal(query);
    if (identical(next, _searchPreferences) || !mounted) return;
    setState(() => _searchPreferences = next);
    await ref.read(studyStoreProvider).saveSearchLocalPreferences(next);
  }

  Future<void> _removeRecentQuery(String query) async {
    final next = _searchPreferences.removeGlobal(query);
    if (!mounted) return;
    setState(() => _searchPreferences = next);
    await ref.read(studyStoreProvider).saveSearchLocalPreferences(next);
  }

  Future<void> _setResultLayout(GlobalSearchResultLayout layout) async {
    final next = _searchPreferences.copyWith(globalResultLayout: layout);
    setState(() => _searchPreferences = next);
    await ref.read(studyStoreProvider).saveSearchLocalPreferences(next);
  }

  void _applyQuery(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    setState(() => _query = query);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final subjects = controller.availableSubjects;
    final visibleSubjectIds = subjects.map((subject) => subject.id).toSet();
    final visibleItems = controller.allContentItems
        .where((item) => visibleSubjectIds.contains(item.effectiveSubjectId))
        .toList(growable: false);
    final results = searchAcrossSubjects(
      query: _query,
      subjects: subjects,
      items: visibleItems,
      progressById: state.progress,
      favoriteItemIds: state.preferences.favoriteItemIds,
      excludedItemIds: state.preferences.excludedItemIds,
    );
    final similar = results.isEmpty && _query.trim().isNotEmpty
        ? suggestSimilarSearches(
            query: _query,
            candidates: visibleItems.expand(
              (item) => [item.text, ...item.translations],
            ),
          )
        : const <String>[];
    final isDesktop =
        defaultTargetPlatform == TargetPlatform.windows &&
        MediaQuery.sizeOf(context).width >= 700;
    final content = Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('global-search-field'),
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: '모든 주제의 표현·뜻·읽기·예문 검색',
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                key: const Key('clear-global-search'),
                                tooltip: '검색어 지우기',
                                onPressed: () => _applyQuery(''),
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                      onChanged: (value) => setState(() => _query = value),
                      onSubmitted: _rememberQuery,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _query.trim().isEmpty
                          ? '검색어를 입력하세요 · tag: type: state: group: 사용 가능'
                          : '결과 ${results.length}개 · Enter로 열고 메뉴에서 수정·그룹·학습',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  if (results.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _SearchLayoutToggle(
                      value: _searchPreferences.globalResultLayout,
                      onChanged: _setResultLayout,
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 12),
            Expanded(
              child: _query.trim().isEmpty
                  ? _GlobalSearchEmpty(
                      recent: _searchPreferences.globalRecent,
                      suggestions: const [
                        'state:due',
                        'state:favorite',
                        'type:sentence',
                        'tag:여행',
                      ],
                      onSelected: _applyQuery,
                      onDeleted: _removeRecentQuery,
                    )
                  : results.isEmpty
                  ? _NoGlobalSearchResults(
                      suggestions: similar,
                      onSelected: _applyQuery,
                    )
                  : _GlobalSearchResults(
                      results: results,
                      query: _query,
                      layout: _searchPreferences.globalResultLayout,
                      onAction: _return,
                    ),
            ),
          ],
        ),
      ),
    );
    if (!isDesktop) return Dialog.fullscreen(child: content);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(width: 720, height: 620, child: content),
    );
  }
}

class _GlobalSearchResultTile extends StatelessWidget {
  const _GlobalSearchResultTile({
    required this.result,
    required this.query,
    required this.autofocus,
    required this.onAction,
  });

  final GlobalSearchResult result;
  final String query;
  final bool autofocus;
  final ValueChanged<_GlobalSearchAction> onAction;

  @override
  Widget build(BuildContext context) {
    final item = switch (result) {
      GlobalItemSearchResult(:final item) => item,
      GlobalSubjectSearchResult() => null,
    };
    return ListTile(
      autofocus: autofocus,
      minTileHeight: 58,
      leading: CircleAvatar(
        child: Text(
          item == null
              ? result.subject.symbol
              : item.kind == LearningItemKind.word
              ? 'W'
              : 'S',
        ),
      ),
      title: HighlightedSearchText(
        item?.text ?? result.subject.name,
        query: query,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: HighlightedSearchText(
        item == null
            ? result.subject.description
            : '${result.subject.name} · ${item.primaryTranslation}'
                  '${item.readingAidsLabel.isEmpty ? '' : '\n${item.readingAidsLabel}'}',
        query: query,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => onAction(_GlobalSearchAction.open),
      trailing: item == null
          ? const Icon(Icons.arrow_forward_rounded)
          : PopupMenuButton<_GlobalSearchAction>(
              tooltip: '자료 작업',
              onSelected: onAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: _GlobalSearchAction.open,
                  child: Text('자료실에서 열기'),
                ),
                PopupMenuItem(
                  value: _GlobalSearchAction.edit,
                  child: const Text('수정 또는 교정 메모'),
                ),
                const PopupMenuItem(
                  value: _GlobalSearchAction.addToGroup,
                  child: Text('그룹에 추가'),
                ),
                const PopupMenuItem(
                  value: _GlobalSearchAction.studyNow,
                  child: Text('바로 학습'),
                ),
              ],
            ),
    );
  }
}

class _GlobalSearchResults extends StatelessWidget {
  const _GlobalSearchResults({
    required this.results,
    required this.query,
    required this.layout,
    required this.onAction,
  });

  final List<GlobalSearchResult> results;
  final String query;
  final GlobalSearchResultLayout layout;
  final void Function(GlobalSearchResult, _GlobalSearchAction) onAction;

  @override
  Widget build(BuildContext context) {
    if (layout == GlobalSearchResultLayout.score) {
      return ListView.builder(
        key: const Key('global-search-results'),
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final result = results[index];
          return _GlobalSearchResultTile(
            result: result,
            query: query,
            autofocus: index == 0,
            onAction: (action) => onAction(result, action),
          );
        },
      );
    }
    final grouped = <String, List<GlobalSearchResult>>{};
    for (final result in results) {
      grouped.putIfAbsent(result.subject.id, () => []).add(result);
    }
    final groups = grouped.values.toList()
      ..sort(
        (left, right) =>
            left.first.subject.name.compareTo(right.first.subject.name),
      );
    var autofocusAssigned = false;
    return ListView(
      key: const Key('global-search-results'),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      children: [
        for (final group in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
            child: Text(
              '${group.first.subject.symbol} ${group.first.subject.name} · ${group.length}',
              key: Key('global-search-group-${group.first.subject.id}'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (final result in group)
            _GlobalSearchResultTile(
              result: result,
              query: query,
              autofocus: !autofocusAssigned && (autofocusAssigned = true),
              onAction: (action) => onAction(result, action),
            ),
        ],
      ],
    );
  }
}

class _SearchLayoutToggle extends StatelessWidget {
  const _SearchLayoutToggle({required this.value, required this.onChanged});

  final GlobalSearchResultLayout value;
  final ValueChanged<GlobalSearchResultLayout> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<GlobalSearchResultLayout>(
      key: const Key('global-search-layout-toggle'),
      segments: const [
        ButtonSegment(
          value: GlobalSearchResultLayout.score,
          icon: Icon(Icons.auto_awesome_rounded, size: 16),
          label: Text('점수'),
          tooltip: '일치 점수순',
        ),
        ButtonSegment(
          value: GlobalSearchResultLayout.subject,
          icon: Icon(Icons.view_agenda_outlined, size: 16),
          label: Text('주제'),
          tooltip: '주제별 그룹',
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selected) => onChanged(selected.single),
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _NoGlobalSearchResults extends StatelessWidget {
  const _NoGlobalSearchResults({
    required this.suggestions,
    required this.onSelected,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 40),
            const SizedBox(height: 10),
            const Text('일치하는 자료가 없어요.'),
            if (suggestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('비슷한 로컬 자료', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in suggestions)
                    ActionChip(
                      key: Key('global-search-similar-$suggestion'),
                      label: Text(suggestion),
                      onPressed: () => onSelected(suggestion),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlobalSearchEmpty extends StatelessWidget {
  const _GlobalSearchEmpty({
    required this.recent,
    required this.suggestions,
    required this.onSelected,
    required this.onDeleted,
  });

  final List<String> recent;
  final List<String> suggestions;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onDeleted;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.manage_search_rounded, size: 44),
            const SizedBox(height: 12),
            Text(
              '주제를 바꾸지 않고 전체 자료를 찾을 수 있어요.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              '표현·뜻·읽는 법·예문·태그를 검색한 뒤 열기, 수정, 그룹 추가, 바로 학습을 실행하세요.',
              textAlign: TextAlign.center,
            ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('전체 최근 검색', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final query in recent)
                    InputChip(
                      key: Key('global-recent-search-$query'),
                      label: Text(query),
                      onPressed: () => onSelected(query),
                      onDeleted: () => onDeleted(query),
                      deleteButtonTooltipMessage: '최근 검색에서 삭제',
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Text('빠른 제안', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in suggestions)
                  ActionChip(
                    key: Key('global-search-suggestion-$suggestion'),
                    label: Text(suggestion),
                    onPressed: () => onSelected(suggestion),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
