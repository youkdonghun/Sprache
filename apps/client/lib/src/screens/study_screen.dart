import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../domain/active_study_session.dart';
import '../domain/accessibility_input_profile.dart';
import '../domain/adaptive_study_session.dart';
import '../domain/answer_normalizer.dart';
import '../domain/app_experience_preferences.dart';
import '../domain/content_management.dart';
import '../domain/course_path.dart';
import '../domain/language.dart';
import '../domain/learning_item.dart';
import '../domain/progress.dart';
import '../domain/quiz_support.dart';
import '../domain/quiz_session_support.dart';
import '../domain/session_enhancements.dart';
import '../domain/study_history.dart';
import '../domain/study_completion_receipt.dart';
import '../domain/study_interaction_preferences.dart';
import '../domain/study_limits.dart';
import '../domain/study_preferences.dart';
import '../domain/study_routines.dart';
import '../domain/study_runtime_modes.dart';
import '../domain/study_subject.dart';
import '../services/app_feedback_service.dart';
import '../services/app_clock.dart';
import '../services/media_lifecycle_coordinator.dart';
import '../services/tts_service.dart';
import '../state/app_state.dart';
import '../state/connection_state.dart';
import '../state/device_preferences_state.dart';
import '../state/local_storage_state.dart';
import '../theme/study_accessibility_theme.dart';
import '../widgets/focus_restoration.dart';
import '../widgets/keyboard_help_overlay.dart';
import '../widgets/quick_content_sheet.dart';
import '../widgets/privacy_mode_scope.dart';

enum _ExerciseMode {
  recognition,
  production,
  cloze,
  sentenceOrder,
  listening,
  listeningDiscrimination,
}

enum _SessionManagementAction {
  options,
  preview,
  keyboardHelp,
  matchSprint,
  restart,
  wrongAnswers,
  remaining,
  finish,
}

enum _ExistingSessionAction { cancel, resume, replace }

enum _FeedbackSecondaryAction { quickAdd, memoryHint }

const _memoryHintField = 'memoryHint';
const _baseContentCorrectionField = 'quizContent';

final studyTtsServiceProvider = Provider<TtsService>(
  (ref) => TtsService.device(),
);

