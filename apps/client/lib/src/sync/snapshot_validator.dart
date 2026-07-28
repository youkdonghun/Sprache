import '../domain/active_study_session.dart';
import '../domain/language.dart';
import '../domain/learning_item_codec.dart';
import '../domain/progress.dart';
import '../domain/study_preferences.dart';

class SnapshotValidationIssue {
  const SnapshotValidationIssue({required this.path, required this.message});

  final String path;
  final String message;
}

class RemoteSnapshotValidationException implements Exception {
  const RemoteSnapshotValidationException(this.issues);

  final List<SnapshotValidationIssue> issues;

  SnapshotValidationIssue get first => issues.first;

  @override
  String toString() => '원격 데이터 검증 실패: ${first.path} ${first.message}';
}

class SyncSnapshotValidator {
  const SyncSnapshotValidator({this.itemCodec = const LearningItemCodec()});

  final LearningItemCodec itemCodec;

  void validate(Map<String, Object?> snapshot) {
    final issues = <SnapshotValidationIssue>[];
    _validateSchema(snapshot, issues);
    _validateDate(snapshot['updatedAt'], r'$.updatedAt', issues);
    _validateProfile(snapshot['profile'], issues);
    _validateSettings(snapshot['settings'], issues);
    _validateProgress(snapshot['progress'], issues);
    _validateCustomItems(snapshot['customItems'], issues);
    _validateCustomItemTombstones(snapshot['customItemTombstones'], issues);
    _validateActiveStudy(snapshot['activeStudy'], issues);
    if (issues.isNotEmpty) {
      throw RemoteSnapshotValidationException(List.unmodifiable(issues));
    }
  }

  void _validateSchema(
    Map<String, Object?> snapshot,
    List<SnapshotValidationIssue> issues,
  ) {
    final raw = snapshot['schemaVersion'];
    if (raw == null) return;
    final value = _integer(raw);
    if (value == null || value < 1) {
      _add(issues, r'$.schemaVersion', '1 이상의 정수여야 합니다.');
    }
  }

  void _validateProfile(Object? raw, List<SnapshotValidationIssue> issues) {
    if (raw == null) return;
    final profile = _map(raw, r'$.profile', issues);
    if (profile == null) return;
    for (final field in const ['totalXp', 'streakDays', 'dailyXp']) {
      final value = profile[field];
      if (value == null) continue;
      final parsed = _integer(value);
      if (parsed == null || parsed < 0 || parsed > 1000000000) {
        _add(issues, '\$.profile.$field', '0부터 1,000,000,000 사이의 정수여야 합니다.');
      }
    }
    final selectedLanguage = profile['selectedLanguage'];
    if (selectedLanguage != null &&
        (selectedLanguage is! String ||
            !LanguageTag.values.any(
              (language) => language.code == selectedLanguage,
            ))) {
      _add(issues, r'$.profile.selectedLanguage', '지원하는 BCP 47 언어 코드여야 합니다.');
    }
    final badges = profile['badges'];
    if (badges != null &&
        (badges is! List<Object?> ||
            badges.length > 100 ||
            badges.any(
              (badge) =>
                  badge is! String ||
                  badge.trim().isEmpty ||
                  badge.runes.length > 80,
            ))) {
      _add(issues, r'$.profile.badges', '80자 이하 문자열을 최대 100개까지 저장할 수 있습니다.');
    }
    _validateDate(profile['lastStudyDate'], r'$.profile.lastStudyDate', issues);
  }

  void _validateSettings(Object? raw, List<SnapshotValidationIssue> issues) {
    if (raw == null) return;
    final settings = _map(raw, r'$.settings', issues);
    if (settings == null) return;
    try {
      StudyPreferences.fromJson(settings);
    } catch (_) {
      _add(issues, r'$.settings', '학습 설정의 필드 형식이 올바르지 않습니다.');
    }
    for (final field in const [
      'excludedItemIds',
      'favoriteItemIds',
      'completedMissionIds',
    ]) {
      final value = settings[field];
      if (value != null &&
          (value is! List<Object?> ||
              value.length > 50000 ||
              value.any(
                (item) =>
                    item is! String ||
                    item.trim().isEmpty ||
                    item.runes.length > 160,
              ))) {
        _add(issues, '\$.settings.$field', '160자 이하 ID 문자열 배열이어야 합니다.');
      }
    }
    _validateSessionPlan(settings['sessionPlan'], issues);
  }

