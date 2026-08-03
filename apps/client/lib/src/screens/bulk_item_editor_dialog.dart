import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/content_validation.dart';
import '../domain/import_distribution.dart';
import '../domain/language.dart';
import '../domain/learning_group.dart';
import '../domain/learning_item.dart';

typedef BulkItemSave = Future<void> Function(List<LearningItem> items);

class BulkItemEditorDialog extends StatefulWidget {
  const BulkItemEditorDialog({
    required this.items,
    required this.onSave,
    super.key,
  });

  final List<LearningItem> items;
  final BulkItemSave onSave;

  @override
  State<BulkItemEditorDialog> createState() => _BulkItemEditorDialogState();
}

class _BulkItemEditorDialogState extends State<BulkItemEditorDialog> {
  final _validator = const LearningContentValidator();
  final _searchController = TextEditingController();
  late final List<_BulkItemDraft> _drafts;
  final _errorsById = <String, String>{};
  var _query = '';
  var _changedOnly = false;
  var _revision = 0;
  var _saving = false;
  var _allowPop = false;

  @override
  void initState() {
    super.initState();
    _drafts = widget.items.map(_BulkItemDraft.fromItem).toList(growable: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _changedCount => _drafts.where((draft) => draft.changed).length;

  List<_BulkItemDraft> get _visibleDrafts {
    final foldedQuery = _query.trim().toLowerCase();
    return _drafts
        .where((draft) {
          if (_changedOnly && !draft.changed) return false;
          if (foldedQuery.isEmpty) return true;
          return draft.searchText.contains(foldedQuery);
        })
        .toList(growable: false);
  }

  void _update(
    _BulkItemDraft draft,
    void Function(_BulkItemDraft draft) change,
  ) {
    change(draft);
    final result = _validator.inspect(draft.toItem());
    final error = result.errors.isEmpty ? null : result.errors.first;
    setState(() {
      if (error == null) {
        _errorsById.remove(draft.item.id);
      } else {
        _errorsById[draft.item.id] = error.message;
      }
    });
  }

  void _reset(_BulkItemDraft draft) {
    setState(() {
      draft.reset();
      _errorsById.remove(draft.item.id);
      _revision += 1;
    });
  }

  void _resetAll() {
    setState(() {
      for (final draft in _drafts) {
        draft.reset();
      }
      _errorsById.clear();
      _revision += 1;
    });
  }

  Future<void> _requestClose() async {
    if (_saving) return;
    if (_changedCount == 0) {
      _pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('수정 내용을 버릴까요?'),
        content: Text('저장하지 않은 $_changedCount개 행의 변경 내용이 사라집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('계속 편집'),
          ),
          FilledButton.tonal(
            key: const Key('discard-bulk-item-edits'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('변경 버리기'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) _pop();
  }

  void _pop([int? result]) {
    if (_allowPop) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final changed = _drafts.where((draft) => draft.changed).toList();
    if (changed.isEmpty) return;

    final items = <LearningItem>[];
    final errors = <String, String>{};
    for (final draft in changed) {
      final result = _validator.inspect(draft.toItem());
      if (result.errors.isEmpty) {
        items.add(result.item);
      } else {
        errors[draft.item.id] = result.errors.first.message;
      }
    }
    if (errors.isNotEmpty) {
      setState(() {
        _errorsById
          ..clear()
          ..addAll(errors);
        _changedOnly = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 있는 ${errors.length}개 행을 먼저 확인해 주세요.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(items);
      if (mounted) _pop(items.length);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('표 편집 내용을 저장하지 못했습니다. $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleDrafts;
    final changedCount = _changedCount;
    final colors = Theme.of(context).colorScheme;
    return PopScope<int>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): _save,
        },
        child: Dialog.fullscreen(
          key: const Key('bulk-item-editor-dialog'),
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                key: const Key('close-bulk-item-editor'),
                onPressed: _saving ? null : _requestClose,
                icon: const Icon(Icons.close_rounded),
                tooltip: '닫기',
              ),
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('표로 한 번에 편집'),
                  Text(
                    '엑셀처럼 셀을 옮겨가며 수정하고 마지막에 한 번만 저장합니다.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: FilledButton.icon(
                    key: const Key('save-bulk-item-edits'),
                    onPressed: changedCount == 0 || _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? '저장 중' : '$changedCount개 변경 저장'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: colors.surfaceContainerLow,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 280,
                          child: TextField(
                            key: const Key('bulk-item-search'),
                            controller: _searchController,
                            onChanged: (value) =>
                                setState(() => _query = value),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: '표현·뜻·태그 검색',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _query = '');
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                      tooltip: '검색 지우기',
                                    ),
                            ),
                          ),
                        ),
                        FilterChip(
                          key: const Key('bulk-item-changed-only'),
                          selected: _changedOnly,
                          onSelected: (value) =>
                              setState(() => _changedOnly = value),
                          avatar: const Icon(Icons.edit_note_rounded, size: 18),
                          label: Text('변경한 행만 $changedCount'),
                        ),
                        _CountChip(
                          icon: Icons.table_rows_outlined,
                          label: '전체 ${_drafts.length}',
                        ),
                        if (_errorsById.isNotEmpty)
                          _CountChip(
                            icon: Icons.error_outline_rounded,
                            label: '오류 ${_errorsById.length}',
                            error: true,
                          ),
                        TextButton.icon(
                          key: const Key('reset-all-bulk-item-edits'),
                          onPressed: changedCount == 0 || _saving
                              ? null
                              : _resetAll,
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('전체 되돌리기'),
                        ),
                        const Text(
                          'Tab: 다음 셀 · Shift+Tab: 이전 셀 · Ctrl/⌘+Enter: 저장',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (_errorsById.isNotEmpty)
                    MaterialBanner(
                      content: Text(
                        '빈 표현·뜻, 너무 긴 값 또는 문장 토큰 불일치가 있습니다. '
                        '빨간 표시가 있는 행을 고치면 전체를 안전하게 저장할 수 있어요.',
                      ),
                      leading: Icon(
                        Icons.error_outline_rounded,
                        color: colors.error,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => setState(() => _changedOnly = true),
                          child: const Text('변경 행 보기'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: visible.isEmpty
                        ? _BulkEditorEmpty(
                            changedOnly: _changedOnly,
                            onShowAll: () => setState(() {
                              _changedOnly = false;
                              _query = '';
                              _searchController.clear();
                            }),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 760) {
                                return ListView.separated(
                                  key: const Key('bulk-item-mobile-list'),
                                  padding: const EdgeInsets.all(12),
                                  itemCount: visible.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final draft = visible[index];
                                    return _BulkItemMobileCard(
                                      key: ValueKey(
                                        '$_revision-${draft.item.id}',
                                      ),
                                      index: _drafts.indexOf(draft) + 1,
                                      draft: draft,
                                      error: _errorsById[draft.item.id],
                                      onChanged: (change) =>
                                          _update(draft, change),
                                      onReset: draft.changed
                                          ? () => _reset(draft)
                                          : null,
                                    );
                                  },
                                );
                              }
                              return _BulkItemDesktopTable(
                                revision: _revision,
                                drafts: visible,
                                allDrafts: _drafts,
                                errorsById: _errorsById,
                                onChanged: _update,
                                onReset: _reset,
                              );
                            },
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

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    this.error = false,
  });

  final IconData icon;
  final String label;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Chip(
      avatar: Icon(icon, size: 18, color: error ? colors.error : null),
      label: Text(label),
      side: error ? BorderSide(color: colors.error) : null,
    );
  }
}

class _BulkEditorEmpty extends StatelessWidget {
  const _BulkEditorEmpty({required this.changedOnly, required this.onShowAll});

  final bool changedOnly;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 44),
          const SizedBox(height: 10),
          Text(changedOnly ? '변경한 행이 없습니다.' : '검색 결과가 없습니다.'),
          const SizedBox(height: 8),
          TextButton(onPressed: onShowAll, child: const Text('전체 행 보기')),
        ],
      ),
    );
  }
}

