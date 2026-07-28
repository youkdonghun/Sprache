import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/study_store.dart';
import '../domain/language.dart';
import '../domain/learning_item.dart';
import '../import/content_import_parser.dart';
import '../import/import_reconciler.dart';
import '../state/app_state.dart';
import '../state/connection_state.dart';
import '../theme/app_theme.dart';

enum _ReviewFilter { all, selected, changed, problems }

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({
    super.key,
    this.initialPreview,
    this.initialFileName,
    this.initialSha256,
    this.initialPreviousImport,
  });

  final ImportPreview? initialPreview;
  final String? initialFileName;
  final String? initialSha256;
  final ImportCommitRecord? initialPreviousImport;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _parser = const ContentImportParser();
  final _decisions = <String, ImportReviewAction>{};
  ImportPreview? _preview;
  ImportCommitRecord? _previousImport;
  String? _fileName;
  String? _fileSha256;
  _ReviewFilter _filter = _ReviewFilter.all;
  int _visibleLimit = 50;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _preview = widget.initialPreview;
    _fileName = widget.initialFileName;
    _fileSha256 = widget.initialSha256;
    _previousImport = widget.initialPreviousImport;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'json', 'jsonl'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _showMessage('파일을 읽을 수 없습니다.');
      return;
    }

    try {
      final text = utf8.decode(bytes, allowMalformed: false);
      final language = ref.read(appControllerProvider).selectedLanguage;
      final extension = file.extension?.toLowerCase();
      final preview = switch (extension) {
        'csv' => _parser.parseCsv(text, defaultLanguage: language),
        'json' => _parser.parseJson(text, defaultLanguage: language),
        'jsonl' => _parser.parseJsonLines(text, defaultLanguage: language),
        _ => throw const FormatException('지원하지 않는 파일 형식입니다.'),
      };
      final fileSha256 = sha256.convert(bytes).toString();
      final previousImport = await ref
          .read(appControllerProvider.notifier)
          .previousImportBySha256(fileSha256);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _fileName = file.name;
        _fileSha256 = fileSha256;
        _previousImport = previousImport;
        _decisions.clear();
        _filter = _ReviewFilter.all;
        _visibleLimit = 50;
      });
    } on FormatException catch (error) {
      _showMessage(error.message.toString());
    } catch (_) {
      _showMessage('파일을 분석하지 못했습니다. 파일 형식과 접근 권한을 확인해 주세요.');
    }
  }

  ImportReviewAction _actionFor(ImportReviewEntry entry) {
    return entry
        .resolve(_decisions[entry.reviewKey] ?? entry.defaultAction)
        .action;
  }

  void _setAction(ImportReviewEntry entry, ImportReviewAction action) {
    setState(() => _decisions[entry.reviewKey] = entry.resolve(action).action);
  }

  void _setBulkAction(
    ImportReview review,
    ImportReviewStatus status,
    ImportReviewAction action,
  ) {
    setState(() {
      for (final entry in review.entries.where(
        (entry) => entry.status == status,
      )) {
        _decisions[entry.reviewKey] = entry.resolve(action).action;
      }
    });
  }

  Future<void> _import(ImportReview review) async {
    final preview = _preview;
    final fileName = _fileName;
    final fileSha256 = _fileSha256;
    if (preview == null || fileName == null || fileSha256 == null || _busy) {
      return;
    }
    final resolutions = [
      for (final entry in review.entries) entry.resolve(_actionFor(entry)),
    ];
    if (!resolutions.any(
      (resolution) => resolution.action != ImportReviewAction.skip,
    )) {
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await ref
          .read(appControllerProvider.notifier)
          .importResolvedItems(
            resolutions,
            fileName: fileName,
            sha256: fileSha256,
            rejectedRows: preview.issues.length + preview.duplicates.length,
          );
      if (!mounted) return;
      if (ref.read(appControllerProvider).driveConnected) {
        unawaited(ref.read(connectionControllerProvider.notifier).syncNow());
      }
      final staleText = result.stale == 0 ? '' : ' · 재검토 필요 ${result.stale}개';
      _showMessage(
        '신규 ${result.added}개 · 교체 ${result.replaced}개 · 제외 ${result.skipped}개$staleText',
      );
      context.go('/library');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<ImportReviewEntry> _filteredEntries(ImportReview review) {
    return review.entries
        .where((entry) {
          return switch (_filter) {
            _ReviewFilter.all => true,
            _ReviewFilter.selected =>
              _actionFor(entry) != ImportReviewAction.skip,
            _ReviewFilter.changed => entry.status == ImportReviewStatus.changed,
            _ReviewFilter.problems =>
              entry.status == ImportReviewStatus.blocked,
          };
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final language = ref.watch(
      appControllerProvider.select((state) => state.selectedLanguage),
    );
    ref.watch(appControllerProvider.select((state) => state.customItems));
    final controller = ref.read(appControllerProvider.notifier);
    final review = preview == null ? null : controller.reviewImport(preview);
    final selectedCount =
        review?.entries
            .where((entry) => _actionFor(entry) != ImportReviewAction.skip)
            .length ??
        0;
    final filtered = review == null
        ? const <ImportReviewEntry>[]
        : _filteredEntries(review);
    final visible = filtered.take(_visibleLimit).toList(growable: false);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PageHeader(language: language),
                  const SizedBox(height: 20),
                  _UploadCard(
                    fileName: _fileName,
                    onPickFile: _busy ? null : _pickFile,
                  ),
                  const SizedBox(height: 12),
                  const _FormatGuide(),
                  if (review != null) ...[
                    const SizedBox(height: 18),
                    _ReviewSummary(
                      fileName: _fileName ?? '미리보기 파일',
                      review: review,
                    ),
                    if (_previousImport case final previous?) ...[
                      const SizedBox(height: 12),
                      _RepeatedImportNotice(record: previous),
                    ],
                    const SizedBox(height: 12),
                    _BulkActions(
                      review: review,
                      onNewAction: (action) => _setBulkAction(
                        review,
                        ImportReviewStatus.newItem,
                        action,
                      ),
                      onChangedAction: (action) => _setBulkAction(
                        review,
                        ImportReviewStatus.changed,
                        action,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FilterBar(
                      filter: _filter,
                      totalCount: review.entries.length,
                      selectedCount: selectedCount,
                      changedCount: review.changedCount,
                      problemCount:
                          review.blockedCount +
                          review.issues.length +
                          review.duplicates.length,
                      onChanged: (filter) => setState(() {
                        _filter = filter;
                        _visibleLimit = 50;
                      }),
                    ),
                    const SizedBox(height: 10),
                    if (visible.isEmpty)
                      const _EmptyFilterResult()
                    else
                      for (final entry in visible) ...[
                        _ImportEntryCard(
                          entry: entry,
                          action: _actionFor(entry),
                          onActionChanged: (action) =>
                              _setAction(entry, action),
                        ),
                        const SizedBox(height: 10),
                      ],
                    if (visible.length < filtered.length)
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _visibleLimit += 50),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: Text(
                          '항목 더 보기 (${filtered.length - visible.length}개 남음)',
                        ),
                      ),
                    if (review.duplicates.isNotEmpty ||
                        review.issues.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _RejectedRows(review: review),
                    ],
                    const SizedBox(height: 14),
                    _ImportCommitBar(
                      selectedCount: selectedCount,
                      skippedCount: review.entries.length - selectedCount,
                      issueCount:
                          review.issues.length + review.duplicates.length,
                      busy: _busy,
                      onImport: selectedCount == 0
                          ? null
                          : () => _import(review),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.language});

  final LanguageTag language;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.filledTonal(
          onPressed: () => context.go('/library'),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '단어장으로',
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '학습 콘텐츠 가져오기',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${language.koreanName} 코스에 추가하기 전에 변경점을 한 항목씩 검토합니다.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({required this.fileName, required this.onPickFile});

  final String? fileName;
  final VoidCallback? onPickFile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = fileName != null;
    return Card(
      child: InkWell(
        onTap: onPickFile,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 58,
                  child: Icon(
                    selected
                        ? Icons.description_rounded
                        : Icons.upload_file_rounded,
                    color: colors.onPrimaryContainer,
                    size: 29,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected ? fileName! : '학습 파일을 선택하세요',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selected
                          ? '파일을 다시 누르면 다른 파일로 바꿀 수 있습니다.'
                          : 'CSV, JSON, JSONL · 이 기기에서 분석하고 검토 후 저장합니다.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onPickFile,
                icon: const Icon(Icons.folder_open_rounded),
                label: Text(selected ? '바꾸기' : '찾아보기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormatGuide extends StatelessWidget {
  const _FormatGuide();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.code_rounded),
        title: const Text(
          '지원 형식과 필수 필드',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('type, term, meaning'),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'word는 part_of_speech를 권장합니다. source·license·source_version·content_version으로 출처와 수정 이력을 보존합니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 5),
          Text(
            '일본어는 kana·romaji, 중국어는 pinyin을 선택적으로 넣을 수 있습니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const SelectableText(
              'type,term,meaning,part_of_speech,source,license\n'
              'word,hello,안녕하세요,interjection,직접 정리,private\n'
              'sentence,How are you?,잘 지내세요?,,직접 정리,private',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.fileName, required this.review});

  final String fileName;
  final ImportReview review;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('import-review-summary'),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        '가져오기 전 변경점 검토',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.fact_check_rounded),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                _ReviewMetric(
                  label: '신규',
                  value: review.newCount,
                  color: AppTheme.success,
                ),
                _ReviewMetric(
                  label: '변경',
                  value: review.changedCount,
                  color: AppTheme.warning,
                ),
                _ReviewMetric(
                  label: '동일',
                  value: review.unchangedCount,
                  color: AppTheme.desktopPrimary,
                ),
                _ReviewMetric(
                  label: '차단',
                  value: review.blockedCount,
                  color: AppTheme.danger,
                ),
                _ReviewMetric(
                  label: '행 오류',
                  value: review.issues.length + review.duplicates.length,
                  color: review.issues.isEmpty && review.duplicates.isEmpty
                      ? const Color(0xFF64748B)
                      : AppTheme.danger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewMetric extends StatelessWidget {
  const _ReviewMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            '$value',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: color),
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RepeatedImportNotice extends StatelessWidget {
  const _RepeatedImportNotice({required this.record});

  final ImportCommitRecord record;

  @override
  Widget build(BuildContext context) {
    final date = record.importedAt.toLocal();
    final formatted =
        '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Card(
      color: AppTheme.warning.withValues(alpha: 0.08),
      child: ListTile(
        key: const Key('import-repeated-file-notice'),
        leading: const Icon(Icons.history_rounded, color: AppTheme.warning),
        title: const Text(
          '이 파일은 이전에 가져온 기록이 있습니다.',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '$formatted · 저장 ${record.importedRows}행 · 제외 ${record.rejectedRows}행\n'
          '현재 단어장과 다시 비교했으므로 필요한 변경만 선택할 수 있습니다.',
        ),
      ),
    );
  }
}

class _BulkActions extends StatelessWidget {
  const _BulkActions({
    required this.review,
    required this.onNewAction,
    required this.onChangedAction,
  });

  final ImportReview review;
  final ValueChanged<ImportReviewAction> onNewAction;
  final ValueChanged<ImportReviewAction> onChangedAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('빠른 선택', style: Theme.of(context).textTheme.titleMedium),
            OutlinedButton.icon(
              key: const Key('import-bulk-add-new'),
              onPressed: review.newCount == 0
                  ? null
                  : () => onNewAction(ImportReviewAction.add),
              icon: const Icon(Icons.add_task_rounded),
              label: Text('신규 ${review.newCount}개 포함'),
            ),
            TextButton(
              onPressed: review.newCount == 0
                  ? null
                  : () => onNewAction(ImportReviewAction.skip),
              child: const Text('신규 제외'),
            ),
            OutlinedButton.icon(
              key: const Key('import-bulk-replace-changed'),
              onPressed: review.changedCount == 0
                  ? null
                  : () => onChangedAction(ImportReviewAction.replace),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text('변경 ${review.changedCount}개 교체'),
            ),
            TextButton(
              onPressed: review.changedCount == 0
                  ? null
                  : () => onChangedAction(ImportReviewAction.skip),
              child: const Text('변경분 기존 유지'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.totalCount,
    required this.selectedCount,
    required this.changedCount,
    required this.problemCount,
    required this.onChanged,
  });

  final _ReviewFilter filter;
  final int totalCount;
  final int selectedCount;
  final int changedCount;
  final int problemCount;
  final ValueChanged<_ReviewFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ReviewFilterChip(
            label: '전체 $totalCount',
            selected: filter == _ReviewFilter.all,
            onSelected: () => onChanged(_ReviewFilter.all),
          ),
          const SizedBox(width: 7),
          _ReviewFilterChip(
            label: '선택됨 $selectedCount',
            selected: filter == _ReviewFilter.selected,
            onSelected: () => onChanged(_ReviewFilter.selected),
          ),
          const SizedBox(width: 7),
          _ReviewFilterChip(
            label: '변경 $changedCount',
            selected: filter == _ReviewFilter.changed,
            onSelected: () => onChanged(_ReviewFilter.changed),
          ),
          const SizedBox(width: 7),
          _ReviewFilterChip(
            label: '문제 $problemCount',
            selected: filter == _ReviewFilter.problems,
            onSelected: () => onChanged(_ReviewFilter.problems),
          ),
        ],
      ),
    );
  }
}

class _ReviewFilterChip extends StatelessWidget {
  const _ReviewFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}

class _ImportEntryCard extends StatelessWidget {
  const _ImportEntryCard({
    required this.entry,
    required this.action,
    required this.onActionChanged,
  });

  final ImportReviewEntry entry;
  final ImportReviewAction action;
  final ValueChanged<ImportReviewAction> onActionChanged;

  Color get _statusColor => switch (entry.status) {
    ImportReviewStatus.newItem => AppTheme.success,
    ImportReviewStatus.unchanged => AppTheme.desktopPrimary,
    ImportReviewStatus.changed => AppTheme.warning,
    ImportReviewStatus.blocked => AppTheme.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('import-review-entry-${entry.row}'),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${entry.row}행 · ${entry.status.label}',
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  entry.incoming.kind == LearningItemKind.word ? '단어' : '문장',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  entry.incoming.learningLanguage.koreanName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              entry.incoming.text,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 3),
            Text(
              entry.incoming.primaryTranslation,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (entry.blockReason case final reason?) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.gpp_maybe_rounded,
                      size: 19,
                      color: AppTheme.danger,
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(reason)),
                  ],
                ),
              ),
            ],
            if (entry.differences.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '바뀌는 필드 ${entry.differences.length}개',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 7),
              for (final difference in entry.differences) ...[
                _DifferenceRow(difference: difference),
                const SizedBox(height: 7),
              ],
            ],
            const SizedBox(height: 12),
            _ActionPicker(
              entry: entry,
              selected: action,
              onChanged: onActionChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DifferenceRow extends StatelessWidget {
  const _DifferenceRow({required this.difference});

  final ImportFieldDifference difference;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 620;
        final oldValue = _DifferenceValue(
          label: '기존',
          value: difference.existingValue,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        );
        final newValue = _DifferenceValue(
          label: '가져올 값',
          value: difference.incomingValue,
          color: AppTheme.warning.withValues(alpha: 0.09),
        );
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                difference.label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              if (narrow) ...[
                oldValue,
                const SizedBox(height: 6),
                newValue,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: oldValue),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Icon(Icons.arrow_forward_rounded, size: 18),
                    ),
                    Expanded(child: newValue),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DifferenceValue extends StatelessWidget {
  const _DifferenceValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          SelectableText(value),
        ],
      ),
    );
  }
}

