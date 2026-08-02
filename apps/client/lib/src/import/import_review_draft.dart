enum ImportDraftDecision { add, replace, skip }

class ImportReviewDraft {
  const ImportReviewDraft({
    required this.fileSha256,
    required this.updatedAt,
    this.extension,
    this.columnMapping = const {},
    this.decisions = const {},
    this.encodingName,
    this.delimiterName,
    this.sheetName,
    this.destinationSubjectId,
    this.distributionKey,
    this.distributionGroup,
  });

  final String fileSha256;
  final DateTime updatedAt;
  final String? extension;
  final Map<String, String> columnMapping;
  final Map<String, ImportDraftDecision> decisions;
  final String? encodingName;
  final String? delimiterName;
  final String? sheetName;
  final String? destinationSubjectId;
  final String? distributionKey;
  final String? distributionGroup;

  Map<String, Object?> toJson() => {
    'version': 1,
    'fileSha256': fileSha256,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (extension != null) 'extension': extension,
    'columnMapping': columnMapping,
    'decisions': {
      for (final entry in decisions.entries) entry.key: entry.value.name,
    },
    if (encodingName != null) 'encodingName': encodingName,
    if (delimiterName != null) 'delimiterName': delimiterName,
    if (sheetName != null) 'sheetName': sheetName,
    if (destinationSubjectId != null)
      'destinationSubjectId': destinationSubjectId,
    if (distributionKey != null) 'distributionKey': distributionKey,
    if (distributionGroup != null) 'distributionGroup': distributionGroup,
  };

  factory ImportReviewDraft.fromJson(Map<String, Object?> json) {
    final hash = _text(json['fileSha256'], max: 64);
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (json['version'] != 1 ||
        hash == null ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash) ||
        updatedAt == null) {
      throw const FormatException('가져오기 검토 초안이 올바르지 않습니다.');
    }
    final mapping = <String, String>{};
    if (json['columnMapping'] case final Map<Object?, Object?> raw) {
      for (final entry in raw.entries.take(50)) {
        final key = _text(entry.key, max: 80);
        final value = _text(entry.value, max: 160);
        if (key != null && value != null) mapping[key] = value;
      }
    }
    final decisions = <String, ImportDraftDecision>{};
    if (json['decisions'] case final Map<Object?, Object?> raw) {
      for (final entry in raw.entries.take(20000)) {
        final key = _text(entry.key, max: 240);
        if (key == null) continue;
        final decision = ImportDraftDecision.values
            .where((value) => value.name == entry.value)
            .firstOrNull;
        if (decision != null) decisions[key] = decision;
      }
    }
    return ImportReviewDraft(
      fileSha256: hash.toLowerCase(),
      updatedAt: updatedAt.toUtc(),
      extension: _text(json['extension'], max: 12),
      columnMapping: Map.unmodifiable(mapping),
      decisions: Map.unmodifiable(decisions),
      encodingName: _text(json['encodingName'], max: 40),
      delimiterName: _text(json['delimiterName'], max: 40),
      sheetName: _text(json['sheetName'], max: 160),
      destinationSubjectId: _text(json['destinationSubjectId'], max: 160),
      distributionKey: _text(json['distributionKey'], max: 120),
      distributionGroup: _text(json['distributionGroup'], max: 160),
    );
  }
}

String? _text(Object? value, {required int max}) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed.runes.length > max) return null;
  return trimmed;
}
