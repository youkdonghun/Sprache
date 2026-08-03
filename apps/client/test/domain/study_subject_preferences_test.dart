import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/import_distribution.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_subject.dart';

void main() {
  test(
    'active subject and custom subjects survive a preferences round trip',
    () {
      final preferences = StudyPreferences(
        activeSubjectId: 'general:baseball',
        hiddenSubjectIds: const {'language:fr'},
        subjectVisibilityChangedAtById: {
          'language:fr': DateTime.utc(2026, 7, 28, 9),
        },
        importDistributionRules: [
          ImportDistributionRule(
            key: 'travel-core',
            subjectId: 'language:en',
            groupName: '여행 준비',
            createdAt: DateTime.utc(2026, 7, 28, 7),
            updatedAt: DateTime.utc(2026, 7, 28, 8),
          ),
        ],
        customSubjects: [
          StudySubject(
            id: 'general:baseball',
            kind: StudySubjectKind.general,
            name: '야구 용어',
            description: '야구 규칙과 기록',
            symbol: '⚾',
            contentLanguage: LanguageTag.korean,
            createdAt: DateTime.utc(2026, 7, 28, 7),
            updatedAt: DateTime.utc(2026, 7, 28, 8),
          ),
        ],
      );

      final restored = StudyPreferences.fromJson(preferences.toJson());

      expect(restored.activeSubjectId, 'general:baseball');
      expect(restored.hiddenSubjectIds, {'language:fr'});
      expect(
        restored.subjectVisibilityChangedAtById['language:fr'],
        DateTime.utc(2026, 7, 28, 9),
      );
      expect(restored.importDistributionRules.single.key, 'travel-core');
      expect(restored.importDistributionRules.single.groupName, '여행 준비');
      expect(restored.customSubjects.single.name, '야구 용어');
      expect(
        restored.customSubjects.single.contentLanguage,
        LanguageTag.korean,
      );
    },
  );

  test('built-in overrides load while malformed subjects are ignored', () {
    final restored = StudyPreferences.fromJson({
      'activeSubjectId': 'INVALID SUBJECT',
      'customSubjects': [
        {
          'id': 'general:idol',
          'kind': 'general',
          'name': '아이돌 용어',
          'description': '',
          'symbol': '🎤',
          'contentLanguage': 'ko',
        },
        {
          'id': 'language:en',
          'kind': 'language',
          'name': '영어',
          'description': '',
          'symbol': 'EN',
          'contentLanguage': 'en',
        },
        {'id': 'bad id'},
      ],
    });

    expect(restored.activeSubjectId, isEmpty);
    expect(restored.customSubjects, hasLength(2));
    expect(
      restored.customSubjects.map((subject) => subject.id),
      containsAll(['general:idol', 'language:en']),
    );
    expect(
      restored.customSubjects
          .singleWhere((subject) => subject.id == 'language:en')
          .name,
      '영어',
    );
  });
}
