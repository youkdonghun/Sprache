import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/course_notes.dart';
import '../domain/course_path.dart';
import '../domain/learning_item.dart';
import '../services/media_lifecycle_coordinator.dart';
import '../services/tts_service.dart';
import '../state/app_state.dart';
import '../state/device_preferences_state.dart';

class UnitGuideScreen extends ConsumerStatefulWidget {
  const UnitGuideScreen({required this.unitIndex, this.ttsService, super.key});

  final int unitIndex;
  final TtsService? ttsService;

  @override
  ConsumerState<UnitGuideScreen> createState() => _UnitGuideScreenState();
}

class _UnitGuideScreenState extends ConsumerState<UnitGuideScreen> {
  late final MediaLifecycleRegistry _mediaLifecycleRegistry;
  late final TtsService _tts;

  @override
  void initState() {
    super.initState();
    _tts = widget.ttsService ?? TtsService.device();
    _mediaLifecycleRegistry = ref.read(mediaLifecycleRegistryProvider);
    _mediaLifecycleRegistry.register(
      this,
      MediaLifecycleRegistration(stopTextToSpeech: _stopTts),
    );
  }

  @override
  void dispose() {
    _mediaLifecycleRegistry.unregister(this);
    unawaited(_stopTts());
    super.dispose();
  }

  Future<void> _stopTts() async {
    try {
      await _tts.stop();
    } catch (_) {
      // The platform channel is absent in widget tests and headless runs.
    }
  }

