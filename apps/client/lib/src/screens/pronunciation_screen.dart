import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/accessibility_input_profile.dart';
import '../domain/learning_item.dart';
import '../domain/pronunciation_ladder.dart';
import '../domain/pronunciation_score.dart';
import '../domain/study_history.dart';
import '../domain/study_preferences.dart';
import '../services/temporary_voice_recording_service.dart';
import '../services/tts_service.dart';
import '../state/app_state.dart';
import '../state/local_storage_state.dart';
import '../theme/study_accessibility_theme.dart';

class PronunciationScreen extends ConsumerStatefulWidget {
  const PronunciationScreen({
    this.unitIndex,
    this.customPlan = false,
    this.ttsService,
    this.voiceRecordingService,
    super.key,
  });

  final int? unitIndex;
  final bool customPlan;
  final TtsService? ttsService;
  final TemporaryVoiceRecordingService? voiceRecordingService;

  @override
  ConsumerState<PronunciationScreen> createState() =>
      _PronunciationScreenState();
}

class _PronunciationScreenState extends ConsumerState<PronunciationScreen> {
  final _speech = SpeechToText();
  late final TtsService _tts;
  TemporaryVoiceRecordingService? _voiceRecording;
  final _scorer = const PronunciationScorer();
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
  var _passed = 0;
  var _needsPractice = 0;
  var _recognized = '';
  var _soundLevel = 0.0;
  var _listening = false;
  var _initialized = false;
  var _speechAvailable = true;
  var _attemptRecorded = false;
  var _completed = false;
  var _saved = false;
  var _subjectChangeHandled = false;
  String? _errorMessage;
  PronunciationAssessment? _assessment;
  var _shadowingStage = ShadowingStage.listen;
  var _voiceRecordingActive = false;
  var _voiceRecordingAvailable = false;
  var _voicePlaybackActive = false;
  String? _voiceRecordingMessage;

  LearningItem get _item => _queue[_index];

  TemporaryVoiceRecordingService get _voiceRecordingService =>
      _voiceRecording ??= DeviceTemporaryVoiceRecordingService();

