class SyncDatasetCodec {
  const SyncDatasetCodec();

  static const layout = 'segmented-v1';
  static const canonicalLayout = 'canonical-v1';
  static const canonicalPath = 'state/snapshot.json';

  static const sectionPaths = <String>[
    'state/meta.json',
    'state/profile.json',
    'state/settings.json',
    'state/progress.json',
    'content/custom-items.json',
    'state/sessions.json',
  ];

  Map<String, Map<String, Object?>> split(Map<String, Object?> snapshot) {
    return {
      'state/meta.json': {
        'schemaVersion': snapshot['schemaVersion'],
        'updatedAt': snapshot['updatedAt'],
      },
      'state/profile.json': {'profile': snapshot['profile']},
      'state/settings.json': {'settings': snapshot['settings']},
      'state/progress.json': {'progress': snapshot['progress']},
      'content/custom-items.json': {
        'customItems': snapshot['customItems'],
        'customItemTombstones': snapshot['customItemTombstones'],
      },
      'state/sessions.json': {
        'recentSessions': snapshot['recentSessions'],
        'activeStudy': snapshot['activeStudy'],
      },
    };
  }

  Map<String, Object?> join(Map<String, Map<String, Object?>> sections) {
    final missing = [
      for (final path in sectionPaths)
        if (!sections.containsKey(path)) path,
    ];
    if (missing.isNotEmpty) {
      throw SyncDatasetException(
        'sync_dataset_section_missing',
        '필수 동기화 섹션이 없습니다: ${missing.join(', ')}',
      );
    }
    return {
      ...sections['state/meta.json']!,
      ...sections['state/profile.json']!,
      ...sections['state/settings.json']!,
      ...sections['state/progress.json']!,
      ...sections['content/custom-items.json']!,
      ...sections['state/sessions.json']!,
    };
  }

  String sectionPathForValidationPath(String validationPath) {
    if (validationPath.startsWith(r'$.profile')) {
      return 'state/profile.json';
    }
    if (validationPath.startsWith(r'$.settings')) {
      return 'state/settings.json';
    }
    if (validationPath.startsWith(r'$.progress')) {
      return 'state/progress.json';
    }
    if (validationPath.startsWith(r'$.customItems') ||
        validationPath.startsWith(r'$.customItemTombstones')) {
      return 'content/custom-items.json';
    }
    if (validationPath.startsWith(r'$.recentSessions') ||
        validationPath.startsWith(r'$.activeStudy')) {
      return 'state/sessions.json';
    }
    return 'state/meta.json';
  }
}

class SyncDatasetException implements Exception {
  const SyncDatasetException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}
