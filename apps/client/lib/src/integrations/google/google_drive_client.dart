import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class DriveBootstrapResult {
  const DriveBootstrapResult({
    required this.appRootFolderId,
    required this.appRootFolderName,
    required this.manifestFileId,
  });

  final String appRootFolderId;
  final String appRootFolderName;
  final String manifestFileId;
}

class DriveDataIntegrityException implements Exception {
  const DriveDataIntegrityException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

class GoogleDriveClient {
  GoogleDriveClient({
    required this.accessTokenProvider,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final Future<String> Function() accessTokenProvider;
  final http.Client _httpClient;
  bool _hasPulledSnapshot = false;
  String? _lastPulledSnapshotFingerprint;

  static const _apiRoot = 'https://www.googleapis.com/drive/v3';
  static const _uploadRoot = 'https://www.googleapis.com/upload/drive/v3';
  static const _folderMimeType = 'application/vnd.google-apps.folder';

  Future<DriveBootstrapResult> ensureAppRoot(String selectedFolderId) async {
    final appRootId =
        await _findChildFolder(selectedFolderId, 'WordStudyData') ??
        await _createFolder('WordStudyData', selectedFolderId);
    for (final name in const ['content', 'state', 'imports', 'backups']) {
      await _findChildFolder(appRootId, name) ??
          await _createFolder(name, appRootId);
    }

    var manifestId = await _findChildFile(appRootId, 'manifest.json');
    if (manifestId == null) {
      manifestId = await _createFile(
        name: 'manifest.json',
        parentId: appRootId,
        mimeType: 'application/json',
      );
      await _uploadJson(manifestId, {
        'schemaVersion': 1,
        'datasetVersion': 1,
        'appRootFolderId': appRootId,
        'files': <String, Object?>{},
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });
    }

    return DriveBootstrapResult(
      appRootFolderId: appRootId,
      appRootFolderName: 'WordStudyData',
      manifestFileId: manifestId,
    );
  }

  Future<Map<String, Object?>?> readStateSnapshot(String appRootId) async {
    final manifestId = await _findChildFile(appRootId, 'manifest.json');
    if (manifestId == null) {
      throw const DriveDataIntegrityException(
        'drive_manifest_missing',
        'manifest.json을 찾을 수 없습니다.',
      );
    }
    final manifest = await _readJsonStrict(manifestId, label: 'manifest.json');
    _validateManifestIdentity(manifest, appRootId);
    final files = _manifestFiles(manifest);
    final snapshotEntry = files['state/snapshot.json'];
    if (snapshotEntry == null) {
      final stateFolderId = await _findChildFolder(appRootId, 'state');
      if (stateFolderId == null ||
          await _findChildFile(stateFolderId, 'snapshot.json') == null) {
        _hasPulledSnapshot = true;
        _lastPulledSnapshotFingerprint = null;
        return null;
      }
      throw const DriveDataIntegrityException(
        'drive_manifest_entry_missing',
        'snapshot 파일은 있지만 manifest 항목이 없습니다.',
      );
    }
    final snapshotId = snapshotEntry['fileId'] as String? ?? '';
    final expectedRevision = snapshotEntry['revision']?.toString() ?? '';
    final expectedSha = snapshotEntry['sha256'] as String? ?? '';
    if (snapshotId.isEmpty ||
        expectedRevision.isEmpty ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(expectedSha)) {
      throw const DriveDataIntegrityException(
        'drive_manifest_invalid',
        'snapshot manifest 항목의 ID, revision 또는 SHA-256이 올바르지 않습니다.',
      );
    }
    final metadata = await _readMetadata(snapshotId);
    final actualRevision = metadata['version']?.toString() ?? '';
    if (actualRevision != expectedRevision) {
      throw const DriveDataIntegrityException(
        'drive_manifest_revision_mismatch',
        'manifest revision과 Drive 파일 revision이 다릅니다.',
      );
    }
    final response = await _authorizedGet(
      Uri.parse('$_apiRoot/files/$snapshotId?alt=media'),
    );
    final actualSha = sha256.convert(response.bodyBytes).toString();
    if (actualSha.toLowerCase() != expectedSha.toLowerCase()) {
      throw const DriveDataIntegrityException(
        'drive_manifest_sha_mismatch',
        'snapshot SHA-256이 manifest와 일치하지 않습니다.',
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const DriveDataIntegrityException(
        'drive_snapshot_invalid',
        'snapshot이 올바른 JSON이 아닙니다.',
      );
    }
    if (decoded is! Map) {
      throw const DriveDataIntegrityException(
        'drive_snapshot_invalid',
        'snapshot은 JSON 객체여야 합니다.',
      );
    }
    _hasPulledSnapshot = true;
    _lastPulledSnapshotFingerprint = _snapshotFingerprint(snapshotEntry);
    return Map<String, Object?>.from(decoded);
  }

  Future<void> writeStateSnapshot({
    required String appRootId,
    required Map<String, Object?> snapshot,
  }) async {
    var manifestId = await _findChildFile(appRootId, 'manifest.json');
    Map<String, Object?> manifest;
    if (manifestId == null) {
      manifestId = await _createFile(
        name: 'manifest.json',
        parentId: appRootId,
        mimeType: 'application/json',
      );
      manifest = {
        'schemaVersion': 1,
        'datasetVersion': 1,
        'appRootFolderId': appRootId,
        'files': <String, Object?>{},
      };
    } else {
      manifest = await _readJsonStrict(manifestId, label: 'manifest.json');
      _validateManifestIdentity(manifest, appRootId);
    }
    final files = _manifestFiles(manifest);
    final existingEntry = files['state/snapshot.json'];
    final currentFingerprint = existingEntry == null
        ? null
        : _snapshotFingerprint(existingEntry);
    if (_hasPulledSnapshot &&
        currentFingerprint != _lastPulledSnapshotFingerprint) {
      throw const DriveDataIntegrityException(
        'drive_upload_conflict',
        '내려받은 뒤 다른 기기에서 snapshot을 변경했습니다. 다시 병합해야 합니다.',
      );
    }
    String? snapshotId = existingEntry?['fileId'] as String?;
    if (existingEntry != null) {
      final expectedRevision = existingEntry['revision']?.toString() ?? '';
      final expectedSha = existingEntry['sha256'] as String? ?? '';
      if (snapshotId == null ||
          snapshotId.isEmpty ||
          expectedRevision.isEmpty ||
          !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(expectedSha)) {
        throw const DriveDataIntegrityException(
          'drive_manifest_invalid',
          '기존 snapshot manifest 항목이 올바르지 않습니다.',
        );
      }
      final metadata = await _readMetadata(snapshotId);
      final currentRevision = metadata['version']?.toString() ?? '';
      if (currentRevision != expectedRevision) {
        throw const DriveDataIntegrityException(
          'drive_upload_conflict',
          '다른 기기에서 snapshot을 변경했습니다. 다시 내려받아 병합해야 합니다.',
        );
      }
    } else {
      final stateFolderId =
          await _findChildFolder(appRootId, 'state') ??
          await _createFolder('state', appRootId);
      snapshotId =
          await _findChildFile(stateFolderId, 'snapshot.json') ??
          await _createFile(
            name: 'snapshot.json',
            parentId: stateFolderId,
            mimeType: 'application/json',
          );
    }
    await _uploadJson(snapshotId, snapshot);

    final metadata = await _readMetadata(snapshotId);
    final encoded = jsonEncode(snapshot);
    final now = DateTime.now().toUtc();
    final nextEntry = <String, Object?>{
      'fileId': snapshotId,
      'revision': '${metadata['version'] ?? now.microsecondsSinceEpoch}',
      'sha256': sha256.convert(utf8.encode(encoded)).toString(),
      'updatedAt': metadata['modifiedTime'] as String? ?? now.toIso8601String(),
    };
    files['state/snapshot.json'] = nextEntry;
    await _uploadJson(manifestId, {
      'schemaVersion': 1,
      'datasetVersion': manifest['datasetVersion'] as int? ?? 1,
      'appRootFolderId': appRootId,
      'files': files,
      'updatedAt': now.toIso8601String(),
    });
    _hasPulledSnapshot = true;
    _lastPulledSnapshotFingerprint = _snapshotFingerprint(nextEntry);
  }

  Future<String?> _findChildFolder(String parentId, String name) {
    return _findChild(
      parentId: parentId,
      name: name,
      mimeType: _folderMimeType,
    );
  }

  Future<String?> _findChildFile(String parentId, String name) {
    return _findChild(
      parentId: parentId,
      name: name,
      mimeType: 'application/json',
    );
  }

  Future<String?> _findChild({
    required String parentId,
    required String name,
    required String mimeType,
  }) async {
    final escapedName = name.replaceAll("'", r"\'");
    final query = [
      "'$parentId' in parents",
      "name = '$escapedName'",
      "mimeType = '$mimeType'",
      'trashed = false',
    ].join(' and ');
    final uri = Uri.parse('$_apiRoot/files').replace(
      queryParameters: {
        'q': query,
        'spaces': 'drive',
        'fields': 'files(id,name,mimeType)',
        'pageSize': '10',
      },
    );
    final response = await _authorizedGet(uri);
    final body = jsonDecode(response.body) as Map<String, Object?>;
    final files = (body['files'] as List<Object?>?) ?? const [];
    if (files.isEmpty) return null;
    return (files.first as Map<String, Object?>)['id']! as String;
  }

  Future<String> _createFolder(String name, String parentId) {
    return _createFile(
      name: name,
      parentId: parentId,
      mimeType: _folderMimeType,
    );
  }

  Future<String> _createFile({
    required String name,
    required String parentId,
    required String mimeType,
  }) async {
    final token = await accessTokenProvider();
    final response = await _httpClient.post(
      Uri.parse('$_apiRoot/files?fields=id,name'),
      headers: {
        'authorization': 'Bearer $token',
        'content-type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'name': name,
        'parents': [parentId],
        'mimeType': mimeType,
      }),
    );
    _ensureSuccess(response, operation: 'create Drive item');
    return (jsonDecode(response.body) as Map<String, Object?>)['id']! as String;
  }

  Future<void> _uploadJson(String fileId, Map<String, Object?> content) async {
    final token = await accessTokenProvider();
    final response = await _httpClient.patch(
      Uri.parse('$_uploadRoot/files/$fileId?uploadType=media'),
      headers: {
        'authorization': 'Bearer $token',
        'content-type': 'application/json; charset=utf-8',
      },
      body: jsonEncode(content),
    );
    _ensureSuccess(response, operation: 'upload Drive JSON');
  }

  Future<Map<String, Object?>> _readMetadata(String fileId) async {
    final response = await _authorizedGet(
      Uri.parse(
        '$_apiRoot/files/$fileId?fields=id,version,modifiedTime,md5Checksum',
      ),
    );
    return jsonDecode(response.body) as Map<String, Object?>;
  }

  Future<Map<String, Object?>> _readJsonStrict(
    String fileId, {
    required String label,
  }) async {
    final response = await _authorizedGet(
      Uri.parse('$_apiRoot/files/$fileId?alt=media'),
    );
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException();
      }
      return Map<String, Object?>.from(decoded);
    } on FormatException {
      throw DriveDataIntegrityException(
        'drive_json_invalid',
        '$label 파일이 올바른 JSON 객체가 아닙니다.',
      );
    } on TypeError {
      throw DriveDataIntegrityException(
        'drive_json_invalid',
        '$label 파일이 올바른 JSON 객체가 아닙니다.',
      );
    }
  }

