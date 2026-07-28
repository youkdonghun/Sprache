import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../domain/learning_item.dart';
import '../domain/pronunciation_score.dart';
import '../domain/study_history.dart';
import '../state/app_state.dart';

class PronunciationScreen extends ConsumerStatefulWidget {
  const PronunciationScreen({this.unitIndex, super.key});

  final int? unitIndex;

  @override
  ConsumerState<PronunciationScreen> createState() =>
      _PronunciationScreenState();
}

class _PronunciationScreenState extends ConsumerState<PronunciationScreen> {
  final _speech = SpeechToText();
  final _tts = FlutterTts();
  final _scorer = const PronunciationScorer();

  late List<LearningItem> _queue;
  late DateTime _startedAt;
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
  String? _errorMessage;
  PronunciationAssessment? _assessment;

  LearningItem get _item => _queue[_index];

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    final controller = ref.read(appControllerProvider.notifier);
    final sourceItems = widget.unitIndex == null
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
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
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

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) _finalizeRecognition();
      return;
    }
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
  }

  void _recordAttempt(bool passed) {
    if (_attemptRecorded) return;
    _attemptRecorded = true;
    ref
        .read(appControllerProvider.notifier)
        .recordAnswer(
          item: _item,
          correct: passed,
          studiedAt: DateTime.now(),
          exerciseType: 'pronunciation',
        );
    if (passed) {
      _passed++;
    } else {
      _needsPractice++;
    }
  }

  void _manualComplete() {
    _recordAttempt(true);
    _next();
  }

  void _retry() {
    setState(() {
      _recognized = '';
      _assessment = null;
      _attemptRecorded = false;
      _errorMessage = null;
      _soundLevel = 0;
    });
  }

  void _next() {
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
    });
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
            courseId: ref.read(appControllerProvider).selectedLanguage.courseId,
            startedAt: _startedAt,
            endedAt: DateTime.now(),
            correctCount: _passed,
            wrongCount: _needsPractice,
            earnedXp: _passed * 10 + _needsPractice * 5,
          ),
        );
  }

  void _close() {
    unawaited(_speech.cancel());
    unawaited(_saveSession());
    context.go(widget.unitIndex == null ? '/learn' : '/path');
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _close,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: const Center(child: Text('발음 연습에 사용할 표현이 없어요.')),
      );
    }
    if (_completed) {
      return _PronunciationCompletion(
        passed: _passed,
        needsPractice: _needsPractice,
        minutes: max(1, DateTime.now().difference(_startedAt).inMinutes),
        onHub: () => context.go(widget.unitIndex == null ? '/learn' : '/path'),
        returnLabel: widget.unitIndex == null ? '학습실로 돌아가기' : '코스 여정으로',
      );
    }

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _close,
          tooltip: '발음 연습 종료',
          icon: const Icon(Icons.close_rounded),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 28,
                          ),
                          child: Column(
                            children: [
                              Text(
                                _item.text,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
                              if (_item.readings.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _item.readings
                                      .map((reading) => reading.value)
                                      .join(' · '),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(color: colors.primary),
                                ),
                              ],
                              const SizedBox(height: 9),
                              Text(
                                _item.primaryTranslation,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 18),
                              OutlinedButton.icon(
                                onPressed: _speak,
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 19,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                '점수는 기기 음성 인식 결과와 목표 문장의 글자 일치도입니다. 억양·개별 음소를 정밀 분석하는 점수는 아닙니다.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
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
              child: _PronunciationActions(
                listening: _listening,
                speechAvailable: _speechAvailable,
                hasAssessment: _assessment != null,
                onMic: _toggleListening,
                onRetry: _retry,
                onNext: _next,
                onManualComplete: _manualComplete,
              ),
            ),
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
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
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
            textAlign: transcript.isEmpty ? TextAlign.center : TextAlign.start,
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
    required this.onManualComplete,
  });

  final bool listening;
  final bool speechAvailable;
  final bool hasAssessment;
  final VoidCallback onMic;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final VoidCallback onManualComplete;

  @override
  Widget build(BuildContext context) {
    if (!speechAvailable) {
      return FilledButton.icon(
        key: const Key('manual-pronunciation-complete'),
        onPressed: onManualComplete,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        icon: const Icon(Icons.check_rounded),
        label: const Text('따라 읽었어요'),
      );
    }
    if (hasAssessment) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('retry-pronunciation'),
              onPressed: onRetry,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('다시 말하기'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              key: const Key('next-pronunciation'),
              onPressed: onNext,
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
        minimumSize: const Size.fromHeight(52),
        backgroundColor: listening ? Theme.of(context).colorScheme.error : null,
      ),
      icon: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded),
      label: Text(listening ? '말하기 끝내기' : '마이크 누르고 말하기'),
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
