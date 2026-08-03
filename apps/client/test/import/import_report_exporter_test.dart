import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/import/import_reconciler.dart';
import 'package:sprache/src/import/import_report_exporter.dart';

void main() {
  test('privacy-safe report uses stable codes and omits original content', () {
    const secret = '절대 보고서에 넣지 않을 원문';
    final item = LearningItem(
      id: 'private-item',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.english,
      text: secret,
      translations: const ['비밀 뜻'],
      acceptedAnswers: const ['비밀 뜻'],
    );
    final review = ImportReview(
      entries: [
        ImportReviewEntry(
          row: 3,
          incoming: item,
          status: ImportReviewStatus.blocked,
          differences: const [],
          blockReason: '앱에 포함된 기본 콘텐츠는 덮어쓸 수 없습니다.',
        ),
      ],
      duplicates: [
        ImportDuplicate(
          row: 4,
          firstRow: 2,
          item: item,
          kind: ImportDuplicateKind.semantic,
        ),
      ],
      issues: const [ImportIssue(row: 5, message: '민감한 원문 오류')],
    );

    final report = const ImportReportExporter().buildCsv(review);

    expect(report, contains('IMP_PROTECTED_BASE'));
    expect(report, contains('IMP_DUPLICATE_SEMANTIC'));
    expect(report, contains('IMP_INVALID_ROW'));
    expect(report, isNot(contains(secret)));
    expect(report, isNot(contains('민감한 원문 오류')));
  });
}
