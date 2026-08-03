import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/widgets/sentence_token_editor.dart';

void main() {
  testWidgets('edits, reorders, adds, and removes explicit token chips', (
    tester,
  ) async {
    var tokens = <String>['I', 'study'];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: SentenceTokenEditor(
              sentenceText: 'I study.',
              language: LanguageTag.english,
              tokens: tokens,
              onChanged: (value) => setState(() => tokens = value),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('sentence-token-chip-0')), findsOneWidget);
    expect(find.textContaining('학습 문장과 다릅니다'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sentence-token-chip-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('sentence-token-edit-field')),
      'study.',
    );
    await tester.tap(find.byKey(const Key('sentence-token-edit-save')));
    await tester.pumpAndSettle();
    expect(tokens, ['I', 'study.']);
    expect(find.textContaining('빈칸 문제에 사용'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sentence-token-move-left-1')));
    await tester.pump();
    expect(tokens, ['study.', 'I']);

    await tester.enterText(
      find.byKey(const Key('sentence-token-add-field')),
      'today',
    );
    await tester.tap(find.byKey(const Key('sentence-token-add')));
    await tester.pump();
    expect(tokens, ['study.', 'I', 'today']);

    final chip = tester.widget<InputChip>(
      find.byKey(const Key('sentence-token-chip-2')),
    );
    chip.onDeleted!();
    await tester.pump();
    expect(tokens, ['study.', 'I']);
  });

  testWidgets(
    'clipboard suggestion changes tokens only after an explicit tap',
    (tester) async {
      var tokens = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            return <String, Object?>{'text': 'We learn together.'};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SentenceTokenEditor(
                sentenceText: 'We learn together.',
                language: LanguageTag.english,
                tokens: tokens,
                onChanged: (value) => setState(() => tokens = value),
              ),
            ),
          ),
        ),
      );

      expect(tokens, isEmpty);
      await tester.tap(find.byKey(const Key('sentence-token-paste')));
      await tester.pumpAndSettle();

      expect(tokens, ['We', 'learn', 'together.']);
      expect(find.byKey(const Key('sentence-token-chip-2')), findsOneWidget);
    },
  );
}
