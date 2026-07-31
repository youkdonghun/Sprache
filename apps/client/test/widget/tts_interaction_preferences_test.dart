import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/flashcard_screen.dart';
import 'package:sprache/src/screens/mission_screen.dart';
import 'package:sprache/src/screens/pronunciation_screen.dart';
import 'package:sprache/src/screens/unit_guide_screen.dart';
import 'package:sprache/src/services/tts_service.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  const preferences = StudyPreferences(
    ttsRate: 0.63,
    interaction: StudyInteractionPreferences(
      autoPlayQuestionAudio: true,
      autoPlayAnswerAudio: true,
      preferOfflineVoice: false,
      audioRepeatCount: 2,
    ),
  );

  testWidgets(
    'flashcards apply automatic question and answer audio preferences',
    (tester) async {
      final platform = _RecordingTtsPlatform();
      final service = TtsService(platform: platform);

      await _pumpHydratedScreen(
        tester,
        const FlashcardScreen(kind: FlashcardKind.words),
        preferences: preferences,
        ttsService: service,
      );

      expect(platform.spoken, hasLength(2));
      expect(platform.rates, [0.63]);
      expect(platform.voices.single['name'], 'English cloud');

      await tester.tap(find.byKey(const Key('reveal-flashcard')));
      await tester.pumpAndSettle();

      expect(platform.spoken, hasLength(4));
      expect(platform.rates, [0.63, 0.63]);
      expect(
        platform.voices.map((voice) => voice['name']),
        everyElement('English cloud'),
      );
    },
  );

  testWidgets('missions apply automatic question and answer audio', (
    tester,
  ) async {
    final platform = _RecordingTtsPlatform();
    final service = TtsService(platform: platform);

    await _pumpHydratedScreen(
      tester,
      const MissionPracticeScreen(unitIndex: 0),
      preferences: preferences,
      ttsService: service,
    );

    expect(platform.spoken, hasLength(2));

    await tester.tap(find.byKey(const Key('mission-reveal')));
    await tester.pumpAndSettle();

    expect(platform.spoken, hasLength(4));
  });

  testWidgets('pronunciation practice automatically plays each prompt', (
    tester,
  ) async {
    final platform = _RecordingTtsPlatform();
    final service = TtsService(platform: platform);

    await _pumpHydratedScreen(
      tester,
      const PronunciationScreen(),
      preferences: preferences,
      ttsService: service,
    );

    expect(platform.spoken, hasLength(2));
    expect(platform.rates, [0.63]);
  });

  testWidgets('unit guide manual playback uses voice and repeat preferences', (
    tester,
  ) async {
    final platform = _RecordingTtsPlatform();
    final service = TtsService(platform: platform);

    await _pumpHydratedScreen(
      tester,
      const UnitGuideScreen(unitIndex: 0),
      preferences: preferences,
      ttsService: service,
    );

    await tester.tap(find.byTooltip(RegExp('발음 듣기')).first);
    await tester.pumpAndSettle();

    expect(platform.spoken, hasLength(2));
    expect(platform.rates, [0.63]);
    expect(platform.voices.single['name'], 'English cloud');
  });

  testWidgets('flashcards show native reading without Korean pronunciation', (
    tester,
  ) async {
    final platform = _RecordingTtsPlatform();

    await _pumpHydratedScreen(
      tester,
      const FlashcardScreen(kind: FlashcardKind.words),
      preferences: const StudyPreferences(
        interaction: StudyInteractionPreferences(
          showKoreanReading: false,
          showNativeReading: true,
        ),
      ),
      profile: _japaneseProfile,
      customItems: const [_japaneseReadingItem],
      ttsService: TtsService(platform: platform),
    );

    await tester.tap(find.byKey(const Key('reveal-flashcard')));
    await tester.pumpAndSettle();

    expect(find.textContaining('にほんごテスト'), findsOneWidget);
    expect(find.textContaining('nihongo tesuto'), findsOneWidget);
    expect(find.text('니혼고 테스트'), findsNothing);
  });

  testWidgets('flashcards show Korean pronunciation without native reading', (
    tester,
  ) async {
    final platform = _RecordingTtsPlatform();

    await _pumpHydratedScreen(
      tester,
      const FlashcardScreen(kind: FlashcardKind.words),
      preferences: const StudyPreferences(
        interaction: StudyInteractionPreferences(
          showKoreanReading: true,
          showNativeReading: false,
        ),
      ),
      profile: _japaneseProfile,
      customItems: const [_japaneseReadingItem],
      ttsService: TtsService(platform: platform),
    );

    await tester.tap(find.byKey(const Key('reveal-flashcard')));
    await tester.pumpAndSettle();

    expect(find.text('니혼고 테스트'), findsOneWidget);
    expect(find.textContaining('にほんごテスト'), findsNothing);
    expect(find.textContaining('nihongo tesuto'), findsNothing);
  });
}

