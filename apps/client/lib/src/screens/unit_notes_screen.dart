import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/course_notes.dart';
import '../domain/course_path.dart';
import '../domain/language.dart';
import '../services/tts_service.dart';
import '../state/app_state.dart';

class UnitNotesScreen extends ConsumerStatefulWidget {
  const UnitNotesScreen({required this.unitIndex, this.ttsService, super.key});

  final int unitIndex;
  final TtsService? ttsService;

  @override
  ConsumerState<UnitNotesScreen> createState() => _UnitNotesScreenState();
}

class _UnitNotesScreenState extends ConsumerState<UnitNotesScreen> {
  late final TtsService _tts;

  @override
  void initState() {
    super.initState();
    _tts = widget.ttsService ?? TtsService.device();
  }

  @override
  void dispose() {
    unawaited(_stopTts());
    super.dispose();
  }

  Future<void> _stopTts() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Platform channels are unavailable in widget tests.
    }
  }

  Future<void> _speak(String text, LanguageTag language) async {
    final preferences = ref.read(appControllerProvider).preferences;
    try {
      await _tts.speak(
        language: language,
        text: text,
        rate: preferences.ttsRate,
        preferOfflineVoice: preferences.interaction.preferOfflineVoice,
        repeatCount: preferences.interaction.audioRepeatCount,
      );
    } catch (_) {
      // Reading notes remains usable when TTS is unavailable.
    }
  }

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/unit/${widget.unitIndex}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final path = ref.read(appControllerProvider.notifier).coursePath;
    if (widget.unitIndex < 0 || widget.unitIndex >= path.units.length) {
      return Center(
        child: FilledButton(
          onPressed: () => context.go('/path'),
          child: const Text('코스 여정으로 돌아가기'),
        ),
      );
    }

    final unit = path.units[widget.unitIndex];
    final note = courseNoteFor(state.selectedLanguage, widget.unitIndex);
    final language = state.selectedLanguage;
    final hasPrevious = widget.unitIndex > 0;
    final hasNext = widget.unitIndex + 1 < path.units.length;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final padding = compact ? 18.0 : 28.0;
          return CustomScrollView(
            key: const Key('unit-notes-scroll'),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 14, padding, 36),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => _close(context),
                                tooltip: '단원 가이드로',
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${language.koreanName} · Unit ${unit.index + 1} 표현 노트',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge,
                                    ),
                                    Text(
                                      note.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                  ],
                                ),
                              ),
                              _NoteLanguageBadge(language: language),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _NoteOverviewCard(
                            unitTitle: unit.title,
                            summary: note.summary,
                          ),
                          const SizedBox(height: 18),
                          _PatternCard(note: note),
                          const SizedBox(height: 24),
                          Text(
                            '문장으로 익히기',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '한국어 뜻을 가리고 먼저 읽은 뒤 발음을 들어 보세요.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          for (final (index, example) in note.examples.indexed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ExampleCard(
                                index: index,
                                example: example,
                                onSpeak: () => _speak(example.target, language),
                              ),
                            ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, tipConstraints) {
                              final columns = tipConstraints.maxWidth >= 700
                                  ? 2
                                  : 1;
                              final width =
                                  (tipConstraints.maxWidth -
                                      (columns - 1) * 10) /
                                  columns;
                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  SizedBox(
                                    width: width,
                                    child: _TipCard(
                                      icon: Icons.chat_bubble_outline_rounded,
                                      title: '이렇게 사용해요',
                                      body: note.usageTip,
                                    ),
                                  ),
                                  SizedBox(
                                    width: width,
                                    child: _TipCard(
                                      icon: Icons.graphic_eq_rounded,
                                      title: '소리 포인트',
                                      body: note.soundTip,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 22),
                          _PracticeActions(unit: unit),
                          const SizedBox(height: 20),
                          _UnitNavigation(
                            unitIndex: unit.index,
                            hasPrevious: hasPrevious,
                            hasNext: hasNext,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NoteLanguageBadge extends StatelessWidget {
  const _NoteLanguageBadge({required this.language});

  final LanguageTag language;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        language.symbol,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _NoteOverviewCard extends StatelessWidget {
  const _NoteOverviewCard({required this.unitTitle, required this.summary});

  final String unitTitle;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.onPrimaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unitTitle,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    summary,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onPrimaryContainer,
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

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.note});

  final CourseNote note;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree_outlined, color: colors.primary),
                const SizedBox(width: 9),
                Text('핵심 문형', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: SelectableText(
                note.pattern,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              note.patternMeaning,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.index,
    required this.example,
    required this.onSpeak,
  });

  final int index;
  final CourseNoteExample example;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    example.target,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    example.korean,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onSpeak,
              tooltip: '예문 발음 듣기',
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 148),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 5),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeActions extends StatelessWidget {
  const _PracticeActions({required this.unit});

  final CourseUnitSnapshot unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '이해했으면 바로 써 보기',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '노트를 읽는 데서 끝내지 말고 같은 단원의 표현을 꺼내 보세요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('notes-start-cards'),
                  onPressed: () =>
                      context.push('/cards?kind=mixed&unit=${unit.index}'),
                  icon: const Icon(Icons.style_rounded),
                  label: const Text('카드로 익히기'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.push('/study?mode=cloze&unit=${unit.index}'),
                  icon: const Icon(Icons.space_bar_rounded),
                  label: const Text('문장 빈칸'),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/mission/${unit.index}'),
                  icon: const Icon(Icons.forum_rounded),
                  label: const Text('실전 미션'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitNavigation extends StatelessWidget {
  const _UnitNavigation({
    required this.unitIndex,
    required this.hasPrevious,
    required this.hasNext,
  });

  final int unitIndex;
  final bool hasPrevious;
  final bool hasNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: hasPrevious
                ? () => context.go('/notes/${unitIndex - 1}')
                : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('이전 단원'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: hasNext
                ? () => context.go('/notes/${unitIndex + 1}')
                : () => context.go('/path'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            icon: Icon(
              hasNext ? Icons.chevron_right_rounded : Icons.route_rounded,
            ),
            label: Text(hasNext ? '다음 단원' : '코스 여정'),
          ),
        ),
      ],
    );
  }
}
