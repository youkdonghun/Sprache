import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/integrations/google/google_connection_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/connection_state.dart';

void main() {
  testWidgets('settings shows the last sync change and conflict review', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.3;

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(MemoryStudyStore()),
            googleConnectionServiceProvider.overrideWithValue(
              MockGoogleConnectionService(),
            ),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('shell-storage-status')), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-category-storage')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('connect-google')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('connect-google')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sync-merge-report')), findsOneWidget);
      final review = tester.widget<ExpansionTile>(
        find.byKey(const Key('sync-conflict-review')),
      );
      expect(review.initiallyExpanded, isFalse);
      expect(find.text('마지막 동기화'), findsOneWidget);
      expect(find.textContaining('↑'), findsWidgets);
      expect(
        tester.getSize(find.byKey(const Key('sync-merge-report'))).height,
        lessThan(120),
      );
      await tester.ensureVisible(find.byKey(const Key('open-sync-center')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-sync-center')));
      await tester.pumpAndSettle();
      expect(find.text('동기화 이력·충돌 복구'), findsOneWidget);
      expect(find.byKey(const Key('sync-policy-manual')), findsOneWidget);
      expect(find.byKey(const Key('copy-sync-diagnostics')), findsOneWidget);
      await tester.tap(find.byKey(const Key('sync-policy-manual')));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      expect(
        container.read(connectionControllerProvider).policy.mode.name,
        'manual',
      );
      expect(tester.takeException(), isNull);
    } finally {
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}
