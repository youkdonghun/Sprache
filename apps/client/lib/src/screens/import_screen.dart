import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/study_store.dart';
import '../domain/content_management.dart';
import '../domain/content_validation.dart';
import '../domain/import_distribution.dart';
import '../domain/language.dart';
import '../domain/learning_group.dart';
import '../domain/learning_item.dart';
import '../domain/study_subject.dart';
import '../import/content_import_parser.dart';
import '../import/bulk_paste_parser.dart';
import '../import/import_column_mapping.dart';
import '../import/import_limits.dart';
import '../import/import_report_exporter.dart';
import '../import/import_reconciler.dart';
import '../import/import_review_draft.dart';
import '../import/template_file_name.dart';
import '../import/text_import_decoder.dart';
import '../import/xlsx_import_reader.dart';
import '../services/clipboard_read_session.dart';
import '../services/recovery_checkpoint_service.dart';
import '../state/app_state.dart';
import '../state/connection_state.dart';
import '../state/local_storage_state.dart';
import '../state/navigation_guard_state.dart';
import '../state/pending_import_state.dart';
import '../theme/app_theme.dart';

final recoveryCheckpointServiceProvider = Provider<RecoveryCheckpointService>(
  (ref) => RecoveryCheckpointService(),
);

enum _ReviewFilter { all, selected, changed, problems }

typedef _ParsedImportFile = ({ImportPreview preview, String sha256});
typedef _ImportParseRequest = ({
  List<int> bytes,
  String? extension,
  String defaultLanguageCode,
  String? defaultSubjectId,
  String? distributionKey,
  String? distributionGroup,
  String? routeSubjectId,
  String? routeLanguageCode,
  Map<String, String> subjectIdByDistributionKey,
  Map<String, String> groupByDistributionKey,
  Map<String, String> languageCodeByDistributionKey,
  Map<String, String> columnMapping,
  String? textEncodingName,
  String? delimiterName,
  String? sheetName,
});

typedef _TabularInspectionRequest = ({
  List<int> bytes,
  String extension,
  String? textEncodingName,
  String? delimiterName,
  String? sheetName,
});

typedef _ExcelSheetInspection = ({
  String name,
  List<String> headers,
  List<List<String>> samples,
});

typedef _TabularInspection = ({
  List<String> headers,
  List<List<String>> samples,
  List<_ExcelSheetInspection> sheets,
  String? encodingName,
  String? delimiterName,
  bool hadBom,
});

_TabularInspection _inspectTabular(_TabularInspectionRequest request) {
  const mapper = ImportColumnMapper();
  if (request.extension == 'xlsx') {
    final sheets = const XlsxImportReader().read(request.bytes);
    final inspected = <_ExcelSheetInspection>[];
    for (final sheet in sheets) {
      final headerIndex = mapper.findExcelHeaderIndex(sheet.rows);
      if (headerIndex < 0) continue;
      inspected.add((
        name: sheet.name,
        headers: sheet.rows[headerIndex].values
            .map((value) => value.trim().replaceFirst('\uFEFF', ''))
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
        samples: sheet.rows
            .skip(headerIndex + 1)
            .where((row) => row.values.any((value) => value.trim().isNotEmpty))
            .take(3)
            .map((row) => row.values.take(6).toList(growable: false))
            .toList(growable: false),
      ));
    }
    final selected = inspected.where(
      (sheet) => request.sheetName == null || sheet.name == request.sheetName,
    );
    final active = selected.isEmpty ? null : selected.first;
    return (
      headers: active?.headers ?? const [],
      samples: active?.samples ?? const [],
      sheets: inspected,
      encodingName: null,
      delimiterName: null,
      hadBom: false,
    );
  }
  final encoding = TextImportEncoding.values.firstWhere(
    (value) => value.name == request.textEncodingName,
    orElse: () => TextImportEncoding.auto,
  );
  final delimiter = TextImportDelimiter.values.firstWhere(
    (value) => value.name == request.delimiterName,
    orElse: () => TextImportDelimiter.auto,
  );
  final inspection = const TextImportDecoder().inspect(
    request.bytes,
    encoding: encoding,
    delimiter: delimiter,
  );
  return (
    headers: inspection.headers,
    samples: inspection.samples,
    sheets: const [],
    encodingName: inspection.encoding.name,
    delimiterName: inspection.delimiter.name,
    hadBom: inspection.hadBom,
  );
}

_ParsedImportFile _parseImportBytes(_ImportParseRequest request) {
  const parser = ContentImportParser();
  parser.validateFileSize(request.bytes.length);
  final defaultLanguage = LanguageTag.values.firstWhere(
    (language) => language.code == request.defaultLanguageCode,
  );
  final preview = switch (request.extension) {
    'xlsx' => parser.parseExcel(
      request.bytes,
      defaultLanguage: defaultLanguage,
      sheetName: request.sheetName,
      defaultSubjectId: request.defaultSubjectId,
      distributionKey: request.distributionKey,
      distributionGroup: request.distributionGroup,
      routeSubjectId: request.routeSubjectId,
      routeLanguageCode: request.routeLanguageCode,
      subjectIdByDistributionKey: request.subjectIdByDistributionKey,
      groupByDistributionKey: request.groupByDistributionKey,
      languageCodeByDistributionKey: request.languageCodeByDistributionKey,
      columnMapping: request.columnMapping,
    ),
    'csv' || 'tsv' => parser.parseCsv(
      const TextImportDecoder()
          .inspect(
            request.bytes,
            encoding: TextImportEncoding.values.firstWhere(
              (value) => value.name == request.textEncodingName,
              orElse: () => TextImportEncoding.auto,
            ),
            delimiter: TextImportDelimiter.values.firstWhere(
              (value) => value.name == request.delimiterName,
              orElse: () => TextImportDelimiter.auto,
            ),
          )
          .text,
      defaultLanguage: defaultLanguage,
      delimiter: TextImportDelimiter.values
          .firstWhere(
            (value) => value.name == request.delimiterName,
            orElse: () => TextImportDelimiter.auto,
          )
          .value,
      defaultSubjectId: request.defaultSubjectId,
      distributionKey: request.distributionKey,
      distributionGroup: request.distributionGroup,
      routeSubjectId: request.routeSubjectId,
      routeLanguageCode: request.routeLanguageCode,
      subjectIdByDistributionKey: request.subjectIdByDistributionKey,
      groupByDistributionKey: request.groupByDistributionKey,
      languageCodeByDistributionKey: request.languageCodeByDistributionKey,
      columnMapping: request.columnMapping,
    ),
    'json' => parser.parseJson(
      utf8.decode(request.bytes, allowMalformed: false),
      defaultLanguage: defaultLanguage,
      defaultSubjectId: request.defaultSubjectId,
      distributionKey: request.distributionKey,
      distributionGroup: request.distributionGroup,
      routeSubjectId: request.routeSubjectId,
      routeLanguageCode: request.routeLanguageCode,
      subjectIdByDistributionKey: request.subjectIdByDistributionKey,
      groupByDistributionKey: request.groupByDistributionKey,
      languageCodeByDistributionKey: request.languageCodeByDistributionKey,
    ),
    'jsonl' => parser.parseJsonLines(
      utf8.decode(request.bytes, allowMalformed: false),
      defaultLanguage: defaultLanguage,
      defaultSubjectId: request.defaultSubjectId,
      distributionKey: request.distributionKey,
      distributionGroup: request.distributionGroup,
      routeSubjectId: request.routeSubjectId,
      routeLanguageCode: request.routeLanguageCode,
      subjectIdByDistributionKey: request.subjectIdByDistributionKey,
      groupByDistributionKey: request.groupByDistributionKey,
      languageCodeByDistributionKey: request.languageCodeByDistributionKey,
    ),
    _ => throw const FormatException('지원하지 않는 파일 형식입니다.'),
  };
  return (preview: preview, sha256: sha256.convert(request.bytes).toString());
}

class _ImportDestination {
  const _ImportDestination({
    required this.subjectId,
    required this.subjectName,
    required this.subjectSymbol,
    required this.groupLabel,
    required this.openGroup,
    required this.distributionKey,
    required this.count,
  });

  final String subjectId;
  final String subjectName;
  final String subjectSymbol;
  final String groupLabel;
  final String? openGroup;
  final String? distributionKey;
  final int count;

