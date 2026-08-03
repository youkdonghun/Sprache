import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/widgets/content_selection_action_bar.dart';

void main() {
  testWidgets('compact selection bar keeps advanced bulk actions in one menu', (
    tester,
  ) async {
    var favorite = 0;
    var tags = 0;
    var exported = 0;
    var visibility = 0;
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: ContentSelectionActionBar(
              selectedCount: 4,
              hiddenSelectedCount: 2,
              onAddToGroup: () {},
              onMoveToGroup: () {},
              onMemorize: () {},
              onQuiz: () {},
              onClear: () {},
              onToggleFavorite: () => favorite++,
              onEditTags: () => tags++,
              onExport: () => exported++,
              onToggleVisibility: () => visibility++,
              onDelete: () => deleted++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('선택 4개 · 숨김 2'), findsOneWidget);
    Future<void> choose(String label) async {
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('content-selection-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await choose('즐겨찾기 바꾸기');
    expect(favorite, 1);

    await choose('선택한 자료의 태그 바꾸기');
    expect(tags, 1);

    await choose('학습에 넣거나 빼기');
    expect(visibility, 1);

    await choose('선택 자료 내보내기');
    expect(exported, 1);

    await choose('내가 추가한 자료 삭제');
    expect(deleted, 1);
    expect(tester.takeException(), isNull);
  });
}
