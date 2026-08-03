import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:universal_io/io.dart';

import '../../sync/sync_dataset.dart';

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

class DriveAppDataBinding {
  const DriveAppDataBinding({
    required this.folderId,
    required this.folderName,
    required this.schemaVersion,
    required this.updatedAt,
  });

  final String folderId;
  final String folderName;
  final int schemaVersion;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'folderId': folderId,
    'folderName': folderName,
    'schemaVersion': schemaVersion,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

enum DriveRequestFailure {
  authenticationExpired,
  permissionRevoked,
  resourceMissing,
  rateLimited,
  quotaExceeded,
  serviceUnavailable,
  requestFailed,
}

class DriveRequestException implements Exception {
  const DriveRequestException({
    required this.failure,
    required this.statusCode,
    required this.operation,
    this.retryAfter,
  });

  final DriveRequestFailure failure;
  final int statusCode;
  final String operation;
  final Duration? retryAfter;

  String get code => switch (failure) {
    DriveRequestFailure.authenticationExpired => 'drive_auth_expired',
    DriveRequestFailure.permissionRevoked => 'drive_permission_revoked',
    DriveRequestFailure.resourceMissing => 'drive_resource_missing',
    DriveRequestFailure.rateLimited => 'drive_rate_limited',
    DriveRequestFailure.quotaExceeded => 'drive_quota_exceeded',
    DriveRequestFailure.serviceUnavailable => 'drive_service_unavailable',
    DriveRequestFailure.requestFailed => 'drive_request_failed',
  };

  bool get retryable =>
      failure == DriveRequestFailure.rateLimited ||
      failure == DriveRequestFailure.serviceUnavailable;

  bool get reconnectRequired =>
      failure == DriveRequestFailure.authenticationExpired ||
      failure == DriveRequestFailure.permissionRevoked ||
      failure == DriveRequestFailure.resourceMissing;

  @override
  String toString() => '$code: $operation failed (HTTP $statusCode)';
}

class DriveQuarantineRecord {
  const DriveQuarantineRecord({
    required this.fileId,
    required this.fileName,
    required this.sourceFileId,
    required this.createdAt,
    required this.reasonCode,
    required this.preview,
  });

  final String fileId;
  final String fileName;
  final String sourceFileId;
  final DateTime createdAt;
  final String reasonCode;
  final String preview;
}

class DriveRetentionItem {
  const DriveRetentionItem({
    required this.fileId,
    required this.fileName,
    required this.folderName,
    required this.byteLength,
    required this.modifiedAt,
    required this.eligibleForCleanup,
  });

  final String fileId;
  final String fileName;
  final String folderName;
  final int byteLength;
  final DateTime modifiedAt;
  final bool eligibleForCleanup;
}

class DriveRetentionInventory {
  const DriveRetentionInventory({
    required this.manifestFingerprint,
    required this.items,
    required this.minimumAge,
    required this.inspectedAt,
  });

  final String manifestFingerprint;
  final List<DriveRetentionItem> items;
  final Duration minimumAge;
  final DateTime inspectedAt;

  int get eligibleCount =>
      items.where((item) => item.eligibleForCleanup).length;
  int get eligibleBytes => items
      .where((item) => item.eligibleForCleanup)
      .fold(0, (total, item) => total + item.byteLength);
}

class DriveRetentionCleanupResult {
  const DriveRetentionCleanupResult({
    required this.trashedCount,
    required this.trashedBytes,
  });

  final int trashedCount;
  final int trashedBytes;
}

class DriveDataIntegrityException implements Exception {
  const DriveDataIntegrityException(
    this.code,
    this.message, {
    this.preview,
    this.quarantine,
  });

  final String code;
  final String message;
  final String? preview;
  final DriveQuarantineRecord? quarantine;

  DriveDataIntegrityException withQuarantine(
    DriveQuarantineRecord? quarantine,
  ) {
    return DriveDataIntegrityException(
      code,
      message,
      preview: preview,
      quarantine: quarantine,
    );
  }

  @override
  String toString() => '$code: $message';
}

class GoogleDriveClient {
  static const appRootFolderName = 'Sprache';
  static const legacyAppRootFolderName = 'WordStudyData';
  static const _supportedAppRootFolderNames = {
    appRootFolderName,
    legacyAppRootFolderName,
  };