final studyFeedbackServiceProvider = Provider<AppFeedbackService>(
  (ref) => AppFeedbackService(
    readPreferences: () =>
        ref.read(appControllerProvider).preferences.experience,
    readDevicePreferences: () =>
        ref.read(devicePreferencesControllerProvider).preferences.voice,
  ),
);

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({
    this.mode = StudyMode.mixed,
    this.unitIndex,
    this.itemLimit,
    this.queuePriority = StudyQueuePriority.dueFirst,
    this.historyFilter = StudyHistoryFilter.all,
    this.resume = false,
    this.customPlan = false,
    this.examMode = false,
    this.startMatchSprint = false,
    this.practiceActivityId,
    this.playlistActivityIds = const [],
    this.playlistIndex = 0,
    super.key,
  });

  final StudyMode mode;
  final int? unitIndex;
  final int? itemLimit;
  final StudyQueuePriority queuePriority;
  final StudyHistoryFilter historyFilter;
  final bool resume;
  final bool customPlan;
  final bool examMode;
  final bool startMatchSprint;
  final String? practiceActivityId;
  final List<String> playlistActivityIds;
  final int playlistIndex;

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen>
    with WidgetsBindingObserver {
  late final MediaLifecycleRegistry _mediaLifecycleRegistry;
  final _answerController = TextEditingController();
  final _answerFocus = FocusNode(debugLabel: 'study-answer-input');
  final _questionFocus = FocusNode(debugLabel: 'study-question');
  final _feedbackFocus = FocusNode(debugLabel: 'study-feedback');
  final _normalizer = const AnswerNormalizer();
  final _choiceBuilder = const QuizChoiceBuilder();
  final _hintBuilder = const QuizHintBuilder();
  final _repairAdvisor = const QuizRepairAdvisor();
  final _uuid = const Uuid();
  DateTime get _now => ref.read(appClockProvider)();
  late final TtsService _baseTtsService;
  Timer? _autoAdvanceTimer;
  Timer? _draftCheckpointTimer;
  Timer? _breakReminderTimer;
  Timer? _examTimer;
  var _questionGeneration = 0;
  var _autoPlayedQuestionGeneration = -1;
  var _speechGeneration = 0;
  var _subjectChangeHandled = false;
  final _adaptiveEngine = const AdaptiveStudySessionEngine();
  final _liveDifficultyEngine = const LiveDifficultyEngine();
  final _listeningDiscriminationBuilder =
      const ListeningDiscriminationBuilder();

  late List<LearningItem> _queue;
  late String _subjectIdAtStart;
  late int _plannedCount;
  late DateTime _sessionStartedAt;
  late String _sessionId;
  late ActiveStudySession _activeSession;
  var _sessionSaved = false;
  var _practiceResultSaved = false;
  PracticeChallengeScore? _challengeScore;
  var _index = 0;
  var _sessionCorrect = 0;
  var _sessionWrong = 0;
  var _sessionXp = 0;
  var _combo = 0;
  var _bestCombo = 0;
  var _completed = false;
  bool? _correct;
  String? _selectedChoice;
  String? _submittedAnswer;
  var _hintLevel = 0;
  var _speechPlayCount = 0;
  var _remainingTokens = <String>[];
  var _orderedTokens = <String>[];
  final _wrongItemIds = <String>{};
  final _finalCorrectItemIds = <String>{};
  final _failureCountByItemId = <String, int>{};
  final _attemptReviews = <QuizAttemptReview>[];
  late StudyAnswerDirection _sessionAnswerDirection;
  var _gradingStrength = StudyGradingStrictness.balanced;
  var _recordProgress = true;
  var _choiceCount = 4;
  var _hintsEnabled = true;
  bool? _autoAdvanceOverride;
  bool? _soundEffectsOverride;
  var _backlogRecovery = false;
  var _inputProfile = PracticeInputProfile.standard;
  _PendingQuizResponse? _pendingResponse;
  late StudySessionRuntimeOptions _runtimeOptions;
  DateTime? _questionPresentedAt;
  var _breakRemindersShown = 0;
  var _breakDialogOpen = false;
  final _attemptMetrics = <StudyAttemptMetric>[];
  var _adaptiveReasonByItemId = <String, String>{};
  var _adaptiveSkillByItemId = <String, StudySkill>{};
  var _saveAnnouncement = '';
  DateTime? _sessionSavedAt;
  var _examSetupComplete = false;
  var _examTimedOut = false;
  var _examRemainingSeconds = 0;
  ExamConfiguration _examConfiguration = const ExamConfiguration();
  final _liveDifficultyAttempts = <LiveDifficultyAttempt>[];
  LiveDifficultyLevel _liveDifficulty = LiveDifficultyLevel.standard;
  LiveDifficultyLevel? _liveDifficultyLock;
  String _liveDifficultyReason = '첫 문제는 기본 난이도로 시작해요.';
  var _showListeningTextFallback = false;

  LearningItem get _item => _queue[_index];
  bool get _isPlaylist => widget.playlistActivityIds.length >= 2;
  bool get _isListeningDiscrimination =>
      widget.practiceActivityId == 'listening-discrimination';
  String get _returnRoute => _isPlaylist
      ? '/learn'
      : widget.customPlan
      ? '/session-builder'
      : widget.unitIndex == null
      ? '/learn'
      : '/path';

  _ExerciseMode get _mode {
    if (widget.practiceActivityId == 'listening-discrimination') {
      return _ExerciseMode.listeningDiscrimination;
    }
    switch (widget.mode) {
      case StudyMode.meaning:
        return _ExerciseMode.recognition;
      case StudyMode.production:
        return _ExerciseMode.production;
      case StudyMode.cloze:
        return _ExerciseMode.cloze;
      case StudyMode.sentenceOrder:
        return _ExerciseMode.sentenceOrder;
      case StudyMode.listening:
      case StudyMode.pronunciation:
        return _ExerciseMode.listening;
      case StudyMode.mixed:
      case StudyMode.review:
      case StudyMode.weak:
      case StudyMode.favorites:
      case StudyMode.newItems:
      case StudyMode.words:
      case StudyMode.sentences:
        break;
    }
    if (_sessionAnswerDirection != StudyAnswerDirection.mixed) {
      return _ExerciseMode.recognition;
    }
    if (!widget.examMode && widget.mode == StudyMode.mixed) {
      if (_liveDifficulty == LiveDifficultyLevel.supportive &&
          _item.capabilities.contains(ExerciseCapability.recognition)) {
        return _ExerciseMode.recognition;
      }
      if (_liveDifficulty == LiveDifficultyLevel.challenge &&
          _item.capabilities.contains(ExerciseCapability.production)) {
        return _ExerciseMode.production;
      }
    }
    final recommendedSkill =
        _runtimeOptions.strategy == StudySessionStrategy.custom
        ? null
        : _adaptiveSkillByItemId[_item.id];
    if (recommendedSkill != null) {
      switch (recommendedSkill) {
        case StudySkill.meaning:
          if (_item.capabilities.contains(ExerciseCapability.recognition)) {
            return _ExerciseMode.recognition;
          }
          break;
        case StudySkill.writing:
          if (_item.capabilities.contains(ExerciseCapability.production)) {
            return _ExerciseMode.production;
          }
          break;
        case StudySkill.listening || StudySkill.pronunciation:
          if (_item.capabilities.contains(ExerciseCapability.listening)) {
            return _ExerciseMode.listening;
          }
          break;
        case StudySkill.sentence:
          if (_item.kind == LearningItemKind.sentence &&
              _item.sentenceTokens.length >= 2) {
            if (_item.capabilities.contains(ExerciseCapability.cloze) &&
                (_index.isEven ||
                    !_item.capabilities.contains(
                      ExerciseCapability.sentenceOrder,
                    ))) {
              return _ExerciseMode.cloze;
            }
            if (_item.capabilities.contains(ExerciseCapability.sentenceOrder)) {
              return _ExerciseMode.sentenceOrder;
            }
          }
          break;
      }
    }
    final modes = <_ExerciseMode>[
      _ExerciseMode.recognition,
      _ExerciseMode.production,
      if (_item.kind == LearningItemKind.sentence &&
          _item.sentenceTokens.length >= 2 &&
          _item.capabilities.contains(ExerciseCapability.cloze))
        _ExerciseMode.cloze,
      if (_item.kind == LearningItemKind.sentence &&
          _item.sentenceTokens.length >= 2 &&
          _item.capabilities.contains(ExerciseCapability.sentenceOrder))
        _ExerciseMode.sentenceOrder,
    ];
    return modes[_index % modes.length];
  }

  bool get _recognitionIsReversed =>
      _mode == _ExerciseMode.recognition &&
      widget.mode != StudyMode.meaning &&
      _sessionAnswerDirection == StudyAnswerDirection.meaningToLearning;

  bool get _isChoiceMode =>
      _mode == _ExerciseMode.recognition ||
      _mode == _ExerciseMode.cloze ||
      _mode == _ExerciseMode.listeningDiscrimination;

  bool get _isTextInputMode =>
      _mode == _ExerciseMode.production || _mode == _ExerciseMode.listening;

  FocusNode get _preferredQuestionFocus =>
      _isTextInputMode ? _answerFocus : _questionFocus;

  bool get _autoAdvanceEnabled =>
      _autoAdvanceOverride ?? _interaction.autoAdvanceCorrect;

  bool get _allowsAutomaticTransition {
    final experience = ref.read(appControllerProvider).preferences.experience;
    return !ref.read(accessibilityInputProfileProvider).reduceMotion &&
        !experience.effectiveReduceMotion;
  }

  AppFeedbackService get _feedbackService {
    final base = ref.read(studyFeedbackServiceProvider);
    final override = _soundEffectsOverride;
    if (override == null) return base;
    return AppFeedbackService(
      readPreferences: () => ref
          .read(appControllerProvider)
          .preferences
          .experience
          .copyWith(soundEffectsEnabled: override),
      readDevicePreferences: base.readDevicePreferences,
      emitHaptic: base.emitHaptic,
      emitSound: base.emitSound,
      emitHapticWithStrength: base.emitHapticWithStrength,
      emitSoundWithStrength: base.emitSoundWithStrength,
    );
  }

  String get _clozeAnswer =>
      _item.sentenceTokens[_item.sentenceTokens.length ~/ 2];

  String get _expectedAnswer => switch (_mode) {
    _ExerciseMode.recognition when _recognitionIsReversed => _item.text,
    _ExerciseMode.recognition => _item.primaryTranslation,
    _ExerciseMode.production => _item.text,
    _ExerciseMode.cloze => _clozeAnswer,
    _ExerciseMode.sentenceOrder => _item.text,
    _ExerciseMode.listening => _item.text,
    _ExerciseMode.listeningDiscrimination => _item.text,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _examSetupComplete = !widget.examMode;
    if (widget.examMode) {
      _recordProgress = false;
      _hintsEnabled = false;
      _autoAdvanceOverride = false;
      _liveDifficultyLock = LiveDifficultyLevel.standard;
    }
    _baseTtsService = ref.read(studyTtsServiceProvider);
    _mediaLifecycleRegistry = ref.read(mediaLifecycleRegistryProvider);
    _mediaLifecycleRegistry.register(
      this,
      MediaLifecycleRegistration(
        persistCheckpoint: _persistLifecycleCheckpoint,
        stopTextToSpeech: _baseTtsService.stop,
      ),
    );
    _sessionAnswerDirection = ref
        .read(appControllerProvider)
        .preferences
        .interaction
        .answerDirection;
    final controller = ref.read(appControllerProvider.notifier);
    final initialPreferences = ref.read(appControllerProvider).preferences;
    _runtimeOptions = StudySessionRuntimeOptions(
      strategy: StudySessionStrategy.adaptive,
      breakReminderMinutes: 20,
      showKoreanReading: initialPreferences.interaction.showKoreanReading,
      showNativeReading: initialPreferences.interaction.showNativeReading,
      ttsRate: initialPreferences.ttsRate,
      liveDifficultyLock: _liveDifficultyLock,
      practiceActivityId: widget.practiceActivityId,
      examSetupPending: widget.examMode,
    );
    if (widget.customPlan) {
      final plan = controller.activeSessionPlan;
      _sessionAnswerDirection =
          plan.answerDirectionOverride ?? _sessionAnswerDirection;
      _gradingStrength = plan.gradingStrictness;
      _recordProgress = plan.recordProgress;
      _choiceCount = plan.choiceCount;
      _hintsEnabled = plan.hintsEnabled;
      _autoAdvanceOverride = plan.autoAdvanceOverride;
      _soundEffectsOverride = plan.soundEffectsOverride;
      if (plan.largeControls) {
        _inputProfile = PracticeInputProfile.accessible;
      }
      _backlogRecovery = plan.backlogRecovery.enabled;
    } else if (widget.resume) {
      _backlogRecovery = controller.activeSessionPlan.backlogRecovery.enabled;
    }
    // Exam integrity rules are absolute and must win over a saved/custom plan.
    if (widget.examMode) {
      _recordProgress = false;
      _hintsEnabled = false;
      _autoAdvanceOverride = false;
      _liveDifficultyLock = LiveDifficultyLevel.standard;
      _runtimeOptions = _runtimeOptions.copyWith(
        liveDifficultyLock: LiveDifficultyLevel.standard,
      );
    }
    if (!widget.mode.allowsAnswerDirectionOverride) {
      _sessionAnswerDirection = widget.mode.effectiveFixedAnswerDirection;
    }
    var persistedSession = ref.read(appControllerProvider).activeStudySession;
    if (widget.resume &&
        persistedSession != null &&
        persistedSession.courseId !=
            ref.read(appControllerProvider).activeCourseId) {
      StudySubject? sessionSubject;
      for (final subject in controller.availableSubjects) {
        if (subject.courseId == persistedSession.courseId) {
          sessionSubject = subject;
          break;
        }
      }
      if (sessionSubject != null) {
        controller.selectSubject(sessionSubject.id);
      }
    }
    if (!widget.resume &&
        persistedSession != null &&
        persistedSession.courseId !=
            ref.read(appControllerProvider).activeCourseId) {
      persistedSession = null;
    }
    _subjectIdAtStart = ref.read(appControllerProvider).activeSubjectId;
    final existingSession = persistedSession;
    if (!widget.resume && existingSession != null) {
      _queue = const [];
      _plannedCount = existingSession.itemIds.length;
      _sessionStartedAt = existingSession.startedAt;
      _sessionId = existingSession.sessionId;
      _activeSession = existingSession;
      _sessionCorrect = existingSession.correctCount;
      _sessionWrong = existingSession.wrongCount;
      _sessionXp = existingSession.earnedXp;
      _wrongItemIds.addAll(existingSession.wrongItemIds);
      _finalCorrectItemIds.addAll(existingSession.finalCorrectItemIds);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showExistingSessionChoice(existingSession);
      });
      return;
    }
    final active = widget.resume
        ? ref.read(appControllerProvider).activeStudySession
        : null;
    if (active != null) {
      _activeSession = active;
      _runtimeOptions = active.runtimeOptions;
      _liveDifficultyLock = _runtimeOptions.liveDifficultyLock;
      _liveDifficultyAttempts
        ..clear()
        ..addAll(
          active.attemptMetrics
              .skip(max(0, active.attemptMetrics.length - 20))
              .map(
                (metric) => LiveDifficultyAttempt(
                  correct: metric.correct,
                  responseTime: metric.responseTime,
                  usedHint: metric.usedHint,
                ),
              ),
        );
      final restoredDifficulty = _liveDifficultyEngine.decide(
        attempts: _liveDifficultyAttempts,
        manualLock: _liveDifficultyLock,
      );
      _liveDifficulty = restoredDifficulty.level;
      _liveDifficultyReason = restoredDifficulty.reason;
      _attemptMetrics.addAll(active.attemptMetrics);
      _attemptReviews.addAll(active.attemptReviews);
      final byId = {for (final item in controller.courseItems) item.id: item};
      _queue = active.itemIds
          .map((id) => byId[id])
          .whereType<LearningItem>()
          .toList(growable: true);
      _plannedCount = _queue.length;
      final restoredExamConfiguration = _runtimeOptions.examConfiguration;
      if (widget.examMode && restoredExamConfiguration != null) {
        _examConfiguration = restoredExamConfiguration.normalizedFor(
          _queue.length,
        );
        final deadline = _runtimeOptions.examDeadline;
        if (deadline != null) {
          _examRemainingSeconds = max(0, deadline.difference(_now).inSeconds);
          _examSetupComplete = true;
        }
      }
      _sessionStartedAt = active.startedAt;
      _sessionId = active.sessionId;
      _sessionCorrect = active.correctCount;
      _sessionWrong = active.wrongCount;
      _sessionXp = active.earnedXp;
      _wrongItemIds.addAll(active.wrongItemIds);
      _finalCorrectItemIds.addAll(active.finalCorrectItemIds);
      if (_queue.isNotEmpty) {
        if (active.currentIndex >= _queue.length) {
          _index = _queue.length - 1;
          _completed = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            controller.clearActiveStudySession(
              expectedSessionId: active.sessionId,
            );
            _recordPracticeChallengeResult();
            unawaited(_saveSession());
          });
        } else {
          _index = active.currentIndex;
          _refreshQueueRecommendation(fromIndex: _index, reorder: false);
          _prepareExercise();
          final checkpoint = active.inputCheckpoint;
          if (checkpoint != null &&
              checkpoint.itemId == _item.id &&
              checkpoint.isMeaningful) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) unawaited(_showDraftRestoreChoice(checkpoint));
            });
          }
          if (active.phase == ActiveStudySessionPhase.paused) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final resumed = controller.resumeActiveStudySession(
                _now,
                expectedSessionId: active.sessionId,
              );
              if (resumed != null && mounted) {
                setState(() => _activeSession = resumed);
              }
            });
          }
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            controller.clearActiveStudySession(
              expectedSessionId: active.sessionId,
            );
          }
        });
      }
    } else {
      _queue = List<LearningItem>.of(
        controller.queue(
          _now,
          mode: widget.mode,
          unitIndex: widget.unitIndex,
          itemLimit: widget.itemLimit,
          queuePriority: widget.queuePriority,
          historyFilter: widget.historyFilter,
          sessionPlan: widget.customPlan
              ? controller.activeSessionPlan.copyWith(mode: widget.mode)
              : null,
        ),
        growable: true,
      );
      if (_queue.isEmpty &&
          widget.mode == StudyMode.mixed &&
          !widget.customPlan) {
        _queue = widget.unitIndex == null
            ? controller.selectedItems
            : controller.itemsForUnit(widget.unitIndex!);
        _queue = _queue
            .take(
              widget.itemLimit ??
                  ref.read(appControllerProvider).preferences.sessionItemLimit,
            )
            .toList(growable: true);
      }
      if (_isListeningDiscrimination) {
        final candidates = controller.selectedItems;
        final eligible = _queue
            .where(
              (item) => _listeningDiscriminationBuilder.canBuild(
                target: item,
                candidates: candidates,
              ),
            )
            .toList(growable: true);
        _queue = eligible
            .take(
              widget.itemLimit ??
                  ref.read(appControllerProvider).preferences.sessionItemLimit,
            )
            .toList(growable: true);
      }
      _refreshQueueRecommendation(fromIndex: 0, reorder: true);
      _plannedCount = _queue.length;
      _sessionStartedAt = _now;
      _sessionId = _newSessionId();
      if (_queue.isNotEmpty) {
        _activeSession = ActiveStudySession.started(
          sessionId: _sessionId,
          courseId: ref.read(appControllerProvider).activeCourseId,
          mode: widget.mode,
          unitIndex: widget.unitIndex,
          itemIds: _queue.map((item) => item.id).toList(growable: false),
          startedAt: _sessionStartedAt,
          runtimeOptions: _runtimeOptions,
        );
        _prepareExercise();
        final initialItemIds = _queue
            .map((item) => item.id)
            .toList(growable: false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          controller.beginActiveStudySession(
            sessionId: _sessionId,
            mode: widget.mode,
            unitIndex: widget.unitIndex,
            itemIds: initialItemIds,
            startedAt: _sessionStartedAt,
            courseId: _activeSession.courseId,
            runtimeOptions: _runtimeOptions,
          );
        });
      }
    }
    ref.listenManual<StudyInteractionPreferences>(
      appControllerProvider.select((state) => state.preferences.interaction),
      (previous, next) {
        if (!next.autoPlayQuestionAudio) return;
        _scheduleQuestionAudio();
      },
    );
    ref.listenManual<String>(
      appControllerProvider.select((state) => state.activeSubjectId),
      (previous, next) {
        if (next != _subjectIdAtStart) {
          _handleSubjectChange();
        }
      },
    );
    if (widget.examMode && _queue.isNotEmpty && !_completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_examSetupComplete) {
          _startExamCountdown();
        } else {
          unawaited(_configureAndStartExam());
        }
      });
    }
    if (widget.startMatchSprint && _queue.isNotEmpty && !widget.examMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showMatchSprint());
      });
    }
    if (_queue.isNotEmpty && !widget.examMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleBreakReminder();
      });
    }
  }

  void _handleSubjectChange() {
    if (_subjectChangeHandled || _completed || _queue.isEmpty) return;
    _subjectChangeHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _autoAdvanceTimer?.cancel();
      _speechGeneration++;
      unawaited(_baseTtsService.stop());
      final inputCheckpoint = _currentInputCheckpoint();
      _commitPendingResponse();
      final nextIndex = (_correct == null ? _index : _index + 1).clamp(
        0,
        _queue.length,
      );
      ref
          .read(appControllerProvider.notifier)
          .pauseActiveStudySession(
            _now,
            itemIds: _queue.map((item) => item.id).toList(growable: false),
            currentIndex: nextIndex,
            correctCount: _sessionCorrect,
            wrongCount: _sessionWrong,
            earnedXp: _sessionXp,
            wrongItemIds: _wrongItemIds,
            finalCorrectItemIds: _finalCorrectItemIds,
            runtimeOptions: _runtimeOptions,
            inputCheckpoint: inputCheckpoint,
            clearInputCheckpoint: inputCheckpoint == null,
            attemptMetrics: _attemptMetrics,
            attemptReviews: _attemptReviews,
            expectedSessionId: _sessionId,
          );
      context.go('/learn');
    });
  }

  Future<void> _showExistingSessionChoice(ActiveStudySession existing) async {
    final controller = ref.read(appControllerProvider.notifier);
    final subject = controller.availableSubjects
        .cast<StudySubject?>()
        .firstWhere(
          (candidate) => candidate?.courseId == existing.courseId,
          orElse: () => null,
        );
    final progress = '${existing.completedCount}/${existing.itemIds.length}문제';
    final action = await showFocusRestoringDialog<_ExistingSessionAction>(
      context: context,
      fallbackFocus: _preferredQuestionFocus,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const Key('active-session-conflict-dialog'),
        icon: const Icon(Icons.restore_rounded),
        title: const Text('진행 중인 학습이 있어요'),
        content: Text(
          '${subject?.name ?? existing.courseId} · ${existing.mode.label} · $progress\n'
          '기존 학습을 이어갈까요, 끝내고 새로 시작할까요?',
        ),
        actions: [
          TextButton(
            key: const Key('cancel-new-session'),
            autofocus: true,
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ExistingSessionAction.cancel),
            child: const Text('돌아가기'),
          ),
          OutlinedButton(
            key: const Key('resume-existing-session'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ExistingSessionAction.resume),
            child: const Text('이어하기'),
          ),
          FilledButton(
            key: const Key('replace-active-session'),
            onPressed: () =>
                Navigator.of(dialogContext).pop(_ExistingSessionAction.replace),
            child: const Text('끝내고 새로 시작'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _ExistingSessionAction.resume:
        if (subject != null) controller.selectSubject(subject.id);
        context.go('/study?resume=true');
        return;
      case _ExistingSessionAction.replace:
        controller.clearActiveStudySession(
          expectedSessionId: existing.sessionId,
        );
        final parameters = <String, String>{
          'mode': widget.mode.name,
          if (widget.unitIndex case final unit?) 'unit': '$unit',
          if (widget.itemLimit case final limit?) 'limit': '$limit',
          if (widget.queuePriority != StudyQueuePriority.dueFirst)
            'queuePriority': widget.queuePriority.name,
          if (widget.historyFilter != StudyHistoryFilter.all)
            'historyFilter': widget.historyFilter.name,
          if (widget.customPlan) 'custom': 'true',
          if (widget.examMode) 'exam': 'true',
          'practiceActivityId': ?widget.practiceActivityId,
          if (widget.playlistActivityIds.length >= 2)
            'playlist': widget.playlistActivityIds.join(','),
          if (widget.playlistActivityIds.length >= 2)
            'playlistIndex': '${widget.playlistIndex}',
          'replace': '${_now.microsecondsSinceEpoch}',
        };
        context.go(Uri(path: '/study', queryParameters: parameters).toString());
        return;
      case _ExistingSessionAction.cancel:
      case null:
        context.go(_returnRoute);
        return;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mediaLifecycleRegistry.unregister(this);
    _autoAdvanceTimer?.cancel();
    _draftCheckpointTimer?.cancel();
    _breakReminderTimer?.cancel();
    _examTimer?.cancel();
    _questionGeneration++;
    _speechGeneration++;
    _answerController.dispose();
    _answerFocus.dispose();
    _questionFocus.dispose();
    _feedbackFocus.dispose();
    unawaited(_baseTtsService.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.examMode || !_examSetupComplete || _completed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _startExamCountdown();
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _examTimer?.cancel();
        return;
    }
  }

  Future<void> _configureAndStartExam() async {
    final configuration = await showFocusRestoringDialog<ExamConfiguration>(
      context: context,
      fallbackFocus: _questionFocus,
      barrierDismissible: false,
      builder: (context) => _ExamSetupDialog(
        availableQuestions: _queue.length,
        initial: _examConfiguration.normalizedFor(_queue.length),
      ),
    );
    if (!mounted) return;
    if (configuration == null) {
      ref
          .read(appControllerProvider.notifier)
          .clearActiveStudySession(expectedSessionId: _sessionId);
      context.go(_returnRoute);
      return;
    }
    final normalized = configuration.normalizedFor(_queue.length);
    final items = _queue.take(normalized.questionCount).toList(growable: true);
    final startedAt = _now;
    final deadline = startedAt.add(normalized.timeLimit).toUtc();
    setState(() {
      _examConfiguration = normalized;
      _queue = items;
      _plannedCount = items.length;
      _sessionStartedAt = startedAt;
      _runtimeOptions = _runtimeOptions.copyWith(
        examSetupPending: false,
        examConfiguration: normalized,
        examDeadline: deadline,
      );
      _activeSession = _activeSession.copyWith(
        itemIds: items.map((item) => item.id).toList(growable: false),
        initialItemIds: items.map((item) => item.id).toList(growable: false),
        startedAt: startedAt,
        updatedAt: startedAt,
        runtimeOptions: _runtimeOptions,
      );
      _examRemainingSeconds = normalized.timeLimit.inSeconds;
      _examSetupComplete = true;
      _prepareExercise();
    });
    _persistActiveSession(0, clearInputCheckpoint: true);
    _startExamCountdown();
    _scheduleQuestionAudio();
  }

  void _startExamCountdown() {
    _examTimer?.cancel();
    final initialRemaining = _examSecondsUntilDeadline();
    if (initialRemaining <= 0) {
      _finishExamDueToTimeout();
      return;
    }
    if (_examRemainingSeconds != initialRemaining && mounted) {
      setState(() => _examRemainingSeconds = initialRemaining);
    }
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _completed) {
        timer.cancel();
        return;
      }
      final remaining = min(
        _examSecondsUntilDeadline(),
        _examRemainingSeconds - 1,
      );
      if (remaining <= 0) {
        timer.cancel();
        _finishExamDueToTimeout();
        return;
      }
      if (remaining != _examRemainingSeconds) {
        setState(() => _examRemainingSeconds = remaining);
      }
    });
  }

  int _examSecondsUntilDeadline() {
    final deadline = _runtimeOptions.examDeadline;
    if (deadline == null) return _examRemainingSeconds;
    final milliseconds = deadline.difference(_now).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds + 999) ~/ 1000;
  }

  void _finishExamDueToTimeout() {
    if (_completed) return;
    _completeExam(timedOut: true);
    SemanticsService.sendAnnouncement(
      View.of(context),
      '시간이 끝나 답안을 자동으로 제출했어요.',
      Directionality.of(context),
    );
  }

  void _completeExam({required bool timedOut}) {
    if (_completed) return;
    _examTimer?.cancel();
    _examTimedOut = timedOut;
    _speechGeneration++;
    unawaited(_baseTtsService.stop());
    ref
        .read(appControllerProvider.notifier)
        .clearActiveStudySession(expectedSessionId: _sessionId);
    if (_sessionCorrect + _sessionWrong == 0) {
      _saveAnnouncement = '푼 문제가 없어 진도는 바뀌지 않았어요.';
    } else {
      unawaited(_saveSession());
    }
    _recordPracticeChallengeResult();
    setState(() {
      if (timedOut) _examRemainingSeconds = 0;
      _completed = true;
    });
  }

  Future<void> _confirmExamSubmission() async {
    final submit = await showFocusRestoringDialog<bool>(
      context: context,
      fallbackFocus: _preferredQuestionFocus,
      builder: (dialogContext) => AlertDialog(
        title: const Text('시험을 지금 제출할까요?'),
        content: Text(
          '${_examConfiguration.questionCount}문제 중 ${_sessionCorrect + _sessionWrong}문제를 풀었어요. 빈 답은 오답으로 채점해요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('계속 풀기'),
          ),
          FilledButton(
            key: const Key('submit-exam-early'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('지금 제출'),
          ),
        ],
      ),
    );
    if (submit == true && mounted) _completeExam(timedOut: false);
  }

  void _prepareExercise() {
    _autoAdvanceTimer?.cancel();
    _questionGeneration++;
    _speechGeneration++;
    unawaited(_baseTtsService.stop());
    _selectedChoice = null;
    _submittedAnswer = null;
    _hintLevel = 0;
    _speechPlayCount = 0;
    _showListeningTextFallback = false;
    _answerController.clear();
    _orderedTokens = [];
    _remainingTokens = [..._item.sentenceTokens];
    _remainingTokens.shuffle(Random(_stableSeed(_item.id)));
    _questionPresentedAt = _now;
    _scheduleQuestionAudio();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _correct != null) return;
      if (_isTextInputMode) {
        _answerFocus.requestFocus();
      } else {
        _questionFocus.requestFocus();
      }
    });
  }

  void _scheduleQuestionAudio() {
    final generation = _questionGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _questionGeneration ||
          generation == _autoPlayedQuestionGeneration ||
          _correct != null ||
          !_examSetupComplete ||
          (widget.examMode && _examRemainingSeconds <= 0) ||
          !_interaction.autoPlayQuestionAudio) {
        return;
      }
      _autoPlayedQuestionGeneration = generation;
      unawaited(_speakQuestion());
    });
  }

  int _stableSeed(String value) {
    var hash = 17;
    for (final codeUnit in value.codeUnits) {
      hash = 37 * hash + codeUnit;
    }
    return hash;
  }

  StudyInteractionPreferences get _interaction =>
      ref.read(appControllerProvider).preferences.interaction;

  Future<void> _speak({bool slow = false}) {
    return _speakText(
      language: _item.learningLanguage,
      text: _item.text,
      slow: slow,
    );
  }

  Future<void> _speakQuestion() {
    final speech = _questionSpeech;
    return _speakText(language: speech.language, text: speech.text);
  }

  ({LanguageTag language, String text}) get _questionSpeech {
    return switch (_mode) {
      _ExerciseMode.recognition when _recognitionIsReversed => (
        language: LanguageTag.korean,
        text: _item.primaryTranslation,
      ),
      _ExerciseMode.production || _ExerciseMode.sentenceOrder => (
        language: LanguageTag.korean,
        text: _item.primaryTranslation,
      ),
      _ExerciseMode.recognition ||
      _ExerciseMode.cloze ||
      _ExerciseMode.listening ||
      _ExerciseMode.listeningDiscrimination => (
        language: _item.learningLanguage,
        text: _item.text,
      ),
    };
  }

  Future<void> _speakText({
    required LanguageTag language,
    required String text,
    bool slow = false,
  }) async {
    final request = ++_speechGeneration;
    final preferredRate = _runtimeOptions.ttsRate;
    final rate = slow
        ? (preferredRate * 0.72).clamp(0.2, 0.7).toDouble()
        : preferredRate;
    final repeatCount = _interaction.audioRepeatCount.clamp(1, 3);
    final voice = ref
        .read(devicePreferencesControllerProvider)
        .preferences
        .voice;
    await _baseTtsService.speak(
      language: language,
      text: text,
      rate: rate,
      preferOfflineVoice: _interaction.preferOfflineVoice,
      repeatCount: repeatCount,
      preferredVoiceId: voice.voiceIdByLanguage[language.code],
      pitch: voice.pitch,
    );
    if (!mounted || request != _speechGeneration) return;
    setState(() => _speechPlayCount += repeatCount);
  }

  String _newSessionId() => 'session-${_uuid.v4()}';

  List<StudyAttemptMetric> get _attemptHistory => [
    ..._attemptMetrics,
    for (final session in ref.read(appControllerProvider).recentSessions)
      if (session.courseId == _activeCourseIdForMetrics)
        ...session.attemptMetrics,
  ];

  String get _activeCourseIdForMetrics {
    if (_queue.isNotEmpty) return _queue.first.courseId;
    return ref.read(appControllerProvider).activeCourseId;
  }

  void _refreshQueueRecommendation({
    required int fromIndex,
    required bool reorder,
  }) {
    if (_queue.isEmpty || fromIndex < 0 || fromIndex >= _queue.length) return;
    final state = ref.read(appControllerProvider);
    final recommendation = _adaptiveEngine.recommend(
      items: _queue.sublist(fromIndex),
      mode: widget.mode,
      strategy: _runtimeOptions.strategy,
      progress: state.progress,
      attemptHistory: _attemptHistory,
      now: _now,
    );
    if (reorder && _runtimeOptions.strategy != StudySessionStrategy.custom) {
      _queue.replaceRange(fromIndex, _queue.length, recommendation.items);
    }
    _adaptiveReasonByItemId = {
      ..._adaptiveReasonByItemId,
      ...recommendation.reasonByItemId,
    };
    _adaptiveSkillByItemId = {
      ..._adaptiveSkillByItemId,
      ...recommendation.skillByItemId,
    };
  }

  StudyInputCheckpoint? _currentInputCheckpoint() {
    if (_queue.isEmpty || _completed || _correct != null) return null;
    final checkpoint = StudyInputCheckpoint(
      itemId: _item.id,
      exerciseType: _mode.name,
      answerText: _isTextInputMode ? _answerController.text : '',
      selectedChoice: _isChoiceMode ? _selectedChoice : null,
      orderedTokens: _mode == _ExerciseMode.sentenceOrder
          ? List.unmodifiable(_orderedTokens)
          : const [],
      savedAt: _now,
    );
    return checkpoint.isMeaningful ? checkpoint : null;
  }

  void _scheduleDraftCheckpoint() {
    if (_correct != null || _completed) return;
    _draftCheckpointTimer?.cancel();
    _draftCheckpointTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || _correct != null || _completed) return;
      final checkpoint = _currentInputCheckpoint();
      _persistActiveSession(
        _index,
        inputCheckpoint: checkpoint,
        clearInputCheckpoint: checkpoint == null,
      );
    });
  }

  void _persistLifecycleCheckpoint() {
    _draftCheckpointTimer?.cancel();
    if (_queue.isEmpty || _completed) return;
    final checkpoint = _currentInputCheckpoint();
    _persistActiveSession(
      _index,
      inputCheckpoint: checkpoint,
      clearInputCheckpoint: checkpoint == null,
    );
  }

  Future<void> _showDraftRestoreChoice(StudyInputCheckpoint checkpoint) async {
    if (!mounted || checkpoint.itemId != _item.id || !checkpoint.isMeaningful) {
      return;
    }
    final action = await showFocusRestoringDialog<bool>(
      context: context,
      fallbackFocus: _preferredQuestionFocus,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const Key('study-draft-restore-dialog'),
        icon: const Icon(Icons.edit_note_rounded),
        title: const Text('작성 중이던 답안이 있어요'),
        content: Text(
          '${_checkpointSummary(checkpoint)}\n'
          '${_relativeCheckpointTime(checkpoint.savedAt)}에 안전하게 저장했습니다.',
        ),
        actions: [
          TextButton(
            key: const Key('discard-study-draft'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('비우고 다시 시작'),
          ),
          FilledButton(
            key: const Key('restore-study-draft'),
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('답안 불러오기'),
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action) {
      _restoreInputCheckpoint(checkpoint);
    } else {
      setState(() {
        _selectedChoice = null;
        _answerController.clear();
        _orderedTokens = [];
        _remainingTokens = [..._item.sentenceTokens]
          ..shuffle(Random(_stableSeed(_item.id)));
        _questionPresentedAt = _now;
      });
      _persistActiveSession(_index, clearInputCheckpoint: true);
    }
  }

  void _restoreInputCheckpoint(StudyInputCheckpoint checkpoint) {
    final remaining = [..._item.sentenceTokens];
    final ordered = <String>[];
    for (final token in checkpoint.orderedTokens) {
      final tokenIndex = remaining.indexOf(token);
      if (tokenIndex < 0) continue;
      ordered.add(remaining.removeAt(tokenIndex));
    }
    setState(() {
      _answerController.value = TextEditingValue(
        text: checkpoint.answerText,
        selection: TextSelection.collapsed(
          offset: checkpoint.answerText.length,
        ),
      );
      _selectedChoice = checkpoint.selectedChoice;
      _orderedTokens = ordered;
      _remainingTokens = remaining;
      _questionPresentedAt = _now;
    });
  }

  String _checkpointSummary(StudyInputCheckpoint checkpoint) {
    if (checkpoint.orderedTokens.isNotEmpty) {
      return '배열한 토큰 ${checkpoint.orderedTokens.length}개가 남아 있습니다.';
    }
    if (checkpoint.answerText.isNotEmpty) {
      return '입력한 답안 ${checkpoint.answerText.runes.length}글자가 남아 있습니다.';
    }
    return '선택 중이던 답안이 남아 있습니다.';
  }

  String _relativeCheckpointTime(DateTime savedAt) {
    final elapsed = _now.toUtc().difference(savedAt.toUtc());
    if (elapsed.inMinutes < 1) return '방금';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}분 전';
    if (elapsed.inDays < 1) return '${elapsed.inHours}시간 전';
    return '${elapsed.inDays}일 전';
  }

  void _scheduleBreakReminder() {
    _breakReminderTimer?.cancel();
    if (_completed || _queue.isEmpty || _breakDialogOpen) return;
    final interval = _runtimeOptions.breakReminderMinutes;
    if (interval > 0 && _breakRemindersShown == 0) {
      final elapsedMinutes = _now
          .toUtc()
          .difference(_sessionStartedAt.toUtc())
          .inMinutes;
      if (elapsedMinutes >= interval) {
        _breakRemindersShown = max(0, elapsedMinutes ~/ interval - 1);
      }
    }
    final delay = StudyBreakSchedule(interval).delayUntilNext(
      startedAt: _sessionStartedAt,
      now: _now,
      remindersShown: _breakRemindersShown,
    );
    if (delay == null) return;
    _breakReminderTimer = Timer(delay, () {
      if (mounted) unawaited(_showBreakReminder());
    });
  }

  Future<void> _showBreakReminder() async {
    if (!mounted || _breakDialogOpen || _completed) return;
    _draftCheckpointTimer?.cancel();
    final checkpoint = _currentInputCheckpoint();
    _persistActiveSession(
      _index,
      inputCheckpoint: checkpoint,
      clearInputCheckpoint: checkpoint == null,
    );
    _breakDialogOpen = true;
    _breakRemindersShown++;
    final pause = await showFocusRestoringDialog<bool>(
      context: context,
      fallbackFocus: _preferredQuestionFocus,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const Key('study-break-reminder-dialog'),
        icon: const Icon(Icons.self_improvement_rounded),
        title: const Text('잠깐 쉬어 갈까요?'),
        content: Text(
          '${_runtimeOptions.breakReminderMinutes}분 동안 집중했어요. '
          '현재 답안은 저장되어 있으니 편하게 쉬어도 돼요.',
        ),
        actions: [
          TextButton(
            key: const Key('continue-after-break-reminder'),
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('계속 학습'),
          ),
          FilledButton.icon(
            key: const Key('pause-after-break-reminder'),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.pause_rounded),
            label: const Text('저장하고 쉬기'),
          ),
        ],
      ),
    );
    _breakDialogOpen = false;
    if (!mounted) return;
    if (pause == true) {
      _pauseAndExit();
    } else {
      _scheduleBreakReminder();
    }
  }

  Future<void> _showQueuePreview() async {
    if (_queue.isEmpty) return;
    final fromIndex = _correct == null ? _index : _index + 1;
    final safeIndex = fromIndex.clamp(0, _queue.length);
    final state = ref.read(appControllerProvider);
    final recommendation = _adaptiveEngine.recommend(
      items: _queue.sublist(safeIndex),
      mode: widget.mode,
      strategy: _runtimeOptions.strategy,
      progress: state.progress,
      attemptHistory: _attemptHistory,
      now: _now,
    );
    final preview = StudyQueuePreview.fromRecommendation(recommendation);
    await showFocusRestoringBottomSheet<void>(
      context: context,
      fallbackFocus: _preferredQuestionFocus,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _StudyQueuePreviewSheet(
        preview: preview,
        strategy: _runtimeOptions.strategy,
      ),
    );
  }

  List<String> _choices() {
    final controller = ref.read(appControllerProvider.notifier);
    final candidates = controller.selectedItems;
    final effectiveChoiceCount = _liveDifficulty.choiceCountFor(_choiceCount);
    if (_mode == _ExerciseMode.listeningDiscrimination) {
      return _listeningDiscriminationQuestion(
        choiceCount: effectiveChoiceCount,
      ).choices;
    }
    if (_mode == _ExerciseMode.cloze) {
      return _applyChoiceOrder(
        _choiceBuilder.clozeChoices(
          target: _item,
          answer: _clozeAnswer,
          candidates: candidates,
          count: effectiveChoiceCount,
        ),
      );
    }
    if (_recognitionIsReversed) {
      return _reverseRecognitionChoices(
        candidates,
        choiceCount: effectiveChoiceCount,
      );
    }
    return _applyChoiceOrder(
      _choiceBuilder.recognitionChoices(
        target: _item,
        candidates: candidates,
        count: effectiveChoiceCount,
      ),
    );
  }

  ListeningDiscriminationQuestion _listeningDiscriminationQuestion({
    int? choiceCount,
  }) => _listeningDiscriminationBuilder.build(
    target: _item,
    candidates: ref.read(appControllerProvider.notifier).selectedItems,
    choiceCount: choiceCount ?? _liveDifficulty.choiceCountFor(_choiceCount),
  );

  List<String> _reverseRecognitionChoices(
    Iterable<LearningItem> candidates, {
    required int choiceCount,
  }) {
    final alternatives =
        candidates
            .where(
              (candidate) =>
                  candidate.id != _item.id &&
                  candidate.learningLanguage == _item.learningLanguage &&
                  candidate.kind == _item.kind &&
                  candidate.text.trim().isNotEmpty,
            )
            .toList()
          ..sort((left, right) => left.id.compareTo(right.id));
    final byNormalized = <String, String>{
      _normalizedChoice(_item.text): _item.text,
    };
    for (final candidate in alternatives) {
      if (byNormalized.length >= choiceCount) break;
      byNormalized.putIfAbsent(
        _normalizedChoice(candidate.text),
        () => candidate.text,
      );
    }
    final choices = byNormalized.values.toList(growable: false);
    if (_interaction.shuffleChoices) {
      return [...choices]..sort(
        (left, right) => _stableSeed(
          '${_item.id}|choice|$left',
        ).compareTo(_stableSeed('${_item.id}|choice|$right')),
      );
    }
    return choices;
  }

  List<String> _applyChoiceOrder(List<String> choices) {
    if (_interaction.shuffleChoices) return choices;
    final answer = _expectedAnswer;
    final normalizedAnswer = _normalizedChoice(answer);
    return [
      answer,
      for (final choice in choices)
        if (_normalizedChoice(choice) != normalizedAnswer) choice,
    ];
  }

  QuizHintMode get _quizHintMode => switch (_mode) {
    _ExerciseMode.recognition => QuizHintMode.recognition,
    _ExerciseMode.production => QuizHintMode.production,
    _ExerciseMode.cloze => QuizHintMode.cloze,
    _ExerciseMode.sentenceOrder => QuizHintMode.sentenceOrder,
    _ExerciseMode.listening => QuizHintMode.listening,
    _ExerciseMode.listeningDiscrimination => QuizHintMode.listening,
  };

  String get _hintText {
    final generated = _hintBuilder.build(
      item: _item,
      mode: _quizHintMode,
      level: _hintLevel,
      clozeAnswer: _mode == _ExerciseMode.cloze ? _clozeAnswer : null,
      orderedTokenCount: _orderedTokens.length,
      readingAidsLabel: _item.readingAidsLabelFor(
        showKoreanReading: _interaction.showKoreanReading,
        showNativeReading: _interaction.showNativeReading,
      ),
    );
    final memoryHint = _correctionFor(_item.id, _memoryHintField);
    final value = memoryHint?.proposedValue?.trim();
    if (value == null || value.isEmpty) return generated;
    return '$generated\n내 암기 단서: $value';
  }

  ContentCorrection? _correctionFor(String itemId, String field) {
    final corrections = ref
        .read(appControllerProvider)
        .preferences
        .contentCorrections;
    ContentCorrection? latest;
    for (final correction in corrections) {
      if (correction.itemId != itemId ||
          correction.field != field ||
          correction.resolved) {
        continue;
      }
      if (latest == null || correction.updatedAt.isAfter(latest.updatedAt)) {
        latest = correction;
      }
    }
    return latest;
  }

  void _showHint() {
    if (!_hintsEnabled || _correct != null || _hintLevel >= 2) return;
    setState(() => _hintLevel++);
  }

  void _resetOrderedTokens() {
    if (_correct != null || _mode != _ExerciseMode.sentenceOrder) return;
    setState(() {
      _orderedTokens = [];
      _remainingTokens = [..._item.sentenceTokens]
        ..shuffle(Random(_stableSeed(_item.id)));
    });
    _scheduleDraftCheckpoint();
  }

  void _selectChoiceAt(int index) {
    if (_correct != null || !_isChoiceMode) return;
    final choices = _choices();
    if (index >= choices.length) return;
    _selectChoice(choices[index]);
  }

  void _moveChoiceSelection(int delta) {
    if (_correct != null || !_isChoiceMode) return;
    final choices = _choices();
    if (choices.isEmpty) return;
    final currentIndex = _selectedChoice == null
        ? (delta > 0 ? -1 : 0)
        : choices.indexOf(_selectedChoice!);
    final nextIndex = (currentIndex + delta) % choices.length;
    _selectChoice(choices[nextIndex]);
  }

  void _selectChoice(String choice) {
    if (_correct != null || _selectedChoice == choice) return;
    setState(() => _selectedChoice = choice);
    _scheduleDraftCheckpoint();
    unawaited(_feedbackService.selection());
  }

  void _appendTokenFromShortcut(int index) {
    if (_mode != _ExerciseMode.sentenceOrder) return;
    _appendToken(index);
  }

  void _removeLastOrderedToken() {
    if (_mode != _ExerciseMode.sentenceOrder || _orderedTokens.isEmpty) return;
    _removeOrderedToken(_orderedTokens.length - 1);
  }

  void _appendToken(int index) {
    if (_correct != null || index >= _remainingTokens.length) return;
    setState(() {
      _orderedTokens.add(_remainingTokens.removeAt(index));
    });
    _scheduleDraftCheckpoint();
    unawaited(_feedbackService.selection());
  }

  void _removeOrderedToken(int index) {
    if (_correct != null || index >= _orderedTokens.length) return;
    setState(() {
      _remainingTokens.add(_orderedTokens.removeAt(index));
    });
    _scheduleDraftCheckpoint();
  }

  void _submit() {
    if (_correct != null) {
      _next();
      return;
    }

    final answer = switch (_mode) {
      _ExerciseMode.recognition || _ExerciseMode.cloze => _selectedChoice ?? '',
      _ExerciseMode.production ||
      _ExerciseMode.listening => _answerController.text,
      _ExerciseMode.listeningDiscrimination => _selectedChoice ?? '',
      _ExerciseMode.sentenceOrder => _joinTokens(
        _orderedTokens,
        _item.learningLanguage,
      ),
    };
    if (answer.trim().isEmpty) {
      if (_mode == _ExerciseMode.production ||
          _mode == _ExerciseMode.listening) {
        _answerFocus.requestFocus();
      }
      return;
    }
    _recordResponse(answer);
  }

  void _submitDontKnow() {
    if (_correct != null) return;
    _recordResponse('', forceWrong: true);
  }

  StudySkill get _currentStudySkill => switch (_mode) {
    _ExerciseMode.recognition => StudySkill.meaning,
    _ExerciseMode.production => StudySkill.writing,
    _ExerciseMode.cloze || _ExerciseMode.sentenceOrder => StudySkill.sentence,
    _ExerciseMode.listening =>
      widget.mode == StudyMode.pronunciation
          ? StudySkill.pronunciation
          : StudySkill.listening,
    _ExerciseMode.listeningDiscrimination => StudySkill.listening,
  };

  void _recordResponse(String answer, {bool forceWrong = false}) {
    final accepted = switch (_mode) {
      _ExerciseMode.recognition when _recognitionIsReversed => <String>[
        _item.text,
      ],
      _ExerciseMode.recognition => _item.acceptedAnswers,
      _ExerciseMode.production => <String>[_item.text],
      _ExerciseMode.cloze => <String>[_clozeAnswer],
      _ExerciseMode.sentenceOrder => <String>[_item.text],
      _ExerciseMode.listening => <String>[_item.text],
      _ExerciseMode.listeningDiscrimination => <String>[_item.text],
    };
    final correct =
        !forceWrong &&
        _normalizer.matches(
          input: answer,
          acceptedAnswers: accepted,
          language:
              _mode == _ExerciseMode.recognition && !_recognitionIsReversed
              ? LanguageTag.korean
              : _item.learningLanguage,
          policy: _gradingStrength.answerPolicy(
            typedResponse: _isTextInputMode,
          ),
        );
    final rating = correct
        ? _hintLevel > 0
              ? ReviewRating.hard
              : ReviewRating.good
        : ReviewRating.again;
    final attempt = QuizAttemptReview(
      sequence: _attemptReviews.length + 1,
      itemId: _item.id,
      prompt: _prompt,
      expectedAnswer: _expectedAnswer,
      userAnswer: answer,
      exerciseType: forceWrong ? '${_mode.name}:gaveUp' : _mode.name,
      correct: correct,
      rating: rating,
      usedHint: _hintLevel > 0,
    );
    final responseTimeMs = _now
        .difference(_questionPresentedAt ?? _now)
        .inMilliseconds
        .clamp(0, 30 * 60 * 1000);
    final metric = StudyAttemptMetric(
      itemId: _item.id,
      skill: _currentStudySkill,
      errorType: studyErrorTypeFor(
        skill: _currentStudySkill,
        correct: correct,
        gaveUp: forceWrong,
        responseTimeMs: responseTimeMs,
      ),
      correct: correct,
      responseTimeMs: responseTimeMs,
      recordedAt: _now,
      usedHint: _hintLevel > 0,
    );
    final pending = _PendingQuizResponse(
      item: _item,
      originalAttempt: attempt,
      currentAttempt: attempt,
      previousCombo: _combo,
      previousBestCombo: _bestCombo,
      previousFailureCount: _failureCountByItemId[_item.id] ?? 0,
      wasWrong: _wrongItemIds.contains(_item.id),
      wasFinalCorrect: _finalCorrectItemIds.contains(_item.id),
      metric: metric,
    );
    setState(() {
      _pendingResponse = pending;
      _applyPendingOutcome(pending);
      _submittedAnswer = answer;
      if (!widget.examMode) _correct = correct;
    });
    if (widget.examMode) {
      _commitPendingResponse();
      _next();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _correct != null) _feedbackFocus.requestFocus();
    });
    unawaited(correct ? _feedbackService.success() : _feedbackService.error());
    if (_interaction.autoPlayAnswerAudio) {
      unawaited(_speak());
    }
    if (correct &&
        _autoAdvanceEnabled &&
        _inputProfile.allowsAutomaticAdvance &&
        _allowsAutomaticTransition) {
      _scheduleAutoAdvance();
    }
  }

  void _applyPendingOutcome(_PendingQuizResponse pending) {
    final attempt = pending.currentAttempt;
    final earnedXp = _recordProgress ? attempt.earnedXp : 0;
    if (attempt.correct) {
      _sessionCorrect++;
      _sessionXp += earnedXp;
      _combo = pending.previousCombo + 1;
      _bestCombo = max(pending.previousBestCombo, _combo);
      _finalCorrectItemIds.add(pending.item.id);
      _failureCountByItemId[pending.item.id] = pending.previousFailureCount;
      return;
    }

    _sessionWrong++;
    _sessionXp += earnedXp;
    _combo = 0;
    _bestCombo = pending.previousBestCombo;
    _wrongItemIds.add(pending.item.id);
    _finalCorrectItemIds.remove(pending.item.id);
    _failureCountByItemId[pending.item.id] = pending.previousFailureCount + 1;
    if (!widget.examMode &&
        _queue.where((candidate) => candidate.id == pending.item.id).length <
            3) {
      _queue.add(pending.item);
      pending.retryAppended = true;
    }
  }

  void _updateLiveDifficulty(StudyAttemptMetric metric) {
    _liveDifficultyAttempts.add(
      LiveDifficultyAttempt(
        correct: metric.correct,
        responseTime: metric.responseTime,
        usedHint: metric.usedHint,
      ),
    );
    if (_liveDifficultyAttempts.length > 20) {
      _liveDifficultyAttempts.removeRange(
        0,
        _liveDifficultyAttempts.length - 20,
      );
    }
    final decision = _liveDifficultyEngine.decide(
      attempts: _liveDifficultyAttempts,
      manualLock: _liveDifficultyLock,
    );
    _liveDifficulty = decision.level;
    _liveDifficultyReason = decision.reason;
  }

  void _restorePendingBaseline(_PendingQuizResponse pending) {
    final attempt = pending.currentAttempt;
    if (attempt.correct) {
      _sessionCorrect--;
    } else {
      _sessionWrong--;
    }
    if (_recordProgress) _sessionXp -= attempt.earnedXp;
    _combo = pending.previousCombo;
    _bestCombo = pending.previousBestCombo;
    if (pending.wasWrong) {
      _wrongItemIds.add(pending.item.id);
    } else {
      _wrongItemIds.remove(pending.item.id);
    }
    if (pending.wasFinalCorrect) {
      _finalCorrectItemIds.add(pending.item.id);
    } else {
      _finalCorrectItemIds.remove(pending.item.id);
    }
    _failureCountByItemId[pending.item.id] = pending.previousFailureCount;
    if (pending.retryAppended) {
      final retryIndex = _queue.lastIndexWhere(
        (candidate) => candidate.id == pending.item.id,
      );
      if (retryIndex > _index) _queue.removeAt(retryIndex);
      pending.retryAppended = false;
    }
  }

  void _replacePendingOutcome({
    required bool correct,
    required ReviewRating rating,
    required String correctionLabel,
  }) {
    final pending = _pendingResponse;
    if (pending == null) return;
    _autoAdvanceTimer?.cancel();
    setState(() {
      _restorePendingBaseline(pending);
      pending.currentAttempt = pending.currentAttempt.copyWith(
        correct: correct,
        rating: rating,
        correctionLabel: correctionLabel,
      );
      _applyPendingOutcome(pending);
      _correct = correct;
    });
  }

  void _restoreOriginalOutcome() {
    final pending = _pendingResponse;
    if (pending == null || pending.currentAttempt.correctionLabel == null) {
      return;
    }
    _autoAdvanceTimer?.cancel();
    setState(() {
      _restorePendingBaseline(pending);
      pending.currentAttempt = pending.originalAttempt;
      _applyPendingOutcome(pending);
      _correct = pending.currentAttempt.correct;
    });
    if (_correct == true &&
        _autoAdvanceEnabled &&
        _inputProfile.allowsAutomaticAdvance &&
        _allowsAutomaticTransition) {
      _scheduleAutoAdvance();
    }
  }

  void _applyShortcutRating(ReviewRating rating) {
    if (_pendingResponse == null) return;
    _replacePendingOutcome(
      correct: rating != ReviewRating.again,
      rating: rating,
      correctionLabel: switch (rating) {
        ReviewRating.again => '단축키 · 다시',
        ReviewRating.hard => '단축키 · 어려움',
        ReviewRating.good => '단축키 · 좋음',
        ReviewRating.easy => '단축키 · 쉬움',
      },
    );
  }

  void _commitPendingResponse() {
    final pending = _pendingResponse;
    if (pending == null) return;
    final attempt = pending.currentAttempt;
    final metric = pending.metric.copyWithOutcome(
      correct: attempt.correct,
      errorType: studyErrorTypeFor(
        skill: pending.metric.skill,
        correct: attempt.correct,
        gaveUp: attempt.exerciseType.endsWith(':gaveUp'),
        responseTimeMs: pending.metric.responseTimeMs,
      ),
    );
    if (_recordProgress) {
      ref
          .read(appControllerProvider.notifier)
          .recordAnswer(
            item: pending.item,
            correct: attempt.correct,
            studiedAt: _now,
            exerciseType: attempt.correctionLabel == null
                ? attempt.exerciseType
                : '${attempt.exerciseType}:corrected',
            rating: attempt.rating,
          );
    }
    _attemptReviews.add(attempt);
    if (_attemptMetrics.length < 300) _attemptMetrics.add(metric);
    if (!widget.examMode) _updateLiveDifficulty(metric);
    _pendingResponse = null;
    final nextIndex = (_index + 1).clamp(0, _queue.length);
    if (!widget.examMode && nextIndex < _queue.length) {
      _refreshQueueRecommendation(fromIndex: nextIndex, reorder: true);
    }
    _persistActiveSession(nextIndex, clearInputCheckpoint: true);
  }

  void _deferCurrentQuestion() {
    if (_correct != null || _index + 1 >= _queue.length) return;
    _autoAdvanceTimer?.cancel();
    _speechGeneration++;
    unawaited(_baseTtsService.stop());
    setState(() {
      final deferred = _queue.removeAt(_index);
      _queue.add(deferred);
      _correct = null;
      _prepareExercise();
    });
    _persistActiveSession(_index, clearInputCheckpoint: true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        content: Text('이 문제는 감점 없이 뒤로 미뤘어요.'),
      ),
    );
  }

  void _next() {
    _autoAdvanceTimer?.cancel();
    _speechGeneration++;
    unawaited(_baseTtsService.stop());
    _commitPendingResponse();
    if (_index + 1 >= _queue.length) {
      _examTimer?.cancel();
      ref
          .read(appControllerProvider.notifier)
          .clearActiveStudySession(expectedSessionId: _sessionId);
      unawaited(_saveSession());
      final connected = ref.read(appControllerProvider).driveConnected;
      if (connected) {
        unawaited(
          ref.read(connectionControllerProvider.notifier).syncAutomatically(),
        );
      }
      _recordPracticeChallengeResult();
      setState(() => _completed = true);
      return;
    }
    setState(() {
      _index++;
      _correct = null;
      _prepareExercise();
    });
    _persistActiveSession(_index);
    if (_mode == _ExerciseMode.production) {
      _answerFocus.requestFocus();
    } else if (_mode == _ExerciseMode.listening ||
        _mode == _ExerciseMode.listeningDiscrimination) {
      unawaited(_speak());
    }
  }

  void _scheduleAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    final questionIndex = _index;
    final motionLevel = ref
        .read(appControllerProvider)
        .preferences
        .experience
        .motionLevel;
    final configuredDelay = _interaction.autoAdvanceDelayMs.clamp(300, 3000);
    final delay =
        configuredDelay + (motionLevel == AppMotionLevel.reduced ? 250 : 0);
    _autoAdvanceTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted || _correct != true || _index != questionIndex) return;
      _next();
    });
  }

  Future<void> _saveSession() async {
    _commitPendingResponse();
    if (_sessionSaved || _sessionCorrect + _sessionWrong == 0) return;
    _sessionSaved = true;
    _saveAnnouncement = '학습 결과를 저장하고 있어요.';
    await ref
        .read(appControllerProvider.notifier)
        .finishSession(
          StudySessionSummary(
            sessionId: _sessionId,
            courseId: _activeSession.courseId,
            startedAt: _sessionStartedAt,
            endedAt: _now,
            correctCount: _sessionCorrect,
            wrongCount: _sessionWrong,
            earnedXp: _sessionXp,
            origin: _activeSession.origin,
            rootSessionId: _activeSession.lineageRootId,
            parentSessionId: _activeSession.parentSessionId,
            generation: _activeSession.generation,
            pauseCount: _activeSession.pauseCount,
            resumeCount: _activeSession.resumeCount,
            journey: _activeSession.journey,
            itemIds: _orderedUnique(
              _activeSession.originalItemIds.isEmpty
                  ? _queue.map((item) => item.id)
                  : _activeSession.originalItemIds,
            ),
            wrongItemIds: Set.unmodifiable(_wrongItemIds),
            finalCorrectItemIds: Set.unmodifiable(_finalCorrectItemIds),
            mode: widget.mode,
            historyFilter: widget.historyFilter,
            recordProgress: _recordProgress,
            backlogRecovery: _backlogRecovery,
            attemptMetrics: List.unmodifiable(_attemptMetrics),
          ),
        );
    if (!mounted) return;
    setState(() {
      _sessionSavedAt = _now.toUtc();
      _saveAnnouncement = '학습 결과를 저장했어요.';
    });
    SemanticsService.sendAnnouncement(
      View.of(context),
      _saveAnnouncement,
      Directionality.of(context),
    );
  }

  void _recordPracticeChallengeResult() {
    if (_practiceResultSaved) return;
    final activityId = widget.practiceActivityId;
    if (activityId == null || activityId.trim().isEmpty) return;
    final attempts = _sessionCorrect + _sessionWrong;
    if (attempts == 0) return;
    _practiceResultSaved = true;
    final state = ref.read(appControllerProvider);
    final interaction = state.preferences.interaction;
    final launch = interaction.practiceCatalog.launchFor(activityId);
    var catalog = interaction.practiceCatalog.recordDailyQuestCompletion(
      activityId: activityId,
      subjectId: state.activeSubjectId,
      completedAt: _now,
    );
    if (launch.challengeScoringEnabled) {
      final elapsedMs = max(
        1,
        _now.difference(_sessionStartedAt).inMilliseconds,
      );
      final challengeScore = PracticeChallengeScore.calculate(
        correctCount: _sessionCorrect,
        wrongCount: _sessionWrong,
        elapsed: Duration(milliseconds: elapsedMs),
        attemptMetrics: _attemptMetrics,
      );
      _challengeScore = challengeScore;
      catalog = catalog.recordBest(
        activityId,
        score: challengeScore.total,
        elapsedMs: elapsedMs,
        at: _now,
      );
    }
    ref
        .read(appControllerProvider.notifier)
        .updateInteractionPreferences(
          interaction.copyWith(practiceCatalog: catalog),
        );
  }

  void _openNextPlaylistGame() {
    final nextIndex = widget.playlistIndex + 1;
    if (widget.playlistActivityIds.length < 2 ||
        nextIndex >= widget.playlistActivityIds.length) {
      context.go('/learn');
      return;
    }
    final ids = widget.playlistActivityIds
        .where(isPlaylistCompatiblePracticeActivity)
        .take(5)
        .toList(growable: false);
    if (nextIndex >= ids.length) {
      context.go('/learn');
      return;
    }
    context.go(
      '/learn?playlist=${Uri.encodeQueryComponent(ids.join(','))}'
      '&playlistIndex=$nextIndex',
    );
  }

  void _pauseAndExit() {
    if (widget.examMode) {
      unawaited(_confirmExamSubmission());
      return;
    }
    _draftCheckpointTimer?.cancel();
    final inputCheckpoint = _currentInputCheckpoint();
    _commitPendingResponse();
    final nextIndex = _correct == null ? _index : _index + 1;
    final paused = ref
        .read(appControllerProvider.notifier)
        .pauseActiveStudySession(
          _now,
          itemIds: _queue.map((item) => item.id).toList(growable: false),
          currentIndex: nextIndex.clamp(0, _queue.length),
          correctCount: _sessionCorrect,
          wrongCount: _sessionWrong,
          earnedXp: _sessionXp,
          wrongItemIds: _wrongItemIds,
          finalCorrectItemIds: _finalCorrectItemIds,
          runtimeOptions: _runtimeOptions,
          inputCheckpoint: inputCheckpoint,
          clearInputCheckpoint: inputCheckpoint == null,
          attemptMetrics: _attemptMetrics,
          attemptReviews: _attemptReviews,
          expectedSessionId: _sessionId,
        );
    if (paused != null) _activeSession = paused;
    if (ref.read(appControllerProvider).driveConnected) {
      unawaited(
        ref.read(connectionControllerProvider.notifier).syncAutomatically(),
      );
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _persistActiveSession(
    int currentIndex, {
    StudyInputCheckpoint? inputCheckpoint,
    bool clearInputCheckpoint = false,
  }) {
    if (_queue.isEmpty || _completed) return;
    final next = ref
        .read(appControllerProvider.notifier)
        .updateActiveStudySession(
          itemIds: _queue.map((item) => item.id).toList(growable: false),
          currentIndex: currentIndex,
          correctCount: _sessionCorrect,
          wrongCount: _sessionWrong,
          earnedXp: _sessionXp,
          wrongItemIds: _wrongItemIds,
          finalCorrectItemIds: _finalCorrectItemIds,
          runtimeOptions: _runtimeOptions,
          inputCheckpoint: inputCheckpoint,
          clearInputCheckpoint: clearInputCheckpoint,
          attemptMetrics: _attemptMetrics,
          attemptReviews: _attemptReviews,
          updatedAt: _now,
          expectedSessionId: _sessionId,
        );
    if (next != null) _activeSession = next;
  }

  Future<void> _retryMistakes() async {
    final unresolvedWrongIds = _wrongItemIds.difference(_finalCorrectItemIds);
    final mistakeIds = _orderedUnique([
      for (final item in _queue)
        if (unresolvedWrongIds.contains(item.id)) item.id,
    ]);
    if (mistakeIds.isEmpty) return;
    await _deriveSession(StudySessionOrigin.wrongAnswers, mistakeIds);
  }

  Future<void> _replayCompletedSession({required bool shuffle}) async {
    final ids = _orderedUnique(
      _activeSession.originalItemIds.isEmpty
          ? _queue.map((item) => item.id)
          : _activeSession.originalItemIds,
    ).toList(growable: true);
    if (shuffle) {
      ids.shuffle(Random(_now.microsecondsSinceEpoch));
    }
    await _deriveSession(StudySessionOrigin.restarted, ids);
  }

  void _openNextRecommendation() {
    final controller = ref.read(appControllerProvider.notifier);
    if (!controller.activeSubject.isLanguage) {
      context.go('/learn');
      return;
    }
    final recommended = controller.coursePath.recommendedUnit;
    context.go(courseLessonRoute(recommended.nextLesson, recommended.index));
  }

  Future<void> _deriveSession(
    StudySessionOrigin origin,
    List<String> itemIds,
  ) async {
    final uniqueItemIds = _orderedUnique(itemIds);
    if (uniqueItemIds.isEmpty) return;
    final byId = {
      for (final item in ref.read(appControllerProvider.notifier).courseItems)
        item.id: item,
    };
    final nextQueue = uniqueItemIds
        .map((id) => byId[id])
        .whereType<LearningItem>()
        .toList(growable: true);
    if (nextQueue.isEmpty) return;
    await _saveSession();
    if (!mounted) return;
    final startedAt = _now;
    final newSessionId = _newSessionId();
    final next = ref
        .read(appControllerProvider.notifier)
        .deriveActiveStudySession(
          source: _activeSession,
          sessionId: newSessionId,
          origin: origin,
          itemIds: nextQueue.map((item) => item.id).toList(growable: false),
          startedAt: startedAt,
        );
    setState(() {
      _activeSession = next;
      _queue = nextQueue;
      _plannedCount = _queue.length;
      _index = 0;
      _sessionCorrect = 0;
      _sessionWrong = 0;
      _sessionXp = 0;
      _combo = 0;
      _bestCombo = 0;
      _completed = false;
      _correct = null;
      _wrongItemIds.clear();
      _finalCorrectItemIds.clear();
      _failureCountByItemId.clear();
      _attemptMetrics.clear();
      _attemptReviews.clear();
      _liveDifficultyAttempts.clear();
      final resetDifficulty = _liveDifficultyEngine.decide(
        attempts: const [],
        manualLock: _liveDifficultyLock,
      );
      _liveDifficulty = resetDifficulty.level;
      _liveDifficultyReason = resetDifficulty.reason;
      _adaptiveReasonByItemId.clear();
      _adaptiveSkillByItemId.clear();
      _sessionStartedAt = startedAt;
      _sessionId = newSessionId;
      _sessionSaved = false;
      _sessionSavedAt = null;
      _saveAnnouncement = '';
      _practiceResultSaved = false;
      _challengeScore = null;
      _refreshQueueRecommendation(fromIndex: 0, reorder: true);
      _prepareExercise();
    });
    _persistActiveSession(0, clearInputCheckpoint: true);
    _breakRemindersShown = 0;
    _scheduleBreakReminder();
    if (_mode == _ExerciseMode.listening ||
        _mode == _ExerciseMode.listeningDiscrimination) {
      unawaited(_speak());
    }
  }

  Future<void> _finishCurrentSession() async {
    _commitPendingResponse();
    final nextIndex = _correct == null ? _index : _index + 1;
    _persistActiveSession(nextIndex.clamp(0, _queue.length));
    await _saveSession();
    if (!mounted) return;
    ref
        .read(appControllerProvider.notifier)
        .clearActiveStudySession(expectedSessionId: _sessionId);
    if (ref.read(appControllerProvider).driveConnected) {
      unawaited(
        ref.read(connectionControllerProvider.notifier).syncAutomatically(),
      );
    }
    context.go('/home');
  }

  Future<void> _showSessionOptions() async {
    if (_correct != null) return;
    final draftBeforeOptions = _currentInputCheckpoint();
    final previousDirection = _sessionAnswerDirection;
    final options = await showFocusRestoringBottomSheet<QuizSessionOptions>(
      context: context,
      fallbackFocus: _preferredQuestionFocus,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _SessionQuizOptionsSheet(
        mode: widget.mode,
        initial: QuizSessionOptions(
          answerDirection: _sessionAnswerDirection,
          gradingStrength: _gradingStrength,
          inputProfile: _inputProfile,
          strategy: _runtimeOptions.strategy,
          breakReminderMinutes: _runtimeOptions.breakReminderMinutes,
          showKoreanReading: _runtimeOptions.showKoreanReading,
          showNativeReading: _runtimeOptions.showNativeReading,
          ttsRate: _runtimeOptions.ttsRate,
          liveDifficultyLock: _liveDifficultyLock,
        ),
      ),
    );
    if (!mounted || options == null) return;
    final requestedDirection = widget.mode.allowsAnswerDirectionOverride
        ? options.answerDirection
        : widget.mode.effectiveFixedAnswerDirection;
    final preserveDraftDirection =
        draftBeforeOptions != null && requestedDirection != previousDirection;
    setState(() {
      _sessionAnswerDirection = preserveDraftDirection
          ? previousDirection
          : requestedDirection;
      _gradingStrength = options.gradingStrength;
      _inputProfile = options.inputProfile;
      _liveDifficultyLock = options.liveDifficultyLock;
      final difficulty = _liveDifficultyEngine.decide(
        attempts: _liveDifficultyAttempts,
        manualLock: _liveDifficultyLock,
      );
      _liveDifficulty = difficulty.level;
      _liveDifficultyReason = difficulty.reason;
      final selectedRuntime = options.runtimeOptions;
      _runtimeOptions = _runtimeOptions.copyWith(
        strategy: selectedRuntime.strategy,
        breakReminderMinutes: selectedRuntime.breakReminderMinutes,
        showKoreanReading: selectedRuntime.showKoreanReading,
        showNativeReading: selectedRuntime.showNativeReading,
        ttsRate: selectedRuntime.ttsRate,
        liveDifficultyLock: selectedRuntime.liveDifficultyLock,
      );
      _refreshQueueRecommendation(fromIndex: _index, reorder: false);
      if (_index + 1 < _queue.length) {
        _refreshQueueRecommendation(fromIndex: _index + 1, reorder: true);
      }
      if (draftBeforeOptions == null &&
          requestedDirection != previousDirection) {
        _prepareExercise();
      }
    });
    _breakRemindersShown = 0;
    _scheduleBreakReminder();
    _persistActiveSession(
      _index,
      inputCheckpoint: draftBeforeOptions,
      clearInputCheckpoint: draftBeforeOptions == null,
    );
    if (preserveDraftDirection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('작성 중인 답안이 있어 출제 방향은 다음 문제부터 바뀌어요.')),
      );
    }
  }

  Future<void> _showMatchSprint() async {
    final deck = MatchSprintDeck.fromItems(_queue);
    if (!deck.canStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('매치 스프린트에는 서로 다른 표현이 2개 이상 필요해요.')),
      );
      return;
    }
    final result = await showFocusRestoringDialog<_MatchSprintResult>(
      context: context,
      fallbackFocus: _preferredQuestionFocus,
      barrierDismissible: false,
      builder: (context) => _MatchSprintDialog(
        deck: deck,
        allowTimedMode:
            _inputProfile.allowsTimedChallenge &&
            ref.read(accessibilityInputProfileProvider).allowsTimedChallenges,
      ),
    );
    if (!mounted || result == null) return;
    final state = ref.read(appControllerProvider);
    final interaction = state.preferences.interaction;
    final catalog = interaction.practiceCatalog
        .recordBest(
          'match-sprint',
          score: result.score,
          elapsedMs: result.elapsedMs,
          at: _now,
        )
        .recordDailyQuestCompletion(
          activityId: 'match-sprint',
          subjectId: state.activeSubjectId,
          completedAt: _now,
        );
    ref
        .read(appControllerProvider.notifier)
        .updateInteractionPreferences(
          interaction.copyWith(practiceCatalog: catalog),
        );
  }

  Future<void> _showRepairOptions() async {
    final editable =
        ref.read(appControllerProvider.notifier).customItemById(_item.id) !=
        null;
    final hasMemoryHint =
        (_correctionFor(_item.id, _memoryHintField)?.proposedValue?.trim() ??
                '')
            .isNotEmpty;
    final action = await showFocusRestoringBottomSheet<_RepairAction>(
      context: context,
      fallbackFocus: _feedbackFocus,
      showDragHandle: true,
      builder: (context) => _RepairOptionsSheet(
        item: _item,
        editable: editable,
        hasMemoryHint: hasMemoryHint,
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _RepairAction.edit:
        await _editItemSafely(_item);
      case _RepairAction.memoryHint:
        await _editMemoryHint(_item);
      case _RepairAction.exclude:
        final controller = ref.read(appControllerProvider.notifier);
        if (!ref
            .read(appControllerProvider)
            .preferences
            .excludedItemIds
            .contains(_item.id)) {
          controller.toggleItemSelection(_item.id);
        }
        setState(() {
          for (var index = _queue.length - 1; index > _index; index--) {
            if (_queue[index].id == _item.id) _queue.removeAt(index);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이 표현을 다음 학습부터 잠시 제외했어요.')),
        );
      case _RepairAction.continueStudy:
        return;
    }
  }

  Future<void> _editItemSafely(LearningItem item) async {
    final controller = ref.read(appControllerProvider.notifier);
    final custom = controller.customItemById(item.id);
    if (custom == null) {
      await _editBaseContentCorrection(item);
      return;
    }
    final result = await showFocusRestoringDialog<_CustomContentEditResult>(
      context: context,
      fallbackFocus: _feedbackFocus,
      builder: (context) => _CustomContentEditDialog(item: custom),
    );
    if (!mounted || result == null) return;
    final translations = <String>[
      result.answer,
      for (final value in custom.translations.skip(1))
        if (_normalizedChoice(value) != _normalizedChoice(result.answer)) value,
    ];
    final acceptedAnswers = <String>[
      result.answer,
      for (final value in custom.acceptedAnswers)
        if (_normalizedChoice(value) != _normalizedChoice(result.answer)) value,
    ];
    final updated = custom.copyWith(
      text: result.question,
      translations: translations,
      acceptedAnswers: acceptedAnswers,
    );
    try {
      await controller.upsertCustomItem(updated);
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('자료를 저장하지 못했습니다: $error')));
      return;
    }
    if (!mounted) return;
    setState(() {
      for (var index = 0; index < _queue.length; index++) {
        if (_queue[index].id == updated.id) _queue[index] = updated;
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('자료를 수정했어요. 지금 문제부터 이어갑니다.')));
  }

  Future<void> _editBaseContentCorrection(LearningItem item) async {
    final existing = _correctionFor(item.id, _baseContentCorrectionField);
    final result = await showFocusRestoringDialog<_BaseCorrectionEditResult>(
      context: context,
      fallbackFocus: _feedbackFocus,
      builder: (context) =>
          _BaseCorrectionEditDialog(item: item, existing: existing),
    );
    if (!mounted || result == null) return;
    await ref
        .read(appControllerProvider.notifier)
        .upsertContentCorrection(
          ContentCorrection(
            itemId: item.id,
            field: _baseContentCorrectionField,
            note: result.note,
            proposedValue: result.proposedValue,
            updatedAt: _now,
          ),
        );
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('원본은 그대로 두고 내 교정 메모에 저장했어요.')));
  }

  Future<void> _editMemoryHint(LearningItem item) async {
    final existing = _correctionFor(item.id, _memoryHintField);
    final result = await showFocusRestoringDialog<_MemoryHintEditResult>(
      context: context,
      fallbackFocus: _feedbackFocus,
      builder: (context) => _MemoryHintDialog(
        item: item,
        initialHint: existing?.proposedValue ?? '',
      ),
    );
    if (!mounted || result == null) return;
    final controller = ref.read(appControllerProvider.notifier);
    if (result.value.isEmpty) {
      if (existing != null) {
        await controller.deleteContentCorrection(
          itemId: item.id,
          field: _memoryHintField,
        );
      }
    } else {
      await controller.upsertContentCorrection(
        ContentCorrection(
          itemId: item.id,
          field: _memoryHintField,
          note: '사용자 암기 단서',
          proposedValue: result.value,
          updatedAt: _now,
        ),
      );
    }
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.value.isEmpty ? '암기 단서를 지웠습니다.' : '암기 단서를 저장했습니다.',
        ),
      ),
    );
  }

  void _openCurrentItemEditor() {
    unawaited(_editItemSafely(_item));
  }

  void _openQuickAddFromCurrentItem() {
    unawaited(
      showQuickContentSheet(
        context: context,
        initialKind: _item.kind,
        initialText: _item.text,
        initialMeaning: _item.primaryTranslation,
        initialExample: _item.example ?? '',
        initialExampleMeaning: _item.exampleTranslation ?? '',
      ),
    );
  }

  void _openMemoryHintEditor() {
    unawaited(_editMemoryHint(_item));
  }

  void _openReviewItem(String itemId) {
    final controller = ref.read(appControllerProvider.notifier);
    LearningItem? item = controller.customItemById(itemId);
    if (item == null) {
      for (final candidate in _queue) {
        if (candidate.id == itemId) {
          item = candidate;
          break;
        }
      }
    }
    if (item == null) return;
    unawaited(_editItemSafely(item));
  }

  Future<void> _showSessionManager() async {
    final nextIndex = (_correct == null ? _index : _index + 1).clamp(
      0,
      _queue.length,
    );
    final remainingIds = _orderedUnique([
      for (final item in _queue.skip(nextIndex)) item.id,
    ]);
    final wrongIds = _orderedUnique([
      for (final item in _queue)
        if (_wrongItemIds.contains(item.id) &&
            !_finalCorrectItemIds.contains(item.id))
          item.id,
    ]);
    final action =
        await showFocusRestoringBottomSheet<_SessionManagementAction>(
          context: context,
          fallbackFocus: _preferredQuestionFocus,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (context) => _SessionManagementSheet(
            session: _activeSession,
            wrongCount: wrongIds.length,
            remainingCount: remainingIds.length,
            answerDirection: _sessionAnswerDirection,
            gradingStrength: _gradingStrength,
            inputProfile: _inputProfile,
            strategy: _runtimeOptions.strategy,
            keyboardHelpShortcut: ref
                .read(accessibilityInputProfileProvider)
                .globalShortcutFor(GlobalShortcutAction.keyboardHelp)
                .displayLabelFor(defaultTargetPlatform),
            showKeyboardHelp:
                defaultTargetPlatform == TargetPlatform.windows ||
                defaultTargetPlatform == TargetPlatform.macOS ||
                defaultTargetPlatform == TargetPlatform.linux,
            canChangeOptions: _correct == null && !widget.examMode,
            canStartMatch:
                !widget.examMode && MatchSprintDeck.fromItems(_queue).canStart,
            canDeriveSession: !widget.examMode,
          ),
        );
    if (!mounted || action == null) return;
    switch (action) {
      case _SessionManagementAction.options:
        await _showSessionOptions();
      case _SessionManagementAction.preview:
        await _showQueuePreview();
      case _SessionManagementAction.keyboardHelp:
        _openKeyboardHelp();
      case _SessionManagementAction.matchSprint:
        await _showMatchSprint();
      case _SessionManagementAction.restart:
        if (widget.examMode) return;
        await _deriveSession(
          StudySessionOrigin.restarted,
          _activeSession.originalItemIds,
        );
      case _SessionManagementAction.wrongAnswers:
        if (widget.examMode) return;
        await _deriveSession(StudySessionOrigin.wrongAnswers, wrongIds);
      case _SessionManagementAction.remaining:
        if (widget.examMode) return;
        await _deriveSession(StudySessionOrigin.remaining, remainingIds);
      case _SessionManagementAction.finish:
        if (widget.examMode) {
          await _confirmExamSubmission();
        } else {
          await _finishCurrentSession();
        }
    }
  }

  List<String> _orderedUnique(Iterable<String> values) {
    final seen = <String>{};
    return [
      for (final value in values)
        if (seen.add(value)) value,
    ];
  }

  void _openKeyboardHelp() {
    unawaited(
      showKeyboardHelpOverlay(
        context: context,
        profile: ref.read(accessibilityInputProfileProvider),
        helpContext: KeyboardHelpContext.study,
        fallbackFocus: _isTextInputMode ? _answerFocus : _questionFocus,
      ),
    );
  }

  Future<void> _requestSystemBack() async {
    if (widget.examMode) {
      await _confirmExamSubmission();
      return;
    }
    final leave = await showFocusRestoringDialog<bool>(
      context: context,
      fallbackFocus: _isTextInputMode ? _answerFocus : _questionFocus,
      builder: (dialogContext) => AlertDialog(
        title: const Text('학습을 잠시 멈출까요?'),
        content: const Text('현재 문제와 위치를 저장해 둘게요. 홈에서 다시 이어갈 수 있어요.'),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('계속 학습'),
          ),
          FilledButton.tonal(
            key: const Key('confirm-system-back-study'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('저장하고 나가기'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) context.go(_returnRoute);
  }

  @override
  Widget build(BuildContext context) {
    final experience = ref.watch(
      appControllerProvider.select((state) => state.preferences.experience),
    );
    Widget withStudyTextScale(Widget child) {
      final multiplier = switch (experience.studyTextScale) {
        AppStudyTextScale.sameAsApp => 1.0,
        AppStudyTextScale.larger => 1.15,
        AppStudyTextScale.extraLarge => 1.3,
      };
      final scaled = multiplier == 1
          ? child
          : MediaQuery(
              key: const Key('study-text-scale-scope'),
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(
                  (MediaQuery.textScalerOf(context).scale(1) * multiplier)
                      .clamp(0.8, 2.4),
                ),
              ),
              child: child,
            );
      return PopScope(
        canPop: _completed || _queue.isEmpty,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) unawaited(_requestSystemBack());
        },
        child: scaled,
      );
    }

    if (_queue.isEmpty) {
      return withStudyTextScale(
        Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: () => context.go(_returnRoute),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.task_alt_rounded,
                    size: 54,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _isListeningDiscrimination
                        ? '소리 구별에 필요한 표현이 부족해요'
                        : widget.customPlan
                        ? _isPlaylist
                              ? '이 게임에 맞는 표현이 없어요'
                              : '조건에 맞는 표현이 없어요'
                        : widget.mode == StudyMode.favorites
                        ? '아직 저장한 표현이 없어요'
                        : '오늘 학습을 모두 마쳤어요',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isListeningDiscrimination
                        ? '소리를 구별할 표현이 3개 이상 필요해요. 대신 받아쓰기를 시작할 수 있어요.'
                        : widget.customPlan
                        ? _isPlaylist
                              ? '플레이리스트로 돌아가 다른 게임을 이어서 선택해 주세요.'
                              : '세션 설정에서 자료 범위나 난이도 조건을 넓혀 보세요.'
                        : widget.mode == StudyMode.favorites
                        ? '자료실에서 외우고 싶은 표현에 별표를 눌러 주세요.'
                        : '새 자료를 가져오거나 다른 언어 코스를 선택해 보세요.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => context.go(
                      _isListeningDiscrimination
                          ? '/study?mode=listening'
                          : widget.mode == StudyMode.favorites
                          ? '/library'
                          : _returnRoute,
                    ),
                    icon: Icon(
                      _isListeningDiscrimination
                          ? Icons.headphones_rounded
                          : widget.mode == StudyMode.favorites
                          ? Icons.star_border_rounded
                          : Icons.arrow_back_rounded,
                    ),
                    label: Text(
                      _isListeningDiscrimination
                          ? '받아쓰기 열기'
                          : widget.mode == StudyMode.favorites
                          ? '자료실에서 표현 저장'
                          : widget.customPlan
                          ? _isPlaylist
                                ? '플레이리스트로 돌아가기'
                                : '세션 설정으로 돌아가기'
                          : widget.unitIndex == null
                          ? '학습실로 돌아가기'
                          : '코스로 돌아가기',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_completed) {
      final completionState = ref.watch(appControllerProvider);
      final completionConnection = ref.watch(connectionControllerProvider);
      final attempts = _sessionCorrect + _sessionWrong;
      final examReport = widget.examMode
          ? ExamReport.evaluate(
              configuration: _examConfiguration,
              correctCount: _sessionCorrect,
              answeredCount: attempts,
              timedOut: _examTimedOut,
            )
          : null;
      final accuracy =
          examReport?.score ??
          (attempts == 0 ? 0 : (_sessionCorrect / attempts * 100).round());
      final elapsed = max(1, _now.difference(_sessionStartedAt).inMinutes);
      final completionSummary = StudySessionSummary(
        sessionId: _sessionId,
        courseId: _activeSession.courseId,
        startedAt: _sessionStartedAt,
        endedAt: _now,
        correctCount: _sessionCorrect,
        wrongCount: _sessionWrong,
        earnedXp: _sessionXp,
      );
      final recentCourseSessions = ref
          .read(appControllerProvider)
          .recentSessions
          .where((session) => session.courseId == _activeSession.courseId);
      final timeRecommendation = recommendLocalStudyTime([
        completionSummary,
        ...recentCourseSessions,
      ]);
      final receipt = StudyCompletionReceipt.fromState(
        savedAt: _sessionSavedAt,
        earnedXp: _sessionXp,
        streakDays: completionState.streakDays,
        driveConnected: completionState.driveConnected,
        pendingSyncCount:
            completionState.pendingSync != null ||
                completionConnection.pendingChanges
            ? 1
            : 0,
        offlineLocked: completionConnection.policy.offlineLock,
      );
      return withStudyTextScale(
        _CompletionScreen(
          correct: _sessionCorrect,
          wrong: _sessionWrong,
          xp: _sessionXp,
          accuracy: accuracy,
          minutes: elapsed,
          bestCombo: _bestCombo,
          plannedCount: _plannedCount,
          hasMistakes: _wrongItemIds
              .difference(_finalCorrectItemIds)
              .isNotEmpty,
          attempts: List.unmodifiable(_attemptReviews),
          attemptMetrics: List.unmodifiable(_attemptMetrics),
          challengeScore: _challengeScore,
          examReport: examReport,
          saveStatus: _saveAnnouncement.isEmpty
              ? '학습 결과를 저장하고 있어요.'
              : _saveAnnouncement,
          receipt: receipt,
          recordProgress: _recordProgress,
          onRetryMistakes: widget.examMode ? null : _retryMistakes,
          onScheduleNext: () => context.push('/session-builder'),
          timeRecommendation: timeRecommendation,
          onApplyRoutineTime: timeRecommendation == null
              ? null
              : () {
                  final changed = ref
                      .read(appControllerProvider.notifier)
                      .applyRecommendedRoutineTime(
                        timeRecommendation.minuteOfDay,
                        now: _now,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        changed == 0
                            ? '적용할 루틴이 없어요. 먼저 다음 예약에서 루틴을 만들어 주세요.'
                            : '${timeRecommendation.label}을 루틴 $changed개에 적용했어요.',
                      ),
                    ),
                  );
                },
          onReplaySame: widget.examMode
              ? null
              : () => _replayCompletedSession(shuffle: false),
          onReplayShuffled: widget.examMode
              ? null
              : () => _replayCompletedSession(shuffle: true),
          onOpenItem: _openReviewItem,
          onNextPlaylist:
              widget.playlistActivityIds.length >= 2 &&
                  widget.playlistIndex + 1 < widget.playlistActivityIds.length
              ? _openNextPlaylistGame
              : null,
          playlistProgressLabel: widget.playlistActivityIds.length >= 2
              ? '${widget.playlistIndex + 1}/${widget.playlistActivityIds.length} 게임 완료'
              : null,
          onNextRecommended: widget.customPlan ? null : _openNextRecommendation,
          onHome: () => context.go(_returnRoute),
          returnLabel: widget.customPlan
              ? _isPlaylist
                    ? '플레이리스트로 돌아가기'
                    : '세션 설정으로 돌아가기'
              : widget.unitIndex == null
              ? '학습실로 돌아가기'
              : '코스로 돌아가기',
          returnIcon: widget.customPlan
              ? _isPlaylist
                    ? Icons.playlist_play_rounded
                    : Icons.tune_rounded
              : widget.unitIndex == null
              ? Icons.grid_view_rounded
              : Icons.route_rounded,
          celebrationLevel: experience.celebrationLevel,
          encouragementTone: experience.encouragementTone,
        ),
      );
    }

    final readingAidsLabel = _item.readingAidsLabelFor(
      showKoreanReading: _runtimeOptions.showKoreanReading,
      showNativeReading: _runtimeOptions.showNativeReading,
    );
    final accessibilityProfile = ref.watch(accessibilityInputProfileProvider);
    final accessibilityTheme = StudyAccessibilityTheme.of(context);
    final keyboardBindings = <ShortcutActivator, VoidCallback>{
      if (_isTextInputMode)
        const SingleActivator(LogicalKeyboardKey.space, control: true): _speak,
      if (_isTextInputMode)
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _answerFocus.requestFocus(),
      if (_isChoiceMode) ...{
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _moveChoiceSelection(1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _moveChoiceSelection(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _moveChoiceSelection(-1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _moveChoiceSelection(-1),
      },
      if (_isChoiceMode || _mode == _ExerciseMode.sentenceOrder) ...{
        const SingleActivator(LogicalKeyboardKey.digit1): () =>
            _isChoiceMode ? _selectChoiceAt(0) : _appendTokenFromShortcut(0),
        const SingleActivator(LogicalKeyboardKey.digit2): () =>
            _isChoiceMode ? _selectChoiceAt(1) : _appendTokenFromShortcut(1),
        const SingleActivator(LogicalKeyboardKey.digit3): () =>
            _isChoiceMode ? _selectChoiceAt(2) : _appendTokenFromShortcut(2),
        const SingleActivator(LogicalKeyboardKey.digit4): () =>
            _isChoiceMode ? _selectChoiceAt(3) : _appendTokenFromShortcut(3),
        const SingleActivator(LogicalKeyboardKey.numpad1): () =>
            _isChoiceMode ? _selectChoiceAt(0) : _appendTokenFromShortcut(0),
        const SingleActivator(LogicalKeyboardKey.numpad2): () =>
            _isChoiceMode ? _selectChoiceAt(1) : _appendTokenFromShortcut(1),
        const SingleActivator(LogicalKeyboardKey.numpad3): () =>
            _isChoiceMode ? _selectChoiceAt(2) : _appendTokenFromShortcut(2),
        const SingleActivator(LogicalKeyboardKey.numpad4): () =>
            _isChoiceMode ? _selectChoiceAt(3) : _appendTokenFromShortcut(3),
      },
      if (_mode == _ExerciseMode.sentenceOrder) ...{
        const SingleActivator(LogicalKeyboardKey.digit5): () =>
            _appendTokenFromShortcut(4),
        const SingleActivator(LogicalKeyboardKey.digit6): () =>
            _appendTokenFromShortcut(5),
        const SingleActivator(LogicalKeyboardKey.digit7): () =>
            _appendTokenFromShortcut(6),
        const SingleActivator(LogicalKeyboardKey.digit8): () =>
            _appendTokenFromShortcut(7),
        const SingleActivator(LogicalKeyboardKey.digit9): () =>
            _appendTokenFromShortcut(8),
        const SingleActivator(LogicalKeyboardKey.backspace):
            _removeLastOrderedToken,
        const SingleActivator(LogicalKeyboardKey.backspace, control: true):
            _resetOrderedTokens,
      },
    };
    keyboardBindings.addAll(
      accessibilityProfile.bindingsFor({
        StudyShortcutAction.playAudio: _speak,
        StudyShortcutAction.nextItem: _submit,
        StudyShortcutAction.showHint: _showHint,
        StudyShortcutAction.dontKnow: _submitDontKnow,
        if (_index + 1 < _queue.length)
          StudyShortcutAction.skip: _deferCurrentQuestion,
        StudyShortcutAction.pause: _pauseAndExit,
        if (_pendingResponse != null) ...{
          StudyShortcutAction.rateAgain: () =>
              _applyShortcutRating(ReviewRating.again),
          StudyShortcutAction.rateHard: () =>
              _applyShortcutRating(ReviewRating.hard),
          StudyShortcutAction.rateGood: () =>
              _applyShortcutRating(ReviewRating.good),
          StudyShortcutAction.rateEasy: () =>
              _applyShortcutRating(ReviewRating.easy),
        },
      }),
    );
    return withStudyTextScale(
      CallbackShortcuts(
        key: const Key('study-screen'),
        bindings: keyboardBindings,
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                key: const Key('pause-study-session'),
                onPressed: _pauseAndExit,
                icon: Icon(
                  widget.examMode
                      ? Icons.stop_circle_outlined
                      : Icons.pause_rounded,
                ),
                tooltip: widget.examMode
                    ? '시험 제출'
                    : '저장하고 홈으로'
                          '(${accessibilityProfile.shortcutFor(StudyShortcutAction.pause).displayLabel})',
              ),
              titleSpacing: 4,
              title: _CompactStudyHud(
                current: _index + 1,
                total: _queue.length,
                correct: _sessionCorrect,
                wrong: _sessionWrong,
                combo: _combo,
                comboGoal: min(3, _plannedCount),
                xp: _sessionXp,
                showTimer: experience.showStudyTimer,
                hideResults: widget.examMode,
                timeLabelOverride: widget.examMode
                    ? _formatExamRemaining(_examRemainingSeconds)
                    : null,
                showQuestionCounter: experience.showQuestionCounter,
                progressStyle: experience.progressStyle,
              ),
              actions: [
                IconButton(
                  key: const Key('open-session-management'),
                  onPressed: _showSessionManager,
                  icon: const Icon(Icons.more_horiz_rounded),
                  tooltip: '세션 관리',
                ),
              ],
            ),
            body: SafeArea(
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            constraints.maxWidth < 600 ? 16 : 24,
                            12,
                            constraints.maxWidth < 600 ? 16 : 24,
                            24,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              key: const Key('study-reading-width'),
                              constraints: BoxConstraints(
                                maxWidth: switch (experience.readingWidth) {
                                  AppReadingWidth.narrow => 620,
                                  AppReadingWidth.balanced => 760,
                                  AppReadingWidth.wide => 920,
                                },
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (!experience.focusStudyMode) ...[
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      alignment: WrapAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        _ExercisePill(
                                          icon: _modeIcon,
                                          label: _instruction,
                                        ),
                                        Text(
                                          '${_item.learningLanguage.symbol} · ${_item.kind == LearningItemKind.word ? '단어' : '문장'}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (!widget.examMode &&
                                      (_liveDifficultyAttempts.length >= 3 ||
                                          _liveDifficultyLock != null)) ...[
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Tooltip(
                                        message: _liveDifficultyReason,
                                        child: Chip(
                                          key: const Key(
                                            'live-difficulty-indicator',
                                          ),
                                          avatar: Icon(
                                            _liveDifficultyLock == null
                                                ? Icons.auto_graph_rounded
                                                : Icons.lock_outline_rounded,
                                            size: 17,
                                          ),
                                          label: Text(
                                            '난이도 ${_liveDifficultyLock == null ? '자동' : '고정'} · '
                                            '${_liveDifficulty.koreanLabel}',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (_adaptiveReasonByItemId[_item.id]
                                      case final reason?) ...[
                                    Semantics(
                                      label: '이 문제가 나온 이유: $reason',
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Chip(
                                          key: const Key(
                                            'adaptive-recommendation-reason',
                                          ),
                                          avatar: const Icon(
                                            Icons.auto_awesome_rounded,
                                            size: 17,
                                          ),
                                          label: Text(
                                            '${_runtimeOptions.strategy.koreanLabel} · $reason',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  FocusTraversalOrder(
                                    order: const NumericFocusOrder(1),
                                    child: Semantics(
                                      key: const Key(
                                        'study-question-live-region',
                                      ),
                                      liveRegion: true,
                                      container: true,
                                      label:
                                          '문제 ${_index + 1}/${_queue.length}. $_instruction. ${PrivacyModeScope.redact(context, _prompt, replacement: '학습 내용 숨김')}',
                                      child: Focus(
                                        focusNode: _questionFocus,
                                        child: Card(
                                          key: const Key('study-question-card'),
                                          shape: accessibilityTheme.highContrast
                                              ? RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  side: BorderSide(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.outline,
                                                    width: 2,
                                                  ),
                                                )
                                              : null,
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  (constraints.maxWidth < 600
                                                      ? 18
                                                      : 30) *
                                                  accessibilityTheme
                                                      .cardScaleFactor,
                                              vertical:
                                                  (constraints.maxWidth < 600
                                                      ? 24
                                                      : 34) *
                                                  accessibilityTheme
                                                      .cardScaleFactor,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  experience.cardAlignment ==
                                                      AppCardAlignment.leading
                                                  ? CrossAxisAlignment.start
                                                  : CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  PrivacyModeScope.redact(
                                                    context,
                                                    _prompt,
                                                    replacement: '학습 내용 숨김',
                                                  ),
                                                  key: const Key(
                                                    'study-question-prompt',
                                                  ),
                                                  textAlign:
                                                      experience
                                                              .cardAlignment ==
                                                          AppCardAlignment
                                                              .leading
                                                      ? TextAlign.start
                                                      : TextAlign.center,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .displaySmall
                                                      ?.copyWith(
                                                        fontSize:
                                                            (Theme.of(context)
                                                                    .textTheme
                                                                    .displaySmall
                                                                    ?.fontSize ??
                                                                32) *
                                                            accessibilityTheme
                                                                .cardScaleFactor,
                                                      ),
                                                ),
                                                if (_mode ==
                                                        _ExerciseMode
                                                            .recognition &&
                                                    !_recognitionIsReversed &&
                                                    readingAidsLabel
                                                        .isNotEmpty) ...[
                                                  const SizedBox(height: 9),
                                                  Text(
                                                    PrivacyModeScope.redact(
                                                      context,
                                                      readingAidsLabel,
                                                    ),
                                                    key: const Key(
                                                      'study-question-reading-aids',
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                          height: 1.4,
                                                          fontSize:
                                                              (Theme.of(context)
                                                                      .textTheme
                                                                      .titleMedium
                                                                      ?.fontSize ??
                                                                  16) *
                                                              accessibilityTheme
                                                                  .cardScaleFactor,
                                                        ),
                                                  ),
                                                ],
                                                const SizedBox(height: 16),
                                                Wrap(
                                                  alignment:
                                                      WrapAlignment.center,
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    OutlinedButton.icon(
                                                      onPressed: () => _speak(),
                                                      icon: const Icon(
                                                        Icons.volume_up_rounded,
                                                        size: 20,
                                                      ),
                                                      label: Text(
                                                        _speechPlayCount == 0
                                                            ? '발음 듣기'
                                                            : '다시 듣기',
                                                      ),
                                                    ),
                                                    if (_mode ==
                                                            _ExerciseMode
                                                                .listening ||
                                                        _mode ==
                                                            _ExerciseMode
                                                                .listeningDiscrimination)
                                                      OutlinedButton.icon(
                                                        key: const Key(
                                                          'slow-listening-playback',
                                                        ),
                                                        onPressed: () =>
                                                            _speak(slow: true),
                                                        icon: const Icon(
                                                          Icons
                                                              .slow_motion_video_rounded,
                                                          size: 20,
                                                        ),
                                                        label: const Text(
                                                          '느리게',
                                                        ),
                                                      ),
                                                    if (_mode ==
                                                        _ExerciseMode
                                                            .listeningDiscrimination)
                                                      TextButton.icon(
                                                        key: const Key(
                                                          'listening-text-fallback',
                                                        ),
                                                        onPressed: () => setState(
                                                          () => _showListeningTextFallback =
                                                              !_showListeningTextFallback,
                                                        ),
                                                        icon: const Icon(
                                                          Icons
                                                              .subtitles_outlined,
                                                          size: 20,
                                                        ),
                                                        label: Text(
                                                          _showListeningTextFallback
                                                              ? '소리 문제로 돌아가기'
                                                              : '글자 힌트 보기',
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                if (_mode ==
                                                    _ExerciseMode
                                                        .listeningDiscrimination) ...[
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    '${_listeningDiscriminationQuestion().selectionBasisLabel} · '
                                                    '정답을 포함해 선택지 3개 이상',
                                                    key: const Key(
                                                      'listening-choice-basis',
                                                    ),
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.labelSmall,
                                                  ),
                                                ],
                                                if (experience
                                                        .showShortcutHints ||
                                                    _speechPlayCount > 0) ...[
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    _speechPlayCount == 0
                                                        ? accessibilityProfile
                                                              .shortcutFor(
                                                                StudyShortcutAction
                                                                    .playAudio,
                                                              )
                                                              .displayLabel
                                                        : '재생 $_speechPlayCount회',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.outline,
                                                        ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_hintLevel > 0) ...[
                                    const SizedBox(height: 12),
                                    _HintCard(
                                      level: _hintLevel,
                                      text: _hintText,
                                    ),
                                  ],
                                  const SizedBox(height: 18),
                                  FocusTraversalOrder(
                                    order: const NumericFocusOrder(2),
                                    child: GestureDetector(
                                      key: const Key(
                                        'study-exercise-gesture-region',
                                      ),
                                      behavior: HitTestBehavior.translucent,
                                      onHorizontalDragEnd:
                                          accessibilityProfile
                                                      .androidSelectionGesture ==
                                                  AndroidSelectionGesture
                                                      .swipeAndButtons &&
                                              _isChoiceMode
                                          ? (details) {
                                              final velocity =
                                                  details.primaryVelocity ?? 0;
                                              if (velocity.abs() < 80) return;
                                              _moveChoiceSelection(
                                                velocity < 0 ? 1 : -1,
                                              );
                                            }
                                          : null,
                                      child: _exerciseInput(
                                        showShortcutHints:
                                            experience.showShortcutHints,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (_correct case final correct?)
                      _StudyFeedbackOverlay(
                        focusNode: _feedbackFocus,
                        reduceTransparency:
                            accessibilityTheme.reduceTransparency,
                        correct: correct,
                        answer: _expectedAnswer,
                        userAnswer: _submittedAnswer ?? '',
                        item: _item,
                        readingAidsLabel: readingAidsLabel,
                        usedHint: _hintLevel > 0,
                        combo: _combo,
                        rating:
                            _pendingResponse?.currentAttempt.rating ??
                            (correct ? ReviewRating.good : ReviewRating.again),
                        correctionLabel:
                            _pendingResponse?.currentAttempt.correctionLabel,
                        recordProgress: _recordProgress,
                        minimumControlHeight:
                            accessibilityTheme.minimumRatingControlHeight,
                        showRepair:
                            !correct &&
                            _repairAdvisor.shouldOfferRepair(
                              _failureCountByItemId[_item.id] ?? 0,
                            ),
                        favorite: ref
                            .watch(appControllerProvider)
                            .preferences
                            .isFavorite(_item.id),
                        feedbackDetail: experience.feedbackDetail,
                        encouragementTone: experience.encouragementTone,
                        celebrationLevel: experience.celebrationLevel,
                        onSpeak: () => _speak(),
                        onToggleFavorite: () => ref
                            .read(appControllerProvider.notifier)
                            .toggleFavorite(_item.id),
                        onEditContent: _openCurrentItemEditor,
                        onQuickAdd: _openQuickAddFromCurrentItem,
                        onEditMemoryHint: _openMemoryHintEditor,
                        onMarkTypo:
                            !correct &&
                                (_submittedAnswer ?? '').trim().isNotEmpty
                            ? () => _replacePendingOutcome(
                                correct: true,
                                rating: ReviewRating.hard,
                                correctionLabel: '오타였어요',
                              )
                            : null,
                        onMarkHard:
                            correct &&
                                _pendingResponse?.currentAttempt.rating !=
                                    ReviewRating.hard
                            ? () => _replacePendingOutcome(
                                correct: true,
                                rating: ReviewRating.hard,
                                correctionLabel: '맞았지만 어려웠어요',
                              )
                            : null,
                        onRestore:
                            _pendingResponse?.currentAttempt.correctionLabel !=
                                null
                            ? _restoreOriginalOutcome
                            : null,
                        onRepair: _showRepairOptions,
                        onNext: _submit,
                      ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: _correct == null
                ? _StudyActionBar(
                    hintLevel: _hintLevel,
                    hintsEnabled: _hintsEnabled,
                    canDefer: _index + 1 < _queue.length,
                    inputProfile: _inputProfile,
                    minimumControlHeight:
                        accessibilityTheme.minimumRatingControlHeight,
                    leftHanded: experience.leftHandedControls,
                    onHint: _showHint,
                    onDefer: _deferCurrentQuestion,
                    onDontKnow: _submitDontKnow,
                    onSubmit: _submit,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  String get _instruction => switch (_mode) {
    _ExerciseMode.recognition when _recognitionIsReversed => '알맞은 학습어를 고르세요',
    _ExerciseMode.recognition => '알맞은 뜻을 고르세요',
    _ExerciseMode.production => '학습할 언어로 써 보세요',
    _ExerciseMode.cloze => '빈칸에 들어갈 표현을 고르세요',
    _ExerciseMode.sentenceOrder => '단어를 순서대로 배열하세요',
    _ExerciseMode.listening => '소리를 듣고 받아쓰세요',
    _ExerciseMode.listeningDiscrimination => '들은 표현을 고르세요',
  };

  IconData get _modeIcon => switch (_mode) {
    _ExerciseMode.recognition => Icons.touch_app_rounded,
    _ExerciseMode.production => Icons.keyboard_rounded,
    _ExerciseMode.cloze => Icons.space_bar_rounded,
    _ExerciseMode.sentenceOrder => Icons.reorder_rounded,
    _ExerciseMode.listening => Icons.headphones_rounded,
    _ExerciseMode.listeningDiscrimination => Icons.hearing_rounded,
  };

  String get _prompt => switch (_mode) {
    _ExerciseMode.recognition when _recognitionIsReversed =>
      _item.primaryTranslation,
    _ExerciseMode.recognition => _item.text,
    _ExerciseMode.production ||
    _ExerciseMode.sentenceOrder => _item.primaryTranslation,
    _ExerciseMode.listening => '재생 버튼을 눌러 듣고 입력하세요',
    _ExerciseMode.listeningDiscrimination =>
      _showListeningTextFallback
          ? '소리 대체 단서: ${_item.primaryTranslation}'
          : '소리를 듣고 가장 가까운 표현을 고르세요',
    _ExerciseMode.cloze => _joinTokens([
      for (var index = 0; index < _item.sentenceTokens.length; index++)
        index == _item.sentenceTokens.length ~/ 2
            ? '_____'
            : _item.sentenceTokens[index],
    ], _item.learningLanguage),
  };

  Widget _exerciseInput({required bool showShortcutHints}) {
    if (_isChoiceMode) {
      final choices = _choices();
      return LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final automaticGrid =
              constraints.maxWidth >= 340 &&
              textScale <= 1.25 &&
              choices.every(
                (choice) => !choice.contains('\n') && choice.runes.length <= 18,
              );
          final useGrid = switch (_interaction.choiceLayout) {
            StudyChoiceLayout.automatic => automaticGrid,
            StudyChoiceLayout.list => false,
            StudyChoiceLayout.grid => true,
          };
          final spacing = useGrid ? 10.0 : 0.0;
          final choiceWidth = useGrid
              ? (constraints.maxWidth - spacing) / 2
              : constraints.maxWidth;
          return Semantics(
            label: _mode == _ExerciseMode.listeningDiscrimination
                ? '듣기 구별 선택지 ${choices.length}개. '
                      '${_showListeningTextFallback ? '텍스트 대체 단서를 사용 중입니다.' : '재생 후 선택하세요.'}'
                : useGrid
                ? '선택지 ${choices.length}개, 두 열 배치'
                : '선택지 ${choices.length}개, 한 열 배치',
            container: true,
            explicitChildNodes: true,
            child: Wrap(
              key: Key(
                useGrid ? 'study-choice-grid' : 'study-choice-single-column',
              ),
              spacing: spacing,
              runSpacing: 10,
              children: [
                for (final (index, choice) in choices.indexed)
                  Semantics(
                    sortKey: OrdinalSortKey(index.toDouble()),
                    child: SizedBox(
                      width: choiceWidth,
                      child: _ChoiceButton(
                        key: Key('study-choice-$index'),
                        shortcut: '${index + 1}',
                        showShortcut: showShortcutHints,
                        label: PrivacyModeScope.redact(
                          context,
                          choice,
                          replacement: '선택지 ${index + 1}',
                        ),
                        selected: _selectedChoice == choice,
                        submitted: _correct != null,
                        correctAnswer: choice == _expectedAnswer,
                        minimumHeight: _inputProfile.minimumControlHeight,
                        onPressed: _correct == null
                            ? () => _selectChoice(choice)
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }
    if (_mode == _ExerciseMode.sentenceOrder) {
      return _SentenceOrderInput(
        selected: _orderedTokens,
        remaining: _remainingTokens,
        enabled: _correct == null,
        onSelectedTap: _removeOrderedToken,
        onRemainingTap: _appendToken,
        onUndo: _removeLastOrderedToken,
        onReset: _resetOrderedTokens,
        showShortcutHints: showShortcutHints,
      );
    }
    return TextField(
      controller: _answerController,
      focusNode: _answerFocus,
      enabled: _correct == null,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      onChanged: (_) => _scheduleDraftCheckpoint(),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.edit_rounded),
        labelText: '${_item.learningLanguage.koreanName} 답안',
        hintText: '정답을 입력하세요',
        helperText: showShortcutHints ? 'Enter 제출 · Ctrl+Space 발음 다시 듣기' : null,
      ),
    );
  }
}

class _SessionManagementSheet extends StatelessWidget {
  const _SessionManagementSheet({
    required this.session,
    required this.wrongCount,
    required this.remainingCount,
    required this.answerDirection,
    required this.gradingStrength,
    required this.inputProfile,
    required this.strategy,
    required this.keyboardHelpShortcut,
    required this.showKeyboardHelp,
    required this.canChangeOptions,
    required this.canStartMatch,
    required this.canDeriveSession,
  });

  final ActiveStudySession session;
  final int wrongCount;
  final int remainingCount;
  final StudyAnswerDirection answerDirection;
  final StudyGradingStrictness gradingStrength;
  final PracticeInputProfile inputProfile;
  final StudySessionStrategy strategy;
  final String keyboardHelpShortcut;
  final bool showKeyboardHelp;
  final bool canChangeOptions;
  final bool canStartMatch;
  final bool canDeriveSession;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('세션 관리', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 5),
                Text(
                  '${session.origin.label} · ${session.completedCount}/${session.itemIds.length}문제'
                  '${session.generation == 0 ? '' : ' · ${session.generation}단계 분기'}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (session.pauseCount + session.resumeCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '일시정지 ${session.pauseCount}회 · 이어하기 ${session.resumeCount}회',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                _SessionManagementTile(
                  key: const Key('study-session-options'),
                  icon: Icons.tune_rounded,
                  title: '이번 세션 설정',
                  subtitle:
                      '${_answerDirectionLabel(answerDirection)} · '
                      '${gradingStrength.koreanLabel} 채점 · '
                      '${inputProfile.koreanLabel}',
                  onTap: canChangeOptions
                      ? () => Navigator.pop(
                          context,
                          _SessionManagementAction.options,
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                _SessionManagementTile(
                  key: const Key('preview-adaptive-study-queue'),
                  icon: Icons.view_list_rounded,
                  title: '남은 문제 미리보기',
                  subtitle: '${strategy.koreanLabel} · 문제 유형과 자료 비율만 보여요',
                  onTap: () =>
                      Navigator.pop(context, _SessionManagementAction.preview),
                ),
                const SizedBox(height: 8),
                if (showKeyboardHelp) ...[
                  _SessionManagementTile(
                    key: const Key('open-session-keyboard-help'),
                    icon: Icons.keyboard_alt_outlined,
                    title: '현재 화면 단축키',
                    subtitle: '이 퀴즈에서 쓸 수 있는 키를 확인하세요 · $keyboardHelpShortcut',
                    onTap: () => Navigator.pop(
                      context,
                      _SessionManagementAction.keyboardHelp,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _SessionManagementTile(
                  key: const Key('start-match-sprint'),
                  icon: Icons.grid_view_rounded,
                  title: '매치 스프린트',
                  subtitle: inputProfile.allowsTimedChallenge
                      ? '60초 안에 표현과 뜻 10쌍을 연결해요.'
                      : '시간 제한 없이 표현과 뜻을 연결해요.',
                  onTap: canStartMatch
                      ? () => Navigator.pop(
                          context,
                          _SessionManagementAction.matchSprint,
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                _SessionManagementTile(
                  key: const Key('restart-study-session'),
                  icon: Icons.restart_alt_rounded,
                  title: '처음 문제로 다시 시작',
                  subtitle: canDeriveSession
                      ? '현재 결과를 저장하고 처음 문제 순서로 다시 시작해요.'
                      : '시험 중에는 문제 묶음과 점수 기준을 바꿀 수 없습니다.',
                  onTap: canDeriveSession
                      ? () => Navigator.pop(
                          context,
                          _SessionManagementAction.restart,
                        )
                      : null,
                ),
                const SizedBox(height: 8),
                _SessionManagementTile(
                  key: const Key('branch-wrong-session'),
                  icon: Icons.error_outline_rounded,
                  title: '틀린 문제 $wrongCount개만 풀기',
                  subtitle: wrongCount == 0
                      ? '아직 틀린 문제가 없습니다.'
                      : '지금까지 틀린 표현만 모아 다시 풀어요.',
                  onTap: !canDeriveSession || wrongCount == 0
                      ? null
                      : () => Navigator.pop(
                          context,
                          _SessionManagementAction.wrongAnswers,
                        ),
                ),
                const SizedBox(height: 8),
                _SessionManagementTile(
                  key: const Key('branch-remaining-session'),
                  icon: Icons.call_split_rounded,
                  title: '남은 문제 $remainingCount개만 풀기',
                  subtitle: remainingCount == 0
                      ? '남은 문제가 없습니다.'
                      : '이미 푼 문제는 빼고 남은 문제만 이어서 풀어요.',
                  onTap: !canDeriveSession || remainingCount == 0
                      ? null
                      : () => Navigator.pop(
                          context,
                          _SessionManagementAction.remaining,
                        ),
                ),
                const SizedBox(height: 8),
                _SessionManagementTile(
                  key: const Key('finish-study-session'),
                  icon: Icons.stop_circle_outlined,
                  title: '현재 세션 종료',
                  subtitle: '푼 문제는 기록에 남기고 이어하기 목록에서 지워요.',
                  color: colors.error,
                  onTap: () =>
                      Navigator.pop(context, _SessionManagementAction.finish),
                ),
                const SizedBox(height: 12),
                Text(
                  '잠시 쉴 때는 이 창을 닫고 왼쪽 위 일시정지를 누르세요. 현재 위치는 바로 저장돼요.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionManagementTile extends StatelessWidget {
  const _SessionManagementTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final tone = enabled
        ? color ?? Theme.of(context).colorScheme.primary
        : Theme.of(context).disabledColor;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: tone),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: enabled ? null : Theme.of(context).disabledColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: enabled ? null : Theme.of(context).disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: tone),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactStudyHud extends StatelessWidget {
  const _CompactStudyHud({
    required this.current,
    required this.total,
    required this.correct,
    required this.wrong,
    required this.combo,
    required this.comboGoal,
    required this.xp,
    required this.showTimer,
    required this.showQuestionCounter,
    required this.progressStyle,
    this.hideResults = false,
    this.timeLabelOverride,
  });

  final int current;
  final int total;
  final int correct;
  final int wrong;
  final int combo;
  final int comboGoal;
  final int xp;
  final bool showTimer;
  final bool showQuestionCounter;
  final AppProgressStyle progressStyle;
  final bool hideResults;
  final String? timeLabelOverride;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final comboAchieved = comboGoal > 0 && combo >= comboGoal;
    final comboColor = comboAchieved
        ? const Color(0xFFD97706)
        : colors.onSurfaceVariant;
    final remainingQuestions = (total - current + 1).clamp(0, total);
    final remainingSeconds = remainingQuestions * 25;
    final estimatedTimeLabel = remainingSeconds < 60
        ? '1분 이내'
        : '약 ${(remainingSeconds / 60).ceil()}분';
    final timeLabel = timeLabelOverride ?? estimatedTimeLabel;
    final description = [
      if (showQuestionCounter) '$current/$total 문제',
      if (!hideResults) ...[
        '정답 $correct개',
        '오답 $wrong개',
        '현재 $combo콤보',
        '연속 목표 $comboGoal개',
        '획득 $xp XP',
      ],
      if (showTimer || timeLabelOverride != null)
        '${timeLabelOverride == null ? '예상 남은 학습 시간' : '시험 남은 시간'} $timeLabel',
    ].join(', ');
    return Semantics(
      key: const Key('compact-study-hud'),
      label: description,
      container: true,
      child: Tooltip(
        message:
            '${showQuestionCounter ? '$current/$total · ' : ''}'
            '${hideResults ? '시험 진행 중' : '정답 $correct · 오답 $wrong · $combo/$comboGoal콤보 · $xp XP'}'
            '${showTimer || timeLabelOverride != null ? ' · 남은 시간 $timeLabel' : ''}',
        child: ExcludeSemantics(
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1,
            child: Row(
              children: [
                if (progressStyle != AppProgressStyle.minimal) ...[
                  Expanded(
                    child: progressStyle == AppProgressStyle.steps
                        ? _StudyStepProgress(current: current, total: total)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: current / total,
                              minHeight: 7,
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (showQuestionCounter) ...[
                  _HudText('$current/$total'),
                  const SizedBox(width: 6),
                ],
                if (!hideResults) ...[
                  _HudMetric(icon: Icons.check_rounded, value: '$correct'),
                  const SizedBox(width: 4),
                  _HudMetric(icon: Icons.close_rounded, value: '$wrong'),
                  const SizedBox(width: 4),
                  _HudMetric(
                    icon: Icons.local_fire_department_rounded,
                    value: '$combo/$comboGoal',
                    color: comboColor,
                  ),
                ],
                if (showTimer || timeLabelOverride != null) ...[
                  const SizedBox(width: 4),
                  _HudMetric(
                    key: const Key('study-time-estimate'),
                    icon: Icons.timer_outlined,
                    value: timeLabel,
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

class _StudyStepProgress extends StatelessWidget {
  const _StudyStepProgress({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const visibleSteps = 6;
    final completed = ((current / total) * visibleSteps).ceil();
    return Row(
      key: const Key('study-step-progress'),
      children: [
        for (var index = 0; index < visibleSteps; index++) ...[
          Expanded(
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                color: index < completed
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (index + 1 < visibleSteps) const SizedBox(width: 2),
        ],
      ],
    );
  }
}

class _HudText extends StatelessWidget {
  const _HudText(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _HudMetric extends StatelessWidget {
  const _HudMetric({
    required this.icon,
    required this.value,
    this.color,
    super.key,
  });

  final IconData icon;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: tone),
        const SizedBox(width: 1),
        Text(
          value,
          style: TextStyle(
            color: tone,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.level, required this.text});

  final int level;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceTransparency = StudyAccessibilityTheme.of(
      context,
    ).reduceTransparency;
    return Semantics(
      liveRegion: true,
      label: '힌트 $level단계. $text',
      child: Container(
        key: const Key('study-hint-card'),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: colors.tertiaryContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: reduceTransparency
                ? colors.tertiary
                : colors.tertiary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lightbulb_rounded,
              color: colors.onTertiaryContainer,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '힌트 $level/2',
                    style: TextStyle(
                      color: colors.onTertiaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    text,
                    style: TextStyle(color: colors.onTertiaryContainer),
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

class _StudyActionBar extends StatelessWidget {
  const _StudyActionBar({
    required this.hintLevel,
    required this.hintsEnabled,
    required this.canDefer,
    required this.inputProfile,
    required this.minimumControlHeight,
    required this.leftHanded,
    required this.onHint,
    required this.onDefer,
    required this.onDontKnow,
    required this.onSubmit,
  });

  final int hintLevel;
  final bool hintsEnabled;
  final bool canDefer;
  final PracticeInputProfile inputProfile;
  final double minimumControlHeight;
  final bool leftHanded;
  final VoidCallback onHint;
  final VoidCallback onDefer;
  final VoidCallback onDontKnow;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceTransparency = StudyAccessibilityTheme.of(
      context,
    ).reduceTransparency;
    final effectiveControlHeight = max(
      inputProfile.minimumControlHeight,
      minimumControlHeight,
    );
    return SafeArea(
      top: false,
      child: Material(
        color: colors.surface,
        elevation: reduceTransparency ? 0 : 8,
        shadowColor: reduceTransparency
            ? Colors.transparent
            : Colors.black.withValues(alpha: 0.12),
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final hintButton = TextButton.icon(
                    key: const Key('show-study-hint'),
                    onPressed: !hintsEnabled || hintLevel >= 2 ? null : onHint,
                    icon: const Icon(Icons.lightbulb_outline_rounded, size: 19),
                    label: Text(
                      !hintsEnabled
                          ? '힌트 꺼짐'
                          : hintLevel == 0
                          ? '힌트'
                          : hintLevel == 1
                          ? '힌트 한 번 더'
                          : '힌트 사용',
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: Size(0, effectiveControlHeight),
                    ),
                  );
                  final deferButton = TextButton.icon(
                    key: const Key('defer-study-question'),
                    onPressed: canDefer ? onDefer : null,
                    icon: const Icon(Icons.low_priority_rounded, size: 19),
                    label: const Text('나중에 풀기'),
                    style: TextButton.styleFrom(
                      minimumSize: Size(0, effectiveControlHeight),
                    ),
                  );
                  final giveUpButton = TextButton.icon(
                    key: const Key('give-up-study-question'),
                    onPressed: onDontKnow,
                    icon: const Icon(Icons.visibility_outlined, size: 19),
                    label: const Text('모르겠어요'),
                    style: TextButton.styleFrom(
                      minimumSize: Size(0, effectiveControlHeight),
                    ),
                  );
                  final submitButton = FilledButton.icon(
                    key: const Key('submit-study-answer'),
                    onPressed: onSubmit,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('정답 확인'),
                    style: FilledButton.styleFrom(
                      minimumSize: Size(0, effectiveControlHeight),
                    ),
                  );
                  if (constraints.maxWidth < 620 ||
                      inputProfile == PracticeInputProfile.accessible) {
                    final largeText =
                        MediaQuery.textScalerOf(context).scale(1) > 1.5;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (leftHanded) ...[
                          SizedBox(
                            height: effectiveControlHeight,
                            child: submitButton,
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (largeText) ...[
                          hintButton,
                          deferButton,
                          giveUpButton,
                        ] else
                          Wrap(
                            alignment: WrapAlignment.spaceEvenly,
                            children: [hintButton, deferButton, giveUpButton],
                          ),
                        if (!leftHanded) ...[
                          const SizedBox(height: 6),
                          SizedBox(
                            height: effectiveControlHeight,
                            child: submitButton,
                          ),
                        ],
                      ],
                    );
                  }
                  final secondaryButtons = <Widget>[
                    hintButton,
                    const SizedBox(width: 6),
                    deferButton,
                    const SizedBox(width: 6),
                    giveUpButton,
                  ];
                  final primaryButton = SizedBox(
                    width: 190,
                    height: effectiveControlHeight,
                    child: submitButton,
                  );
                  return Row(
                    key: Key(
                      leftHanded
                          ? 'study-actions-left-handed'
                          : 'study-actions-right-handed',
                    ),
                    children: leftHanded
                        ? [primaryButton, const Spacer(), ...secondaryButtons]
                        : [...secondaryButtons, const Spacer(), primaryButton],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudyFeedbackOverlay extends StatelessWidget {
  const _StudyFeedbackOverlay({
    required this.focusNode,
    required this.reduceTransparency,
    required this.correct,
    required this.answer,
    required this.userAnswer,
    required this.item,
    required this.readingAidsLabel,
    required this.usedHint,
    required this.combo,
    required this.rating,
    required this.correctionLabel,
    required this.recordProgress,
    required this.minimumControlHeight,
    required this.showRepair,
    required this.favorite,
    required this.feedbackDetail,
    required this.encouragementTone,
    required this.celebrationLevel,
    required this.onSpeak,
    required this.onToggleFavorite,
    required this.onEditContent,
    required this.onQuickAdd,
    required this.onEditMemoryHint,
    required this.onMarkTypo,
    required this.onMarkHard,
    required this.onRestore,
    required this.onRepair,
    required this.onNext,
  });

  final FocusNode focusNode;
  final bool reduceTransparency;
  final bool correct;
  final String answer;
  final String userAnswer;
  final LearningItem item;
  final String readingAidsLabel;
  final bool usedHint;
  final int combo;
  final ReviewRating rating;
  final String? correctionLabel;
  final bool recordProgress;
  final double minimumControlHeight;
  final bool showRepair;
  final bool favorite;
  final AppFeedbackDetail feedbackDetail;
  final AppEncouragementTone encouragementTone;
  final AppCelebrationLevel celebrationLevel;
  final VoidCallback onSpeak;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEditContent;
  final VoidCallback onQuickAdd;
  final VoidCallback onEditMemoryHint;
  final VoidCallback? onMarkTypo;
  final VoidCallback? onMarkHard;
  final VoidCallback? onRestore;
  final VoidCallback onRepair;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compactControlStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, minimumControlHeight)),
    );
    return Semantics(
      liveRegion: true,
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: correct ? '정답 결과' : '오답 결과',
      child: Stack(
        fit: StackFit.expand,
        children: [
          ModalBarrier(
            dismissible: false,
            color: reduceTransparency
                ? colors.surface
                : colors.scrim.withValues(alpha: 0.28),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 420,
                      maxHeight: min(560, constraints.maxHeight - 32),
                    ),
                    child: Focus(
                      focusNode: focusNode,
                      autofocus: true,
                      child: Material(
                        key: const Key('study-feedback-popup'),
                        color: colors.surface,
                        elevation: reduceTransparency ? 0 : 18,
                        shadowColor: reduceTransparency
                            ? Colors.transparent
                            : colors.shadow.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: colors.outline),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _FeedbackCard(
                                correct: correct,
                                answer: answer,
                                userAnswer: userAnswer,
                                item: item,
                                readingAidsLabel: readingAidsLabel,
                                usedHint: usedHint,
                                combo: combo,
                                rating: rating,
                                correctionLabel: correctionLabel,
                                recordProgress: recordProgress,
                                favorite: favorite,
                                feedbackDetail: feedbackDetail,
                                encouragementTone: encouragementTone,
                                celebrationLevel: celebrationLevel,
                                onSpeak: onSpeak,
                                onToggleFavorite: onToggleFavorite,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    key: const Key(
                                      'edit-content-from-feedback',
                                    ),
                                    onPressed: onEditContent,
                                    style: compactControlStyle,
                                    icon: const Icon(
                                      Icons.edit_note_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      item.source == ContentSource.userCreated
                                          ? '자료 수정'
                                          : '교정 메모',
                                    ),
                                  ),
                                  if (onMarkTypo case final action?)
                                    OutlinedButton.icon(
                                      key: const Key('correct-as-typo'),
                                      onPressed: action,
                                      style: compactControlStyle,
                                      icon: const Icon(
                                        Icons.spellcheck_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('오타였어요'),
                                    ),
                                  if (onMarkHard case final action?)
                                    OutlinedButton.icon(
                                      key: const Key('correct-as-hard'),
                                      onPressed: action,
                                      style: compactControlStyle,
                                      icon: const Icon(
                                        Icons.psychology_alt_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('맞았지만 어려웠어요'),
                                    ),
                                  if (onRestore case final action?)
                                    TextButton.icon(
                                      key: const Key('restore-answer-result'),
                                      onPressed: action,
                                      style: compactControlStyle,
                                      icon: const Icon(
                                        Icons.undo_rounded,
                                        size: 18,
                                      ),
                                      label: const Text('결과 되돌리기'),
                                    ),
                                  if (showRepair)
                                    TextButton.icon(
                                      key: const Key('repair-repeated-mistake'),
                                      onPressed: onRepair,
                                      style: compactControlStyle,
                                      icon: const Icon(
                                        Icons.build_circle_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('문제 확인하기'),
                                    ),
                                  PopupMenuButton<_FeedbackSecondaryAction>(
                                    key: const Key('feedback-more-actions'),
                                    tooltip: '자료와 암기 도구',
                                    onSelected: (action) => switch (action) {
                                      _FeedbackSecondaryAction.quickAdd =>
                                        onQuickAdd(),
                                      _FeedbackSecondaryAction.memoryHint =>
                                        onEditMemoryHint(),
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        key: Key(
                                          'quick-add-from-study-feedback',
                                        ),
                                        value:
                                            _FeedbackSecondaryAction.quickAdd,
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(
                                            Icons.add_circle_outline_rounded,
                                          ),
                                          title: Text('새 자료로 복사'),
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        key: Key('edit-memory-hint'),
                                        value:
                                            _FeedbackSecondaryAction.memoryHint,
                                        child: ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Icon(
                                            Icons.lightbulb_outline_rounded,
                                          ),
                                          title: Text('암기 단서'),
                                        ),
                                      ),
                                    ],
                                    child: Container(
                                      constraints: BoxConstraints(
                                        minHeight: minimumControlHeight,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: colors.outline,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.more_horiz_rounded,
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text('더보기'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                key: const Key('next-question-from-feedback'),
                                onPressed: onNext,
                                autofocus: true,
                                style: FilledButton.styleFrom(
                                  minimumSize: Size(0, minimumControlHeight),
                                ),
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: const Text('다음 문제'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _joinTokens(List<String> tokens, LanguageTag language) {
  final separator = LanguageProfile.of(language).usesSpaces ? ' ' : '';
  return tokens.join(separator);
}

String _formatExamRemaining(int seconds) {
  final safe = max(0, seconds);
  final minutes = safe ~/ 60;
  final remainder = safe % 60;
  return '$minutes:${remainder.toString().padLeft(2, '0')}';
}

String _normalizedChoice(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

class _ExercisePill extends StatelessWidget {
  const _ExercisePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: colors.onPrimaryContainer),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onPrimaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamSetupDialog extends StatefulWidget {
  const _ExamSetupDialog({
    required this.availableQuestions,
    required this.initial,
  });

  final int availableQuestions;
  final ExamConfiguration initial;

  @override
  State<_ExamSetupDialog> createState() => _ExamSetupDialogState();
}

class _ExamSetupDialogState extends State<_ExamSetupDialog> {
  late int _questionCount;
  late int _timeLimitMinutes;
  late int _passScore;

  @override
  void initState() {
    super.initState();
    _questionCount = widget.initial.questionCount;
    _timeLimitMinutes = widget.initial.timeLimit.inMinutes;
    _passScore = widget.initial.passScore;
  }

  @override
  Widget build(BuildContext context) {
    final maximumQuestionCount = min(
      widget.availableQuestions,
      StudyLimits.maxSessionItems,
    );
    final countOptions =
        <int>{
              5,
              10,
              20,
              50,
              100,
              250,
              500,
              StudyLimits.maxSessionItems,
              maximumQuestionCount,
            }
            .where((value) => value > 0 && value <= maximumQuestionCount)
            .toList()
          ..sort();
    return AlertDialog(
      key: const Key('exam-setup-dialog'),
      title: const Text('시험 설정'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '시험 중에는 정답을 보여 주지 않아요. 제출한 뒤 문제별 결과를 확인할 수 있고, XP와 복습 일정은 바뀌지 않아요.',
              ),
              const SizedBox(height: 18),
              Text('문항 수', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final count in countOptions)
                    ChoiceChip(
                      key: Key('exam-question-count-$count'),
                      label: Text('$count문항'),
                      selected: _questionCount == count,
                      onSelected: (_) => setState(() => _questionCount = count),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('시간 제한', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final minutes in const [5, 10, 20, 30])
                    ChoiceChip(
                      key: Key('exam-time-limit-$minutes'),
                      label: Text('$minutes분'),
                      selected: _timeLimitMinutes == minutes,
                      onSelected: (_) =>
                          setState(() => _timeLimitMinutes = minutes),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('통과 점수', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 7),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final score in const [60, 70, 80, 90])
                    ChoiceChip(
                      key: Key('exam-pass-score-$score'),
                      label: Text('$score점'),
                      selected: _passScore == score,
                      onSelected: (_) => setState(() => _passScore = score),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-exam-mode'),
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton.icon(
          key: const Key('start-exam-mode'),
          onPressed: () => Navigator.pop(
            context,
            ExamConfiguration(
              questionCount: _questionCount,
              timeLimit: Duration(minutes: _timeLimitMinutes),
              passScore: _passScore,
            ),
          ),
          icon: const Icon(Icons.timer_outlined),
          label: const Text('시험 시작'),
        ),
      ],
    );
  }
}

class _ExamReportCard extends StatelessWidget {
  const _ExamReportCard({required this.report});

  final ExamReport report;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('exam-report-card'),
      container: true,
      label:
          '시험 ${report.passed ? '통과' : '미통과'}. ${report.score}점. '
          '정답 ${report.correctCount}개. 미응답 ${report.unansweredCount}개.',
      child: Card(
        color: report.passed ? colors.primaryContainer : colors.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                report.passed
                    ? Icons.workspace_premium_rounded
                    : Icons.fact_check_outlined,
                size: 36,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.passed ? '통과했어요' : '한 번 더 도전해 보세요',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${report.score}점 / 통과 ${report.configuration.passScore}점 · '
                      '정답 ${report.correctCount} · 오답 ${report.answeredCount - report.correctCount} · '
                      '미응답 ${report.unansweredCount}'
                      '${report.timedOut ? ' · 시간 종료' : ''}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompletionScreen extends StatelessWidget {
  const _CompletionScreen({
    required this.correct,
    required this.wrong,
    required this.xp,
    required this.accuracy,
    required this.minutes,
    required this.bestCombo,
    required this.plannedCount,
    required this.hasMistakes,
    required this.attempts,
    required this.attemptMetrics,
    required this.challengeScore,
    required this.examReport,
    required this.saveStatus,
    required this.receipt,
    required this.recordProgress,
    required this.onRetryMistakes,
    required this.onScheduleNext,
    required this.timeRecommendation,
    required this.onApplyRoutineTime,
    required this.onReplaySame,
    required this.onReplayShuffled,
    required this.onOpenItem,
    required this.onNextPlaylist,
    required this.playlistProgressLabel,
    required this.onNextRecommended,
    required this.onHome,
    required this.returnLabel,
    required this.returnIcon,
    required this.celebrationLevel,
    required this.encouragementTone,
  });

  final int correct;
  final int wrong;
  final int xp;
  final int accuracy;
  final int minutes;
  final int bestCombo;
  final int plannedCount;
  final bool hasMistakes;
  final List<QuizAttemptReview> attempts;
  final List<StudyAttemptMetric> attemptMetrics;
  final PracticeChallengeScore? challengeScore;
  final ExamReport? examReport;
  final String saveStatus;
  final StudyCompletionReceipt receipt;
  final bool recordProgress;
  final VoidCallback? onRetryMistakes;
  final VoidCallback onScheduleNext;
  final LocalStudyTimeRecommendation? timeRecommendation;
  final VoidCallback? onApplyRoutineTime;
  final VoidCallback? onReplaySame;
  final VoidCallback? onReplayShuffled;
  final ValueChanged<String> onOpenItem;
  final VoidCallback? onNextPlaylist;
  final String? playlistProgressLabel;
  final VoidCallback? onNextRecommended;
  final VoidCallback onHome;
  final String returnLabel;
  final IconData returnIcon;
  final AppCelebrationLevel celebrationLevel;
  final AppEncouragementTone encouragementTone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceTransparency = StudyAccessibilityTheme.of(
      context,
    ).reduceTransparency;
    final excellent = examReport?.passed ?? accuracy >= 80;
    final accent = excellent
        ? const Color(0xFF238B57)
        : const Color(0xFFD97706);
    final standardTitle = switch (encouragementTone) {
      AppEncouragementTone.calm =>
        excellent ? '오늘 학습을 아주 잘 마쳤어요!' : '오늘도 한 걸음 익혔어요',
      AppEncouragementTone.playful
          when celebrationLevel == AppCelebrationLevel.off =>
        excellent ? '학습을 잘 마쳤어요!' : '오늘 학습을 마쳤어요',
      AppEncouragementTone.playful =>
        excellent ? '🎉 오늘 학습을 모두 마쳤어요!' : '🚀 오늘도 꾸준히 해냈어요!',
      AppEncouragementTone.minimal => '학습 완료',
    };
    final title = examReport == null
        ? standardTitle
        : examReport!.passed
        ? '시험 통과 · ${examReport!.score}점'
        : '시험 완료 · ${examReport!.score}점';
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(constraints.maxWidth < 600 ? 18 : 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 720,
                    minHeight: max(0, constraints.maxHeight - 56),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        key: const Key('study-completion-live-region'),
                        liveRegion: true,
                        container: true,
                        label:
                            '학습 완료. 정확도 $accuracy퍼센트. 정답 $correct개, 오답 $wrong개. $saveStatus',
                        child: ExcludeSemantics(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.save_outlined, size: 18),
                              const SizedBox(width: 6),
                              Flexible(child: Text(saveStatus)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CompletionReceiptCard(receipt: receipt),
                      const SizedBox(height: 12),
                      if (celebrationLevel != AppCelebrationLevel.off) ...[
                        DecoratedBox(
                          key: Key(
                            celebrationLevel == AppCelebrationLevel.full
                                ? 'completion-celebration-full'
                                : 'completion-celebration-subtle',
                          ),
                          decoration: BoxDecoration(
                            color: reduceTransparency
                                ? colors.surfaceContainerHighest
                                : accent.withValues(
                                    alpha:
                                        celebrationLevel ==
                                            AppCelebrationLevel.full
                                        ? 0.12
                                        : 0.07,
                                  ),
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox.square(
                            dimension:
                                celebrationLevel == AppCelebrationLevel.full
                                ? 104
                                : 72,
                            child: Icon(
                              excellent
                                  ? Icons.emoji_events_rounded
                                  : Icons.auto_awesome_rounded,
                              size: celebrationLevel == AppCelebrationLevel.full
                                  ? 52
                                  : 34,
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        examReport == null
                            ? '$plannedCount문제로 시작한 학습 결과예요. '
                                  '최고 $bestCombo콤보 · $minutes분. '
                                  '${recordProgress ? '' : '진도 비기록 연습 · '}'
                                  '${hasMistakes ? '틀린 표현은 바로 다시 풀어 보세요.' : '모든 표현을 맞혔어요.'}'
                            : '정답은 시험 중에 공개하지 않았습니다. '
                                  '${examReport!.configuration.questionCount}문항 기준 · '
                                  '통과 ${examReport!.configuration.passScore}점 · '
                                  '미응답 ${examReport!.unansweredCount}개.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (examReport case final report?) ...[
                        const SizedBox(height: 14),
                        _ExamReportCard(report: report),
                      ],
                      const SizedBox(height: 26),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: LayoutBuilder(
                            builder: (context, cardConstraints) {
                              final compact = cardConstraints.maxWidth < 520;
                              final metrics = [
                                (
                                  '정확도',
                                  '$accuracy%',
                                  Icons.track_changes_rounded,
                                ),
                                ('정답', '$correct', Icons.check_circle_rounded),
                                (
                                  '최고 콤보',
                                  '$bestCombo',
                                  Icons.local_fire_department_rounded,
                                ),
                                ('획득 XP', '+$xp', Icons.bolt_rounded),
                              ];
                              return GridView.count(
                                crossAxisCount: compact ? 2 : 4,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: compact ? 1.55 : 1.15,
                                children: [
                                  for (final metric in metrics)
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: colors.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              metric.$3,
                                              color: colors.primary,
                                              size: 21,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              metric.$2,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleLarge,
                                            ),
                                            Text(
                                              metric.$1,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      if (challengeScore case final score?) ...[
                        const SizedBox(height: 12),
                        Card(
                          key: const Key('completion-challenge-score'),
                          color: colors.tertiaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(Icons.speed_rounded),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '도전 점수 ${score.total}점',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(
                                        '정확도 ${score.accuracyPoints}/70 · '
                                        '속도 ${score.speedPoints}/20 · '
                                        '힌트 ${score.hintPoints}/10 · '
                                        '평균 ${(score.averageResponseTimeMs / 1000).toStringAsFixed(1)}초',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (attemptMetrics.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final mastery = StudyMasterySnapshot.fromAttempts(
                              attemptMetrics,
                            );
                            final measured = [
                              for (final skill in StudySkill.values)
                                if (mastery.bySkill[skill]!.attempts > 0)
                                  mastery.bySkill[skill]!,
                            ];
                            return Card(
                              key: const Key('completion-skill-mastery'),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      '이번 세션 유형별 결과',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        for (final skill in measured)
                                          Chip(
                                            label: Text(
                                              '${skill.skill.koreanLabel} '
                                              '${(skill.score * 100).round()}% · '
                                              '${(skill.averageResponseTimeMs / 1000).toStringAsFixed(1)}초',
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      if (wrong > 0 && examReport == null) ...[
                        const SizedBox(height: 12),
                        Text(
                          '틀린 문제 $wrong개는 복습 일정에 반영했어요.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        key: const Key('completion-action-line'),
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ActionChip(
                              key: const Key('completion-action-exit'),
                              avatar: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('종료'),
                              onPressed: onHome,
                            ),
                            if (hasMistakes && onRetryMistakes != null) ...[
                              const SizedBox(width: 8),
                              ActionChip(
                                key: const Key('completion-action-wrong'),
                                avatar: const Icon(
                                  Icons.replay_rounded,
                                  size: 18,
                                ),
                                label: const Text('틀린 문제 복습'),
                                onPressed: onRetryMistakes,
                              ),
                            ],
                            const SizedBox(width: 8),
                            ActionChip(
                              key: const Key('completion-action-schedule'),
                              avatar: const Icon(Icons.event_rounded, size: 18),
                              label: const Text('다음 예약'),
                              onPressed: onScheduleNext,
                            ),
                            if (timeRecommendation
                                case final recommendation?) ...[
                              const SizedBox(width: 8),
                              ActionChip(
                                key: const Key(
                                  'completion-action-routine-time',
                                ),
                                avatar: const Icon(
                                  Icons.schedule_rounded,
                                  size: 18,
                                ),
                                label: Text('루틴 ${recommendation.label} 적용'),
                                onPressed: onApplyRoutineTime,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const Key('completion-review-attempts'),
                          onPressed: attempts.isEmpty
                              ? null
                              : () => showFocusRestoringBottomSheet<void>(
                                  context: context,
                                  showDragHandle: true,
                                  isScrollControlled: true,
                                  builder: (context) => CompletionReviewSheet(
                                    attempts: attempts,
                                    onOpenItem: onOpenItem,
                                  ),
                                ),
                          icon: const Icon(Icons.fact_check_outlined),
                          label: Text('문제별 결과 ${attempts.length}개 보기'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (hasMistakes && onRetryMistakes != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('completion-retry-mistakes'),
                            onPressed: onRetryMistakes,
                            icon: const Icon(Icons.replay_rounded),
                            label: const Text('틀린 문제만 다시 풀기'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (onReplaySame != null && onReplayShuffled != null)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key('completion-replay-same'),
                                onPressed: onReplaySame,
                                icon: const Icon(Icons.replay_rounded),
                                label: const Text('같은 순서'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key('completion-replay-shuffled'),
                                onPressed: onReplayShuffled,
                                icon: const Icon(Icons.shuffle_rounded),
                                label: const Text('새로 섞기'),
                              ),
                            ),
                          ],
                        ),
                      if (onNextPlaylist case final onNextGame?) ...[
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('completion-next-playlist-game'),
                            onPressed: onNextGame,
                            icon: const Icon(Icons.queue_play_next_rounded),
                            label: Text(
                              '${playlistProgressLabel ?? '플레이리스트'} · 다음 게임',
                            ),
                          ),
                        ),
                      ],
                      if (onNextRecommended case final onNext?) ...[
                        if (hasMistakes) const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: hasMistakes
                              ? OutlinedButton.icon(
                                  key: const Key('completion-next-recommended'),
                                  onPressed: onNext,
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  label: const Text('다음 추천 학습'),
                                )
                              : FilledButton.icon(
                                  key: const Key('completion-next-recommended'),
                                  onPressed: onNext,
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  label: const Text('다음 추천 학습'),
                                ),
                        ),
                      ],
                      if (!hasMistakes &&
                          onNextRecommended == null &&
                          onNextPlaylist == null)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('completion-return'),
                            onPressed: onHome,
                            icon: Icon(returnIcon),
                            label: Text(returnLabel),
                          ),
                        )
                      else ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            key: const Key('completion-return'),
                            onPressed: onHome,
                            icon: Icon(returnIcon),
                            label: Text(returnLabel),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CompletionReceiptCard extends StatelessWidget {
  const _CompletionReceiptCard({required this.receipt});

  final StudyCompletionReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      key: const Key('completion-local-receipt'),
      container: true,
      label: receipt.semanticsLabel,
      child: ExcludeSemantics(
        child: Card(
          color: colors.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      receipt.saved
                          ? Icons.task_alt_rounded
                          : Icons.sync_rounded,
                      color: receipt.saved ? colors.primary : colors.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '기기 저장 내역',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Text(receipt.saved ? '저장 완료' : '저장 중'),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.schedule_rounded, size: 18),
                      label: Text(receipt.savedTimeLabel),
                    ),
                    Chip(
                      avatar: const Icon(Icons.bolt_rounded, size: 18),
                      label: Text('+${receipt.earnedXp} XP'),
                    ),
                    Chip(
                      avatar: const Icon(
                        Icons.local_fire_department_rounded,
                        size: 18,
                      ),
                      label: Text('연속 ${receipt.streakDays}일'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.save_outlined, size: 18),
                      label: Text(receipt.localSaveLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SentenceOrderInput extends StatelessWidget {
  const _SentenceOrderInput({
    required this.selected,
    required this.remaining,
    required this.enabled,
    required this.onSelectedTap,
    required this.onRemainingTap,
    required this.onUndo,
    required this.onReset,
    required this.showShortcutHints,
  });

  final List<String> selected;
  final List<String> remaining;
  final bool enabled;
  final ValueChanged<int> onSelectedTap;
  final ValueChanged<int> onRemainingTap;
  final VoidCallback onUndo;
  final VoidCallback onReset;
  final bool showShortcutHints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: selected.isEmpty
              ? Center(
                  child: Text(
                    showShortcutHints
                        ? '아래 단어를 누르거나 숫자키 1~9로 문장을 만드세요'
                        : '아래 단어를 눌러 문장을 만드세요',
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (index, token) in selected.indexed)
                      ActionChip(
                        onPressed: enabled ? () => onSelectedTap(index) : null,
                        label: Text(token),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final (index, token) in remaining.indexed)
              ActionChip(
                onPressed: enabled ? () => onRemainingTap(index) : null,
                label: Text(
                  showShortcutHints && index < 9
                      ? '${index + 1} · $token'
                      : token,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              key: const Key('undo-sentence-token'),
              onPressed: enabled && selected.isNotEmpty ? onUndo : null,
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('한 칸 되돌리기'),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              key: const Key('reset-sentence-order'),
              onPressed: enabled && selected.isNotEmpty ? onReset : null,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('처음부터'),
            ),
          ],
        ),
        if (showShortcutHints)
          Text(
            '1~9 선택 · Backspace 되돌리기 · Ctrl+Backspace 초기화 · Enter 제출',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.shortcut,
    required this.showShortcut,
    required this.label,
    required this.selected,
    required this.submitted,
    required this.correctAnswer,
    required this.minimumHeight,
    required this.onPressed,
    super.key,
  });

  final String shortcut;
  final bool showShortcut;
  final String label;
  final bool selected;
  final bool submitted;
  final bool correctAnswer;
  final double minimumHeight;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceTransparency = StudyAccessibilityTheme.of(
      context,
    ).reduceTransparency;
    final showCorrect = submitted && correctAnswer;
    final showWrong = submitted && selected && !correctAnswer;
    final accent = showCorrect
        ? const Color(0xFF238B57)
        : showWrong
        ? const Color(0xFFC2414B)
        : selected
        ? colors.primary
        : colors.outline;
    final background = showCorrect
        ? const Color(0xFFE8F5ED)
        : showWrong
        ? const Color(0xFFFFECEE)
        : selected
        ? colors.primaryContainer
        : colors.surface;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(minimumHeight),
        alignment: Alignment.centerLeft,
        backgroundColor: background,
        foregroundColor: colors.onSurface,
        disabledForegroundColor: colors.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        side: BorderSide(color: accent, width: selected || showCorrect ? 2 : 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          if (showShortcut) ...[
            Container(
              key: const Key('study-choice-shortcut'),
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: reduceTransparency
                    ? colors.surfaceContainerHighest
                    : accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                shortcut,
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (showCorrect)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF238B57))
          else if (showWrong)
            const Icon(Icons.cancel_rounded, color: Color(0xFFC2414B))
          else if (selected)
            Icon(Icons.radio_button_checked_rounded, color: colors.primary),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.correct,
    required this.answer,
    required this.userAnswer,
    required this.item,
    required this.readingAidsLabel,
    required this.usedHint,
    required this.combo,
    required this.rating,
    required this.correctionLabel,
    required this.recordProgress,
    required this.favorite,
    required this.feedbackDetail,
    required this.encouragementTone,
    required this.celebrationLevel,
    required this.onSpeak,
    required this.onToggleFavorite,
  });

  final bool correct;
  final String answer;
  final String userAnswer;
  final LearningItem item;
  final String readingAidsLabel;
  final bool usedHint;
  final int combo;
  final ReviewRating rating;
  final String? correctionLabel;
  final bool recordProgress;
  final bool favorite;
  final AppFeedbackDetail feedbackDetail;
  final AppEncouragementTone encouragementTone;
  final AppCelebrationLevel celebrationLevel;
  final VoidCallback onSpeak;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceTransparency = StudyAccessibilityTheme.of(
      context,
    ).reduceTransparency;
    final color = correct ? const Color(0xFF238B57) : colors.error;
    final resultSurface = reduceTransparency
        ? correct
              ? colors.primaryContainer
              : colors.errorContainer
        : color.withValues(alpha: 0.09);
    final resultForeground = reduceTransparency
        ? correct
              ? colors.onPrimaryContainer
              : colors.onErrorContainer
        : color;
    final xp = recordProgress
        ? switch (rating) {
            ReviewRating.again => 5,
            ReviewRating.hard => 8,
            ReviewRating.good => 10,
            ReviewRating.easy => 15,
          }
        : 0;
    final calmTitle = correctionLabel != null
        ? '$correctionLabel · 바꾼 결과를 반영할게요'
        : correct
        ? usedHint
              ? '힌트를 보고 맞혔어요'
              : combo >= 3
              ? '$combo콤보! 흐름이 좋아요'
              : combo == 2
              ? '2콤보! 감을 잡았어요'
              : '정답이에요'
        : userAnswer.trim().isEmpty
        ? '지금 정답을 익혀 두세요'
        : '답을 비교해 보세요';
    final title = switch (encouragementTone) {
      AppEncouragementTone.calm => calmTitle,
      AppEncouragementTone.playful when correctionLabel != null =>
        '$correctionLabel! 결과를 바꿨어요',
      AppEncouragementTone.playful
          when correct && celebrationLevel == AppCelebrationLevel.off =>
        combo >= 3 ? '$combo콤보! 계속 이어가요' : '좋아요, 정답!',
      AppEncouragementTone.playful when correct && combo >= 3 =>
        '🔥 $combo콤보! 계속 달려요',
      AppEncouragementTone.playful when correct => '🎉 좋아요, 정답!',
      AppEncouragementTone.playful => '💪 한 번 더 보면 기억나요',
      AppEncouragementTone.minimal when correct => '정답',
      AppEncouragementTone.minimal => '다시 확인',
    };
    return Semantics(
      key: const Key('study-feedback-result'),
      label: correct ? '정답. $title' : '오답. $title',
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: resultSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: reduceTransparency ? 2 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...[
                    DecoratedBox(
                      key: Key(
                        !correct || celebrationLevel == AppCelebrationLevel.off
                            ? 'feedback-result-icon'
                            : celebrationLevel == AppCelebrationLevel.full
                            ? 'feedback-celebration-full'
                            : 'feedback-celebration-subtle',
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(
                          alpha: reduceTransparency ? 1 : 0.12,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(
                        dimension:
                            correct &&
                                celebrationLevel == AppCelebrationLevel.subtle
                            ? 30
                            : 36,
                        child: Icon(
                          correct ? Icons.check_rounded : Icons.refresh_rounded,
                          color: reduceTransparency ? colors.surface : color,
                          size:
                              correct &&
                                  celebrationLevel == AppCelebrationLevel.subtle
                              ? 17
                              : 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: resultForeground,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    recordProgress ? '+$xp XP' : '진도 비기록',
                    style: TextStyle(
                      color: resultForeground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              if (!correct)
                _FeedbackAnswerRow(
                  label: '내 답',
                  value: userAnswer.trim().isEmpty ? '모르겠어요' : userAnswer,
                ),
              if (!correct) const SizedBox(height: 7),
              _FeedbackAnswerRow(label: '정답', value: answer, emphasized: true),
              if (feedbackDetail != AppFeedbackDetail.concise &&
                  readingAidsLabel.isNotEmpty) ...[
                const SizedBox(height: 7),
                _FeedbackAnswerRow(label: '읽기', value: readingAidsLabel),
              ],
              if (feedbackDetail != AppFeedbackDetail.concise &&
                  item.primaryTranslation.trim().isNotEmpty &&
                  item.primaryTranslation != answer) ...[
                const SizedBox(height: 7),
                _FeedbackAnswerRow(label: '뜻', value: item.primaryTranslation),
              ],
              if (feedbackDetail != AppFeedbackDetail.concise &&
                  (item.example ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 7),
                _FeedbackAnswerRow(
                  label: '예문',
                  value:
                      '${item.example}'
                      '${(item.exampleTranslation ?? '').trim().isEmpty ? '' : '\n${item.exampleTranslation}'}',
                ),
              ],
              if (feedbackDetail != AppFeedbackDetail.concise) ...[
                const SizedBox(height: 11),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: reduceTransparency
                        ? colors.surface
                        : colors.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    correct
                        ? correctionLabel != null
                              ? '다음 문제로 갈 때 바꾼 결과만 한 번 기록해요.'
                              : usedHint
                              ? '힌트를 사용해 “어려움”으로 기록했어요. 곧 다시 복습해요.'
                              : '잘 기억해서 다음 복습까지 간격이 늘어났어요.'
                        : recordProgress
                        ? '이 표현은 뒤에서 다시 나와요. 세 번 안에 떠올릴 수 있도록 도와드릴게요.'
                        : '이번 결과만 보여 주고 XP와 복습 일정은 바꾸지 않아요.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              if (feedbackDetail == AppFeedbackDetail.coach) ...[
                const SizedBox(height: 8),
                _FeedbackCoachTip(
                  correct: correct,
                  usedHint: usedHint,
                  hasExample: (item.example ?? '').trim().isNotEmpty,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    key: const Key('feedback-listen-again'),
                    onPressed: onSpeak,
                    icon: const Icon(Icons.volume_up_rounded, size: 18),
                    label: const Text('다시 듣기'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    key: const Key('feedback-toggle-favorite'),
                    onPressed: onToggleFavorite,
                    icon: Icon(
                      favorite ? Icons.star_rounded : Icons.star_border_rounded,
                    ),
                    label: Text(favorite ? '저장됨' : '저장'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackCoachTip extends StatelessWidget {
  const _FeedbackCoachTip({
    required this.correct,
    required this.usedHint,
    required this.hasExample,
  });

  final bool correct;
  final bool usedHint;
  final bool hasExample;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceTransparency = StudyAccessibilityTheme.of(
      context,
    ).reduceTransparency;
    final message = correct
        ? usedHint
              ? '다음에는 힌트를 보기 전에 3초만 더 떠올려 보세요.'
              : '소리 내어 한 번 말하면 더 오래 기억할 수 있어요.'
        : hasExample
        ? '예문 속 장면과 정답을 함께 떠올려 보세요.'
        : '정답을 본 뒤 가리고 바로 한 번 말해 보세요.';
    return Container(
      key: const Key('study-feedback-coach-tip'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: reduceTransparency
            ? colors.secondaryContainer
            : colors.secondaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: colors.onSecondaryContainer),
      ),
    );
  }
}

class _FeedbackAnswerRow extends StatelessWidget {
  const _FeedbackAnswerRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceTransparency = StudyAccessibilityTheme.of(
      context,
    ).reduceTransparency;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: emphasized
            ? reduceTransparency
                  ? colors.primaryContainer
                  : colors.primaryContainer.withValues(alpha: 0.72)
            : reduceTransparency
            ? colors.surface
            : colors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingQuizResponse {
  _PendingQuizResponse({
    required this.item,
    required this.originalAttempt,
    required this.currentAttempt,
    required this.previousCombo,
    required this.previousBestCombo,
    required this.previousFailureCount,
    required this.wasWrong,
    required this.wasFinalCorrect,
    required this.metric,
  });

  final LearningItem item;
  final QuizAttemptReview originalAttempt;
  QuizAttemptReview currentAttempt;
  final int previousCombo;
  final int previousBestCombo;
  final int previousFailureCount;
  final bool wasWrong;
  final bool wasFinalCorrect;
  final StudyAttemptMetric metric;
  bool retryAppended = false;
}

String _answerDirectionLabel(StudyAnswerDirection direction) =>
    switch (direction) {
      StudyAnswerDirection.learningToMeaning => '학습어 → 한국어',
      StudyAnswerDirection.meaningToLearning => '한국어 → 학습어',
      StudyAnswerDirection.mixed => '양방향',
    };

class _SessionQuizOptionsSheet extends StatefulWidget {
  const _SessionQuizOptionsSheet({required this.mode, required this.initial});

  final StudyMode mode;
  final QuizSessionOptions initial;

  @override
  State<_SessionQuizOptionsSheet> createState() =>
      _SessionQuizOptionsSheetState();
}

class _SessionQuizOptionsSheetState extends State<_SessionQuizOptionsSheet> {
  late QuizSessionOptions _options;

  @override
  void initState() {
    super.initState();
    _options = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '이번 세션 설정',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                const Text('앱 전체 설정은 그대로 두고 이번 세션에만 적용해요.'),
                const SizedBox(height: 20),
                _OptionSection(
                  title: '다음 문제 선택',
                  description: _options.strategy.description,
                  children: [
                    for (final strategy in StudySessionStrategy.values)
                      ChoiceChip(
                        key: Key('session-strategy-${strategy.name}'),
                        label: Text(strategy.koreanLabel),
                        selected: _options.strategy == strategy,
                        onSelected: (_) => setState(
                          () =>
                              _options = _options.copyWith(strategy: strategy),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _OptionSection(
                  title: '출제 방향',
                  description: widget.mode.answerDirectionExplanation,
                  children: widget.mode.allowsAnswerDirectionOverride
                      ? [
                          for (final direction in StudyAnswerDirection.values)
                            ChoiceChip(
                              key: Key('session-direction-${direction.name}'),
                              label: Text(_answerDirectionLabel(direction)),
                              selected: _options.answerDirection == direction,
                              onSelected: (_) => setState(
                                () => _options = _options.copyWith(
                                  answerDirection: direction,
                                ),
                              ),
                            ),
                        ]
                      : [
                          Chip(
                            key: const Key('session-direction-locked'),
                            avatar: const Icon(Icons.lock_outline_rounded),
                            label: Text(
                              _answerDirectionLabel(
                                widget.mode.effectiveFixedAnswerDirection,
                              ),
                            ),
                          ),
                        ],
                ),
                const SizedBox(height: 16),
                _OptionSection(
                  title: '채점 강도',
                  description: _options.gradingStrength.description,
                  children: [
                    for (final strength in StudyGradingStrictness.values)
                      ChoiceChip(
                        key: Key('session-grading-${strength.name}'),
                        label: Text(strength.koreanLabel),
                        selected: _options.gradingStrength == strength,
                        onSelected: (_) => setState(
                          () => _options = _options.copyWith(
                            gradingStrength: strength,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _OptionSection(
                  title: '입력 프로필',
                  description: _options.inputProfile.description,
                  children: [
                    for (final profile in PracticeInputProfile.values)
                      ChoiceChip(
                        key: Key('session-input-profile-${profile.name}'),
                        avatar: Icon(
                          profile == PracticeInputProfile.accessible
                              ? Icons.accessibility_new_rounded
                              : Icons.touch_app_rounded,
                          size: 18,
                        ),
                        label: Text(profile.koreanLabel),
                        selected: _options.inputProfile == profile,
                        onSelected: (_) => setState(
                          () => _options = _options.copyWith(
                            inputProfile: profile,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _OptionSection(
                  title: '난이도 자동 조절',
                  description: _options.liveDifficultyLock == null
                      ? '최근 5문제의 정답률, 속도, 힌트 사용에 맞춰 다음 문제를 조절해요.'
                      : '${_options.liveDifficultyLock!.koreanLabel} 난이도를 이 세션에 고정합니다.',
                  children: [
                    ChoiceChip(
                      key: const Key('session-difficulty-auto'),
                      label: const Text('자동'),
                      selected: _options.liveDifficultyLock == null,
                      onSelected: (_) => setState(
                        () => _options = _options.copyWith(
                          liveDifficultyLock: null,
                        ),
                      ),
                    ),
                    for (final level in LiveDifficultyLevel.values)
                      ChoiceChip(
                        key: Key('session-difficulty-${level.name}'),
                        label: Text(level.koreanLabel),
                        selected: _options.liveDifficultyLock == level,
                        onSelected: (_) => setState(
                          () => _options = _options.copyWith(
                            liveDifficultyLock: level,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _OptionSection(
                  title: '읽기 표시',
                  description: '현재 세션에서만 보조 읽기 표기를 켜거나 끕니다.',
                  children: [
                    FilterChip(
                      key: const Key('session-korean-reading'),
                      label: const Text('한글 읽기'),
                      selected: _options.showKoreanReading,
                      onSelected: (selected) => setState(
                        () => _options = _options.copyWith(
                          showKoreanReading: selected,
                        ),
                      ),
                    ),
                    FilterChip(
                      key: const Key('session-native-reading'),
                      label: const Text('원어 읽기'),
                      selected: _options.showNativeReading,
                      onSelected: (selected) => setState(
                        () => _options = _options.copyWith(
                          showNativeReading: selected,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _OptionSection(
                  title: 'TTS 속도',
                  description:
                      '이번 세션 ${_options.ttsRate.toStringAsFixed(2)}배 · 앱 음성 설정은 그대로예요.',
                  children: [
                    SizedBox(
                      width: 560,
                      child: Slider(
                        key: const Key('session-tts-rate'),
                        value: _options.ttsRate.clamp(0.2, 0.8),
                        min: 0.2,
                        max: 0.8,
                        divisions: 12,
                        label: _options.ttsRate.toStringAsFixed(2),
                        onChanged: (value) => setState(
                          () => _options = _options.copyWith(ttsRate: value),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _OptionSection(
                  title: '휴식 알림',
                  description: _options.breakReminderMinutes == 0
                      ? '이번 세션의 휴식 알림을 끕니다.'
                      : '${_options.breakReminderMinutes}분마다 답안을 저장하고 안전한 휴식을 제안합니다.',
                  children: [
                    for (final minutes in const [0, 10, 20, 30])
                      ChoiceChip(
                        key: Key('session-break-$minutes'),
                        label: Text(minutes == 0 ? '끄기' : '$minutes분'),
                        selected: _options.breakReminderMinutes == minutes,
                        onSelected: (_) => setState(
                          () => _options = _options.copyWith(
                            breakReminderMinutes: minutes,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const Key('apply-session-quiz-options'),
                  onPressed: () => Navigator.pop(context, _options),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('이 세션에 적용'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudyQueuePreviewSheet extends StatelessWidget {
  const _StudyQueuePreviewSheet({
    required this.preview,
    required this.strategy,
  });

  final StudyQueuePreview preview;
  final StudySessionStrategy strategy;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              key: const Key('study-queue-preview-sheet'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '남은 문제 미리보기',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  '${strategy.koreanLabel} · 남은 ${preview.total}문제 · '
                  '단어 ${preview.wordCount} · 문장 ${preview.sentenceCount} '
                  '(${preview.sentencePercent}%)',
                  key: const Key('study-queue-preview-summary'),
                ),
                const SizedBox(height: 5),
                Text(
                  '문제와 정답은 실제로 풀 때 보여 드려요.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (preview.entries.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('남은 문제가 없습니다.'),
                    ),
                  )
                else
                  for (final entry in preview.entries.take(30))
                    Card(
                      key: Key('study-queue-preview-${entry.sequence}'),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${entry.sequence}')),
                        title: Text(
                          '${entry.skill.koreanLabel} · '
                          '${entry.kind == LearningItemKind.word ? '단어' : '문장'}',
                        ),
                        subtitle: Text(entry.reason),
                        trailing: const Icon(Icons.lock_outline_rounded),
                      ),
                    ),
                if (preview.entries.length > 30) ...[
                  const SizedBox(height: 8),
                  Text(
                    '나머지 ${preview.entries.length - 30}문제도 세션에서 이어서 나와요.',
                    textAlign: TextAlign.center,
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

class _OptionSection extends StatelessWidget {
  const _OptionSection({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: '$title. $description',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}

class _MatchSprintResult {
  const _MatchSprintResult({required this.score, required this.elapsedMs});

  final int score;
  final int elapsedMs;
}

class _MatchSprintDialog extends StatefulWidget {
  const _MatchSprintDialog({required this.deck, required this.allowTimedMode});

  final MatchSprintDeck deck;
  final bool allowTimedMode;

  @override
  State<_MatchSprintDialog> createState() => _MatchSprintDialogState();
}

class _MatchSprintDialogState extends State<_MatchSprintDialog> {
  late final List<MatchSprintPair> _learningPairs;
  late final List<MatchSprintPair> _meaningPairs;
  var _matchState = const SequentialMatchState();
  String _matchAnnouncement = '먼저 표현을 하나 선택하세요.';
  MatchSprintMode _mode = MatchSprintMode.tenPairs;
  Timer? _timer;
  var _remainingSeconds = 60;
  var _started = false;
  var _finished = false;
  DateTime? _startedAt;

  Set<String> get _matchedIds => _matchState.matchedIds;
  int get _mistakes => _matchState.mistakes;
  MatchSprintPair? get _selectedLearning {
    final id = _matchState.selectedLearningId;
    if (id == null) return null;
    for (final pair in _learningPairs) {
      if (pair.itemId == id) return pair;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _learningPairs = [...widget.deck.pairs];
    _meaningPairs = [...widget.deck.pairs]
      ..shuffle(Random(_deckSeed(widget.deck.pairs)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _started = true;
      _remainingSeconds = 60;
      _startedAt = DateTime.now();
    });
    if (_mode != MatchSprintMode.timed) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _finished = true;
        });
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _selectLearning(MatchSprintPair pair) {
    if (_finished || _matchedIds.contains(pair.itemId)) return;
    final transition = _matchState.selectLearning(pair.itemId);
    setState(() {
      _matchState = transition.state;
      _matchAnnouncement = '“${pair.learningText}” 표현을 골랐습니다. 이제 맞는 뜻을 선택하세요.';
    });
  }

  void _selectMeaning(MatchSprintPair pair) {
    if (_finished ||
        !_matchState.awaitingMeaning ||
        _matchedIds.contains(pair.itemId)) {
      return;
    }
    final selected = _selectedLearning;
    final transition = _matchState.selectMeaning(pair.itemId);
    setState(() {
      _matchState = transition.state;
      if (transition.outcome == SequentialMatchOutcome.matched) {
        _matchAnnouncement = '정답입니다. 다음 표현을 선택하세요.';
        if (_matchedIds.length == widget.deck.pairs.length) {
          _finished = true;
          _timer?.cancel();
        }
      } else {
        _matchAnnouncement =
            '“${selected?.learningText ?? ''}”와 “${pair.meaningText}”은 짝이 아닙니다. 표현부터 다시 선택하세요.';
      }
    });
    SemanticsService.sendAnnouncement(
      View.of(context),
      _matchAnnouncement,
      Directionality.of(context),
    );
  }

  _MatchSprintResult get _result {
    final elapsedMs = max(
      1,
      DateTime.now().difference(_startedAt ?? DateTime.now()).inMilliseconds,
    );
    final completionScore = widget.deck.pairs.isEmpty
        ? 0
        : (_matchedIds.length / widget.deck.pairs.length * 100).round();
    final score = _mode == MatchSprintMode.timed
        ? completionScore
        : (completionScore - _mistakes * 5).clamp(0, 100);
    return _MatchSprintResult(score: score, elapsedMs: elapsedMs);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: min(760, MediaQuery.sizeOf(context).width - 32),
        height: min(720, MediaQuery.sizeOf(context).height - 32),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '매치 스프린트',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        Navigator.pop(context, _finished ? _result : null),
                    tooltip: '닫기',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (!_started) ...[
                const Text('표현과 뜻을 한 쌍씩 연결하세요. 학습 자료와 복습 일정은 바뀌지 않아요.'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      key: const Key('match-mode-ten-pairs'),
                      label: const Text('10쌍 · 시간 제한 없음'),
                      selected: _mode == MatchSprintMode.tenPairs,
                      onSelected: (_) =>
                          setState(() => _mode = MatchSprintMode.tenPairs),
                    ),
                    if (widget.allowTimedMode)
                      ChoiceChip(
                        key: const Key('match-mode-timed'),
                        label: const Text('60초 도전'),
                        selected: _mode == MatchSprintMode.timed,
                        onSelected: (_) =>
                            setState(() => _mode = MatchSprintMode.timed),
                      ),
                  ],
                ),
                if (!widget.allowTimedMode) ...[
                  const SizedBox(height: 8),
                  const Text('편한 입력 모드에서는 시간 제한이 없어요.'),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('begin-match-sprint'),
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('${widget.deck.pairs.length}쌍 시작'),
                ),
              ] else ...[
                Row(
                  children: [
                    Text(
                      '${_matchedIds.length}/${widget.deck.pairs.length}쌍',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const Spacer(),
                    Text(
                      _mode == MatchSprintMode.timed
                          ? '$_remainingSeconds초'
                          : '실수 $_mistakes회',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_finished) ...[
                  Semantics(
                    key: const Key('match-sequence-status'),
                    liveRegion: true,
                    container: true,
                    label: _matchAnnouncement,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _matchAnnouncement,
                        style: TextStyle(color: colors.onPrimaryContainer),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_finished)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _matchedIds.length == widget.deck.pairs.length
                                ? Icons.emoji_events_rounded
                                : Icons.timer_off_outlined,
                            size: 58,
                            color: colors.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _matchedIds.length == widget.deck.pairs.length
                                ? '모든 쌍을 연결했어요'
                                : '60초 도전을 마쳤어요',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 5),
                          Text('성공 ${_matchedIds.length}쌍 · 실수 $_mistakes회'),
                          const SizedBox(height: 18),
                          FilledButton(
                            key: const Key('close-match-result'),
                            onPressed: () => Navigator.pop(context, _result),
                            child: const Text('퀴즈로 돌아가기'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _MatchColumn(
                              title: '표현',
                              pairs: _learningPairs,
                              matchedIds: _matchedIds,
                              selectedId: _selectedLearning?.itemId,
                              enabled: true,
                              semanticRole: '표현',
                              keyPrefix: 'learning',
                              traversalOrder: 1,
                              labelOf: (pair) => pair.learningText,
                              onSelect: _selectLearning,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MatchColumn(
                              title: '뜻',
                              pairs: _meaningPairs,
                              matchedIds: _matchedIds,
                              selectedId: null,
                              enabled: _matchState.awaitingMeaning,
                              semanticRole: '뜻',
                              keyPrefix: 'meaning',
                              traversalOrder: 2,
                              labelOf: (pair) => pair.meaningText,
                              onSelect: _selectMeaning,
                            ),
                          ),
                        ],
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

class _MatchColumn extends StatelessWidget {
  const _MatchColumn({
    required this.title,
    required this.pairs,
    required this.matchedIds,
    required this.selectedId,
    required this.enabled,
    required this.semanticRole,
    required this.keyPrefix,
    required this.traversalOrder,
    required this.labelOf,
    required this.onSelect,
  });

  final String title;
  final List<MatchSprintPair> pairs;
  final Set<String> matchedIds;
  final String? selectedId;
  final bool enabled;
  final String semanticRole;
  final String keyPrefix;
  final double traversalOrder;
  final String Function(MatchSprintPair pair) labelOf;
  final ValueChanged<MatchSprintPair> onSelect;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalOrder(
      order: NumericFocusOrder(traversalOrder),
      child: Semantics(
        container: true,
        label: '$semanticRole 선택 단계${enabled ? '' : '. 표현을 먼저 선택하세요'}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final pair in pairs) ...[
              Semantics(
                selected: selectedId == pair.itemId,
                label:
                    '$semanticRole ${labelOf(pair)}. ${matchedIds.contains(pair.itemId)
                        ? '연결 완료'
                        : enabled
                        ? '선택 가능'
                        : '현재 단계에서 선택할 수 없음'}',
                child: OutlinedButton(
                  key: Key('match-$keyPrefix-${pair.itemId}'),
                  onPressed: !enabled || matchedIds.contains(pair.itemId)
                      ? null
                      : () => onSelect(pair),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: selectedId == pair.itemId
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    alignment: Alignment.center,
                  ),
                  child: Text(
                    matchedIds.contains(pair.itemId) ? '✓' : labelOf(pair),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 7),
            ],
          ],
        ),
      ),
    );
  }
}

int _deckSeed(List<MatchSprintPair> pairs) {
  var seed = 17;
  for (final pair in pairs) {
    for (final unit in pair.itemId.codeUnits) {
      seed = (seed * 37 + unit) & 0x7fffffff;
    }
  }
  return seed;
}

enum _RepairAction { edit, memoryHint, exclude, continueStudy }

class _RepairOptionsSheet extends StatelessWidget {
  const _RepairOptionsSheet({
    required this.item,
    required this.editable,
    required this.hasMemoryHint,
  });

  final LearningItem item;
  final bool editable;
  final bool hasMemoryHint;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('자꾸 틀리는 이유 확인'),
              subtitle: Text('“${item.text}”을 다시 풀기 전에 어려웠던 부분을 확인해 보세요.'),
            ),
            ListTile(
              key: const Key('repair-edit-content'),
              leading: const Icon(Icons.edit_rounded),
              title: Text(editable ? '문제 수정' : '교정 메모 작성'),
              subtitle: Text(
                editable
                    ? '문제와 정답을 고친 뒤 지금 세션을 이어가요.'
                    : '기본 언어팩은 그대로 두고 내 제안만 따로 저장해요.',
              ),
              onTap: () => Navigator.pop(context, _RepairAction.edit),
            ),
            ListTile(
              key: const Key('repair-memory-hint'),
              leading: const Icon(Icons.lightbulb_outline_rounded),
              title: Text(hasMemoryHint ? '암기 단서 수정' : '암기 단서 추가'),
              subtitle: const Text('나만의 짧은 기억 단서를 저장해요.'),
              onTap: () => Navigator.pop(context, _RepairAction.memoryHint),
            ),
            ListTile(
              key: const Key('repair-exclude-item'),
              leading: const Icon(Icons.pause_circle_outline_rounded),
              title: const Text('잠시 제외'),
              subtitle: const Text('다음 학습부터 이 표현은 나오지 않아요.'),
              onTap: () => Navigator.pop(context, _RepairAction.exclude),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward_rounded),
              title: const Text('계속 학습'),
              onTap: () => Navigator.pop(context, _RepairAction.continueStudy),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryHintDialog extends StatefulWidget {
  const _MemoryHintDialog({required this.item, required this.initialHint});

  final LearningItem item;
  final String initialHint;

  @override
  State<_MemoryHintDialog> createState() => _MemoryHintDialogState();
}

class _MemoryHintDialogState extends State<_MemoryHintDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialHint);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final reading = item.readingAidsLabel.trim();
    final example = item.example?.trim() ?? '';
    final translation = item.exampleTranslation?.trim() ?? '';
    return AlertDialog(
      title: const Text('암기 단서 편집'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _FeedbackAnswerRow(label: '표현', value: item.text, emphasized: true),
            const SizedBox(height: 8),
            _FeedbackAnswerRow(label: '뜻', value: item.primaryTranslation),
            if (reading.isNotEmpty) ...[
              const SizedBox(height: 8),
              _FeedbackAnswerRow(label: '읽기', value: reading),
            ],
            if (example.isNotEmpty) ...[
              const SizedBox(height: 8),
              _FeedbackAnswerRow(
                label: '예문',
                value: '$example${translation.isEmpty ? '' : '\n$translation'}',
              ),
            ],
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              _FeedbackAnswerRow(label: '태그', value: item.tags.join(', ')),
            ],
            const SizedBox(height: 14),
            TextField(
              key: const Key('memory-hint-input'),
              controller: _controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 240,
              decoration: const InputDecoration(
                labelText: '내 암기 단서',
                hintText: '예: 공항에서 탑승구를 다시 물을 때 쓰는 문장',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('save-memory-hint'),
          onPressed: () => Navigator.pop(
            context,
            _MemoryHintEditResult(_controller.text.trim()),
          ),
          child: Text(_controller.text.trim().isEmpty ? '비우기' : '저장'),
        ),
      ],
    );
  }
}

class _CustomContentEditDialog extends StatefulWidget {
  const _CustomContentEditDialog({required this.item});

  final LearningItem item;

  @override
  State<_CustomContentEditDialog> createState() =>
      _CustomContentEditDialogState();
}

class _CustomContentEditDialogState extends State<_CustomContentEditDialog> {
  late final TextEditingController _questionController;
  late final TextEditingController _answerController;

  @override
  void initState() {
    super.initState();
    _questionController = TextEditingController(text: widget.item.text);
    _answerController = TextEditingController(
      text: widget.item.primaryTranslation,
    );
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  void _save() {
    final question = _questionController.text.trim();
    final answer = _answerController.text.trim();
    if (question.isEmpty || answer.isEmpty) return;
    Navigator.pop(
      context,
      _CustomContentEditResult(question: question, answer: answer),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('quiz-custom-content-editor'),
      title: const Text('학습 자료 수정'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('quiz-edit-question'),
              controller: _questionController,
              autofocus: true,
              maxLength: 500,
              decoration: const InputDecoration(labelText: '문제 · 표현'),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('quiz-edit-answer'),
              controller: _answerController,
              maxLength: 500,
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(labelText: '대표 정답 · 뜻'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('save-quiz-custom-content'),
          onPressed: _save,
          child: const Text('수정하고 계속'),
        ),
      ],
    );
  }
}

class _BaseCorrectionEditDialog extends StatefulWidget {
  const _BaseCorrectionEditDialog({required this.item, required this.existing});

  final LearningItem item;
  final ContentCorrection? existing;

  @override
  State<_BaseCorrectionEditDialog> createState() =>
      _BaseCorrectionEditDialogState();
}

class _BaseCorrectionEditDialogState extends State<_BaseCorrectionEditDialog> {
  late final TextEditingController _proposalController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _proposalController = TextEditingController(
      text:
          widget.existing?.proposedValue ??
          '${widget.item.text} → ${widget.item.primaryTranslation}',
    );
    _noteController = TextEditingController(text: widget.existing?.note ?? '');
  }

  @override
  void dispose() {
    _proposalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final proposal = _proposalController.text.trim();
    final note = _noteController.text.trim();
    if (proposal.isEmpty || note.isEmpty) return;
    Navigator.pop(
      context,
      _BaseCorrectionEditResult(proposedValue: proposal, note: note),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('base-content-correction-editor'),
      title: const Text('기본 언어팩 교정 메모'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '원본은 바뀌지 않아요. 내 제안은 이 항목에 따로 저장되어 나중에 다시 고칠 수 있어요.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('base-correction-proposal'),
                controller: _proposalController,
                autofocus: true,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: '제안 내용'),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('base-correction-note'),
                controller: _noteController,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(labelText: '왜 수정이 필요한가요?'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('save-base-content-correction'),
          onPressed: _save,
          child: const Text('교정 메모 저장'),
        ),
      ],
    );
  }
}

class _MemoryHintEditResult {
  const _MemoryHintEditResult(this.value);

  final String value;
}

class _CustomContentEditResult {
  const _CustomContentEditResult({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}

class _BaseCorrectionEditResult {
  const _BaseCorrectionEditResult({
    required this.proposedValue,
    required this.note,
  });

  final String proposedValue;
  final String note;
}

@visibleForTesting
class CompletionReviewSheet extends StatefulWidget {
  const CompletionReviewSheet({
    required this.attempts,
    required this.onOpenItem,
    super.key,
  });

  final List<QuizAttemptReview> attempts;
  final ValueChanged<String> onOpenItem;

  @override
  State<CompletionReviewSheet> createState() => _CompletionReviewSheetState();
}

class _CompletionReviewSheetState extends State<CompletionReviewSheet> {
  var _wrongOnly = false;

  @override
  Widget build(BuildContext context) {
    final visible = _wrongOnly
        ? widget.attempts.where((attempt) => !attempt.correct).toList()
        : widget.attempts;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.86,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '문제별 결과 확인',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      FilterChip(
                        key: const Key('completion-review-wrong-only'),
                        selected: _wrongOnly,
                        label: const Text('틀린 문제만'),
                        onSelected: (value) =>
                            setState(() => _wrongOnly = value),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(child: Text('다시 볼 틀린 문제가 없어요.'))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final attempt = visible[index];
                            return Card(
                              child: ExpansionTile(
                                key: Key(
                                  'completion-attempt-${attempt.sequence}',
                                ),
                                leading: Icon(
                                  attempt.correct
                                      ? Icons.check_circle_rounded
                                      : Icons.cancel_rounded,
                                  color: attempt.correct
                                      ? const Color(0xFF238B57)
                                      : Theme.of(context).colorScheme.error,
                                ),
                                title: Text(
                                  '${attempt.sequence}. ${attempt.prompt}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  attempt.correctionLabel ??
                                      (attempt.usedHint
                                          ? '힌트 사용'
                                          : attempt.exerciseType),
                                ),
                                childrenPadding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  14,
                                ),
                                children: [
                                  _FeedbackAnswerRow(
                                    label: '내 답',
                                    value: attempt.userAnswer.trim().isEmpty
                                        ? '모르겠어요'
                                        : attempt.userAnswer,
                                  ),
                                  const SizedBox(height: 7),
                                  _FeedbackAnswerRow(
                                    label: '정답',
                                    value: attempt.expectedAnswer,
                                    emphasized: true,
                                  ),
                                  const SizedBox(height: 9),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      key: Key(
                                        'completion-edit-${attempt.sequence}',
                                      ),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        widget.onOpenItem(attempt.itemId);
                                      },
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('자료 확인하기'),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