Future<void> _pumpHydratedScreen(
  WidgetTester tester,
  Widget screen, {
  required StudyPreferences preferences,
  required TtsService ttsService,
  StoredProfile? profile,
  Iterable<LearningItem> customItems = const [],
}) async {
  final store = MemoryStudyStore(profile: profile, preferences: preferences);
  if (customItems.isNotEmpty) {
    await store.saveCustomItems(customItems);
  }
  final controller = AppController(store);
  for (var attempt = 0; attempt < 20; attempt++) {
    if (controller.state.isHydrated) break;
    await tester.pump();
  }
  expect(controller.state.isHydrated, isTrue);

  late final Widget injectedScreen;
  if (screen is FlashcardScreen) {
    injectedScreen = FlashcardScreen(
      kind: screen.kind,
      unitIndex: screen.unitIndex,
      customPlan: screen.customPlan,
      ttsService: ttsService,
    );
  } else if (screen is MissionPracticeScreen) {
    injectedScreen = MissionPracticeScreen(
      unitIndex: screen.unitIndex,
      ttsService: ttsService,
    );
  } else if (screen is PronunciationScreen) {
    injectedScreen = PronunciationScreen(
      unitIndex: screen.unitIndex,
      customPlan: screen.customPlan,
      ttsService: ttsService,
    );
  } else if (screen is UnitGuideScreen) {
    injectedScreen = UnitGuideScreen(
      unitIndex: screen.unitIndex,
      ttsService: ttsService,
    );
  } else {
    throw ArgumentError.value(screen, 'screen');
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studyStoreProvider.overrideWithValue(store),
        appControllerProvider.overrideWith((ref) => controller),
      ],
      child: MaterialApp(home: injectedScreen),
    ),
  );
  await tester.pumpAndSettle();
}

const _japaneseProfile = StoredProfile(
  selectedLanguage: LanguageTag.japanese,
  totalXp: 0,
  streakDays: 0,
  dailyXp: 0,
  badges: {},
  driveConnected: false,
  progress: {},
);

const _japaneseReadingItem = LearningItem(
  id: 'tts-reading-preference-ja',
  kind: LearningItemKind.word,
  learningLanguage: LanguageTag.japanese,
  text: '日本語テスト',
  translations: ['일본어 테스트'],
  acceptedAnswers: ['일본어 테스트'],
  readings: [
    Reading(scheme: ReadingScheme.hangul, value: '니혼고 테스트'),
    Reading(scheme: ReadingScheme.kana, value: 'にほんごテスト'),
    Reading(scheme: ReadingScheme.romaji, value: 'nihongo tesuto'),
  ],
  priority: 10,
);

class _RecordingTtsPlatform implements TtsPlatformAdapter {
  final List<String> languages = [];
  final List<Map<String, String>> voices = [];
  final List<double> rates = [];
  final List<String> spoken = [];
  int stopCount = 0;

  @override
  Future<List<Object?>> loadVoices() async => [
    {
      'name': 'English offline',
      'locale': 'en-US',
      'network_required': false,
      'quality': 100,
    },
    {
      'name': 'English cloud',
      'locale': 'en-US',
      'network_required': true,
      'quality': 500,
    },
  ];

  @override
  Future<void> setLanguage(String locale) async {
    languages.add(locale);
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    rates.add(rate);
  }

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    voices.add(voice);
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}
