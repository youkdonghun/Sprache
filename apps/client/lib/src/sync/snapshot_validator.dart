import '../domain/active_study_session.dart';
import '../domain/app_experience_preferences.dart';
import '../domain/dataset_capacity.dart';
import '../domain/import_distribution.dart';
import '../domain/language.dart';
import '../domain/learning_group.dart';
import '../domain/learning_item_codec.dart';
import '../domain/progress.dart';
import '../domain/session_enhancements.dart';
import '../domain/study_history.dart';
import '../domain/study_interaction_preferences.dart';
import '../domain/study_limits.dart';
import '../domain/study_preferences.dart';
import '../domain/study_subject.dart';

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
    _validateRecentSessions(snapshot['recentSessions'], issues);
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
    final xpByReplica = profile['xpByReplica'];
    if (xpByReplica != null) {
      if (xpByReplica is! Map || xpByReplica.length > 500) {
        _add(issues, r'$.profile.xpByReplica', '기기별 XP는 최대 500개 기기의 객체여야 합니다.');
      } else {
        for (final entry in xpByReplica.entries) {
          final key = entry.key;
          final value = _integer(entry.value);
          if (key is! String ||
              !_isValidReplicaId(key) ||
              value == null ||
              value < 0 ||
              value > 1000000000) {
            _add(
              issues,
              r'$.profile.xpByReplica',
              '기기 ID와 XP 값의 형식이 올바르지 않습니다.',
            );
            break;
          }
        }
      }
    }
    final dailyXpByCourse = profile['dailyXpByCourse'];
    if (dailyXpByCourse != null) {
      if (dailyXpByCourse is! Map || dailyXpByCourse.length > 200) {
        _add(
          issues,
          r'$.profile.dailyXpByCourse',
          '코스별 오늘 XP는 최대 200개 코스의 객체여야 합니다.',
        );
      } else {
        for (final entry in dailyXpByCourse.entries) {
          final key = entry.key;
          final value = _integer(entry.value);
          if (key is! String ||
              key.trim().isEmpty ||
              key.runes.length > 160 ||
              value == null ||
              value < 0 ||
              value > 1000000000) {
            _add(
              issues,
              r'$.profile.dailyXpByCourse',
              '각 코스 ID는 160자 이하이고 XP는 0부터 1,000,000,000 사이의 정수여야 합니다.',
            );
            break;
          }
        }
      }
    }
    final dailyXpByCourseAndReplica = profile['dailyXpByCourseAndReplica'];
    if (dailyXpByCourseAndReplica != null) {
      if (dailyXpByCourseAndReplica is! Map ||
          dailyXpByCourseAndReplica.length > 200) {
        _add(
          issues,
          r'$.profile.dailyXpByCourseAndReplica',
          '기기별 오늘 XP는 최대 200개 코스의 객체여야 합니다.',
        );
      } else {
        for (final courseEntry in dailyXpByCourseAndReplica.entries) {
          final courseId = courseEntry.key;
          final replicaValues = courseEntry.value;
          if (courseId is! String ||
              courseId.trim().isEmpty ||
              courseId.runes.length > 160 ||
              replicaValues is! Map ||
              replicaValues.length > 500) {
            _add(
              issues,
              r'$.profile.dailyXpByCourseAndReplica',
              '코스별 기기 XP 객체의 형식이 올바르지 않습니다.',
            );
            break;
          }
          final invalidReplica = replicaValues.entries.any((entry) {
            final value = _integer(entry.value);
            return entry.key is! String ||
                !_isValidReplicaId(entry.key! as String) ||
                value == null ||
                value < 0 ||
                value > 1000000000;
          });
          if (invalidReplica) {
            _add(
              issues,
              r'$.profile.dailyXpByCourseAndReplica',
              '기기 ID와 오늘 XP 값의 형식이 올바르지 않습니다.',
            );
            break;
          }
        }
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
    _validateAdvancedSettings(settings, issues);
    final onboardingCompleted = settings['onboardingCompleted'];
    if (onboardingCompleted != null && onboardingCompleted is! bool) {
      _add(
        issues,
        r'$.settings.onboardingCompleted',
        '온보딩 완료 여부는 true 또는 false여야 합니다.',
      );
    }
    final dailyGoalsBySubject = settings['dailyGoalsBySubject'];
    if (dailyGoalsBySubject != null) {
      if (dailyGoalsBySubject is! Map || dailyGoalsBySubject.length > 100) {
        _add(
          issues,
          r'$.settings.dailyGoalsBySubject',
          '주제별 하루 목표는 최대 100개 주제의 객체여야 합니다.',
        );
      } else {
        for (final entry in dailyGoalsBySubject.entries) {
          final value = _integer(entry.value);
          try {
            if (entry.key is! String) {
              throw const FormatException();
            }
            normalizeStudySubjectId(entry.key! as String);
            if (value == null || value < 20 || value > 500) {
              throw const FormatException();
            }
          } on FormatException {
            _add(
              issues,
              r'$.settings.dailyGoalsBySubject',
              '주제 ID별 목표는 20부터 500 사이의 정수여야 합니다.',
            );
            break;
          }
        }
      }
    }
    final dailyGoalChangedAtBySubject = settings['dailyGoalChangedAtBySubject'];
    if (dailyGoalChangedAtBySubject != null) {
      if (dailyGoalChangedAtBySubject is! Map ||
          dailyGoalChangedAtBySubject.length > 100) {
        _add(
          issues,
          r'$.settings.dailyGoalChangedAtBySubject',
          '주제별 목표 변경 시각은 최대 100개 주제의 객체여야 합니다.',
        );
      } else {
        for (final entry in dailyGoalChangedAtBySubject.entries) {
          try {
            if (entry.key is! String) throw const FormatException();
            normalizeStudySubjectId(entry.key! as String);
            if (entry.value is! String ||
                DateTime.tryParse(entry.value! as String) == null) {
              throw const FormatException();
            }
          } on FormatException {
            _add(
              issues,
              r'$.settings.dailyGoalChangedAtBySubject',
              '주제 ID별 변경 시각은 ISO 8601 날짜 문자열이어야 합니다.',
            );
            break;
          }
        }
      }
    }
    final subjectIds = <String>{};
    final rawSubjects = settings['customSubjects'];
    if (rawSubjects != null) {
      if (rawSubjects is! List<Object?> || rawSubjects.length > 100) {
        _add(
          issues,
          r'$.settings.customSubjects',
          '사용자 학습 주제는 최대 100개까지 저장할 수 있습니다.',
        );
      } else {
        for (var index = 0; index < rawSubjects.length; index++) {
          final path = '\$.settings.customSubjects[$index]';
          final subjectMap = _map(rawSubjects[index], path, issues);
          if (subjectMap == null) continue;
          try {
            final subject = StudySubject.fromJson(subjectMap);
            final builtInOverride =
                subject.kind == StudySubjectKind.language &&
                builtInLanguageSubjects.any(
                  (builtIn) => builtIn.id == subject.id,
                );
            if (subject.kind != StudySubjectKind.general && !builtInOverride) {
              _add(issues, '$path.kind', '사용자 주제 또는 지원 언어의 표시 설정이어야 합니다.');
            } else if (!subjectIds.add(subject.id)) {
              _add(issues, '$path.id', '같은 학습 주제 ID가 두 번 포함되어 있습니다.');
            }
          } on FormatException catch (error) {
            _add(issues, path, error.message);
          }
        }
      }
    }
    final validSubjectIds = {
      ...builtInLanguageSubjects.map((subject) => subject.id),
      ...subjectIds,
    };
    final hiddenSubjectIds = settings['hiddenSubjectIds'];
    if (hiddenSubjectIds != null) {
      if (hiddenSubjectIds is! List<Object?> ||
          hiddenSubjectIds.length > 100 ||
          hiddenSubjectIds.any(
            (value) => value is! String || !validSubjectIds.contains(value),
          )) {
        _add(
          issues,
          r'$.settings.hiddenSubjectIds',
          '숨긴 주제는 저장된 주제 ID의 배열이어야 합니다.',
        );
      }
    }
    final visibilityChanges = settings['subjectVisibilityChangedAtById'];
    if (visibilityChanges != null) {
      if (visibilityChanges is! Map || visibilityChanges.length > 100) {
        _add(
          issues,
          r'$.settings.subjectVisibilityChangedAtById',
          '주제 표시 변경 시각은 최대 100개의 객체여야 합니다.',
        );
      } else {
        for (final entry in visibilityChanges.entries) {
          if (entry.key is! String ||
              !validSubjectIds.contains(entry.key) ||
              entry.value is! String ||
              DateTime.tryParse(entry.value! as String) == null) {
            _add(
              issues,
              r'$.settings.subjectVisibilityChangedAtById',
              '주제 ID별 변경 시각은 ISO 8601 날짜 문자열이어야 합니다.',
            );
            break;
          }
        }
      }
    }
    final rawDistributionRules = settings['importDistributionRules'];
    if (rawDistributionRules != null) {
      if (rawDistributionRules is! List<Object?> ||
          rawDistributionRules.length > 200) {
        _add(
          issues,
          r'$.settings.importDistributionRules',
          '업로드 분배 규칙은 최대 200개 배열이어야 합니다.',
        );
      } else {
        final keys = <String>{};
        for (final (index, rawRule) in rawDistributionRules.indexed) {
          final path = '\$.settings.importDistributionRules[$index]';
          final ruleMap = _map(rawRule, path, issues);
          if (ruleMap == null) continue;
          try {
            final rule = ImportDistributionRule.fromJson(ruleMap);
            if (!validSubjectIds.contains(rule.subjectId)) {
              _add(issues, '$path.subjectId', '저장된 학습 주제를 가리켜야 합니다.');
            } else if (!keys.add(rule.key)) {
              _add(issues, '$path.key', '같은 분배 키가 두 번 포함되어 있습니다.');
            }
          } on FormatException catch (error) {
            _add(issues, path, error.message);
          }
        }
      }
    }
    final learningGroupIds = <String>{};
    final rawLearningGroups = settings['learningGroups'];
    if (rawLearningGroups != null) {
      if (rawLearningGroups is! List<Object?> ||
          rawLearningGroups.length > 500) {
        _add(
          issues,
          r'$.settings.learningGroups',
          '학습 그룹은 최대 500개의 배열이어야 합니다.',
        );
      } else {
        for (final (index, rawGroup) in rawLearningGroups.indexed) {
          final path = '\$.settings.learningGroups[$index]';
          final groupMap = _map(rawGroup, path, issues);
          if (groupMap == null) continue;
          try {
            final group = LearningGroupDefinition.fromJson(groupMap);
            final validSubject = validSubjectIds.contains(group.subjectId);
            if (!validSubject) {
              _add(issues, '$path.subjectId', '저장된 학습 주제의 그룹이어야 합니다.');
            } else if (!learningGroupIds.add(group.id)) {
              _add(issues, path, '같은 학습 그룹이 두 번 포함되어 있습니다.');
            }
          } on FormatException catch (error) {
            _add(issues, path, error.message);
          }
        }
      }
    }
    final learningGroupTombstones = settings['learningGroupTombstones'];
    if (learningGroupTombstones != null) {
      if (learningGroupTombstones is! Map ||
          learningGroupTombstones.length > 500) {
        _add(
          issues,
          r'$.settings.learningGroupTombstones',
          '삭제한 학습 그룹은 최대 500개의 변경 시각 객체여야 합니다.',
        );
      } else {
        for (final entry in learningGroupTombstones.entries) {
          if (entry.key is! String ||
              (entry.key! as String).trim().isEmpty ||
              (entry.key! as String).runes.length > 240 ||
              entry.value is! String ||
              DateTime.tryParse(entry.value! as String) == null) {
            _add(
              issues,
              r'$.settings.learningGroupTombstones',
              '그룹 ID별 삭제 시각은 ISO 8601 날짜 문자열이어야 합니다.',
            );
            break;
          }
        }
      }
    }
    final rawActiveSubjectId = settings['activeSubjectId'];
    if (rawActiveSubjectId != null) {
      if (rawActiveSubjectId is! String) {
        _add(issues, r'$.settings.activeSubjectId', '학습 주제 ID는 문자열이어야 합니다.');
      } else if (rawActiveSubjectId.isNotEmpty) {
        try {
          final activeSubjectId = normalizeStudySubjectId(rawActiveSubjectId);
          final builtIn = builtInLanguageSubjects.any(
            (subject) => subject.id == activeSubjectId,
          );
          if (!builtIn && !subjectIds.contains(activeSubjectId)) {
            _add(
              issues,
              r'$.settings.activeSubjectId',
              '현재 학습 주제는 저장된 언어 또는 사용자 주제여야 합니다.',
            );
          }
        } on FormatException catch (error) {
          _add(issues, r'$.settings.activeSubjectId', error.message);
        }
      }
    }
    final activeSubjectChangedAt = settings['activeSubjectChangedAt'];
    if (activeSubjectChangedAt != null) {
      _date(
        activeSubjectChangedAt,
        r'$.settings.activeSubjectChangedAt',
        issues,
      );
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
    for (final field in const [
      'excludedItemChangedAtById',
      'favoriteItemChangedAtById',
    ]) {
      final value = settings[field];
      if (value == null) continue;
      if (value is! Map || value.length > 50000) {
        _add(issues, '\$.settings.$field', '항목별 변경 시각 객체여야 합니다.');
        continue;
      }
      for (final entry in value.entries) {
        if (entry.key is! String ||
            (entry.key! as String).trim().isEmpty ||
            (entry.key! as String).runes.length > 160 ||
            entry.value is! String ||
            DateTime.tryParse(entry.value! as String) == null) {
          _add(
            issues,
            '\$.settings.$field',
            '항목 ID별 변경 시각은 ISO 8601 날짜 문자열이어야 합니다.',
          );
          break;
        }
      }
    }
    final contentItemAliases = settings['contentItemAliases'];
    if (contentItemAliases != null) {
      if (contentItemAliases is! Map || contentItemAliases.length > 50000) {
        _add(
          issues,
          r'$.settings.contentItemAliases',
          '병합한 자료 ID 연결은 최대 50,000개의 객체여야 합니다.',
        );
      } else {
        for (final entry in contentItemAliases.entries) {
          if (entry.key is! String ||
              entry.value is! String ||
              (entry.key! as String).trim().isEmpty ||
              (entry.value! as String).trim().isEmpty ||
              (entry.key! as String).runes.length > 160 ||
              (entry.value! as String).runes.length > 160 ||
              entry.key == entry.value) {
            _add(
              issues,
              r'$.settings.contentItemAliases',
              '병합 전후 자료 ID는 서로 다른 160자 이하 문자열이어야 합니다.',
            );
            break;
          }
        }
      }
    }
    final savedSessionPlanTombstones = settings['savedSessionPlanTombstones'];
    if (savedSessionPlanTombstones != null) {
      if (savedSessionPlanTombstones is! Map ||
          savedSessionPlanTombstones.length > 100) {
        _add(
          issues,
          r'$.settings.savedSessionPlanTombstones',
          '삭제한 학습 일정은 최대 100개의 변경 시각 객체여야 합니다.',
        );
      } else {
        for (final entry in savedSessionPlanTombstones.entries) {
          if (entry.key is! String ||
              (entry.key! as String).trim().isEmpty ||
              (entry.key! as String).runes.length > 80 ||
              entry.value is! String ||
              DateTime.tryParse(entry.value! as String) == null) {
            _add(
              issues,
              r'$.settings.savedSessionPlanTombstones',
              '일정 ID별 삭제 시각은 ISO 8601 날짜 문자열이어야 합니다.',
            );
            break;
          }
        }
      }
    }
    _validateSessionPlan(
      settings['sessionPlan'],
      issues,
      path: r'$.settings.sessionPlan',
      validSubjectIds: {
        ...builtInLanguageSubjects.map((subject) => subject.id),
        ...subjectIds,
      },
    );
    final savedPlans = settings['savedSessionPlans'];
    if (savedPlans != null) {
      if (savedPlans is! List<Object?>) {
        _add(issues, r'$.settings.savedSessionPlans', '배열이어야 합니다.');
      } else if (savedPlans.length > 20) {
        _add(
          issues,
          r'$.settings.savedSessionPlans',
          '저장한 학습 일정은 최대 20개까지 허용됩니다.',
        );
      } else {
        final ids = <String>{};
        for (final (index, rawPlan) in savedPlans.indexed) {
          final path = '\$.settings.savedSessionPlans[$index]';
          if (rawPlan is! Map) {
            _add(issues, path, '객체여야 합니다.');
            continue;
          }
          final plan = Map<String, Object?>.from(rawPlan);
          final planId = plan['planId'];
          if (planId is! String ||
              planId.trim().isEmpty ||
              planId.runes.length > 80) {
            _add(issues, '$path.planId', '80자 이하의 일정 ID가 필요합니다.');
          } else if (!ids.add(planId)) {
            _add(issues, '$path.planId', '같은 일정 ID가 두 번 포함되어 있습니다.');
          }
          _validateSessionPlan(
            rawPlan,
            issues,
            path: path,
            validSubjectIds: {
              ...builtInLanguageSubjects.map((subject) => subject.id),
              ...subjectIds,
            },
          );
        }
      }
    }
  }

  void _validateAdvancedSettings(
    Map<String, Object?> settings,
    List<SnapshotValidationIssue> issues,
  ) {
    if (settings.containsKey('showReadingAids') &&
        settings['showReadingAids'] is! bool) {
      _add(
        issues,
        r'$.settings.showReadingAids',
        '읽기 도움 표시 여부는 true 또는 false여야 합니다.',
      );
    }
    if (settings.containsKey('ttsRate')) {
      final value = settings['ttsRate'];
      if (value is! num || !value.isFinite || value < 0.2 || value > 0.8) {
        _add(issues, r'$.settings.ttsRate', '음성 속도는 0.2부터 0.8 사이의 숫자여야 합니다.');
      }
    }
    if (settings.containsKey('settingsUpdatedAt')) {
      _date(
        settings['settingsUpdatedAt'],
        r'$.settings.settingsUpdatedAt',
        issues,
        required: true,
      );
    }
    if (settings.containsKey('experience')) {
      _validateExperiencePreferences(settings['experience'], issues);
    }
    if (settings.containsKey('interaction')) {
      _validateInteractionPreferences(settings['interaction'], issues);
    }
  }

  void _validateExperiencePreferences(
    Object? raw,
    List<SnapshotValidationIssue> issues,
  ) {
    const path = r'$.settings.experience';
    final preferences = _map(raw, path, issues);
    if (preferences == null) return;
    _validateEnumField(
      preferences,
      'colorMode',
      AppColorMode.values,
      path,
      issues,
    );
    _validateEnumField(
      preferences,
      'accentPalette',
      AppAccentPalette.values,
      path,
      issues,
    );
    _validateEnumField(preferences, 'density', AppDensity.values, path, issues);
    _validateEnumField(
      preferences,
      'textScale',
      AppTextScale.values,
      path,
      issues,
    );
    for (final field in const [
      'reduceMotion',
      'hapticsEnabled',
      'soundEffectsEnabled',
    ]) {
      _validateBooleanField(preferences, field, path, issues);
    }
    if (preferences.containsKey('updatedAt')) {
      _date(
        preferences['updatedAt'],
        '$path.updatedAt',
        issues,
        required: true,
      );
    }
  }

  void _validateInteractionPreferences(
    Object? raw,
    List<SnapshotValidationIssue> issues,
  ) {
    const path = r'$.settings.interaction';
    final preferences = _map(raw, path, issues);
    if (preferences == null) return;
    for (final field in const [
      'autoPlayQuestionAudio',
      'autoPlayAnswerAudio',
      'preferOfflineVoice',
      'showKoreanReading',
      'showNativeReading',
      'shuffleChoices',
      'autoAdvanceCorrect',
    ]) {
      _validateBooleanField(preferences, field, path, issues);
    }
    final repeatCount = _integer(preferences['audioRepeatCount']);
    if (repeatCount == null || repeatCount < 1 || repeatCount > 3) {
      _add(issues, '$path.audioRepeatCount', '음성 반복 횟수는 1부터 3 사이의 정수여야 합니다.');
    }
    _validateEnumField(
      preferences,
      'answerDirection',
      StudyAnswerDirection.values,
      path,
      issues,
    );
    _validateEnumField(
      preferences,
      'choiceLayout',
      StudyChoiceLayout.values,
      path,
      issues,
    );
    final delay = _integer(preferences['autoAdvanceDelayMs']);
    if (delay == null || delay < 300 || delay > 3000) {
      _add(
        issues,
        '$path.autoAdvanceDelayMs',
        '자동 넘김 대기 시간은 300부터 3000 사이의 정수여야 합니다.',
      );
    }
    if (preferences.containsKey('updatedAt')) {
      _date(
        preferences['updatedAt'],
        '$path.updatedAt',
        issues,
        required: true,
      );
    }
  }

  void _validateBooleanField(
    Map<String, Object?> values,
    String field,
    String path,
    List<SnapshotValidationIssue> issues,
  ) {
    if (values[field] is! bool) {
      _add(issues, '$path.$field', 'true 또는 false여야 합니다.');
    }
  }

  void _validateEnumField<T extends Enum>(
    Map<String, Object?> values,
    String field,
    Iterable<T> supported,
    String path,
    List<SnapshotValidationIssue> issues,
  ) {
    final value = values[field];
    if (value is! String ||
        !supported.any((candidate) => candidate.name == value)) {
      _add(issues, '$path.$field', '지원하는 설정 값이어야 합니다.');
    }
  }

  void _validateSessionPlan(
    Object? raw,
    List<SnapshotValidationIssue> issues, {
    required String path,
    required Set<String> validSubjectIds,
  }) {
    if (raw == null) return;
    final plan = _map(raw, path, issues);
    if (plan == null) return;
    final subjectId = plan['subjectId'];
    if (subjectId != null && subjectId != '') {
      if (subjectId is! String) {
        _add(issues, '$path.subjectId', '학습 주제 ID는 문자열이어야 합니다.');
      } else {
        try {
          final normalized = normalizeStudySubjectId(subjectId);
          if (!validSubjectIds.contains(normalized)) {
            _add(
              issues,
              '$path.subjectId',
              '일정의 학습 주제는 저장된 언어 또는 사용자 주제여야 합니다.',
            );
          }
        } on FormatException catch (error) {
          _add(issues, '$path.subjectId', error.message);
        }
      }
    }
    final mode = plan['mode'];
    if (mode != null &&
        (mode is! String ||
            !StudyMode.values.any((value) => value.name == mode))) {
      _add(issues, '$path.mode', '지원하지 않는 문제 방식입니다.');
    }
    final deck = plan['deck'];
    if (deck != null &&
        (deck is! String ||
            !StudyDeckScope.values.any((value) => value.name == deck))) {
      _add(issues, '$path.deck', '지원하지 않는 덱 범위입니다.');
    }
    final difficulty = plan['difficulty'];
    if (difficulty != null &&
        (difficulty is! String ||
            !StudyDifficulty.values.any((value) => value.name == difficulty))) {
      _add(issues, '$path.difficulty', '지원하지 않는 학습 단계입니다.');
    }
    final queuePriority = plan['queuePriority'];
    if (queuePriority != null &&
        (queuePriority is! String ||
            !StudyQueuePriority.values.any(
              (value) => value.name == queuePriority,
            ))) {
      _add(issues, '$path.queuePriority', '지원하지 않는 출제 순서입니다.');
    }
    final historyFilter = plan['historyFilter'];
    if (historyFilter != null &&
        (historyFilter is! String ||
            !StudyHistoryFilter.values.any(
              (value) => value.name == historyFilter,
            ))) {
      _add(issues, '$path.historyFilter', '지원하지 않는 학습 기록 조건입니다.');
    }
    final unitIndex = plan['unitIndex'];
    if (unitIndex != null) {
      final parsed = _integer(unitIndex);
      if (parsed == null || parsed < 0 || parsed > 5) {
        _add(issues, '$path.unitIndex', '0부터 5 사이의 정수여야 합니다.');
      }
    }
    final itemLimit = plan['itemLimit'];
    if (itemLimit != null) {
      final parsed = _integer(itemLimit);
      if (parsed == null ||
          parsed < StudyLimits.minSessionItems ||
          parsed > StudyLimits.maxSessionItems) {
        _add(
          issues,
          '$path.itemLimit',
          '${StudyLimits.minSessionItems}부터 '
              '${StudyLimits.maxSessionItems} 사이의 정수여야 합니다.',
        );
      }
    }
    final sentenceRatio = plan['sentenceRatio'];
    if (sentenceRatio != null &&
        (sentenceRatio is! num ||
            !sentenceRatio.isFinite ||
            sentenceRatio < 0 ||
            sentenceRatio > 1)) {
      _add(issues, '$path.sentenceRatio', '0부터 1 사이의 숫자여야 합니다.');
    }
    for (final field in const [
      'includeWords',
      'includeSentences',
      'recordProgress',
    ]) {
      final value = plan[field];
      if (value != null && value is! bool) {
        _add(issues, '$path.$field', '참 또는 거짓이어야 합니다.');
      }
    }
    for (final field in const [
      'groupIds',
      'tags',
      'levels',
      'selectedItemIds',
    ]) {
      final value = plan[field];
      final maxLength = field == 'selectedItemIds' ? 500 : 100;
      final maxRunes = field == 'selectedItemIds' || field == 'groupIds'
          ? 160
          : 80;
      if (value != null &&
          (value is! List<Object?> ||
              value.length > maxLength ||
              value.any(
                (item) =>
                    item is! String ||
                    item.trim().isEmpty ||
                    item.runes.length > maxRunes,
              ))) {
        _add(
          issues,
          '$path.$field',
          '$maxRunes자 이하 문자열을 최대 $maxLength개까지 저장할 수 있습니다.',
        );
      }
    }
    final lengthMode = plan['lengthMode'];
    if (lengthMode != null &&
        (lengthMode is! String ||
            !StudySessionLengthMode.values.any(
              (value) => value.name == lengthMode,
            ))) {
      _add(issues, '$path.lengthMode', '지원하지 않는 세션 길이 방식입니다.');
    }
    final timeBudgetMinutes = plan['timeBudgetMinutes'];
    if (timeBudgetMinutes != null) {
      final parsed = _integer(timeBudgetMinutes);
      if (parsed == null || parsed < 3 || parsed > 15) {
        _add(issues, '$path.timeBudgetMinutes', '3부터 15 사이의 정수여야 합니다.');
      }
    }
    final answerDirection = plan['answerDirectionOverride'];
    if (answerDirection != null &&
        (answerDirection is! String ||
            !StudyAnswerDirection.values.any(
              (value) => value.name == answerDirection,
            ))) {
      _add(issues, '$path.answerDirectionOverride', '지원하지 않는 출제 방향입니다.');
    }
    final gradingStrictness = plan['gradingStrictness'];
    if (gradingStrictness != null &&
        (gradingStrictness is! String ||
            !StudyGradingStrictness.values.any(
              (value) => value.name == gradingStrictness,
            ))) {
      _add(issues, '$path.gradingStrictness', '지원하지 않는 채점 강도입니다.');
    }
    final examSchedule = plan['examSchedule'];
    if (examSchedule != null) {
      final schedule = _map(examSchedule, '$path.examSchedule', issues);
      if (schedule != null) {
        _date(
          schedule['targetDate'],
          '$path.examSchedule.targetDate',
          issues,
          required: true,
        );
        for (final field in const [
          'startDate',
          'lastCompletedAt',
          'snoozedUntil',
          'updatedAt',
        ]) {
          _validateDate(schedule[field], '$path.examSchedule.$field', issues);
        }
        final dailyCap = _integer(schedule['dailyCap']);
        if (dailyCap == null || dailyCap < 1 || dailyCap > 100) {
          _add(issues, '$path.examSchedule.dailyCap', '1부터 100 사이의 정수여야 합니다.');
        }
        final minute = _integer(schedule['preferredMinuteOfDay']);
        if (minute == null || minute < 0 || minute > 1439) {
          _add(
            issues,
            '$path.examSchedule.preferredMinuteOfDay',
            '0부터 1439 사이의 정수여야 합니다.',
          );
        }
      }
    }
    final backlogRecovery = plan['backlogRecovery'];
    if (backlogRecovery != null) {
      final recovery = _map(backlogRecovery, '$path.backlogRecovery', issues);
      if (recovery != null) {
        final enabled = recovery['enabled'];
        if (enabled is! bool) {
          _add(issues, '$path.backlogRecovery.enabled', '참 또는 거짓이어야 합니다.');
        }
        final dailyLimit = _integer(recovery['dailyLimit']);
        if (dailyLimit == null ||
            dailyLimit < 1 ||
            dailyLimit > StudyLimits.maxSessionItems) {
          _add(
            issues,
            '$path.backlogRecovery.dailyLimit',
            '1부터 ${StudyLimits.maxSessionItems} 사이의 정수여야 합니다.',
          );
        }
      }
    }
    final title = plan['title'];
    if (title != null && (title is! String || title.runes.length > 60)) {
      _add(issues, '$path.title', '60자 이하 문자열이어야 합니다.');
    }
    final planId = plan['planId'];
    if (planId != null && (planId is! String || planId.runes.length > 80)) {
      _add(issues, '$path.planId', '80자 이하 문자열이어야 합니다.');
    }
    _validateDate(plan['scheduledAt'], '$path.scheduledAt', issues);
    _validateDate(plan['updatedAt'], '$path.updatedAt', issues);
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
    if (raw.length > DatasetCapacityPolicy.maxCustomItems) {
      _add(
        issues,
        r'$.customItems',
        '${DatasetCapacityPolicy.maxCustomItems}개를 초과할 수 없습니다.',
      );
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

  void _validateRecentSessions(
    Object? raw,
    List<SnapshotValidationIssue> issues,
  ) {
    if (raw == null) return;
    if (raw is! List<Object?>) {
      _add(issues, r'$.recentSessions', '배열이어야 합니다.');
      return;
    }
    if (raw.length > 20) {
      _add(issues, r'$.recentSessions', '최근 학습 기록은 최대 20개까지 저장할 수 있습니다.');
      return;
    }
    final ids = <String>{};
    for (var index = 0; index < raw.length; index++) {
      final path = '\$.recentSessions[$index]';
      final sessionMap = _map(raw[index], path, issues);
      if (sessionMap == null) continue;
      try {
        final session = StudySessionSummary.fromJson(sessionMap);
        if (!ids.add(session.sessionId)) {
          _add(issues, '$path.sessionId', '같은 학습 기록 ID가 두 번 포함되어 있습니다.');
        }
        if (!isSupportedCourseId(session.courseId)) {
          _add(issues, '$path.courseId', '지원하지 않는 코스입니다.');
        }
        if (session.endedAt.isBefore(session.startedAt)) {
          _add(issues, '$path.endedAt', '종료 시각은 시작 시각보다 빠를 수 없습니다.');
        }
      } catch (error) {
        _add(issues, path, error.toString());
      }
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
    Set<String>? rawIds(Object? value) {
      if (value is! List || value.any((item) => item is! String)) {
        return null;
      }
      return value.cast<String>().toSet();
    }

    final rawItemIds = rawIds(sessionMap['itemIds']);
    final rawInitialItemIds =
        rawIds(sessionMap['initialItemIds']) ?? rawItemIds;
    if (rawItemIds != null && rawInitialItemIds != null) {
      final knownItemIds = {...rawItemIds, ...rawInitialItemIds};
      final rawWrongItemIds = rawIds(sessionMap['wrongItemIds']);
      if (rawWrongItemIds != null &&
          !knownItemIds.containsAll(rawWrongItemIds)) {
        _add(
          issues,
          r'$.activeStudy.session.wrongItemIds',
          '오답 ID는 현재 또는 최초 문제 묶음 안에 있어야 합니다.',
        );
      }
      final rawFinalCorrectItemIds = rawIds(sessionMap['finalCorrectItemIds']);
      if (rawFinalCorrectItemIds != null &&
          !knownItemIds.containsAll(rawFinalCorrectItemIds)) {
        _add(
          issues,
          r'$.activeStudy.session.finalCorrectItemIds',
          '최종 정답 ID는 현재 또는 최초 문제 묶음 안에 있어야 합니다.',
        );
      }
    }
    try {
      final session = ActiveStudySession.fromJson(sessionMap);
      if (!isSupportedCourseId(session.courseId)) {
        _add(issues, r'$.activeStudy.session.courseId', '지원하지 않는 코스입니다.');
      }
      if (session.itemIds.length > StudyLimits.maxActiveQueueEntries) {
        _add(
          issues,
          r'$.activeStudy.session.itemIds',
          '오답 재출제를 포함해 최대 '
              '${StudyLimits.maxActiveQueueEntries}개의 항목만 포함할 수 있습니다.',
        );
      }
      if (session.initialItemIds.isEmpty ||
          session.initialItemIds.length > StudyLimits.maxSessionItems ||
          session.initialItemIds.toSet().length !=
              session.initialItemIds.length) {
        _add(
          issues,
          r'$.activeStudy.session.initialItemIds',
          '중복 없이 1개부터 ${StudyLimits.maxSessionItems}개의 최초 문제 ID가 필요합니다.',
        );
      }
      final knownItemIds = {...session.itemIds, ...session.initialItemIds};
      if (session.wrongItemIds.length > StudyLimits.maxSessionItems ||
          !knownItemIds.containsAll(session.wrongItemIds)) {
        _add(
          issues,
          r'$.activeStudy.session.wrongItemIds',
          '오답 ID는 현재 또는 최초 문제 묶음 안에 있어야 합니다.',
        );
      }
      if (session.finalCorrectItemIds.length > StudyLimits.maxSessionItems ||
          !knownItemIds.containsAll(session.finalCorrectItemIds)) {
        _add(
          issues,
          r'$.activeStudy.session.finalCorrectItemIds',
          '최종 정답 ID는 현재 또는 최초 문제 묶음 안에 있어야 합니다.',
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

  bool _isValidReplicaId(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.length > 80 || trimmed != value) {
      return false;
    }
    return trimmed.codeUnits.every(
      (code) =>
          (code >= 48 && code <= 57) ||
          (code >= 65 && code <= 90) ||
          (code >= 97 && code <= 122) ||
          code == 45 ||
          code == 95,
    );
  }

  void _add(List<SnapshotValidationIssue> issues, String path, String message) {
    issues.add(SnapshotValidationIssue(path: path, message: message));
  }
}
