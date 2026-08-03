import 'package:flutter/material.dart';

import '../import/pdf_extraction_service.dart';

Future<List<PdfImportCandidate>?> showPdfImportReviewDialog({
  required BuildContext context,
  required PdfExtractionResult result,
}) => showDialog<List<PdfImportCandidate>>(
  context: context,
  barrierDismissible: false,
  builder: (context) => _PdfImportReviewDialog(result: result),
);

enum _PdfCandidateFilter { all, mapped, terms, selected }

class _PdfImportReviewDialog extends StatefulWidget {
  const _PdfImportReviewDialog({required this.result});

  final PdfExtractionResult result;

  @override
  State<_PdfImportReviewDialog> createState() => _PdfImportReviewDialogState();
}

class _PdfImportReviewDialogState extends State<_PdfImportReviewDialog> {
  late List<PdfImportCandidate> _candidates = [...widget.result.candidates];
  _PdfCandidateFilter _filter = _PdfCandidateFilter.all;

  List<int> get _visibleIndexes => [
    for (var index = 0; index < _candidates.length; index += 1)
      if (switch (_filter) {
        _PdfCandidateFilter.all => true,
        _PdfCandidateFilter.mapped =>
          _candidates[index].kind == PdfCandidateKind.mappedPair,
        _PdfCandidateFilter.terms =>
          _candidates[index].kind == PdfCandidateKind.documentTerm,
        _PdfCandidateFilter.selected => _candidates[index].selected,
      })
        index,
  ];

  int get _selectedCount =>
      _candidates.where((candidate) => candidate.selected).length;
  int get _missingMeaningCount => _candidates
      .where((candidate) => candidate.selected && !candidate.hasMeaning)
      .length;

  void _update(int index, PdfImportCandidate candidate) {
    setState(() => _candidates[index] = candidate);
  }

  void _selectMapped() {
    setState(() {
      _candidates = [
        for (final candidate in _candidates)
          candidate.copyWith(
            selected: candidate.kind == PdfCandidateKind.mappedPair,
          ),
      ];
    });
  }

  void _clearSelection() {
    setState(() {
      _candidates = [
        for (final candidate in _candidates)
          candidate.copyWith(selected: false),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleIndexes;
    final size = MediaQuery.sizeOf(context);
    return Dialog.fullscreen(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PDF 후보 검토',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          '${widget.result.fileName} · ${widget.result.pageCount}쪽 · 후보 ${_candidates.length}개',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (size.width >= 640)
                    FilledButton.icon(
                      onPressed: _selectedCount == 0 || _missingMeaningCount > 0
                          ? null
                          : () => Navigator.pop(
                              context,
                              _candidates
                                  .where((candidate) => candidate.selected)
                                  .toList(growable: false),
                            ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text('기존 자료와 비교 ($_selectedCount)'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '단어–뜻으로 명확히 읽힌 ${widget.result.mappedPairCount}개만 먼저 선택했습니다. 일반 문서 후보는 뜻을 입력한 뒤 선택해 주세요.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_missingMeaningCount > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '선택한 후보 중 $_missingMeaningCount개에 뜻이 없습니다.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final filter in _PdfCandidateFilter.values) ...[
                          FilterChip(
                            selected: _filter == filter,
                            label: Text(switch (filter) {
                              _PdfCandidateFilter.all => '전체',
                              _PdfCandidateFilter.mapped => '단어–뜻',
                              _PdfCandidateFilter.terms => '일반 문서',
                              _PdfCandidateFilter.selected => '선택됨',
                            }),
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                          const SizedBox(width: 6),
                        ],
                        TextButton(
                          onPressed: _selectMapped,
                          child: const Text('명확한 항목만 선택'),
                        ),
                        TextButton(
                          onPressed: _clearSelection,
                          child: const Text('선택 해제'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('이 조건에 맞는 후보가 없습니다.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, visibleIndex) {
                        final index = visible[visibleIndex];
                        final candidate = _candidates[index];
                        return _PdfCandidateCard(
                          key: ValueKey(candidate.id),
                          candidate: candidate,
                          onChanged: (value) => _update(index, value),
                        );
                      },
                    ),
            ),
            if (size.width < 640)
              Material(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: FilledButton.icon(
                    onPressed: _selectedCount == 0 || _missingMeaningCount > 0
                        ? null
                        : () => Navigator.pop(
                            context,
                            _candidates
                                .where((candidate) => candidate.selected)
                                .toList(growable: false),
                          ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text('기존 자료와 비교 ($_selectedCount)'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PdfCandidateCard extends StatefulWidget {
  const _PdfCandidateCard({
    super.key,
    required this.candidate,
    required this.onChanged,
  });

  final PdfImportCandidate candidate;
  final ValueChanged<PdfImportCandidate> onChanged;

  @override
  State<_PdfCandidateCard> createState() => _PdfCandidateCardState();
}

class _PdfCandidateCardState extends State<_PdfCandidateCard> {
  late final TextEditingController _term = TextEditingController(
    text: widget.candidate.term,
  );
  late final TextEditingController _meaning = TextEditingController(
    text: widget.candidate.meaning,
  );

  @override
  void dispose() {
    _term.dispose();
    _meaning.dispose();
    super.dispose();
  }

  void _emit({bool? selected}) {
    widget.onChanged(
      widget.candidate.copyWith(
        term: _term.text,
        meaning: _meaning.text,
        selected: selected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidate = widget.candidate;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: candidate.selected,
              onChanged: (value) => _emit(selected: value ?? false),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('p.${candidate.pageNumber}'),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('빈도 ${candidate.frequency}'),
                      ),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          candidate.kind == PdfCandidateKind.mappedPair
                              ? '단어–뜻'
                              : '일반 문서',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final fields = [
                        TextField(
                          controller: _term,
                          onChanged: (_) => _emit(),
                          decoration: const InputDecoration(labelText: '단어'),
                        ),
                        TextField(
                          controller: _meaning,
                          onChanged: (_) => _emit(),
                          decoration: InputDecoration(
                            labelText: '뜻',
                            errorText:
                                candidate.selected && !candidate.hasMeaning
                                ? '뜻을 입력해 주세요.'
                                : null,
                          ),
                        ),
                      ];
                      if (constraints.maxWidth < 560) {
                        return Column(
                          children: [
                            fields[0],
                            const SizedBox(height: 8),
                            fields[1],
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: fields[0]),
                          const SizedBox(width: 10),
                          Expanded(child: fields[1]),
                        ],
                      );
                    },
                  ),
                  if (candidate.excerpt.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      candidate.excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