  GoogleDriveClient({
    required this.accessTokenProvider,
    http.Client? httpClient,
    DateTime Function()? clock,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _httpClient = httpClient ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final Future<String> Function() accessTokenProvider;
  final http.Client _httpClient;
  final DateTime Function() _clock;
  final Duration requestTimeout;
  final _datasetCodec = const SyncDatasetCodec();
  bool _hasPulledSnapshot = false;
  String? _lastPulledSnapshotFileId;
  String? _lastPulledSnapshotPreview;
  String? _lastPulledDatasetFingerprint;
  String? _lastPulledCanonicalFingerprint;
  final _lastPulledSectionFileIds = <String, String>{};
  final _lastPulledSectionPreviews = <String, String>{};
  final _lastPulledSectionFingerprints = <String, String>{};
  final _cachedSections = <String, Map<String, Object?>>{};
  var _writerSequence = 0;

  static const _apiRoot = 'https://www.googleapis.com/drive/v3';
  static const _uploadRoot = 'https://www.googleapis.com/upload/drive/v3';
  static const _folderMimeType = 'application/vnd.google-apps.folder';
  static const _jsonMimeType = 'application/json';
  static const _canonicalEnvelopeFormat = 'sprache-canonical-drive-snapshot-v1';
  static const appDataOAuthScope =
      'https://www.googleapis.com/auth/drive.appdata';
  static const appDataBindingFileName = 'sprache-binding-v1.json';
  static const appDataBindingSchemaVersion = 1;
  static const _maximumAppDataBindingBytes = 16 * 1024;

  Future<DriveAppDataBinding?> readAppDataBinding() async {
    final file = await _findAppDataBindingFile();
    if (file == null) return null;
    return _readAppDataBindingFile(file);
  }

  Future<DriveAppDataBinding> upsertAppDataBinding({
    required String folderId,
    required String folderName,
  }) async {
    final binding = _parseAppDataBinding({
      'folderId': folderId.trim(),
      'folderName': folderName.trim(),
      'schemaVersion': appDataBindingSchemaVersion,
      'updatedAt': _clock().toUtc().toIso8601String(),
    });
    final existing = await _findAppDataBindingFile();
    if (existing != null) {
      // Refuse to overwrite an unknown or damaged binding. The caller can
      // surface the integrity error without touching learning snapshots.
      await _readAppDataBindingFile(existing);
      await _uploadJson(existing.id, binding.toJson());
      return binding;
    }

    final fileId = await _createAppDataBindingFile();
    try {
      await _uploadJson(fileId, binding.toJson());
      return binding;
    } catch (_) {
      await _bestEffortDeleteAppDataFile(fileId);
      rethrow;
    }
  }

  Future<bool> deleteAppDataBinding() async {
    final file = await _findAppDataBindingFile();
    if (file == null) return false;
    // appDataFolder files cannot be moved to trash. Validate ownership and
    // payload shape before issuing the permanent files.delete request.
    await _readAppDataBindingFile(file);
    await _deleteAppDataFile(file.id);
    return true;
  }

  Future<DriveBootstrapResult?> discoverAppRoot() async {
    final roots = await _listDriveItems(
      query: [
        "(name = '$appRootFolderName' or "
            "name = '$legacyAppRootFolderName')",
        "mimeType = '$_folderMimeType'",
        'trashed = false',
      ].join(' and '),
      spaces: 'drive',
    );
    final valid = <DriveBootstrapResult>[];
    final visitedRootIds = <String>{};
    for (final root in roots) {
      if (!visitedRootIds.add(root.id) ||
          !_supportedAppRootFolderNames.contains(root.name) ||
          root.mimeType != _folderMimeType) {
        continue;
      }
      try {
        final escapedRootId = root.id.replaceAll("'", r"\'");
        final manifests = await _listDriveItems(
          query: [
            "'$escapedRootId' in parents",
            "name = 'manifest.json'",
            "mimeType = '$_jsonMimeType'",
            'trashed = false',
          ].join(' and '),
          spaces: 'drive',
        );
        if (manifests.length != 1) continue;
        final manifest = await _readJsonStrict(
          manifests.single.id,
          label: 'manifest.json',
        );
        _validateDiscoverableAppRootManifest(manifest, root.id);
        valid.add(
          DriveBootstrapResult(
            appRootFolderId: root.id,
            appRootFolderName: root.name,
            manifestFileId: manifests.single.id,
          ),
        );
        if (valid.length > 1) return null;
      } on DriveDataIntegrityException {
        // A damaged or future-schema candidate is not a safe recovery target.
      } on FormatException {
        // A malformed candidate is ignored without touching Drive data.
      } on TypeError {
        // A candidate with wrong JSON field types is not safe to recover.
      }
    }
    return valid.length == 1 ? valid.single : null;
  }

  Future<DriveRetentionInventory> inspectRetention({
    required String appRootId,
    Duration minimumAge = const Duration(days: 30),
  }) async {
    final manifestId = await _findChildFile(appRootId, 'manifest.json');
    if (manifestId == null) {
      throw const DriveDataIntegrityException(
        'drive_manifest_missing',
        '보존 항목을 확인할 manifest.json이 없습니다.',
      );
    }
    final manifest = await _readJsonStrict(manifestId, label: 'manifest.json');
    _validateManifestIdentity(manifest, appRootId);
    final manifestFiles = _manifestFiles(manifest);
    final referencedIds = {
      for (final entry in manifestFiles.values)
        if (entry['fileId'] case final String id when id.isNotEmpty) id,
      manifestId,
    };
    final now = _clock().toUtc();
    final cutoff = now.subtract(minimumAge);
    final items = <DriveRetentionItem>[];
    for (final folderName in const ['state', 'content']) {
      final folderId = await _findChildFolder(appRootId, folderName);
      if (folderId == null) continue;
      for (final file in await _listChildren(folderId)) {
        if (file.mimeType != _jsonMimeType || referencedIds.contains(file.id)) {
          continue;
        }
        items.add(
          DriveRetentionItem(
            fileId: file.id,
            fileName: file.name,
            folderName: folderName,
            byteLength: file.byteLength,
            modifiedAt: file.modifiedAt,
            eligibleForCleanup: !file.modifiedAt.isAfter(cutoff),
          ),
        );
      }
    }
    items.sort((left, right) => left.modifiedAt.compareTo(right.modifiedAt));
    return DriveRetentionInventory(
      manifestFingerprint: _datasetFingerprint(manifest),
      items: List.unmodifiable(items),
      minimumAge: minimumAge,
      inspectedAt: now,
    );
  }

  Future<DriveRetentionCleanupResult> trashRetentionItems({
    required String appRootId,
    required DriveRetentionInventory inventory,
    required Set<String> selectedFileIds,
  }) async {
    if (selectedFileIds.isEmpty) {
      return const DriveRetentionCleanupResult(
        trashedCount: 0,
        trashedBytes: 0,
      );
    }
    final manifestId = await _findChildFile(appRootId, 'manifest.json');
    if (manifestId == null) {
      throw const DriveDataIntegrityException(
        'drive_manifest_missing',
        '정리 전에 manifest.json을 다시 확인할 수 없습니다.',
      );
    }
    final manifest = await _readJsonStrict(manifestId, label: 'manifest.json');
    _validateManifestIdentity(manifest, appRootId);
    if (_datasetFingerprint(manifest) != inventory.manifestFingerprint) {
      throw const DriveDataIntegrityException(
        'drive_retention_conflict',
        '보존 항목을 확인한 뒤 다른 기기에서 manifest가 바뀌었습니다. 목록을 새로 확인해 주세요.',
      );
    }
    final referencedIds = {
      for (final entry in _manifestFiles(manifest).values)
        if (entry['fileId'] case final String id when id.isNotEmpty) id,
      manifestId,
    };
    final candidates = {for (final item in inventory.items) item.fileId: item};
    var trashedCount = 0;
    var trashedBytes = 0;
    for (final fileId in selectedFileIds) {
      final candidate = candidates[fileId];
      if (candidate == null || !candidate.eligibleForCleanup) {
        throw const DriveDataIntegrityException(
          'drive_retention_not_eligible',
          '30일 보존 기간을 지나지 않았거나 확인 목록에 없는 파일은 정리할 수 없습니다.',
        );
      }
      if (referencedIds.contains(fileId)) {
        throw const DriveDataIntegrityException(
          'drive_retention_referenced',
          '현재 manifest가 참조하는 파일은 정리할 수 없습니다.',
        );
      }
      await _trashFile(fileId);
      trashedCount++;
      trashedBytes += candidate.byteLength;
    }
    return DriveRetentionCleanupResult(
      trashedCount: trashedCount,
      trashedBytes: trashedBytes,
    );
  }

  Future<DriveBootstrapResult> ensureAppRoot(String selectedFolderId) async {
    var resolvedFolderName = appRootFolderName;
    var appRootId = await _findChildFolder(selectedFolderId, appRootFolderName);
    if (appRootId == null) {
      appRootId = await _findChildFolder(
        selectedFolderId,
        legacyAppRootFolderName,
      );
      if (appRootId != null) resolvedFolderName = legacyAppRootFolderName;
    }
    appRootId ??= await _createFolder(appRootFolderName, selectedFolderId);
    return _prepareAppRoot(appRootId, appRootFolderName: resolvedFolderName);
  }

  Future<DriveBootstrapResult> reuseAppRoot(
    String appRootId, {
    String? expectedFolderName,
  }) async {
    final folderName = await _readFolderName(appRootId);
    return _prepareAppRoot(appRootId, appRootFolderName: folderName);
  }

  Future<String> _readFolderName(String folderId) async {
    final response = await _authorizedGet(
      Uri.parse(
        '$_apiRoot/files/$folderId'
        '?fields=id,name,mimeType,trashed',
      ),
    );
    final metadata = jsonDecode(response.body) as Map<String, Object?>;
    final folderName = metadata['name'] as String? ?? '';
    if (metadata['mimeType'] != _folderMimeType ||
        metadata['trashed'] == true ||
        folderName.isEmpty) {
      throw const DriveDataIntegrityException(
        'drive_app_root_invalid',
        '연결된 Google Drive 저장 위치가 유효한 폴더가 아닙니다.',
      );
    }
    return folderName;
  }

  Future<DriveBootstrapResult> _prepareAppRoot(
    String appRootId, {
    required String appRootFolderName,
  }) async {
    for (final name in const ['content', 'state', 'backups', 'quarantine']) {
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
      appRootFolderName: appRootFolderName,
      manifestFileId: manifestId,
    );
  }

  Future<Map<String, Object?>?> readStateSnapshot(String appRootId) async {
    String? quarantineSourceId;
    var quarantineSourceName = 'manifest.json';
    String? safePreview;
    try {
      final manifestId = await _findChildFile(appRootId, 'manifest.json');
      if (manifestId == null) {
        throw const DriveDataIntegrityException(
          'drive_manifest_missing',
          'manifest.json을 찾을 수 없습니다.',
        );
      }
      quarantineSourceId = manifestId;
      final manifest = await _readJsonStrict(
        manifestId,
        label: 'manifest.json',
      );
      safePreview = _mapPreview('manifest.json', manifest);
      _validateManifestIdentity(manifest, appRootId);
      final files = _manifestFiles(manifest);
      if (manifest['layout'] == SyncDatasetCodec.layout) {
        final snapshot = await _readSegmentedSnapshot(
          appRootId: appRootId,
          manifest: manifest,
          files: files,
        );
        _hasPulledSnapshot = true;
        _lastPulledSnapshotFileId = null;
        _lastPulledSnapshotPreview = null;
        _lastPulledDatasetFingerprint = _datasetFingerprint(manifest);
        _lastPulledCanonicalFingerprint = null;
        return snapshot;
      }
      final snapshotEntry = files[SyncDatasetCodec.canonicalPath];
      if (snapshotEntry == null) {
        final stateFolderId = await _findChildFolder(appRootId, 'state');
        if (stateFolderId == null ||
            await _findChildFile(stateFolderId, 'snapshot.json') == null) {
          _hasPulledSnapshot = true;
          _lastPulledSnapshotFileId = null;
          _lastPulledSnapshotPreview = null;
          _lastPulledDatasetFingerprint = _datasetFingerprint(manifest);
          _lastPulledCanonicalFingerprint = null;
          _lastPulledSectionFileIds.clear();
          _lastPulledSectionPreviews.clear();
          _lastPulledSectionFingerprints.clear();
          _cachedSections.clear();
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
        throw DriveDataIntegrityException(
          'drive_manifest_invalid',
          'snapshot manifest 항목의 ID, revision 또는 SHA-256이 올바르지 않습니다.',
          preview: safePreview,
        );
      }
      quarantineSourceId = snapshotId;
      quarantineSourceName = 'snapshot.json';
      final metadata = await _readMetadata(snapshotId);
      final actualRevision = metadata['version']?.toString() ?? '';
      final revisionChanged = actualRevision != expectedRevision;
      final response = await _authorizedGet(
        Uri.parse('$_apiRoot/files/$snapshotId?alt=media'),
      );
      safePreview = _bytePreview('snapshot.json', response.bodyBytes);
      final actualSha = sha256.convert(response.bodyBytes).toString();
      Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw DriveDataIntegrityException(
          'drive_snapshot_invalid',
          'snapshot이 올바른 JSON이 아닙니다.',
          preview: safePreview,
        );
      }
      if (decoded is! Map) {
        throw DriveDataIntegrityException(
          'drive_snapshot_invalid',
          'snapshot은 JSON 객체여야 합니다.',
          preview: safePreview,
        );
      }
      final decodedDocument = Map<String, Object?>.from(decoded);
      final isSelfVerifiedCanonical =
          manifest['layout'] == SyncDatasetCodec.canonicalLayout &&
          decodedDocument['format'] == _canonicalEnvelopeFormat;
      final decodedSnapshot = _decodeCanonicalPayload(
        decodedDocument,
        preview: safePreview,
      );
      if (actualSha.toLowerCase() != expectedSha.toLowerCase()) {
        if (!isSelfVerifiedCanonical) {
          throw DriveDataIntegrityException(
            revisionChanged
                ? 'drive_manifest_revision_mismatch'
                : 'drive_manifest_sha_mismatch',
            revisionChanged
                ? 'manifest revision과 Drive 파일 내용이 함께 변경되었습니다.'
                : 'snapshot SHA-256이 manifest와 일치하지 않습니다.',
            preview: revisionChanged
                ? '$safePreview · manifest revision $expectedRevision · '
                      'Drive revision $actualRevision'
                : safePreview,
          );
        }
      }
      _hasPulledSnapshot = true;
      _lastPulledDatasetFingerprint = _datasetFingerprint(manifest);
      _lastPulledSnapshotFileId = snapshotId;
      _lastPulledCanonicalFingerprint =
          '$snapshotId|${actualSha.toLowerCase()}';
      _lastPulledSnapshotPreview =
          '$safePreview · ${_mapPreview('snapshot.json', decodedSnapshot)}';
      _lastPulledSectionFileIds.clear();
      _lastPulledSectionPreviews.clear();
      _lastPulledSectionFingerprints.clear();
      _cachedSections.clear();
      return decodedSnapshot;
    } on DriveDataIntegrityException catch (error) {
      if (error.quarantine != null ||
          quarantineSourceId == null ||
          !_shouldQuarantine(error.code)) {
        rethrow;
      }
      final quarantine = await _tryQuarantineFile(
        appRootId: appRootId,
        sourceFileId: quarantineSourceId,
        sourceFileName: quarantineSourceName,
        reasonCode: error.code,
        preview: error.preview ?? safePreview ?? quarantineSourceName,
      );
      throw error.withQuarantine(quarantine);
    }
  }

  Future<DriveQuarantineRecord?> quarantineLastPulledSnapshot({
    required String appRootId,
    required String reasonCode,
    required String preview,
  }) async {
    var sourceFileId = _lastPulledSnapshotFileId;
    var sourceFileName = 'snapshot.json';
    var storedPreview = _lastPulledSnapshotPreview;
    if (_lastPulledSectionFileIds.isNotEmpty) {
      final validationPath = RegExp(
        r'검증 경로 ([^ ·]+)',
      ).firstMatch(preview)?.group(1);
      final sectionPath = _datasetCodec.sectionPathForValidationPath(
        validationPath ?? r'$.schemaVersion',
      );
      sourceFileId = _lastPulledSectionFileIds[sectionPath];
      sourceFileName = sectionPath.split('/').last;
      storedPreview = _lastPulledSectionPreviews[sectionPath];
    }
    if (sourceFileId == null) return null;
    return _tryQuarantineFile(
      appRootId: appRootId,
      sourceFileId: sourceFileId,
      sourceFileName: sourceFileName,
      reasonCode: reasonCode,
      preview: [?storedPreview, preview].join(' · '),
    );
  }

  Future<Map<String, Object?>> _readSegmentedSnapshot({
    required String appRootId,
    required Map<String, Object?> manifest,
    required Map<String, Map<String, Object?>> files,
  }) async {
    final sections = <String, Map<String, Object?>>{};
    final nextFileIds = <String, String>{};
    final nextPreviews = <String, String>{};
    final nextFingerprints = <String, String>{};
    for (final path in SyncDatasetCodec.sectionPaths) {
      final entry = files[path];
      if (entry == null) {
        throw DriveDataIntegrityException(
          'drive_manifest_entry_missing',
          '$path manifest 항목이 없습니다.',
          preview: _mapPreview('manifest.json', manifest),
        );
      }
      final sourceFileId = entry['fileId'] as String? ?? '';
      try {
        final fingerprint = _snapshotFingerprint(entry);
        final cached = _cachedSections[path];
        if (cached != null &&
            _lastPulledSectionFingerprints[path] == fingerprint) {
          sections[path] = cached;
          nextFileIds[path] = sourceFileId;
          nextPreviews[path] = _lastPulledSectionPreviews[path] ?? path;
          nextFingerprints[path] = fingerprint;
          continue;
        }
        final section = await _readManifestEntryJson(path, entry);
        sections[path] = section.content;
        nextFileIds[path] = section.fileId;
        nextPreviews[path] = section.preview;
        nextFingerprints[path] = fingerprint;
      } on DriveDataIntegrityException catch (error) {
        if (sourceFileId.isEmpty || !_shouldQuarantine(error.code)) rethrow;
        final quarantine = await _tryQuarantineFile(
          appRootId: appRootId,
          sourceFileId: sourceFileId,
          sourceFileName: path.split('/').last,
          reasonCode: error.code,
          preview: error.preview ?? path,
        );
        throw error.withQuarantine(quarantine);
      }
    }
    try {
      final snapshot = _datasetCodec.join(sections);
      _lastPulledSectionFileIds
        ..clear()
        ..addAll(nextFileIds);
      _lastPulledSectionPreviews
        ..clear()
        ..addAll(nextPreviews);
      _lastPulledSectionFingerprints
        ..clear()
        ..addAll(nextFingerprints);
      _cachedSections
        ..clear()
        ..addAll(sections);
      return snapshot;
    } on SyncDatasetException catch (error) {
      throw DriveDataIntegrityException(
        error.code,
        error.message,
        preview: 'segmented-v1 · ${sections.length}개 섹션',
      );
    }
  }

  Future<_VerifiedJsonFile> _readManifestEntryJson(
    String path,
    Map<String, Object?> entry,
  ) async {
    final fileId = entry['fileId'] as String? ?? '';
    final expectedRevision = entry['revision']?.toString() ?? '';
    final expectedSha = entry['sha256'] as String? ?? '';
    if (fileId.isEmpty ||
        expectedRevision.isEmpty ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(expectedSha)) {
      throw DriveDataIntegrityException(
        'drive_manifest_invalid',
        '$path manifest 항목의 ID, revision 또는 SHA-256이 올바르지 않습니다.',
        preview: '$path manifest 항목',
      );
    }
    final metadata = await _readMetadata(fileId);
    final actualRevision = metadata['version']?.toString() ?? '';
    final revisionChanged = actualRevision != expectedRevision;
    final response = await _authorizedGet(
      Uri.parse('$_apiRoot/files/$fileId?alt=media'),
    );
    final preview = _bytePreview(path, response.bodyBytes);
    final actualSha = sha256.convert(response.bodyBytes).toString();
    if (actualSha.toLowerCase() != expectedSha.toLowerCase()) {
      throw DriveDataIntegrityException(
        revisionChanged
            ? 'drive_manifest_revision_mismatch'
            : 'drive_manifest_sha_mismatch',
        revisionChanged
            ? '$path revision과 파일 내용이 함께 변경되었습니다.'
            : '$path SHA-256이 manifest와 일치하지 않습니다.',
        preview: revisionChanged
            ? '$preview · manifest revision $expectedRevision · '
                  'Drive revision $actualRevision'
            : preview,
      );
    }
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) throw const FormatException();
      final content = Map<String, Object?>.from(decoded);
      return _VerifiedJsonFile(
        fileId: fileId,
        content: content,
        preview: '$preview · ${_mapPreview(path, content)}',
      );
    } on FormatException {
      throw DriveDataIntegrityException(
        'drive_json_invalid',
        '$path 파일이 올바른 JSON 객체가 아닙니다.',
        preview: preview,
      );
    } on TypeError {
      throw DriveDataIntegrityException(
        'drive_json_invalid',
        '$path 파일이 올바른 JSON 객체가 아닙니다.',
        preview: preview,
      );
    }
  }

