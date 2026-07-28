import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/learning_item.dart';
import '../domain/progress.dart';
import '../state/app_state.dart';
import '../state/connection_state.dart';
import '../theme/app_theme.dart';

enum _LibraryFilter { all, favorites, word, sentence, weak }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  var _query = '';
  var _filter = _LibraryFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final items = controller.courseItems;
    final customItemIds = state.customItems.map((item) => item.id).toSet();
    final filtered = items
        .where((item) {
          final progress = state.progress[item.id];
          final matchesFilter = switch (_filter) {
            _LibraryFilter.all => true,
            _LibraryFilter.favorites => state.preferences.isFavorite(item.id),
            _LibraryFilter.word => item.kind == LearningItemKind.word,
            _LibraryFilter.sentence => item.kind == LearningItemKind.sentence,
            _LibraryFilter.weak =>
              progress != null &&
                  progress.attempts > 0 &&
                  progress.accuracy < 0.7,
          };
          if (!matchesFilter) return false;
          if (_query.isEmpty) return true;
          final haystack = [
            item.text,
            ...item.translations,
            ...item.readings.map((reading) => reading.value),
            ...item.tags,
            if (item.partOfSpeech != null) item.partOfSpeech!.koreanLabel,
            item.source.name,
            item.source.license,
          ].join(' ').toLowerCase();
          return haystack.contains(_query.toLowerCase());
        })
        .toList(growable: false);
    final studiedCount = items
        .where((item) => state.progress.containsKey(item.id))
        .length;
    final favoriteCount = items
        .where((item) => state.preferences.isFavorite(item.id))
        .length;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LibraryHeader(
                  languageName: state.selectedLanguage.koreanName,
                  totalCount: items.length,
                  studiedCount: studiedCount,
                  favoriteCount: favoriteCount,
                  onAdd: () => context.go('/library/new'),
                  onImport: () => context.go('/import'),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 680;
                    final search = TextField(
                      controller: _searchController,
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: '단어, 뜻, 읽기, 품사, 출처 검색',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
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
                            onSelected: () =>
                                setState(() => _filter = _LibraryFilter.all),
                          ),
                          const SizedBox(width: 7),
                          _FilterChip(
                            label: '저장됨',
                            selected: _filter == _LibraryFilter.favorites,
                            onSelected: () => setState(
                              () => _filter = _LibraryFilter.favorites,
                            ),
                          ),
                          const SizedBox(width: 7),
                          _FilterChip(
                            label: '단어',
                            selected: _filter == _LibraryFilter.word,
                            onSelected: () =>
                                setState(() => _filter = _LibraryFilter.word),
                          ),
                          const SizedBox(width: 7),
                          _FilterChip(
                            label: '문장',
                            selected: _filter == _LibraryFilter.sentence,
                            onSelected: () => setState(
                              () => _filter = _LibraryFilter.sentence,
                            ),
                          ),
                          const SizedBox(width: 7),
                          _FilterChip(
                            label: '집중 필요',
                            selected: _filter == _LibraryFilter.weak,
                            onSelected: () =>
                                setState(() => _filter = _LibraryFilter.weak),
                          ),
                        ],
                      ),
                    );
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [search, const SizedBox(height: 10), filters],
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
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Card(
                    child: filtered.isEmpty
                        ? _EmptyLibrary(query: _query, filter: _filter)
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final progress = state.progress[item.id];
                              return _LibraryRow(
                                item: item,
                                progress: progress,
                                selected: state.preferences.includes(item),
                                favorite: state.preferences.isFavorite(item.id),
                                isCustom: customItemIds.contains(item.id),
                                onToggle: () =>
                                    controller.toggleItemSelection(item.id),
                                onFavorite: () =>
                                    controller.toggleFavorite(item.id),
                                onEdit: () =>
                                    context.go('/library/edit/${item.id}'),
                                onDelete: () => _confirmDelete(context, item),
                                onTap: () => _showDetails(
                                  context,
                                  item: item,
                                  progress: progress,
                                ),
                              );
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'CSV · JSON · JSONL로 나만의 표현을 추가할 수 있습니다.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    await ref.read(appControllerProvider.notifier).deleteCustomItem(item.id);
    if (!context.mounted) return;
    if (ref.read(appControllerProvider).driveConnected) {
      unawaited(ref.read(connectionControllerProvider.notifier).syncNow());
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('사용자 표현을 삭제했습니다.')));
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

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({
    required this.languageName,
    required this.totalCount,
    required this.studiedCount,
    required this.favoriteCount,
    required this.onAdd,
    required this.onImport,
  });

  final String languageName;
  final int totalCount;
  final int studiedCount;
  final int favoriteCount;
  final VoidCallback onAdd;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$languageName 단어장',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          '전체 $totalCount개 · 학습 $studiedCount개 · 저장 $favoriteCount개',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
    final addButton = FilledButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add_rounded),
      label: const Text('직접 추가'),
    );
    final importButton = IconButton.filledTonal(
      onPressed: onImport,
      icon: const Icon(Icons.upload_file_rounded),
      tooltip: '파일 가져오기',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              copy,
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(child: addButton),
                  const SizedBox(width: 8),
                  importButton,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: copy),
            const SizedBox(width: 18),
            addButton,
            const SizedBox(width: 6),
            importButton,
          ],
        );
      },
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.item,
    required this.progress,
    required this.selected,
    required this.favorite,
    required this.isCustom,
    required this.onToggle,
    required this.onFavorite,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  final LearningItem item;
  final ProgressRecord? progress;
  final bool selected;
  final bool favorite;
  final bool isCustom;
  final VoidCallback onToggle;
  final VoidCallback onFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _statusFor(progress);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '${item.text}, ${item.primaryTranslation}, ${status.$1}',
      child: InkWell(
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
              child: Row(
                children: [
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
                          dimension: 46,
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
                  const SizedBox(width: 13),
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
                                  fontSize: 16,
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
                            if (item.readings.isNotEmpty)
                              item.readings.first.value,
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
                  IconButton(
                    key: Key('favorite-${item.id}'),
                    onPressed: onFavorite,
                    tooltip: favorite ? '저장 해제' : '표현 저장',
                    icon: Icon(
                      favorite ? Icons.star_rounded : Icons.star_border_rounded,
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
                      ],
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _ItemAction { toggle, edit, delete }

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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              query.isEmpty
                  ? Icons.auto_awesome_rounded
                  : Icons.search_off_rounded,
              size: 44,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              query.isEmpty && filter == _LibraryFilter.weak
                  ? '집중이 필요한 항목이 없어요'
                  : query.isEmpty && filter == _LibraryFilter.favorites
                  ? '아직 저장한 표현이 없어요'
                  : '조건에 맞는 표현이 없어요',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              query.isEmpty && filter == _LibraryFilter.weak
                  ? '정확도가 낮아지면 이곳에 자동으로 모아드려요.'
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
  }
}

class _ItemDetails extends StatelessWidget {
  const _ItemDetails({required this.item, required this.progress});

  final LearningItem item;
  final ProgressRecord? progress;

  @override
  Widget build(BuildContext context) {
    final status = _statusFor(progress);
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
                if (item.readings.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    item.readings.map((reading) => reading.value).join(' · '),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  item.primaryTranslation,
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
                        ],
                      ),
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
