import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/widgets/privacy_mode_scope.dart';

void main() {
  testWidgets('privacy scope redacts content but keeps numerical context', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyModeScope(
          enabled: true,
          child: Builder(
            builder: (context) => Column(
              children: [
                Text(PrivacyModeScope.redact(context, 'secret word')),
                const Text('정확도 82%'),
                const FilledButton(onPressed: null, child: Text('복습 시작')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('secret word'), findsNothing);
    expect(find.text('••••••'), findsOneWidget);
    expect(find.text('정확도 82%'), findsOneWidget);
    expect(find.text('복습 시작'), findsOneWidget);
  });
}
