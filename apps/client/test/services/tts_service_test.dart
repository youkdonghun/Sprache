import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/services/tts_service.dart';

void main() {
  const selector = TtsVoiceSelector();

  test('normalizes locales and prefers an offline exact-locale voice', () {
    final selected = selector.select(LanguageTag.english, const [
      TtsVoice(
        name: 'Cloud US',
        locale: 'en_US',
        networkRequired: true,
        quality: 500,
      ),
      TtsVoice(
        name: 'Local US',
        locale: 'en-US',
        networkRequired: false,
        quality: 100,
      ),
      TtsVoice(
        name: 'Local GB',
        locale: 'en-GB',
        networkRequired: false,
        quality: 900,
      ),
    ]);

    expect(selected?.name, 'Local US');
    expect(normalizeTtsLocale(' ZH_hans_CN '), 'zh-hans-cn');
  });

  test('prefers simplified Chinese locales over traditional fallbacks', () {
    final selected = selector.select(LanguageTag.simplifiedChinese, const [
      TtsVoice(
        name: 'Traditional local',
        locale: 'zh-TW',
        networkRequired: false,
      ),
      TtsVoice(
        name: 'Simplified cloud',
        locale: 'zh-Hans',
        networkRequired: true,
      ),
      TtsVoice(name: 'English', locale: 'en-US', networkRequired: false),
    ]);

    expect(selected?.name, 'Simplified cloud');
  });

  test(
    'allows a higher-quality network voice when offline is not preferred',
    () {
      final selected = selector.select(LanguageTag.english, const [
        TtsVoice(
          name: 'Local',
          locale: 'en-US',
          networkRequired: false,
          quality: 100,
        ),
        TtsVoice(
          name: 'Cloud',
          locale: 'en-US',
          networkRequired: true,
          quality: 500,
        ),
      ], preferOfflineVoice: false);

      expect(selected?.name, 'Cloud');
    },
  );

  test(
    'returns locale-only fallback when no installed voice matches',
    () async {
      final platform = _FakeTtsPlatform([
        {'name': 'English', 'locale': 'en-US', 'network_required': false},
      ]);
      final service = TtsService(platform: platform);

      final selection = await service.configure(LanguageTag.japanese);

      expect(selection.locale, 'ja-JP');
      expect(selection.voice, isNull);
      expect(platform.languages, ['ja-JP']);
      expect(platform.voices, isEmpty);
    },
  );

  test('configures and speaks with the selected device-local voice', () async {
    final platform = _FakeTtsPlatform([
      {'name': 'Cloud', 'locale': 'de-DE', 'network_required': true},
      {'name': 'Offline', 'locale': 'de_DE', 'network_required': false},
    ]);
    final service = TtsService(platform: platform);

    final selection = await service.speak(
      language: LanguageTag.german,
      text: ' Guten Morgen ',
      rate: 2,
      repeatCount: 2,
    );

    expect(selection.voice?.name, 'Offline');
    expect(platform.languages, ['de-DE']);
    expect(platform.voices.single['name'], 'Offline');
    expect(platform.rates, [0.8]);
    expect(platform.spoken, ['Guten Morgen', 'Guten Morgen']);
    expect(platform.stopCount, 1);
  });
}

class _FakeTtsPlatform implements TtsPlatformAdapter {
  _FakeTtsPlatform(this.rawVoices);

  final List<Object?> rawVoices;
  final List<String> languages = [];
  final List<Map<String, String>> voices = [];
  final List<double> rates = [];
  final List<String> spoken = [];
  int stopCount = 0;

  @override
  Future<List<Object?>> loadVoices() async => rawVoices;

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
