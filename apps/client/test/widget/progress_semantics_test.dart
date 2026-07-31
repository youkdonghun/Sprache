import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/app.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/routing/app_router.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  testWidgets('learning progress has contextual accessibility labels', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
          child: const SpracheApp(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SpracheApp)),
      );
      final router = container.read(appRouterProvider);

      router.go('/path');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('코스 전체 진행률')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'Unit 1 .* 학습 진행률')),
        findsOneWidget,
      );

      router.go('/mission/0');
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == '실전 미션 표현 진행률',
        ),
        findsOneWidget,
      );

      router.go('/cards?kind=words');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('암기 카드 진행률'), findsOneWidget);

      router.go('/pronunciation');
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('발음 연습 진행률'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
      debugDefaultTargetPlatformOverride = null;
      tester.view.reset();
    }
  });
}