  Map<String, Object?> _canonicalEnvelope({
    required Map<String, Object?> snapshot,
    required String writerOperationId,
    required DateTime writtenAt,
  }) {
    final payloadBytes = utf8.encode(jsonEncode(snapshot));
    return {
      'format': _canonicalEnvelopeFormat,
      'snapshotSchemaVersion': snapshot['schemaVersion'],
      'payloadSha256': sha256.convert(payloadBytes).toString(),
      'writerOperationId': writerOperationId,
      'writtenAt': writtenAt.toIso8601String(),
      'snapshot': snapshot,
    };
  }

  Map<String, Object?> _decodeCanonicalPayload(
    Map<String, Object?> document, {
    String? preview,
    String? expectedWriterOperationId,
  }) {
    if (document['format'] != _canonicalEnvelopeFormat) {
      return document;
    }
    final rawSnapshot = document['snapshot'];
    final expectedPayloadSha = document['payloadSha256'] as String? ?? '';
    final writerOperationId = document['writerOperationId'] as String? ?? '';
    if (rawSnapshot is! Map ||
        writerOperationId.isEmpty ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(expectedPayloadSha)) {
      throw DriveDataIntegrityException(
        'drive_snapshot_invalid',
        'canonical snapshot envelope 형식이 올바르지 않습니다.',
        preview: preview,
      );
    }
    if (expectedWriterOperationId != null &&
        writerOperationId != expectedWriterOperationId) {
      throw DriveDataIntegrityException(
        'drive_upload_conflict',
        'snapshot 저장 직후 다른 기기의 쓰기가 확인되었습니다. 원격 데이터를 다시 병합해야 합니다.',
        preview: preview,
      );
    }
    final snapshot = Map<String, Object?>.from(rawSnapshot);
    final actualPayloadSha = sha256
        .convert(utf8.encode(jsonEncode(snapshot)))
        .toString();
    if (actualPayloadSha.toLowerCase() != expectedPayloadSha.toLowerCase()) {
      throw DriveDataIntegrityException(
        'drive_snapshot_sha_mismatch',
        'canonical snapshot 내부 SHA-256 검증에 실패했습니다.',
        preview: preview,
      );
    }
    return snapshot;
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
        'updatedAt': _clock().toUtc().toIso8601String(),
      };
      await _uploadJson(manifestId, manifest);
    } else {
      manifest = await _readJsonStrict(manifestId, label: 'manifest.json');
      _validateManifestIdentity(manifest, appRootId);
    }
    final files = _manifestFiles(manifest);
    final currentFingerprint = _datasetFingerprint(manifest);
    if (_hasPulledSnapshot &&
        currentFingerprint != _lastPulledDatasetFingerprint) {
      throw const DriveDataIntegrityException(
        'drive_upload_conflict',
        '내려받은 뒤 다른 기기에서 동기화 dataset을 변경했습니다. 다시 병합해야 합니다.',
      );
    }
    final now = _clock().toUtc();
    final previousDatasetVersion =
        (manifest['datasetVersion'] as num?)?.toInt() ?? 1;
    final nextDatasetVersion = previousDatasetVersion + 1;
    final writerOperationId =
        'writer-${now.microsecondsSinceEpoch}-'
        '${identityHashCode(this).toRadixString(16)}-${_writerSequence++}';

