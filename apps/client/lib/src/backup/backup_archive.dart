import 'dart:convert';

import '../domain/dataset_capacity.dart';
import '../domain/language.dart';
import '../domain/study_history.dart';
import '../domain/study_subject.dart';
import '../sync/snapshot_validator.dart';

class BackupArchiveException implements Exception {
  const BackupArchiveException(this.message, {this.path});

  final String message;
  final String? path;

  @override
  String toString() => path == null ? message : '$path: $message';
}

class BackupArchive {
  const BackupArchive._({
    required this.snapshot,
    required this.sessions,
    required this.exportedAt,
    required this.selectedLanguage,
    required this.totalXp,
    required this.progressCount,
    required this.customItemCount,
  });

  final Map<String, Object?> snapshot;
  final List<StudySessionSummary> sessions;
  final DateTime exportedAt;
  final LanguageTag selectedLanguage;
  final int totalXp;
  final int progressCount;
  final int customItemCount;
}

enum BackupRestoreCategory { content, progress, sessions, settings }

extension BackupRestoreCategoryLabel on BackupRestoreCategory {
  String get label => switch (this) {
    BackupRestoreCategory.content => '개인 콘텐츠',
    BackupRestoreCategory.progress => '진도·XP',
    BackupRestoreCategory.sessions => '학습 세션',
    BackupRestoreCategory.settings => '학습·화면 설정',
  };
}

class BackupRestoreSelection {
  const BackupRestoreSelection({
    this.content = true,
    this.progress = true,
    this.sessions = true,
    this.settings = true,
  });

  final bool content;
  final bool progress;
  final bool sessions;
  final bool settings;

  bool get any => content || progress || sessions || settings;

  bool includes(BackupRestoreCategory category) => switch (category) {
    BackupRestoreCategory.content => content,
    BackupRestoreCategory.progress => progress,
    BackupRestoreCategory.sessions => sessions,
    BackupRestoreCategory.settings => settings,
  };

  BackupRestoreSelection copyWith({
    bool? content,
    bool? progress,
    bool? sessions,
    bool? settings,
  }) => BackupRestoreSelection(
    content: content ?? this.content,
    progress: progress ?? this.progress,
    sessions: sessions ?? this.sessions,
    settings: settings ?? this.settings,
  );
}

class BackupRestoreDelta {
  const BackupRestoreDelta({
    this.added = 0,
    this.changed = 0,
    this.preserved = 0,
  });

  final int added;
  final int changed;
  final int preserved;

  BackupRestoreDelta operator +(BackupRestoreDelta other) => BackupRestoreDelta(
    added: added + other.added,
    changed: changed + other.changed,
    preserved: preserved + other.preserved,
  );
}

class BackupRestorePreview {
  const BackupRestorePreview(this.byCategory);

  final Map<BackupRestoreCategory, BackupRestoreDelta> byCategory;

  BackupRestoreDelta get total => byCategory.values.fold(
    const BackupRestoreDelta(),
    (sum, value) => sum + value,
  );
}

class BackupArchiveCodec {
  const BackupArchiveCodec({
    this.snapshotValidator = const SyncSnapshotValidator(),
  });

  static const maxArchiveBytes = DatasetCapacityPolicy.maxBackupArchiveBytes;
  static const maxSessions = 5000;

  final SyncSnapshotValidator snapshotValidator;