  Future<void> _speak(LearningItem item) async {
    final preferences = ref.read(appControllerProvider).preferences;
    final voice = ref
        .read(devicePreferencesControllerProvider)
        .preferences
        .voice;
    try {
      await _tts.speak(
        language: item.learningLanguage,
        text: item.text,
        rate: preferences.ttsRate,
        preferOfflineVoice: preferences.interaction.preferOfflineVoice,
        repeatCount: preferences.interaction.audioRepeatCount,
        preferredVoiceId: voice.voiceIdByLanguage[item.learningLanguage.code],
        pitch: voice.pitch,
      );
    } catch (_) {
      // Unit browsing remains available when the device has no matching voice.
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
          child: const Text('코스로 돌아가기'),
        ),
      );
    }
    final unit = path.units[widget.unitIndex];
    final note = courseNoteFor(state.selectedLanguage, widget.unitIndex);
    final interaction = state.preferences.interaction;
    final lessons = [
      CourseLessonKind.cards,
      CourseLessonKind.meaning,
      CourseLessonKind.writing,
      if (unit.sentences.isNotEmpty) CourseLessonKind.sentence,
      CourseLessonKind.listening,
      CourseLessonKind.speaking,
    ];

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final padding = compact ? 18.0 : 28.0;
          return CustomScrollView(
            key: const Key('unit-guide-scroll'),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding, 16, padding, 36),
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
                                onPressed: () => context.go('/path'),
                                tooltip: '코스로 돌아가기',
                                icon: const Icon(Icons.arrow_back_rounded),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Unit ${unit.index + 1} 가이드',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge,
                                    ),
                                    Text(
                                      unit.title,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                  ],
                                ),
                              ),
                              _ProgressRing(progress: unit.progress),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _GoalCard(unit: unit),
                          const SizedBox(height: 12),
                          _PatternPreview(
                            note: note,
                            onOpen: () => context.push('/notes/${unit.index}'),
                          ),
                          const SizedBox(height: 24),
                          _SectionHeader(
                            title: '핵심 단어',
                            caption: '단어를 보고 발음을 들어 보세요.',
                            count: unit.words.length,
                          ),
                          const SizedBox(height: 10),
                          _WordPreviewGrid(
                            items: unit.words.take(8).toList(growable: false),
                            showKoreanReading: interaction.showKoreanReading,
                            showNativeReading: interaction.showNativeReading,
                            onSpeak: _speak,
                          ),
                          const SizedBox(height: 24),
                          _SectionHeader(
                            title: '핵심 문장',
                            caption: '뜻을 확인하고 문장을 소리 내어 읽어 보세요.',
                            count: unit.sentences.length,
                          ),
                          const SizedBox(height: 10),
                          if (unit.sentences.isEmpty)
                            const _EmptyUnitSection(
                              message: '이 단원은 핵심 단어를 집중해서 익혀요.',
                            )
                          else
                            for (final sentence in unit.sentences.take(4))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _SentencePreview(
                                  item: sentence,
                                  showKoreanReading:
                                      interaction.showKoreanReading,
                                  showNativeReading:
                                      interaction.showNativeReading,
                                  onSpeak: () => _speak(sentence),
                                ),
                              ),
                          const SizedBox(height: 14),
                          _SectionHeader(
                            title: '추천 학습 순서',
                            caption: '보고 익힌 뒤 듣기와 말하기로 이어가세요.',
                            count: lessons.length,
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, lessonConstraints) {
                              final columns = lessonConstraints.maxWidth >= 700
                                  ? 2
                                  : 1;
                              final width =
                                  (lessonConstraints.maxWidth -
                                      (columns - 1) * 10) /
                                  columns;
                              return Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final (index, lesson) in lessons.indexed)
                                    SizedBox(
                                      width: width,
                                      child: _LessonStep(
                                        index: index,
                                        lesson: lesson,
                                        recommended: lesson == unit.nextLesson,
                                        onTap: () => context.push(
                                          courseLessonRoute(lesson, unit.index),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            key: const Key('start-unit-next-lesson'),
                            onPressed: () => context.push(
                              courseLessonRoute(unit.nextLesson, unit.index),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text('다음 학습 · ${unit.nextLesson.label}'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            key: const Key('start-unit-mission'),
                            onPressed: () =>
                                context.push('/mission/${unit.index}'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                            ),
                            icon: const Icon(Icons.forum_rounded),
                            label: const Text('실전 미션에서 써 보기'),
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

class _PatternPreview extends StatelessWidget {
  const _PatternPreview({required this.note, required this.onOpen});

  final CourseNote note;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final copy = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '이 단원의 표현 노트',
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: colors.primary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        note.pattern,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        note.patternMeaning,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            );
            final button = OutlinedButton.icon(
              key: const Key('open-unit-notes'),
              onPressed: onOpen,
              style: OutlinedButton.styleFrom(minimumSize: const Size(146, 48)),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('표현 노트 열기'),
            );
            if (constraints.maxWidth < 620) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 14), button],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 18),
                button,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.unit});

  final CourseUnitSnapshot unit;

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
              child: Icon(Icons.flag_rounded, color: colors.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이 단원에서 할 수 있는 말',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    unit.goal,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '단어 ${unit.words.length}개 · 문장 ${unit.sentences.length}개',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onPrimaryContainer.withValues(alpha: 0.78),
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

class _WordPreviewGrid extends StatelessWidget {
  const _WordPreviewGrid({
    required this.items,
    required this.showKoreanReading,
    required this.showNativeReading,
    required this.onSpeak,
  });

  final List<LearningItem> items;
  final bool showKoreanReading;
  final bool showNativeReading;
  final ValueChanged<LearningItem> onSpeak;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyUnitSection(message: '이 단원에 표시할 핵심 단어가 없어요.');
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.text,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (item
                                  .readingAidsLabelFor(
                                    showKoreanReading: showKoreanReading,
                                    showNativeReading: showNativeReading,
                                  )
                                  .isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  item.readingAidsLabelFor(
                                    showKoreanReading: showKoreanReading,
                                    showNativeReading: showNativeReading,
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        height: 1.4,
                                      ),
                                ),
                              ],
                              Text(
                                item.primaryTranslation,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => onSpeak(item),
                          tooltip: '${item.text} 발음 듣기',
                          icon: const Icon(Icons.volume_up_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SentencePreview extends StatelessWidget {
  const _SentencePreview({
    required this.item,
    required this.showKoreanReading,
    required this.showNativeReading,
    required this.onSpeak,
  });

  final LearningItem item;
  final bool showKoreanReading;
  final bool showNativeReading;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final readingAidsLabel = item.readingAidsLabelFor(
      showKoreanReading: showKoreanReading,
      showNativeReading: showNativeReading,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (readingAidsLabel.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      readingAidsLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    item.primaryTranslation,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onSpeak,
              tooltip: '문장 발음 듣기',
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonStep extends StatelessWidget {
  const _LessonStep({
    required this.index,
    required this.lesson,
    required this.recommended,
    required this.onTap,
  });

  final int index;
  final CourseLessonKind lesson;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: recommended ? colors.primaryContainer : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: recommended ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 78),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: recommended
                        ? colors.onPrimaryContainer.withValues(alpha: 0.1)
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        lesson.label,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lesson.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (recommended)
                  const Icon(Icons.star_rounded)
                else
                  const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.caption,
    required this.count,
  });

  final String title;
  final String caption;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          '$count',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 5,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
          Text(
            '${(progress * 100).round()}',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _EmptyUnitSection extends StatelessWidget {
  const _EmptyUnitSection({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}