    final existingEntry = files[SyncDatasetCodec.canonicalPath];
    String snapshotFileId;
    List<int>? previousSnapshotBytes;
    if (existingEntry != null) {
      if (manifest['layout'] == SyncDatasetCodec.canonicalLayout) {
        snapshotFileId = existingEntry['fileId'] as String? ?? '';
      } else {
        snapshotFileId = await _verifyEntryRevision(
          SyncDatasetCodec.canonicalPath,
          existingEntry,
          conflictCode: 'drive_upload_conflict',
        );
      }
      final response = await _authorizedGet(
        Uri.parse('$_apiRoot/files/$snapshotFileId?alt=media'),
      );
      previousSnapshotBytes = response.bodyBytes;
      final currentSha = sha256.convert(previousSnapshotBytes).toString();
      if (manifest['layout'] == SyncDatasetCodec.canonicalLayout) {
        try {
          final document = jsonDecode(utf8.decode(previousSnapshotBytes));
          if (document is! Map) throw const FormatException();
          _decodeCanonicalPayload(
            Map<String, Object?>.from(document),
            preview: _bytePreview('snapshot.json', previousSnapshotBytes),
          );
        } on FormatException {
          throw const DriveDataIntegrityException(
            'drive_snapshot_invalid',
            'canonical snapshot이 올바른 JSON 객체가 아닙니다.',
          );
        }
      }
      final currentCanonicalFingerprint =
          '$snapshotFileId|${currentSha.toLowerCase()}';
      if (_hasPulledSnapshot &&
          manifest['layout'] != SyncDatasetCodec.layout &&
          _lastPulledCanonicalFingerprint != null &&
          currentCanonicalFingerprint != _lastPulledCanonicalFingerprint) {
        throw const DriveDataIntegrityException(
          'drive_upload_conflict',
          'canonical snapshot이 다른 기기에서 변경되었습니다. 최신 데이터를 다시 병합해야 합니다.',
        );
      }
    } else {
      snapshotFileId = await _ensureJsonFileForPath(
        appRootId,
        SyncDatasetCodec.canonicalPath,
      );
    }