  BackupArchive decode(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const BackupArchiveException('올바른 JSON 백업 파일이 아닙니다.');
    }
    if (decoded is! Map) {
      throw const BackupArchiveException(
        '백업 최상위 값은 JSON 객체여야 합니다.',
        path: r'$',
      );
    }
    Map<String, Object?> json;
    try {
      json = Map<String, Object?>.from(decoded);
    } catch (_) {
      throw const BackupArchiveException('백업 키 형식이 올바르지 않습니다.', path: r'$');
    }
    return validate(json);
  }

  BackupArchive validate(Map<String, Object?> json) {
    const requiredKeys = {
      'schemaVersion',
      'updatedAt',
      'profile',
      'settings',
      'progress',
      'customItems',
      'customItemTombstones',
      'activeStudy',
      'exportedAt',
      'sessions',
    };
    final missing = requiredKeys
        .where((key) => !json.containsKey(key))
        .toList();
    if (missing.isNotEmpty) {
      throw BackupArchiveException(
        '필수 항목이 없습니다: ${missing.join(', ')}',
        path: r'$',
      );
    }

    final schemaVersion = _integer(json['schemaVersion']);
    if (schemaVersion == null || schemaVersion < 1) {
      throw const BackupArchiveException(
        'schemaVersion은 1 이상의 정수여야 합니다.',
        path: r'$.schemaVersion',
      );
    }
    if (schemaVersion > 1) {
      throw const BackupArchiveException(
        '이 앱보다 새로운 백업 형식입니다. Sprache를 업데이트한 뒤 다시 시도해 주세요.',
        path: r'$.schemaVersion',
      );
    }
    final snapshotSchemaVersion =
        _integer(json['snapshotSchemaVersion']) ?? schemaVersion;
    if (snapshotSchemaVersion < 1 || snapshotSchemaVersion > 2) {
      throw const BackupArchiveException(
        '지원하지 않는 학습 데이터 형식입니다. Sprache를 업데이트한 뒤 다시 시도해 주세요.',
        path: r'$.snapshotSchemaVersion',
      );
    }

    try {
      snapshotValidator.validate({
        ...json,
        'schemaVersion': snapshotSchemaVersion,
      });
    } on RemoteSnapshotValidationException catch (error) {
      throw BackupArchiveException(error.first.message, path: error.first.path);
    }

    final exportedAt = _date(json['exportedAt']);
    if (exportedAt == null) {
      throw const BackupArchiveException(
        'ISO 8601 내보내기 시각이 필요합니다.',
        path: r'$.exportedAt',
      );
    }

    final profile = _requiredMap(json['profile'], r'$.profile');
    final languageCode = profile['selectedLanguage'];
    final selectedLanguage = LanguageTag.values
        .where((language) => language.code == languageCode)
        .firstOrNull;
    if (selectedLanguage == null) {
      throw const BackupArchiveException(
        '지원하는 학습 언어 코드가 필요합니다.',
        path: r'$.profile.selectedLanguage',
      );
    }

    final rawSessions = json['sessions'];
    if (rawSessions is! List<Object?>) {
      throw const BackupArchiveException(
        '학습 기록은 배열이어야 합니다.',
        path: r'$.sessions',
      );
    }
    if (rawSessions.length > maxSessions) {
      throw const BackupArchiveException(
        '학습 기록은 최대 5,000개까지 복원할 수 있습니다.',
        path: r'$.sessions',
      );
    }

    final sessionIds = <String>{};
    final sessions = <StudySessionSummary>[];
    for (final (index, raw) in rawSessions.indexed) {
      final path =
          r'$.sessions'
          '[$index]';
      final sessionJson = _requiredMap(raw, path);
      final rawJourney = sessionJson['journey'];
      if (rawJourney is List<Object?> && rawJourney.length > 1000) {
        throw BackupArchiveException(
          '한 학습 기록의 여정은 최대 1,000개까지 허용됩니다.',
          path: '$path.journey',
        );
      }
      StudySessionSummary session;
      try {
        session = StudySessionSummary.fromJson(sessionJson);
      } on FormatException {
        throw BackupArchiveException('학습 기록 필드 형식이 올바르지 않습니다.', path: path);
      }
      if (session.sessionId.runes.length > 160) {
        throw BackupArchiveException(
          '세션 ID는 160자 이하여야 합니다.',
          path: '$path.sessionId',
        );
      }
      if (!isSupportedCourseId(session.courseId)) {
        throw BackupArchiveException(
          '지원하지 않는 학습 코스입니다.',
          path: '$path.courseId',
        );
      }
      if (session.endedAt.isBefore(session.startedAt)) {
        throw BackupArchiveException(
          '종료 시각은 시작 시각보다 빠를 수 없습니다.',
          path: '$path.endedAt',
        );
      }
      if (!sessionIds.add(session.sessionId)) {
        throw BackupArchiveException(
          '같은 세션 ID가 두 번 포함되어 있습니다.',
          path: '$path.sessionId',
        );
      }
      sessions.add(session);
    }

    final progress = json['progress'] as List<Object?>;
    final customItems = json['customItems'] as List<Object?>;
    final totalXp = _integer(profile['totalXp']) ?? 0;
    final snapshot = <String, Object?>{
      for (final key in const [
        'updatedAt',
        'profile',
        'settings',
        'progress',
        'customItems',
        'customItemTombstones',
        'activeStudy',
      ])
        key: json[key],
      'schemaVersion': snapshotSchemaVersion,
    };
    return BackupArchive._(
      snapshot: Map.unmodifiable(snapshot),
      sessions: List.unmodifiable(sessions),
      exportedAt: exportedAt,
      selectedLanguage: selectedLanguage,
      totalXp: totalXp,
      progressCount: progress.length,
      customItemCount: customItems.length,
    );
  }

  Map<String, Object?> _requiredMap(Object? raw, String path) {
    if (raw is! Map) {
      throw BackupArchiveException('JSON 객체여야 합니다.', path: path);
    }
    try {
      return Map<String, Object?>.from(raw);
    } catch (_) {
      throw BackupArchiveException('객체 키 형식이 올바르지 않습니다.', path: path);
    }
  }

  int? _integer(Object? raw) {
    if (raw is! num || !raw.isFinite || raw != raw.round()) return null;
    return raw.toInt();
  }

  DateTime? _date(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }
}

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.customItemCount,
    required this.progressCount,
    required this.restoredSessionCount,
    required this.recentSessionCount,
  });

  final int customItemCount;
  final int progressCount;
  final int restoredSessionCount;
  final int recentSessionCount;
}