  _ImportDestination withCount(int value) => _ImportDestination(
    subjectId: subjectId,
    subjectName: subjectName,
    subjectSymbol: subjectSymbol,
    groupLabel: groupLabel,
    openGroup: openGroup,
    distributionKey: distributionKey,
    count: value,
  );
}

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({
    super.key,
    this.initialPreview,
    this.initialFileName,
    this.initialSha256,
    this.initialPreviousImport,
  });

  final ImportPreview? initialPreview;
  final String? initialFileName;
  final String? initialSha256;
  final ImportCommitRecord? initialPreviousImport;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _decisions = <String, ImportReviewAction>{};
  final _distributionKeyController = TextEditingController();
  final _distributionGroupController = TextEditingController();
  ImportPreview? _preview;
  ImportCommitRecord? _previousImport;
  String? _fileName;
  String? _fileSha256;
  String? _routeSubjectId;
  Map<String, String> _columnMapping = const {};
  String? _sourceExtension;
  String? _textEncodingName;
  String? _delimiterName;
  String? _sheetName;
  String? _sourceSummary;
  _ReviewFilter _filter = _ReviewFilter.all;
  int _visibleLimit = 50;
  bool _busy = false;
  String? _busyMessage;
  bool _committed = false;
  Future<void> _draftWriteTail = Future.value();
  late final NavigationGuardController _navigationGuard;

  @override
  void initState() {
    super.initState();
    _preview = widget.initialPreview;
    _fileName = widget.initialFileName;
    _fileSha256 = widget.initialSha256;
    _previousImport = widget.initialPreviousImport;
    _navigationGuard = ref.read(navigationGuardProvider)
      ..register(this, _confirmLeave);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_consumeDroppedFile());
    });
  }

  Future<void> _consumeDroppedFile() async {
    final pending = ref.read(pendingImportFileProvider);
    if (pending == null || !mounted) return;
    ref.read(pendingImportFileProvider.notifier).state = null;
    final dot = pending.name.lastIndexOf('.');
    await _loadFileBytes(
      fileName: pending.name,
      extension: dot < 0 ? null : pending.name.substring(dot + 1).toLowerCase(),
      bytes: pending.bytes,
    );
  }

  @override
  void dispose() {
    _navigationGuard.unregister(this);
    _distributionKeyController.dispose();
    _distributionGroupController.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (_committed || (_preview == null && !_busy)) return true;
    if (_busy) {
      _showMessage('안전 저장이 끝날 때까지 잠시 기다려 주세요.');
      return false;
    }
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: const Key('import-draft-exit-dialog'),
            title: const Text('가져오기 미리보기를 닫을까요?'),
            content: const Text(
              '파일 원문 없이 해시·열 배치·선택·목적지만 이 기기의 검토 초안에 보관합니다. '
              '기존 학습 자료는 바뀌지 않습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('계속 검토'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('미리보기 닫기'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _requestSystemBack() async {
    if (await _confirmLeave() && mounted) context.go('/library');
  }

  void _invalidatePreviewForRoutingChange() {
    if (_preview == null) return;
    setState(() {
      _preview = null;
      _committed = false;
      _previousImport = null;
      _fileName = null;
      _fileSha256 = null;
      _columnMapping = const {};
      _sourceExtension = null;
      _textEncodingName = null;
      _delimiterName = null;
      _sheetName = null;
      _sourceSummary = null;
      _decisions.clear();
      _filter = _ReviewFilter.all;
      _visibleLimit = 50;
    });
    final previousDraftWrite = _draftWriteTail;
    _draftWriteTail = () async {
      try {
        await previousDraftWrite;
      } on Object {
        // A later clear still wins over a failed draft write.
      }
      try {
        await ref.read(studyStoreProvider).clearImportReviewDraft();
      } on Object {
        // Draft cleanup must not change the already safe learning dataset.
      }
    }();
    _showMessage('분배 위치가 바뀌었습니다. 파일을 다시 선택해 새 기준으로 검증해 주세요.');
  }

  void _loadDistributionRule(String value) {
    _invalidatePreviewForRoutingChange();
    final trimmed = value.trim();
    ImportDistributionRoute? route;
    try {
      if (trimmed.isNotEmpty) {
        final controller = ref.read(appControllerProvider.notifier);
        route = resolveImportDistributionRoute(
          trimmed,
          savedRules: ref
              .read(appControllerProvider)
              .preferences
              .importDistributionRules,
          subjects: controller.allSubjects,
        );
      }
    } on FormatException {
      // Partial typing is allowed; validation happens when the file is chosen.
    }
    setState(() {
      _routeSubjectId = route?.subjectId;
      _distributionGroupController.text = route?.groupName ?? '';
    });
  }

  Future<void> _pickFile() async {
    if (_busy) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv', 'tsv', 'json', 'jsonl'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _showMessage('파일을 읽을 수 없습니다.');
      return;
    }
    await _loadFileBytes(
      fileName: file.name,
      extension: file.extension?.toLowerCase(),
      bytes: bytes,
    );
  }

  Future<void> _loadFileBytes({
    required String fileName,
    required String? extension,
    required List<int> bytes,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyMessage = '파일을 백그라운드에서 검증하고 있습니다…';
    });
    try {
      final appController = ref.read(appControllerProvider.notifier);
      final activeSubject = appController.activeSubject;
      final sourceHash = sha256.convert(bytes).toString();
      final storedDraft = await ref
          .read(studyStoreProvider)
          .loadImportReviewDraft();
      if (!mounted) return;
      final matchingDraft = storedDraft?.fileSha256 == sourceHash
          ? storedDraft
          : null;
      final rawDistributionKey = _distributionKeyController.text.trim();
      var distributionKey = rawDistributionKey.isEmpty
          ? matchingDraft?.distributionKey
          : normalizeImportDistributionKey(rawDistributionKey);
      final hasUiDistributionKey = distributionKey != null;
      final routeSubjectId =
          _routeSubjectId ??
          matchingDraft?.destinationSubjectId ??
          activeSubject.id;
      var routeSubject = appController.allSubjects.firstWhere(
        (subject) => subject.id == routeSubjectId,
        orElse: () => activeSubject,
      );
      var distributionGroup = _distributionGroupController.text.trim();
      if (distributionGroup.isEmpty) {
        distributionGroup = matchingDraft?.distributionGroup ?? '';
      }
      final subjectsById = {
        for (final subject in appController.allSubjects) subject.id: subject,
      };
      final savedRules = ref
          .read(appControllerProvider)
          .preferences
          .importDistributionRules;
      final subjectIdByDistributionKey = {
        for (final route in fallbackImportDistributionRoutes)
          route.key: route.subjectId,
        for (final rule in savedRules) rule.key: rule.subjectId,
      };
      final groupByDistributionKey = <String, String>{};
      for (final rule in savedRules) {
        final groupName = rule.groupName;
        if (groupName != null) {
          groupByDistributionKey[rule.key] = groupName;
        }
      }
      final languageCodeByDistributionKey = <String, String>{};
      for (final route in fallbackImportDistributionRoutes) {
        languageCodeByDistributionKey[route.key] = route.languageCode;
      }
      for (final rule in savedRules) {
        final subject = subjectsById[rule.subjectId];
        if (subject != null) {
          languageCodeByDistributionKey[rule.key] =
              subject.contentLanguage.code;
        }
      }
      var columnMapping = const <String, String>{};
      String? textEncodingName;
      String? delimiterName;
      String? sheetName;
      String? sourceSummary;
      if (extension == 'xlsx' || extension == 'csv' || extension == 'tsv') {
        var inspection = await compute(_inspectTabular, (
          bytes: bytes,
          extension: extension!,
          textEncodingName: null,
          delimiterName: extension == 'tsv'
              ? TextImportDelimiter.tab.name
              : null,
          sheetName: null,
        ));
        if (!mounted) return;
        if (extension == 'xlsx') {
          if (inspection.sheets.isEmpty) {
            throw const FormatException('문제와 정답이 있는 Excel 시트를 찾지 못했습니다.');
          }
          sheetName = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                _ExcelSheetSelectionDialog(sheets: inspection.sheets),
          );
          if (sheetName == null) return;
          inspection = await compute(_inspectTabular, (
            bytes: bytes,
            extension: extension,
            textEncodingName: null,
            delimiterName: null,
            sheetName: sheetName,
          ));
          sourceSummary = 'Excel · $sheetName 시트';
        } else {
          final selection = await showDialog<_TextImportSelection>(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                _TextImportOptionsDialog(inspection: inspection),
          );
          if (selection == null) return;
          textEncodingName = selection.encoding.name;
          delimiterName = selection.delimiter.name;
          inspection = await compute(_inspectTabular, (
            bytes: bytes,
            extension: extension,
            textEncodingName: textEncodingName,
            delimiterName: delimiterName,
            sheetName: null,
          ));
          sourceSummary =
              '${selection.encoding.label} · ${selection.delimiter.label}'
              '${inspection.hadBom ? ' · BOM 확인' : ''}';
        }
        final headers = inspection.headers;
        if (headers.length < 2) {
          throw const FormatException('문제와 정답이 있는 헤더 행을 찾지 못했습니다.');
        }
        if (!mounted) return;
        final savedMapping = matchingDraft?.columnMapping ?? const {};
        final savedMappingFits =
            savedMapping.isNotEmpty &&
            savedMapping.values.every(headers.contains);
        final suggested = savedMappingFits
            ? savedMapping
            : const ImportColumnMapper().suggest(headers);
        final selected = await showDialog<_ImportColumnMappingSelection>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _ImportColumnMappingDialog(
            headers: headers,
            suggested: suggested,
            presets: appController.importMappingPresets,
          ),
        );
        if (selected == null) return;
        columnMapping = selected.mapping;
        if (selected.presetName case final presetName?) {
          final now = DateTime.now().toUtc();
          await appController.upsertImportMappingPreset(
            ImportMappingPreset(
              id: 'mapping-${now.microsecondsSinceEpoch}',
              name: presetName,
              columns: columnMapping,
              updatedAt: now,
            ),
          );
        }
      }
      final _ImportParseRequest parseRequest = (
        bytes: bytes,
        extension: extension,
        defaultLanguageCode: routeSubject.contentLanguage.code,
        defaultSubjectId: routeSubject.isLanguage ? null : routeSubject.id,
        distributionKey: distributionKey,
        distributionGroup: distributionGroup.isEmpty ? null : distributionGroup,
        routeSubjectId: distributionKey == null ? null : routeSubject.id,
        routeLanguageCode: distributionKey == null
            ? null
            : routeSubject.contentLanguage.code,
        subjectIdByDistributionKey: subjectIdByDistributionKey,
        groupByDistributionKey: groupByDistributionKey,
        languageCodeByDistributionKey: languageCodeByDistributionKey,
        columnMapping: columnMapping,
        textEncodingName: textEncodingName,
        delimiterName: delimiterName,
        sheetName: sheetName,
      );
      final parsed = await compute(_parseImportBytes, parseRequest);
      final embeddedKeys = parsed.preview.items
          .map(importDistributionKeyOf)
          .whereType<String>()
          .toSet();
      if (!hasUiDistributionKey && embeddedKeys.isNotEmpty) {
        final inferredRules =
            <({String key, String subjectId, String? groupName})>[];
        for (final embeddedKey in embeddedKeys) {
          if (resolveImportDistributionRoute(
                embeddedKey,
                savedRules: savedRules,
                subjects: appController.allSubjects,
              ) !=
              null) {
            continue;
          }
          final keyedItems = parsed.preview.items
              .where((item) => importDistributionKeyOf(item) == embeddedKey)
              .toList(growable: false);
          final subjectIds = keyedItems
              .map((item) => item.effectiveSubjectId)
              .toSet();
          if (subjectIds.length != 1) {
            throw FormatException(
              '분배 키 "$embeddedKey"가 여러 학습 대상에 연결되어 있습니다. '
              '같은 키의 subject_id를 하나로 맞춰 주세요.',
            );
          }
          final groupNames = keyedItems
              .expand((item) => learningGroupsOf(item))
              .toSet();
          inferredRules.add((
            key: embeddedKey,
            subjectId: subjectIds.single,
            groupName: groupNames.length == 1 ? groupNames.single : null,
          ));
        }
        for (final rule in inferredRules) {
          await appController.upsertImportDistributionRule(
            key: rule.key,
            subjectId: rule.subjectId,
            groupName: rule.groupName,
          );
        }
        if (embeddedKeys.length == 1) {
          final embeddedKey = embeddedKeys.single;
          distributionKey = embeddedKey;
          final resolvedRoute = resolveImportDistributionRoute(
            embeddedKey,
            savedRules: ref
                .read(appControllerProvider)
                .preferences
                .importDistributionRules,
            subjects: appController.allSubjects,
          );
          if (resolvedRoute != null) {
            routeSubject = appController.allSubjects.firstWhere(
              (subject) => subject.id == resolvedRoute.subjectId,
              orElse: () => routeSubject,
            );
            distributionGroup = resolvedRoute.groupName ?? '';
          }
        }
      }
      if (hasUiDistributionKey && distributionKey != null) {
        await appController.upsertImportDistributionRule(
          key: distributionKey,
          subjectId: routeSubject.id,
          groupName: distributionGroup.isEmpty ? null : distributionGroup,
        );
      }
      final previousImport = await ref
          .read(appControllerProvider.notifier)
          .previousImportBySha256(parsed.sha256);
      if (!mounted) return;
      setState(() {
        if (distributionKey != null) {
          _distributionKeyController.text = distributionKey;
          _routeSubjectId = routeSubject.id;
          _distributionGroupController.text = distributionGroup;
        }
        _preview = parsed.preview;
        _committed = false;
        _fileName = fileName;
        _fileSha256 = parsed.sha256;
        _previousImport = previousImport;
        _columnMapping = columnMapping;
        _sourceExtension = extension;
        _textEncodingName = textEncodingName;
        _delimiterName = delimiterName;
        _sheetName = sheetName;
        _sourceSummary = matchingDraft == null
            ? sourceSummary
            : '${sourceSummary ?? '검증 완료'} · 이전 검토 선택 복원';
        _decisions
          ..clear()
          ..addAll({
            for (final entry
                in matchingDraft == null
                    ? const <MapEntry<String, ImportDraftDecision>>[]
                    : matchingDraft.decisions.entries)
              entry.key: switch (entry.value) {
                ImportDraftDecision.add => ImportReviewAction.add,
                ImportDraftDecision.replace => ImportReviewAction.replace,
                ImportDraftDecision.skip => ImportReviewAction.skip,
              },
          });
        _filter = _ReviewFilter.all;
        _visibleLimit = 50;
      });
      _saveReviewDraft();
    } on FormatException catch (error) {
      _showMessage(error.message.toString());
    } catch (_) {
      _showMessage('파일을 분석하지 못했습니다. 파일 형식과 접근 권한을 확인해 주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _openBulkPaste() async {
    if (_busy) return;
    final input = await showDialog<String>(
      context: context,
      builder: (context) => const _BulkPasteDialog(),
    );
    if (input == null || !mounted) return;
    late final BulkPasteResult quick;
    try {
      quick = const BulkPasteParser().parse(input);
    } on FormatException catch (error) {
      _showMessage(error.message.toString());
      return;
    }
    if (!quick.canImport) {
      _showMessage(
        quick.issues.isEmpty ? '가져올 문제와 정답이 없습니다.' : quick.issues.first.message,
      );
      return;
    }
    setState(() {
      _busy = true;
      _busyMessage = '붙여넣은 ${quick.entryCount}개 행을 검증하고 있습니다…';
    });
    try {
      final controller = ref.read(appControllerProvider.notifier);
      final activeSubject = controller.activeSubject;
      final subjectId = _routeSubjectId ?? activeSubject.id;
      final subject = controller.allSubjects.firstWhere(
        (value) => value.id == subjectId,
        orElse: () => activeSubject,
      );
      final rawKey = _distributionKeyController.text.trim();
      final distributionKey = rawKey.isEmpty
          ? null
          : normalizeImportDistributionKey(rawKey);
      final group = _distributionGroupController.text.trim();
      if (distributionKey != null) {
        await controller.upsertImportDistributionRule(
          key: distributionKey,
          subjectId: subject.id,
          groupName: group.isEmpty ? null : group,
        );
      }
      final bytes = utf8.encode(quick.csvText);
      final parseRequest = (
        bytes: bytes,
        extension: 'csv',
        defaultLanguageCode: subject.contentLanguage.code,
        defaultSubjectId: subject.isLanguage ? null : subject.id,
        distributionKey: distributionKey,
        distributionGroup: group.isEmpty ? null : group,
        routeSubjectId: distributionKey == null ? null : subject.id,
        routeLanguageCode: distributionKey == null
            ? null
            : subject.contentLanguage.code,
        subjectIdByDistributionKey: const <String, String>{},
        groupByDistributionKey: const <String, String>{},
        languageCodeByDistributionKey: const <String, String>{},
        columnMapping: const <String, String>{
          'term': 'term',
          'meaning': 'meaning',
        },
        textEncodingName: TextImportEncoding.utf8.name,
        delimiterName: TextImportDelimiter.comma.name,
        sheetName: null,
      );
      final parsed = await compute(_parseImportBytes, parseRequest);
      final now = DateTime.now();
      final fileName =
          '붙여넣기-${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}-'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}.csv';
      final previous = await controller.previousImportBySha256(parsed.sha256);
      if (!mounted) return;
      setState(() {
        _preview = ImportPreview(
          entries: parsed.preview.entries,
          issues: [
            ...parsed.preview.issues,
            for (final issue in quick.issues)
              ImportIssue(row: issue.line, message: issue.message),
          ],
          duplicates: parsed.preview.duplicates,
          notices: parsed.preview.notices,
        );
        _committed = false;
        _fileName = fileName;
        _fileSha256 = parsed.sha256;
        _previousImport = previous;
        _columnMapping = const {'term': 'term', 'meaning': 'meaning'};
        _sourceSummary = 'UTF-8 · 쉼표 (붙여넣기)';
        _decisions.clear();
        _filter = _ReviewFilter.all;
        _visibleLimit = 50;
      });
    } on FormatException catch (error) {
      _showMessage(error.message.toString());
    } catch (_) {
      _showMessage('붙여넣은 내용을 분석하지 못했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _saveTemplate({
    required String assetFileName,
    required String suggestedFileName,
    required String templateLabel,
  }) async {
    try {
      final data = await rootBundle.load('assets/templates/$assetFileName');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Sprache $templateLabel 저장',
        fileName: suggestedFileName,
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        bytes: bytes,
      );
      if (path != null) _showMessage('$templateLabel을 저장했습니다.');
    } catch (_) {
      _showMessage('$templateLabel을 저장하지 못했습니다. 저장 위치 권한을 확인해 주세요.');
    }
  }

  Future<void> _exportImportReport(ImportReview review) async {
    try {
      final csvText = const ImportReportExporter().buildCsv(review);
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}-'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '개인정보 안전 가져오기 보고서 저장',
        fileName: 'sprache-import-report-$stamp.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: Uint8List.fromList(utf8.encode(csvText)),
      );
      if (path != null) {
        _showMessage('원문을 제외한 가져오기 보고서를 저장했습니다.');
      }
    } catch (_) {
      _showMessage('가져오기 보고서를 저장하지 못했습니다.');
    }
  }

  Future<void> _editBlockedEntry(ImportReviewEntry entry) async {
    final edited = await showDialog<_BlockedEntryEdit>(
      context: context,
      builder: (context) => _BlockedEntryEditDialog(entry: entry),
    );
    if (edited == null || !mounted) return;
    try {
      final oldMeaning = entry.incoming.primaryTranslation;
      final translations = <String>{
        edited.meaning,
        ...entry.incoming.translations.where((value) => value != oldMeaning),
      }.toList(growable: false);
      final answers = <String>{
        edited.meaning,
        ...entry.incoming.acceptedAnswers.where((value) => value != oldMeaning),
      }.toList(growable: false);
      final candidate = const LearningContentValidator().ensureValid(
        entry.incoming.copyWith(
          id: edited.id,
          text: edited.text,
          translations: translations,
          acceptedAnswers: answers,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      final preview = _preview;
      if (preview == null) return;
      setState(() {
        _preview = ImportPreview(
          entries: [
            for (final parsed in preview.entries)
              if (parsed.row == entry.row &&
                  parsed.item.id == entry.incoming.id)
                ParsedImportEntry(row: parsed.row, item: candidate)
              else
                parsed,
          ],
          issues: preview.issues,
          duplicates: preview.duplicates,
          notices: preview.notices,
        );
        _committed = false;
        _decisions.remove(entry.reviewKey);
      });
      _showMessage('${entry.row}행을 다시 검증했습니다.');
    } on FormatException catch (error) {
      _showMessage(error.message.toString());
    }
  }

  Future<void> _loadBundledWebPack({
    required String fileName,
    required String busyMessage,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyMessage = busyMessage;
    });
    try {
      final content = await rootBundle.loadString('assets/content/$fileName');
      final bytes = utf8.encode(content);
      final language = ref
          .read(appControllerProvider.notifier)
          .activeSubject
          .contentLanguage;
      final _ImportParseRequest parseRequest = (
        bytes: bytes,
        extension: 'json',
        defaultLanguageCode: language.code,
        defaultSubjectId: null,
        distributionKey: null,
        distributionGroup: null,
        routeSubjectId: null,
        routeLanguageCode: null,
        subjectIdByDistributionKey: const <String, String>{},
        groupByDistributionKey: const <String, String>{},
        languageCodeByDistributionKey: const <String, String>{},
        columnMapping: const <String, String>{},
        textEncodingName: null,
        delimiterName: null,
        sheetName: null,
      );
      final parsed = await compute(_parseImportBytes, parseRequest);
      final previousImport = await ref
          .read(appControllerProvider.notifier)
          .previousImportBySha256(parsed.sha256);
      if (!mounted) return;
      setState(() {
        _preview = parsed.preview;
        _committed = false;
        _fileName = fileName;
        _fileSha256 = parsed.sha256;
        _previousImport = previousImport;
        _sourceSummary = null;
        _decisions.clear();
        _filter = _ReviewFilter.all;
        _visibleLimit = 50;
      });
    } on FormatException catch (error) {
      _showMessage(error.message.toString());
    } catch (_) {
      _showMessage('검증된 웹 예문 팩을 열지 못했습니다. 앱 파일을 다시 설치해 주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<void> _loadBundledTopicPack({
    required String subjectId,
    required String subjectName,
    required String symbol,
    required String description,
    required String fileName,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyMessage = '$subjectName 학습 팩을 준비하고 있습니다…';
    });
    try {
      final controller = ref.read(appControllerProvider.notifier);
      final exists = controller.availableSubjects.any(
        (subject) => subject.id == subjectId,
      );
      if (!exists) {
        await controller.upsertStudySubject(
          StudySubject(
            id: subjectId,
            kind: StudySubjectKind.general,
            name: subjectName,
            description: description,
            symbol: symbol,
            contentLanguage: LanguageTag.korean,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      } else {
        controller.selectSubject(subjectId);
      }
      final content = await rootBundle.loadString('assets/content/$fileName');
      final bytes = utf8.encode(content);
      final _ImportParseRequest parseRequest = (
        bytes: bytes,
        extension: 'json',
        defaultLanguageCode: LanguageTag.korean.code,
        defaultSubjectId: subjectId,
        distributionKey: null,
        distributionGroup: null,
        routeSubjectId: null,
        routeLanguageCode: null,
        subjectIdByDistributionKey: const <String, String>{},
        groupByDistributionKey: const <String, String>{},
        languageCodeByDistributionKey: const <String, String>{},
        columnMapping: const <String, String>{},
        textEncodingName: null,
        delimiterName: null,
        sheetName: null,
      );
      final parsed = await compute(_parseImportBytes, parseRequest);
      final previousImport = await controller.previousImportBySha256(
        parsed.sha256,
      );
      if (!mounted) return;
      setState(() {
        _preview = parsed.preview;
        _committed = false;
        _fileName = fileName;
        _fileSha256 = parsed.sha256;
        _previousImport = previousImport;
        _sourceSummary = null;
        _decisions.clear();
        _filter = _ReviewFilter.all;
        _visibleLimit = 50;
      });
    } on FormatException catch (error) {
      _showMessage(error.message.toString());
    } catch (_) {
      _showMessage('샘플 팩을 열지 못했습니다. 앱 파일을 다시 설치해 주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  ImportReviewAction _actionFor(ImportReviewEntry entry) {
    return entry
        .resolve(_decisions[entry.reviewKey] ?? entry.defaultAction)
        .action;
  }

  void _saveReviewDraft() {
    final hash = _fileSha256;
    if (hash == null || _preview == null || _committed) return;
    final draft = ImportReviewDraft(
      fileSha256: hash,
      updatedAt: DateTime.now().toUtc(),
      extension: _sourceExtension,
      columnMapping: Map.unmodifiable(_columnMapping),
      decisions: {
        for (final entry in _decisions.entries)
          entry.key: switch (entry.value) {
            ImportReviewAction.add => ImportDraftDecision.add,
            ImportReviewAction.replace => ImportDraftDecision.replace,
            ImportReviewAction.skip => ImportDraftDecision.skip,
          },
      },
      encodingName: _textEncodingName,
      delimiterName: _delimiterName,
      sheetName: _sheetName,
      destinationSubjectId: _routeSubjectId,
      distributionKey: _distributionKeyController.text.trim().isEmpty
          ? null
          : _distributionKeyController.text.trim(),
      distributionGroup: _distributionGroupController.text.trim().isEmpty
          ? null
          : _distributionGroupController.text.trim(),
    );
    final previousDraftWrite = _draftWriteTail;
    _draftWriteTail = () async {
      try {
        await previousDraftWrite;
      } on Object {
        // The latest valid review state should still get a chance to persist.
      }
      try {
        await ref.read(studyStoreProvider).saveImportReviewDraft(draft);
      } on Object {
        // The preview remains usable in memory when local draft storage fails.
      }
    }();
  }

  void _setAction(ImportReviewEntry entry, ImportReviewAction action) {
    setState(() => _decisions[entry.reviewKey] = entry.resolve(action).action);
    _saveReviewDraft();
  }

  void _setBulkAction(
    ImportReview review,
    ImportReviewStatus status,
    ImportReviewAction action,
  ) {
    setState(() {
      for (final entry in review.entries.where(
        (entry) => entry.status == status,
      )) {
        _decisions[entry.reviewKey] = entry.resolve(action).action;
      }
    });
    _saveReviewDraft();
  }

  List<_ImportDestination> _destinationsFor(
    ImportReview review,
    AppController controller,
  ) {
    final subjectsById = {
      for (final subject in controller.allSubjects) subject.id: subject,
    };
    final destinations = <String, _ImportDestination>{};
    final counts = <String, int>{};
    for (final entry in review.entries) {
      if (_actionFor(entry) == ImportReviewAction.skip) continue;
      final item = entry.incoming;
      final subjectId = item.effectiveSubjectId;
      final subject = subjectsById[subjectId];
      final distributionKey = importDistributionKeyOf(item);
      final groups = learningGroupsOf(item).toList()..sort();
      final routedGroup = distributionKey == null
          ? null
          : controller.importDistributionRuleFor(distributionKey)?.groupName;
      final openGroup =
          routedGroup ?? (groups.length == 1 ? groups.single : null);
      final groupLabel = groups.isEmpty ? '그룹 없음' : groups.join(' · ');
      final mapKey = jsonEncode([subjectId, groupLabel, distributionKey ?? '']);
      destinations.putIfAbsent(
        mapKey,
        () => _ImportDestination(
          subjectId: subjectId,
          subjectName: subject?.name ?? subjectId,
          subjectSymbol: subject?.symbol ?? '📚',
          groupLabel: groupLabel,
          openGroup: openGroup,
          distributionKey: distributionKey,
          count: 0,
        ),
      );
      counts[mapKey] = (counts[mapKey] ?? 0) + 1;
    }
    final result =
        [
          for (final entry in destinations.entries)
            entry.value.withCount(counts[entry.key] ?? 0),
        ]..sort((left, right) {
          final subjectOrder = left.subjectName.compareTo(right.subjectName);
          if (subjectOrder != 0) return subjectOrder;
          final groupOrder = left.groupLabel.compareTo(right.groupLabel);
          if (groupOrder != 0) return groupOrder;
          return (left.distributionKey ?? '').compareTo(
            right.distributionKey ?? '',
          );
        });
    return result;
  }

  Future<void> _import(
    ImportReview review,
    List<_ImportDestination> destinations,
  ) async {
    final preview = _preview;
    final fileName = _fileName;
    final fileSha256 = _fileSha256;
    if (preview == null || fileName == null || fileSha256 == null || _busy) {
      return;
    }
    final resolutions = [
      for (final entry in review.entries) entry.resolve(_actionFor(entry)),
    ];
    if (!resolutions.any(
      (resolution) => resolution.action != ImportReviewAction.skip,
    )) {
      return;
    }

    setState(() {
      _busy = true;
      _busyMessage = '1/4 · 가져오기 전 안전 지점을 검증하고 있습니다…';
    });
    ImportCommitResult? committedResult;
    try {
      await ref
          .read(recoveryCheckpointServiceProvider)
          .create(
            ref.read(appControllerProvider.notifier).exportArchive(),
            reason: RecoveryCheckpointReason.bulkImport,
          );
      if (!mounted) return;
      setState(() {
        _busyMessage = '2/4 · 전체 항목을 앱 DB에 원자적으로 저장하고 있습니다…';
      });
      final result = await ref
          .read(appControllerProvider.notifier)
          .importResolvedItems(
            resolutions,
            fileName: fileName,
            sha256: fileSha256,
            rejectedRows: preview.issues.length + preview.duplicates.length,
          );
      committedResult = result;
      _committed = true;
      try {
        await _draftWriteTail;
      } on Object {
        // Commit succeeded; clear any older draft even if a write failed.
      }
      try {
        await ref.read(studyStoreProvider).clearImportReviewDraft();
      } on Object {
        // Imported content is already committed; stale metadata is harmless.
      }
      if (!mounted) return;
      var storageText = ' · 앱 데이터에 병합됨';
      if (result.added + result.replaced > 0) {
        if (ref.read(appControllerProvider).driveConnected) {
          setState(() {
            _busyMessage = '3/4 · Drive의 기존 데이터와 키별로 병합하고 있습니다…';
          });
          await ref.read(connectionControllerProvider.notifier).syncOrRestore();
          if (!mounted) return;
          final connection = ref.read(connectionControllerProvider);
          storageText = connection.phase == ConnectionPhase.connected
              ? ' · Drive 기존 데이터셋 업데이트 완료'
              : ' · 로컬 병합 완료 · Drive 재시도 대기';
        } else {
          setState(() {
            _busyMessage = '3/4 · 지정한 로컬 저장본을 업데이트하고 있습니다…';
          });
          await ref.read(localStorageControllerProvider.notifier).saveNow();
          if (!mounted) return;
          final localStorage = ref.read(localStorageControllerProvider);
          storageText = localStorage.configured
              ? ' · 로컬 저장본 업데이트 완료'
              : ' · 앱 DB에 저장됨';
        }
      }
      setState(() {
        _busyMessage = '4/4 · 저장 결과와 이동할 자료실을 확인하고 있습니다…';
      });
      final staleText = result.stale == 0 ? '' : ' · 재검토 필요 ${result.stale}개';
      _showMessage(
        '신규 ${result.added}개 · 교체 ${result.replaced}개 · 제외 ${result.skipped}개$staleText$storageText',
      );
      if (destinations.length == 1) {
        _openDestination(destinations.single);
        return;
      }
      if (destinations.length > 1) {
        final destination = await _showDestinationResult(destinations);
        if (!mounted) return;
        if (destination != null) {
          _openDestination(destination);
        } else {
          context.go('/library');
        }
        return;
      }
      context.go('/library');
    } on ImportLimitException catch (error) {
      if (!mounted) return;
      _showMessage(error.message.toString());
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        committedResult == null
            ? '안전 지점을 만들거나 앱 DB에 저장하지 못했습니다. 기존 학습 데이터는 변경되지 않았습니다. 저장 공간을 확인한 뒤 다시 시도해 주세요.'
            : '앱 DB 저장은 완료했지만 외부 저장본을 갱신하지 못했습니다. 가져온 자료는 이 기기에 유지되며 설정에서 동기화·로컬 저장을 다시 시도할 수 있습니다.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyMessage = null;
        });
      }
    }
  }

  Future<_ImportDestination?> _showDestinationResult(
    List<_ImportDestination> destinations,
  ) {
    return showDialog<_ImportDestination>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SimpleDialog(
        key: const Key('import-destination-result-dialog'),
        title: const Text('가져온 자료를 어디에서 볼까요?'),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text('목적지별 자료 수를 확인하고 바로 해당 자료실을 열 수 있습니다.'),
          ),
          for (final (index, destination) in destinations.indexed)
            SimpleDialogOption(
              key: Key('open-import-destination-$index'),
              onPressed: () => Navigator.pop(dialogContext, destination),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  destination.subjectSymbol,
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(
                  '${destination.subjectName} > ${destination.groupLabel}',
                ),
                subtitle: Text(
                  '${destination.distributionKey == null ? '분배 키 없음' : '키 ${destination.distributionKey}'}'
                  ' · ${destination.count}개',
                ),
                trailing: const Icon(Icons.arrow_forward_rounded),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('현재 자료실로 이동'),
            ),
          ),
        ],
      ),
    );
  }

  void _openDestination(_ImportDestination destination) {
    ref
        .read(appControllerProvider.notifier)
        .selectSubject(destination.subjectId);
    final queryParameters = {
      'subject': destination.subjectId,
      'imported': 'true',
    };
    final group = destination.openGroup;
    if (group != null) {
      queryParameters['group'] = group;
    }
    final uri = Uri(path: '/library', queryParameters: queryParameters);
    context.go(uri.toString());
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _undoImport(ImportBatchReceipt receipt) async {
    final controller = ref.read(appControllerProvider.notifier);
    final preview = controller.previewImportUndo(receipt.importId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('가져오기 되돌리기'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '“${receipt.fileName}”에서 추가 ${receipt.addedCount}개, '
                '병합·교체 ${receipt.mergedCount}개를 되돌립니다.',
              ),
              const SizedBox(height: 10),
              Text('안전하게 되돌릴 변경 ${preview.safeChangeCount}개'),
              if (preview.hasConflicts) ...[
                const SizedBox(height: 10),
                Text(
                  '가져온 뒤 수정되었거나 삭제된 ${preview.conflicts.length}개는 '
                  '덮어쓰지 않습니다. 아래 비교를 확인한 뒤 계속하세요.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final conflict in preview.conflicts.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_undoConflictLabel(conflict)),
                  ),
                if (preview.conflicts.length > 5)
                  Text('외 ${preview.conflicts.length - 5}개 충돌'),
              ] else
                const Text('가져온 뒤 직접 수정된 자료가 없어 모두 안전하게 되돌릴 수 있습니다.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('confirm-import-undo'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('되돌리기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await controller.undoImport(receipt.importId);
    if (!mounted) return;
    _showMessage(
      '추가 자료 삭제 ${result.removed}개 · 이전 내용 복원 ${result.restored}개'
      '${result.skippedConflicts == 0 ? '' : ' · 직접 수정 보호 ${result.skippedConflicts}개'}',
    );
  }

  String _undoConflictLabel(ImportUndoConflict conflict) {
    String label(Map<String, Object?>? value, String fallback) {
      if (value == null) return fallback;
      final text = value['text'];
      final translations = value['translations'];
      final meaning = translations is List && translations.isNotEmpty
          ? ' → ${translations.first}'
          : '';
      return text is String && text.trim().isNotEmpty
          ? '${text.trim()}$meaning'
          : fallback;
    }

    return '• 가져오기 직후: '
        '${label(conflict.imported, conflict.itemId)}\n'
        '  현재: ${label(conflict.current, '삭제됨')}';
  }

  Future<void> _deleteMappingPreset(ImportMappingPreset preset) async {
    await ref
        .read(appControllerProvider.notifier)
        .deleteImportMappingPreset(preset.id);
    if (mounted) _showMessage('“${preset.name}” 열 연결을 삭제했습니다.');
  }

  List<ImportReviewEntry> _filteredEntries(ImportReview review) {
    return review.entries
        .where((entry) {
          return switch (_filter) {
            _ReviewFilter.all => true,
            _ReviewFilter.selected =>
              _actionFor(entry) != ImportReviewAction.skip,
            _ReviewFilter.changed => entry.status == ImportReviewStatus.changed,
            _ReviewFilter.problems =>
              entry.status == ImportReviewStatus.blocked,
          };
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PendingImportFile?>(pendingImportFileProvider, (previous, next) {
      if (next == null || identical(previous, next)) return;
      unawaited(
        Future<void>.microtask(() async {
          if (mounted) await _consumeDroppedFile();
        }),
      );
    });
    final preview = _preview;
    final appState = ref.watch(appControllerProvider);
    final controller = ref.read(appControllerProvider.notifier);
    final activeSubject = controller.activeSubject;
    final availableSubjects = controller.availableSubjects;
    final receipts = controller.importReceipts.take(5).toList(growable: false);
    final mappingPresets = controller.importMappingPresets;
    final routeSubjectId =
        availableSubjects.any(
          (subject) => subject.id == (_routeSubjectId ?? activeSubject.id),
        )
        ? (_routeSubjectId ?? activeSubject.id)
        : activeSubject.id;
    final routeGroups =
        appState.preferences.learningGroups
            .where((group) => group.subjectId == routeSubjectId)
            .map((group) => group.name)
            .toSet()
            .toList()
          ..sort();
    final review = preview == null ? null : controller.reviewImport(preview);
    final notices = preview?.notices ?? const <ImportNotice>[];
    final selectedCount =
        review?.entries
            .where((entry) => _actionFor(entry) != ImportReviewAction.skip)
            .length ??
        0;
    final destinations = review == null
        ? const <_ImportDestination>[]
        : _destinationsFor(review, controller);
    final filtered = review == null
        ? const <ImportReviewEntry>[]
        : _filteredEntries(review);
    final visible = filtered.take(_visibleLimit).toList(growable: false);

    return PopScope(
      canPop: _committed || (_preview == null && !_busy),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestSystemBack());
      },
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PageHeader(
                      subjectName: activeSubject.name,
                      subjectSymbol: activeSubject.symbol,
                      generalTopic: !activeSubject.isLanguage,
                    ),
                    const SizedBox(height: 20),
                    _ImportRoutingCard(
                      keyController: _distributionKeyController,
                      groupController: _distributionGroupController,
                      subjects: availableSubjects,
                      selectedSubjectId: routeSubjectId,
                      groupSuggestions: routeGroups,
                      driveConnected: appState.driveConnected,
                      enabled: !_busy,
                      onKeyChanged: _loadDistributionRule,
                      onSubjectChanged: (subjectId) {
                        _invalidatePreviewForRoutingChange();
                        setState(() => _routeSubjectId = subjectId);
                      },
                      onGroupChanged: (_) =>
                          _invalidatePreviewForRoutingChange(),
                    ),
                    const SizedBox(height: 12),
                    _UploadCard(
                      fileName: _fileName,
                      busyMessage: _busyMessage,
                      onPickFile: _busy ? null : _pickFile,
                      onPaste: _busy ? null : _openBulkPaste,
                      onSaveEasyTemplate: _busy
                          ? null
                          : () => _saveTemplate(
                              assetFileName:
                                  'Sprache-easy-import-template.xlsx',
                              suggestedFileName: buildUploadTemplateFileName(
                                DateTime.now(),
                              ),
                              templateLabel: '간편 엑셀 템플릿',
                            ),
                      onSaveFullTemplate: _busy
                          ? null
                          : () => _saveTemplate(
                              assetFileName:
                                  'Sprache-word-import-template.xlsx',
                              suggestedFileName:
                                  'Sprache-full-import-template.xlsx',
                              templateLabel: '전체 엑셀 템플릿',
                            ),
                    ),
                    if (receipts.isNotEmpty || mappingPresets.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _ImportHistoryCard(
                        receipts: receipts,
                        mappingPresets: mappingPresets,
                        subjects: availableSubjects,
                        onUndo: _busy ? null : _undoImport,
                        onDeletePreset: _busy ? null : _deleteMappingPreset,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _WebSentencePackCard(
                      busy: _busy,
                      onBasics: _busy
                          ? null
                          : () => _loadBundledWebPack(
                              fileName:
                                  'tatoeba-korean-sentence-pack-2026-07-28.json',
                              busyMessage: '기초 예문 팩을 준비하고 있습니다…',
                            ),
                      onPractical: _busy
                          ? null
                          : () => _loadBundledWebPack(
                              fileName:
                                  'tatoeba-practical-sentence-pack-2026-07-29.json',
                              busyMessage: '출퇴근·학습 예문 팩을 준비하고 있습니다…',
                            ),
                    ),
                    const SizedBox(height: 12),
                    _TopicStarterPacksCard(
                      busy: _busy,
                      onBaseball: _busy
                          ? null
                          : () => _loadBundledTopicPack(
                              subjectId: 'general:baseball',
                              subjectName: '야구 용어',
                              symbol: '⚾',
                              description: '야구 기록, 규칙, 포지션을 익히는 주제',
                              fileName: 'baseball-starter-pack-2026-07-28.json',
                            ),
                      onIdol: _busy
                          ? null
                          : () => _loadBundledTopicPack(
                              subjectId: 'general:idol-fandom',
                              subjectName: '아이돌·팬덤 용어',
                              symbol: '🎤',
                              description: 'K-pop 팬덤과 일정 표현을 익히는 주제',
                              fileName:
                                  'idol-fandom-starter-pack-2026-07-28.json',
                            ),
                    ),
                    const SizedBox(height: 12),
                    const _FormatGuide(),
                    if (review != null) ...[
                      const SizedBox(height: 18),
                      _ReviewSummary(
                        fileName: _fileName ?? '미리보기 파일',
                        review: review,
                      ),
                      if (_sourceSummary case final summary?) ...[
                        const SizedBox(height: 8),
                        Card(
                          child: ListTile(
                            key: const Key('import-source-summary'),
                            leading: const Icon(Icons.source_rounded),
                            title: const Text('확인한 파일 원본'),
                            subtitle: Text(summary),
                            trailing: const Icon(Icons.verified_rounded),
                          ),
                        ),
                      ],
                      if (_columnMapping.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _ColumnMappingSummary(mapping: _columnMapping),
                      ],
                      if (notices.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _ImportNotices(notices: notices),
                      ],
                      if (_previousImport case final previous?) ...[
                        const SizedBox(height: 12),
                        _RepeatedImportNotice(record: previous),
                      ],
                      const SizedBox(height: 12),
                      _BulkActions(
                        review: review,
                        onNewAction: (action) => _setBulkAction(
                          review,
                          ImportReviewStatus.newItem,
                          action,
                        ),
                        onChangedAction: (action) => _setBulkAction(
                          review,
                          ImportReviewStatus.changed,
                          action,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _FilterBar(
                        filter: _filter,
                        totalCount: review.entries.length,
                        selectedCount: selectedCount,
                        changedCount: review.changedCount,
                        problemCount:
                            review.blockedCount +
                            review.issues.length +
                            review.duplicates.length,
                        onChanged: (filter) => setState(() {
                          _filter = filter;
                          _visibleLimit = 50;
                        }),
                      ),
                      const SizedBox(height: 10),
                      if (visible.isEmpty)
                        const _EmptyFilterResult()
                      else
                        for (final entry in visible) ...[
                          _ImportEntryCard(
                            entry: entry,
                            action: _actionFor(entry),
                            onActionChanged: (action) =>
                                _setAction(entry, action),
                            onEdit: entry.status == ImportReviewStatus.blocked
                                ? () => _editBlockedEntry(entry)
                                : null,
                          ),
                          const SizedBox(height: 10),
                        ],
                      if (visible.length < filtered.length)
                        OutlinedButton.icon(
                          onPressed: () => setState(() => _visibleLimit += 50),
                          icon: const Icon(Icons.expand_more_rounded),
                          label: Text(
                            '항목 더 보기 (${filtered.length - visible.length}개 남음)',
                          ),
                        ),
                      if (review.duplicates.isNotEmpty ||
                          review.issues.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _RejectedRows(review: review),
                      ],
                      if (review.blockedCount > 0 ||
                          review.issues.isNotEmpty ||
                          review.duplicates.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          key: const Key('export-import-report'),
                          onPressed: _busy
                              ? null
                              : () => _exportImportReport(review),
                          icon: const Icon(Icons.privacy_tip_outlined),
                          label: const Text('원문 없는 오류 보고서 저장'),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _ImportDestinationSummaryCard(
                        destinations: destinations,
                        driveConnected: appState.driveConnected,
                      ),
                      const SizedBox(height: 10),
                      _ImportCommitBar(
                        selectedCount: selectedCount,
                        skippedCount: review.entries.length - selectedCount,
                        issueCount:
                            review.issues.length + review.duplicates.length,
                        busy: _busy,
                        onImport: selectedCount == 0
                            ? null
                            : () => _import(review, destinations),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextImportSelection {
  const _TextImportSelection({required this.encoding, required this.delimiter});

  final TextImportEncoding encoding;
  final TextImportDelimiter delimiter;
}

class _TextImportOptionsDialog extends StatefulWidget {
  const _TextImportOptionsDialog({required this.inspection});

  final _TabularInspection inspection;

  @override
  State<_TextImportOptionsDialog> createState() =>
      _TextImportOptionsDialogState();
}

class _TextImportOptionsDialogState extends State<_TextImportOptionsDialog> {
  late TextImportEncoding _encoding;
  late TextImportDelimiter _delimiter;

  @override
  void initState() {
    super.initState();
    _encoding = TextImportEncoding.values.firstWhere(
      (value) => value.name == widget.inspection.encodingName,
      orElse: () => TextImportEncoding.utf8,
    );
    _delimiter = TextImportDelimiter.values.firstWhere(
      (value) => value.name == widget.inspection.delimiterName,
      orElse: () => TextImportDelimiter.comma,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('텍스트 형식 확인'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('자동 감지 결과를 확인하거나 직접 바꾼 뒤 다음으로 진행하세요.'),
              const SizedBox(height: 14),
              DropdownButtonFormField<TextImportEncoding>(
                key: const Key('import-encoding-picker'),
                initialValue: _encoding,
                decoration: const InputDecoration(labelText: '문자 인코딩'),
                items: [
                  for (final value in TextImportEncoding.values)
                    if (value != TextImportEncoding.auto)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _encoding = value);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<TextImportDelimiter>(
                key: const Key('import-delimiter-picker'),
                initialValue: _delimiter,
                decoration: const InputDecoration(labelText: '열 구분자'),
                items: [
                  for (final value in TextImportDelimiter.values)
                    if (value != TextImportDelimiter.auto)
                      DropdownMenuItem(value: value, child: Text(value.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _delimiter = value);
                },
              ),
              const SizedBox(height: 14),
              Text(
                '첫 행 미리보기 · ${widget.inspection.headers.length}열',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 7),
              _CompactTabularPreview(
                headers: widget.inspection.headers,
                rows: widget.inspection.samples,
              ),
              const SizedBox(height: 8),
              const Text(
                '선택을 바꾸면 확인 시 원본 바이트를 새 기준으로 다시 읽습니다.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('confirm-text-import-options'),
          onPressed: () => Navigator.pop(
            context,
            _TextImportSelection(encoding: _encoding, delimiter: _delimiter),
          ),
          child: const Text('이 형식으로 다시 확인'),
        ),
      ],
    );
  }
}

class _ExcelSheetSelectionDialog extends StatefulWidget {
  const _ExcelSheetSelectionDialog({required this.sheets});

  final List<_ExcelSheetInspection> sheets;

  @override
  State<_ExcelSheetSelectionDialog> createState() =>
      _ExcelSheetSelectionDialogState();
}

class _ExcelSheetSelectionDialogState
    extends State<_ExcelSheetSelectionDialog> {
  late String _selected = widget.sheets.first.name;

  @override
  Widget build(BuildContext context) {
    final active = widget.sheets.firstWhere((sheet) => sheet.name == _selected);
    return AlertDialog(
      title: const Text('가져올 Excel 시트 선택'),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final sheet in widget.sheets)
                ListTile(
                  key: Key('import-sheet-${sheet.name}'),
                  selected: _selected == sheet.name,
                  leading: Icon(
                    _selected == sheet.name
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                  ),
                  title: Text(sheet.name),
                  subtitle: Text(
                    '${sheet.headers.length}열 · 표본 ${sheet.samples.length}행',
                  ),
                  onTap: () => setState(() => _selected = sheet.name),
                ),
              const Divider(),
              Text(
                '“${active.name}” 표본',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 7),
              _CompactTabularPreview(
                headers: active.headers,
                rows: active.samples,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('confirm-excel-sheet'),
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('이 시트 사용'),
        ),
      ],
    );
  }
}

class _CompactTabularPreview extends StatelessWidget {
  const _CompactTabularPreview({required this.headers, required this.rows});

  final List<String> headers;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final visibleHeaders = headers.take(6).toList(growable: false);
    if (visibleHeaders.isEmpty) return const Text('표시할 행이 없습니다.');
    return Container(
      constraints: const BoxConstraints(maxHeight: 210),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 42,
            dataRowMinHeight: 38,
            dataRowMaxHeight: 54,
            columns: [
              for (final header in visibleHeaders)
                DataColumn(
                  label: Text(header, overflow: TextOverflow.ellipsis),
                ),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    for (var index = 0; index < visibleHeaders.length; index++)
                      DataCell(
                        SizedBox(
                          width: 130,
                          child: Text(
                            index < row.length ? row[index] : '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedEntryEdit {
  const _BlockedEntryEdit({
    required this.id,
    required this.text,
    required this.meaning,
  });

  final String id;
  final String text;
  final String meaning;
}

class _BlockedEntryEditDialog extends StatefulWidget {
  const _BlockedEntryEditDialog({required this.entry});

  final ImportReviewEntry entry;

  @override
  State<_BlockedEntryEditDialog> createState() =>
      _BlockedEntryEditDialogState();
}

class _BlockedEntryEditDialogState extends State<_BlockedEntryEditDialog> {
  late final TextEditingController _id = TextEditingController(
    text: widget.entry.incoming.id,
  );
  late final TextEditingController _text = TextEditingController(
    text: widget.entry.incoming.text,
  );
  late final TextEditingController _meaning = TextEditingController(
    text: widget.entry.incoming.primaryTranslation,
  );
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _text.dispose();
    _meaning.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sentence = widget.entry.incoming.kind == LearningItemKind.sentence;
    return AlertDialog(
      title: Text('${widget.entry.row}행 문제 필드 수정'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('blocked-import-id'),
              controller: _id,
              decoration: const InputDecoration(labelText: '고유 ID'),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('blocked-import-text'),
              controller: _text,
              enabled: !sentence,
              decoration: InputDecoration(
                labelText: '문제·표현',
                helperText: sentence ? '문장 토큰 보호를 위해 원문 파일에서 수정하세요.' : null,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('blocked-import-meaning'),
              controller: _meaning,
              decoration: const InputDecoration(labelText: '대표 정답·뜻'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppTheme.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('confirm-blocked-import-edit'),
          onPressed: () {
            final id = _id.text.trim();
            final text = _text.text.trim();
            final meaning = _meaning.text.trim();
            if (id.isEmpty || text.isEmpty || meaning.isEmpty) {
              setState(() => _error = 'ID·문제·뜻을 모두 입력해 주세요.');
              return;
            }
            Navigator.pop(
              context,
              _BlockedEntryEdit(id: id, text: text, meaning: meaning),
            );
          },
          child: const Text('수정하고 재검증'),
        ),
      ],
    );
  }
}

class _ImportColumnMappingSelection {
  const _ImportColumnMappingSelection({required this.mapping, this.presetName});

  final Map<String, String> mapping;
  final String? presetName;
}

class _ImportColumnMappingDialog extends StatefulWidget {
  const _ImportColumnMappingDialog({
    required this.headers,
    required this.suggested,
    required this.presets,
  });

  final List<String> headers;
  final Map<String, String> suggested;
  final List<ImportMappingPreset> presets;

  @override
  State<_ImportColumnMappingDialog> createState() =>
      _ImportColumnMappingDialogState();
}

class _ImportColumnMappingDialogState
    extends State<_ImportColumnMappingDialog> {
  late final Map<String, String> _mapping;
  final _presetNameController = TextEditingController();

  List<ImportMappingPreset> get _usablePresets => widget.presets
      .where((preset) => preset.columns.values.every(widget.headers.contains))
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _mapping = {...widget.suggested};
  }

  @override
  void dispose() {
    _presetNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const mapper = ImportColumnMapper();
    final missing = mapper.missingRequired(_mapping);
    return AlertDialog(
      key: const Key('import-column-mapping-dialog'),
      title: const Text('파일 열 연결 확인'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.sizeOf(context).height * 0.68,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('열 이름을 자동으로 연결했습니다. 문제와 정답이 맞는지만 확인하세요.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_usablePresets.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                key: const Key('import-mapping-preset-picker'),
                decoration: const InputDecoration(
                  labelText: '저장한 열 연결 불러오기',
                  prefixIcon: Icon(Icons.bookmark_outline_rounded),
                ),
                items: [
                  for (final preset in _usablePresets)
                    DropdownMenuItem(
                      value: preset.id,
                      child: Text(preset.name),
                    ),
                ],
                onChanged: (id) {
                  if (id == null) return;
                  final preset = _usablePresets.firstWhere(
                    (value) => value.id == id,
                  );
                  setState(() {
                    _mapping
                      ..clear()
                      ..addAll(preset.columns);
                  });
                },
              ),
              const SizedBox(height: 10),
            ],
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: ImportColumnMapper.fields.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final field = ImportColumnMapper.fields[index];
                  final current = _mapping[field.key];
                  return DropdownButtonFormField<String>(
                    key: Key('import-column-${field.key}'),
                    initialValue: widget.headers.contains(current)
                        ? current
                        : null,
                    decoration: InputDecoration(
                      labelText:
                          '${field.label}${field.required ? ' · 필수' : ''}',
                      isDense: true,
                    ),
                    items: [
                      if (!field.required)
                        const DropdownMenuItem(
                          value: '',
                          child: Text('연결하지 않음'),
                        ),
                      for (final header in widget.headers)
                        DropdownMenuItem(value: header, child: Text(header)),
                    ],
                    onChanged: (value) => setState(() {
                      if (value == null || value.isEmpty) {
                        _mapping.remove(field.key);
                      } else {
                        _mapping[field.key] = value;
                      }
                    }),
                  );
                },
              ),
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '${missing.map((field) => field.label).join('·')} 열을 연결해 주세요.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              key: const Key('import-mapping-preset-name'),
              controller: _presetNameController,
              maxLength: 40,
              decoration: const InputDecoration(
                labelText: '이 연결을 저장할 이름 (선택)',
                hintText: '예: 회사 단어장 양식',
                prefixIcon: Icon(Icons.bookmark_add_outlined),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('confirm-import-column-mapping'),
          onPressed: missing.isNotEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  _ImportColumnMappingSelection(
                    mapping: Map<String, String>.unmodifiable(_mapping),
                    presetName: _presetNameController.text.trim().isEmpty
                        ? null
                        : _presetNameController.text.trim(),
                  ),
                ),
          child: const Text('이대로 분석'),
        ),
      ],
    );
  }
}

class _BulkPasteDialog extends StatefulWidget {
  const _BulkPasteDialog();

  @override
  State<_BulkPasteDialog> createState() => _BulkPasteDialogState();
}

class _BulkPasteDialogState extends State<_BulkPasteDialog> {
  final _controller = TextEditingController();
  final _clipboardSession = ClipboardReadSession();
  String? _clipboardMessage;

  Future<void> _pasteFromSystemClipboard() async {
    final result = await _clipboardSession.readOnce(
      () async => (await Clipboard.getData(Clipboard.kTextPlain))?.text,
    );
    if (!mounted) return;
    switch (result.status) {
      case ClipboardReadStatus.accepted:
        final text = result.text!;
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        setState(() {
          _clipboardMessage = '클립보드를 한 번만 읽어 미리보기에 넣었습니다.';
        });
      case ClipboardReadStatus.empty:
        setState(() {
          _clipboardMessage = '클립보드에 붙여넣을 텍스트가 없습니다.';
        });
      case ClipboardReadStatus.alreadyRead:
        setState(() {
          _clipboardMessage = '이 창에서는 클립보드를 이미 한 번 읽었습니다.';
        });
      case ClipboardReadStatus.failed:
        setState(() {
          _clipboardMessage = '클립보드를 읽지 못했습니다. 직접 붙여넣어 주세요.';
        });
    }
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _clipboardMessage = '입력한 내용을 모두 지웠습니다.';
    });
  }

  @override
  void dispose() {
    if (_clipboardSession.hasUnconfirmedContent) {
      _controller.clear();
      _clipboardSession.discard();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    BulkPasteResult? preview;
    String? error;
    if (_controller.text.trim().isNotEmpty) {
      try {
        preview = const BulkPasteParser().parse(_controller.text);
      } on FormatException catch (exception) {
        error = exception.message.toString();
      }
    }
    return AlertDialog(
      key: const Key('bulk-paste-import-dialog'),
      title: const Text('문제·정답 여러 줄 붙여넣기'),
      content: SizedBox(
        width: 680,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 620),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Excel 두 열을 그대로 붙여넣거나 탭·쉼표·세미콜론·콜론·파이프·대시로 '
                  '문제와 정답을 나누세요. 구분자가 없으면 두 줄씩 한 쌍으로 묶습니다.',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('bulk-paste-system-clipboard'),
                      onPressed: _clipboardSession.hasRead
                          ? null
                          : _pasteFromSystemClipboard,
                      icon: const Icon(Icons.content_paste_go_rounded),
                      label: const Text('클립보드에서 붙여넣기'),
                    ),
                    TextButton.icon(
                      key: const Key('clear-bulk-paste-input'),
                      onPressed: _controller.text.isEmpty ? null : _clear,
                      icon: const Icon(Icons.clear_all_rounded),
                      label: const Text('모두 지우기'),
                    ),
                  ],
                ),
                if (_clipboardMessage != null) ...[
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _clipboardMessage!,
                      key: const Key('bulk-paste-clipboard-message'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  key: const Key('bulk-paste-import-input'),
                  controller: _controller,
                  autofocus: true,
                  minLines: 7,
                  maxLines: 12,
                  onChanged: (_) => setState(() {
                    _clipboardMessage = null;
                  }),
                  decoration: const InputDecoration(
                    hintText:
                        'hello\t안녕하세요\n'
                        'good morning | 좋은 아침\n'
                        'thank you - 고마워요',
                    helperText: '여러 구분자를 혼합해도 됩니다 · 최대 100개',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    key: const Key('bulk-paste-summary'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      error ??
                          (preview == null
                              ? '붙여넣으면 형식·개수·오류를 미리 확인합니다.'
                              : '감지 형식 ${preview.detectedFormat.label} · '
                                    '가져올 ${preview.entryCount}개 · '
                                    '확인 ${preview.problemCount}건'
                                    '${preview.duplicateCount == 0 ? '' : ' · 중복 ${preview.duplicateCount}건 제외'}'),
                      style: TextStyle(
                        color: error != null || (preview?.problemCount ?? 0) > 0
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (preview != null && preview.entries.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '최대 5행 미리보기',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    key: const Key('bulk-paste-entry-preview'),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        for (final entry in preview.entries.take(5))
                          Padding(
                            key: ValueKey(
                              'bulk-paste-preview-row-${entry.line}',
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '${entry.line}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry.term,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry.meaning,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (preview != null && preview.issues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('확인할 내용', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  for (final issue in preview.issues.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${issue.message}'
                        '${issue.source.isEmpty ? '' : '\n  ${issue.source}'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: issue.kind == BulkPasteIssueKind.duplicate
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (preview.issues.length > 3)
                    Text(
                      '외 ${preview.issues.length - 3}건',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('confirm-bulk-paste-import'),
          onPressed: preview?.canImport == true && error == null
              ? () {
                  _clipboardSession.confirm();
                  Navigator.pop(context, _controller.text);
                }
              : null,
          child: const Text('검토 화면 만들기'),
        ),
      ],
    );
  }
}

class _ColumnMappingSummary extends StatelessWidget {
  const _ColumnMappingSummary({required this.mapping});

  final Map<String, String> mapping;

  @override
  Widget build(BuildContext context) {
    final labels = {
      for (final field in ImportColumnMapper.fields) field.key: field.label,
    };
    return Container(
      key: const Key('import-column-mapping-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.view_column_outlined, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mapping.entries
                  .map(
                    (entry) =>
                        '${labels[entry.key] ?? entry.key} ← ${entry.value}',
                  )
                  .join('\n'),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.subjectName,
    required this.subjectSymbol,
    required this.generalTopic,
  });

  final String subjectName;
  final String subjectSymbol;
  final bool generalTopic;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton.filledTonal(
          onPressed: () => context.go('/library'),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: '자료실로',
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '학습 콘텐츠 가져오기',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                generalTopic
                    ? '$subjectSymbol $subjectName 주제에 추가하기 전에 변경점을 한 항목씩 검토합니다.'
                    : '$subjectName 코스에 추가하기 전에 변경점을 한 항목씩 검토합니다.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WebSentencePackCard extends StatelessWidget {
  const _WebSentencePackCard({
    required this.busy,
    required this.onBasics,
    required this.onPractical,
  });

  final bool busy;
  final VoidCallback? onBasics;
  final VoidCallback? onPractical;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final description = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '검증된 웹 예문 팩',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '6개 언어 Tatoeba 예문 24개 · 기초 또는 출퇴근·학습 팩을 골라 원문 ID, URL, 작성자와 라이선스 표시까지 가져옵니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '바로 저장하지 않고 다음 화면에서 항목별로 검토합니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  key: const Key('load-tatoeba-web-pack'),
                  onPressed: onBasics,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.waving_hand_rounded),
                  label: Text(busy ? '읽는 중' : '기초 12개'),
                ),
                FilledButton.tonalIcon(
                  key: const Key('load-tatoeba-practical-pack'),
                  onPressed: onPractical,
                  icon: const Icon(Icons.commute_rounded),
                  label: const Text('출퇴근·학습 12개'),
                ),
              ],
            );
            if (constraints.maxWidth < 600) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [description, const SizedBox(height: 14), actions],
              );
            }
            return Row(
              children: [
                Icon(Icons.language_rounded, size: 34, color: colors.secondary),
                const SizedBox(width: 14),
                Expanded(child: description),
                const SizedBox(width: 16),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopicStarterPacksCard extends StatelessWidget {
  const _TopicStarterPacksCard({
    required this.busy,
    required this.onBaseball,
    required this.onIdol,
  });

  final bool busy;
  final VoidCallback? onBaseball;
  final VoidCallback? onIdol;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.tertiaryContainer.withValues(alpha: 0.38),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '무엇이든 외우는 샘플 주제',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '주제와 학습 그룹을 자동으로 만들고, 출처가 기록된 개념·설명·예문을 검토 화면에 올립니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  key: const Key('load-baseball-starter-pack'),
                  onPressed: onBaseball,
                  icon: const Text('⚾'),
                  label: const Text('야구 용어'),
                ),
                FilledButton.tonalIcon(
                  key: const Key('load-idol-starter-pack'),
                  onPressed: onIdol,
                  icon: const Text('🎤'),
                  label: const Text('아이돌·팬덤'),
                ),
              ],
            );
            if (constraints.maxWidth < 700) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 14), actions],
              );
            }
            return Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 18),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ImportRoutingCard extends StatelessWidget {
  const _ImportRoutingCard({
    required this.keyController,
    required this.groupController,
    required this.subjects,
    required this.selectedSubjectId,
    required this.groupSuggestions,
    required this.driveConnected,
    required this.enabled,
    required this.onKeyChanged,
    required this.onSubjectChanged,
    required this.onGroupChanged,
  });

  final TextEditingController keyController;
  final TextEditingController groupController;
  final List<StudySubject> subjects;
  final String selectedSubjectId;
  final List<String> groupSuggestions;
  final bool driveConnected;
  final bool enabled;
  final ValueChanged<String> onKeyChanged;
  final ValueChanged<String> onSubjectChanged;
  final ValueChanged<String> onGroupChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusText = driveConnected
        ? '반영 후 원본 파일은 만들지 않고 기존 Drive 데이터에 병합'
        : '정돈된 학습 데이터만 로컬 저장 · Google 연결 후 기기 간 동기화';
    final fields = <Widget>[
      TextField(
        key: const Key('import-distribution-key'),
        controller: keyController,
        enabled: enabled,
        maxLength: 48,
        onChanged: onKeyChanged,
        decoration: const InputDecoration(
          labelText: '분배 키',
          hintText: '예: office-en, baseball-2026',
          helperText: '같은 키를 다시 쓰면 같은 목적지로 분류',
          prefixIcon: Icon(Icons.key_rounded),
        ),
      ),
      DropdownButtonFormField<String>(
        key: ValueKey('import-route-subject-$selectedSubjectId'),
        initialValue: selectedSubjectId,
        decoration: const InputDecoration(
          labelText: '들어갈 주제',
          prefixIcon: Icon(Icons.folder_copy_rounded),
        ),
        items: [
          for (final subject in subjects)
            DropdownMenuItem(
              value: subject.id,
              child: Text('${subject.symbol} ${subject.name}'),
            ),
        ],
        onChanged: enabled
            ? (value) {
                if (value != null) onSubjectChanged(value);
              }
            : null,
      ),
      Autocomplete<String>(
        optionsBuilder: (value) {
          final query = value.text.trim().toLowerCase();
          return groupSuggestions.where(
            (group) => query.isEmpty || group.toLowerCase().contains(query),
          );
        },
        onSelected: (value) {
          groupController.text = value;
          onGroupChanged(value);
        },
        fieldViewBuilder:
            (context, textController, focusNode, onFieldSubmitted) {
              if (textController.text != groupController.text) {
                textController.value = groupController.value;
              }
              return TextField(
                key: const Key('import-distribution-group'),
                controller: textController,
                focusNode: focusNode,
                enabled: enabled,
                maxLength: 40,
                onChanged: (value) {
                  groupController.text = value;
                  onGroupChanged(value);
                },
                onSubmitted: (_) => onFieldSubmitted(),
                decoration: const InputDecoration(
                  labelText: '그룹 (선택)',
                  hintText: '예: 출근길 복습',
                  prefixIcon: Icon(Icons.folder_rounded),
                ),
              );
            },
      ),
    ];
    return Card(
      color: colors.primaryContainer.withValues(alpha: 0.34),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.account_tree_rounded, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '어디로 분배할까요?',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        statusText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  driveConnected
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: driveConnected ? AppTheme.success : colors.outline,
                ),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 760) {
                  return Column(
                    children: [
                      for (final field in fields) ...[
                        field,
                        if (field != fields.last) const SizedBox(height: 8),
                      ],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final field in fields) ...[
                      Expanded(child: field),
                      if (field != fields.last) const SizedBox(width: 12),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.fileName,
    required this.busyMessage,
    required this.onPickFile,
    required this.onPaste,
    required this.onSaveEasyTemplate,
    required this.onSaveFullTemplate,
  });

  final String? fileName;
  final String? busyMessage;
  final VoidCallback? onPickFile;
  final VoidCallback? onPaste;
  final VoidCallback? onSaveEasyTemplate;
  final VoidCallback? onSaveFullTemplate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = fileName != null;
    Widget summary({required bool compact}) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: compact ? 46 : 58,
              child: Icon(
                selected
                    ? Icons.description_rounded
                    : Icons.upload_file_rounded,
                color: colors.onPrimaryContainer,
                size: compact ? 24 : 29,
              ),
            ),
          ),
          SizedBox(width: compact ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected ? fileName! : '학습 파일을 선택하세요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  selected
                      ? '다른 파일로 바꾸거나 아래 템플릿을 내려받을 수 있습니다.'
                      : 'Excel, CSV, JSON, JSONL · 이 기기에서 검토한 뒤 저장합니다.',
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  const ImportLimits().userSummary,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (busyMessage != null) ...[
                  const SizedBox(height: 10),
                  Semantics(
                    liveRegion: true,
                    label: busyMessage,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LinearProgressIndicator(
                          key: Key('import-busy-progress'),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          busyMessage!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    Widget actions({required bool compact}) {
      return Wrap(
        spacing: 6,
        runSpacing: 4,
        alignment: compact ? WrapAlignment.start : WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: onPickFile,
            icon: const Icon(Icons.folder_open_rounded),
            label: Text(selected ? '바꾸기' : '찾아보기'),
          ),
          OutlinedButton.icon(
            key: const Key('open-bulk-paste-import'),
            onPressed: onPaste,
            icon: const Icon(Icons.content_paste_rounded),
            label: const Text('여러 줄 붙여넣기'),
          ),
          TextButton.icon(
            key: const Key('save-excel-template'),
            onPressed: onSaveEasyTemplate,
            icon: const Icon(Icons.download_rounded),
            label: const Text('간편 템플릿'),
          ),
          TextButton.icon(
            key: const Key('save-full-excel-template'),
            onPressed: onSaveFullTemplate,
            icon: const Icon(Icons.tune_rounded),
            label: const Text('전체 템플릿'),
          ),
        ],
      );
    }

    return Card(
      child: InkWell(
        onTap: onPickFile,
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 22,
                vertical: compact ? 16 : 22,
              ),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        summary(compact: true),
                        const SizedBox(height: 10),
                        actions(compact: true),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: summary(compact: false)),
                        const SizedBox(width: 16),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 330),
                          child: actions(compact: false),
                        ),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _ImportHistoryCard extends StatelessWidget {
  const _ImportHistoryCard({
    required this.receipts,
    required this.mappingPresets,
    required this.subjects,
    required this.onUndo,
    required this.onDeletePreset,
  });

  final List<ImportBatchReceipt> receipts;
  final List<ImportMappingPreset> mappingPresets;
  final List<StudySubject> subjects;
  final Future<void> Function(ImportBatchReceipt)? onUndo;
  final Future<void> Function(ImportMappingPreset)? onDeletePreset;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        key: const Key('import-history-card'),
        leading: const Icon(Icons.history_rounded),
        title: const Text(
          '최근 가져오기와 열 연결',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '가져오기 ${receipts.length}건 · 저장한 열 연결 ${mappingPresets.length}개',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          if (receipts.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '가져오기 영수증',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            for (final receipt in receipts)
              ListTile(
                key: Key('import-receipt-${receipt.importId}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  receipt.undoneAt == null
                      ? Icons.receipt_long_outlined
                      : Icons.undo_rounded,
                ),
                title: Text(
                  receipt.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '추가 ${receipt.addedCount} · 병합·교체 ${receipt.mergedCount} · '
                      '제외 ${receipt.skippedCount} · 오류 ${receipt.errorCount}',
                    ),
                    for (final destination
                        in (receipt.destinations.isEmpty
                                ? [
                                    ImportReceiptDestination(
                                      subjectId: receipt.subjectId,
                                      distributionKey: receipt.distributionKey,
                                      itemCount:
                                          receipt.addedCount +
                                          receipt.mergedCount,
                                    ),
                                  ]
                                : receipt.destinations)
                            .take(3))
                      Text(
                        _destinationLabel(destination),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (receipt.destinations.length > 3)
                      Text('외 ${receipt.destinations.length - 3}개 대상'),
                  ],
                ),
                trailing: receipt.canUndo
                    ? TextButton(
                        onPressed: onUndo == null
                            ? null
                            : () => onUndo!(receipt),
                        child: const Text('되돌리기'),
                      )
                    : const Chip(label: Text('되돌림 완료')),
              ),
          ],
          if (mappingPresets.isNotEmpty) ...[
            if (receipts.isNotEmpty) const Divider(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '저장한 열 연결',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final preset in mappingPresets)
                    InputChip(
                      key: Key('mapping-preset-${preset.id}'),
                      avatar: const Icon(Icons.view_column_outlined, size: 17),
                      label: Text(preset.name),
                      onDeleted: onDeletePreset == null
                          ? null
                          : () => onDeletePreset!(preset),
                      deleteButtonTooltipMessage: '열 연결 삭제',
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _destinationLabel(ImportReceiptDestination destination) {
    final subject = subjects
        .where((value) => value.id == destination.subjectId)
        .firstOrNull;
    final subjectLabel = subject?.name ?? destination.subjectId;
    final keyLabel = destination.distributionKey.isEmpty
        ? '키 없음'
        : '키 ${destination.distributionKey}';
    return '대상 $subjectLabel · $keyLabel · ${destination.itemCount}개';
  }
}

class _FormatGuide extends StatelessWidget {
  const _FormatGuide();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.code_rounded),
        title: const Text(
          '지원 형식과 필수 필드',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text(
          'language, type, term, meaning, group, example, subject_id',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '일반 주제는 먼저 앱에서 주제를 선택한 뒤 가져오세요. subject_id를 비우면 현재 주제에 저장되고, 언어 코스에서는 language 값에 맞는 코스로 들어갑니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 5),
          Text(
            'type=word는 개념·용어, type=sentence는 사실·문장입니다. meaning은 | 로 여러 뜻을 넣고, group으로 함께 묶습니다. example·example_translation 한 쌍은 독립 학습 문장도 자동 생성합니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const SelectableText(
              'language,type,term,meaning,group,example,example_translation,subject_id\n'
              'ko,word,WHIP,이닝당 출루 허용률,야구 기록,WHIP가 1.10이다.,주자가 적게 나갔다.,\n'
              'ko,sentence,팬사인회는 추첨제로 진행된다.,응모 후 당첨된 팬이 참여한다.,아이돌 일정,,,',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({required this.fileName, required this.review});

  final String fileName;
  final ImportReview review;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('import-review-summary'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '가져오기 전 변경점 검토',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.fact_check_rounded),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                _ReviewMetric(
                  label: '신규',
                  value: review.newCount,
                  color: AppTheme.success,
                ),
                _ReviewMetric(
                  label: '변경',
                  value: review.changedCount,
                  color: AppTheme.warning,
                ),
                _ReviewMetric(
                  label: '동일',
                  value: review.unchangedCount,
                  color: AppTheme.desktopPrimary,
                ),
                _ReviewMetric(
                  label: '차단',
                  value: review.blockedCount,
                  color: AppTheme.danger,
                ),
                _ReviewMetric(
                  label: '행 오류',
                  value: review.issues.length + review.duplicates.length,
                  color: review.issues.isEmpty && review.duplicates.isEmpty
                      ? const Color(0xFF64748B)
                      : AppTheme.danger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewMetric extends StatelessWidget {
  const _ReviewMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            '$value',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: color),
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RepeatedImportNotice extends StatelessWidget {
  const _RepeatedImportNotice({required this.record});

  final ImportCommitRecord record;

  @override
  Widget build(BuildContext context) {
    final date = record.importedAt.toLocal();
    final formatted =
        '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Card(
      color: AppTheme.warning.withValues(alpha: 0.08),
      child: ListTile(
        key: const Key('import-repeated-file-notice'),
        leading: const Icon(Icons.history_rounded, color: AppTheme.warning),
        title: const Text(
          '이 파일은 이전에 가져온 기록이 있습니다.',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '$formatted · 저장 ${record.importedRows}행 · 제외 ${record.rejectedRows}행\n'
          '현재 자료실과 다시 비교했으므로 필요한 변경만 선택할 수 있습니다.',
        ),
      ),
    );
  }
}

class _BulkActions extends StatelessWidget {
  const _BulkActions({
    required this.review,
    required this.onNewAction,
    required this.onChangedAction,
  });

  final ImportReview review;
  final ValueChanged<ImportReviewAction> onNewAction;
  final ValueChanged<ImportReviewAction> onChangedAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('빠른 선택', style: Theme.of(context).textTheme.titleMedium),
            OutlinedButton.icon(
              key: const Key('import-bulk-add-new'),
              onPressed: review.newCount == 0
                  ? null
                  : () => onNewAction(ImportReviewAction.add),
              icon: const Icon(Icons.add_task_rounded),
              label: Text('신규 ${review.newCount}개 포함'),
            ),
            TextButton(
              onPressed: review.newCount == 0
                  ? null
                  : () => onNewAction(ImportReviewAction.skip),
              child: const Text('신규 제외'),
            ),
            OutlinedButton.icon(
              key: const Key('import-bulk-replace-changed'),
              onPressed: review.changedCount == 0
                  ? null
                  : () => onChangedAction(ImportReviewAction.replace),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text('변경 ${review.changedCount}개 병합·교체'),
            ),
            TextButton(
              onPressed: review.changedCount == 0
                  ? null
                  : () => onChangedAction(ImportReviewAction.skip),
              child: const Text('변경분 기존 유지'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.totalCount,
    required this.selectedCount,
    required this.changedCount,
    required this.problemCount,
    required this.onChanged,
  });

  final _ReviewFilter filter;
  final int totalCount;
  final int selectedCount;
  final int changedCount;
  final int problemCount;
  final ValueChanged<_ReviewFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ReviewFilterChip(
            label: '전체 $totalCount',
            selected: filter == _ReviewFilter.all,
            onSelected: () => onChanged(_ReviewFilter.all),
          ),
          const SizedBox(width: 7),
          _ReviewFilterChip(
            label: '선택됨 $selectedCount',
            selected: filter == _ReviewFilter.selected,
            onSelected: () => onChanged(_ReviewFilter.selected),
          ),
          const SizedBox(width: 7),
          _ReviewFilterChip(
            label: '변경 $changedCount',
            selected: filter == _ReviewFilter.changed,
            onSelected: () => onChanged(_ReviewFilter.changed),
          ),
          const SizedBox(width: 7),
          _ReviewFilterChip(
            label: '문제 $problemCount',
            selected: filter == _ReviewFilter.problems,
            onSelected: () => onChanged(_ReviewFilter.problems),
          ),
        ],
      ),
    );
  }
}

class _ReviewFilterChip extends StatelessWidget {
  const _ReviewFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }
}

class _ImportEntryCard extends StatelessWidget {
  const _ImportEntryCard({
    required this.entry,
    required this.action,
    required this.onActionChanged,
    this.onEdit,
  });

  final ImportReviewEntry entry;
  final ImportReviewAction action;
  final ValueChanged<ImportReviewAction> onActionChanged;
  final VoidCallback? onEdit;

  Color get _statusColor => switch (entry.status) {
    ImportReviewStatus.newItem => AppTheme.success,
    ImportReviewStatus.unchanged => AppTheme.desktopPrimary,
    ImportReviewStatus.changed => AppTheme.warning,
    ImportReviewStatus.blocked => AppTheme.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('import-review-entry-${entry.row}'),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${entry.row}행 · ${entry.status.label}',
                    style: TextStyle(
                      color: _statusColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  entry.incoming.kind == LearningItemKind.word ? '단어' : '문장',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  entry.incoming.learningLanguage.koreanName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              entry.incoming.text,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 3),
            Text(
              entry.incoming.primaryTranslation,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (entry.blockReason case final reason?) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.gpp_maybe_rounded,
                      size: 19,
                      color: AppTheme.danger,
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(reason)),
                  ],
                ),
              ),
              if (onEdit != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: Key('edit-blocked-import-${entry.row}'),
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('문제 필드 고치고 다시 검증'),
                  ),
                ),
              ],
            ],
            if (entry.differences.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                '바뀌는 필드 ${entry.differences.length}개',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 7),
              for (final difference in entry.differences) ...[
                _DifferenceRow(difference: difference),
                const SizedBox(height: 7),
              ],
            ],
            const SizedBox(height: 12),
            _ActionPicker(
              entry: entry,
              selected: action,
              onChanged: onActionChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DifferenceRow extends StatelessWidget {
  const _DifferenceRow({required this.difference});

  final ImportFieldDifference difference;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 620;
        final oldValue = _DifferenceValue(
          label: '기존',
          value: difference.existingValue,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        );
        final newValue = _DifferenceValue(
          label: '가져올 값',
          value: difference.incomingValue,
          color: AppTheme.warning.withValues(alpha: 0.09),
        );
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                difference.label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              if (narrow) ...[
                oldValue,
                const SizedBox(height: 6),
                newValue,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: oldValue),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      child: Icon(Icons.arrow_forward_rounded, size: 18),
                    ),
                    Expanded(child: newValue),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DifferenceValue extends StatelessWidget {
  const _DifferenceValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          SelectableText(value),
        ],
      ),
    );
  }
}

