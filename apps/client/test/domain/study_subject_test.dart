import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/study_subject.dart';

void main() {
  test('general study subjects survive JSON and use an isolated course id', () {
    final createdAt = DateTime.utc(2026, 7, 28, 10);
    final subject = StudySubject(
      id: 'general:baseball',
      kind: StudySubjectKind.general,
      name: '야구 용어',
      description: '규칙, 기록, 수비 위치를 외우는 주제',
      symbol: '⚾',
      contentLanguage: LanguageTag.korean,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final restored = StudySubject.fromJson(subject.toJson());

    expect(restored.id, 'general:baseball');
    expect(restored.kind, StudySubjectKind.general);
    expect(restored.name, '야구 용어');
    expect(restored.contentLanguage, LanguageTag.korean);
    expect(restored.courseId, 'subject:general:baseball');
    expect(restored.createdAt, createdAt);
  });

  test('six language subjects remain available and Korean is content-only', () {
    expect(builtInLanguageSubjects, hasLength(6));
    expect(
      builtInLanguageSubjects.map((subject) => subject.contentLanguage),
      isNot(contains(LanguageTag.korean)),
    );
    expect(LanguageTag.korean.available, isFalse);
    expect(
      StudySubject.language(LanguageTag.english).courseId,
      LanguageTag.english.courseId,
    );
    expect(
      languageSubjectId(LanguageTag.simplifiedChinese),
      'language:zh-hans',
    );
    expect(
      StudySubject.language(LanguageTag.simplifiedChinese).courseId,
      LanguageTag.simplifiedChinese.courseId,
    );
  });

  test('invalid subject identifiers and mismatched language subjects fail', () {
    expect(() => normalizeStudySubjectId('야구 용어'), throwsFormatException);
    expect(
      () => StudySubject.fromJson({
        'id': 'language:ja',
        'kind': 'language',
        'name': 'English',
        'description': '',
        'symbol': 'EN',
        'contentLanguage': 'en',
      }),
      throwsFormatException,
    );
  });

  test('course id validation accepts language and general subjects only', () {
    expect(isSupportedCourseId('ko-en'), isTrue);
    expect(isSupportedCourseId('subject:general:baseball'), isTrue);
    expect(isSupportedCourseId('subject:bad subject'), isFalse);
    expect(isSupportedCourseId('unknown-course'), isFalse);
  });
}
