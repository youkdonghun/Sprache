import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';

import '../domain/learning_item.dart';
import '../domain/progress.dart';
import '../domain/study_history.dart';
import '../state/app_state.dart';

enum FlashcardKind { mixed, words, sentences }

class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({
    this.kind = FlashcardKind.mixed,
    this.unitIndex,
    super.key,
  });

  final FlashcardKind kind;
  final int? unitIndex;

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  final _tts = FlutterTts();
  final _requeued = <String>{};

  late List<LearningItem> _queue;
  late DateTime _startedAt;
  var _index = 0;
  var _remembered = 0;
  var _again = 0;
  var _earnedXp = 0;
  var _revealed = false;
  var _completed = false;
  var _saved = false;

  LearningItem get _item => _queue[_index];

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    final controller = ref.read(appControllerProvider.notifier);
    final progress = ref.read(appControllerProvider).progress;
    final sourceItems = widget.unitIndex == null
        ? controller.selectedItems
        : controller.itemsForUnit(widget.unitIndex!);
    final items = sourceItems.where((item) {
      return switch (widget.kind) {
        FlashcardKind.mixed => true,
        FlashcardKind.words => item.kind == LearningItemKind.word,
        FlashcardKind.sentences => item.kind == LearningItemKind.sentence,
      };
    }).toList();
    items.sort((left, right) {
      final leftProgress = progress[left.id];
      final rightProgress = progress[right.id];
      if (leftProgress == null && rightProgress != null) return -1;
      if (leftProgress != null && rightProgress == null) return 1;
      if (leftProgress != null && rightProgress != null) {
        final accuracy = leftProgress.accuracy.compareTo(
          rightProgress.accuracy,
        );
        if (accuracy != 0) return accuracy;
      }
      return right.priority.compareTo(left.priority);
    });
    _queue = items
        .take(ref.read(appControllerProvider).preferences.sessionItemLimit)
        .toList(growable: true);
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
      // The platform channel is absent in widget tests and some headless runs.
    }
  }

  Future<void> _speak() async {
    await _tts.setLanguage(_item.learningLanguage.ttsLocale);
    await _tts.setSpeechRate(
      ref.read(appControllerProvider).preferences.ttsRate,
    );
    await _tts.speak(_item.text);
  }

  void _reveal() {
    setState(() => _revealed = true);
  }

  void _rate(ReviewRating rating) {
    if (!_revealed) return;
    final item = _item;
    final remembered = rating != ReviewRating.again;
    final xp = switch (rating) {
      ReviewRating.again => 5,
      ReviewRating.hard => 8,
      ReviewRating.good => 10,
      ReviewRating.easy => 15,
    };
    ref
        .read(appControllerProvider.notifier)
        .recordAnswer(
          item: item,
          correct: remembered,
          studiedAt: DateTime.now(),
          exerciseType: 'flashcard_${rating.name}',
          rating: rating,
        );
    _earnedXp += xp;
    if (remembered) {
      _remembered++;
    } else {
      _again++;
      if (_requeued.add(item.id)) _queue.add(item);
    }

    if (_index + 1 >= _queue.length) {
      unawaited(_saveSession());
      setState(() => _completed = true);
      return;
    }
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  Future<void> _saveSession() async {
    if (_saved || _remembered + _again == 0) return;
    _saved = true;
    await ref
        .read(appControllerProvider.notifier)
        .finishSession(
          StudySessionSummary(
            sessionId: 'cards-${_startedAt.toUtc().microsecondsSinceEpoch}',
            courseId: ref.read(appControllerProvider).selectedLanguage.courseId,
            startedAt: _startedAt,
            endedAt: DateTime.now(),
            correctCount: _remembered,
            wrongCount: _again,
            earnedXp: _earnedXp,
          ),
        );
  }

  void _close() {
    unawaited(_saveSession());
    context.go(widget.unitIndex == null ? '/learn' : '/path');
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) {
      return _EmptyLearningScreen(
        title: '학습할 카드가 없어요',
        description: '단어장에서 이 코스의 단어와 문장을 추가해 주세요.',
        onClose: _close,
      );
    }
    if (_completed) {
      return _CardCompletion(
        remembered: _remembered,
        again: _again,
        minutes: max(1, DateTime.now().difference(_startedAt).inMinutes),
        onHub: () => context.go(widget.unitIndex == null ? '/learn' : '/path'),
        onQuiz: () => context.go(
          widget.unitIndex == null
              ? '/study?mode=meaning'
              : '/study?mode=meaning&unit=${widget.unitIndex}',
        ),
        returnLabel: widget.unitIndex == null ? '학습실로 돌아가기' : '코스 여정으로',
      );
    }

    final favorite = ref.watch(
      appControllerProvider.select(
        (state) => state.preferences.isFavorite(_item.id),
      ),
    );
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final controller = ref.read(appControllerProvider.notifier);
    final intervalLabels = {
      for (final rating in ReviewRating.values)
        rating: _intervalLabel(
          controller
              .previewReview(item: _item, rating: rating, studiedAt: now)
              .nextReviewAt!,
          now,
        ),
    };
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _reveal,
        const SingleActivator(LogicalKeyboardKey.space): _speak,
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.digit1): () =>
            _rate(ReviewRating.again),
        const SingleActivator(LogicalKeyboardKey.digit2): () =>
            _rate(ReviewRating.hard),
        const SingleActivator(LogicalKeyboardKey.digit3): () =>
            _rate(ReviewRating.good),
        const SingleActivator(LogicalKeyboardKey.digit4): () =>
            _rate(ReviewRating.easy),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              key: const Key('close-flashcards'),
              onPressed: _close,
              icon: const Icon(Icons.close_rounded),
              tooltip: '카드 학습 종료',
            ),
            titleSpacing: 4,
            title: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: (_index + 1) / _queue.length,
                minHeight: 9,
              ),
            ),
            actions: [
              IconButton(
                key: const Key('toggle-flashcard-favorite'),
                onPressed: () => ref
                    .read(appControllerProvider.notifier)
                    .toggleFavorite(_item.id),
                tooltip: favorite ? '저장 해제' : '표현 저장',
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: favorite ? const Color(0xFFF59E0B) : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Center(
                  child: Text(
                    '${_index + 1} / ${_queue.length}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth < 600 ? 16 : 24,
                    16,
                    constraints.maxWidth < 600 ? 16 : 24,
                    24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              _LearningPill(
                                icon: Icons.style_rounded,
                                label: _revealed ? '뜻과 읽는 법 확인' : '먼저 소리 내어 읽기',
                              ),
                              const Spacer(),
                              Text(
                                widget.unitIndex == null
                                    ? _item.kind == LearningItemKind.word
                                          ? '단어'
                                          : '문장'
                                    : 'Unit ${widget.unitIndex! + 1}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Semantics(
                            button: !_revealed,
                            label: _revealed ? '카드 뒷면' : '카드 앞면, 눌러서 뜻 보기',
                            child: Card(
                              color: _revealed
                                  ? colors.secondaryContainer
                                  : colors.surface,
                              child: InkWell(
                                key: const Key('flashcard-surface'),
                                onTap: _revealed ? null : _reveal,
                                borderRadius: BorderRadius.circular(18),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minHeight: 330,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 30,
                                    ),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      child: _revealed
                                          ? _FlashcardBack(
                                              key: const ValueKey('back'),
                                              item: _item,
                                              onSpeak: _speak,
                                            )
                                          : _FlashcardFront(
                                              key: const ValueKey('front'),
                                              item: _item,
                                              onSpeak: _speak,
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _revealed
                                ? '기억이 났는지 스스로 판단해 주세요. 어려웠던 카드는 마지막에 한 번 더 나옵니다.'
                                : '시험이 아닙니다. 충분히 읽어 본 뒤 카드를 뒤집으세요.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.outlineVariant)),
              ),
              child: Align(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _revealed
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final buttonWidth = constraints.maxWidth < 560
                                ? (constraints.maxWidth - 8) / 2
                                : (constraints.maxWidth - 24) / 4;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _RatingButton(
                                  key: const Key('flashcard-again'),
                                  width: buttonWidth,
                                  icon: Icons.replay_rounded,
                                  label: '다시',
                                  shortcut: '1',
                                  interval: intervalLabels[ReviewRating.again]!,
                                  onPressed: () => _rate(ReviewRating.again),
                                ),
                                _RatingButton(
                                  key: const Key('flashcard-hard'),
                                  width: buttonWidth,
                                  icon: Icons.psychology_alt_rounded,
                                  label: '어려움',
                                  shortcut: '2',
                                  interval: intervalLabels[ReviewRating.hard]!,
                                  onPressed: () => _rate(ReviewRating.hard),
                                ),
                                _RatingButton(
                                  key: const Key('flashcard-remembered'),
                                  width: buttonWidth,
                                  icon: Icons.check_rounded,
                                  label: '기억남',
                                  shortcut: '3',
                                  interval: intervalLabels[ReviewRating.good]!,
                                  emphasized: true,
                                  onPressed: () => _rate(ReviewRating.good),
                                ),
                                _RatingButton(
                                  key: const Key('flashcard-easy'),
                                  width: buttonWidth,
                                  icon: Icons.bolt_rounded,
                                  label: '쉬움',
                                  shortcut: '4',
                                  interval: intervalLabels[ReviewRating.easy]!,
                                  onPressed: () => _rate(ReviewRating.easy),
                                ),
                              ],
                            );
                          },
                        )
                      : FilledButton.icon(
                          key: const Key('reveal-flashcard'),
                          onPressed: _reveal,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                          ),
                          icon: const Icon(Icons.visibility_rounded),
                          label: const Text('뜻과 설명 보기'),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _intervalLabel(DateTime reviewAt, DateTime now) {
  final difference = reviewAt.difference(now);
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes.clamp(1, 59)}분';
  }
  if (difference.inHours < 24) return '${difference.inHours}시간';
  return '${difference.inDays.clamp(1, 9999)}일';
}

class _RatingButton extends StatelessWidget {
  const _RatingButton({
    required this.width,
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.interval,
    required this.onPressed,
    this.emphasized = false,
    super.key,
  });

  final double width;
  final IconData icon;
  final String label;
  final String shortcut;
  final String interval;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            '$label [$shortcut] · $interval',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    return SizedBox(
      width: width,
      height: 58,
      child: emphasized
          ? FilledButton(onPressed: onPressed, child: content)
          : OutlinedButton(onPressed: onPressed, child: content),
    );
  }
}