class _ActionPicker extends StatelessWidget {
  const _ActionPicker({
    required this.entry,
    required this.selected,
    required this.onChanged,
  });

  final ImportReviewEntry entry;
  final ImportReviewAction selected;
  final ValueChanged<ImportReviewAction> onChanged;

  @override
  Widget build(BuildContext context) {
    final actions = switch (entry.status) {
      ImportReviewStatus.newItem => const [
        ImportReviewAction.add,
        ImportReviewAction.skip,
      ],
      ImportReviewStatus.changed => const [
        ImportReviewAction.skip,
        ImportReviewAction.replace,
      ],
      ImportReviewStatus.unchanged ||
      ImportReviewStatus.blocked => const [ImportReviewAction.skip],
    };
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final action in actions)
          ChoiceChip(
            key: Key(
              'import-action-${entry.row}-${entry.incoming.id}-${action.name}',
            ),
            avatar: Icon(_actionIcon(action), size: 17),
            label: Text(_actionLabel(entry, action)),
            selected: selected == action,
            onSelected: (_) => onChanged(action),
          ),
      ],
    );
  }

  String _actionLabel(ImportReviewEntry entry, ImportReviewAction action) {
    return switch (action) {
      ImportReviewAction.add => '가져오기',
      ImportReviewAction.replace when entry.mergeOnly => '새 뜻·그룹만 병합',
      ImportReviewAction.replace => '가져온 값으로 교체',
      ImportReviewAction.skip when entry.status == ImportReviewStatus.changed =>
        '기존 값 유지',
      ImportReviewAction.skip
          when entry.status == ImportReviewStatus.unchanged =>
        '동일 항목 · 건너뜀',
      ImportReviewAction.skip when entry.status == ImportReviewStatus.blocked =>
        '안전하게 제외',
      ImportReviewAction.skip => '제외',
    };
  }

  IconData _actionIcon(ImportReviewAction action) => switch (action) {
    ImportReviewAction.add => Icons.add_circle_outline_rounded,
    ImportReviewAction.replace => Icons.swap_horiz_rounded,
    ImportReviewAction.skip => Icons.shield_outlined,
  };
}

