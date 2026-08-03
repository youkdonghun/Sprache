import 'package:flutter/material.dart';

class ContentSelectionActionBar extends StatelessWidget {
  const ContentSelectionActionBar({
    required this.selectedCount,
    required this.onAddToGroup,
    required this.onMoveToGroup,
    required this.onMemorize,
    required this.onQuiz,
    required this.onClear,
    this.hiddenSelectedCount = 0,
    this.busy = false,
    this.onMoveToSubject,
    this.onToggleFavorite,
    this.onBulkEdit,
    this.onEditTags,
    this.onExport,
    this.onToggleVisibility,
    this.onDelete,
    this.keyPrefix = 'content-selection',
    this.addKey,
    super.key,
  });

  final int selectedCount;
  final int hiddenSelectedCount;
  final bool busy;
  final VoidCallback? onAddToGroup;
  final VoidCallback? onMoveToGroup;
  final VoidCallback? onMemorize;
  final VoidCallback? onQuiz;
  final VoidCallback onClear;
  final VoidCallback? onMoveToSubject;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onBulkEdit;
  final VoidCallback? onEditTags;
  final VoidCallback? onExport;
  final VoidCallback? onToggleVisibility;
  final VoidCallback? onDelete;
  final String keyPrefix;
  final Key? addKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final countLabel = hiddenSelectedCount == 0
        ? '선택 $selectedCount개'
        : '선택 $selectedCount개 · 숨김 $hiddenSelectedCount';
    return Material(
      key: Key('$keyPrefix-action-bar'),
      color: colors.primaryContainer.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.primary.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final actions = <Widget>[
              FilledButton.tonalIcon(
                key: addKey ?? Key('$keyPrefix-group-add'),
                onPressed: busy ? null : onAddToGroup,
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('그룹 추가'),
              ),
              OutlinedButton.icon(
                key: Key('$keyPrefix-group-move'),
                onPressed: busy ? null : onMoveToGroup,
                icon: const Icon(Icons.drive_file_move_outline, size: 18),
                label: const Text('그룹 이동'),
              ),
              TextButton.icon(
                key: Key('$keyPrefix-memorize'),
                onPressed: busy ? null : onMemorize,
                icon: const Icon(Icons.style_rounded, size: 18),
                label: const Text('암기'),
              ),
              TextButton.icon(
                key: Key('$keyPrefix-quiz'),
                onPressed: busy ? null : onQuiz,
                icon: const Icon(Icons.quiz_outlined, size: 18),
                label: const Text('퀴즈'),
              ),
              if (onBulkEdit != null)
                FilledButton.tonalIcon(
                  key: Key('$keyPrefix-bulk-edit'),
                  onPressed: busy ? null : onBulkEdit,
                  icon: const Icon(Icons.table_view_outlined, size: 18),
                  label: const Text('표 편집'),
                ),
              if (onMoveToSubject != null)
                IconButton(
                  key: Key('$keyPrefix-subject-move'),
                  onPressed: busy ? null : onMoveToSubject,
                  icon: const Icon(Icons.swap_horiz_rounded),
                  tooltip: '다른 학습 주제로 이동',
                ),
              if (onToggleFavorite != null ||
                  onEditTags != null ||
                  onExport != null ||
                  onToggleVisibility != null ||
                  onDelete != null)
                PopupMenuButton<_SelectionMoreAction>(
                  key: Key('$keyPrefix-more'),
                  enabled: !busy,
                  tooltip: '선택 자료 더보기',
                  icon: const Icon(Icons.more_horiz_rounded),
                  onSelected: (action) {
                    switch (action) {
                      case _SelectionMoreAction.favorite:
                        onToggleFavorite?.call();
                      case _SelectionMoreAction.tags:
                        onEditTags?.call();
                      case _SelectionMoreAction.export:
                        onExport?.call();
                      case _SelectionMoreAction.visibility:
                        onToggleVisibility?.call();
                      case _SelectionMoreAction.delete:
                        onDelete?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    if (onToggleFavorite != null)
                      const PopupMenuItem(
                        value: _SelectionMoreAction.favorite,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.star_outline_rounded),
                          title: Text('즐겨찾기 바꾸기'),
                        ),
                      ),
                    if (onEditTags != null)
                      const PopupMenuItem(
                        value: _SelectionMoreAction.tags,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.sell_outlined),
                          title: Text('선택한 자료의 태그 바꾸기'),
                        ),
                      ),
                    if (onToggleVisibility != null)
                      const PopupMenuItem(
                        value: _SelectionMoreAction.visibility,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.visibility_off_outlined),
                          title: Text('학습에 넣거나 빼기'),
                        ),
                      ),
                    if (onExport != null)
                      const PopupMenuItem(
                        value: _SelectionMoreAction.export,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.file_download_outlined),
                          title: Text('선택 자료 내보내기'),
                        ),
                      ),
                    if (onDelete != null) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: _SelectionMoreAction.delete,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('내가 추가한 자료 삭제'),
                        ),
                      ),
                    ],
                  ],
                ),
              TextButton.icon(
                key: Key('$keyPrefix-clear'),
                onPressed: busy ? null : onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('선택 해제'),
              ),
            ];
            final count = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: colors.primary),
                const SizedBox(width: 7),
                Text(
                  countLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            );
            if (constraints.maxWidth >= 760) {
              return Row(
                children: [
                  count,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: actions,
                    ),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: count),
                    if (busy)
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _SelectionMoreAction { favorite, tags, export, visibility, delete }