class _ActionPicker extends StatelessWidget {
  const _ActionPicker({
    required this.entry,
    required this.selected,
    required this.onChanged,
  });

  final ImportReviewEntry entry;
  final ImportReviewAction selected;
  final ValueChanged<ImportReviewAction> onChanged;

  @override
  Widget build(BuildContext context) {
    final actions = switch (entry.status) {
      ImportReviewStatus.newItem => const [
        ImportReviewAction.add,
        ImportReviewAction.skip,
      ],
      ImportReviewStatus.changed => const [
        ImportReviewAction.skip,
        ImportReviewAction.replace,
      ],
      ImportReviewStatus.unchanged ||
      ImportReviewStatus.blocked => const [ImportReviewAction.skip],
    };
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final action in actions)
          ChoiceChip(
            key: Key(
              'import-action-${entry.row}-${entry.incoming.id}-${action.name}',
            ),
            avatar: Icon(_actionIcon(action), size: 17),
            label: Text(_actionLabel(entry, action)),
            selected: selected == action,
            onSelected: (_) => onChanged(action),
          ),
      ],
    );
  }

  String _actionLabel(ImportReviewEntry entry, ImportReviewAction action) {
    return switch (action) {
      ImportReviewAction.add => '가져오기',
      ImportReviewAction.replace => '가져온 값으로 교체',
      ImportReviewAction.skip when entry.status == ImportReviewStatus.changed =>
        '기존 값 유지',
      ImportReviewAction.skip
          when entry.status == ImportReviewStatus.unchanged =>
        '동일 항목 · 건너뜀',
      ImportReviewAction.skip when entry.status == ImportReviewStatus.blocked =>
        '안전하게 제외',
      ImportReviewAction.skip => '제외',
    };
  }

  IconData _actionIcon(ImportReviewAction action) => switch (action) {
    ImportReviewAction.add => Icons.add_circle_outline_rounded,
    ImportReviewAction.replace => Icons.swap_horiz_rounded,
    ImportReviewAction.skip => Icons.shield_outlined,
  };
}

