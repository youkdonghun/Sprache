import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/screens/import_screen.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/theme/app_theme.dart';

void main() {
  testWidgets('bulk paste reads the clipboard only after an explicit action', (
    tester,
  ) async {
    var clipboardReads = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          clipboardReads++;
          return <String, Object?>{
            'text':
                'hello\t안녕\n'
                'apple | 사과\n'
                'thanks;고마워\n'
                'water: 물\n'
                'good night - 안녕히 주무세요\n'
                'morning,아침',
          };
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
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [studyStoreProvider.overrideWithValue(MemoryStudyStore())],
        child: MaterialApp(
          theme: AppTheme.desktop,
          home: const Scaffold(body: ImportScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final open = find.byKey(const Key('open-bulk-paste-import'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bulk-paste-import-dialog')), findsOneWidget);
    expect(clipboardReads, 0);
    expect(find.text('붙여넣으면 형식·개수·오류를 미리 확인합니다.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bulk-paste-system-clipboard')));
    await tester.pumpAndSettle();

    expect(clipboardReads, 1);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('bulk-paste-system-clipboard')),
          )
          .onPressed,
      isNull,
    );
    expect(find.textContaining('감지 형식 혼합 구분자'), findsOneWidget);
    expect(find.textContaining('가져올 6개'), findsOneWidget);
    expect(find.byKey(const Key('bulk-paste-entry-preview')), findsOneWidget);
    for (var line = 1; line <= 5; line++) {
      expect(
        find.byKey(ValueKey('bulk-paste-preview-row-$line')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const ValueKey('bulk-paste-preview-row-6')),
      findsNothing,
    );

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();

    expect(clipboardReads, 1);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('bulk-paste-import-input')))
          .controller
          ?.text,
      isEmpty,
      reason: '확정하지 않은 클립보드 내용은 창을 나갈 때 폐기한다.',
    );

    await tester.tap(find.byKey(const Key('bulk-paste-system-clipboard')));
    await tester.pumpAndSettle();
    expect(clipboardReads, 2);

    await tester.tap(find.byKey(const Key('clear-bulk-paste-input')));
    await tester.pumpAndSettle();

    expect(clipboardReads, 2);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('bulk-paste-import-input')))
          .controller
          ?.text,
      isEmpty,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('confirm-bulk-paste-import')),
          )
          .onPressed,
      isNull,
    );

    expect(tester.takeException(), isNull);
  });
}
