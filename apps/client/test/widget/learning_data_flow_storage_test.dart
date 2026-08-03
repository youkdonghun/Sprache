import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/widgets/learning_data_flow_card.dart';

void main() {
  testWidgets('condensed flow keeps one-line summary and direct next action', (
    tester,
  ) async {
    var organized = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningDataFlowCard(
            condensed: true,
            totalCount: 12,
            localCopyCount: 12,
            groupCount: 0,
            driveConnected: false,
            currentStep: LearningDataStep.organize,
            onOrganize: () => organized = true,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('open-learning-data-details-condensed')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('learning-data-flow-primary')));
    expect(organized, isTrue);
    expect(
      tester.getSize(find.byKey(const Key('learning-data-flow-card'))).height,
      lessThanOrEqualTo(60),
    );
  });

  testWidgets('320px always shows the active storage target and DB role', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LearningDataFlowCard(
            totalCount: 120,
            localCopyCount: 4,
            groupCount: 3,
            driveConnected: false,
          ),
        ),
      ),
    );

    expect(find.text('현재: Google Drive 연결 필요'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Drive details describe Drive and the app-only offline cache', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LearningDataFlowCard(
            totalCount: 120,
            localCopyCount: 4,
            groupCount: 3,
            driveConnected: true,
          ),
        ),
      ),
    );

    expect(find.text('현재: Google Drive · 앱 내부 오프라인 캐시'), findsOneWidget);
    await tester.tap(find.byKey(const Key('learning-data-flow-card')));
    await tester.pumpAndSettle();

    expect(find.text('앱 내부 오프라인 캐시'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