class _RejectedRows extends StatelessWidget {
  const _RejectedRows({required this.review});

  final ImportReview review;

  @override
  Widget build(BuildContext context) {
    final total = review.duplicates.length + review.issues.length;
    return Card(
      child: ExpansionTile(
        key: const Key('import-rejected-rows'),
        leading: const Icon(Icons.report_gmailerrorred_rounded),
        title: Text(
          '저장하지 않는 원본 행 $total개',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('파일 안 중복과 형식 오류는 원본 행 번호와 이유를 표시합니다.'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final duplicate in review.duplicates)
            ListTile(
              dense: true,
              leading: Text(
                '${duplicate.row}행',
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w900,
                ),
              ),
              title: Text(duplicate.item.text),
              subtitle: Text(
                '${duplicate.firstRow}행과 ${duplicate.kind.label} 중복입니다.',
              ),
            ),
          for (final issue in review.issues)
            ListTile(
              dense: true,
              leading: Text(
                '${issue.row}행',
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w900,
                ),
              ),
              title: Text(issue.message),
            ),
        ],
      ),
    );
  }
}

class _ImportCommitBar extends StatelessWidget {
  const _ImportCommitBar({
    required this.selectedCount,
    required this.skippedCount,
    required this.issueCount,
    required this.busy,
    required this.onImport,
  });

  final int selectedCount;
  final int skippedCount;
  final int issueCount;
  final bool busy;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 600;
            final summary = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$selectedCount개를 단어장에 반영합니다.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '기존 유지·제외 $skippedCount개 · 파일 오류 $issueCount개',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
            final button = FilledButton.icon(
              key: const Key('import-commit-button'),
              onPressed: busy ? null : onImport,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt_rounded),
              label: Text(busy ? '안전하게 저장 중…' : '$selectedCount개 가져오기'),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [summary, const SizedBox(height: 12), button],
              );
            }
            return Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: 16),
                button,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyFilterResult extends StatelessWidget {
  const _EmptyFilterResult();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.filter_alt_off_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            const Text('이 조건에 해당하는 항목이 없습니다.'),
          ],
        ),
      ),
    );
  }
}
