import 'package:csv/csv.dart';

import 'import_reconciler.dart';

enum ImportReportCode {
  duplicateId,
  duplicateSemantic,
  idConflict,
  protectedBaseContent,
  invalidRow,
}

extension ImportReportCodeValue on ImportReportCode {
  String get value => switch (this) {
    ImportReportCode.duplicateId => 'IMP_DUPLICATE_ID',
    ImportReportCode.duplicateSemantic => 'IMP_DUPLICATE_SEMANTIC',
    ImportReportCode.idConflict => 'IMP_ID_CONFLICT',
    ImportReportCode.protectedBaseContent => 'IMP_PROTECTED_BASE',
    ImportReportCode.invalidRow => 'IMP_INVALID_ROW',
  };
}

/// Creates a privacy-safe local report. Item text and source rows are excluded
/// by default so the file can be shared with support without exposing study
/// content.
class ImportReportExporter {
  const ImportReportExporter();

  String buildCsv(ImportReview review, {bool includeOriginal = false}) {
    final rows = <List<Object?>>[
      const ['row', 'severity', 'error_code', 'recommended_action', 'original'],
      for (final duplicate in review.duplicates)
        [
          duplicate.row,
          'error',
          (duplicate.kind.name == 'id'
                  ? ImportReportCode.duplicateId
                  : ImportReportCode.duplicateSemantic)
              .value,
          '중복 행을 합치거나 고유 ID를 사용하세요.',
          includeOriginal ? duplicate.item.text : '',
        ],
      for (final issue in review.issues)
        [
          issue.row,
          'error',
          ImportReportCode.invalidRow.value,
          '해당 행의 필수 필드와 형식을 확인하세요.',
          includeOriginal ? issue.message : '',
        ],
      for (final entry in review.entries)
        if (entry.status == ImportReviewStatus.blocked)
          [
            entry.row,
            'error',
            (entry.blockReason?.contains('기본 콘텐츠') ?? false)
                ? ImportReportCode.protectedBaseContent.value
                : ImportReportCode.idConflict.value,
            '검토 화면에서 문제·뜻·ID를 수정한 뒤 다시 검증하세요.',
            includeOriginal ? entry.incoming.text : '',
          ],
    ];
    return Csv(addBom: true).encode(rows);
  }
}
