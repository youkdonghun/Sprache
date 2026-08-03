import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class LocalRecoveryBackup {
  const LocalRecoveryBackup({
    required this.id,
    required this.path,
    required this.byteLength,
    required this.modifiedAt,
    required this.fileCount,
    required this.eligibleForCleanup,
    this.reason,
    this.sha256Hex,
    this.itemCount,
    this.verified = false,
  });

  final String id;
  final String path;
  final int byteLength;
  final DateTime modifiedAt;
  final int fileCount;
  final bool eligibleForCleanup;
  final String? reason;
  final String? sha256Hex;
  final int? itemCount;
  final bool verified;
}

class LocalRecoveryInventory {
  const LocalRecoveryInventory({
    required this.items,
    required this.minimumAge,
    required this.inspectedAt,
  });

  final List<LocalRecoveryBackup> items;
  final Duration minimumAge;
  final DateTime inspectedAt;

  int get eligibleCount =>
      items.where((item) => item.eligibleForCleanup).length;
  int get eligibleBytes => items
      .where((item) => item.eligibleForCleanup)
      .fold(0, (total, item) => total + item.byteLength);
}

class LocalRecoveryCleanupResult {
  const LocalRecoveryCleanupResult({
    required this.deletedCount,
    required this.deletedBytes,
  });

  final int deletedCount;
  final int deletedBytes;
}

typedef RecoveryRootResolver = Future<String> Function();

class RecoveryBackupCatalogService {
  RecoveryBackupCatalogService({
    RecoveryRootResolver? rootResolver,
    DateTime Function()? clock,
  }) : _rootResolver = rootResolver ?? _defaultRoot,
       _clock = clock ?? DateTime.now;

  final RecoveryRootResolver _rootResolver;
  final DateTime Function() _clock;

  Future<LocalRecoveryInventory> inspect({
    Duration minimumAge = const Duration(days: 30),
  }) async {
    final now = _clock().toUtc();
    final root = Directory(await _rootResolver());
    if (!await root.exists()) {
      return LocalRecoveryInventory(
        items: const [],
        minimumAge: minimumAge,
        inspectedAt: now,
      );
    }
    final items = <LocalRecoveryBackup>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      var bytes = 0;
      var count = 0;
      DateTime? latest;
      await for (final child in entity.list(
        recursive: true,
        followLinks: false,
      )) {
        if (child is! File) continue;
        final stat = await child.stat();
        bytes += stat.size;
        count++;
        final modified = stat.modified.toUtc();
        if (latest == null || modified.isAfter(latest)) latest = modified;
      }
      final directoryStat = await entity.stat();
      final modifiedAt = latest ?? directoryStat.modified.toUtc();
      final checkpoint = await _checkpointMetadata(entity);
      items.add(
        LocalRecoveryBackup(
          id: entity.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last,
          path: entity.absolute.path,
          byteLength: bytes,
          modifiedAt: modifiedAt,
          fileCount: count,
          eligibleForCleanup: !modifiedAt.isAfter(now.subtract(minimumAge)),
          reason: checkpoint?.reason,
          sha256Hex: checkpoint?.sha256Hex,
          itemCount: checkpoint?.itemCount,
          verified: checkpoint?.verified ?? false,
        ),
      );
    }
    items.sort((left, right) => left.modifiedAt.compareTo(right.modifiedAt));
    return LocalRecoveryInventory(
      items: List.unmodifiable(items),
      minimumAge: minimumAge,
      inspectedAt: now,
    );
  }

  Future<({String reason, String sha256Hex, int itemCount, bool verified})?>
  _checkpointMetadata(Directory directory) async {
    final metadataFile = File(
      path.join(directory.path, 'checkpoint-metadata.json'),
    );
    final archiveFile = File(path.join(directory.path, 'checkpoint.json'));
    if (!await metadataFile.exists() || !await archiveFile.exists()) {
      return null;
    }
    try {
      final metadata = Map<String, Object?>.from(
        jsonDecode(await metadataFile.readAsString()) as Map,
      );
      if (metadata['format'] != 'sprache-recovery-checkpoint-v1') return null;
      final expectedHash = metadata['sha256'];
      final expectedLength = metadata['byteLength'];
      final bytes = await archiveFile.readAsBytes();
      final verified =
          expectedHash is String &&
          expectedLength is int &&
          bytes.length == expectedLength &&
          sha256.convert(bytes).toString() == expectedHash;
      int safeCount(String key) => switch (metadata[key]) {
        final int value when value >= 0 => value,
        _ => 0,
      };
      return (
        reason: metadata['reason'] as String? ?? 'manual',
        sha256Hex: expectedHash is String ? expectedHash : '',
        itemCount:
            safeCount('customItemCount') +
            safeCount('progressCount') +
            safeCount('sessionCount'),
        verified: verified,
      );
    } catch (_) {
      return null;
    }
  }

  Future<LocalRecoveryCleanupResult> deleteSelected({
    required LocalRecoveryInventory inventory,
    required Set<String> selectedIds,
  }) async {
    if (selectedIds.isEmpty) {
      return const LocalRecoveryCleanupResult(deletedCount: 0, deletedBytes: 0);
    }
    final current = await inspect(minimumAge: inventory.minimumAge);
    final currentById = {for (final item in current.items) item.id: item};
    final root = Directory(await _rootResolver()).absolute;
    var deletedCount = 0;
    var deletedBytes = 0;
    for (final id in selectedIds) {
      final original = inventory.items
          .where((item) => item.id == id)
          .firstOrNull;
      final item = currentById[id];
      if (original == null ||
          item == null ||
          !original.eligibleForCleanup ||
          !item.eligibleForCleanup ||
          item.modifiedAt != original.modifiedAt ||
          item.byteLength != original.byteLength) {
        throw StateError('복구 사본 목록이 바뀌었습니다. 새로 확인한 뒤 다시 정리해 주세요.');
      }
      final target = Directory(item.path).absolute;
      if (_normalized(target.parent.path) != _normalized(root.path)) {
        throw StateError('복구 폴더 밖의 경로는 정리할 수 없습니다.');
      }
      await target.delete(recursive: true);
      deletedCount++;
      deletedBytes += item.byteLength;
    }
    return LocalRecoveryCleanupResult(
      deletedCount: deletedCount,
      deletedBytes: deletedBytes,
    );
  }

  static String _normalized(String path) {
    final normalized = path.replaceAll('/', Platform.pathSeparator);
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  static Future<String> _defaultRoot() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}${Platform.pathSeparator}sprache-recovery';
  }
}