  @override
  void initState() {
    super.initState();
    _tts = widget.ttsService ?? TtsService.device();
    _voiceRecording = widget.voiceRecordingService;
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
    final sourceItems = widget.customPlan
        ? controller
              .previewSessionPlan(controller.activeSessionPlan, _startedAt)
              .items
        : widget.unitIndex == null
        ? controller.selectedItems
        : controller.itemsForUnit(widget.unitIndex!);
    final items = sourceItems
        .where(
          (item) => item.capabilities.contains(ExerciseCapability.listening),
        )
        .toList();
    items.sort((left, right) {
      if (left.kind != right.kind) {
        return left.kind == LearningItemKind.sentence ? -1 : 1;
      }
      return right.priority.compareTo(left.priority);
    });
    _queue = items.take(12).toList(growable: false);
    if (_queue.isNotEmpty) _scheduleQuestionAudio();
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
      await _speech.cancel();
      await _stopTts();
      await _voiceRecording?.clear();
      await _saveSession();
      if (mounted) context.go('/learn');
    });
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
    unawaited(_stopTts());
    final voiceRecording = _voiceRecording;
    if (voiceRecording != null) {
      unawaited(voiceRecording.dispose());
    }
    super.dispose();
  }

  Future<void> _stopTts() async {
    try {
      await _tts.stop();
    } catch (_) {
      // The platform channel is absent in widget tests and some headless runs.
    }
  }

  Future<void> _speak({bool slow = false}) async {
    final preferences = ref.read(appControllerProvider).preferences;
    try {
      await _tts.speak(
        language: _item.learningLanguage,
        text: _item.text,
        rate: slow
            ? (preferences.ttsRate * 0.75).clamp(0.2, 0.75).toDouble()
            : preferences.ttsRate,
        preferOfflineVoice: preferences.interaction.preferOfflineVoice,
        repeatCount: preferences.interaction.audioRepeatCount,
      );
    } catch (_) {
      // Pronunciation scoring still works when the platform has no TTS voice.
    }
  }

  Future<void> _selectShadowingStage(ShadowingStage stage) async {
    if (_voiceRecordingActive && stage != ShadowingStage.localRecording) {
      await _stopVoiceRecording();
    }
    if (!mounted) return;
    setState(() {
      _shadowingStage = stage;
      _voiceRecordingMessage = null;
    });
    switch (stage) {
      case ShadowingStage.listen:
        await _speak();
      case ShadowingStage.slowListen:
        await _speak(slow: true);
      case ShadowingStage.repeat:
      case ShadowingStage.localRecording:
      case ShadowingStage.hint:
      case ShadowingStage.context:
        return;
    }
  }

  Future<void> _toggleVoiceRecording() async {
    await _speech.cancel();
    await _stopTts();
    if (_voiceRecordingActive) {
      await _stopVoiceRecording();
      return;
    }
    try {
      final started = await _voiceRecordingService.start();
      if (!mounted) return;
      setState(() {
        _voiceRecordingActive = started;
        _voiceRecordingAvailable = false;
        _voiceRecordingMessage = started
            ? '녹음 중입니다. 목표 표현을 말한 뒤 정지하세요.'
            : '마이크 권한이 없어 임시 녹음을 시작할 수 없어요.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _voiceRecordingActive = false;
        _voiceRecordingMessage = '임시 녹음을 시작하지 못했어요. 마이크 권한과 입력 장치를 확인해 주세요.';
      });
    }
  }

  Future<void> _stopVoiceRecording() async {
    try {
      final saved = await _voiceRecordingService.stop();
      if (!mounted) return;
      setState(() {
        _voiceRecordingActive = false;
        _voiceRecordingAvailable = saved;
        _voiceRecordingMessage = saved
            ? '이 기기에만 임시 저장했습니다. 내 음성을 바로 들어 보세요.'
            : '녹음된 음성이 없어요. 다시 녹음해 주세요.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _voiceRecordingActive = false;
        _voiceRecordingAvailable = false;
        _voiceRecordingMessage = '녹음을 마무리하지 못했어요. 다시 시도해 주세요.';
      });
    }
  }

  Future<void> _playVoiceRecording() async {
    if (!_voiceRecordingAvailable || _voicePlaybackActive) return;
    setState(() => _voicePlaybackActive = true);
    try {
      await _voiceRecordingService.play();
    } catch (_) {
      if (mounted) {
        setState(() => _voiceRecordingMessage = '내 음성 파일을 재생하지 못했어요.');
      }
    } finally {
      if (mounted) setState(() => _voicePlaybackActive = false);
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

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) _finalizeRecognition();
      return;
    }
    if (_voiceRecordingActive) await _stopVoiceRecording();
    await _stopTts();
    if (defaultTargetPlatform == TargetPlatform.windows &&
        _item.learningLanguage.code != 'en') {
      setState(() {
        _speechAvailable = false;
        _errorMessage =
            'Windows 음성 인식은 현재 영어 코스에서만 안정적으로 지원돼요. 목표 발음을 듣고 따라 읽거나, Android에서 마이크 채점을 사용해 주세요.';
      });
      return;
    }
    if (!_initialized) {
      try {
        final available = await _speech.initialize(
          onStatus: _onSpeechStatus,
          onError: _onSpeechError,
          finalTimeout: const Duration(seconds: 2),
        );
        if (!mounted) return;
        _initialized = available;
        _speechAvailable = available;
        if (!available) {
          setState(() {
            _errorMessage = '이 장치에서 음성 인식을 시작할 수 없어요. 마이크 권한과 음성 언어팩을 확인해 주세요.';
          });
          return;
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _speechAvailable = false;
          _errorMessage = '음성 인식 서비스를 열지 못했어요. 잠시 후 다시 시도하거나 따라 읽기만 진행해 주세요.';
        });
        return;
      }
    }

    setState(() {
      _recognized = '';
      _assessment = null;
      _attemptRecorded = false;
      _errorMessage = null;
      _soundLevel = 0;
      _listening = true;
    });
    try {
      await _speech.listen(
        onResult: _onSpeechResult,
        onSoundLevelChange: (level) {
          if (!mounted) return;
          setState(() => _soundLevel = level);
        },
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
          listenMode: _item.kind == LearningItemKind.sentence
              ? ListenMode.dictation
              : ListenMode.confirmation,
          pauseFor: const Duration(seconds: 3),
          listenFor: const Duration(seconds: 15),
          localeId: _item.learningLanguage.ttsLocale,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _errorMessage = '마이크를 시작하지 못했어요. 운영체제의 마이크 권한을 확인해 주세요.';
      });
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() => _recognized = result.recognizedWords);
    if (result.finalResult) _finalizeRecognition();
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;
    if (status == SpeechToText.doneStatus ||
        status == SpeechToText.notListeningStatus) {
      _finalizeRecognition();
    } else if (status == SpeechToText.listeningStatus) {
      setState(() => _listening = true);
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _listening = false;
      _errorMessage = switch (error.errorMsg) {
        'error_permission' =>
          '마이크 권한이 필요해요. 시스템 설정에서 Sprache의 마이크 접근을 허용해 주세요.',
        'error_language_not_supported' || 'error_language_unavailable' =>
          '${_item.learningLanguage.koreanName} 음성 언어팩을 찾지 못했어요. 운영체제 언어 설정에서 설치해 주세요.',
        'error_no_match' ||
        'error_speech_timeout' => '목소리를 인식하지 못했어요. 마이크 가까이에서 조금 더 또렷하게 말해 보세요.',
        _ => '음성 인식 중 문제가 생겼어요. 다시 한 번 시도해 주세요.',
      };
    });
  }

  void _finalizeRecognition() {
    if (!mounted) return;
    final transcript = _recognized.trim();
    setState(() => _listening = false);
    if (transcript.isEmpty || _assessment != null) return;
    final assessment = _scorer.assess(
      expected: _item.text,
      recognized: transcript,
      language: _item.learningLanguage,
    );
    setState(() => _assessment = assessment);
    _recordAttempt(assessment.passed);
    if (ref
        .read(appControllerProvider)
        .preferences
        .interaction
        .autoPlayAnswerAudio) {
      unawaited(_speak());
    }
  }

  void _recordAttempt(bool passed) {
    if (_attemptRecorded) return;
    _attemptRecorded = true;
    _attemptedItemIds.add(_item.id);
    ref
        .read(appControllerProvider.notifier)
        .recordAnswer(
          item: _item,
          correct: passed,
          studiedAt: DateTime.now(),
          exerciseType: 'pronunciation',
          recordProgress: _recordProgress,
        );
    if (passed) {
      _passed++;
      _finalCorrectItemIds.add(_item.id);
    } else {
      _needsPractice++;
      _wrongItemIds.add(_item.id);
      _finalCorrectItemIds.remove(_item.id);
    }
  }

  void _submitSelfAssessment(bool passed) {
    _recordAttempt(passed);
    _next();
  }

  void _retry() {
    setState(() {
      _recognized = '';
      _assessment = null;
      _attemptRecorded = false;
      _errorMessage = null;
      _soundLevel = 0;
      _shadowingStage = ShadowingStage.repeat;
    });
    _scheduleQuestionAudio();
  }

  void _next() {
    final voiceRecording = _voiceRecording;
    if (voiceRecording != null) {
      unawaited(voiceRecording.clear());
    }
    if (_index + 1 >= _queue.length) {
      unawaited(_saveSession());
      setState(() => _completed = true);
      return;
    }
    setState(() {
      _index++;
      _recognized = '';
      _assessment = null;
      _attemptRecorded = false;
      _errorMessage = null;
      _soundLevel = 0;
      _listening = false;
      _speechAvailable = true;
      _shadowingStage = ShadowingStage.listen;
      _voiceRecordingActive = false;
      _voiceRecordingAvailable = false;
      _voicePlaybackActive = false;
      _voiceRecordingMessage = null;
    });
    _scheduleQuestionAudio();
  }

  Future<void> _saveSession() async {
    if (_saved || _passed + _needsPractice == 0) return;
    _saved = true;
    await ref
        .read(appControllerProvider.notifier)
        .finishSession(
          StudySessionSummary(
            sessionId:
                'pronunciation-${_startedAt.toUtc().microsecondsSinceEpoch}',
            courseId: _courseIdAtStart,
            startedAt: _startedAt,
            endedAt: DateTime.now(),
            correctCount: _passed,
            wrongCount: _needsPractice,
            earnedXp: _recordProgress ? _passed * 10 + _needsPractice * 5 : 0,
            itemIds: _attemptedItemIds.toList(growable: false),
            wrongItemIds: Set.unmodifiable(_wrongItemIds),
            finalCorrectItemIds: Set.unmodifiable(_finalCorrectItemIds),
            mode: StudyMode.pronunciation,
            historyFilter: _historyFilter,
            recordProgress: _recordProgress,
            backlogRecovery: _backlogRecovery,
          ),
        );
  }

  void _close() {
    unawaited(_speech.cancel());
    final voiceRecording = _voiceRecording;
    if (voiceRecording != null) {
      unawaited(voiceRecording.clear());
    }
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
      : '코스 여정으로';

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) {
      return _EmptyPronunciationScreen(
        onClose: _close,
        onAdd: () => context.go('/library/new'),
      );
    }
    if (_completed) {
      return _PronunciationCompletion(
        passed: _passed,
        needsPractice: _needsPractice,
        minutes: max(1, DateTime.now().difference(_startedAt).inMinutes),
        onHub: () => context.go(_returnRoute),
        returnLabel: _returnLabel,
      );
    }

    final colors = Theme.of(context).colorScheme;
    final accessibilityProfile = ref.watch(accessibilityInputProfileProvider);
    final accessibilityTheme = StudyAccessibilityTheme.of(context);
    final interaction = ref.watch(
      appControllerProvider.select((state) => state.preferences.interaction),
    );
    final readingAidsLabel = _item.readingAidsLabelFor(
      showKoreanReading: interaction.showKoreanReading,
      showNativeReading: interaction.showNativeReading,
    );
    return CallbackShortcuts(
      bindings: {
        ...accessibilityProfile.bindingsFor({
          StudyShortcutAction.playAudio: () => unawaited(_speak()),
          StudyShortcutAction.revealAnswer: () =>
              unawaited(_selectShadowingStage(ShadowingStage.localRecording)),
          StudyShortcutAction.rateAgain: () {
            if (!_speechAvailable && !_attemptRecorded) {
              _submitSelfAssessment(false);
            } else if (_assessment != null) {
              _retry();
            }
          },
          StudyShortcutAction.rateHard: () {
            if (!_speechAvailable && !_attemptRecorded) {
              _submitSelfAssessment(true);
            }
          },
          StudyShortcutAction.nextItem: () {
            if (_assessment != null) _next();
          },
        }),
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: _close,
              tooltip: '발음 연습 종료',
              icon: const Icon(Icons.close_rounded),
            ),
            titleSpacing: 4,
            title: Semantics(
              label: '발음 연습 진행률',
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
                    14,
                    constraints.maxWidth < 600 ? 16 : 24,
                    28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              _PronunciationPill(listening: _listening),
                              const Spacer(),
                              Text(
                                widget.unitIndex == null
                                    ? '${_item.learningLanguage.symbol} · ${_item.kind == LearningItemKind.word ? '단어' : '문장'}'
                                    : '${_item.learningLanguage.symbol} · Unit ${widget.unitIndex! + 1}',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Card(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal:
                                    22 * accessibilityTheme.cardScaleFactor,
                                vertical:
                                    28 * accessibilityTheme.cardScaleFactor,
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _item.text,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(
                                          fontSize:
                                              (Theme.of(context)
                                                      .textTheme
                                                      .displaySmall
                                                      ?.fontSize ??
                                                  36) *
                                              accessibilityTheme
                                                  .cardScaleFactor,
                                        ),
                                  ),
                                  if (readingAidsLabel.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      readingAidsLabel,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: colors.primary,
                                            height: 1.4,
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: 9),
                                  Text(
                                    _item.primaryTranslation,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 18),
                                  OutlinedButton.icon(
                                    onPressed: () => unawaited(_speak()),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: Size.fromHeight(
                                        accessibilityTheme
                                            .minimumRatingControlHeight,
                                      ),
                                    ),
                                    icon: const Icon(Icons.volume_up_rounded),
                                    label: const Text('목표 발음 듣기'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _RecognitionPanel(
                            listening: _listening,
                            transcript: _recognized,
                            soundLevel: _soundLevel,
                            assessment: _assessment,
                            errorMessage: _errorMessage,
                          ),
                          const SizedBox(height: 12),
                          const _PronunciationScoreDisclosure(),
                          const SizedBox(height: 14),
                          _ShadowingLadder(
                            item: _item,
                            stages: PronunciationLadder.stagesFor(_item),
                            selectedStage: _shadowingStage,
                            readingAidsLabel: readingAidsLabel,
                            recording: _voiceRecordingActive,
                            recordingAvailable: _voiceRecordingAvailable,
                            playbackActive: _voicePlaybackActive,
                            recordingMessage: _voiceRecordingMessage,
                            selectionGesture:
                                accessibilityProfile.androidSelectionGesture,
                            minimumControlHeight:
                                accessibilityTheme.minimumRatingControlHeight,
                            onStageSelected: (stage) =>
                                unawaited(_selectShadowingStage(stage)),
                            onListen: () => unawaited(_speak()),
                            onSlowListen: () => unawaited(_speak(slow: true)),
                            onToggleRecording: () =>
                                unawaited(_toggleVoiceRecording()),
                            onPlayRecording: () =>
                                unawaited(_playVoiceRecording()),
                            onOpenSpeechCheck: () =>
                                unawaited(_toggleListening()),
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
                  child: _PronunciationActions(
                    listening: _listening,
                    speechAvailable: _speechAvailable,
                    hasAssessment: _assessment != null,
                    onMic: _toggleListening,
                    onRetry: _retry,
                    onNext: _next,
                    onSelfNeedsPractice: () => _submitSelfAssessment(false),
                    onSelfPassed: () => _submitSelfAssessment(true),
                    minimumControlHeight:
                        accessibilityTheme.minimumRatingControlHeight,
                    needsPracticeShortcut: accessibilityProfile
                        .shortcutFor(StudyShortcutAction.rateAgain)
                        .displayLabel,
                    passedShortcut: accessibilityProfile
                        .shortcutFor(StudyShortcutAction.rateHard)
                        .displayLabel,
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

class _ShadowingLadder extends StatelessWidget {
  const _ShadowingLadder({
    required this.item,
    required this.stages,
    required this.selectedStage,
    required this.readingAidsLabel,
    required this.recording,
    required this.recordingAvailable,
    required this.playbackActive,
    required this.recordingMessage,
    required this.selectionGesture,
    required this.minimumControlHeight,
    required this.onStageSelected,
    required this.onListen,
    required this.onSlowListen,
    required this.onToggleRecording,
    required this.onPlayRecording,
    required this.onOpenSpeechCheck,
  });

  final LearningItem item;
  final List<ShadowingStage> stages;
  final ShadowingStage selectedStage;
  final String readingAidsLabel;
  final bool recording;
  final bool recordingAvailable;
  final bool playbackActive;
  final String? recordingMessage;
  final AndroidSelectionGesture selectionGesture;
  final double minimumControlHeight;
  final ValueChanged<ShadowingStage> onStageSelected;
  final VoidCallback onListen;
  final VoidCallback onSlowListen;
  final VoidCallback onToggleRecording;
  final VoidCallback onPlayRecording;
  final VoidCallback onOpenSpeechCheck;

  int get _selectedIndex => stages.indexOf(selectedStage);

  void _selectRelative(int delta) {
    final next = (_selectedIndex + delta).clamp(0, stages.length - 1).toInt();
    if (next != _selectedIndex) onStageSelected(stages[next]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final tapAdvances =
        isAndroid && selectionGesture == AndroidSelectionGesture.tapAndButtons;
    final swipeChanges =
        isAndroid &&
        selectionGesture == AndroidSelectionGesture.swipeAndButtons;

    return Semantics(
      container: true,
      label:
          '발음 사다리 ${_selectedIndex + 1}단계, ${selectedStage.label}. '
          '${selectedStage.instruction}',
      hint: tapAdvances
          ? '빈 공간을 두 번 눌러 다음 단계로 이동할 수 있습니다. 화면의 단계 버튼도 항상 사용할 수 있습니다.'
          : swipeChanges
          ? '좌우로 밀어 단계를 이동할 수 있습니다. 화면의 단계 버튼도 항상 사용할 수 있습니다.'
          : '화면의 단계 버튼으로 이동합니다.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: tapAdvances ? () => _selectRelative(1) : null,
        onHorizontalDragEnd: swipeChanges
            ? (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 120) return;
                _selectRelative(velocity < 0 ? 1 : -1);
              }
            : null,
        child: Card(
          key: const Key('pronunciation-shadowing-ladder'),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.stairs_rounded, color: colors.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '발음 사다리',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(
                      '${_selectedIndex + 1}/${stages.length}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var index = 0; index < stages.length; index++) ...[
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: ChoiceChip(
                            key: Key(
                              'pronunciation-stage-${stages[index].name}',
                            ),
                            selected: stages[index] == selectedStage,
                            onSelected: (_) => onStageSelected(stages[index]),
                            label: Text('${index + 1}. ${stages[index].label}'),
                          ),
                        ),
                        if (index + 1 < stages.length) const SizedBox(width: 7),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        selectedStage.instruction,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _stageBody(context),
                    ],
                  ),
                ),
                if (_selectedIndex + 1 < stages.length) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const Key('pronunciation-next-ladder-stage'),
                      onPressed: () => _selectRelative(1),
                      style: TextButton.styleFrom(
                        minimumSize: Size(
                          0,
                          minimumControlHeight.clamp(44, 72).toDouble(),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('다음 단계'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stageBody(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final buttonHeight = minimumControlHeight.clamp(44, 72).toDouble();
    final outlinedStyle = OutlinedButton.styleFrom(
      minimumSize: Size(0, buttonHeight),
    );
    final filledStyle = FilledButton.styleFrom(
      minimumSize: Size(0, buttonHeight),
    );

    return switch (selectedStage) {
      ShadowingStage.listen => OutlinedButton.icon(
        key: const Key('pronunciation-ladder-listen'),
        onPressed: onListen,
        style: outlinedStyle,
        icon: const Icon(Icons.volume_up_rounded),
        label: const Text('보통 속도로 듣기'),
      ),
      ShadowingStage.slowListen => OutlinedButton.icon(
        key: const Key('pronunciation-ladder-slow-listen'),
        onPressed: onSlowListen,
        style: outlinedStyle,
        icon: const Icon(Icons.slow_motion_video_rounded),
        label: const Text('0.75배속으로 듣기'),
      ),
      ShadowingStage.repeat => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '“${item.text}”',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('pronunciation-ladder-repeat-audio'),
            onPressed: onListen,
            style: outlinedStyle,
            icon: const Icon(Icons.hearing_rounded),
            label: const Text('한 번 더 듣고 따라 읽기'),
          ),
        ],
      ),
      ShadowingStage.localRecording => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('pronunciation-local-record'),
                onPressed: onToggleRecording,
                style: filledStyle.copyWith(
                  backgroundColor: recording
                      ? WidgetStatePropertyAll(colors.error)
                      : null,
                ),
                icon: Icon(
                  recording ? Icons.stop_rounded : Icons.fiber_manual_record,
                ),
                label: Text(recording ? '녹음 정지' : '내 음성 녹음'),
              ),
              OutlinedButton.icon(
                key: const Key('pronunciation-local-playback'),
                onPressed: recordingAvailable && !playbackActive
                    ? onPlayRecording
                    : null,
                style: outlinedStyle,
                icon: Icon(
                  playbackActive
                      ? Icons.graphic_eq_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(playbackActive ? '재생 중…' : '내 음성 듣기'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            recordingMessage ??
                '음성은 현재 기기에만 임시 저장되며, 다음 표현으로 이동하거나 화면을 닫으면 바로 삭제됩니다.',
            key: const Key('pronunciation-local-recording-status'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: recording ? colors.error : colors.onSurfaceVariant,
              fontWeight: recording ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
      ShadowingStage.hint => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (readingAidsLabel.isNotEmpty)
            Text(
              readingAidsLabel,
              key: const Key('pronunciation-ladder-reading-hint'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (readingAidsLabel.isNotEmpty) const SizedBox(height: 6),
          Text(
            item.primaryTranslation,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const Key('pronunciation-ladder-hint-speech'),
            onPressed: onOpenSpeechCheck,
            style: filledStyle,
            icon: const Icon(Icons.mic_rounded),
            label: const Text('힌트를 보고 말하기'),
          ),
        ],
      ),
      ShadowingStage.context => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PronunciationLadder.contextPrompt(item),
            key: const Key('pronunciation-ladder-context-prompt'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const Key('pronunciation-ladder-context-speech'),
            onPressed: onOpenSpeechCheck,
            style: filledStyle,
            icon: const Icon(Icons.record_voice_over_rounded),
            label: const Text('상황 속에서 말하기'),
          ),
        ],
      ),
    };
  }
}

class _EmptyPronunciationScreen extends StatelessWidget {
  const _EmptyPronunciationScreen({required this.onClose, required this.onAdd});

  final VoidCallback onClose;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: onClose,
          tooltip: '발음 연습 종료',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic_none_rounded, size: 56),
              const SizedBox(height: 14),
              Text(
                '발음 연습에 사용할 표현이 없어요',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text(
                '듣기를 지원하는 단어나 문장을 자료실에 추가해 주세요.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('empty-pronunciation-add-content'),
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

class _PronunciationPill extends StatelessWidget {
  const _PronunciationPill({required this.listening});

  final bool listening;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = listening ? colors.error : colors.primary;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            listening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 7),
          Text(
            listening ? '듣고 있어요' : '듣고 따라 말하기',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PronunciationScoreDisclosure extends StatelessWidget {
  const _PronunciationScoreDisclosure();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: const Key('pronunciation-score-disclosure'),
          dense: true,
          visualDensity: VisualDensity.compact,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: colors.onSurfaceVariant,
          ),
          title: const Text(
            '점수는 어떻게 계산하나요?',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '기기 음성 인식 결과와 목표 문장의 글자 일치도를 비교합니다. '
                '억양이나 개별 음소를 정밀 분석하는 점수는 아닙니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecognitionPanel extends StatelessWidget {
  const _RecognitionPanel({
    required this.listening,
    required this.transcript,
    required this.soundLevel,
    required this.assessment,
    required this.errorMessage,
  });

  final bool listening;
  final String transcript;
  final double soundLevel;
  final PronunciationAssessment? assessment;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final score = assessment?.score;
    final isEmpty =
        !listening &&
        transcript.isEmpty &&
        assessment == null &&
        errorMessage == null;
    final statusLabel = errorMessage != null
        ? '발음 인식 오류. $errorMessage'
        : assessment != null
        ? '발음 인식 결과. 인식 내용 ${transcript.trim()}. '
              '$score점. ${assessment!.feedback}'
        : listening
        ? transcript.trim().isEmpty
              ? '발음 인식 중. 말을 시작해 주세요.'
              : '발음 인식 중. 현재 인식 내용 ${transcript.trim()}.'
        : '발음 인식 대기. 마이크 버튼을 누르면 인식된 문장이 표시됩니다.';
    return Semantics(
      key: const Key('pronunciation-status-live-region'),
      container: true,
      liveRegion: assessment != null || errorMessage != null,
      label: statusLabel,
      child: ExcludeSemantics(
        child: Container(
          key: const Key('pronunciation-recognition-panel'),
          constraints: BoxConstraints(minHeight: isEmpty ? 116 : 160),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: assessment == null
                  ? colors.outlineVariant
                  : assessment!.passed
                  ? const Color(0xFF238B57)
                  : colors.error,
              width: assessment == null ? 1 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '내가 말한 내용',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (score != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (assessment!.passed
                                    ? const Color(0xFF238B57)
                                    : colors.error)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$score점',
                        style: TextStyle(
                          color: assessment!.passed
                              ? const Color(0xFF238B57)
                              : colors.error,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (listening) ...[
                LinearProgressIndicator(
                  value: ((soundLevel + 2) / 12).clamp(0.08, 1.0),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                transcript.isEmpty
                    ? listening
                          ? '말을 시작해 주세요…'
                          : '마이크 버튼을 누르면 인식된 문장이 여기에 표시됩니다.'
                    : transcript,
                textAlign: transcript.isEmpty
                    ? TextAlign.center
                    : TextAlign.start,
                style: transcript.isEmpty
                    ? Theme.of(context).textTheme.bodyMedium
                    : Theme.of(context).textTheme.headlineSmall,
              ),
              if (assessment != null) ...[
                const SizedBox(height: 12),
                Text(
                  assessment!.feedback,
                  style: TextStyle(
                    color: assessment!.passed
                        ? const Color(0xFF238B57)
                        : colors.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: TextStyle(
                    color: colors.error,
                    fontWeight: FontWeight.w700,
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

class _PronunciationActions extends StatelessWidget {
  const _PronunciationActions({
    required this.listening,
    required this.speechAvailable,
    required this.hasAssessment,
    required this.onMic,
    required this.onRetry,
    required this.onNext,
    required this.onSelfNeedsPractice,
    required this.onSelfPassed,
    required this.minimumControlHeight,
    required this.needsPracticeShortcut,
    required this.passedShortcut,
  });

  final bool listening;
  final bool speechAvailable;
  final bool hasAssessment;
  final VoidCallback onMic;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final VoidCallback onSelfNeedsPractice;
  final VoidCallback onSelfPassed;
  final double minimumControlHeight;
  final String needsPracticeShortcut;
  final String passedShortcut;

  @override
  Widget build(BuildContext context) {
    if (!speechAvailable) {
      return CallbackShortcuts(
        key: const Key('pronunciation-self-assessment-shortcuts'),
        bindings: {
          if (needsPracticeShortcut == '1')
            const SingleActivator(LogicalKeyboardKey.digit1):
                onSelfNeedsPractice,
          if (passedShortcut == '2')
            const SingleActivator(LogicalKeyboardKey.digit2): onSelfPassed,
        },
        child: Focus(
          autofocus: true,
          child: _ManualPronunciationAssessment(
            onNeedsPractice: onSelfNeedsPractice,
            onPassed: onSelfPassed,
            minimumControlHeight: minimumControlHeight,
            needsPracticeShortcut: needsPracticeShortcut,
            passedShortcut: passedShortcut,
          ),
        ),
      );
    }
    if (hasAssessment) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('retry-pronunciation'),
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                minimumSize: Size.fromHeight(minimumControlHeight),
              ),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('다시 말하기'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              key: const Key('next-pronunciation'),
              onPressed: onNext,
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(minimumControlHeight),
              ),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('다음 표현'),
            ),
          ),
        ],
      );
    }
    return FilledButton.icon(
      key: const Key('pronunciation-mic'),
      onPressed: onMic,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(max(52.0, minimumControlHeight)),
        backgroundColor: listening ? Theme.of(context).colorScheme.error : null,
      ),
      icon: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded),
      label: Text(listening ? '말하기 끝내기' : '마이크 누르고 말하기'),
    );
  }
}

class _ManualPronunciationAssessment extends StatelessWidget {
  const _ManualPronunciationAssessment({
    required this.onNeedsPractice,
    required this.onPassed,
    required this.minimumControlHeight,
    required this.needsPracticeShortcut,
    required this.passedShortcut,
  });

  final VoidCallback onNeedsPractice;
  final VoidCallback onPassed;
  final double minimumControlHeight;
  final String needsPracticeShortcut;
  final String passedShortcut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final needsPracticeButton = Semantics(
      button: true,
      label: '연습 필요로 평가하고 다음 표현으로 이동. 단축키 $needsPracticeShortcut',
      child: ExcludeSemantics(
        child: OutlinedButton.icon(
          key: const Key('pronunciation-self-needs-practice'),
          onPressed: onNeedsPractice,
          style: OutlinedButton.styleFrom(
            minimumSize: Size.fromHeight(max(52.0, minimumControlHeight)),
          ),
          icon: const Icon(Icons.replay_rounded),
          label: Text('연습 필요 [$needsPracticeShortcut]'),
        ),
      ),
    );
    final passedButton = Semantics(
      button: true,
      label: '잘 읽었음으로 평가하고 다음 표현으로 이동. 단축키 $passedShortcut',
      child: ExcludeSemantics(
        child: FilledButton.icon(
          key: const Key('pronunciation-self-passed'),
          onPressed: onPassed,
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(max(52.0, minimumControlHeight)),
          ),
          icon: const Icon(Icons.check_rounded),
          label: Text('잘 읽었음 [$passedShortcut]'),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final stackButtons =
            constraints.maxWidth < 520 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        return Semantics(
          key: const Key('pronunciation-self-assessment'),
          container: true,
          explicitChildNodes: true,
          label: '음성 인식 없이 스스로 평가. 목표 발음을 듣고 따라 읽은 뒤 결과를 직접 선택하세요.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '음성 인식 없이 스스로 평가',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 3),
                      Text('목표 발음을 듣고 따라 읽은 뒤 결과를 직접 선택하세요.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (stackButtons) ...[
                needsPracticeButton,
                const SizedBox(height: 8),
                passedButton,
              ] else
                Row(
                  children: [
                    Expanded(child: needsPracticeButton),
                    const SizedBox(width: 10),
                    Expanded(child: passedButton),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PronunciationCompletion extends StatelessWidget {
  const _PronunciationCompletion({
    required this.passed,
    required this.needsPractice,
    required this.minutes,
    required this.onHub,
    required this.returnLabel,
  });

  final int passed;
  final int needsPractice;
  final int minutes;
  final VoidCallback onHub;
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
                    Icons.record_voice_over_rounded,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '발음 연습을 마쳤어요',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$minutes분 · 통과 $passed개 · 더 연습 $needsPractice개',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: onHub,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
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