    final latestManifest = await _readJsonStrict(
      manifestId,
      label: 'manifest.json',
    );
    _validateManifestIdentity(latestManifest, appRootId);
    if (_datasetFingerprint(latestManifest) != currentFingerprint) {
      throw const DriveDataIntegrityException(
        'drive_upload_conflict',
        '섹션 업로드 중 다른 기기에서 manifest를 변경했습니다. 새 파일은 적용하지 않고 다시 병합해야 합니다.',
      );
    }

    final envelope = _canonicalEnvelope(
      snapshot: snapshot,
      writerOperationId: writerOperationId,
      writtenAt: now,
    );
    final encodedEnvelope = utf8.encode(jsonEncode(envelope));
    final envelopeSha = sha256.convert(encodedEnvelope).toString();
    await _uploadJson(snapshotFileId, envelope);
    final snapshotMetadata = await _readMetadata(snapshotFileId);
    final committedSnapshotResponse = await _authorizedGet(
      Uri.parse('$_apiRoot/files/$snapshotFileId?alt=media'),
    );
    final committedSnapshotBytes = committedSnapshotResponse.bodyBytes;
    final committedSnapshotSha = sha256
        .convert(committedSnapshotBytes)
        .toString();
    if (committedSnapshotSha.toLowerCase() != envelopeSha.toLowerCase()) {
      await _restoreCanonicalSnapshot(snapshotFileId, previousSnapshotBytes);
      throw const DriveDataIntegrityException(
        'drive_upload_conflict',
        'canonical snapshot 저장 직후 다른 기기의 쓰기가 확인되었습니다. 원격 데이터를 다시 병합해야 합니다.',
      );
    }
    try {
      final committedDocument = jsonDecode(utf8.decode(committedSnapshotBytes));
      if (committedDocument is! Map) throw const FormatException();
      _decodeCanonicalPayload(
        Map<String, Object?>.from(committedDocument),
        preview: _bytePreview('snapshot.json', committedSnapshotBytes),
        expectedWriterOperationId: writerOperationId,
      );
    } on FormatException {
      await _restoreCanonicalSnapshot(snapshotFileId, previousSnapshotBytes);
      throw const DriveDataIntegrityException(
        'drive_snapshot_invalid',
        '저장된 canonical snapshot을 다시 검증할 수 없습니다.',
      );
    }

