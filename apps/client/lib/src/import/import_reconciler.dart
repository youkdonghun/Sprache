import 'dart:convert';

import '../domain/content_validation.dart';
import '../domain/learning_item.dart';
import 'content_import_parser.dart';

enum ImportReviewStatus { newItem, unchanged, changed, blocked }

extension ImportReviewStatusLabel on ImportReviewStatus {
  String get label => switch (this) {
    ImportReviewStatus.newItem => '신규',
    ImportReviewStatus.unchanged => '동일',
    ImportReviewStatus.changed => '변경',
    ImportReviewStatus.blocked => '확인 필요',
  };
}

enum ImportMatchKind { id, semantic }

enum ImportReviewAction { add, replace, skip }

class ImportFieldDifference {
  const ImportFieldDifference({
    required this.field,
    required this.label,
    required this.existingValue,
    required this.incomingValue,
  });

  final String field;
  final String label;
  final String existingValue;
  final String incomingValue;
}

class ImportReviewEntry {
  const ImportReviewEntry({
    required this.row,
    required this.incoming,
    required this.status,
    required this.differences,
    this.existing,
    this.matchKind,
    this.blockReason,
    this.expectedExistingSignature,
  });

  final int row;
  final LearningItem incoming;
  final LearningItem? existing;
  final ImportReviewStatus status;
  final List<ImportFieldDifference> differences;
  final ImportMatchKind? matchKind;
  final String? blockReason;
  final String? expectedExistingSignature;

  String get reviewKey => '$row:${incoming.id}';

  bool get canReplace => status == ImportReviewStatus.changed;

  ImportReviewAction get defaultAction => switch (status) {
    ImportReviewStatus.newItem => ImportReviewAction.add,
    ImportReviewStatus.unchanged ||
    ImportReviewStatus.changed ||
    ImportReviewStatus.blocked => ImportReviewAction.skip,
  };

  ImportResolution resolve(ImportReviewAction action) {
    final safeAction = switch (action) {
      ImportReviewAction.replace when !canReplace => ImportReviewAction.skip,
      ImportReviewAction.add when status != ImportReviewStatus.newItem =>
        ImportReviewAction.skip,
      _ => action,
    };
    return ImportResolution(
      incoming: incoming,
      action: safeAction,
      expectedExistingId: existing?.id,
      expectedExistingSignature: expectedExistingSignature,
    );
  }
}

class ImportResolution {
  const ImportResolution({
    required this.incoming,
    required this.action,
    this.expectedExistingId,
    this.expectedExistingSignature,
  });

  final LearningItem incoming;
  final ImportReviewAction action;
  final String? expectedExistingId;
  final String? expectedExistingSignature;
}

class ImportReview {
  const ImportReview({
    required this.entries,
    required this.duplicates,
    required this.issues,
  });

  final List<ImportReviewEntry> entries;
  final List<ImportDuplicate> duplicates;
  final List<ImportIssue> issues;

  int count(ImportReviewStatus status) =>
      entries.where((entry) => entry.status == status).length;

  int get newCount => count(ImportReviewStatus.newItem);
  int get unchangedCount => count(ImportReviewStatus.unchanged);
  int get changedCount => count(ImportReviewStatus.changed);
  int get blockedCount => count(ImportReviewStatus.blocked);
}

class ImportReconciler {
  const ImportReconciler({this.validator = const LearningContentValidator()});

  final LearningContentValidator validator;

