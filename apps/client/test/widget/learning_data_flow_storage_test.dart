import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/widgets/learning_data_flow_card.dart';

void main() {
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
            localFolderConfigured: true,
            localFolderName: 'Sprache',
          ),
        ),
      ),
    );

    expect(find.text('현재: 로컬 폴더 · 앱 DB 원본'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Drive details describe the local folder as the fallback', (
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
            localFolderConfigured: true,
            localFolderName: '내 Sprache 폴더',
          ),
        ),
      ),
    );

    expect(find.text('현재: Drive · 앱 DB 원본'), findsOneWidget);
    await tester.tap(find.byKey(const Key('learning-data-flow-card')));
    await tester.pumpAndSettle();

    expect(
      find.text('내 Sprache 폴더는 Drive 연결 해제 시 자동으로 복귀할 대기 위치입니다.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
