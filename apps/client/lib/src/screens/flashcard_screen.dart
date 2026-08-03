import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../domain/accessibility_input_profile.dart';
import '../domain/learning_item.dart';
import '../domain/progress.dart';
import '../domain/study_history.dart';
import '../domain/study_preferences.dart';
import '../services/media_lifecycle_coordinator.dart';
import '../services/tts_service.dart';
import '../state/app_state.dart';
import '../state/device_preferences_state.dart';
import '../state/local_storage_state.dart';
import '../theme/study_accessibility_theme.dart';

enum FlashcardKind { mixed, words, sentences }

class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({
    this.kind = FlashcardKind.mixed,
    this.unitIndex,
    this.customPlan = false,
    this.ttsService,
    super.key,
  });

  final FlashcardKind kind;
  final int? unitIndex;
  final bool customPlan;
  final TtsService? ttsService;

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  late final MediaLifecycleRegistry _mediaLifecycleRegistry;
  late final TtsService _tts;
  final _revealFocusNode = FocusNode(debugLabel: 'flashcard-reveal');
  final _rememberedFocusNode = FocusNode(
    debugLabel: 'flashcard-rating-remembered',
  );
  final _requeued = <String>{};
  final _attemptedItemIds = <String>{};
  final _wrongItemIds = <String>{};
  final _finalCorrectItemIds = <String>{};

  late List<LearningItem> _queue;
  late String _subjectIdAtStart;
  late String _courseIdAtStart;
  late DateTime _startedAt;
  late bool _recordProgress;
  late bool _backlogRecovery;
  late StudyHistoryFilter _historyFilter;
  var _index = 0;
  var _remembered = 0;
  var _again = 0;
  var _earnedXp = 0;
  var _revealed = false;
  var _completed = false;
  var _saved = false;
  var _subjectChangeHandled = false;
  String? _lastRatingLabel;

  LearningItem get _item => _queue[_index];

  @override
  void initState() {
    super.initState();
    _tts = widget.ttsService ?? TtsService.device();
    _mediaLifecycleRegistry = ref.read(mediaLifecycleRegistryProvider);
    _mediaLifecycleRegistry.register(
      this,
      MediaLifecycleRegistration(stopTextToSpeech: _stopTts),
    );
    _startedAt = DateTime.now();
    final controller = ref.read(appControllerProvider.notifier);
    final appState = ref.read(appControllerProvider);
    final plan = controller.activeSessionPlan;
    _recordProgress = widget.customPlan ? plan.recordProgress : true;
    _backlogRecovery = widget.customPlan && plan.backlogRecovery.enabled;
    _historyFilter = widget.customPlan
        ? plan.historyFilter
        : StudyHistoryFilter.all;
    _subjectIdAtStart = appState.activeSubjectId;
    _courseIdAtStart = appState.activeCourseId;
    final progress = ref.read(appControllerProvider).progress;
    final sourceItems = widget.customPlan
        ? controller
              .previewSessionPlan(controller.activeSessionPlan, DateTime.now())
              .items
        : widget.unitIndex == null
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
      final priority = right.priority.compareTo(left.priority);
      if (priority != 0) return priority;
      return left.id.compareTo(right.id);
    });
    final itemLimit = widget.customPlan
        ? items.length
        : ref.read(appControllerProvider).preferences.sessionItemLimit;
    _queue = items.take(itemLimit).toList(growable: true);
    if (_queue.isNotEmpty) {
      _scheduleQuestionAudio();
      _requestWindowsFocus(_revealFocusNode);
    }
    ref.listenManual<String>(
      appControllerProvider.select((state) => state.activeSubjectId),
      (previous, next) {
        if (next != _subjectIdAtStart) {
          _handleSubjectChange();
        }
      },
    );
  }

  void _handleSubjectChange() {
    if (_subjectChangeHandled) return;
    _subjectChangeHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _stopTts();
      await _saveSession();
      if (mounted) context.go('/learn');
    });
  }

  @override
  void dispose() {
    _mediaLifecycleRegistry.unregister(this);
    unawaited(_stopTts());
    _revealFocusNode.dispose();
    _rememberedFocusNode.dispose();
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
    final preferences = ref.read(appControllerProvider).preferences;
    final voice = ref
        .read(devicePreferencesControllerProvider)
        .preferences
        .voice;
    try {
      await _tts.speak(
        language: _item.learningLanguage,
        text: _item.text,
        rate: preferences.ttsRate,
        preferOfflineVoice: preferences.interaction.preferOfflineVoice,
        repeatCount: preferences.interaction.audioRepeatCount,
        preferredVoiceId: voice.voiceIdByLanguage[_item.learningLanguage.code],
        pitch: voice.pitch,
      );
    } catch (_) {
      // Audio is optional; learning remains usable without a platform voice.
    }
  }

  void _reveal() {
    if (_revealed) return;
    setState(() {
      _revealed = true;
      _lastRatingLabel = null;
    });
    _requestWindowsFocus(_rememberedFocusNode);
    if (ref
        .read(appControllerProvider)
        .preferences
        .interaction
        .autoPlayAnswerAudio) {
      unawaited(_speak());
    }
  }

  void _scheduleQuestionAudio() {
    final preferences = ref.read(appControllerProvider).preferences.interaction;
    if (!preferences.autoPlayQuestionAudio || _queue.isEmpty) return;
    final expectedItemId = _item.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _completed ||
          _queue.isEmpty ||
          _item.id != expectedItemId) {
        return;
      }
      unawaited(_speak());
    });
  }

  void _requestWindowsFocus(FocusNode focusNode) {
    if (defaultTargetPlatform != TargetPlatform.windows) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !focusNode.canRequestFocus) return;
      focusNode.requestFocus();
    });
  }

  void _rate(ReviewRating rating) {
    if (!_revealed) return;
    final item = _item;
    final remembered = rating != ReviewRating.again;
    final ratingLabel = switch (rating) {
      ReviewRating.again => '다시',
      ReviewRating.hard => '어려워요',
      ReviewRating.good => '기억나요',
      ReviewRating.easy => '쉬워요',
    };
    _attemptedItemIds.add(item.id);
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
          recordProgress: _recordProgress,
        );
    if (_recordProgress) _earnedXp += xp;
    if (remembered) {
      _remembered++;
      _finalCorrectItemIds.add(item.id);
    } else {
      _again++;
      _wrongItemIds.add(item.id);
      _finalCorrectItemIds.remove(item.id);
      if (_requeued.add(item.id)) _queue.add(item);
    }

    if (_index + 1 >= _queue.length) {
      unawaited(_saveSession());
      setState(() {
        _completed = true;
        _lastRatingLabel = ratingLabel;
      });
      return;
    }
    setState(() {
      _index++;
      _revealed = false;
      _lastRatingLabel = ratingLabel;
    });
    _requestWindowsFocus(_revealFocusNode);
    _scheduleQuestionAudio();
  }

  String _statusAnnouncement(
    String readingAidsLabel,
    AccessibilityInputProfile accessibilityProfile,
  ) {
    final revealShortcut = accessibilityProfile
        .shortcutFor(StudyShortcutAction.nextItem)
        .displayLabel;
    if (_revealed) {
      final reading = readingAidsLabel.isEmpty
          ? ''
          : ' 읽는 법 $readingAidsLabel.';
      final shortcutLabels = [
        accessibilityProfile
            .shortcutFor(StudyShortcutAction.rateAgain)
            .displayLabel,
        accessibilityProfile
            .shortcutFor(StudyShortcutAction.rateHard)
            .displayLabel,
        accessibilityProfile
            .shortcutFor(StudyShortcutAction.rateGood)
            .displayLabel,
        accessibilityProfile
            .shortcutFor(StudyShortcutAction.rateEasy)
            .displayLabel,
      ];
      final shortcuts = shortcutLabels.join(', ');
      final shortcutDescription =
          const ['1', '2', '3', '4'].every(shortcutLabels.contains) &&
              shortcutLabels.length == 4
          ? '1부터 4'
          : shortcuts;
      return '답 공개. ${_item.text}.$reading '
          '뜻 ${_item.primaryTranslation}. '
          '기억한 정도를 다시, 어려워요, 기억나요, 쉬워요 중에서 골라 주세요. '
          '단축키 $shortcutDescription.';
    }
    final previousRating = _lastRatingLabel == null
        ? ''
        : '평가: $_lastRatingLabel. ';
    final cardPosition = _lastRatingLabel == null ? '카드' : '다음 카드';
    return '$previousRating$cardPosition ${_index + 1}/${_queue.length} 앞면. '
        '${_item.text}. $revealShortcut 키 또는 뜻 보기 버튼으로 뒤집으세요.';
  }

  Future<void> _saveSession() async {
    if (_saved || _remembered + _again == 0) return;
    _saved = true;
    await ref
        .read(appControllerProvider.notifier)
        .finishSession(
          StudySessionSummary(
            sessionId: 'cards-${_startedAt.toUtc().microsecondsSinceEpoch}',
            courseId: _courseIdAtStart,
            startedAt: _startedAt,
            endedAt: DateTime.now(),
            correctCount: _remembered,
            wrongCount: _again,
            earnedXp: _earnedXp,
            itemIds: _attemptedItemIds.toList(growable: false),
            wrongItemIds: Set.unmodifiable(_wrongItemIds),
            finalCorrectItemIds: Set.unmodifiable(_finalCorrectItemIds),
            mode: switch (widget.kind) {
              FlashcardKind.mixed => StudyMode.mixed,
              FlashcardKind.words => StudyMode.words,
              FlashcardKind.sentences => StudyMode.sentences,
            },
            historyFilter: _historyFilter,
            recordProgress: _recordProgress,
            backlogRecovery: _backlogRecovery,
          ),
        );
  }

  void _close() {
    unawaited(_saveSession());
    context.go(_returnRoute);
  }

  String get _returnRoute => widget.customPlan
      ? '/session-builder'
      : widget.unitIndex == null
      ? '/learn'
      : '/path';

  String get _returnLabel => widget.customPlan
      ? '세션 설계로 돌아가기'
      : widget.unitIndex == null
      ? '학습실로 돌아가기'
      : '코스로 돌아가기';

  void _handleCardSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 120) return;
    if (!_revealed) {
      _reveal();
      return;
    }
    _rate(velocity > 0 ? ReviewRating.again : ReviewRating.good);
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) {
      return _EmptyLearningScreen(
        title: '학습할 카드가 없어요',
        description: '자료실에서 이 주제에 맞는 단어나 문장을 추가해 주세요.',
        onClose: _close,
        onAdd: () => context.go('/library/new'),
      );
    }
    if (_completed) {
      return _CardCompletion(
        remembered: _remembered,
        again: _again,
        minutes: max(1, DateTime.now().difference(_startedAt).inMinutes),
        lastRatingLabel: _lastRatingLabel,
        onHub: () => context.go(_returnRoute),
        onQuiz: () => context.go(
          widget.unitIndex == null
              ? '/study?mode=meaning${widget.customPlan ? '&custom=true' : ''}'
              : '/study?mode=meaning&unit=${widget.unitIndex}',
        ),
        returnLabel: _returnLabel,
      );
    }

    final favorite = ref.watch(
      appControllerProvider.select(
        (state) => state.preferences.isFavorite(_item.id),
      ),
    );
    final interaction = ref.watch(
      appControllerProvider.select((state) => state.preferences.interaction),
    );
    final readingAidsLabel = _item.readingAidsLabelFor(
      showKoreanReading: interaction.showKoreanReading,
      showNativeReading: interaction.showNativeReading,
    );
    final accessibilityProfile = ref.watch(accessibilityInputProfileProvider);
    final accessibilityTheme = StudyAccessibilityTheme.of(context);
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
    final revealShortcut = accessibilityProfile
        .shortcutFor(StudyShortcutAction.nextItem)
        .displayLabel;
    final ratingShortcuts = {
      ReviewRating.again: accessibilityProfile
          .shortcutFor(StudyShortcutAction.rateAgain)
          .displayLabel,
      ReviewRating.hard: accessibilityProfile
          .shortcutFor(StudyShortcutAction.rateHard)
          .displayLabel,
      ReviewRating.good: accessibilityProfile
          .shortcutFor(StudyShortcutAction.rateGood)
          .displayLabel,
      ReviewRating.easy: accessibilityProfile
          .shortcutFor(StudyShortcutAction.rateEasy)
          .displayLabel,
    };
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final tapRatesGood =
        isAndroid &&
        accessibilityProfile.androidSelectionGesture ==
            AndroidSelectionGesture.tapAndButtons;
    final swipeRates =
        isAndroid &&
        accessibilityProfile.androidSelectionGesture ==
            AndroidSelectionGesture.swipeAndButtons;
    return CallbackShortcuts(
      bindings: {
        ...accessibilityProfile.bindingsFor({
          StudyShortcutAction.revealAnswer: _reveal,
          StudyShortcutAction.playAudio: () => unawaited(_speak()),
          StudyShortcutAction.rateAgain: () => _rate(ReviewRating.again),
          StudyShortcutAction.rateHard: () => _rate(ReviewRating.hard),
          StudyShortcutAction.rateGood: () => _rate(ReviewRating.good),
          StudyShortcutAction.rateEasy: () => _rate(ReviewRating.easy),
          StudyShortcutAction.nextItem: () {
            if (!_revealed) {
              _reveal();
            } else {
              _rate(ReviewRating.good);
            }
          },
        }),
        const SingleActivator(LogicalKeyboardKey.escape): _close,
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
            title: Semantics(
              label: '암기 카드 진행률',
              value: '${_index + 1} / ${_queue.length}',
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: (_index + 1) / _queue.length,
                    minHeight: 9,
                  ),
                ),
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
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _LearningPill(
                                    icon: Icons.style_rounded,
                                    label: _revealed
                                        ? '뜻과 읽는 법 확인'
                                        : '먼저 소리 내어 읽기',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
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
                            hint: swipeRates
                                ? '좌우로 밀어 뜻을 보거나 바로 평가할 수 있어요. 아래 버튼도 사용할 수 있어요.'
                                : tapRatesGood
                                ? '뜻을 본 뒤 카드를 한 번 더 누르면 “기억나요”로 평가해요. 아래 버튼도 사용할 수 있어요.'
                                : null,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragEnd: swipeRates
                                  ? _handleCardSwipe
                                  : null,
                              child: Card(
                                color: _revealed
                                    ? colors.secondaryContainer
                                    : colors.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: accessibilityTheme.highContrast
                                      ? BorderSide(
                                          color: colors.onSurface,
                                          width: 2,
                                        )
                                      : BorderSide.none,
                                ),
                                child: InkWell(
                                  key: const Key('flashcard-surface'),
                                  onTap: !_revealed
                                      ? _reveal
                                      : tapRatesGood
                                      ? () => _rate(ReviewRating.good)
                                      : null,
                                  borderRadius: BorderRadius.circular(18),
                                  child: AnimatedSize(
                                    key: const Key('compact-flashcard-content'),
                                    duration:
                                        MediaQuery.disableAnimationsOf(
                                              context,
                                            ) ||
                                            accessibilityTheme.reduceMotion
                                        ? Duration.zero
                                        : const Duration(milliseconds: 180),
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal:
                                            (constraints.maxWidth < 600
                                                ? 20
                                                : 24) *
                                            accessibilityTheme.cardScaleFactor,
                                        vertical:
                                            (constraints.maxWidth < 600
                                                ? 22
                                                : 28) *
                                            accessibilityTheme.cardScaleFactor,
                                      ),
                                      child: AnimatedSwitcher(
                                        duration:
                                            MediaQuery.disableAnimationsOf(
                                                  context,
                                                ) ||
                                                accessibilityTheme.reduceMotion
                                            ? Duration.zero
                                            : const Duration(milliseconds: 180),
                                        child: _revealed
                                            ? _FlashcardBack(
                                                key: const ValueKey('back'),
                                                item: _item,
                                                readingAidsLabel:
                                                    readingAidsLabel,
                                                onSpeak: _speak,
                                                cardScaleFactor:
                                                    accessibilityTheme
                                                        .cardScaleFactor,
                                              )
                                            : _FlashcardFront(
                                                key: const ValueKey('front'),
                                                item: _item,
                                                onSpeak: _speak,
                                                cardScaleFactor:
                                                    accessibilityTheme
                                                        .cardScaleFactor,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Semantics(
                            key: const Key('flashcard-status-live-region'),
                            container: true,
                            liveRegion: true,
                            label: _statusAnnouncement(
                              readingAidsLabel,
                              accessibilityProfile,
                            ),
                            child: ExcludeSemantics(
                              child: Text(
                                _revealed
                                    ? '얼마나 잘 떠올렸는지 골라 주세요. 어려웠던 카드는 끝에 한 번 더 나와요.'
                                    : '천천히 읽어 본 뒤 카드를 뒤집어 뜻을 확인하세요.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
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
                            final stackButtons =
                                accessibilityProfile.largeRatingControls ||
                                MediaQuery.textScalerOf(context).scale(1) > 1.3;
                            final buttonWidth = stackButtons
                                ? constraints.maxWidth
                                : constraints.maxWidth < 560
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
                                  shortcut:
                                      ratingShortcuts[ReviewRating.again]!,
                                  interval: intervalLabels[ReviewRating.again]!,
                                  minimumHeight: accessibilityTheme
                                      .minimumRatingControlHeight,
                                  onPressed: () => _rate(ReviewRating.again),
                                ),
                                _RatingButton(
                                  key: const Key('flashcard-hard'),
                                  width: buttonWidth,
                                  icon: Icons.psychology_alt_rounded,
                                  label: '어려워요',
                                  shortcut: ratingShortcuts[ReviewRating.hard]!,
                                  interval: intervalLabels[ReviewRating.hard]!,
                                  minimumHeight: accessibilityTheme
                                      .minimumRatingControlHeight,
                                  onPressed: () => _rate(ReviewRating.hard),
                                ),
                                _RatingButton(
                                  key: const Key('flashcard-remembered'),
                                  width: buttonWidth,
                                  icon: Icons.check_rounded,
                                  label: '기억나요',
                                  shortcut: ratingShortcuts[ReviewRating.good]!,
                                  interval: intervalLabels[ReviewRating.good]!,
                                  minimumHeight: accessibilityTheme
                                      .minimumRatingControlHeight,
                                  emphasized: true,
                                  focusNode: _rememberedFocusNode,
                                  onPressed: () => _rate(ReviewRating.good),
                                ),
                                _RatingButton(
                                  key: const Key('flashcard-easy'),
                                  width: buttonWidth,
                                  icon: Icons.bolt_rounded,
                                  label: '쉬워요',
                                  shortcut: ratingShortcuts[ReviewRating.easy]!,
                                  interval: intervalLabels[ReviewRating.easy]!,
                                  minimumHeight: accessibilityTheme
                                      .minimumRatingControlHeight,
                                  onPressed: () => _rate(ReviewRating.easy),
                                ),
                              ],
                            );
                          },
                        )
                      : Semantics(
                          button: true,
                          enabled: true,
                          onTap: _reveal,
                          label:
                              '뜻 보기. 카드를 뒤집은 뒤 평가 버튼으로 이동합니다. 단축키 $revealShortcut.',
                          child: ExcludeSemantics(
                            child: FilledButton.icon(
                              key: const Key('reveal-flashcard'),
                              focusNode: _revealFocusNode,
                              onPressed: _reveal,
                              style: FilledButton.styleFrom(
                                minimumSize: Size.fromHeight(
                                  max(
                                    50.0,
                                    accessibilityTheme
                                        .minimumRatingControlHeight,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.visibility_rounded),
                              label: const Text('뜻 보기'),
                            ),
                          ),
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
    required this.minimumHeight,
    required this.onPressed,
    this.emphasized = false,
    this.focusNode,
    super.key,
  });

  final double width;
  final IconData icon;
  final String label;
  final String shortcut;
  final String interval;
  final double minimumHeight;
  final VoidCallback onPressed;
  final bool emphasized;
  final FocusNode? focusNode;

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
    return Semantics(
      button: true,
      enabled: true,
      onTap: onPressed,
      label: '$label 선택. 단축키 $shortcut. 다음 복습 $interval 후.',
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          height: max(58.0, minimumHeight),
          child: emphasized
              ? FilledButton(
                  focusNode: focusNode,
                  onPressed: onPressed,
                  child: content,
                )
              : OutlinedButton(
                  focusNode: focusNode,
                  onPressed: onPressed,
                  child: content,
                ),
        ),
      ),
    );
  }
}