  ImportReview review({
    required ImportPreview preview,
    required Iterable<LearningItem> existingItems,
    required Set<String> replaceableItemIds,
  }) {
    final byId = <String, LearningItem>{};
    final byContentKey = <String, LearningItem>{};
    for (final item in existingItems) {
      byId.putIfAbsent(item.id, () => item);
      byContentKey.putIfAbsent(validator.duplicateKey(item), () => item);
    }

    final entries = <ImportReviewEntry>[];
    for (final parsed in preview.entries) {
      final incoming = parsed.item;
      final idMatch = byId[incoming.id];
      final semanticMatch = byContentKey[validator.duplicateKey(incoming)];
      if (idMatch != null &&
          semanticMatch != null &&
          idMatch.id != semanticMatch.id) {
        entries.add(
          ImportReviewEntry(
            row: parsed.row,
            incoming: incoming,
            existing: idMatch,
            status: ImportReviewStatus.blocked,
            differences: differences(idMatch, incoming),
            matchKind: ImportMatchKind.id,
            blockReason:
                '가져올 ID는 한 항목과 같지만 표현·뜻·품사는 다른 항목과 겹칩니다. ID를 수정한 뒤 다시 가져오세요.',
            expectedExistingSignature: signature(idMatch),
          ),
        );
        continue;
      }

      final existing = idMatch ?? semanticMatch;
      if (existing == null) {
        entries.add(
          ImportReviewEntry(
            row: parsed.row,
            incoming: incoming,
            status: ImportReviewStatus.newItem,
            differences: const [],
          ),
        );
        continue;
      }

      final fieldDifferences = differences(existing, incoming);
      final matchKind = idMatch != null
          ? ImportMatchKind.id
          : ImportMatchKind.semantic;
      if (fieldDifferences.isEmpty) {
        entries.add(
          ImportReviewEntry(
            row: parsed.row,
            incoming: incoming,
            existing: existing,
            status: ImportReviewStatus.unchanged,
            differences: const [],
            matchKind: matchKind,
            expectedExistingSignature: signature(existing),
          ),
        );
        continue;
      }
      if (!replaceableItemIds.contains(existing.id)) {
        entries.add(
          ImportReviewEntry(
            row: parsed.row,
            incoming: incoming,
            existing: existing,
            status: ImportReviewStatus.blocked,
            differences: fieldDifferences,
            matchKind: matchKind,
            blockReason:
                '앱에 포함된 기본 콘텐츠는 가져오기로 덮어쓸 수 없습니다. 다른 뜻이나 품사라면 ID와 핵심 필드를 구분하세요.',
            expectedExistingSignature: signature(existing),
          ),
        );
        continue;
      }
      entries.add(
        ImportReviewEntry(
          row: parsed.row,
          incoming: incoming,
          existing: existing,
          status: ImportReviewStatus.changed,
          differences: fieldDifferences,
          matchKind: matchKind,
          expectedExistingSignature: signature(existing),
        ),
      );
    }

    return ImportReview(
      entries: List.unmodifiable(entries),
      duplicates: preview.duplicates,
      issues: preview.issues,
    );
  }

  List<ImportFieldDifference> differences(
    LearningItem existing,
    LearningItem incoming,
  ) {
    final oldFields = _comparableFields(existing);
    final newFields = _comparableFields(incoming);
    final labels = _fieldLabels;
    return [
      for (final key in labels.keys)
        if (jsonEncode(oldFields[key]) != jsonEncode(newFields[key]))
          ImportFieldDifference(
            field: key,
            label: labels[key]!,
            existingValue: _display(oldFields[key]!),
            incomingValue: _display(newFields[key]!),
          ),
    ];
  }

  String signature(LearningItem item) => jsonEncode(_comparableFields(item));

  Map<String, Object?> _comparableFields(LearningItem item) => {
    'kind': item.kind.name,
    'language': item.learningLanguage.code,
    'text': item.text,
    'translations': item.translations,
    'acceptedAnswers': [...item.acceptedAnswers]..sort(),
    'readings': [
      for (final reading in item.readings)
        '${reading.scheme.name}:${reading.value}',
    ]..sort(),
    'sentenceTokens': item.sentenceTokens,
    'example': item.example ?? '',
    'exampleTranslation': item.exampleTranslation ?? '',
    'partOfSpeech': item.partOfSpeech?.name ?? '',
    'tags': [...item.tags]..sort(),
    'level': item.level,
    'capabilities': item.capabilities.map((value) => value.name).toList()
      ..sort(),
    'priority': item.priority,
    'sourceName': item.source.name,
    'license': item.source.license,
    'sourceVersion': item.source.sourceVersion,
  };

  String _display(Object? value) {
    if (value is List) {
      return value.isEmpty ? '—' : value.join(' · ');
    }
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return '—';
    return switch (text) {
      'word' => '단어',
      'sentence' => '문장',
      final String value
          when PartOfSpeech.values.any((part) => part.name == value) =>
        PartOfSpeech.values
            .firstWhere((part) => part.name == value)
            .koreanLabel,
      _ => text,
    };
  }
}

const _fieldLabels = <String, String>{
  'kind': '유형',
  'language': '언어',
  'text': '표현',
  'translations': '한국어 뜻',
  'acceptedAnswers': '허용 정답',
  'readings': '읽기',
  'sentenceTokens': '문장 토큰',
  'example': '예문',
  'exampleTranslation': '예문 뜻',
  'partOfSpeech': '품사',
  'tags': '태그',
  'level': '레벨',
  'capabilities': '학습 방식',
  'priority': '우선순위',
  'sourceName': '출처',
  'license': '라이선스',
  'sourceVersion': '원본 버전',
};
