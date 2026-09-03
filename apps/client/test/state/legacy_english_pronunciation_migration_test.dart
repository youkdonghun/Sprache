import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/learning_item_codec.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test(
    'startup removes legacy pack readings and queues the clean snapshot',
    () async {
      final store = MemoryStudyStore();
      await store.saveCustomItems([_legacyPackItem()]);

      final controller = AppController(store);
      await _waitForHydration(controller);
      await controller.flushPendingWrites();

      expect(controller.state.customItems.single.koreanPronunciation, isNull);
      expect(store.savedItems.single.koreanPronunciation, isNull);
      expect(store.savedItems.single.source.contentVersion, 2);
      expect(store.pendingSnapshotSync, isNotNull);

      final queuedItems =
          store.pendingSnapshotSync!.payload['customItems']! as List;
      final queuedItem = const LearningItemCodec().fromJson(
        Map<String, Object?>.from(queuedItems.single as Map),
      );
      expect(queuedItem.koreanPronunciation, isNull);
      controller.dispose();
    },
  );

  test('Drive merge cannot restore a legacy generated reading', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await _waitForHydration(controller);
    final remote = controller.exportSyncSnapshot();
    remote['customItems'] = [
      const LearningItemCodec().toJson(_legacyPackItem()),
    ];

    await controller.mergeRemoteSnapshot(remote);

    expect(controller.state.customItems.single.koreanPronunciation, isNull);
    expect(store.savedItems.single.koreanPronunciation, isNull);
    controller.dispose();
  });

  test('snapshot restore also removes a legacy generated reading', () async {
    final store = MemoryStudyStore();
    final controller = AppController(store);
    await _waitForHydration(controller);
    final snapshot = controller.exportSyncSnapshot();
    snapshot['customItems'] = [
      const LearningItemCodec().toJson(_legacyPackItem()),
    ];

    await controller.replaceWithSyncSnapshot(snapshot);

    expect(controller.state.customItems.single.koreanPronunciation, isNull);
    expect(store.savedItems.single.koreanPronunciation, isNull);
    controller.dispose();
  });
}

LearningItem _legacyPackItem() => const LearningItem(
  id: 'legacy-adult',
  kind: LearningItemKind.word,
  learningLanguage: LanguageTag.english,
  text: 'adult',
  translations: ['어른'],
  acceptedAnswers: ['어른'],
  readings: [Reading(scheme: ReadingScheme.hangul, value: '아둘트')],
  source: ContentSource(
    name: '영어 생활 핵심 어휘',
    license: 'CC-BY-4.0',
    sourceVersion: '2026.09.1',
    contentVersion: 1,
    sourceId: 'language-pack:sprache-en-tufs-core-2026-09',
  ),
);

Future<void> _waitForHydration(AppController controller) async {
  for (
    var attempt = 0;
    attempt < 100 && !controller.state.isHydrated;
    attempt++
  ) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(controller.state.isHydrated, isTrue);
}
