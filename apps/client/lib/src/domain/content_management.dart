enum ImportChangeKind { added, replaced, merged, skipped }

class TrashBatch {
  const TrashBatch({
    required this.id,
    required this.entries,
    required this.createdAt,
  });

  final String id;
  final List<TrashEntry> entries;
  final DateTime createdAt;
}

class ImportUndoResult {
  const ImportUndoResult({
    required this.restored,
    required this.removed,
    required this.skippedConflicts,
  });

  final int restored;
  final int removed;
  final int skippedConflicts;
}

class ImportUndoConflict {
  const ImportUndoConflict({
    required this.itemId,
    required this.current,
    required this.imported,
    required this.before,
  });

  final String itemId;
  final Map<String, Object?>? current;
  final Map<String, Object?>? imported;
  final Map<String, Object?>? before;
}

class ImportUndoPreview {
  const ImportUndoPreview({
    required this.safeChangeCount,
    required this.conflicts,
  });

  final int safeChangeCount;
  final List<ImportUndoConflict> conflicts;

  bool get hasConflicts => conflicts.isNotEmpty;
}

class ImportBatchChange {
  const ImportBatchChange({
    required this.itemId,
    required this.kind,
    this.before,
    this.after,
  });

  final String itemId;
  final ImportChangeKind kind;
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;

  Map<String, Object?> toJson() => {
    'itemId': itemId,
    'kind': kind.name,
    if (before != null) 'before': before,
    if (after != null) 'after': after,
  };

  factory ImportBatchChange.fromJson(Map<String, Object?> json) {
    final itemId = json['itemId'];
    if (itemId is! String || itemId.trim().isEmpty) {
      throw const FormatException('가져오기 변경 항목 ID가 필요합니다.');
    }
    return ImportBatchChange(
      itemId: itemId,
      kind: ImportChangeKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => ImportChangeKind.skipped,
      ),
      before: _optionalMap(json['before']),
      after: _optionalMap(json['after']),
    );
  }
}

class ImportReceiptDestination {
  const ImportReceiptDestination({
    required this.subjectId,
    required this.distributionKey,
    required this.itemCount,
  });

  final String subjectId;
  final String distributionKey;
  final int itemCount;

  Map<String, Object?> toJson() => {
    'subjectId': subjectId,
    if (distributionKey.isNotEmpty) 'distributionKey': distributionKey,
    'itemCount': itemCount,
  };

  factory ImportReceiptDestination.fromJson(Map<String, Object?> json) {
    final subjectId = json['subjectId'];
    final distributionKey = json['distributionKey'];
    final itemCount = _count(json['itemCount']);
    if (subjectId is! String ||
        subjectId.trim().isEmpty ||
        (distributionKey != null && distributionKey is! String) ||
        itemCount <= 0) {
      throw const FormatException('가져오기 대상 정보가 올바르지 않습니다.');
    }
    return ImportReceiptDestination(
      subjectId: subjectId,
      distributionKey: distributionKey as String? ?? '',
      itemCount: itemCount,
    );
  }
}

class ImportBatchReceipt {
  const ImportBatchReceipt({
    required this.importId,
    required this.fileName,
    required this.subjectId,
    required this.distributionKey,
    required this.addedCount,
    required this.mergedCount,
    required this.skippedCount,
    required this.errorCount,
    required this.changes,
    required this.createdAt,
    this.destinations = const [],
    this.undoneAt,
  });

  final String importId;
  final String fileName;
  final String subjectId;
  final String distributionKey;
  final int addedCount;
  final int mergedCount;
  final int skippedCount;
  final int errorCount;
  final List<ImportBatchChange> changes;
  final DateTime createdAt;
  final List<ImportReceiptDestination> destinations;
  final DateTime? undoneAt;

  bool get canUndo => undoneAt == null && changes.isNotEmpty;

  ImportBatchReceipt markUndone(DateTime at) => ImportBatchReceipt(
    importId: importId,
    fileName: fileName,
    subjectId: subjectId,
    distributionKey: distributionKey,
    addedCount: addedCount,
    mergedCount: mergedCount,
    skippedCount: skippedCount,
    errorCount: errorCount,
    changes: changes,
    createdAt: createdAt,
    destinations: destinations,
    undoneAt: at.toUtc(),
  );

  Map<String, Object?> toJson() => {
    'importId': importId,
    'fileName': fileName,
    'subjectId': subjectId,
    'distributionKey': distributionKey,
    'addedCount': addedCount,
    'mergedCount': mergedCount,
    'skippedCount': skippedCount,
    'errorCount': errorCount,
    'changes': [for (final change in changes) change.toJson()],
    if (destinations.isNotEmpty)
      'destinations': [
        for (final destination in destinations) destination.toJson(),
      ],
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (undoneAt != null) 'undoneAt': undoneAt!.toUtc().toIso8601String(),
  };

