import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../backup/backup_archive.dart';

enum RecoveryCheckpointReason { bulkImport, bulkDelete, restore, manual }

extension RecoveryCheckpointReasonLabel on RecoveryCheckpointReason {
  String get label => switch (this) {
    RecoveryCheckpointReason.bulkImport => '대량 가져오기 전',
    RecoveryCheckpointReason.bulkDelete => '일괄 삭제 전',
    RecoveryCheckpointReason.restore => '백업 복원 전',
    RecoveryCheckpointReason.manual => '수동 안전 지점',
  };
}

class RecoveryCheckpointReceipt {
  const RecoveryCheckpointReceipt({
    required this.id,
    required this.reason,
    required this.createdAt,
    required this.byteLength,
    required this.sha256Hex,
    required this.customItemCount,
    required this.progressCount,
    required this.sessionCount,
    required this.path,
  });

  final String id;
  final RecoveryCheckpointReason reason;
  final DateTime createdAt;
  final int byteLength;
  final String sha256Hex;
  final int customItemCount;
  final int progressCount;
  final int sessionCount;
  final String path;

  int get itemCount => customItemCount + progressCount + sessionCount;
}

typedef RecoveryCheckpointRootResolver = Future<String> Function();

class RecoveryCheckpointService {
  RecoveryCheckpointService({
    RecoveryCheckpointRootResolver? rootResolver,
    DateTime Function()? clock,
    this.codec = const BackupArchiveCodec(),
  }) : _rootResolver = rootResolver ?? _defaultRoot,
       _clock = clock ?? DateTime.now;

  final RecoveryCheckpointRootResolver _rootResolver;
  final DateTime Function() _clock;
  final BackupArchiveCodec codec;

  Future<RecoveryCheckpointReceipt> create(
    Map<String, Object?> archive, {
    required RecoveryCheckpointReason reason,
  }) async {
    final validated = codec.validate(archive);
    final createdAt = _clock().toUtc();
    final encoded = utf8.encode(jsonEncode(archive));
    if (encoded.length > BackupArchiveCodec.maxArchiveBytes) {
      throw const BackupArchiveException('복구 체크포인트가 10MB 제한을 넘었습니다.');
    }
    final fingerprint = sha256.convert(encoded).toString();
    final safeTimestamp = createdAt.toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final id = '$safeTimestamp-${reason.name}-${fingerprint.substring(0, 8)}';
    final root = Directory(await _rootResolver()).absolute;
    await root.create(recursive: true);
    final pending = Directory(path.join(root.path, '.$id.pending'));
    final target = Directory(path.join(root.path, id));
    if (await pending.exists()) await pending.delete(recursive: true);
    if (await target.exists()) {
      return _readReceipt(target, verifyArchive: true);
    }
    await pending.create();
    try {
      final archiveFile = File(path.join(pending.path, 'checkpoint.json'));
      await archiveFile.writeAsBytes(encoded, flush: true);
      final metadata = {
        'format': 'sprache-recovery-checkpoint-v1',
        'id': id,
        'reason': reason.name,
        'createdAt': createdAt.toIso8601String(),
        'byteLength': encoded.length,
        'sha256': fingerprint,
        'customItemCount': validated.customItemCount,
        'progressCount': validated.progressCount,
        'sessionCount': validated.sessions.length,
      };
      await File(
        path.join(pending.path, 'checkpoint-metadata.json'),
      ).writeAsString(jsonEncode(metadata), flush: true);
      final bytes = await archiveFile.readAsBytes();
      if (bytes.length != encoded.length ||
          sha256.convert(bytes).toString() != fingerprint) {
        throw const BackupArchiveException('복구 체크포인트 쓰기 검증에 실패했습니다.');
      }
      await pending.rename(target.path);
      return _readReceipt(target, verifyArchive: true);
    } catch (_) {
      if (await pending.exists()) await pending.delete(recursive: true);
      rethrow;
    }
  }

  Future<BackupArchive> load(String checkpointPath) async {
    final directory = await _safeDirectory(checkpointPath);
    final receipt = await _readReceipt(directory, verifyArchive: true);
    final source = await File(
      path.join(receipt.path, 'checkpoint.json'),
    ).readAsString();
    return codec.decode(source);
  }

  Future<RecoveryCheckpointReceipt> verify(String checkpointPath) async =>
      _readReceipt(await _safeDirectory(checkpointPath), verifyArchive: true);

  Future<Directory> _safeDirectory(String checkpointPath) async {
    final root = Directory(await _rootResolver()).absolute;
    final directory = Directory(checkpointPath).absolute;
    if (_normalized(directory.parent.path) != _normalized(root.path)) {
      throw StateError('복구 루트 밖의 체크포인트는 열 수 없습니다.');
    }
    return directory;
  }

  Future<RecoveryCheckpointReceipt> _readReceipt(
    Directory directory, {
    required bool verifyArchive,
  }) async {
    final metadataFile = File(
      path.join(directory.path, 'checkpoint-metadata.json'),
    );
    final archiveFile = File(path.join(directory.path, 'checkpoint.json'));
    final metadata = Map<String, Object?>.from(
      jsonDecode(await metadataFile.readAsString()) as Map,
    );
    if (metadata['format'] != 'sprache-recovery-checkpoint-v1') {
      throw const FormatException('지원하지 않는 복구 체크포인트입니다.');
    }
    final bytes = await archiveFile.readAsBytes();
    final expectedLength = metadata['byteLength'];
    final expectedHash = metadata['sha256'];
    if (expectedLength is! int || expectedHash is! String) {
      throw const FormatException('복구 체크포인트 메타데이터가 올바르지 않습니다.');
    }
    if (verifyArchive &&
        (bytes.length != expectedLength ||
            sha256.convert(bytes).toString() != expectedHash)) {
      throw const FormatException('복구 체크포인트 무결성 검증에 실패했습니다.');
    }
    if (verifyArchive) codec.decode(utf8.decode(bytes, allowMalformed: false));
    final reason = RecoveryCheckpointReason.values.firstWhere(
      (value) => value.name == metadata['reason'],
      orElse: () => RecoveryCheckpointReason.manual,
    );
    final createdAt = DateTime.tryParse(metadata['createdAt'] as String? ?? '');
    if (createdAt == null) throw const FormatException('체크포인트 시각이 없습니다.');
    int count(String key) => switch (metadata[key]) {
      final int value when value >= 0 => value,
      _ => throw const FormatException('체크포인트 항목 수가 올바르지 않습니다.'),
    };
    return RecoveryCheckpointReceipt(
      id: metadata['id'] as String? ?? path.basename(directory.path),
      reason: reason,
      createdAt: createdAt.toUtc(),
      byteLength: bytes.length,
      sha256Hex: expectedHash,
      customItemCount: count('customItemCount'),
      progressCount: count('progressCount'),
      sessionCount: count('sessionCount'),
      path: directory.path,
    );
  }

  static String _normalized(String value) {
    final normalized = path.normalize(value);
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  static Future<String> _defaultRoot() async {
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      return _headlessRoot();
    }
    try {
      final directory = await getApplicationDocumentsDirectory();
      return path.join(directory.path, 'sprache-recovery');
    } on MissingPluginException {
      // Headless Flutter tests do not register path_provider. Keep the same
      // verified, atomic checkpoint behavior in a process-scoped temp root.
      return _headlessRoot();
    } on MissingPlatformDirectoryException {
      return _headlessRoot();
    }
  }

  static String _headlessRoot() =>
      path.join(Directory.systemTemp.path, 'sprache-recovery-headless-$pid');
}
