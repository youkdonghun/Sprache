import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/exam_pack.dart';
import '../domain/exam_session.dart';
import '../state/exam_state.dart';

class ExamHubScreen extends ConsumerWidget {
  const ExamHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(examStudyControllerProvider);
    final controller = ref.read(examStudyControllerProvider.notifier);
    final pack = state.library.primaryPack;

    Future<void> start(ExamSessionMode mode, {ExamPart? part}) async {
      try {
        await controller.startSession(mode: mode, part: part);
        if (context.mounted) await context.push('/exam/session');
      } on Object catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is StateError ? error.message : '시험을 시작하지 못했습니다.',
            ),
          ),
        );
      }
    }

    Future<void> choosePart() async {
      final part = await showModalBottomSheet<ExamPart>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            children: [
              const ListTile(
                title: Text(
                  '파트 선택',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('연습할 파트를 고르세요.'),
              ),
              for (final value in ExamPart.values)
                ListTile(
                  key: Key('exam-part-${value.number}'),
                  leading: CircleAvatar(child: Text('${value.number}')),
                  title: Text('${value.label} · ${value.koreanTitle}'),
                  subtitle: Text(
                    value.isListening
                        ? '듣기 · ${pack?.questionCountFor(value) ?? 0}문제'
                        : '읽기 · ${pack?.questionCountFor(value) ?? 0}문제',
                  ),
                  onTap: () => Navigator.pop(context, value),
                ),
            ],
          ),
        ),
      );
      if (part != null) await start(ExamSessionMode.part, part: part);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('비즈니스 영어 실전'),
        leading: IconButton(
          tooltip: '돌아가기',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
              children: [
                if (state.loading && pack == null)
                  const _ExamLoadingCard()
                else if (pack == null)
                  _ExamErrorCard(
                    message: state.errorMessage ?? '사용할 수 있는 시험팩이 없습니다.',
                    onRetry: () =>
                        unawaited(controller.prepare(forceRefresh: true)),
                  )
                else ...[
                  _ExamPackHeader(pack: pack, offlineReady: true),
                  if (state.library.activeSession case final active?) ...[
                    const SizedBox(height: 14),
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: ListTile(
                        key: const Key('resume-exam-session'),
                        leading: const Icon(Icons.play_circle_fill_rounded),
                        title: const Text(
                          '풀던 시험 이어하기',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          '${active.currentIndex + 1}/${active.questionIds.length} · '
                          '답안 ${active.answers.length}개 저장됨',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/exam/session'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    '바로 시작',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ExamStartCard(
                    key: const Key('start-quick-exam'),
                    icon: Icons.bolt_rounded,
                    title: '빠른 10문제',
                    description: '시간 제한 없이 짧게 풀고 바로 풀이를 봅니다.',
                    badge: '10문제',
                    onTap: () => unawaited(start(ExamSessionMode.quick)),
                  ),
                  const SizedBox(height: 10),
                  _ExamStartCard(
                    key: const Key('choose-exam-part'),
                    icon: Icons.view_list_rounded,
                    title: '파트별 연습',
                    description: 'Part 1~7 중 하나를 시간 제한 없이 연습합니다.',
                    badge: '파트 선택',
                    onTap: () => unawaited(choosePart()),
                  ),
                  const SizedBox(height: 10),
                  _ExamStartCard(
                    key: const Key('start-full-mock'),
                    icon: Icons.timer_rounded,
                    title: '실전 모의고사',
                    description: '듣기 100문제와 읽기 100문제를 120분 동안 풉니다.',
                    badge: '200문제',
                    enabled: pack.supportsFullMock,
                    onTap: () => unawaited(start(ExamSessionMode.mock)),
                  ),
                  if (state.library.wrongQuestionIds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _ExamStartCard(
                      key: const Key('start-wrong-exam'),
                      icon: Icons.replay_rounded,
                      title: '틀린 문제 다시 풀기',
                      description: '최근 답안을 기준으로 아직 틀린 문제만 모았습니다.',
                      badge: '${state.library.wrongQuestionIds.length}문제',
                      onTap: () =>
                          unawaited(start(ExamSessionMode.wrongAnswers)),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _ExamProgressCard(
                    attempts: state.library.attempts,
                    pack: pack,
                  ),
                  const SizedBox(height: 12),
                  _ExamNoticeCard(
                    pack: pack,
                    busy: state.busy,
                    onRefresh: () =>
                        unawaited(controller.prepare(forceRefresh: true)),
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

class _ExamLoadingCard extends StatelessWidget {
  const _ExamLoadingCard();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('시험팩을 처음 한 번 준비하고 있어요.'),
        ],
      ),
    ),
  );
}

class _ExamErrorCard extends StatelessWidget {
  const _ExamErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('다시 준비'),
          ),
        ],
      ),
    ),
  );
}

class _ExamPackHeader extends StatelessWidget {
  const _ExamPackHeader({required this.pack, required this.offlineReady});

  final ExamPack pack;
  final bool offlineReady;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colors.secondary,
              foregroundColor: colors.onSecondary,
              child: const Icon(Icons.assignment_rounded),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pack.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${pack.questions.length}문제 · Part 1~7 · 모든 문제 풀이 포함'),
                  const SizedBox(height: 4),
                  Text(
                    offlineReady ? '다운로드 완료 · 오프라인 사용 가능' : '다운로드 필요',
                    style: TextStyle(
                      color: colors.onSecondaryContainer.withValues(
                        alpha: 0.75,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamStartCard extends StatelessWidget {
  const _ExamStartCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final String badge;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(description),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(badge, style: Theme.of(context).textTheme.labelMedium),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: enabled ? onTap : null,
    ),
  );
}

class _ExamProgressCard extends StatelessWidget {
  const _ExamProgressCard({required this.attempts, required this.pack});

  final List<ExamAttemptSummary> attempts;
  final ExamPack pack;

  @override
  Widget build(BuildContext context) {
    final latest = attempts.firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '최근 기록',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (latest == null)
              const Text('아직 푼 시험이 없어요. 빠른 10문제로 시작해 보세요.')
            else ...[
              Text(
                '${latest.correctCount}/${latest.totalCount} 정답 · ${(latest.accuracy * 100).round()}%',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final part in ExamPart.values)
                    if (_hasPartResult(part, latest, pack))
                      _partChip(part, latest, pack),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasPartResult(ExamPart part, ExamAttemptSummary latest, ExamPack pack) {
    final attemptedIds = latest.questionIds.toSet();
    return pack.questions.any(
      (question) => question.part == part && attemptedIds.contains(question.id),
    );
  }

  Widget _partChip(ExamPart part, ExamAttemptSummary latest, ExamPack pack) {
    final ids = pack.questions
        .where((q) => q.part == part)
        .map((q) => q.id)
        .toSet();
    final attemptedIds = latest.questionIds.where(ids.contains).toSet();
    final answers = latest.answers.values
        .where((answer) => attemptedIds.contains(answer.questionId))
        .toList();
    final correct = answers.where((answer) => answer.correct).length;
    return Chip(label: Text('${part.label} $correct/${attemptedIds.length}'));
  }
}

class _ExamNoticeCard extends StatelessWidget {
  const _ExamNoticeCard({
    required this.pack,
    required this.busy,
    required this.onRefresh,
  });

  final ExamPack pack;
  final bool busy;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: const Text('문제팩 관리'),
      subtitle: Text('v${pack.version} · 독자 제작 문제'),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text('${pack.attribution}\n\n${pack.disclaimer}'),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onRefresh,
            icon: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(busy ? '확인 중' : '문제 업데이트 확인'),
          ),
        ),
      ],
    ),
  );
}
