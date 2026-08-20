import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../domain/device_preferences.dart';
import '../domain/language.dart';

class TtsVoice {
  const TtsVoice({
    required this.name,
    required this.locale,
    this.networkRequired,
    this.quality = 0,
  });

  final String name;
  final String locale;
  final bool? networkRequired;
  final int quality;

  String get id => '${normalizeTtsLocale(locale)}::$name';

  Map<String, String> get platformValue => {'name': name, 'locale': locale};

  static TtsVoice? tryParse(Object? source) {
    if (source is! Map) return null;
    Object? read(String key) {
      for (final entry in source.entries) {
        if (entry.key.toString() == key) return entry.value;
      }
      return null;
    }

    final name = (read('name') ?? read('identifier'))?.toString().trim() ?? '';
    final locale = read('locale')?.toString().trim() ?? '';
    if (name.isEmpty || locale.isEmpty) return null;
    return TtsVoice(
      name: name,
      locale: locale,
      networkRequired: _optionalBool(
        read('network_required') ?? read('networkRequired'),
      ),
      quality: int.tryParse(read('quality')?.toString() ?? '') ?? 0,
    );
  }
}

class TtsVoiceSelector {
  const TtsVoiceSelector();

  TtsVoice? select(
    LanguageTag language,
    Iterable<TtsVoice> voices, {
    bool preferOfflineVoice = true,
  }) {
    final target = normalizeTtsLocale(language.ttsLocale);
    final candidates = voices
        .where((voice) => _localeRank(target, voice.locale) < _noLocaleMatch)
        .toList(growable: false);
    if (candidates.isEmpty) return null;
    candidates.sort((left, right) {
      final localeOrder = _localeRank(
        target,
        left.locale,
      ).compareTo(_localeRank(target, right.locale));
      if (localeOrder != 0) return localeOrder;
      if (preferOfflineVoice) {
        final networkOrder = _networkRank(
          left.networkRequired,
        ).compareTo(_networkRank(right.networkRequired));
        if (networkOrder != 0) return networkOrder;
      }
      final qualityOrder = right.quality.compareTo(left.quality);
      if (qualityOrder != 0) return qualityOrder;
      if (!preferOfflineVoice) {
        final networkOrder = _networkRank(
          left.networkRequired,
        ).compareTo(_networkRank(right.networkRequired));
        if (networkOrder != 0) return networkOrder;
      }
      return left.name.compareTo(right.name);
    });
    return candidates.first;
  }
}

class TtsVoiceSelection {
  const TtsVoiceSelection({required this.locale, this.voice});

  final String locale;
  final TtsVoice? voice;

  bool get usesInstalledVoice => voice != null;
}

abstract interface class TtsPlatformAdapter {
  Future<List<Object?>> loadVoices();

  Future<void> setLanguage(String locale);

  Future<void> setVoice(Map<String, String> voice);

  Future<void> setSpeechRate(double rate);

  Future<void> speak(String text);

  Future<void> stop();
}

abstract interface class TtsPitchPlatformAdapter {
  Future<void> setPitch(double pitch);
}

class FlutterTtsPlatformAdapter
    implements TtsPlatformAdapter, TtsPitchPlatformAdapter {
  FlutterTtsPlatformAdapter({FlutterTts? flutterTts})
    : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;
  var _awaitsCompletion = false;

  @override
  Future<List<Object?>> loadVoices() async {
    final voices = await _flutterTts.getVoices;
    if (voices is! Iterable<dynamic>) return const [];
    return List<Object?>.from(voices, growable: false);
  }

  @override
  Future<void> setLanguage(String locale) async {
    await _flutterTts.setLanguage(locale);
  }

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    await _flutterTts.setVoice(voice);
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }

  @override
  Future<void> speak(String text) async {
    if (!_awaitsCompletion) {
      await _flutterTts.awaitSpeakCompletion(true);
      _awaitsCompletion = true;
    }
    await _flutterTts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}

class TtsService {
  TtsService({
    required this.platform,
    this.selector = const TtsVoiceSelector(),
  });

  factory TtsService.device() =>
      TtsService(platform: FlutterTtsPlatformAdapter());

  final TtsPlatformAdapter platform;
  final TtsVoiceSelector selector;
  List<TtsVoice>? _voiceCache;
  Future<void> _speechTail = Future<void>.value();
  var _speechGeneration = 0;

  Future<List<TtsVoice>> installedVoices({bool refresh = false}) async {
    if (refresh) _voiceCache = null;
    return List.unmodifiable(_voiceCache ??= await _loadVoicesSafely());
  }

  Future<List<TtsVoice>> voicesFor(
    LanguageTag language, {
    bool refresh = false,
  }) async {
    final target = normalizeTtsLocale(language.ttsLocale);
    return [
      for (final voice in await installedVoices(refresh: refresh))
        if (_localeRank(target, voice.locale) < _noLocaleMatch) voice,
    ]..sort((left, right) {
      final localeOrder = _localeRank(
        target,
        left.locale,
      ).compareTo(_localeRank(target, right.locale));
      if (localeOrder != 0) return localeOrder;
      final networkOrder = _networkRank(
        left.networkRequired,
      ).compareTo(_networkRank(right.networkRequired));
      if (networkOrder != 0) return networkOrder;
      return left.name.compareTo(right.name);
    });
  }