    final manifestBeforeCommit = await _readJsonStrict(
      manifestId,
      label: 'manifest.json',
    );
    _validateManifestIdentity(manifestBeforeCommit, appRootId);
    if (_datasetFingerprint(manifestBeforeCommit) != currentFingerprint) {
      await _restoreCanonicalSnapshot(snapshotFileId, previousSnapshotBytes);
      throw const DriveDataIntegrityException(
        'drive_upload_conflict',
        'canonical snapshot 업로드 중 다른 기기에서 manifest를 변경했습니다. 최신 데이터를 다시 병합해야 합니다.',
      );
    }
    final nextEntry = <String, Object?>{
      'fileId': snapshotFileId,
      'revision':
          '${snapshotMetadata['version'] ?? now.microsecondsSinceEpoch}',
      'sha256': envelopeSha,
      'updatedAt':
          snapshotMetadata['modifiedTime'] as String? ?? now.toIso8601String(),
    };
    final nextManifest = <String, Object?>{
      'schemaVersion': 1,
      'datasetVersion': nextDatasetVersion,
      'layout': SyncDatasetCodec.canonicalLayout,
      'appRootFolderId': appRootId,
      'files': {SyncDatasetCodec.canonicalPath: nextEntry},
      'writerOperationId': writerOperationId,
      'parentDatasetFingerprint': currentFingerprint,
      'updatedAt': now.toIso8601String(),
    };
    try {
      await _uploadJson(manifestId, nextManifest);
    } catch (_) {
      await _restoreCanonicalSnapshot(snapshotFileId, previousSnapshotBytes);
      rethrow;
    }
    final committedManifest = await _readJsonStrict(
      manifestId,
      label: 'manifest.json',
    );
    _validateManifestIdentity(committedManifest, appRootId);
    if (committedManifest['writerOperationId'] != writerOperationId ||
        _datasetFingerprint(committedManifest) !=
            _datasetFingerprint(nextManifest)) {
      throw const DriveDataIntegrityException(
        'drive_upload_conflict',
        'manifest 저장 직후 다른 기기의 쓰기가 확인되었습니다. 원격 데이터를 다시 병합해야 합니다.',
      );
    }
    _hasPulledSnapshot = true;
    _lastPulledSnapshotFileId = snapshotFileId;
    _lastPulledSnapshotPreview =
        '${_bytePreview('snapshot.json', committedSnapshotBytes)} · '
        '${_mapPreview('snapshot.json', snapshot)}';
    _lastPulledDatasetFingerprint = _datasetFingerprint(committedManifest);
    _lastPulledCanonicalFingerprint =
        '$snapshotFileId|${envelopeSha.toLowerCase()}';
    _lastPulledSectionFileIds.clear();
    _lastPulledSectionPreviews.clear();
    _lastPulledSectionFingerprints.clear();
    _cachedSections.clear();
  }

  Future<_DriveListedItem?> _findAppDataBindingFile() async {
    final files = await _listDriveItems(
      query: [
        "name = '$appDataBindingFileName'",
        'trashed = false',
      ].join(' and '),
      spaces: 'appDataFolder',
    );
    if (files.length > 1) {
      throw const DriveDataIntegrityException(
        'drive_appdata_binding_duplicate',
        '숨김 Drive 설정 파일이 중복되어 안전하게 선택할 수 없습니다.',
      );
    }
    if (files.isEmpty) return null;
    final file = files.single;
    if (file.name != appDataBindingFileName || file.mimeType != _jsonMimeType) {
      throw const DriveDataIntegrityException(
        'drive_appdata_binding_invalid',
        '숨김 Drive 설정 파일의 이름 또는 형식이 올바르지 않습니다.',
      );
    }
    return file;
  }

  void _validateDiscoverableAppRootManifest(
    Map<String, Object?> manifest,
    String appRootId,
  ) {
    _validateManifestIdentity(manifest, appRootId);
    final rawDatasetVersion = manifest['datasetVersion'];
    final datasetVersion =
        rawDatasetVersion is num &&
            rawDatasetVersion.isFinite &&
            rawDatasetVersion == rawDatasetVersion.round()
        ? rawDatasetVersion.toInt()
        : null;
    if (datasetVersion == null || datasetVersion < 1) {
      throw const DriveDataIntegrityException(
        'drive_manifest_invalid',
        'manifest datasetVersion이 올바르지 않습니다.',
      );
    }
    final files = _manifestFiles(manifest);
    final layout = manifest['layout'];
    if (layout == SyncDatasetCodec.layout &&
        !SyncDatasetCodec.sectionPaths.every(files.containsKey)) {
      throw const DriveDataIntegrityException(
        'drive_manifest_invalid',
        '분할 manifest에 필수 데이터 파일 항목이 없습니다.',
      );
    }
    if (layout == SyncDatasetCodec.canonicalLayout &&
        !files.containsKey(SyncDatasetCodec.canonicalPath)) {
      throw const DriveDataIntegrityException(
        'drive_manifest_invalid',
        'canonical manifest에 snapshot 파일 항목이 없습니다.',
      );
    }
    if (layout == null &&
        files.isNotEmpty &&
        !files.containsKey(SyncDatasetCodec.canonicalPath)) {
      throw const DriveDataIntegrityException(
        'drive_manifest_invalid',
        'legacy manifest에 snapshot 파일 항목이 없습니다.',
      );
    }
    _datasetFingerprint(manifest);
  }

  Future<DriveAppDataBinding> _readAppDataBindingFile(
    _DriveListedItem file,
  ) async {
    final response = await _authorizedGet(
      Uri.parse('$_apiRoot/files/${file.id}?alt=media'),
    );
    if (response.bodyBytes.length > _maximumAppDataBindingBytes) {
      throw const DriveDataIntegrityException(
        'drive_appdata_binding_too_large',
        '숨김 Drive 설정 파일이 허용 크기를 초과했습니다.',
      );
    }
    try {
      final decoded = jsonDecode(
        utf8.decode(response.bodyBytes, allowMalformed: false),
      );
      if (decoded is! Map) throw const FormatException();
      return _parseAppDataBinding(Map<String, Object?>.from(decoded));
    } on DriveDataIntegrityException {
      rethrow;
    } on FormatException {
      throw const DriveDataIntegrityException(
        'drive_appdata_binding_invalid',
        '숨김 Drive 설정 파일이 올바른 JSON 객체가 아닙니다.',
      );
    } on TypeError {
      throw const DriveDataIntegrityException(
        'drive_appdata_binding_invalid',
        '숨김 Drive 설정 파일의 필드 형식이 올바르지 않습니다.',
      );
    }
  }

  DriveAppDataBinding _parseAppDataBinding(Map<String, Object?> json) {
    final rawSchemaVersion = json['schemaVersion'];
    final schemaVersion =
        rawSchemaVersion is num &&
            rawSchemaVersion.isFinite &&
            rawSchemaVersion == rawSchemaVersion.round()
        ? rawSchemaVersion.toInt()
        : null;
    if (schemaVersion != null && schemaVersion > appDataBindingSchemaVersion) {
      throw const DriveDataIntegrityException(
        'drive_appdata_binding_newer_schema',
        '숨김 Drive 설정 파일이 현재 앱보다 최신 스키마입니다.',
      );
    }
    final folderId = json['folderId'];
    final folderName = json['folderName'];
    final rawUpdatedAt = json['updatedAt'];
    final updatedAt = rawUpdatedAt is String
        ? DateTime.tryParse(rawUpdatedAt)?.toUtc()
        : null;
    if (schemaVersion != appDataBindingSchemaVersion ||
        !_validAppDataText(folderId, maximumLength: 200) ||
        !_validAppDataText(folderName, maximumLength: 240) ||
        updatedAt == null) {
      throw const DriveDataIntegrityException(
        'drive_appdata_binding_invalid',
        '숨김 Drive 설정 파일에 필수 바인딩 정보가 없습니다.',
      );
    }
    return DriveAppDataBinding(
      folderId: (folderId! as String).trim(),
      folderName: (folderName! as String).trim(),
      schemaVersion: schemaVersion!,
      updatedAt: updatedAt,
    );
  }

  bool _validAppDataText(Object? value, {required int maximumLength}) =>
      value is String &&
      value.trim().isNotEmpty &&
      value.runes.length <= maximumLength &&
      !RegExp(r'[\u0000-\u001F\u007F]').hasMatch(value);

  Future<String> _createAppDataBindingFile() async {
    final token = await accessTokenProvider();
    final response = await _driveRequest(
      operation: 'create Drive app data binding',
      send: () => _httpClient.post(
        Uri.parse('$_apiRoot/files?fields=id,name,mimeType'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'name': appDataBindingFileName,
          'parents': ['appDataFolder'],
          'mimeType': _jsonMimeType,
        }),
      ),
    );
    try {
      final body = jsonDecode(response.body);
      final fileId = body is Map ? body['id'] as String? : null;
      if (fileId == null || fileId.trim().isEmpty) {
        throw const FormatException();
      }
      return fileId.trim();
    } on FormatException {
      throw const DriveDataIntegrityException(
        'drive_appdata_binding_create_invalid',
        'Drive가 숨김 설정 파일 ID를 반환하지 않았습니다.',
      );
    } on TypeError {
      throw const DriveDataIntegrityException(
        'drive_appdata_binding_create_invalid',
        'Drive가 숨김 설정 파일 ID를 반환하지 않았습니다.',
      );
    }
  }

  Future<void> _deleteAppDataFile(String fileId) async {
    final token = await accessTokenProvider();
    await _driveRequest(
      operation: 'delete Drive app data binding',
      send: () => _httpClient.delete(
        Uri.parse('$_apiRoot/files/$fileId'),
        headers: {'authorization': 'Bearer $token'},
      ),
    );
  }

  Future<void> _bestEffortDeleteAppDataFile(String fileId) async {
    try {
      await _deleteAppDataFile(fileId);
    } catch (_) {
      // Preserve the upload failure as the actionable error. A later lookup
      // will reject the empty or malformed file instead of touching data.
    }
  }

  Future<List<_DriveListedItem>> _listDriveItems({
    required String query,
    required String spaces,
  }) async {
    final items = <String, _DriveListedItem>{};
    final seenPageTokens = <String>{};
    String? pageToken;
    do {
      final queryParameters = <String, String>{
        'q': query,
        'spaces': spaces,
        'fields': 'nextPageToken,files(id,name,mimeType,trashed)',
        'pageSize': '100',
      };
      if (pageToken != null) queryParameters['pageToken'] = pageToken;
      final response = await _authorizedGet(
        Uri.parse('$_apiRoot/files').replace(queryParameters: queryParameters),
      );
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) throw const FormatException();
        final rawFiles = decoded['files'];
        if (rawFiles != null && rawFiles is! List) {
          throw const FormatException();
        }
        for (final raw in (rawFiles as List? ?? const [])) {
          if (raw is! Map || raw['trashed'] == true) continue;
          final id = raw['id'];
          final name = raw['name'];
          final mimeType = raw['mimeType'];
          if (id is! String ||
              id.trim().isEmpty ||
              name is! String ||
              name.trim().isEmpty ||
              mimeType is! String ||
              mimeType.trim().isEmpty) {
            throw const FormatException();
          }
          items[id] = _DriveListedItem(id: id, name: name, mimeType: mimeType);
        }
        final rawNextPageToken = decoded['nextPageToken'];
        if (rawNextPageToken != null && rawNextPageToken is! String) {
          throw const FormatException();
        }
        pageToken = rawNextPageToken as String?;
        if (pageToken != null &&
            pageToken.isNotEmpty &&
            !seenPageTokens.add(pageToken)) {
          throw const FormatException();
        }
      } on FormatException {
        throw const DriveDataIntegrityException(
          'drive_file_list_invalid',
          'Drive 파일 목록 응답이 올바르지 않습니다.',
        );
      } on TypeError {
        throw const DriveDataIntegrityException(
          'drive_file_list_invalid',
          'Drive 파일 목록 응답이 올바르지 않습니다.',
        );
      }
    } while (pageToken != null && pageToken.isNotEmpty);
    return List.unmodifiable(items.values);
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

  Future<String> _ensureJsonFileForPath(String appRootId, String path) async {
    final segments = path.split('/');
    if (segments.length != 2) {
      throw DriveDataIntegrityException(
        'drive_manifest_invalid',
        '지원하지 않는 동기화 파일 경로입니다: $path',
      );
    }
    final folderId =
        await _findChildFolder(appRootId, segments.first) ??
        await _createFolder(segments.first, appRootId);
    return await _findChildFile(folderId, segments.last) ??
        await _createFile(
          name: segments.last,
          parentId: folderId,
          mimeType: 'application/json',
        );
  }

  Future<String> _verifyEntryRevision(
    String path,
    Map<String, Object?> entry, {
    required String conflictCode,
  }) async {
    final fileId = entry['fileId'] as String? ?? '';
    final expectedRevision = entry['revision']?.toString() ?? '';
    final expectedSha = entry['sha256'] as String? ?? '';
    if (fileId.isEmpty ||
        expectedRevision.isEmpty ||
        !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(expectedSha)) {
      throw DriveDataIntegrityException(
        'drive_manifest_invalid',
        '$path manifest 항목이 올바르지 않습니다.',
      );
    }
    final metadata = await _readMetadata(fileId);
    final currentRevision = metadata['version']?.toString() ?? '';
    if (currentRevision != expectedRevision) {
      final response = await _authorizedGet(
        Uri.parse('$_apiRoot/files/$fileId?alt=media'),
      );
      final currentSha = sha256.convert(response.bodyBytes).toString();
      if (currentSha.toLowerCase() != expectedSha.toLowerCase()) {
        throw DriveDataIntegrityException(
          conflictCode,
          '$path 파일 내용이 다른 기기에서 변경되었습니다. 다시 내려받아 병합해야 합니다.',
        );
      }
    }
    return fileId;
  }

  Future<String?> _findChild({
    required String parentId,
    required String name,
    String? mimeType,
  }) async {
    final escapedName = name.replaceAll("'", r"\'");
    final query = [
      "'$parentId' in parents",
      "name = '$escapedName'",
      if (mimeType != null) "mimeType = '$mimeType'",
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

  Future<List<_DriveChildFile>> _listChildren(String parentId) async {
    final children = <_DriveChildFile>[];
    String? pageToken;
    do {
      final queryParameters = <String, String>{
        'q': "'$parentId' in parents and trashed = false",
        'spaces': 'drive',
        'fields':
            'nextPageToken,files(id,name,mimeType,size,modifiedTime,trashed)',
        'pageSize': '1000',
      };
      if (pageToken != null) queryParameters['pageToken'] = pageToken;
      final uri = Uri.parse(
        '$_apiRoot/files',
      ).replace(queryParameters: queryParameters);
      final response = await _authorizedGet(uri);
      final body = jsonDecode(response.body) as Map<String, Object?>;
      final files = body['files'] as List<Object?>? ?? const [];
      for (final raw in files) {
        final file = Map<String, Object?>.from(raw! as Map);
        if (file['trashed'] == true) continue;
        final id = file['id'] as String? ?? '';
        final name = file['name'] as String? ?? '';
        final mimeType = file['mimeType'] as String? ?? '';
        final modifiedAt = DateTime.tryParse(
          file['modifiedTime'] as String? ?? '',
        )?.toUtc();
        if (id.isEmpty ||
            name.isEmpty ||
            mimeType.isEmpty ||
            modifiedAt == null) {
          continue;
        }
        children.add(
          _DriveChildFile(
            id: id,
            name: name,
            mimeType: mimeType,
            byteLength: int.tryParse(file['size']?.toString() ?? '') ?? 0,
            modifiedAt: modifiedAt,
          ),
        );
      }
      pageToken = body['nextPageToken'] as String?;
    } while (pageToken != null && pageToken.isNotEmpty);
    return children;
  }

  Future<void> _trashFile(String fileId) async {
    final token = await accessTokenProvider();
    await _driveRequest(
      operation: 'move unused Drive file to trash',
      send: () => _httpClient.patch(
        Uri.parse('$_apiRoot/files/$fileId?fields=id,trashed'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'trashed': true}),
      ),
    );
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
    final response = await _driveRequest(
      operation: 'create Drive item',
      send: () => _httpClient.post(
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
      ),
    );
    return (jsonDecode(response.body) as Map<String, Object?>)['id']! as String;
  }

  Future<void> _uploadJson(String fileId, Map<String, Object?> content) async {
    return _uploadJsonBytes(fileId, utf8.encode(jsonEncode(content)));
  }

  Future<void> _uploadJsonBytes(String fileId, List<int> bytes) async {
    final token = await accessTokenProvider();
    await _driveRequest(
      operation: 'upload Drive JSON',
      send: () => _httpClient.patch(
        Uri.parse('$_uploadRoot/files/$fileId?uploadType=media'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json; charset=utf-8',
        },
        body: bytes,
      ),
    );
  }

  Future<void> _restoreCanonicalSnapshot(
    String fileId,
    List<int>? previousBytes,
  ) async {
    if (previousBytes == null || previousBytes.isEmpty) return;
    try {
      await _uploadJsonBytes(fileId, previousBytes);
    } catch (_) {
      // The original error remains the actionable result. A later pull still
      // validates both the manifest checksum and the envelope checksum.
    }
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
    final preview = _bytePreview(label, response.bodyBytes);
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
        preview: preview,
      );
    } on TypeError {
      throw DriveDataIntegrityException(
        'drive_json_invalid',
        '$label 파일이 올바른 JSON 객체가 아닙니다.',
        preview: preview,
      );
    }
  }

  bool _shouldQuarantine(String code) => const {
    'drive_json_invalid',
    'drive_manifest_invalid',
    'drive_manifest_root_mismatch',
    'drive_manifest_revision_mismatch',
    'drive_manifest_sha_mismatch',
    'drive_snapshot_invalid',
    'drive_snapshot_sha_mismatch',
  }.contains(code);

  Future<DriveQuarantineRecord?> _tryQuarantineFile({
    required String appRootId,
    required String sourceFileId,
    required String sourceFileName,
    required String reasonCode,
    required String preview,
  }) async {
    try {
      final quarantineFolderId =
          await _findChildFolder(appRootId, 'quarantine') ??
          await _createFolder('quarantine', appRootId);
      final createdAt = DateTime.now().toUtc();
      final timestamp = createdAt
          .toIso8601String()
          .replaceAll(':', '')
          .replaceAll('.', '-');
      final safeReason = reasonCode.replaceFirst('drive_', '');
      final fileName = '$sourceFileName.$safeReason.$timestamp.copy';
      final token = await accessTokenProvider();
      final response = await _driveRequest(
        operation: 'copy corrupt Drive file',
        send: () => _httpClient.post(
          Uri.parse(
            '$_apiRoot/files/$sourceFileId/copy'
            '?fields=id,name,createdTime,size',
          ),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'name': fileName,
            'parents': [quarantineFolderId],
          }),
        ),
      );
      final body = jsonDecode(response.body) as Map<String, Object?>;
      final fileId = body['id'] as String? ?? '';
      if (fileId.isEmpty) return null;
      return DriveQuarantineRecord(
        fileId: fileId,
        fileName: body['name'] as String? ?? fileName,
        sourceFileId: sourceFileId,
        createdAt: createdAt,
        reasonCode: reasonCode,
        preview: preview,
      );
    } catch (_) {
      return null;
    }
  }

  String _mapPreview(String label, Map<String, Object?> value) {
    final keys = value.keys.take(6).join(', ');
    final schemaVersion = value['schemaVersion'];
    final schema = schemaVersion == null ? '' : ' · schema $schemaVersion';
    return '$label JSON 객체$schema · 최상위 키 ${value.length}개'
        '${keys.isEmpty ? '' : ': $keys'}';
  }

  String _bytePreview(String label, List<int> bytes) {
    final checksum = sha256.convert(bytes).toString();
    return '$label · ${bytes.length} bytes · SHA-256 ${checksum.substring(0, 16)}…';
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
    final layout = manifest['layout'];
    if (layout != null && layout is! String) {
      throw const DriveDataIntegrityException(
        'drive_manifest_invalid',
        'manifest layout 형식이 올바르지 않습니다.',
      );
    }
    if (layout is String &&
        layout != SyncDatasetCodec.layout &&
        layout != SyncDatasetCodec.canonicalLayout) {
      throw const DriveDataIntegrityException(
        'drive_manifest_newer_layout',
        'manifest 동기화 레이아웃을 현재 앱에서 지원하지 않습니다.',
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

  String _datasetFingerprint(Map<String, Object?> manifest) {
    final files = _manifestFiles(manifest);
    final paths = files.keys.toList()..sort();
    final signature = [
      manifest['layout']?.toString() ?? 'legacy-snapshot-v1',
      manifest['datasetVersion']?.toString() ?? '1',
      for (final path in paths) '$path=${_snapshotFingerprint(files[path]!)}',
    ].join('|');
    return sha256.convert(utf8.encode(signature)).toString();
  }

  Future<http.Response> _authorizedGet(Uri uri) async {
    final token = await accessTokenProvider();
    return _driveRequest(
      operation: 'read Drive metadata',
      send: () =>
          _httpClient.get(uri, headers: {'authorization': 'Bearer $token'}),
    );
  }

  Future<http.Response> _driveRequest({
    required String operation,
    required Future<http.Response> Function() send,
  }) async {
    try {
      final response = await send().timeout(requestTimeout);
      _ensureSuccess(response, operation: operation);
      return response;
    } on DriveRequestException {
      rethrow;
    } on TimeoutException {
      throw DriveRequestException(
        failure: DriveRequestFailure.serviceUnavailable,
        statusCode: 0,
        operation: operation,
      );
    } on http.ClientException {
      throw DriveRequestException(
        failure: DriveRequestFailure.serviceUnavailable,
        statusCode: 0,
        operation: operation,
      );
    } on SocketException {
      throw DriveRequestException(
        failure: DriveRequestFailure.serviceUnavailable,
        statusCode: 0,
        operation: operation,
      );
    } on HandshakeException {
      throw DriveRequestException(
        failure: DriveRequestFailure.serviceUnavailable,
        statusCode: 0,
        operation: operation,
      );
    }
  }

  void _ensureSuccess(http.Response response, {required String operation}) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final reasons = _driveErrorReasons(response);
    final failure = switch (response.statusCode) {
      401 => DriveRequestFailure.authenticationExpired,
      404 => DriveRequestFailure.resourceMissing,
      429 => DriveRequestFailure.rateLimited,
      >= 500 => DriveRequestFailure.serviceUnavailable,
      403 when reasons.any(_isRateLimitReason) =>
        DriveRequestFailure.rateLimited,
      403 when reasons.any(_isQuotaReason) => DriveRequestFailure.quotaExceeded,
      403 => DriveRequestFailure.permissionRevoked,
      _ => DriveRequestFailure.requestFailed,
    };
    throw DriveRequestException(
      failure: failure,
      statusCode: response.statusCode,
      operation: operation,
      retryAfter: _retryAfter(response),
    );
  }

  Set<String> _driveErrorReasons(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is! Map) return const {};
      final error = body['error'];
      if (error is! Map) return const {};
      final reasons = <String>{};
      final details = error['errors'];
      if (details is List) {
        for (final detail in details) {
          if (detail is Map) {
            final reason = detail['reason'];
            if (reason is String) reasons.add(reason);
          }
        }
      }
      if (error['status'] case final String status) reasons.add(status);
      return reasons;
    } catch (_) {
      return const {};
    }
  }

  bool _isRateLimitReason(String reason) {
    final normalized = reason.toLowerCase();
    return normalized.contains('ratelimit') ||
        normalized.contains('rate_limit') ||
        normalized.contains('dailylimit') ||
        normalized == 'resource_exhausted';
  }

  bool _isQuotaReason(String reason) => reason.toLowerCase().contains('quota');

  Duration? _retryAfter(http.Response response) {
    final seconds = int.tryParse(response.headers['retry-after'] ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }
}

class _DriveChildFile {
  const _DriveChildFile({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.byteLength,
    required this.modifiedAt,
  });

  final String id;
  final String name;
  final String mimeType;
  final int byteLength;
  final DateTime modifiedAt;
}

class _DriveListedItem {
  const _DriveListedItem({
    required this.id,
    required this.name,
    required this.mimeType,
  });

  final String id;
  final String name;
  final String mimeType;
}

class _VerifiedJsonFile {
  const _VerifiedJsonFile({
    required this.fileId,
    required this.content,
    required this.preview,
  });

  final String fileId;
  final Map<String, Object?> content;
  final String preview;
}
