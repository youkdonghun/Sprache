import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/screens/item_editor_screen.dart';
import 'package:sprache/src/state/app_state.dart';

class _EditorLauncher extends ConsumerWidget {
  const _EditorLauncher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hydrated = ref.watch(appControllerProvider).isHydrated;
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const Key('open-full-editor'),
          onPressed: !hydrated
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: ItemEditorScreen()),
                  ),
                ),
          child: const Text('Open editor'),
        ),
      ),
    );
  }
}

Future<void> _openEditor(WidgetTester tester, MemoryStudyStore store) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [studyStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(home: _EditorLauncher()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open-full-editor')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('full editor draft is autosaved and restored after restart', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1000);
    addTearDown(tester.view.reset);
    final store = MemoryStudyStore();

    await _openEditor(tester, store);
    await tester.enterText(
      find.byKey(const Key('item-text-field')),
      'recoverable full draft',
    );
    await tester.enterText(
      find.byKey(const Key('item-translation-field')),
      '복구할 전체 초안',
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect((await store.loadItemEditorDraft())?.text, 'recoverable full draft');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _openEditor(tester, store);

    expect(find.byKey(const Key('item-editor-draft-recovery')), findsOneWidget);
    await tester.tap(find.byKey(const Key('item-editor-draft-restore')));
    await tester.pump();

    final textField = tester.widget<TextFormField>(
      find.byKey(const Key('item-text-field')),
    );
    final translationField = tester.widget<TextFormField>(
      find.byKey(const Key('item-translation-field')),
    );
    expect(textField.controller?.text, 'recoverable full draft');
    expect(translationField.controller?.text, '복구할 전체 초안');
  });

  testWidgets('changing subject refreshes groups and clears stale selection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1000);
    addTearDown(tester.view.reset);
    final store = MemoryStudyStore(
      preferences: StudyPreferences(
        activeSubjectId: 'language:en',
        learningGroups: [
          LearningGroupDefinition(
            subjectId: 'language:en',
            name: 'English only',
          ),
          LearningGroupDefinition(
            subjectId: 'language:ja',
            name: 'Japanese only',
          ),
        ],
      ),
    );

    await _openEditor(tester, store);
    var groupField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('item-group-none')),
    );
    groupField.onChanged?.call('English only');
    await tester.pump();

    final subjectField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('item-subject-field')),
    );
    subjectField.onChanged?.call('language:ja');
    await tester.pump();

    groupField = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('item-group-none')),
    );
    final dropdown = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const ValueKey('item-group-none')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    final values = dropdown.items!.map((item) => item.value).toList();
    expect(values, contains('Japanese only'));
    expect(values, isNot(contains('English only')));
    expect(groupField.initialValue, '__no_group__');
  });
}
