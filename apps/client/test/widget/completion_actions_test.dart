import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/services/app_clock.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets(
    'completion clears a mistake after the retry is answered correctly',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      final now = DateTime.utc(2026, 7, 30, 12);

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyStoreProvider.overrideWithValue(MemoryStudyStore()),
              appClockProvider.overrideWithValue(() => now),
            ],
            child: const SpracheApp(),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(SpracheApp)),
        );
        final controller = container.read(appControllerProvider.notifier);
        final item = controller
            .queue(now, mode: StudyMode.meaning, itemLimit: 1)
            .single;

        container.read(appRouterProvider).go('/study?mode=meaning&limit=1');
        await tester.pumpAndSettle();

        await tester.tap(find.text('모르겠어요'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('다음 문제'));
        await tester.pumpAndSettle();

        await tester.tap(find.text(item.primaryTranslation));
        await tester.tap(find.text('정답 확인'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('다음 문제'));
        await tester.pumpAndSettle();

        final retry = find.byKey(const Key('completion-retry-mistakes'));
        final next = find.byKey(const Key('completion-next-recommended'));
        final back = find.byKey(const Key('completion-return'));
        final receipt = find.byKey(const Key('completion-local-receipt'));
        expect(retry, findsNothing);
        expect(next, findsOneWidget);
        expect(back, findsOneWidget);
        expect(receipt, findsOneWidget);
        expect(find.text('로컬 저장 영수증'), findsOneWidget);
        expect(find.textContaining('동기화 대기 1건'), findsOneWidget);
        expect(
          tester.getTopLeft(next).dy,
          lessThan(tester.getTopLeft(back).dy),
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        tester.view.reset();
      }
    },
  );
}