  void _validateManifestIdentity(
    Map<String, Object?> manifest,
    String appRootId,
  ) {
    final schemaVersion = (manifest['schemaVersion'] as num?)?.toInt();
    if (schemaVersion == null || schemaVersion < 1) {
      throw const DriveDataIntegrityException(
        'drive_manifest_invalid',
        'manifest schemaVersion이 올바르지 않습니다.',
      );
    }
    if (schemaVersion > 1) {
      throw const DriveDataIntegrityException(
        'drive_manifest_newer_schema',
        'manifest가 현재 앱보다 최신 버전입니다.',
      );
    }
    if (manifest['appRootFolderId'] != appRootId) {
      throw const DriveDataIntegrityException(
        'drive_manifest_root_mismatch',
        'manifest의 앱 루트 Folder ID가 현재 연결과 다릅니다.',
      );
    }
  }

  Map<String, Map<String, Object?>> _manifestFiles(
    Map<String, Object?> manifest,
  ) {
    final raw = manifest['files'];
    if (raw is! Map) {
      throw const DriveDataIntegrityException(
        'drive_manifest_invalid',
        'manifest files 객체가 없습니다.',
      );
    }
    try {
      return {
        for (final entry in raw.entries)
          entry.key as String: Map<String, Object?>.from(entry.value! as Map),
      };
    } catch (_) {
      throw const DriveDataIntegrityException(
        'drive_manifest_invalid',
        'manifest files 항목 형식이 올바르지 않습니다.',
      );
    }
  }

  String _snapshotFingerprint(Map<String, Object?> entry) {
    final fileId = entry['fileId'] as String? ?? '';
    final revision = entry['revision']?.toString() ?? '';
    final checksum = entry['sha256'] as String? ?? '';
    if (fileId.isEmpty ||
        revision.isEmpty ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(checksum)) {
      throw const DriveDataIntegrityException(
        'drive_manifest_invalid',
        'snapshot manifest 항목의 ID, revision 또는 SHA-256이 올바르지 않습니다.',
      );
    }
    return '$fileId|$revision|${checksum.toLowerCase()}';
  }

  Future<http.Response> _authorizedGet(Uri uri) async {
    final token = await accessTokenProvider();
    final response = await _httpClient.get(
      uri,
      headers: {'authorization': 'Bearer $token'},
    );
    _ensureSuccess(response, operation: 'read Drive metadata');
    return response;
  }

  void _ensureSuccess(http.Response response, {required String operation}) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError('drive_permission_revoked');
    }
    if (response.statusCode == 404) {
      throw StateError('drive_folder_missing');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('$operation failed (${response.statusCode})');
    }
  }
}
