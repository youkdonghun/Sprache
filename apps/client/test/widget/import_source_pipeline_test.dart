import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sprache/src/backup/study_data_xlsx_exporter.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/screens/import_screen.dart';
import 'package:sprache/src/services/recovery_checkpoint_service.dart';
import 'package:sprache/src/state/app_state.dart';
import 'package:sprache/src/state/pending_import_state.dart';
import 'package:sprache/src/theme/app_theme.dart';

void main() {
  final sources = <({String name, Uint8List Function() bytes})>[
    (
      name: 'csv',
      bytes: () => _utf8Bytes(
        'type,term,meaning,language\n'
        'word,pipeline csv,CSV 검증,en\n',
      ),
    ),
    (
      name: 'tsv',
      bytes: () => _utf8Bytes(
        'type\tterm\tmeaning\tlanguage\n'
        'word\tpipeline tsv\tTSV 검증\ten\n',
      ),
    ),
    (
      name: 'json',
      bytes: () => _utf8Bytes(
        '[{"type":"word","term":"pipeline json",'
        '"meaning":"JSON 검증","language":"en"}]',
      ),
    ),
    (
      name: 'jsonl',
      bytes: () => _utf8Bytes(
        '{"type":"word","term":"pipeline jsonl",'
        '"meaning":"JSONL 검증","language":"en"}\n',
      ),
    ),
    (
      name: 'xlsx',
      bytes: () => Uint8List.fromList(
        const StudyDataXlsxExporter().encode([
          LearningItem(
            id: 'pipeline-xlsx',
            kind: LearningItemKind.word,
            learningLanguage: LanguageTag.english,
            text: 'pipeline xlsx',
            translations: const ['XLSX 확인'],
            acceptedAnswers: const ['XLSX 확인'],
          ),
        ]),
      ),
    ),
  ];

  for (final source in sources) {
    testWidgets(
      '${source.name.toUpperCase()} file reaches shared review and applies',
      (tester) async {
        final harness = await _pumpImportHarness(
          tester,
          pending: PendingImportFile(
            name: 'pipeline.${source.name}',
            bytes: source.bytes(),
          ),
        );
        addTearDown(harness.dispose);

        if (source.name == 'xlsx') {
          await _tapWhenReady(
            tester,
            find.byKey(const Key('confirm-excel-sheet')),
          );
        } else if (source.name == 'csv' || source.name == 'tsv') {
          await _tapWhenReady(
            tester,
            find.byKey(const Key('confirm-text-import-options')),
          );
        }
        if (source.name == 'xlsx' ||
            source.name == 'csv' ||
            source.name == 'tsv') {
          await _tapWhenReady(
            tester,
            find.byKey(const Key('confirm-import-column-mapping')),
          );
        }

        await _pumpUntil(
          tester,
          find.byKey(const Key('import-review-workbench')),
        );
        expect(find.text('저장 전에 바뀔 내용 확인'), findsOneWidget);
        expect(harness.container.read(pendingImportFileProvider), isNull);

        await _commit(tester, harness.store);
        expect(harness.store.savedItems, isNotEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('bulk paste reaches the same review and apply pipeline', (
    tester,
  ) async {
    final harness = await _pumpImportHarness(tester);
    addTearDown(harness.dispose);

    final open = find.byKey(const Key('open-bulk-paste-import'));
    await _pumpUntil(tester, open);
    await tester.ensureVisible(open);
    await tester.tap(open);
    await _pumpUntil(tester, find.byKey(const Key('bulk-paste-import-dialog')));
    await tester.enterText(
      find.byKey(const Key('bulk-paste-import-input')),
      'pipeline paste\t붙여넣기 검증',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-bulk-paste-import')));

    await _pumpUntil(tester, find.byKey(const Key('import-review-workbench')));
    expect(find.text('저장 전에 바뀔 내용 확인'), findsOneWidget);

    await _commit(tester, harness.store);
    expect(harness.store.savedItems, isNotEmpty);
    expect(tester.takeException(), isNull);
  });
}

Uint8List _utf8Bytes(String value) => Uint8List.fromList(utf8.encode(value));

Future<_ImportHarness> _pumpImportHarness(
  WidgetTester tester, {
  PendingImportFile? pending,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1400);
  addTearDown(tester.view.reset);

  final store = MemoryStudyStore();
  final container = ProviderContainer(
    overrides: [
      studyStoreProvider.overrideWithValue(store),
      recoveryCheckpointServiceProvider.overrideWithValue(
        _NoopRecoveryCheckpointService(),
      ),
    ],
  );
  if (pending != null) {
    container.read(pendingImportFileProvider.notifier).state = pending;
  }
  final router = GoRouter(
    initialLocation: '/import',
    routes: [
      GoRoute(
        path: '/import',
        builder: (context, state) => const Scaffold(body: ImportScreen()),
      ),
      GoRoute(
        path: '/library',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('test library destination')),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.desktop, routerConfig: router),
    ),
  );
  await tester.pump();
  return _ImportHarness(store: store, container: container, router: router);
}

Future<void> _tapWhenReady(WidgetTester tester, Finder finder) async {
  await _pumpUntil(tester, finder);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _commit(WidgetTester tester, MemoryStudyStore store) async {
  final commit = find.byKey(const Key('import-commit-button'));
  await _pumpUntil(tester, commit);
  await tester.ensureVisible(commit);
  await tester.pumpAndSettle();
  await tester.tap(commit);
  for (var frame = 0; frame < 240; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (store.savedItems.isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Timed out waiting for the reviewed import to be applied.');
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 150,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
    // Import parsing runs through compute(). Give its worker isolate real
    // time between fake-clock frames so this remains deterministic in CI.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  }
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data)
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .take(20)
      .toList(growable: false);
  final exception = tester.takeException();
  fail(
    'Timed out waiting for $finder. '
    'Visible text: $visibleText. Exception: $exception',
  );
}

class _ImportHarness {
  const _ImportHarness({
    required this.store,
    required this.container,
    required this.router,
  });

  final MemoryStudyStore store;
  final ProviderContainer container;
  final GoRouter router;

  void dispose() {
    router.dispose();
    container.dispose();
  }
}

class _NoopRecoveryCheckpointService extends RecoveryCheckpointService {
  _NoopRecoveryCheckpointService() : super(rootResolver: _unusedRoot);

  @override
  Future<RecoveryCheckpointReceipt> create(
    Map<String, Object?> archive, {
    required RecoveryCheckpointReason reason,
  }) async => RecoveryCheckpointReceipt(
    id: 'pipeline-checkpoint',
    reason: reason,
    createdAt: DateTime.utc(2026, 8, 3),
    byteLength: 0,
    sha256Hex: 'pipeline',
    customItemCount: 0,
    progressCount: 0,
    sessionCount: 0,
    path: 'memory',
  );
}

Future<String> _unusedRoot() async => 'memory';
