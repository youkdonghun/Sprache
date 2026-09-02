import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../domain/command_palette.dart';
import '../domain/global_search.dart';
import '../domain/content_management.dart';
import '../domain/learning_item.dart';
import '../domain/local_search_query.dart';
import '../domain/search_preferences.dart';
import '../domain/study_preferences.dart';
import '../state/app_state.dart';
import '../state/navigation_guard_state.dart';
import 'highlighted_search_text.dart';
import 'quick_content_result_handler.dart';
import 'quick_content_sheet.dart';

enum _GlobalSearchAction { open, edit, addToGroup, studyNow }

sealed class _GlobalPaletteSelection {
  const _GlobalPaletteSelection();
}

class _GlobalSearchCommand extends _GlobalPaletteSelection {
  const _GlobalSearchCommand(this.result, this.action);

  final GlobalSearchResult result;
  final _GlobalSearchAction action;
}

class _GlobalCommandSelection extends _GlobalPaletteSelection {
  const _GlobalCommandSelection(this.command);

  final CommandPaletteCommand command;
}

Future<void> showGlobalSearchPalette(
  BuildContext context,
  WidgetRef ref,
) async {
  final selection = await showDialog<_GlobalPaletteSelection>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => const _GlobalSearchDialog(),
  );
  if (selection == null || !context.mounted) return;
  if (selection case _GlobalCommandSelection(:final command)) {
    if (command.id == 'quick-add') {
      final result = await showQuickContentSheet(context: context);
      if (!context.mounted) return;
      await handleQuickContentResult(
        context: context,
        ref: ref,
        result: result,
      );
      return;
    }
    if (command.practiceActivityId case final activityId?) {
      final canNavigate = await ref.read(navigationGuardProvider).canNavigate();
      if (context.mounted && canNavigate) {
        context.go(
          '/learn?launch=${Uri.encodeQueryComponent(activityId)}&'
          'request=${DateTime.now().microsecondsSinceEpoch}',
        );
      }
      return;
    }
    if (command.route case final route?) {
      final canNavigate = await ref.read(navigationGuardProvider).canNavigate();
      if (context.mounted && canNavigate) context.go(route);
    }
    return;
  }
  final command = selection as _GlobalSearchCommand;
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
                const Text('기본 언어팩은 바꾸지 않고, 내 교정 메모만 저장해요.'),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  autofocus: true,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: '어떤 부분을 고칠까요?'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valueController,
                  maxLength: 300,
                  decoration: const InputDecoration(labelText: '추천 수정값 (선택)'),
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
  static const _searchDelay = Duration(milliseconds: 180);

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _searchDebounce;
  var _query = '';
  var _selectedCommandIndex = 0;
  var _searchPreferences = const SearchLocalPreferences();
  var _results = const <GlobalSearchResult>[];
  var _similar = const <String>[];
  var _searching = false;
  var _searchRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadSearchPreferences();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchRequest += 1;
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _return(GlobalSearchResult result, _GlobalSearchAction action) {
    unawaited(_rememberQuery(_query));
    Navigator.of(context).pop(_GlobalSearchCommand(result, action));
  }

  void _returnCommand(CommandPaletteCommand command) {
    if (_query.trim().isNotEmpty) unawaited(_rememberQuery(_query));
    Navigator.of(context).pop(_GlobalCommandSelection(command));
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
    _onQueryChanged(query, immediately: true);
    _focusNode.requestFocus();
  }

  void _onQueryChanged(String value, {bool immediately = false}) {
    _searchDebounce?.cancel();
    final request = ++_searchRequest;
    final normalized = value.trim();
    setState(() {
      _query = value;
      _selectedCommandIndex = 0;
      _searching = normalized.isNotEmpty;
      if (normalized.isEmpty) {
        _results = const [];
        _similar = const [];
      }
    });
    if (normalized.isEmpty) return;
    _searchDebounce = Timer(
      immediately ? Duration.zero : _searchDelay,
      () => unawaited(_runSearch(request, normalized)),
    );
  }

  Future<void> _runSearch(int request, String query) async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted || request != _searchRequest) return;
    final controller = ref.read(appControllerProvider.notifier);
    final subjects = controller.availableSubjects;
    final visibleSubjectIds = subjects.map((subject) => subject.id).toSet();
    final visibleItems = controller.allContentItems.where(
      (item) => visibleSubjectIds.contains(item.effectiveSubjectId),
    );
    final state = ref.read(appControllerProvider);
    final results = await searchAcrossSubjectsCooperatively(
      query: query,
      subjects: subjects,
      items: visibleItems,
      progressById: state.progress,
      favoriteItemIds: state.preferences.favoriteItemIds,
      excludedItemIds: state.preferences.excludedItemIds,
      isCancelled: () => !mounted || request != _searchRequest,
    );
    if (!mounted || request != _searchRequest) return;
    final similar = results.isEmpty
        ? suggestSimilarSearches(
            query: query,
            candidates: controller.allContentItems
                .take(2500)
                .expand((item) => [item.text, ...item.translations]),
          )
        : const <String>[];
    if (!mounted || request != _searchRequest) return;
    setState(() {
      _results = results;
      _similar = similar;
      _searching = false;
    });
  }

  void _moveCommandSelection(int delta, int commandCount) {
    if (commandCount <= 0) return;
    setState(() {
      _selectedCommandIndex =
          (_selectedCommandIndex + delta + commandCount) % commandCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final commandResults = searchCommandPalette(
      _query,
      limit: _query.trim().isEmpty ? 4 : 5,
    );
    final selectedCommandIndex = commandResults.isEmpty
        ? 0
        : _selectedCommandIndex.clamp(0, commandResults.length - 1);
    final similar = _similar;
    final desktopPlatform =
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
    final isDesktop =
        desktopPlatform && MediaQuery.sizeOf(context).width >= 700;
    final content = CallbackShortcuts(
      bindings: {
        SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _moveCommandSelection(1, commandResults.length),
        SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _moveCommandSelection(-1, commandResults.length),
      },
      child: Material(
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
                          prefixIcon: const Icon(Icons.manage_search_rounded),
                          hintText: '찾을 단어나 실행할 기능 입력',
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  key: const Key('clear-global-search'),
                                  tooltip: '검색어 지우기',
                                  onPressed: () => _applyQuery(''),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                        onChanged: _onQueryChanged,
                        onSubmitted: (value) {
                          if (commandResults.isNotEmpty) {
                            _returnCommand(
                              commandResults[selectedCommandIndex],
                            );
                          } else if (value.trim().isNotEmpty &&
                              results.isNotEmpty) {
                            _return(results.first, _GlobalSearchAction.open);
                          } else {
                            unawaited(_rememberQuery(value));
                          }
                        },
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _query.trim().isEmpty
                            ? '기능을 바로 실행하거나 모든 주제의 자료를 찾아보세요'
                            : _searching
                            ? '바로가기 ${commandResults.length}개 · 자료 검색 중…'
                            : '바로가기 ${commandResults.length}개 · 자료 ${results.length}개 · ↑↓ 이동 · Enter 실행',
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
              if (_searching)
                const LinearProgressIndicator(
                  key: Key('global-search-progress'),
                  minHeight: 2,
                ),
              if (commandResults.isNotEmpty)
                _CommandPaletteResults(
                  commands: commandResults,
                  query: _query,
                  selectedIndex: selectedCommandIndex,
                  onSelected: _returnCommand,
                ),
              if (commandResults.isNotEmpty) const Divider(height: 1),
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

class _CommandPaletteResults extends StatelessWidget {
  const _CommandPaletteResults({
    required this.commands,
    required this.query,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<CommandPaletteCommand> commands;
  final String query;
  final int selectedIndex;
  final ValueChanged<CommandPaletteCommand> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final height = (38 + commands.length * 58).clamp(96, 270).toDouble();
    return SizedBox(
      key: const Key('command-palette-results'),
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 9, 18, 5),
            child: Text(
              query.trim().isEmpty ? '빠른 실행' : '바로가기',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              itemCount: commands.length,
              itemBuilder: (context, index) {
                final command = commands[index];
                return Semantics(
                  button: true,
                  label: '${command.title}. ${command.description}',
                  child: ListTile(
                    key: Key('command-palette-${command.id}'),
                    dense: true,
                    selected: index == selectedIndex,
                    selectedTileColor: colors.primaryContainer.withValues(
                      alpha: 0.42,
                    ),
                    minTileHeight: 54,
                    leading: Icon(
                      _commandIcon(command.id),
                      color: colors.primary,
                    ),
                    title: HighlightedSearchText(
                      command.title,
                      query: query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      command.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: command.id == 'quick-add'
                        ? const _ShortcutBadge('Ctrl/⌘+N')
                        : const Icon(Icons.arrow_forward_rounded, size: 18),
                    onTap: () => onSelected(command),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

IconData _commandIcon(String id) => switch (id) {
  'quick-add' => Icons.add_circle_outline_rounded,
  'home' => Icons.home_outlined,
  'library' => Icons.menu_book_outlined,
  'learning-hub' => Icons.school_outlined,
  'stats' => Icons.insights_outlined,
  'import' => Icons.file_download_outlined,
  'new-item' => Icons.edit_note_rounded,
  'settings' => Icons.tune_outlined,
  'storage-settings' => Icons.cloud_sync_outlined,
  'course-path' => Icons.route_outlined,
  'missions' => Icons.alt_route_rounded,
  'mixed-quiz' => Icons.quiz_outlined,
  'exam-simulator' => Icons.fact_check_outlined,
  'meaning-choice' => Icons.checklist_rounded,
  'production-writing' => Icons.keyboard_alt_outlined,
  'listening-discrimination' => Icons.hearing_outlined,
  'sentence-order' => Icons.reorder_rounded,
  'match-sprint' => Icons.bolt_rounded,
  'flashcards' => Icons.style_outlined,
  'pronunciation' => Icons.record_voice_over_outlined,
  _ => Icons.arrow_forward_rounded,
};

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
              Text('비슷한 자료', style: Theme.of(context).textTheme.labelLarge),
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
              '지금 화면을 벗어나지 않고 모든 주제의 자료를 찾을 수 있어요.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              '표현·뜻·읽는 법·예문·태그를 검색하고 바로 열거나 학습할 수 있어요.',
              textAlign: TextAlign.center,
            ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('최근 검색', style: Theme.of(context).textTheme.labelLarge),
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
