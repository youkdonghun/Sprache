class ManifestFile {
  const ManifestFile({
    required this.fileId,
    required this.revision,
    required this.sha256,
    required this.updatedAt,
  });

  final String fileId;
  final String revision;
  final String sha256;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'fileId': fileId,
    'revision': revision,
    'sha256': sha256,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory ManifestFile.fromJson(Map<String, Object?> json) => ManifestFile(
    fileId: json['fileId']! as String,
    revision: json['revision']! as String,
    sha256: json['sha256']! as String,
    updatedAt: DateTime.parse(json['updatedAt']! as String),
  );
}

class SyncManifest {
  const SyncManifest({
    required this.schemaVersion,
    required this.datasetVersion,
    required this.appRootFolderId,
    required this.files,
    required this.updatedAt,
  });

  final int schemaVersion;
  final int datasetVersion;
  final String appRootFolderId;
  final Map<String, ManifestFile> files;
  final DateTime updatedAt;

  Set<String> changedFilesComparedTo(SyncManifest? local) {
    if (local == null) return files.keys.toSet();
    return {
      for (final entry in files.entries)
        if (local.files[entry.key]?.revision != entry.value.revision ||
            local.files[entry.key]?.sha256 != entry.value.sha256)
          entry.key,
    };
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'datasetVersion': datasetVersion,
    'appRootFolderId': appRootFolderId,
    'files': {
      for (final entry in files.entries) entry.key: entry.value.toJson(),
    },
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory SyncManifest.fromJson(Map<String, Object?> json) {
    final filesJson = json['files']! as Map<String, Object?>;
    return SyncManifest(
      schemaVersion: json['schemaVersion']! as int,
      datasetVersion: json['datasetVersion']! as int,
      appRootFolderId: json['appRootFolderId']! as String,
      files: {
        for (final entry in filesJson.entries)
          entry.key: ManifestFile.fromJson(
            entry.value! as Map<String, Object?>,
          ),
      },
      updatedAt: DateTime.parse(json['updatedAt']! as String),
    );
  }
}

class SyncRecord {
  const SyncRecord({
    required this.id,
    required this.updatedAt,
    required this.deviceId,
    required this.payload,
    this.deletedAt,
  });

  final String id;
  final DateTime updatedAt;
  final String deviceId;
  final Map<String, Object?> payload;
  final DateTime? deletedAt;

  bool get deleted => deletedAt != null;
}