  factory ImportBatchReceipt.fromJson(Map<String, Object?> json) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final importId = json['importId'];
    final fileName = json['fileName'];
    final subjectId = json['subjectId'];
    if (createdAt == null ||
        importId is! String ||
        importId.trim().isEmpty ||
        fileName is! String ||
        subjectId is! String ||
        subjectId.trim().isEmpty) {
      throw const FormatException('가져오기 영수증이 올바르지 않습니다.');
    }
    return ImportBatchReceipt(
      importId: importId,
      fileName: fileName,
      subjectId: subjectId,
      distributionKey: json['distributionKey'] as String? ?? '',
      addedCount: _count(json['addedCount']),
      mergedCount: _count(json['mergedCount']),
      skippedCount: _count(json['skippedCount']),
      errorCount: _count(json['errorCount']),
      changes: [
        for (final raw in (json['changes'] as List<Object?>? ?? const []).take(
          20000,
        ))
          if (raw is Map)
            ImportBatchChange.fromJson(Map<String, Object?>.from(raw)),
      ],
      destinations: [
        for (final raw
            in (json['destinations'] as List<Object?>? ?? const []).take(200))
          if (raw is Map)
            ImportReceiptDestination.fromJson(Map<String, Object?>.from(raw)),
      ],
      createdAt: createdAt.toUtc(),
      undoneAt: switch (json['undoneAt']) {
        final String value => DateTime.tryParse(value)?.toUtc(),
        _ => null,
      },
    );
  }
}

class ImportMappingPreset {
  const ImportMappingPreset({
    required this.id,
    required this.name,
    required this.columns,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final Map<String, String> columns;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'columns': columns,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory ImportMappingPreset.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        updatedAt == null) {
      throw const FormatException('가져오기 매핑 프리셋이 올바르지 않습니다.');
    }
    final columns = <String, String>{};
    final rawColumns = json['columns'];
    if (rawColumns is Map) {
      for (final entry in rawColumns.entries.take(64)) {
        if (entry.key is String && entry.value is String) {
          columns[entry.key as String] = entry.value as String;
        }
      }
    }
    return ImportMappingPreset(
      id: id,
      name: name,
      columns: Map.unmodifiable(columns),
      updatedAt: updatedAt.toUtc(),
    );
  }
}

class TrashEntry {
  const TrashEntry({
    required this.entryId,
    required this.itemId,
    required this.subjectId,
    required this.item,
    required this.wasFavorite,
    required this.wasExcluded,
    required this.deletedAt,
  });

  final String entryId;
  final String itemId;
  final String subjectId;
  final Map<String, Object?> item;
  final bool wasFavorite;
  final bool wasExcluded;
  final DateTime deletedAt;

  Map<String, Object?> toJson() => {
    'entryId': entryId,
    'itemId': itemId,
    'subjectId': subjectId,
    'item': item,
    'wasFavorite': wasFavorite,
    'wasExcluded': wasExcluded,
    'deletedAt': deletedAt.toUtc().toIso8601String(),
  };

  factory TrashEntry.fromJson(Map<String, Object?> json) {
    final entryId = json['entryId'];
    final itemId = json['itemId'];
    final subjectId = json['subjectId'];
    final deletedAt = DateTime.tryParse(json['deletedAt'] as String? ?? '');
    final item = _optionalMap(json['item']);
    if (entryId is! String ||
        entryId.trim().isEmpty ||
        itemId is! String ||
        itemId.trim().isEmpty ||
        subjectId is! String ||
        subjectId.trim().isEmpty ||
        deletedAt == null ||
        item == null) {
      throw const FormatException('휴지통 항목이 올바르지 않습니다.');
    }
    return TrashEntry(
      entryId: entryId,
      itemId: itemId,
      subjectId: subjectId,
      item: item,
      wasFavorite: json['wasFavorite'] == true,
      wasExcluded: json['wasExcluded'] == true,
      deletedAt: deletedAt.toUtc(),
    );
  }
}

class ContentCorrection {
  const ContentCorrection({
    required this.itemId,
    required this.field,
    required this.note,
    this.proposedValue,
    required this.updatedAt,
    this.resolved = false,
  });

  final String itemId;
  final String field;
  final String note;
  final String? proposedValue;
  final DateTime updatedAt;
  final bool resolved;

  Map<String, Object?> toJson() => {
    'itemId': itemId,
    'field': field,
    'note': note,
    if (proposedValue != null) 'proposedValue': proposedValue,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'resolved': resolved,
  };

  factory ContentCorrection.fromJson(Map<String, Object?> json) {
    final itemId = json['itemId'];
    final field = json['field'];
    final note = json['note'];
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    if (itemId is! String ||
        itemId.trim().isEmpty ||
        field is! String ||
        field.trim().isEmpty ||
        note is! String ||
        note.trim().isEmpty ||
        updatedAt == null) {
      throw const FormatException('콘텐츠 교정 메모가 올바르지 않습니다.');
    }
    return ContentCorrection(
      itemId: itemId,
      field: field,
      note: note,
      proposedValue: json['proposedValue'] as String?,
      updatedAt: updatedAt.toUtc(),
      resolved: json['resolved'] == true,
    );
  }
}

Map<String, Object?>? _optionalMap(Object? raw) {
  return raw is Map ? Map<String, Object?>.from(raw) : null;
}

int _count(Object? raw) =>
    (raw is num && raw.isFinite ? raw.toInt() : 0).clamp(0, 20000);
