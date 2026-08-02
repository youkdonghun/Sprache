import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/device_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/settings_screen.dart';
import 'package:sprache/src/services/tts_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/device_preferences_state.dart';

void main() {
  testWidgets(
    'device voice card selects, previews, and saves feedback levels',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1100, 900);
      final platform = _PreviewTtsPlatform([
        {'name': 'English A', 'locale': 'en-US', 'network_required': false},
        {'name': 'English B', 'locale': 'en-GB', 'network_required': true},
      ]);
      final store = MemoryStudyStore(
        preferences: const StudyPreferences(onboardingCompleted: true),
      );

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(store),
              deviceTtsServiceProvider.overrideWithValue(
                TtsService(platform: platform),
              ),
            ],
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final card = find.byKey(const Key('device-feedback-preferences-card'));
        await tester.scrollUntilVisible(
          card,
          360,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(card, findsOneWidget);
        expect(find.text('2개 설치 음성'), findsOneWidget);
        expect(find.byKey(const Key('device-voice-pitch')), findsOneWidget);
        expect(find.byKey(const Key('device-sound-strength')), findsOneWidget);
        expect(find.byKey(const Key('device-haptic-strength')), findsOneWidget);

        final voice = find.byKey(const Key('device-installed-voice'));
        await tester.ensureVisible(voice);
        await tester.tap(voice);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('English B').last);
        await tester.pumpAndSettle();
        var saved = await store.loadDevicePreferences();
        expect(saved.voice.voiceIdByLanguage['en'], 'en-gb::English B');

        final pitch = find.byKey(const Key('device-voice-pitch'));
        await tester.ensureVisible(pitch);
        await tester.drag(pitch, const Offset(120, 0));
        await tester.pumpAndSettle();
        saved = await store.loadDevicePreferences();
        expect(saved.voice.pitch, greaterThan(1));

        final preview = find.byKey(const Key('preview-device-voice'));
        await tester.ensureVisible(preview);
        await tester.tap(preview);
        await tester.pumpAndSettle();
        expect(platform.voices.last['name'], 'English B');
        expect(platform.pitches.last, saved.voice.pitch);
        expect(
          platform.spoken,
          contains('Hello. Let us learn together today.'),
        );
        expect(find.text('미리 듣기를 재생했습니다.'), findsOneWidget);

        await tester.ensureVisible(
          find.byKey(const Key('device-sound-strength')),
        );
        await tester.tap(find.byKey(const Key('device-sound-strength')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('강하게').last);
        await tester.pumpAndSettle();
        saved = await store.loadDevicePreferences();
        expect(saved.voice.soundStrength, DeviceFeedbackStrength.strong);

        await tester.ensureVisible(
          find.byKey(const Key('device-haptic-strength')),
        );
        await tester.tap(find.byKey(const Key('device-haptic-strength')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('끔').last);
        await tester.pumpAndSettle();
        saved = await store.loadDevicePreferences();
        expect(saved.voice.hapticStrength, DeviceFeedbackStrength.off);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );
}

class _PreviewTtsPlatform
    implements TtsPlatformAdapter, TtsPitchPlatformAdapter {
  _PreviewTtsPlatform(this.rawVoices);

  final List<Object?> rawVoices;
  final List<Map<String, String>> voices = [];
  final List<double> pitches = [];
  final List<String> spoken = [];

  @override
  Future<List<Object?>> loadVoices() async => rawVoices;

  @override
  Future<void> setLanguage(String locale) async {}

  @override
  Future<void> setPitch(double pitch) async => pitches.add(pitch);

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> setVoice(Map<String, String> voice) async => voices.add(voice);

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}
