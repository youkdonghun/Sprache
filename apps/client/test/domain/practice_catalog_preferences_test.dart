import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';

void main() {
  group('PracticeCatalogPreferences', () {
    test('round trip keeps catalog ordering and every launch rule', () {
      const catalog = PracticeCatalogPreferences(
        favoriteActivityIds: {'/study?mode=production', '/study?mode=meaning'},
        hiddenActivityIds: {'/path'},
        launchByActivityId: {
          '/study?mode=production': PracticeLaunchPreferences(
            length: PracticeSessionLength.tenMinutes,
            itemCount: 24,
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
        '/study?mode=meaning',
        '/study?mode=production',
      ]);
      expect((json['launchByActivityId'] as Map<String, Object?>).keys, [
        '/study?mode=meaning',
        '/study?mode=production',
      ]);

      final restored = PracticeCatalogPreferences.fromJson(json);
      final launch = restored.launchFor('/study?mode=production');
      expect(restored.favoriteActivityIds, catalog.favoriteActivityIds);
      expect(restored.hiddenActivityIds, catalog.hiddenActivityIds);
      expect(launch.length, PracticeSessionLength.tenMinutes);
      expect(launch.itemCount, 24);
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

      expect(restored.hiddenActivityIds, {'/path', '/study?mode=meaning'});
      expect(restored.favoriteActivityIds, isNot(contains('/path')));
      expect(
        restored.favoriteActivityIds,
        isNot(contains('/study?mode=meaning')),
      );
      expect(restored.favoriteActivityIds.length, lessThanOrEqualTo(50));
      expect(restored.launchByActivityId.keys, {'/study?mode=production'});
      final launch = restored.launchFor('/study?mode=production');
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
  });
}