  void _validateSessionPlan(Object? raw, List<SnapshotValidationIssue> issues) {
    if (raw == null) return;
    final plan = _map(raw, r'$.settings.sessionPlan', issues);
    if (plan == null) return;
    final mode = plan['mode'];
    if (mode != null &&
        (mode is! String ||
            !StudyMode.values.any((value) => value.name == mode))) {
      _add(issues, r'$.settings.sessionPlan.mode', '지원하지 않는 문제 방식입니다.');
    }
    final deck = plan['deck'];
    if (deck != null &&
        (deck is! String ||
            !StudyDeckScope.values.any((value) => value.name == deck))) {
      _add(issues, r'$.settings.sessionPlan.deck', '지원하지 않는 덱 범위입니다.');
    }
    final difficulty = plan['difficulty'];
    if (difficulty != null &&
        (difficulty is! String ||
            !StudyDifficulty.values.any((value) => value.name == difficulty))) {
      _add(issues, r'$.settings.sessionPlan.difficulty', '지원하지 않는 학습 단계입니다.');
    }
    final unitIndex = plan['unitIndex'];
    if (unitIndex != null) {
      final parsed = _integer(unitIndex);
      if (parsed == null || parsed < 0 || parsed > 5) {
        _add(
          issues,
          r'$.settings.sessionPlan.unitIndex',
          '0부터 5 사이의 정수여야 합니다.',
        );
      }
    }
    final itemLimit = plan['itemLimit'];
    if (itemLimit != null) {
      final parsed = _integer(itemLimit);
      if (parsed == null || parsed < 5 || parsed > 30) {
        _add(
          issues,
          r'$.settings.sessionPlan.itemLimit',
          '5부터 30 사이의 정수여야 합니다.',
        );
      }
    }
    final sentenceRatio = plan['sentenceRatio'];
    if (sentenceRatio != null &&
        (sentenceRatio is! num ||
            !sentenceRatio.isFinite ||
            sentenceRatio < 0 ||
            sentenceRatio > 1)) {
      _add(
        issues,
        r'$.settings.sessionPlan.sentenceRatio',
        '0부터 1 사이의 숫자여야 합니다.',
      );
    }
    for (final field in const ['includeWords', 'includeSentences']) {
      final value = plan[field];
      if (value != null && value is! bool) {
        _add(issues, '\$.settings.sessionPlan.$field', '참 또는 거짓이어야 합니다.');
      }
    }
    for (final field in const ['tags', 'levels']) {
      final value = plan[field];
      if (value != null &&
          (value is! List<Object?> ||
              value.length > 100 ||
              value.any(
                (item) =>
                    item is! String ||
                    item.trim().isEmpty ||
                    item.runes.length > 80,
              ))) {
        _add(
          issues,
          '\$.settings.sessionPlan.$field',
          '80자 이하 문자열을 최대 100개까지 저장할 수 있습니다.',
        );
      }
    }
    _validateDate(
      plan['updatedAt'],
      r'$.settings.sessionPlan.updatedAt',
      issues,
    );
  }

  void _validateProgress(Object? raw, List<SnapshotValidationIssue> issues) {
    if (raw == null) return;
    if (raw is! List<Object?>) {
      _add(issues, r'$.progress', '배열이어야 합니다.');
      return;
    }
    if (raw.length > 100000) {
      _add(issues, r'$.progress', '100,000개를 초과할 수 없습니다.');
      return;
    }
    final ids = <String>{};
    for (var index = 0; index < raw.length; index++) {
      final path = '\$.progress[$index]';
      final record = _map(raw[index], path, issues);
      if (record == null) continue;
      final itemId = record['itemId'];
      if (itemId is! String ||
          itemId.trim().isEmpty ||
          itemId.runes.length > 160) {
        _add(issues, '$path.itemId', '160자 이하의 ID가 필요합니다.');
      } else if (!ids.add(itemId)) {
        _add(issues, '$path.itemId', '같은 itemId가 두 번 포함되어 있습니다.');
      }
      final status = record['status'];
      if (status != null &&
          (status is! String ||
              !LearningStatus.values.any((value) => value.name == status))) {
        _add(issues, '$path.status', '지원하지 않는 학습 상태입니다.');
      }
      final lastResult = record['lastResult'];
      if (lastResult != null &&
          (lastResult is! String ||
              !ReviewRating.values.any((value) => value.name == lastResult))) {
        _add(issues, '$path.lastResult', '지원하지 않는 복습 평가입니다.');
      }
      for (final field in const [
        'correctCount',
        'wrongCount',
        'lapseCount',
        'currentIntervalDays',
      ]) {
        final value = record[field];
        if (value == null) continue;
        final parsed = _integer(value);
        if (parsed == null || parsed < 0 || parsed > 10000000) {
          _add(issues, '$path.$field', '0부터 10,000,000 사이의 정수여야 합니다.');
        }
      }
      _validateDate(record['nextReviewAt'], '$path.nextReviewAt', issues);
      _validateDate(record['lastStudiedAt'], '$path.lastStudiedAt', issues);
    }
  }

  void _validateCustomItems(Object? raw, List<SnapshotValidationIssue> issues) {
    if (raw == null) return;
    if (raw is! List<Object?>) {
      _add(issues, r'$.customItems', '배열이어야 합니다.');
      return;
    }
    if (raw.length > 20000) {
      _add(issues, r'$.customItems', '20,000개를 초과할 수 없습니다.');
      return;
    }
    final ids = <String>{};
    for (var index = 0; index < raw.length; index++) {
      final path = '\$.customItems[$index]';
      final value = _map(raw[index], path, issues);
      if (value == null) continue;
      try {
        final item = itemCodec.fromJson(value);
        if (!ids.add(item.id)) {
          _add(issues, '$path.id', '같은 콘텐츠 ID가 두 번 포함되어 있습니다.');
        }
      } catch (error) {
        _add(issues, path, error.toString());
      }
    }
  }