class _ImportNotices extends StatelessWidget {
  const _ImportNotices({required this.notices});

  final List<ImportNotice> notices;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.tertiaryContainer.withValues(alpha: 0.35),
      child: ExpansionTile(
        key: const Key('import-reading-notices'),
        leading: Icon(Icons.record_voice_over_rounded, color: colors.tertiary),
        title: Text(
          '발음 보조 확인 ${notices.length}개',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('가져오기는 가능하며, 추측이 위험한 발음만 비워 두었습니다.'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          for (final notice in notices)
            ListTile(
              dense: true,
              leading: Text(
                '${notice.row}행',
                style: TextStyle(
                  color: colors.onTertiaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
              title: Text(notice.message),
            ),
        ],
      ),
    );
  }
}

class _RejectedRows extends StatelessWidget {
  const _RejectedRows({required this.review});

  final ImportReview review;

  @override
  Widget build(BuildContext context) {
    final total = review.duplicates.length + review.issues.length;
    return Card(
      child: ExpansionTile(
        key: const Key('import-rejected-rows'),
        leading: const Icon(Icons.report_gmailerrorred_rounded),
        title: Text(
          '저장하지 않는 원본 행 $total개',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('파일 안 중복과 형식 오류는 원본 행 번호와 이유를 표시합니다.'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (final duplicate in review.duplicates)
            ListTile(
              dense: true,
              leading: Text(
                '${duplicate.row}행',
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w900,
                ),
              ),
              title: Text(duplicate.item.text),
              subtitle: Text(
                '${duplicate.firstRow}행과 ${duplicate.kind.label} 중복입니다.',
              ),
            ),
          for (final issue in review.issues)
            ListTile(
              dense: true,
              leading: Text(
                '${issue.row}행',
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w900,
                ),
              ),
              title: Text(issue.message),
            ),
        ],
      ),
    );
  }
}

