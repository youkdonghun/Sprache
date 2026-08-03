import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/services/recovery_backup_catalog.dart';
import 'package:sprache/src/services/recovery_checkpoint_service.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  late Directory temporaryRoot;
  late DateTime now;

  setUp(() async {
    temporaryRoot = await Directory.systemTemp.createTemp(
      'sprache-recovery-checkpoint-',
    );
    now = DateTime.utc(2026, 8, 2, 9, 30);
  });

  tearDown(() async {
    if (await temporaryRoot.exists()) {
      await temporaryRoot.delete(recursive: true);
    }
  });

  test(
    'creates an atomic checkpoint with a verifiable recovery receipt',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      await controller.upsertCustomItem(
        const LearningItem(
          id: 'checkpoint-word',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          text: 'recovery',
          translations: ['복구'],
          acceptedAnswers: ['복구'],
        ),
      );
      final service = RecoveryCheckpointService(
        rootResolver: () async => temporaryRoot.path,
        clock: () => now,
      );

      final receipt = await service.create(
        controller.exportArchive(),
        reason: RecoveryCheckpointReason.bulkImport,
      );
      final verified = await service.verify(receipt.path);
      final restored = await service.load(receipt.path);

      expect(receipt.reason, RecoveryCheckpointReason.bulkImport);
      expect(receipt.customItemCount, 1);
      expect(receipt.sha256Hex, hasLength(64));
      expect(receipt.byteLength, greaterThan(0));
      expect(verified.sha256Hex, receipt.sha256Hex);
      expect(restored.customItemCount, 1);
      expect(
        temporaryRoot.listSync().whereType<Directory>().single.path,
        receipt.path,
      );
      expect(
        temporaryRoot.listSync().whereType<Directory>().single.path,
        isNot(contains('.pending')),
      );
      controller.dispose();
    },
  );

  test(
    'catalog exposes reason, item count, and hash verification state',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      final service = RecoveryCheckpointService(
        rootResolver: () async => temporaryRoot.path,
        clock: () => now,
      );
      final receipt = await service.create(
        controller.exportArchive(),
        reason: RecoveryCheckpointReason.restore,
      );
      for (final file in Directory(receipt.path).listSync().whereType<File>()) {
        await file.setLastModified(now);
      }

      final inventory = await RecoveryBackupCatalogService(
        rootResolver: () async => temporaryRoot.path,
        clock: () => now.add(const Duration(days: 31)),
      ).inspect();

      expect(inventory.items, hasLength(1));
      expect(inventory.items.single.reason, 'restore');
      expect(inventory.items.single.itemCount, isNonNegative);
      expect(inventory.items.single.sha256Hex, hasLength(64));
      expect(inventory.items.single.verified, isTrue);
      expect(inventory.items.single.eligibleForCleanup, isTrue);
      controller.dispose();
    },
  );

  test(
    'tampering is detected and never decoded as a valid checkpoint',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      final service = RecoveryCheckpointService(
        rootResolver: () async => temporaryRoot.path,
        clock: () => now,
      );
      final receipt = await service.create(
        controller.exportArchive(),
        reason: RecoveryCheckpointReason.manual,
      );
      final checkpoint = File(path.join(receipt.path, 'checkpoint.json'));
      await checkpoint.writeAsString(
        '${await checkpoint.readAsString()} ',
        flush: true,
      );

      expect(() => service.verify(receipt.path), throwsFormatException);
      expect(() => service.load(receipt.path), throwsFormatException);

      final inventory = await RecoveryBackupCatalogService(
        rootResolver: () async => temporaryRoot.path,
        clock: () => now,
      ).inspect();
      expect(inventory.items.single.verified, isFalse);
      controller.dispose();
    },
  );

  test(
    'refuses checkpoint paths outside the configured recovery root',
    () async {
      final outside = await Directory.systemTemp.createTemp(
        'sprache-recovery-outside-',
      );
      addTearDown(() async {
        if (await outside.exists()) await outside.delete(recursive: true);
      });
      final service = RecoveryCheckpointService(
        rootResolver: () async => temporaryRoot.path,
        clock: () => now,
      );

      expect(() => service.load(outside.path), throwsStateError);
      expect(() => service.verify(outside.path), throwsStateError);
    },
  );
}