class _FlashcardFront extends StatelessWidget {
  const _FlashcardFront({
    required this.item,
    required this.onSpeak,
    required this.cardScaleFactor,
    super.key,
  });

  final LearningItem item;
  final VoidCallback onSpeak;
  final double cardScaleFactor;

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
        const SizedBox(height: 12),
        Text(
          item.text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontSize:
                (Theme.of(context).textTheme.displaySmall?.fontSize ?? 36) *
                cardScaleFactor,
          ),
        ),
        const SizedBox(height: 16),
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
  const _FlashcardBack({
    required this.item,
    required this.readingAidsLabel,
    required this.onSpeak,
    required this.cardScaleFactor,
    super.key,
  });

  final LearningItem item;
  final String readingAidsLabel;
  final VoidCallback onSpeak;
  final double cardScaleFactor;

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
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize:
                      (Theme.of(context).textTheme.headlineMedium?.fontSize ??
                          28) *
                      cardScaleFactor,
                ),
              ),
            ),
            IconButton(
              onPressed: onSpeak,
              tooltip: '발음 듣기',
              icon: const Icon(Icons.volume_up_rounded),
            ),
          ],
        ),
        if (readingAidsLabel.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            readingAidsLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colors.primary,
              height: 1.4,
            ),
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
            fontSize:
                (Theme.of(context).textTheme.headlineSmall?.fontSize ?? 24) *
                cardScaleFactor,
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
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
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
    required this.lastRatingLabel,
    required this.onHub,
    required this.onQuiz,
    required this.returnLabel,
  });

  final int remembered;
  final int again;
  final int minutes;
  final String? lastRatingLabel;
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
                  Semantics(
                    key: const Key('flashcard-status-live-region'),
                    container: true,
                    liveRegion: true,
                    label:
                        '${lastRatingLabel == null ? '' : '평가: $lastRatingLabel. '}'
                        '카드 학습 완료. 기억한 카드 $remembered개, 다시 볼 카드 $again개.',
                    child: ExcludeSemantics(
                      child: Column(
                        children: [
                          Text(
                            '카드 학습을 마쳤어요',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$minutes분 · 기억한 카드 $remembered개 · 다시 볼 카드 $again개',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: onQuiz,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.touch_app_rounded),
                    label: const Text('뜻 고르기 시작'),
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
    required this.onAdd,
  });

  final String title;
  final String description;
  final VoidCallback onClose;
  final VoidCallback onAdd;

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
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('empty-flashcard-add-content'),
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('자료 추가'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