class _BulkItemDesktopTable extends StatefulWidget {
  const _BulkItemDesktopTable({
    required this.revision,
    required this.drafts,
    required this.allDrafts,
    required this.errorsById,
    required this.onChanged,
    required this.onReset,
  });

  static const tableWidth = 1640.0;
  final int revision;
  final List<_BulkItemDraft> drafts;
  final List<_BulkItemDraft> allDrafts;
  final Map<String, String> errorsById;
  final void Function(
    _BulkItemDraft draft,
    void Function(_BulkItemDraft draft) change,
  )
  onChanged;
  final void Function(_BulkItemDraft draft) onReset;

  @override
  State<_BulkItemDesktopTable> createState() => _BulkItemDesktopTableState();
}

class _BulkItemDesktopTableState extends State<_BulkItemDesktopTable> {
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      child: SingleChildScrollView(
        key: const Key('bulk-item-horizontal-scroll'),
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: _BulkItemDesktopTable.tableWidth,
          child: Column(
            children: [
              Container(
                height: 44,
                color: colors.surfaceContainerHighest,
                child: const Row(
                  children: [
                    _TableHeader('#', 52),
                    _TableHeader('종류', 72),
                    _TableHeader('표현', 190),
                    _TableHeader('뜻', 220),
                    _TableHeader('한글 발음', 150),
                    _TableHeader('예문', 250),
                    _TableHeader('예문 뜻', 250),
                    _TableHeader('태그(쉼표)', 220),
                    _TableHeader('레벨', 100),
                    _TableHeader('', 56),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  key: const Key('bulk-item-desktop-table'),
                  itemCount: widget.drafts.length,
                  itemExtent: 58,
                  itemBuilder: (context, index) {
                    final draft = widget.drafts[index];
                    return _BulkItemDesktopRow(
                      key: ValueKey('${widget.revision}-${draft.item.id}'),
                      index: widget.allDrafts.indexOf(draft) + 1,
                      draft: draft,
                      error: widget.errorsById[draft.item.id],
                      onChanged: (change) => widget.onChanged(draft, change),
                      onReset: draft.changed
                          ? () => widget.onReset(draft)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.label, this.width);

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
  );
}

class _BulkItemDesktopRow extends StatelessWidget {
  const _BulkItemDesktopRow({
    required this.index,
    required this.draft,
    required this.error,
    required this.onChanged,
    required this.onReset,
    super.key,
  });

  final int index;
  final _BulkItemDraft draft;
  final String? error;
  final void Function(void Function(_BulkItemDraft draft) change) onChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: error != null
            ? colors.errorContainer.withValues(alpha: 0.28)
            : draft.changed
            ? colors.primaryContainer.withValues(alpha: 0.20)
            : null,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (error != null)
                  Tooltip(
                    message: error!,
                    child: Icon(
                      Icons.error_rounded,
                      size: 17,
                      color: colors.error,
                    ),
                  )
                else if (draft.changed)
                  Icon(Icons.edit_rounded, size: 16, color: colors.primary),
                const SizedBox(width: 3),
                Text('$index'),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              draft.item.kind == LearningItemKind.word ? '단어' : '문장',
              textAlign: TextAlign.center,
            ),
          ),
          _TableCell(
            width: 190,
            value: draft.text,
            fieldKey: 'bulk-text-${draft.item.id}',
            error: error != null,
            onChanged: (value) => onChanged((draft) => draft.text = value),
          ),
          _TableCell(
            width: 220,
            value: draft.meaning,
            fieldKey: 'bulk-meaning-${draft.item.id}',
            error: error != null,
            onChanged: (value) => onChanged((draft) => draft.meaning = value),
          ),
          _TableCell(
            width: 150,
            value: draft.pronunciation,
            fieldKey: 'bulk-pronunciation-${draft.item.id}',
            onChanged: (value) =>
                onChanged((draft) => draft.pronunciation = value),
          ),
          _TableCell(
            width: 250,
            value: draft.example,
            fieldKey: 'bulk-example-${draft.item.id}',
            onChanged: (value) => onChanged((draft) => draft.example = value),
          ),
          _TableCell(
            width: 250,
            value: draft.exampleMeaning,
            fieldKey: 'bulk-example-meaning-${draft.item.id}',
            onChanged: (value) =>
                onChanged((draft) => draft.exampleMeaning = value),
          ),
          _TableCell(
            width: 220,
            value: draft.tags,
            fieldKey: 'bulk-tags-${draft.item.id}',
            onChanged: (value) => onChanged((draft) => draft.tags = value),
          ),
          _TableCell(
            width: 100,
            value: draft.level,
            fieldKey: 'bulk-level-${draft.item.id}',
            onChanged: (value) => onChanged((draft) => draft.level = value),
          ),
          SizedBox(
            width: 56,
            child: IconButton(
              key: Key('reset-bulk-row-${draft.item.id}'),
              onPressed: onReset,
              icon: const Icon(Icons.undo_rounded, size: 19),
              tooltip: '이 행 되돌리기',
            ),
          ),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({
    required this.width,
    required this.value,
    required this.fieldKey,
    required this.onChanged,
    this.error = false,
  });

  final double width;
  final String value;
  final String fieldKey;
  final ValueChanged<String> onChanged;
  final bool error;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: TextFormField(
        key: Key(fieldKey),
        initialValue: value,
        onChanged: onChanged,
        maxLines: 1,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 9,
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: error
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
    ),
  );
}

class _BulkItemMobileCard extends StatelessWidget {
  const _BulkItemMobileCard({
    required this.index,
    required this.draft,
    required this.error,
    required this.onChanged,
    required this.onReset,
    super.key,
  });

  final int index;
  final _BulkItemDraft draft;
  final String? error;
  final void Function(void Function(_BulkItemDraft draft) change) onChanged;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card.outlined(
      color: error != null
          ? colors.errorContainer.withValues(alpha: 0.24)
          : draft.changed
          ? colors.primaryContainer.withValues(alpha: 0.16)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '$index · ${draft.item.kind == LearningItemKind.word ? '단어' : '문장'}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (error != null)
                  Tooltip(
                    message: error!,
                    child: Icon(Icons.error_rounded, color: colors.error),
                  ),
                IconButton(
                  key: Key('reset-bulk-row-${draft.item.id}'),
                  onPressed: onReset,
                  icon: const Icon(Icons.undo_rounded),
                  tooltip: '이 행 되돌리기',
                ),
              ],
            ),
            if (error != null) ...[
              Text(error!, style: TextStyle(color: colors.error)),
              const SizedBox(height: 8),
            ],
            _MobileField(
              fieldKey: 'bulk-text-${draft.item.id}',
              label: '표현',
              value: draft.text,
              onChanged: (value) => onChanged((draft) => draft.text = value),
            ),
            _MobileField(
              fieldKey: 'bulk-meaning-${draft.item.id}',
              label: '뜻',
              value: draft.meaning,
              onChanged: (value) => onChanged((draft) => draft.meaning = value),
            ),
            _MobileField(
              fieldKey: 'bulk-pronunciation-${draft.item.id}',
              label: '한글 발음',
              value: draft.pronunciation,
              onChanged: (value) =>
                  onChanged((draft) => draft.pronunciation = value),
            ),
            _MobileField(
              fieldKey: 'bulk-example-${draft.item.id}',
              label: '예문',
              value: draft.example,
              onChanged: (value) => onChanged((draft) => draft.example = value),
            ),
            _MobileField(
              fieldKey: 'bulk-example-meaning-${draft.item.id}',
              label: '예문 뜻',
              value: draft.exampleMeaning,
              onChanged: (value) =>
                  onChanged((draft) => draft.exampleMeaning = value),
            ),
            _MobileField(
              fieldKey: 'bulk-tags-${draft.item.id}',
              label: '태그(쉼표로 구분)',
              value: draft.tags,
              onChanged: (value) => onChanged((draft) => draft.tags = value),
            ),
            _MobileField(
              fieldKey: 'bulk-level-${draft.item.id}',
              label: '레벨',
              value: draft.level,
              onChanged: (value) => onChanged((draft) => draft.level = value),
              last: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileField extends StatelessWidget {
  const _MobileField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final String fieldKey;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 9),
    child: TextFormField(
      key: Key(fieldKey),
      initialValue: value,
      onChanged: onChanged,
      textInputAction: last ? TextInputAction.done : TextInputAction.next,
      decoration: InputDecoration(labelText: label, isDense: true),
    ),
  );
}

class _BulkItemDraft {
  _BulkItemDraft.fromItem(this.item)
    : originalText = item.text,
      originalMeaning = item.primaryTranslation,
      originalPronunciation = item.koreanPronunciation ?? '',
      originalExample = item.example ?? '',
      originalExampleMeaning = item.exampleTranslation ?? '',
      originalTags = _editableTags(item).join(', '),
      originalLevel = item.level {
    reset();
  }

  final LearningItem item;
  final String originalText;
  final String originalMeaning;
  final String originalPronunciation;
  final String originalExample;
  final String originalExampleMeaning;
  final String originalTags;
  final String originalLevel;

  late String text;
  late String meaning;
  late String pronunciation;
  late String example;
  late String exampleMeaning;
  late String tags;
  late String level;

  bool get changed =>
      text != originalText ||
      meaning != originalMeaning ||
      pronunciation != originalPronunciation ||
      example != originalExample ||
      exampleMeaning != originalExampleMeaning ||
      tags != originalTags ||
      level != originalLevel;

  String get searchText => <String>[
    originalText,
    originalMeaning,
    originalTags,
    text,
    meaning,
    pronunciation,
    example,
    exampleMeaning,
    tags,
    level,
  ].join(' ').toLowerCase();

  void reset() {
    text = originalText;
    meaning = originalMeaning;
    pronunciation = originalPronunciation;
    example = originalExample;
    exampleMeaning = originalExampleMeaning;
    tags = originalTags;
    level = originalLevel;
  }

  LearningItem toItem() {
    final otherTranslations = item.translations.skip(1);
    final acceptedWithoutOldPrimary = item.acceptedAnswers.where(
      (answer) => answer.trim() != item.primaryTranslation.trim(),
    );
    final readings = <Reading>[
      for (final reading in item.readings)
        if (reading.scheme != ReadingScheme.hangul) reading,
      if (pronunciation.trim().isNotEmpty)
        Reading(scheme: ReadingScheme.hangul, value: pronunciation),
    ];
    final protectedTags = item.tags.where(_protectedTag);
    return LearningItem(
      id: item.id,
      kind: item.kind,
      learningLanguage: item.learningLanguage,
      subjectId: item.subjectId,
      text: text,
      translations: [meaning, ...otherTranslations],
      acceptedAnswers: [
        meaning,
        ...otherTranslations,
        ...acceptedWithoutOldPrimary,
      ],
      readings: readings,
      sentenceTokens: item.sentenceTokens,
      example: example.trim().isEmpty ? null : example,
      exampleTranslation: exampleMeaning.trim().isEmpty ? null : exampleMeaning,
      partOfSpeech: item.partOfSpeech,
      tags: [...protectedTags, ..._parseTags(tags)],
      level: level,
      capabilities: item.capabilities,
      priority: item.priority,
      source: item.source,
      updatedAt: item.updatedAt,
    );
  }

  static Iterable<String> _editableTags(LearningItem item) =>
      item.tags.where((tag) => !_protectedTag(tag));

  static bool _protectedTag(String tag) =>
      tag.startsWith(learningGroupTagPrefix) ||
      tag.startsWith(importDistributionTagPrefix) ||
      tag.startsWith('unit-');

  static Iterable<String> _parseTags(String source) sync* {
    final seen = <String>{};
    for (final raw in source.split(RegExp(r'[,，\n]+'))) {
      final tag = raw.trim().replaceFirst(RegExp(r'^#+'), '');
      if (tag.isNotEmpty && seen.add(tag)) yield tag;
    }
  }
}
