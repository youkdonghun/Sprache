import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/services/app_clock.dart';
import 'package:sprache/src/services/window_workspace_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:window_manager/window_manager.dart';

const _outputDirectory = String.fromEnvironment(
  'WINDOWS_RUNTIME_VISUAL_OUTPUT',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Windows engine renders and navigates at minimum, focus, and standard sizes',
    timeout: const Timeout(Duration(minutes: 3)),
    (tester) async {
      expect(defaultTargetPlatform, TargetPlatform.windows);
      expect(
        _outputDirectory,
        isNotEmpty,
        reason:
            'WINDOWS_RUNTIME_VISUAL_OUTPUT dart-define must point to an '
            'absolute output directory.',
      );

      await windowManager.ensureInitialized();
      await windowManager.setResizable(true);
      await windowManager.setMinimumSize(const Size(380, 520));
      addTearDown(() async {
        await windowManager.setSize(const Size(1040, 760), animate: false);
        await windowManager.setAlwaysOnTop(false);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            appClockProvider.overrideWithValue(() => DateTime(2026, 7, 29, 12)),
          ],
          child: const SpracheApp(),
        ),
      );
      await _pumpUntilHydrated(tester);

      await _resize(tester, const Size(380, 520));
      expect(find.text('오늘 학습'), findsOneWidget);
      expect(find.text('다음 학습'), findsOneWidget);
      expect(find.byKey(const Key('window-compact-toggle')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _captureFlutterView(tester, 'minimum-home-380x520.png');

      await tester.tap(find.byKey(const Key('nav-learn')));
      await tester.pumpAndSettle();
      expect(find.text('영어 학습실'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _captureFlutterView(tester, 'minimum-practice-380x520.png');

      await tester.tap(find.byKey(const Key('nav-home')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('window-compact-toggle')));
      await _pumpUntilWorkspaceState(tester, compact: true);
      final focusSize = await windowManager.getSize();
      expect(focusSize.width, closeTo(420, 2));
      expect(focusSize.height, closeTo(640, 2));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      expect(container.read(windowWorkspaceControllerProvider).compact, isTrue);
      expect(tester.takeException(), isNull);
      await _captureFlutterView(tester, 'focus-home-420x640.png');

      await tester.tap(find.byKey(const Key('window-compact-toggle')));
      await _pumpUntilWorkspaceState(tester, compact: false);
      expect(
        container.read(windowWorkspaceControllerProvider).compact,
        isFalse,
      );
      await _resize(tester, const Size(1040, 760));
      expect(find.textContaining('오늘의'), findsWidgets);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byIcon(Icons.home_rounded), findsWidgets);
      expect(tester.takeException(), isNull);
      await _captureFlutterView(tester, 'standard-home-1040x760.png');

      await tester.tap(find.byKey(const Key('nav-settings')));
      await tester.pumpAndSettle();
      expect(find.text('환경설정'), findsOneWidget);
      expect(find.byKey(const Key('local-folder-status')), findsOneWidget);
      expect(find.textContaining('앱 전용 DB에는 계속 저장됩니다'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _captureFlutterView(tester, 'standard-settings-1040x760.png');
    },
  );
}

Future<void> _pumpUntilHydrated(WidgetTester tester) async {
  for (var attempt = 0; attempt < 60; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 250));
    final appFinder = find.byType(SpracheApp);
    if (appFinder.evaluate().isNotEmpty) {
      final container = ProviderScope.containerOf(tester.element(appFinder));
      if (container.read(appControllerProvider).isHydrated) {
        await tester.pumpAndSettle();
        return;
      }
    }
  }
  fail('Windows UI did not hydrate within 15 seconds.');
}

Future<void> _pumpUntilWorkspaceState(
  WidgetTester tester, {
  required bool compact,
}) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 100));
    final appFinder = find.byType(SpracheApp);
    if (appFinder.evaluate().isEmpty) continue;
    final container = ProviderScope.containerOf(tester.element(appFinder));
    final workspace = container.read(windowWorkspaceControllerProvider);
    if (!workspace.busy && workspace.compact == compact) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Windows workspace did not reach compact=$compact within 10 seconds.');
}

Future<void> _resize(WidgetTester tester, Size requested) async {
  await windowManager.setSize(requested, animate: false);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
  final actual = await windowManager.getSize();
  expect(actual.width, closeTo(requested.width, 2));
  expect(actual.height, closeTo(requested.height, 2));
}

Future<void> _captureFlutterView(WidgetTester tester, String fileName) async {
  await tester.pumpAndSettle();
  final renderView = tester.binding.renderViews.single;
  final layer = renderView.debugLayer;
  expect(layer, isA<OffsetLayer>());
  final image = await (layer! as OffsetLayer).toImage(
    renderView.paintBounds,
    pixelRatio: 1,
  );
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(data, isNotNull);
    final bytes = data!.buffer.asUint8List();
    expect(bytes.length, greaterThan(10000));
    final directory = Directory(_outputDirectory);
    await directory.create(recursive: true);
    await File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    ).writeAsBytes(bytes, flush: true);
  } finally {
    image.dispose();
  }
}
