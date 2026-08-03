import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/active_study_session.dart';
import 'package:sprache/src/domain/adaptive_study_session.dart';
import 'package:sprache/src/domain/app_experience_preferences.dart';
import 'package:sprache/src/domain/import_distribution.dart';
import 'package:sprache/src/domain/progress.dart';
import 'package:sprache/src/domain/quiz_session_support.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/sync/snapshot_validator.dart';

void main() {
  const validator = SyncSnapshotValidator();

  test('accepts a minimal backward-compatible snapshot', () {
    expect(() => validator.validate({'schemaVersion': 1}), returnsNormally);
  });

  test('pronunciation metrics reject sensitive fields and outside times', () {
    final startedAt = DateTime.utc(2026, 8, 3, 10);
    final endedAt = DateTime.utc(2026, 8, 3, 10, 5);
    final session = StudySessionSummary(
      sessionId: 'privacy-pronunciation',
      courseId: 'ko-en',
      startedAt: startedAt,
      endedAt: endedAt,
      correctCount: 1,
      wrongCount: 0,
      earnedXp: 10,
      pronunciationMetrics: [
        PronunciationAttemptMetric(
          score: 82,
          recordedAt: startedAt.add(const Duration(minutes: 2)),
          method: PronunciationEvaluationMethod.speechRecognition,
        ),
      ],
    );
    final valid = session.toJson();
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'recentSessions': [valid],
      }),
      returnsNormally,
    );

    final sensitive = Map<String, Object?>.from(valid);
    sensitive['pronunciationMetrics'] = [
      {
        ...(valid['pronunciationMetrics']! as List).single as Map,
        'transcript': 'private speech',
      },
    ];
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'recentSessions': [sensitive],
      }),
      throwsA(isA<RemoteSnapshotValidationException>()),
    );

    final outside = Map<String, Object?>.from(valid);
    outside['pronunciationMetrics'] = [
      {
        ...(valid['pronunciationMetrics']! as List).single as Map,
        'recordedAt': endedAt.add(const Duration(minutes: 1)).toIso8601String(),
      },
    ];
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'recentSessions': [outside],
      }),
      throwsA(isA<RemoteSnapshotValidationException>()),
    );
  });

  test('adaptive response metrics reject answer content and outside times', () {
    final startedAt = DateTime.utc(2026, 8, 3, 10);
    final endedAt = DateTime.utc(2026, 8, 3, 10, 5);
    final session = StudySessionSummary(
      sessionId: 'privacy-adaptive',
      courseId: 'ko-en',
      startedAt: startedAt,
      endedAt: endedAt,
      correctCount: 1,
      wrongCount: 0,
      earnedXp: 10,
      itemIds: const ['word-1'],
      finalCorrectItemIds: const {'word-1'},
      attemptMetrics: [
        StudyAttemptMetric(
          itemId: 'word-1',
          skill: StudySkill.meaning,
          errorType: StudyErrorType.none,
          correct: true,
          responseTimeMs: 2400,
          recordedAt: startedAt.add(const Duration(minutes: 2)),
        ),
      ],
    );
    final valid = session.toJson();
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'recentSessions': [valid],
      }),
      returnsNormally,
    );

    final sensitive = Map<String, Object?>.from(valid);
    sensitive['attemptMetrics'] = [
      {
        ...(valid['attemptMetrics']! as List).single as Map,
        'answerText': 'private answer',
      },
    ];
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'recentSessions': [sensitive],
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) => error.issues.map((issue) => issue.path),
          'path',
          contains(r'$.recentSessions[0].attemptMetrics[0]'),
        ),
      ),
    );

    final outside = Map<String, Object?>.from(valid);
    outside['attemptMetrics'] = [
      {
        ...(valid['attemptMetrics']! as List).single as Map,
        'recordedAt': endedAt.add(const Duration(minutes: 1)).toIso8601String(),
      },
    ];
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'recentSessions': [outside],
      }),
      throwsA(isA<RemoteSnapshotValidationException>()),
    );
  });

  test('accepts and round-trips complete advanced preferences', () {
    final settingsUpdatedAt = DateTime.utc(2026, 7, 31, 12);
    final original = StudyPreferences(
      showReadingAids: false,
      ttsRate: 0.8,
      settingsUpdatedAt: settingsUpdatedAt,
      experience: AppExperiencePreferences(
        colorMode: AppColorMode.dark,
        accentPalette: AppAccentPalette.violet,
        density: AppDensity.compact,
        textScale: AppTextScale.large,
        motionLevel: AppMotionLevel.off,
        reduceMotion: true,
        hapticsEnabled: true,
        soundEffectsEnabled: true,
        updatedAt: settingsUpdatedAt,
      ),
      interaction: StudyInteractionPreferences(
        autoPlayQuestionAudio: true,
        autoPlayAnswerAudio: true,
        preferOfflineVoice: false,
        audioRepeatCount: 3,
        showKoreanReading: false,
        showNativeReading: true,
        answerDirection: StudyAnswerDirection.meaningToLearning,
        choiceLayout: StudyChoiceLayout.grid,
        shuffleChoices: false,
        autoAdvanceCorrect: true,
        autoAdvanceDelayMs: 3000,
        updatedAt: settingsUpdatedAt,
      ),
    );
    final settings = original.toJson();

    expect(
      () => validator.validate({'schemaVersion': 1, 'settings': settings}),
      returnsNormally,
    );

    final restored = StudyPreferences.fromJson(settings);
    expect(restored.experience.toJson(), original.experience.toJson());
    expect(restored.interaction.toJson(), original.interaction.toJson());
    expect(restored.settingsUpdatedAt, settingsUpdatedAt);
    expect(restored.ttsRate, 0.8);
  });

  test('accepts and migrates a legacy showReadingAids-only snapshot', () {
    final legacySettings = <String, Object?>{'showReadingAids': false};

    expect(
      () =>
          validator.validate({'schemaVersion': 1, 'settings': legacySettings}),
      returnsNormally,
    );

    final restored = StudyPreferences.fromJson(legacySettings);
    expect(restored.showReadingAids, isFalse);
    expect(restored.interaction.showKoreanReading, isFalse);
    expect(restored.interaction.showNativeReading, isFalse);
    expect(restored.experience, isA<AppExperiencePreferences>());
  });

  test('accepts pre-1.31 preference blocks without new fields', () {
    final legacyExperience = <String, Object?>{
      'colorMode': AppColorMode.system.name,
      'accentPalette': AppAccentPalette.sprache.name,
      'density': AppDensity.platform.name,
      'textScale': AppTextScale.system.name,
      'reduceMotion': false,
      'hapticsEnabled': false,
      'soundEffectsEnabled': false,
    };
    final legacyInteraction = <String, Object?>{
      'autoPlayQuestionAudio': false,
      'autoPlayAnswerAudio': false,
      'preferOfflineVoice': true,
      'audioRepeatCount': 1,
      'showKoreanReading': true,
      'showNativeReading': true,
      'answerDirection': StudyAnswerDirection.mixed.name,
      'choiceLayout': StudyChoiceLayout.automatic.name,
      'shuffleChoices': true,
      'autoAdvanceCorrect': false,
      'autoAdvanceDelayMs': 900,
    };

    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'settings': {
          'experience': legacyExperience,
          'interaction': legacyInteraction,
        },
      }),
      returnsNormally,
    );
  });

  test('rejects every malformed 1.31 experience enum and boolean', () {
    final baseline = AppExperiencePreferences(
      updatedAt: DateTime.utc(2026, 8, 3),
    ).toJson();

    void expectRejected(String field, Object? value) {
      expect(
        () => validator.validate({
          'schemaVersion': 1,
          'settings': {
            'experience': {...baseline, field: value},
          },
        }),
        throwsA(
          isA<RemoteSnapshotValidationException>().having(
            (error) => error.issues.map((issue) => issue.path),
            'validation paths',
            contains('\$.settings.experience.$field'),
          ),
        ),
        reason: field,
      );
    }

    for (final field in const [
      'surfaceTone',
      'cornerStyle',
      'cardStyle',
      'contentWidth',
      'fontEmphasis',
      'fontFamily',
      'themeScheduleMode',
      'studyTextScale',
      'cardAlignment',
      'navigationIconStyle',
      'decorationIntensity',
      'lightAccentPalette',
      'darkAccentPalette',
      'motionLevel',
      'celebrationLevel',
      'homeLayout',
      'navigationLabelMode',
      'subjectSwitcherStyle',
      'quickAddKind',
      'duplicateDefault',
      'feedbackDetail',
      'progressStyle',
      'encouragementTone',
      'readingLineHeight',
      'readingWidth',
    ]) {
      expectRejected(field, 'unsupported');
    }
    for (final field in const [
      'highContrast',
      'showFocusRing',
      'showHomeHeader',
      'showStreak',
      'showXp',
      'showSyncStatus',
      'showTodayPlan',
      'showPinnedCollections',
      'showRecentAdditions',
      'showDataFlow',
      'showSchedules',
      'showQuickAdd',
      'showGlobalSearch',
      'quickAddFavoriteDefault',
      'quickAddOpenDetails',
      'quickAddKeepAddingDefault',
      'quickAddAutoNormalize',
      'quickAddRememberTags',
      'showShortcutHints',
      'focusStudyMode',
      'leftHandedControls',
      'showStudyTimer',
      'showQuestionCounter',
      'perSubjectAccentEnabled',
      'separateBrightnessAccents',
      'scheduledDarkUsesOled',
      'customAccentEnabled',
    ]) {
      expectRejected(field, 1);
    }
  });

  test('rejects corrupt 1.31 layout, quick-add, and palette settings', () {
    final baseline = AppExperiencePreferences(
      updatedAt: DateTime.utc(2026, 8, 3),
    ).toJson();

    void expectRejected(String expectedPath, String field, Object? value) {
      expect(
        () => validator.validate({
          'schemaVersion': 1,
          'settings': {
            'experience': {...baseline, field: value},
          },
        }),
        throwsA(
          isA<RemoteSnapshotValidationException>().having(
            (error) => error.issues.map((issue) => issue.path),
            'validation paths',
            contains(expectedPath),
          ),
        ),
        reason: '$field: $value',
      );
    }

    for (final value in const <Object?>[-1, 6, 1.5, '3']) {
      expectRejected(
        r'$.settings.experience.quickAddPriorityDefault',
        'quickAddPriorityDefault',
        value,
      );
    }
    for (final value in const <Object?>[199, 2001, 450.5, '450']) {
      expectRejected(
        r'$.settings.experience.quickAddDraftDelayMs',
        'quickAddDraftDelayMs',
        value,
      );
    }
    for (final field in const ['themeDarkStartHour', 'themeLightStartHour']) {
      for (final value in const <Object?>[-1, 24, 1.5, '7']) {
        expectRejected(r'$.settings.experience.' + field, field, value);
      }
    }
    for (final value in const <Object?>[-1, 0x1000000, 1.5, '#112233']) {
      expectRejected(
        r'$.settings.experience.customAccentRgb',
        'customAccentRgb',
        value,
      );
    }
    expectRejected(
      r'$.settings.experience.homeSectionOrder',
      'homeSectionOrder',
      'not-a-list',
    );
    expectRejected(
      r'$.settings.experience.homeSectionOrder[0]',
      'homeSectionOrder',
      ['unknown'],
    );
    expectRejected(
      r'$.settings.experience.homeSectionOrder[1]',
      'homeSectionOrder',
      ['schedules', 'schedules'],
    );
    expectRejected(
      r'$.settings.experience.homeSectionOrder',
      'homeSectionOrder',
      [
        'pinnedCollections',
        'recentAdditions',
        'dataFlow',
        'schedules',
        'schedules',
      ],
    );
    expectRejected(
      r'$.settings.experience.accentPaletteBySubject',
      'accentPaletteBySubject',
      'not-a-map',
    );
    expectRejected(
      r'$.settings.experience.accentPaletteBySubject',
      'accentPaletteBySubject',
      {1: AppAccentPalette.sprache.name},
    );
    expectRejected(
      r'$.settings.experience.accentPaletteBySubject',
      'accentPaletteBySubject',
      {' language:en ': AppAccentPalette.sprache.name},
    );
    expectRejected(
      r'$.settings.experience.accentPaletteBySubject',
      'accentPaletteBySubject',
      {List.filled(161, 'x').join(): AppAccentPalette.sprache.name},
    );
    expectRejected(
      r'$.settings.experience.accentPaletteBySubject.language:en',
      'accentPaletteBySubject',
      {'language:en': 'neon'},
    );
    expectRejected(
      r'$.settings.experience.accentPaletteBySubject',
      'accentPaletteBySubject',
      {
        for (var index = 0; index < 101; index++)
          'custom:$index': AppAccentPalette.sprache.name,
      },
    );
  });

  test('validates bounded theme profiles and active profile references', () {
    final basePreferences = const AppExperiencePreferences();
    Map<String, Object?> profile(String id) => AppThemeProfile.capture(
      id: id,
      name: '프로필 $id',
      preferences: basePreferences,
    ).toJson();
    final baseline = basePreferences
        .copyWith(
          themeProfiles: [
            AppThemeProfile.capture(
              id: 'safe_1',
              name: '안전한 테마',
              preferences: basePreferences,
            ),
          ],
          activeThemeProfileId: 'safe_1',
        )
        .toJson();

    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'settings': {'experience': baseline},
      }),
      returnsNormally,
    );

    void expectRejected(Object? profiles, Object? active, String path) {
      expect(
        () => validator.validate({
          'schemaVersion': 1,
          'settings': {
            'experience': {
              ...baseline,
              'themeProfiles': profiles,
              'activeThemeProfileId': ?active,
            },
          },
        }),
        throwsA(
          isA<RemoteSnapshotValidationException>().having(
            (error) => error.issues.map((issue) => issue.path),
            'validation paths',
            contains(path),
          ),
        ),
      );
    }

    expectRejected('not-a-list', null, r'$.settings.experience.themeProfiles');
    expectRejected(
      [for (var index = 0; index < 6; index++) profile('theme_$index')],
      null,
      r'$.settings.experience.themeProfiles',
    );
    expectRejected(
      [profile('same'), profile('same')],
      null,
      r'$.settings.experience.themeProfiles[1].id',
    );
    expectRejected(
      [
        {...profile('broken'), 'customAccentRgb': '#FFFFFF'},
      ],
      null,
      r'$.settings.experience.themeProfiles[0]',
    );
    expectRejected(
      [profile('safe_1')],
      'missing',
      r'$.settings.experience.activeThemeProfileId',
    );
  });

  test('rejects corrupt practice activity personalization lists', () {
    final baseline = StudyInteractionPreferences(
      updatedAt: DateTime.utc(2026, 8, 3),
    ).toJson();
    final catalog = Map<String, Object?>.from(
      baseline['practiceCatalog']! as Map,
    );

    void expectRejected(String field, Object? value, String expectedPath) {
      expect(
        () => validator.validate({
          'schemaVersion': 1,
          'settings': {
            'interaction': {
              ...baseline,
              'practiceCatalog': {...catalog, field: value},
            },
          },
        }),
        throwsA(
          isA<RemoteSnapshotValidationException>().having(
            (error) => error.issues.map((issue) => issue.path),
            'validation paths',
            contains(expectedPath),
          ),
        ),
        reason: field,
      );
    }

    for (final field in const [
      'recentActivityIds',
      'favoriteActivityOrder',
      'quickLaunchActivityIds',
    ]) {
      expectRejected(
        field,
        'not-a-list',
        '\$.settings.interaction.practiceCatalog.$field',
      );
      expectRejected(field, [
        ' valid-id',
      ], '\$.settings.interaction.practiceCatalog.$field[0]');
      expectRejected(field, [
        List.filled(161, 'x').join(),
      ], '\$.settings.interaction.practiceCatalog.$field[0]');
      expectRejected(field, [
        'activity\ncontrol',
      ], '\$.settings.interaction.practiceCatalog.$field[0]');
      expectRejected(field, [
        '',
        1,
      ], '\$.settings.interaction.practiceCatalog.$field[0]');
      expectRejected(field, [
        'same-id',
        'same-id',
      ], '\$.settings.interaction.practiceCatalog.$field[1]');
    }
    expectRejected(
      'recentActivityIds',
      [for (var index = 0; index < 9; index++) 'activity-$index'],
      r'$.settings.interaction.practiceCatalog.recentActivityIds',
    );
    for (final field in const [
      'favoriteActivityOrder',
      'quickLaunchActivityIds',
    ]) {
      expectRejected(field, [
        for (var index = 0; index < 51; index++) 'activity-$index',
      ], '\$.settings.interaction.practiceCatalog.$field');
    }

    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'settings': {
          'interaction': {
            ...baseline,
            'practiceCatalog': {
              ...catalog,
              'recentActivityIds': ['/study?mode=meaning', 'meaning-choice'],
              'favoriteActivityOrder': ['course-path'],
              'quickLaunchActivityIds': ['match-sprint'],
            },
          },
        },
      }),
      returnsNormally,
    );
  });

  test('rejects corrupt game autonomy maps, records, and playlists', () {
    final interaction = StudyInteractionPreferences(
      updatedAt: DateTime.utc(2026, 8, 3),
    ).toJson();
    final catalog = Map<String, Object?>.from(
      interaction['practiceCatalog']! as Map,
    );

    void expectRejected(
      Map<String, Object?> corruptCatalog,
      String expectedPath,
    ) {
      expect(
        () => validator.validate({
          'schemaVersion': 1,
          'settings': {
            'interaction': {
              ...interaction,
              'practiceCatalog': {...catalog, ...corruptCatalog},
            },
          },
        }),
        throwsA(
          isA<RemoteSnapshotValidationException>().having(
            (error) => error.issues.map((issue) => issue.path),
            'validation paths',
            contains(expectedPath),
          ),
        ),
      );
    }

    expectRejected({
      'durationFilter': 'instant',
    }, r'$.settings.interaction.practiceCatalog.durationFilter');
    expectRejected(
      {
        'launchCountByActivityId': {'mixed-quiz': 1000001},
      },
      r'$.settings.interaction.practiceCatalog.launchCountByActivityId.mixed-quiz',
    );
    expectRejected(
      {
        'recommendationWeightByActivityId': {'mixed-quiz': 0},
      },
      r'$.settings.interaction.practiceCatalog.recommendationWeightByActivityId.mixed-quiz',
    );
    expectRejected(
      {
        'recommendationSnoozedUntilByActivityId': {'mixed-quiz': 'tomorrow'},
      },
      r'$.settings.interaction.practiceCatalog.recommendationSnoozedUntilByActivityId',
    );
    expectRejected(
      {
        'dailyQuestCompletionDayByScope': {
          'language%3Aen|meaning-choice': '2026-02-31',
        },
      },
      r'$.settings.interaction.practiceCatalog.dailyQuestCompletionDayByScope',
    );
    expectRejected(
      {
        'bestRecordsByActivityId': {
          'match-sprint': {
            'bestScore': 101,
            'updatedAt': '2026-08-03T00:00:00Z',
          },
        },
      },
      r'$.settings.interaction.practiceCatalog.bestRecordsByActivityId.match-sprint.bestScore',
    );
    expectRejected({
      'playlists': [
        {
          'id': 'too-short',
          'name': '한 게임',
          'activityIds': ['mixed-quiz'],
        },
      ],
    }, r'$.settings.interaction.practiceCatalog.playlists[0].activityIds');
    expectRejected(
      {
        'launchByActivityId': {
          'mixed-quiz': {'challengeScoringEnabled': 'yes'},
        },
      },
      r'$.settings.interaction.practiceCatalog.launchByActivityId.mixed-quiz.challengeScoringEnabled',
    );
  });

  test('rejects malformed advanced remote settings with exact paths', () {
    final updatedAt = DateTime.utc(2026, 7, 31, 12);
    final valid = StudyPreferences(
      settingsUpdatedAt: updatedAt,
      experience: AppExperiencePreferences(updatedAt: updatedAt),
      interaction: StudyInteractionPreferences(updatedAt: updatedAt),
    ).toJson();

    Map<String, Object?> corruptNested(
      String block,
      String field,
      Object? value,
    ) {
      return {
        ...valid,
        block: {
          ...Map<String, Object?>.from(valid[block]! as Map),
          field: value,
        },
      };
    }

    Map<String, Object?> removeNested(String block, String field) {
      final nested = Map<String, Object?>.from(valid[block]! as Map)
        ..remove(field);
      return {...valid, block: nested};
    }

    final cases = <({String path, Map<String, Object?> settings})>[
      (
        path: r'$.settings.showReadingAids',
        settings: {...valid, 'showReadingAids': 'yes'},
      ),
      (path: r'$.settings.ttsRate', settings: {...valid, 'ttsRate': 0.81}),
      (
        path: r'$.settings.settingsUpdatedAt',
        settings: {...valid, 'settingsUpdatedAt': 'not-a-date'},
      ),
      (
        path: r'$.settings.experience',
        settings: {...valid, 'experience': <Object?>[]},
      ),
      (
        path: r'$.settings.experience.colorMode',
        settings: corruptNested('experience', 'colorMode', 'sepia'),
      ),
      (
        path: r'$.settings.experience.accentPalette',
        settings: corruptNested('experience', 'accentPalette', 'neon'),
      ),
      (
        path: r'$.settings.experience.density',
        settings: corruptNested('experience', 'density', 'tiny'),
      ),
      (
        path: r'$.settings.experience.textScale',
        settings: corruptNested('experience', 'textScale', 'huge'),
      ),
      (
        path: r'$.settings.experience.textScale',
        settings: removeNested('experience', 'textScale'),
      ),
      (
        path: r'$.settings.experience.hapticsEnabled',
        settings: corruptNested('experience', 'hapticsEnabled', 1),
      ),
      (
        path: r'$.settings.experience.updatedAt',
        settings: corruptNested('experience', 'updatedAt', 'not-a-date'),
      ),
      (
        path: r'$.settings.interaction',
        settings: {...valid, 'interaction': 'invalid'},
      ),
      (
        path: r'$.settings.interaction.audioRepeatCount',
        settings: corruptNested('interaction', 'audioRepeatCount', 0),
      ),
      (
        path: r'$.settings.interaction.audioRepeatCount',
        settings: corruptNested('interaction', 'audioRepeatCount', 1.5),
      ),
      (
        path: r'$.settings.interaction.audioRepeatCount',
        settings: removeNested('interaction', 'audioRepeatCount'),
      ),
      (
        path: r'$.settings.interaction.autoAdvanceDelayMs',
        settings: corruptNested('interaction', 'autoAdvanceDelayMs', 299),
      ),
      (
        path: r'$.settings.interaction.answerDirection',
        settings: corruptNested('interaction', 'answerDirection', 'sideways'),
      ),
      (
        path: r'$.settings.interaction.choiceLayout',
        settings: corruptNested('interaction', 'choiceLayout', 'carousel'),
      ),
      (
        path: r'$.settings.interaction.autoPlayQuestionAudio',
        settings: corruptNested('interaction', 'autoPlayQuestionAudio', 'yes'),
      ),
      (
        path: r'$.settings.interaction.updatedAt',
        settings: corruptNested('interaction', 'updatedAt', 'not-a-date'),
      ),
    ];

    for (final testCase in cases) {
      expect(
        () => validator.validate({
          'schemaVersion': 1,
          'settings': testCase.settings,
        }),
        throwsA(
          isA<RemoteSnapshotValidationException>().having(
            (error) => error.issues.map((issue) => issue.path),
            'validation paths',
            contains(testCase.path),
          ),
        ),
        reason: testCase.path,
      );
    }
  });

  test('accepts the 100-question session plan boundary', () {
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'settings': {
          'sessionPlan': {
            ...const StudySessionPlan(itemLimit: 100).toJson(),
            'queuePriority': StudyQueuePriority.newFirst.name,
            'historyFilter': StudyHistoryFilter.wrongOnly.name,
          },
        },
      }),
      returnsNormally,
    );
  });

  test('accepts the normalized simplified Chinese subject ID from Drive', () {
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'settings': {
          'sessionPlan': {'subjectId': 'language:zh-hans'},
          'activeSubjectId': 'language:zh-hans',
        },
      }),
      returnsNormally,
    );
  });

  test('validates built-in overrides, visibility, and upload routes', () {
    final rule = ImportDistributionRule(
      key: 'travel-core',
      subjectId: 'language:en',
      groupName: '여행 준비',
      createdAt: DateTime.utc(2026, 7, 30, 1),
      updatedAt: DateTime.utc(2026, 7, 30, 2),
    );
    final settings = {
      'customSubjects': [
        {
          'id': 'language:en',
          'kind': 'language',
          'name': '업무 영어',
          'description': '회사에서 쓰는 영어',
          'symbol': '💼',
          'contentLanguage': 'en',
        },
      ],
      'hiddenSubjectIds': ['language:fr'],
      'subjectVisibilityChangedAtById': {
        'language:fr': '2026-07-30T02:00:00.000Z',
      },
      'importDistributionRules': [rule.toJson()],
    };

    expect(
      () => validator.validate({'schemaVersion': 1, 'settings': settings}),
      returnsNormally,
    );

    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'settings': {
          ...settings,
          'hiddenSubjectIds': ['general:missing'],
          'importDistributionRules': [
            {...rule.toJson(), 'subjectId': 'general:missing'},
          ],
        },
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) => error.issues.map((issue) => issue.path),
          'paths',
          containsAll([
            r'$.settings.hiddenSubjectIds',
            r'$.settings.importDistributionRules[0].subjectId',
          ]),
        ),
      ),
    );
  });

  test('validates per-course XP and per-subject daily goals', () {
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'profile': {
          'dailyXpByCourse': {'ko-en': 25, 'ko-ja': 15},
          'dailyXpByCourseAndReplica': {
            'ko-en': {'replica-windows': 15, 'replica-android': 10},
          },
          'xpByReplica': {'replica-windows': 120, 'replica-android': 80},
        },
        'settings': {
          'dailyGoalsBySubject': {'language:en': 100, 'language:ja': 200},
          'weeklyTargetDays': 5,
          'weeklyTargetMinutes': 90,
          'dailyGoalChangedAtBySubject': {
            'language:en': '2026-07-29T00:00:00.000Z',
          },
          'activeSubjectChangedAt': '2026-07-29T00:00:00.000Z',
          'favoriteItemChangedAtById': {'item-1': '2026-07-29T00:00:00.000Z'},
          'savedSessionPlanTombstones': {'plan-1': '2026-07-29T00:00:00.000Z'},
        },
      }),
      returnsNormally,
    );

    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'profile': {
          'dailyXpByCourse': {'ko-en': -1},
          'dailyXpByCourseAndReplica': {
            'ko-en': {'invalid replica': -1},
          },
          'xpByReplica': {'invalid replica id': -1},
        },
        'settings': {
          'dailyGoalsBySubject': {'bad subject': 10},
          'weeklyTargetDays': 2.5,
          'weeklyTargetMinutes': 1000,
          'dailyGoalChangedAtBySubject': {'language:en': 'not-a-date'},
          'activeSubjectChangedAt': 123,
          'favoriteItemChangedAtById': {'item-1': 'not-a-date'},
          'savedSessionPlanTombstones': {'plan-1': 'not-a-date'},
        },
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) => error.issues.map((issue) => issue.path),
          'paths',
          containsAll([
            r'$.profile.dailyXpByCourse',
            r'$.profile.dailyXpByCourseAndReplica',
            r'$.profile.xpByReplica',
            r'$.settings.dailyGoalsBySubject',
            r'$.settings.weeklyTargetDays',
            r'$.settings.weeklyTargetMinutes',
            r'$.settings.dailyGoalChangedAtBySubject',
            r'$.settings.activeSubjectChangedAt',
            r'$.settings.favoriteItemChangedAtById',
            r'$.settings.savedSessionPlanTombstones',
          ]),
        ),
      ),
    );
  });

  test('reports exact paths for corrupt progress and content', () {
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'progress': [
          {'itemId': 'item-1', 'correctCount': -1},
        ],
        'customItems': [
          {
            'id': 'bad-item',
            'kind': 'word',
            'language': 'en',
            'text': 'word',
            'translations': <String>[],
          },
        ],
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) => error.issues.map((issue) => issue.path),
          'paths',
          containsAll([r'$.progress[0].correctCount', r'$.customItems[0]']),
        ),
      ),
    );
  });

  test('rejects duplicate remote content IDs', () {
    final item = {
      'id': 'same-id',
      'kind': 'word',
      'language': 'en',
      'text': 'hello',
      'translations': ['안녕하세요'],
      'acceptedAnswers': ['안녕하세요'],
    };

    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'customItems': [item, item],
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) =>
              error.issues.any((issue) => issue.path == r'$.customItems[1].id'),
          'duplicate ID issue',
          isTrue,
        ),
      ),
    );
  });

  test('rejects malformed custom item tombstones', () {
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'customItemTombstones': [
          {'id': 'deleted-item', 'deletedAt': 'not-a-date'},
        ],
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) => error.first.path,
          'path',
          r'$.customItemTombstones[0].deletedAt',
        ),
      ),
    );
  });

  test('validates synchronized recent sessions and duplicate IDs', () {
    final session = StudySessionSummary(
      sessionId: 'recent-session',
      courseId: 'subject:general:baseball',
      startedAt: DateTime.utc(2026, 7, 28, 9),
      endedAt: DateTime.utc(2026, 7, 28, 9, 5),
      correctCount: 1,
      wrongCount: 1,
      earnedXp: 15,
      itemIds: const ['word-1', 'sentence-1'],
      wrongItemIds: const {'sentence-1'},
    );

    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'recentSessions': [session.toJson()],
      }),
      returnsNormally,
    );
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'recentSessions': [session.toJson(), session.toJson()],
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) => error.issues.map((issue) => issue.path),
          'paths',
          contains(r'$.recentSessions[1].sessionId'),
        ),
      ),
    );
  });

  test('rejects malformed session builder settings with exact paths', () {
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'settings': {
          'sessionPlan': {
            'mode': 'unsupported',
            'deck': 'everywhere',
            'unitIndex': 20,
            'sentenceRatio': 4,
            'itemLimit': 101,
            'updatedAt': 'not-a-date',
          },
        },
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) => error.issues.map((issue) => issue.path),
          'paths',
          containsAll([
            r'$.settings.sessionPlan.mode',
            r'$.settings.sessionPlan.deck',
            r'$.settings.sessionPlan.unitIndex',
            r'$.settings.sessionPlan.sentenceRatio',
            r'$.settings.sessionPlan.itemLimit',
            r'$.settings.sessionPlan.updatedAt',
          ]),
        ),
      ),
    );
  });

  test('rejects duplicate or malformed saved schedule IDs', () {
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'settings': {
          'savedSessionPlans': [
            const StudySessionPlan(planId: 'same-plan', title: '첫 일정').toJson(),
            {
              ...const StudySessionPlan(
                planId: 'same-plan',
                title: '둘째 일정',
              ).toJson(),
              'scheduledAt': 'not-a-date',
            },
          ],
        },
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) => error.issues.map((issue) => issue.path),
          'paths',
          containsAll([
            r'$.settings.savedSessionPlans[1].planId',
            r'$.settings.savedSessionPlans[1].scheduledAt',
          ]),
        ),
      ),
    );
  });

  test('rejects a schedule that points to an unknown study subject', () {
    expect(
      () => validator.validate({
        'schemaVersion': 1,
        'settings': {
          'activeSubjectId': 'language:en',
          'savedSessionPlans': [
            const StudySessionPlan(
              planId: 'orphan-plan',
              subjectId: 'general:missing',
              title: '연결이 끊긴 일정',
            ).toJson(),
          ],
        },
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) => error.issues.map((issue) => issue.path),
          'paths',
          contains(r'$.settings.savedSessionPlans[0].subjectId'),
        ),
      ),
    );
  });

  test(
    'rejects corrupt custom subjects before they can replace local data',
    () {
      expect(
        () => validator.validate({
          'schemaVersion': 1,
          'settings': {
            'activeSubjectId': 'general:missing',
            'customSubjects': [
              {
                'id': 'general:baseball',
                'kind': 'general',
                'name': '야구',
                'description': '',
                'symbol': '⚾',
                'contentLanguage': 'ko',
              },
              {
                'id': 'general:baseball',
                'kind': 'general',
                'name': '중복 야구',
                'description': '',
                'symbol': 'B',
                'contentLanguage': 'ko',
              },
            ],
          },
        }),
        throwsA(
          isA<RemoteSnapshotValidationException>().having(
            (error) => error.issues.map((issue) => issue.path),
            'paths',
            containsAll([
              r'$.settings.customSubjects[1].id',
              r'$.settings.activeSubjectId',
            ]),
          ),
        ),
      );
    },
  );

  test(
    'validates active session lineage while allowing repeat queue entries',
    () {
      final startedAt = DateTime.utc(2026, 7, 28, 9);
      final session = ActiveStudySession.started(
        sessionId: 'active-session',
        courseId: 'subject:general:baseball',
        mode: StudyMode.mixed,
        unitIndex: null,
        itemIds: const ['a', 'b'],
        startedAt: startedAt,
      ).copyWith(itemIds: const ['a', 'b', 'a'], wrongItemIds: const {'a'});
      final valid = {
        'schemaVersion': 1,
        'activeStudy': {
          'changedAt': session.updatedAt.toIso8601String(),
          'session': session.toJson(),
        },
      };

      expect(() => validator.validate(valid), returnsNormally);
      expect(
        () => validator.validate({
          ...valid,
          'activeStudy': {
            'changedAt': session.updatedAt.toIso8601String(),
            'session': {
              ...session.toJson(),
              'wrongItemIds': ['missing'],
            },
          },
        }),
        throwsA(
          isA<RemoteSnapshotValidationException>().having(
            (error) => error.issues.map((issue) => issue.path),
            'paths',
            contains(r'$.activeStudy.session.wrongItemIds'),
          ),
        ),
      );
    },
  );

  test('validates active exam attempt review identity and sequence', () {
    final startedAt = DateTime.utc(2026, 8, 3, 9);
    final session =
        ActiveStudySession.started(
          sessionId: 'active-exam-session',
          courseId: 'ko-en',
          mode: StudyMode.meaning,
          unitIndex: null,
          itemIds: const ['a'],
          startedAt: startedAt,
        ).copyWith(
          attemptReviews: const [
            QuizAttemptReview(
              sequence: 1,
              itemId: 'a',
              prompt: 'alpha',
              expectedAnswer: '알파',
              userAnswer: '알파',
              exerciseType: 'recognition',
              correct: true,
              rating: ReviewRating.good,
              usedHint: false,
            ),
          ],
        );
    final valid = {
      'schemaVersion': 1,
      'activeStudy': {
        'changedAt': session.updatedAt.toIso8601String(),
        'session': session.toJson(),
      },
    };

    expect(() => validator.validate(valid), returnsNormally);
    final review = (session.toJson()['attemptReviews']! as List).single as Map;
    expect(
      () => validator.validate({
        ...valid,
        'activeStudy': {
          'changedAt': session.updatedAt.toIso8601String(),
          'session': {
            ...session.toJson(),
            'attemptReviews': [
              {...review, 'itemId': 'missing'},
            ],
          },
        },
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) => error.issues.map((issue) => issue.path),
          'paths',
          contains(r'$.activeStudy.session.attemptReviews[0].itemId'),
        ),
      ),
    );
  });

  test('validates every snapshot v2 session planning field', () {
    final validPlan = <String, Object?>{
      'subjectId': 'language:en',
      'groupIds': ['language:en:group:office'],
      'lengthMode': 'timeBudget',
      'timeBudgetMinutes': 10,
      'recordProgress': false,
      'answerDirectionOverride': 'meaningToLearning',
      'gradingStrictness': 'strict',
      'examSchedule': {
        'targetDate': '2026-09-01T00:00:00.000Z',
        'dailyCap': 40,
        'preferredMinuteOfDay': 1140,
      },
      'backlogRecovery': {'enabled': true, 'dailyLimit': 25},
    };
    expect(
      () => validator.validate({
        'schemaVersion': 2,
        'settings': {'sessionPlan': validPlan},
      }),
      returnsNormally,
    );

    final invalidPlan = <String, Object?>{
      ...validPlan,
      'groupIds': [1],
      'lengthMode': 'endless',
      'timeBudgetMinutes': 90,
      'recordProgress': 'yes',
      'answerDirectionOverride': 'reverse',
      'gradingStrictness': 'impossible',
      'examSchedule': {
        'targetDate': 'not-a-date',
        'dailyCap': 0,
        'preferredMinuteOfDay': 1440,
      },
      'backlogRecovery': {'enabled': 'yes', 'dailyLimit': 0},
    };
    expect(
      () => validator.validate({
        'schemaVersion': 2,
        'settings': {'sessionPlan': invalidPlan},
      }),
      throwsA(
        isA<RemoteSnapshotValidationException>().having(
          (error) => error.issues.map((issue) => issue.path),
          'paths',
          containsAll([
            r'$.settings.sessionPlan.groupIds',
            r'$.settings.sessionPlan.lengthMode',
            r'$.settings.sessionPlan.timeBudgetMinutes',
            r'$.settings.sessionPlan.recordProgress',
            r'$.settings.sessionPlan.answerDirectionOverride',
            r'$.settings.sessionPlan.gradingStrictness',
            r'$.settings.sessionPlan.examSchedule.targetDate',
            r'$.settings.sessionPlan.examSchedule.dailyCap',
            r'$.settings.sessionPlan.examSchedule.preferredMinuteOfDay',
            r'$.settings.sessionPlan.backlogRecovery.enabled',
            r'$.settings.sessionPlan.backlogRecovery.dailyLimit',
          ]),
        ),
      ),
    );
  });
}
