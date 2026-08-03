import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test(
    'weak and recent-wrong collections update from answer history',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      final first = controller.selectedItems[0];
      final second = controller.selectedItems[1];
      final now = DateTime.utc(2026, 7, 28, 12);

      controller.recordAnswer(
        item: first,
        correct: false,
        studiedAt: now,
        exerciseType: 'recognition',
      );
      controller.recordAnswer(
        item: first,
        correct: true,
        studiedAt: now.add(const Duration(minutes: 1)),
        exerciseType: 'recognition',
      );
      controller.recordAnswer(
        item: second,
        correct: false,
        studiedAt: now.add(const Duration(minutes: 2)),
        exerciseType: 'recognition',
      );

      expect(controller.weakItems.map((item) => item.id), contains(first.id));
      expect(controller.weakItems.map((item) => item.id), contains(second.id));
      expect(
        controller.recentWrongItems.map((item) => item.id),
        isNot(contains(first.id)),
      );
      expect(
        controller.recentWrongItems.map((item) => item.id),
        contains(second.id),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      controller.dispose();
    },
  );
}