  void _validateCustomItemTombstones(
    Object? raw,
    List<SnapshotValidationIssue> issues,
  ) {
    if (raw == null) return;
    if (raw is! List<Object?>) {
      _add(issues, r'$.customItemTombstones', '배열이어야 합니다.');
      return;
    }
    if (raw.length > 50000) {
      _add(issues, r'$.customItemTombstones', '50,000개를 초과할 수 없습니다.');
      return;
    }
    final ids = <String>{};
    for (var index = 0; index < raw.length; index++) {
      final path = '\$.customItemTombstones[$index]';
      final tombstone = _map(raw[index], path, issues);
      if (tombstone == null) continue;
      final id = tombstone['id'];
      if (id is! String || id.trim().isEmpty || id.runes.length > 160) {
        _add(issues, '$path.id', '160자 이하의 ID가 필요합니다.');
      } else if (!ids.add(id)) {
        _add(issues, '$path.id', '같은 삭제 ID가 두 번 포함되어 있습니다.');
      }
      _date(tombstone['deletedAt'], '$path.deletedAt', issues, required: true);
    }
  }

  void _validateActiveStudy(Object? raw, List<SnapshotValidationIssue> issues) {
    if (raw == null) return;
    final active = _map(raw, r'$.activeStudy', issues);
    if (active == null) return;
    final changedAt = _date(
      active['changedAt'],
      r'$.activeStudy.changedAt',
      issues,
      required: true,
    );
    final sessionRaw = active['session'];
    if (sessionRaw == null) return;
    final sessionMap = _map(sessionRaw, r'$.activeStudy.session', issues);
    if (sessionMap == null) return;
    try {
      final session = ActiveStudySession.fromJson(sessionMap);
      if (!LanguageTag.values.any(
        (language) => language.courseId == session.courseId,
      )) {
        _add(issues, r'$.activeStudy.session.courseId', '지원하지 않는 코스입니다.');
      }
      if (session.itemIds.length > 100) {
        _add(
          issues,
          r'$.activeStudy.session.itemIds',
          '오답 재출제를 포함해 최대 100개의 항목만 포함할 수 있습니다.',
        );
      }
      if (session.initialItemIds.isEmpty ||
          session.initialItemIds.length > 100 ||
          session.initialItemIds.toSet().length !=
              session.initialItemIds.length) {
        _add(
          issues,
          r'$.activeStudy.session.initialItemIds',
          '중복 없이 1개부터 100개의 최초 문제 ID가 필요합니다.',
        );
      }
      final knownItemIds = {...session.itemIds, ...session.initialItemIds};
      if (session.wrongItemIds.length > 100 ||
          !knownItemIds.containsAll(session.wrongItemIds)) {
        _add(
          issues,
          r'$.activeStudy.session.wrongItemIds',
          '오답 ID는 현재 또는 최초 문제 묶음 안에 있어야 합니다.',
        );
      }
      if (session.journey.length > 50) {
        _add(
          issues,
          r'$.activeStudy.session.journey',
          '세션 수명주기 기록은 최대 50개까지 저장할 수 있습니다.',
        );
      }
      if (session.updatedAt.isBefore(session.startedAt)) {
        _add(issues, r'$.activeStudy.session.updatedAt', '시작 시각보다 빠를 수 없습니다.');
      }
      if (changedAt != null && changedAt.isBefore(session.updatedAt)) {
        _add(issues, r'$.activeStudy.changedAt', '세션의 마지막 변경 시각보다 빠를 수 없습니다.');
      }
    } catch (error) {
      _add(issues, r'$.activeStudy.session', error.toString());
    }
  }

  Map<String, Object?>? _map(
    Object? raw,
    String path,
    List<SnapshotValidationIssue> issues,
  ) {
    if (raw is! Map) {
      _add(issues, path, '객체여야 합니다.');
      return null;
    }
    try {
      return Map<String, Object?>.from(raw);
    } catch (_) {
      _add(issues, path, '문자열 필드 이름을 가진 객체여야 합니다.');
      return null;
    }
  }

  void _validateDate(
    Object? raw,
    String path,
    List<SnapshotValidationIssue> issues,
  ) {
    _date(raw, path, issues);
  }

  DateTime? _date(
    Object? raw,
    String path,
    List<SnapshotValidationIssue> issues, {
    bool required = false,
  }) {
    if (raw == null) {
      if (required) _add(issues, path, '날짜 값이 필요합니다.');
      return null;
    }
    if (raw is! String || DateTime.tryParse(raw) == null) {
      _add(issues, path, 'ISO 8601 날짜 문자열이어야 합니다.');
      return null;
    }
    return DateTime.parse(raw).toUtc();
  }

  int? _integer(Object? raw) {
    if (raw is! num || raw.isNaN || raw.isInfinite || raw != raw.round()) {
      return null;
    }
    return raw.toInt();
  }

  void _add(List<SnapshotValidationIssue> issues, String path, String message) {
    issues.add(SnapshotValidationIssue(path: path, message: message));
  }
}