  Future<TtsVoiceSelection> resolve(
    LanguageTag language, {
    bool refresh = false,
    bool preferOfflineVoice = true,
    String? preferredVoiceId,
  }) async {
    final voices = await installedVoices(refresh: refresh);
    TtsVoice? preferred;
    if (preferredVoiceId != null && preferredVoiceId.trim().isNotEmpty) {
      final target = normalizeTtsLocale(language.ttsLocale);
      for (final voice in voices) {
        if (voice.id == preferredVoiceId &&
            _localeRank(target, voice.locale) < _noLocaleMatch) {
          preferred = voice;
          break;
        }
      }
    }
    return TtsVoiceSelection(
      locale: language.ttsLocale,
      voice:
          preferred ??
          selector.select(
            language,
            voices,
            preferOfflineVoice: preferOfflineVoice,
          ),
    );
  }

  Future<TtsVoiceSelection> configure(
    LanguageTag language, {
    bool refresh = false,
    bool preferOfflineVoice = true,
    String? preferredVoiceId,
    double pitch = 1,
  }) async {
    final selection = await resolve(
      language,
      refresh: refresh,
      preferOfflineVoice: preferOfflineVoice,
      preferredVoiceId: preferredVoiceId,
    );
    await platform.setLanguage(selection.locale);
    final voice = selection.voice;
    if (voice != null) {
      try {
        await platform.setVoice(voice.platformValue);
      } catch (_) {
        // Some Windows engines expose a voice list but only support locale
        // selection. The language fallback remains usable in that case.
      }
    }
    final pitchAdapter = platform;
    if (pitchAdapter is TtsPitchPlatformAdapter) {
      try {
        await (pitchAdapter as TtsPitchPlatformAdapter).setPitch(
          normalizeNaturalVoicePitch(pitch),
        );
      } catch (_) {
        // Pitch is optional on some engines; selected voice remains usable.
      }
    }
    return selection;
  }

  Future<TtsVoiceSelection> speak({
    required LanguageTag language,
    required String text,
    double rate = 0.45,
    bool preferOfflineVoice = true,
    int repeatCount = 1,
    String? preferredVoiceId,
    double pitch = 1,
  }) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return Future<TtsVoiceSelection>.error(
        const FormatException('재생할 문장이 비어 있습니다.'),
      );
    }
    final generation = ++_speechGeneration;
    final completer = Completer<TtsVoiceSelection>();

    // Stop active playback immediately, then serialize configuration and
    // speech. This prevents autoplay and rapid taps from racing the same
    // platform voice engine and producing overlapping or broken audio.
    final interrupt = platform.stop();
    final previous = _speechTail;
    final operation = previous.then<void>((_) async {
      try {
        await interrupt;
        if (generation != _speechGeneration) {
          completer.complete(TtsVoiceSelection(locale: language.ttsLocale));
          return;
        }
        final selection = await configure(
          language,
          preferOfflineVoice: preferOfflineVoice,
          preferredVoiceId: preferredVoiceId,
          pitch: pitch,
        );
        if (generation != _speechGeneration) {
          completer.complete(selection);
          return;
        }
        await platform.setSpeechRate(rate.clamp(0.2, 0.8).toDouble());
        final repeats = repeatCount.clamp(1, 3);
        for (var index = 0; index < repeats; index++) {
          if (generation != _speechGeneration) break;
          await platform.speak(normalized);
        }
        completer.complete(selection);
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
    });
    _speechTail = operation.catchError((Object _) {});
    return completer.future;
  }

  Future<void> stop() {
    _speechGeneration += 1;
    return platform.stop();
  }

  Future<List<TtsVoice>> _loadVoicesSafely() async {
    try {
      final voices = <TtsVoice>[];
      for (final raw in await platform.loadVoices()) {
        final voice = TtsVoice.tryParse(raw);
        if (voice != null) voices.add(voice);
      }
      return voices;
    } catch (_) {
      return const [];
    }
  }
}

String normalizeTtsLocale(String value) => value
    .trim()
    .replaceAll('_', '-')
    .split('-')
    .where((part) => part.isNotEmpty)
    .join('-')
    .toLowerCase();

const _noLocaleMatch = 100;

int _localeRank(String normalizedTarget, String candidate) {
  final normalizedCandidate = normalizeTtsLocale(candidate);
  if (normalizedCandidate == normalizedTarget) return 0;
  final targetLanguage = normalizedTarget.split('-').first;
  final candidateParts = normalizedCandidate.split('-');
  if (candidateParts.first != targetLanguage) return _noLocaleMatch;
  if (targetLanguage == 'zh') {
    if (candidateParts.any(const {'hans', 'cn', 'sg'}.contains)) return 1;
    return 2;
  }
  return 1;
}

int _networkRank(bool? networkRequired) => switch (networkRequired) {
  false => 0,
  null => 1,
  true => 2,
};

bool? _optionalBool(Object? value) => switch (value) {
  final bool result => result,
  final num result => result != 0,
  final String result when result.toLowerCase() == 'true' => true,
  final String result when result.toLowerCase() == 'false' => false,
  _ => null,
};