class _FlashcardFront extends StatelessWidget {
  const _FlashcardFront({required this.item, required this.onSpeak, super.key});

  final LearningItem item;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          item.learningLanguage.nativeName,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          item.text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onSpeak,
          icon: const Icon(Icons.volume_up_rounded),
          label: const Text('발음 듣기'),
        ),
      ],
    );
  }
}

class _FlashcardBack extends StatelessWidget {
  const _FlashcardBack({required this.item, required this.onSpeak, super.key});

  final LearningItem item;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                item.text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            IconButton(
              onPressed: onSpeak,
              tooltip: '발음 듣기',
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ],
        ),
        if (item.readings.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            item.readings.map((reading) => reading.value).join(' · '),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colors.primary),
          ),
        ],
        const SizedBox(height: 18),
        Divider(color: colors.onSecondaryContainer.withValues(alpha: 0.2)),
        const SizedBox(height: 18),
        Text(
          item.primaryTranslation,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: colors.onSecondaryContainer,
          ),
        ),
        if (item.example case final example?) ...[
          const SizedBox(height: 20),
          Text(example, textAlign: TextAlign.center),
          if (item.exampleTranslation case final translation?)
            Text(
              translation,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ],
    );
  }
}

class _LearningPill extends StatelessWidget {
  const _LearningPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colors.onPrimaryContainer),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardCompletion extends StatelessWidget {
  const _CardCompletion({
    required this.remembered,
    required this.again,
    required this.minutes,
    required this.onHub,
    required this.onQuiz,
    required this.returnLabel,
  });

  final int remembered;
  final int again;
  final int minutes;
  final VoidCallback onHub;
  final VoidCallback onQuiz;
  final String returnLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '카드 학습을 마쳤어요',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$minutes분 동안 기억남 $remembered개 · 다시 보기 $again개',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onQuiz,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.touch_app_rounded),
                    label: const Text('뜻 고르기로 확인하기'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onHub,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: Text(returnLabel),
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

class _EmptyLearningScreen extends StatelessWidget {
  const _EmptyLearningScreen({
    required this.title,
    required this.description,
    required this.onClose,
  });

  final String title;
  final String description;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.style_outlined, size: 56),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(description, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