class _ImportDestinationSummaryCard extends StatelessWidget {
  const _ImportDestinationSummaryCard({
    required this.destinations,
    required this.driveConnected,
  });

  final List<_ImportDestination> destinations;
  final bool driveConnected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('import-destination-summary'),
      color: colors.secondaryContainer.withValues(alpha: 0.34),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.route_rounded, color: colors.secondary),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '반영 위치 확인',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        driveConnected
                            ? '앱 데이터에 병합한 뒤 같은 Drive 데이터셋을 업데이트합니다.'
                            : '이 기기의 앱 데이터와 선택한 로컬 저장본에 반영합니다.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (destinations.isEmpty)
              const Text('반영하도록 선택한 항목이 없습니다.')
            else
              for (final (index, destination) in destinations.indexed) ...[
                if (index > 0) const Divider(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.subjectSymbol,
                      style: const TextStyle(fontSize: 21),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${destination.subjectName} > ${destination.groupLabel}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            destination.distributionKey == null
                                ? '분배 키 없음'
                                : '분배 키 ${destination.distributionKey}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${destination.count}개',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _ImportCommitBar extends StatelessWidget {
  const _ImportCommitBar({
    required this.selectedCount,
    required this.skippedCount,
    required this.issueCount,
    required this.busy,
    required this.onImport,
  });

  final int selectedCount;
  final int skippedCount;
  final int issueCount;
  final bool busy;
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 600;
            final summary = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$selectedCount개를 자료실에 반영합니다.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  '기존 유지·제외 $skippedCount개 · 파일 오류 $issueCount개',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
            final button = FilledButton.icon(
              key: const Key('import-commit-button'),
              onPressed: busy ? null : onImport,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_alt_rounded),
              label: Text(busy ? '안전하게 저장 중…' : '$selectedCount개 가져오기'),
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [summary, const SizedBox(height: 12), button],
              );
            }
            return Row(
              children: [
                Expanded(child: summary),
                const SizedBox(width: 16),
                button,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyFilterResult extends StatelessWidget {
  const _EmptyFilterResult();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.filter_alt_off_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            const Text('이 조건에 해당하는 항목이 없습니다.'),
          ],
        ),
      ),
    );
  }
}
