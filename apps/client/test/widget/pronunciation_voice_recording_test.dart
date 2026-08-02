import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_subject.dart';
import 'package:sprache/src/screens/flashcard_screen.dart';
import 'package:sprache/src/screens/pronunciation_screen.dart';
import 'package:sprache/src/services/temporary_voice_recording_service.dart';
import 'package:sprache/src/services/tts_service.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets(
    'pronunciation ladder records locally, replays, and clears before next item',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final voice = _FakeVoiceRecordingService();
      final store = MemoryStudyStore(
        profile: _profile,
        preferences: _preferences,
      );
      await store.saveCustomItems(_items);

      try {
        await _pumpHydrated(
          tester,
          store,
          PronunciationScreen(
            ttsService: TtsService(platform: _NoopTtsPlatform()),
            voiceRecordingService: voice,
          ),
        );

        for (final stage in [
          'listen',
          'slowListen',
          'repeat',
          'localRecording',
          'hint',
          'context',
        ]) {
          expect(find.byKey(Key('pronunciation-stage-$stage')), findsOneWidget);
        }

        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('pronunciation-stage-localRecording')),
            )
            .onSelected!(true);
        await tester.pump();

        tester
            .widget<FilledButton>(
              find.byKey(const Key('pronunciation-local-record')),
            )
            .onPressed!();
        await tester.pump();
        expect(voice.isRecording, isTrue);

        tester
            .widget<FilledButton>(
              find.byKey(const Key('pronunciation-local-record')),
            )
            .onPressed!();
        await tester.pump();
        expect(voice.hasRecording, isTrue);

        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('pronunciation-local-playback')),
            )
            .onPressed!();
        await tester.pump();
        expect(voice.playCalls, 1);

        tester
            .widget<ActionChip>(find.byKey(const Key('pronunciation-ab-0.75')))
            .onPressed!();
        await tester.pump();
        expect(voice.playCalls, 2);

        await tester.tap(find.byKey(const Key('pronunciation-mic')));
        await tester.pumpAndSettle();
        final clearsBeforeNext = voice.clearCalls;
        await tester.tap(find.byKey(const Key('pronunciation-self-passed')));
        await tester.pump();

        expect(find.text('테스트 둘'), findsOneWidget);
        expect(voice.clearCalls, greaterThan(clearsBeforeNext));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(voice.disposeCalls, 1);
        expect(voice.hasRecording, isFalse);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('privacy-safe pronunciation history can be cleared in place', (
    tester,
  ) async {
    final store = MemoryStudyStore(
      profile: _profile,
      preferences: _preferences,
    );
    await store.saveCustomItems(_items);
    await store.saveStudySession(
      StudySessionSummary(
        sessionId: 'pronunciation-history',
        courseId: 'subject:general:practice-flags',
        startedAt: DateTime.utc(2026, 8, 2, 9),
        endedAt: DateTime.utc(2026, 8, 2, 9, 2),
        correctCount: 1,
        wrongCount: 0,
        earnedXp: 10,
        mode: StudyMode.pronunciation,
        pronunciationMetrics: [
          PronunciationAttemptMetric(
            score: 87,
            recordedAt: DateTime.utc(2026, 8, 2, 9, 1),
            method: PronunciationEvaluationMethod.speechRecognition,
          ),
        ],
      ),
    );

    await _pumpHydrated(
      tester,
      store,
      PronunciationScreen(
        ttsService: TtsService(platform: _NoopTtsPlatform()),
        voiceRecordingService: _FakeVoiceRecordingService(),
      ),
    );
    expect(
      find.byKey(const Key('pronunciation-score-history')),
      findsOneWidget,
    );
    expect(find.textContaining('원문, 인식 문장, 음성 파일은 기록하지 않습니다'), findsOneWidget);

    final clear = find.byKey(const Key('clear-pronunciation-history'));
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pronunciation-score-history')), findsNothing);
    expect(store.savedSessions.single.pronunciationMetrics, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'custom flashcards save recovery flags and no-progress practice stays local',
    (tester) async {
      final recordedStore = MemoryStudyStore(
        profile: _profile,
        preferences: _preferences.copyWith(
          sessionPlan: const StudySessionPlan(
            subjectId: 'general:practice-flags',
            mode: StudyMode.words,
            itemLimit: 1,
            historyFilter: StudyHistoryFilter.excludeCorrect,
            backlogRecovery: BacklogRecoverySettings(
              enabled: true,
              dailyLimit: 5,
            ),
          ),
        ),
      );
      await recordedStore.saveCustomItems(_items);
      await _pumpHydrated(
        tester,
        recordedStore,
        FlashcardScreen(
          kind: FlashcardKind.words,
          customPlan: true,
          ttsService: TtsService(platform: _NoopTtsPlatform()),
        ),
      );

      await tester.tap(find.byKey(const Key('reveal-flashcard')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('flashcard-remembered')));
      await tester.pumpAndSettle();

      expect(recordedStore.savedSessions, hasLength(1));
      final summary = recordedStore.savedSessions.single;
      expect(summary.recordProgress, isTrue);
      expect(summary.backlogRecovery, isTrue);
      expect(summary.historyFilter, StudyHistoryFilter.excludeCorrect);
      expect(summary.mode, StudyMode.words);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      final unrecordedStore = MemoryStudyStore(
        profile: _profile,
        preferences: _preferences.copyWith(
          sessionPlan: const StudySessionPlan(
            subjectId: 'general:practice-flags',
            mode: StudyMode.words,
            itemLimit: 1,
            recordProgress: false,
          ),
        ),
      );
      await unrecordedStore.saveCustomItems(_items);
      await _pumpHydrated(
        tester,
        unrecordedStore,
        FlashcardScreen(
          kind: FlashcardKind.words,
          customPlan: true,
          ttsService: TtsService(platform: _NoopTtsPlatform()),
        ),
      );

      await tester.tap(find.byKey(const Key('reveal-flashcard')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('flashcard-remembered')));
      await tester.pumpAndSettle();

      expect(unrecordedStore.savedEvents, isEmpty);
      expect(unrecordedStore.savedSessions, isEmpty);
    },
  );
}

Future<void> _pumpHydrated(
  WidgetTester tester,
  MemoryStudyStore store,
  Widget screen,
) async {
  final controller = AppController(store);
  for (var attempt = 0; attempt < 20; attempt++) {
    if (controller.state.isHydrated) break;
    await tester.pump();
  }
  expect(controller.state.isHydrated, isTrue);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studyStoreProvider.overrideWithValue(store),
        appControllerProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

const _subject = StudySubject(
  id: 'general:practice-flags',
  kind: StudySubjectKind.general,
  name: '연습 플래그',
  description: '',
  symbol: '말',
  contentLanguage: LanguageTag.japanese,
);

const _preferences = StudyPreferences(
  activeSubjectId: 'general:practice-flags',
  customSubjects: [_subject],
);

const _profile = StoredProfile(
  selectedLanguage: LanguageTag.japanese,
  totalXp: 0,
  streakDays: 0,
  dailyXp: 0,
  badges: {},
  driveConnected: false,
  progress: {},
);

const _items = [
  LearningItem(
    id: 'voice-practice-1',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.japanese,
    subjectId: 'general:practice-flags',
    text: 'テスト一',
    translations: ['테스트 하나'],
    acceptedAnswers: ['테스트 하나'],
    capabilities: {ExerciseCapability.listening},
    priority: 10,
  ),
  LearningItem(
    id: 'voice-practice-2',
    kind: LearningItemKind.word,
    learningLanguage: LanguageTag.japanese,
    subjectId: 'general:practice-flags',
    text: 'テスト二',
    translations: ['테스트 둘'],
    acceptedAnswers: ['테스트 둘'],
    capabilities: {ExerciseCapability.listening},
    priority: 9,
  ),
];

class _FakeVoiceRecordingService implements TemporaryVoiceRecordingService {
  bool _isRecording = false;
  bool _hasRecording = false;
  int clearCalls = 0;
  int playCalls = 0;
  int disposeCalls = 0;

  @override
  bool get hasRecording => _hasRecording;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<bool> start() async {
    await clear();
    _isRecording = true;
    return true;
  }

  @override
  Future<bool> stop() async {
    _isRecording = false;
    _hasRecording = true;
    return true;
  }

  @override
  Future<void> play() async {
    playCalls++;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    _isRecording = false;
    _hasRecording = false;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await clear();
  }
}

class _NoopTtsPlatform implements TtsPlatformAdapter {
  @override
  Future<List<Object?>> loadVoices() async => const [];

  @override
  Future<void> setLanguage(String locale) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> setVoice(Map<String, String> voice) async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}
