import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final defaultGoldenComparator = goldenFileComparator;
  if (defaultGoldenComparator is LocalFileComparator) {
    goldenFileComparator = _TolerantLocalFileComparator(
      defaultGoldenComparator.basedir.resolve('flutter_test_config.dart'),
    );
  }
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

class _TolerantLocalFileComparator extends LocalFileComparator {
  _TolerantLocalFileComparator(super.testFile);

  // Hosted Windows runners can differ by a handful of anti-aliased edge
  // pixels. This still rejects any visual change larger than 0.02%.
  static const double _maxDiffRate = 0.0002;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _maxDiffRate) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw TestFailure(error);
  }
}
