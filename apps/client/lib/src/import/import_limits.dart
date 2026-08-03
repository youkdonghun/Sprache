import '../domain/dataset_capacity.dart';

class ImportLimitException extends FormatException {
  const ImportLimitException(super.message);
}

class ImportLimits {
  const ImportLimits({
    this.maxFileBytes = 20 * 1024 * 1024,
    this.maxTextCharacters = 20 * 1024 * 1024,
    this.maxRows = 20000,
    this.maxColumns = 64,
    this.maxCellCharacters = 20000,
    this.maxGeneratedItems = DatasetCapacityPolicy.maxCustomItems,
    this.maxDatasetItems = DatasetCapacityPolicy.maxCustomItems,
  });

  final int maxFileBytes;
  final int maxTextCharacters;
  final int maxRows;
  final int maxColumns;
  final int maxCellCharacters;
  final int maxGeneratedItems;
  final int maxDatasetItems;

  String get userSummary =>
      '최대 ${_formatNumber(maxFileBytes ~/ (1024 * 1024))}MB · '
      '${_formatNumber(maxRows)}행 · ${_formatNumber(maxColumns)}열 · '
      '생성 항목 ${_formatNumber(maxGeneratedItems)}개';

  void ensureFileSize(int byteLength) {
    if (byteLength <= maxFileBytes) return;
    throw ImportLimitException(
      '파일이 ${_formatNumber(maxFileBytes ~/ (1024 * 1024))}MB 제한을 넘었습니다. '
      '파일을 나누어 다시 가져와 주세요.',
    );
  }

  void ensureTextLength(int characterLength) {
    if (characterLength <= maxTextCharacters) return;
    throw ImportLimitException(
      '텍스트가 ${_formatNumber(maxTextCharacters)}자 제한을 넘었습니다. '
      '파일을 나누어 다시 가져와 주세요.',
    );
  }

  void ensureRowCount(int rowCount) {
    if (rowCount <= maxRows) return;
    throw ImportLimitException(
      '학습 행이 ${_formatNumber(maxRows)}행 제한을 넘었습니다. '
      '여러 파일로 나누어 순서대로 가져와 주세요.',
    );
  }

  void ensureColumnCount(int columnCount) {
    if (columnCount <= maxColumns) return;
    throw ImportLimitException(
      '열이 ${_formatNumber(maxColumns)}열 제한을 넘었습니다. '
      '사용하지 않는 열을 지우고 다시 가져와 주세요.',
    );
  }

  void ensureCellLength(int characterLength, {int? row, String? field}) {
    if (characterLength <= maxCellCharacters) return;
    final location = [
      if (row != null) '$row행',
      if (field != null && field.trim().isNotEmpty) field.trim(),
    ].join(' ');
    throw ImportLimitException(
      '${location.isEmpty ? '한 셀' : location}의 내용이 '
      '${_formatNumber(maxCellCharacters)}자 제한을 넘었습니다. '
      '내용을 줄이거나 여러 항목으로 나누어 주세요.',
    );
  }

  void ensureGeneratedItemCount(int itemCount) {
    if (itemCount <= maxGeneratedItems) return;
    throw ImportLimitException(
      '단어와 자동 생성 예문이 합계 ${_formatNumber(maxGeneratedItems)}개 제한을 넘었습니다. '
      '예문 수를 줄이거나 파일을 나누어 다시 가져와 주세요.',
    );
  }

  void ensureDatasetItemCount(int itemCount) {
    if (itemCount <= maxDatasetItems) return;
    throw ImportLimitException(
      '저장 후 사용자 자료가 ${_formatNumber(maxDatasetItems)}개 제한을 넘습니다. '
      '기존 자료를 정리하거나 가져올 파일을 나누어 주세요.',
    );
  }

  void ensureMapCells(Map<String, Object?> row, {required int rowNumber}) {
    ensureColumnCount(row.length);
    for (final entry in row.entries) {
      ensureCellLength(
        _valueLength(entry.value),
        row: rowNumber,
        field: entry.key,
      );
    }
  }

  int _valueLength(Object? value) {
    return switch (value) {
      null => 0,
      final String text => text.length,
      final Iterable<Object?> values => values.fold(
        0,
        (length, item) => length + _valueLength(item),
      ),
      final Map<Object?, Object?> values => values.entries.fold(
        0,
        (length, entry) =>
            length + entry.key.toString().length + _valueLength(entry.value),
      ),
      _ => value.toString().length,
    };
  }

  static String _formatNumber(int value) {
    final source = value.toString();
    final output = StringBuffer();
    for (var index = 0; index < source.length; index++) {
      if (index > 0 && (source.length - index) % 3 == 0) output.write(',');
      output.write(source[index]);
    }
    return output.toString();
  }
}
