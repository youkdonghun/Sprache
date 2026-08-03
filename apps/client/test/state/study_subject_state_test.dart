import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/import_distribution.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_subject.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test(
    'general subjects isolate their content, progress course, and selection',
    () async {
      final store = MemoryStudyStore();
      final controller = AppController(store);
      await Future<void>.delayed(Duration.zero);

      await controller.upsertStudySubject(
        StudySubject(
          id: 'general:baseball',
          kind: StudySubjectKind.general,
          name: '야구 용어',
          description: '기록과 규칙',
          symbol: '⚾',
          contentLanguage: LanguageTag.korean,
          updatedAt: DateTime.utc(2026, 7, 28),
        ),
      );
      await controller.upsertCustomItem(
        const LearningItem(
          id: 'baseball-whip',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.korean,
          subjectId: 'general:baseball',
          text: 'WHIP',
          translations: ['이닝당 출루 허용률'],
          acceptedAnswers: ['이닝당 출루 허용률'],
        ),
      );

      expect(controller.activeSubject.name, '야구 용어');
      expect(controller.state.activeSubjectId, 'general:baseball');
      expect(controller.state.activeCourseId, 'subject:general:baseball');
      expect(controller.courseItems.map((item) => item.id), ['baseball-whip']);

      controller.selectLanguage(LanguageTag.english);

      expect(controller.state.activeSubjectId, 'language:en');
      expect(controller.courseItems, isNotEmpty);
      expect(
        controller.courseItems.every(
          (item) => item.learningLanguage == LanguageTag.english,
        ),
        isTrue,
      );
    },
  );

  test(
    'selected material can move between subjects without losing its id',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      for (final subject in [
        const StudySubject(
          id: 'general:baseball',
          kind: StudySubjectKind.general,
          name: '야구',
          description: '',
          symbol: '⚾',
          contentLanguage: LanguageTag.korean,
        ),
        const StudySubject(
          id: 'general:idol',
          kind: StudySubjectKind.general,
          name: '아이돌',
          description: '',
          symbol: '🎤',
          contentLanguage: LanguageTag.korean,
        ),
      ]) {
        await controller.upsertStudySubject(subject);
      }
      controller.selectSubject('general:baseball');
      await controller.upsertCustomItem(
        const LearningItem(
          id: 'fan-term',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.korean,
          subjectId: 'general:baseball',
          text: '팬',
          translations: ['응원하는 사람'],
          acceptedAnswers: ['응원하는 사람'],
        ),
      );

      final moved = await controller.moveItemsToStudySubject({
        'fan-term',
      }, 'general:idol');

      expect(moved, 1);
      expect(controller.courseItems, isEmpty);
      controller.selectSubject('general:idol');
      expect(controller.courseItems.single.id, 'fan-term');
      expect(controller.courseItems.single.effectiveSubjectId, 'general:idol');
    },
  );

  test(
    'built-in subjects can be edited, hidden, restored, and reset safely',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);
      const item = LearningItem(
        id: 'office-hello',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'hello',
        translations: ['안녕하세요'],
        acceptedAnswers: ['안녕하세요'],
      );
      await controller.upsertCustomItem(item);

      await controller.upsertStudySubject(
        StudySubject.language(
          LanguageTag.english,
        ).copyWith(name: '업무 영어', description: '회사에서 바로 쓰는 영어', symbol: '💼'),
      );

      expect(controller.activeSubject.name, '업무 영어');
      expect(controller.hasStudySubjectOverride('language:en'), isTrue);

      await controller.hideStudySubject('language:en');

      expect(
        controller.availableSubjects.map((subject) => subject.id),
        isNot(contains('language:en')),
      );
      expect(
        controller.state.customItems
            .singleWhere((candidate) => candidate.id == item.id)
            .id,
        item.id,
      );

      await controller.restoreStudySubject('language:en');

      expect(controller.state.activeSubjectId, 'language:en');
      expect(controller.activeSubject.name, '업무 영어');

      await controller.resetStudySubjectOverride('language:en');

      expect(controller.hasStudySubjectOverride('language:en'), isFalse);
      expect(controller.activeSubject.name, '영어');
      expect(
        controller.state.customItems
            .singleWhere((candidate) => candidate.id == item.id)
            .text,
        item.text,
      );
    },
  );

  test(
    'distribution keys remember and update a subject and group route',
    () async {
      final controller = AppController(MemoryStudyStore());
      await Future<void>.delayed(Duration.zero);

      final first = await controller.upsertImportDistributionRule(
        key: ' Travel Core ',
        subjectId: 'language:en',
        groupName: '여행 준비',
      );
      final updated = await controller.upsertImportDistributionRule(
        key: 'travel-core',
        subjectId: 'language:ja',
        groupName: '다음 일본 여행',
      );

      expect(first.key, 'travel-core');
      expect(updated.createdAt, first.createdAt);
      expect(
        controller.state.preferences.importDistributionRules,
        hasLength(1),
      );
      expect(
        controller.importDistributionRuleFor('TRAVEL CORE'),
        isA<ImportDistributionRule>()
            .having((rule) => rule.subjectId, 'subjectId', 'language:ja')
            .having((rule) => rule.groupName, 'groupName', '다음 일본 여행'),
      );
    },
  );
}
