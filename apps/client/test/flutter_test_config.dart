import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fontLoader = FontLoader('NotoSansKR')
    ..addFont(rootBundle.load('assets/fonts/NotoSansKR-Variable.ttf'));
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait([fontLoader.load(), iconLoader.load()]);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter_tts'),
        (call) async => switch (call.method) {
          'getLanguages' => <String>[
            'en-US',
            'ja-JP',
            'de-DE',
            'fr-FR',
            'es-ES',
            'zh-CN',
          ],
          'getVoices' => <Object?>[],
          _ => 1,
        },
      );
  await testMain();
}
