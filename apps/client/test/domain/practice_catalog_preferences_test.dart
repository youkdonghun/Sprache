import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';

void main() {
  group('PracticeCatalogPreferences', () {
    test('round trip migrates stable ids and keeps every launch rule', () {
      const catalog = PracticeCatalogPreferences(
        favoriteActivityIds: {'/study?mode=production', '/study?mode=meaning'},
        hiddenActivityIds: {'/path'},
        recentActivityIds: [
          '/study?mode=meaning',
          '/study?mode=production',
          '/study?mode=meaning',
        ],
        favoriteActivityOrder: [
          '/study?mode=production',
          '/path',
          '/study?mode=meaning',
        ],
        quickLaunchActivityIds: {'/study?mode=production'},
        launchByActivityId: {
          '/study?mode=production': PracticeLaunchPreferences(
            length: PracticeSessionLength.fifteenMinutes,
            itemCount: 36,
            difficulty: PracticeDifficultyPreset.challenge,
            historyScope: PracticeHistoryScope.excludeCorrect,
            queueOrder: PracticeQueueOrder.newFirst,
            answerDirection: StudyAnswerDirection.meaningToLearning,
            gradingStrictness: StudyGradingStrictness.strict,
            choiceCount: 6,
            recordProgress: false,
            hintsEnabled: false,
            autoAdvance: true,
            soundEnabled: true,
            largeControls: true,
            challengeScoringEnabled: true,
          ),
          '/study?mode=meaning': PracticeLaunchPreferences(
            length: PracticeSessionLength.fiveItems,
            itemCount: 5,
            difficulty: PracticeDifficultyPreset.relaxed,
            answerDirection: StudyAnswerDirection.learningToMeaning,
            gradingStrictness: StudyGradingStrictness.lenient,
            choiceCount: 2,
          ),
        },
      );

      final json = catalog.toJson();
      expect(json['favoriteActivityIds'], [
        'meaning-choice',
        'production-writing',
      ]);
      expect((json['launchByActivityId'] as Map<String, Object?>).keys, [
        'meaning-choice',
        'production-writing',
      ]);
      expect(json['recentActivityIds'], [
        'meaning-choice',
        'production-writing',
      ]);
      expect(json['favoriteActivityOrder'], [
        'production-writing',
        'meaning-choice',
      ]);
      expect(json['quickLaunchActivityIds'], ['production-writing']);

      final restored = PracticeCatalogPreferences.fromJson(json);
      final launch = restored.launchFor('production-writing');
      expect(restored.favoriteActivityIds, {
        'production-writing',
        'meaning-choice',
      });
      expect(restored.hiddenActivityIds, {'course-path'});
      expect(restored.recentActivityIds, [
        'meaning-choice',
        'production-writing',
      ]);
      expect(restored.quickLaunchActivityIds, {'production-writing'});
      expect(
        restored.launchFor('/study?mode=production').itemCount,
        launch.itemCount,
      );
      expect(launch.length, PracticeSessionLength.fifteenMinutes);
      expect(launch.itemCount, 36);
      expect(launch.difficulty, PracticeDifficultyPreset.challenge);
      expect(launch.historyScope, PracticeHistoryScope.excludeCorrect);
      expect(launch.queueOrder, PracticeQueueOrder.newFirst);
      expect(launch.answerDirection, StudyAnswerDirection.meaningToLearning);
      expect(launch.gradingStrictness, StudyGradingStrictness.strict);
      expect(launch.choiceCount, 6);
      expect(launch.recordProgress, isFalse);
      expect(launch.hintsEnabled, isFalse);
      expect(launch.autoAdvance, isTrue);
      expect(launch.soundEnabled, isTrue);
      expect(launch.largeControls, isTrue);
      expect(launch.challengeScoringEnabled, isTrue);
      expect(restored.launchFor('/unknown'), isA<PracticeLaunchPreferences>());
      expect(
        () => restored.launchByActivityId['/new'] =
            const PracticeLaunchPreferences(),
        throwsUnsupportedError,
      );
    });

    test('sanitizes ids, overlaps, limits, and malformed launch values', () {
      final oversizedId = List.filled(161, 'x').join();
      final favoriteIds = <Object?>[
        '  /study?mode=meaning  ',
        '/study?mode=meaning',
        '/path',
        '',
        7,
        oversizedId,
        for (var index = 0; index < 70; index++) '/favorite-$index',
      ];
      final restored = PracticeCatalogPreferences.fromJson({
        'favoriteActivityIds': favoriteIds,
        'hiddenActivityIds': const ['/path', ' /study?mode=meaning ', null],
        'launchByActivityId': {
          ' /study?mode=production ': {
            'itemCount': 400,
            'choiceCount': 3,
            'recordProgress': 'false',
          },
          '/bad-value': 'not-a-map',
          oversizedId: {'choiceCount': 6},
        },
      });

      expect(restored.hiddenActivityIds, {'course-path', 'meaning-choice'});
      expect(restored.favoriteActivityIds, isNot(contains('course-path')));
      expect(restored.favoriteActivityIds, isNot(contains('meaning-choice')));
      expect(restored.favoriteActivityIds.length, lessThanOrEqualTo(50));
      expect(restored.launchByActivityId.keys, {'production-writing'});
      final launch = restored.launchFor('production-writing');
      expect(launch.itemCount, 100);
      expect(launch.choiceCount, 4);
      expect(launch.recordProgress, isTrue);
    });

    test('malformed nested launch maps never escape as parse errors', () {
      expect(
        () => PracticeCatalogPreferences.fromJson({
          'launchByActivityId': {
            '/study?mode=meaning': {1: 'invalid-key'},
          },
        }),
        returnsNormally,
      );
    });

    test('dynamic unit note routes migrate to one stable preference id', () {
      final restored = PracticeCatalogPreferences.fromJson({
        'favoriteActivityIds': const ['/notes/2'],
        'recentActivityIds': const ['/notes/4', '/notes/1'],
      });

      expect(restored.favoriteActivityIds, {'unit-notes'});
      expect(restored.recentActivityIds, ['unit-notes']);
      expect(restored.toJson()['favoriteActivityIds'], ['unit-notes']);
    });

    test(
      'recents, favorite order, and quick launch remain bounded and coherent',
      () {
        var catalog = const PracticeCatalogPreferences(
          favoriteActivityIds: {'mixed-quiz', 'meaning-choice'},
          favoriteActivityOrder: [
            'missing',
            'meaning-choice',
            'meaning-choice',
          ],
          quickLaunchActivityIds: {'mixed-quiz', 'hidden'},
          hiddenActivityIds: {'hidden'},
        ).copyWith();

        for (var index = 0; index < 12; index++) {
          catalog = catalog.recordActivity('game-$index');
        }

        expect(catalog.recentActivityIds, hasLength(8));
        expect(catalog.recentActivityIds.first, 'game-11');
        expect(catalog.recentActivityIds.last, 'game-4');
        expect(catalog.favoriteActivityOrder, ['meaning-choice']);
        expect(catalog.quickLaunchActivityIds, {'mixed-quiz'});

        final withoutMeaning = catalog.copyWith(
          favoriteActivityIds: {'mixed-quiz'},
        );
        expect(withoutMeaning.favoriteActivityOrder, isEmpty);
        expect(
          () => withoutMeaning.recentActivityIds.add('mutate'),
          throwsUnsupportedError,
        );
      },
    );

    test('malformed new catalog collections fall back without throwing', () {
      expect(
        () => PracticeCatalogPreferences.fromJson({
          'recentActivityIds': 'not-a-list',
          'favoriteActivityOrder': 7,
          'quickLaunchActivityIds': {'not': 'a-list'},
        }),
        returnsNormally,
      );
    });

    test(
      'autonomy settings keep filters, counts, snoozes, weights, records, and playlists bounded',
      () {
        final now = DateTime.utc(2026, 8, 3, 9);
        var catalog = PracticeCatalogPreferences.fromJson({
          'durationFilter': 'tenMinutes',
          'skillFilter': 'listening',
          'sortOrder': 'launchCount',
          'launchCountByActivityId': {
            '/study?mode=meaning': 7,
            'bad-negative': -1,
            'bad-string': '4',
          },
          'recommendationSnoozedUntilByActivityId': {
            '/study?mode=meaning': now
                .add(const Duration(days: 1))
                .toIso8601String(),
            'bad-date': 'tomorrow',
          },
          'recommendationWeightByActivityId': {
            '/study?mode=meaning': 2,
            'too-large': 4,
            'zero': 0,
          },
          'surpriseDurationFilter': 'threeMinutes',
          'surpriseSkillFilter': 'recognition',
          'surpriseFavoritesOnly': true,
          'surpriseAvoidRecent': false,
          'bestRecordsByActivityId': {
            '/study?mode=mixed&match=true': {
              'bestScore': 82,
              'bestElapsedMs': 45000,
              'updatedAt': now.toIso8601String(),
            },
            'broken': {'bestScore': 101, 'updatedAt': 'bad'},
          },
          'playlists': [
            {
              'id': 'morning',
              'name': '아침 루틴',
              'activityIds': [
                '/study?mode=meaning',
                '/study?mode=production',
                '/cards?kind=words',
              ],
            },
            {
              'id': 'too-short',
              'name': '하나',
              'activityIds': ['/study?mode=meaning'],
            },
          ],
        });

        expect(catalog.durationFilter, PracticeDurationFilter.tenMinutes);
        expect(catalog.skillFilter, PracticeSkillFilter.listening);
        expect(catalog.sortOrder, PracticeCatalogSort.launchCount);
        expect(catalog.launchCountByActivityId, {'meaning-choice': 7});
        expect(catalog.recommendationWeightByActivityId, {'meaning-choice': 2});
        expect(
          catalog.surpriseDurationFilter,
          PracticeDurationFilter.threeMinutes,
        );
        expect(catalog.surpriseSkillFilter, PracticeSkillFilter.recognition);
        expect(catalog.surpriseFavoritesOnly, isTrue);
        expect(catalog.surpriseAvoidRecent, isFalse);
        expect(catalog.bestRecordsByActivityId['match-sprint']?.bestScore, 82);
        expect(catalog.playlists, hasLength(1));
        expect(catalog.playlists.single.activityIds, [
          'meaning-choice',
          'production-writing',
        ]);

        catalog = catalog.recordActivity('/study?mode=meaning');
        expect(catalog.launchCountByActivityId['meaning-choice'], 8);
        catalog = catalog.adjustRecommendationWeight('meaning-choice', 9);
        expect(catalog.recommendationWeightByActivityId['meaning-choice'], 3);
        catalog = catalog.snoozeRecommendation(
          'meaning-choice',
          now.add(const Duration(days: 7)),
        );
        expect(
          catalog.recommendationSnoozedUntilByActivityId['meaning-choice'],
          now.add(const Duration(days: 7)),
        );
        catalog = catalog.recordBest(
          'match-sprint',
          score: 91,
          elapsedMs: 42000,
          at: now.add(const Duration(minutes: 2)),
        );
        expect(catalog.bestRecordsByActivityId['match-sprint']?.bestScore, 91);
        expect(
          catalog.bestRecordsByActivityId['match-sprint']?.bestElapsedMs,
          42000,
        );

        final restored = PracticeCatalogPreferences.fromJson(catalog.toJson());
        expect(restored.toJson(), catalog.toJson());
        expect(
          () => restored.playlists.single.activityIds.add('weak-review'),
          throwsUnsupportedError,
        );
      },
    );

    test('daily quest completion persists by local day and subject', () {
      final completedAt = DateTime(2026, 8, 3, 20, 15);
      final catalog = const PracticeCatalogPreferences()
          .recordDailyQuestCompletion(
            activityId: '/study?mode=meaning',
            subjectId: 'language:en',
            completedAt: completedAt,
          )
          .recordDailyQuestCompletion(
            activityId: 'production-writing',
            subjectId: 'language:en',
            completedAt: completedAt,
          );

      expect(
        catalog.completedDailyQuestActivityIds(
          day: completedAt,
          subjectId: 'language:en',
          activityIds: const [
            'meaning-choice',
            'production-writing',
            'sentence-order',
          ],
        ),
        {'meaning-choice', 'production-writing'},
      );
      expect(
        catalog.completedDailyQuestActivityIds(
          day: completedAt,
          subjectId: 'language:ja',
          activityIds: const ['meaning-choice'],
        ),
        isEmpty,
      );
      expect(
        catalog.completedDailyQuestActivityIds(
          day: completedAt.add(const Duration(days: 1)),
          subjectId: 'language:en',
          activityIds: const ['meaning-choice'],
        ),
        isEmpty,
      );

      final restored = PracticeCatalogPreferences.fromJson(catalog.toJson());
      expect(restored.toJson(), catalog.toJson());
      expect(
        () => restored.dailyQuestCompletionDayByScope['unsafe'] = '2026-08-03',
        throwsUnsupportedError,
      );
    });

    test('daily quest assignment stays fixed when candidates change', () {
      final day = DateTime(2026, 8, 3, 9);
      final assigned = const PracticeCatalogPreferences()
          .ensureDailyQuestAssignment(
            day: day,
            subjectId: 'language:en',
            activityIds: const [
              'meaning-choice',
              'production-writing',
              'sentence-order',
              'match-sprint',
            ],
          );
      final original = assigned.dailyQuestActivityIds(
        day: day,
        subjectId: 'language:en',
        activityIds: const ['meaning-choice'],
      );
      final afterCandidateChange = assigned
          .ensureDailyQuestAssignment(
            day: day,
            subjectId: 'language:en',
            activityIds: const [
              'meaning-choice',
              'exam-simulator',
              'recent-wrong',
            ],
          )
          .dailyQuestActivityIds(
            day: day,
            subjectId: 'language:en',
            activityIds: const ['exam-simulator'],
          );

      expect(afterCandidateChange, original);
      final restored = PracticeCatalogPreferences.fromJson(assigned.toJson());
      expect(
        restored.dailyQuestActivityIds(
          day: day,
          subjectId: 'language:en',
          activityIds: const ['exam-simulator'],
        ),
        original,
      );
    });

    test(
      'daily quest assignment keeps the newest day after the 60-day cap',
      () {
        var catalog = const PracticeCatalogPreferences();
        final firstDay = DateTime(2026, 1, 1, 9);
        for (var offset = 0; offset < 61; offset++) {
          catalog = catalog.ensureDailyQuestAssignment(
            day: firstDay.add(Duration(days: offset)),
            subjectId: 'language:en',
            activityIds: const [
              'meaning-choice',
              'production-writing',
              'sentence-order',
            ],
          );
        }

        final newestDay = firstDay.add(const Duration(days: 60));
        expect(catalog.dailyQuestAssignmentByScope, hasLength(60));
        expect(
          catalog.hasDailyQuestAssignment(
            day: newestDay,
            subjectId: 'language:en',
          ),
          isTrue,
        );
        expect(
          catalog.dailyQuestActivityIds(
            day: newestDay,
            subjectId: 'language:en',
            activityIds: const ['meaning-choice'],
          ),
          hasLength(3),
        );
      },
    );

    test(
      'playlist route allowlist rejects navigation and non-study activities',
      () {
        expect(isPlaylistCompatiblePracticeActivity('meaning-choice'), isTrue);
        expect(
          isPlaylistCompatiblePracticeActivity('/study?mode=production'),
          isTrue,
        );
        expect(
          isPlaylistCompatiblePracticeActivity('/cards?kind=words'),
          isFalse,
        );
        expect(isPlaylistCompatiblePracticeActivity('/settings'), isFalse);
        expect(
          practiceRouteForActivityId('match-sprint'),
          contains('match=true'),
        );
        expect(
          practiceRouteForActivityId('listening-discrimination'),
          contains('practiceActivityId=listening-discrimination'),
        );
        expect(
          practiceRouteForActivityId('exam-simulator'),
          contains('exam=true'),
        );
      },
    );
  });
}
