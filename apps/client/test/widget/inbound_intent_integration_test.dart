import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/import_screen.dart';
import 'package:sprache/src/screens/stats_screen.dart';
import 'package:sprache/src/services/platform_inbound_intent_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/pending_import_state.dart';

void main() {
  testWidgets(
    'OS launch file is validated, read, and handed to the import preview',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.reset);
      final source = _FakeInboundIntentSource(
        file: InboundFilePayload(
          name: 'words.json',
          bytes: Uint8List.fromList(
            utf8.encode('[{"type":"word","term":"water","meaning":"물"}]'),
          ),
        ),
      );
      addTearDown(source.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(
              MemoryStudyStore(
                preferences: const StudyPreferences(onboardingCompleted: true),
              ),
            ),
            platformInboundIntentSourceProvider.overrideWithValue(source),
          ],
          child: const SpracheApp(launchArguments: ['C:\\Study\\words.json']),
        ),
      );
      await _pumpUntil(tester, find.byType(ImportScreen));

      expect(find.byType(ImportScreen), findsOneWidget);
      expect(source.readUris.single.scheme, 'file');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('runtime deep link uses the allowlisted app router', (
    tester,
  ) async {
    final source = _FakeInboundIntentSource();
    addTearDown(source.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studyStoreProvider.overrideWithValue(
            MemoryStudyStore(
              preferences: const StudyPreferences(onboardingCompleted: true),
            ),
          ),
          platformInboundIntentSourceProvider.overrideWithValue(source),
        ],
        child: const SpracheApp(),
      ),
    );
    await tester.pumpAndSettle();

    source.emit('sprache://route/stats');
    await _pumpUntil(tester, find.byType(StatsScreen));

    expect(find.byType(StatsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'runtime file is consumed when the import screen is already open',
    (tester) async {
      final source = _FakeInboundIntentSource(
        file: InboundFilePayload(
          name: 'runtime.json',
          bytes: Uint8List.fromList(
            utf8.encode('[{"type":"word","term":"safe","meaning":"안전"}]'),
          ),
        ),
      );
      addTearDown(source.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(
              MemoryStudyStore(
                preferences: const StudyPreferences(onboardingCompleted: true),
              ),
            ),
            platformInboundIntentSourceProvider.overrideWithValue(source),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      source.emit('sprache://route/import');
      await _pumpUntil(tester, find.byType(ImportScreen));
      source.emit('file:///C:/Study/runtime.json');
      for (var frame = 0; frame < 40 && source.readUris.isEmpty; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(source.readUris.single.path, '/C:/Study/runtime.json');
      await tester.pump(const Duration(milliseconds: 50));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ImportScreen)),
      );
      expect(container.read(pendingImportFileProvider), isNull);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 120,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

class _FakeInboundIntentSource implements PlatformInboundIntentSource {
  _FakeInboundIntentSource({this.file});

  final InboundFilePayload? file;
  final StreamController<String> _controller = StreamController.broadcast();
  final List<Uri> readUris = [];

  @override
  Stream<String> get intents => _controller.stream;

  @override
  Future<String?> initialIntent() async => null;

  @override
  Future<InboundFilePayload> readFile(Uri uri) async {
    readUris.add(uri);
    return file ??
        InboundFilePayload(name: 'empty.json', bytes: Uint8List.fromList([1]));
  }

  void emit(String raw) => _controller.add(raw);

  Future<void> close() => _controller.close();
}
