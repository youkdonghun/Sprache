import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'mobile ${brightness.name} subject symbol picker stays stable',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        tester.binding.platformDispatcher.platformBrightnessTestValue =
            brightness;

        try {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                studyStoreProvider.overrideWithValue(MemoryStudyStore()),
              ],
              child: const SpracheApp(),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('shell-mobile-subject-switcher')),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const Key('create-study-subject-from-shell-picker')),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('study-subject-symbol-categories')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'goldens/mobile-study-subject-picker-${brightness.name}.png',
            ),
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
          tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
          tester.view.reset();
        }
      },
    );
  }
}
