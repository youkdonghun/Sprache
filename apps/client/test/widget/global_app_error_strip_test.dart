import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/global_app_error_state.dart';

void main() {
  testWidgets('global app error uses a non-overlay shell strip', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyStoreProvider.overrideWithValue(
              MemoryStudyStore(
                preferences: const StudyPreferences(onboardingCompleted: true),
              ),
            ),
          ],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );

      container
          .read(globalAppErrorProvider.notifier)
          .report(
            source: 'runtime-test',
            message: '저장 상태를 확인해 주세요.',
            actionRoute: '/settings?focus=storage',
          );
      await tester.pump();

      final strip = find.byKey(const Key('global-app-error-strip'));
      final main = find.byKey(const Key('shell-main-content-focus'));
      expect(strip, findsOneWidget);
      expect(main, findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.getBottomLeft(strip).dy,
        lessThanOrEqualTo(tester.getTopLeft(main).dy),
        reason: '오류 안내는 본문 위의 레이아웃 영역을 차지하고 겹치지 않아야 한다.',
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('global-app-error-dismiss')));
      await tester.pump();
      expect(strip, findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}
