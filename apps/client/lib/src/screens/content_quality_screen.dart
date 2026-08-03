import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/content_quality_audit.dart';
import '../domain/exercise_readiness.dart';
import '../state/app_state.dart';

class ContentQualityScreen extends ConsumerStatefulWidget {
  const ContentQualityScreen({super.key});

  @override
  ConsumerState<ContentQualityScreen> createState() =>
      _ContentQualityScreenState();
}

class _ContentQualityScreenState extends ConsumerState<ContentQualityScreen> {
  ContentQualityIssueKind? _filter;
  var _cursor = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final customIds = state.customItems.map((item) => item.id).toSet();
    final report = const ContentQualityAuditor().audit(
      controller.courseItems,
      corrections: state.preferences.contentCorrections,
    );
    final filtered = report.results
        .where((result) => _filter == null || result.hasIssue(_filter!))
        .toList(growable: false);
    if (_cursor >= filtered.length) _cursor = 0;
    final ordered = filtered.isEmpty
        ? const <ContentQualityResult>[]
        : [...filtered.skip(_cursor), ...filtered.take(_cursor)];

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            key: const Key('content-quality-screen'),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    key: const Key('close-content-quality'),
                    onPressed: () => context.pop(),
                    tooltip: '뒤로',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '학습 자료 점검',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '자료는 그대로 저장할 수 있어요. 더 다양한 문제에 필요한 정보만 확인합니다.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _QualityScoreBadge(score: report.averageScore),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${report.results.length}개 항목 · 평균 ${report.averageScore}점',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        key: const Key('content-quality-filters'),
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          FilterChip(
                            key: const Key('quality-filter-all'),
                            label: const Text('전체'),
                            selected: _filter == null,
                            onSelected: (_) => setState(() {
                              _filter = null;
                              _cursor = 0;
                            }),
                          ),
                          for (final kind in ContentQualityIssueKind.values)
                            FilterChip(
                              key: Key('quality-filter-${kind.name}'),
                              label: Text(
                                '${kind.label} ${report.count(kind)}',
                              ),
                              selected: _filter == kind,
                              onSelected: (_) => setState(() {
                                _filter = kind;
                                _cursor = 0;
                              }),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (ordered.isEmpty)
                const _QualityEmptyState()
              else ...[
                FilledButton.tonalIcon(
                  key: const Key('next-quality-item'),
                  onPressed: () => setState(() {
                    _cursor = (_cursor + 1) % filtered.length;
                  }),
                  icon: const Icon(Icons.skip_next_rounded),
                  label: Text('다음 자료 수정 · ${ordered.first.item.text}'),
                ),
                const SizedBox(height: 12),
                for (final result in ordered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _QualityItemCard(
                      result: result,
                      editable: customIds.contains(result.item.id),
                      onEdit: () => context.push(
                        '/library/edit/${Uri.encodeComponent(result.item.id)}',
                      ),
                      onInspect: () => context.go(
                        '/library?q=${Uri.encodeQueryComponent(result.item.text)}',
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QualityScoreBadge extends StatelessWidget {
  const _QualityScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '콘텐츠 품질 평균 $score점',
    child: CircleAvatar(
      radius: 28,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: Text(
        '$score',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
    ),
  );
}

class _QualityItemCard extends StatelessWidget {
  const _QualityItemCard({
    required this.result,
    required this.editable,
    required this.onEdit,
    required this.onInspect,
  });

  final ContentQualityResult result;
  final bool editable;
  final VoidCallback onEdit;
  final VoidCallback onInspect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: Key('quality-item-${result.item.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: result.score >= 80
                      ? colors.secondaryContainer
                      : colors.errorContainer,
                  child: Text('${result.score}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.item.text,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        result.item.translations
                            .where((value) => value.trim().isNotEmpty)
                            .join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: Key(
                    editable
                        ? 'edit-quality-${result.item.id}'
                        : 'inspect-quality-${result.item.id}',
                  ),
                  onPressed: editable ? onEdit : onInspect,
                  icon: Icon(
                    editable ? Icons.edit_outlined : Icons.lock_outline_rounded,
                    size: 18,
                  ),
                  label: Text(editable ? '수정' : '내용 보기'),
                ),
              ],
            ),
            if (result.issues.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final issue in result.issues)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text('${issue.kind.label} · ${issue.message}'),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final status in result.exerciseReadiness)
                  Tooltip(
                    message: status.reason,
                    child: Chip(
                      avatar: Icon(
                        status.ready
                            ? Icons.check_circle_outline_rounded
                            : Icons.block_rounded,
                        size: 16,
                      ),
                      label: Text(status.kind.label),
                      side: BorderSide(
                        color: status.ready ? colors.primary : colors.error,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityEmptyState extends StatelessWidget {
  const _QualityEmptyState();

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('content-quality-empty'),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.verified_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 9),
          Text(
            '이 조건에서 고칠 자료는 없어요.',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          const Text('선택한 연습에 바로 사용할 수 있는 자료예요.'),
        ],
      ),
    ),
  );
}
