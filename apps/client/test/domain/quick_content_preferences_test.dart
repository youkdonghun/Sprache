import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/quick_content_preferences.dart';

void main() {
  test('quick content preferences remember kind and recent tags', () {
    final preferences = const QuickContentLocalPreferences()
        .rememberKind(subjectId: 'language:en', kind: LearningItemKind.sentence)
        .rememberTags(subjectId: 'language:en', tags: const ['여행', '시험', '여행']);

    expect(
      preferences.lastKindBySubject['language:en'],
      LearningItemKind.sentence,
    );
    expect(preferences.recentTagsBySubject['language:en'], const ['여행', '시험']);

    final restored = QuickContentLocalPreferences.fromJson(
      preferences.toJson(),
    );
    expect(restored.toJson(), preferences.toJson());
  });

  test('malformed quick preferences keep valid entries and enforce limits', () {
    final preferences = QuickContentLocalPreferences.fromJson({
      'lastKindBySubject': {
        'language:en': 'sentence',
        'language:ja': 'unknown',
      },
      'recentTagsBySubject': {
        'language:en': [...List.generate(20, (index) => 'tag-$index'), 42, ''],
        'language:ja': 'broken',
      },
    });

    expect(preferences.lastKindBySubject, const {
      'language:en': LearningItemKind.sentence,
    });
    expect(preferences.recentTagsBySubject['language:en'], hasLength(12));
    expect(preferences.recentTagsBySubject.containsKey('language:ja'), isFalse);
  });

  test('named templates persist metadata without source text or meanings', () {
    final now = DateTime.utc(2026, 8, 3, 9);
    final template = QuickContentTemplate(
      id: 'travel',
      name: '여행 단어',
      kind: LearningItemKind.word,
      partOfSpeech: PartOfSpeech.noun,
      group: '여행',
      tags: const ['회화', '여행'],
      favorite: true,
      priority: 4,
      createdAt: now,
      updatedAt: now,
    );
    final preferences = const QuickContentLocalPreferences().saveTemplate(
      subjectId: 'language:en',
      template: template,
    );

    final json = preferences.toJson();
    final encoded = json.toString();
    expect(encoded, isNot(contains('sourceText')));
    expect(encoded, isNot(contains('meanings')));

    final restored = QuickContentLocalPreferences.fromJson(json);
    final saved = restored.orderedTemplates('language:en').single;
    expect(saved.name, '여행 단어');
    expect(saved.group, '여행');
    expect(saved.tags, const ['회화', '여행']);
    expect(saved.favorite, isTrue);
    expect(saved.priority, 4);
    expect(restored.toJson(), preferences.toJson());
  });

  test('templates can be renamed duplicated pinned sorted and deleted', () {
    QuickContentTemplate template(String id, String name, DateTime at) =>
        QuickContentTemplate(
          id: id,
          name: name,
          kind: LearningItemKind.word,
          partOfSpeech: PartOfSpeech.noun,
          group: null,
          tags: const [],
          favorite: false,
          priority: 0,
          createdAt: at,
          updatedAt: at,
        );

    var preferences = const QuickContentLocalPreferences()
        .saveTemplate(
          subjectId: 'language:en',
          template: template('b', 'Beta', DateTime.utc(2026, 1, 2)),
        )
        .saveTemplate(
          subjectId: 'language:en',
          template: template('a', 'Alpha', DateTime.utc(2026, 1, 1)),
        );
    preferences = preferences
        .renameTemplate(
          subjectId: 'language:en',
          id: 'b',
          name: 'Gamma',
          at: DateTime.utc(2026, 1, 4),
        )
        .duplicateTemplate(
          subjectId: 'language:en',
          sourceId: 'a',
          newId: 'a-copy',
          newName: 'Alpha Copy',
          at: DateTime.utc(2026, 1, 5),
        )
        .toggleTemplatePinned(
          subjectId: 'language:en',
          id: 'b',
          at: DateTime.utc(2026, 1, 6),
        )
        .copyWith(templateSort: QuickContentTemplateSort.name);

    expect(
      preferences
          .orderedTemplates('language:en')
          .map((template) => template.name),
      const ['Gamma', 'Alpha', 'Alpha Copy'],
    );
    expect(
      preferences.templatesBySubject['language:en']!
          .singleWhere((template) => template.id == 'a-copy')
          .pinned,
      isFalse,
    );

    preferences = preferences.deleteTemplate(subjectId: 'language:en', id: 'b');
    expect(
      preferences.templatesBySubject['language:en']!.map(
        (template) => template.id,
      ),
      isNot(contains('b')),
    );
  });

  test('template parser isolates damage and template count stays bounded', () {
    QuickContentTemplate template(int index, {bool pinned = false}) =>
        QuickContentTemplate(
          id: 'id-$index',
          name: 'template-$index',
          kind: LearningItemKind.word,
          partOfSpeech: PartOfSpeech.noun,
          group: null,
          tags: const [],
          favorite: false,
          priority: index,
          pinned: pinned,
          createdAt: DateTime.utc(2026, 1, 1).add(Duration(days: index)),
          updatedAt: DateTime.utc(2026, 1, 1).add(Duration(days: index)),
        );
    var preferences = const QuickContentLocalPreferences();
    for (var index = 0; index < quickContentTemplateLimit + 8; index++) {
      preferences = preferences.saveTemplate(
        subjectId: 'language:en',
        template: template(index, pinned: index == 0),
      );
    }
    expect(
      preferences.templatesBySubject['language:en'],
      hasLength(quickContentTemplateLimit),
    );
    expect(
      preferences.templatesBySubject['language:en']!.any(
        (template) => template.id == 'id-0',
      ),
      isTrue,
    );

    final valid = template(1).toJson();
    final restored = QuickContentLocalPreferences.fromJson({
      'templatesBySubject': {
        'language:en': [
          <Object?, Object?>{...valid, 7: 'ignored extra key'},
          {'id': 7},
          'broken',
        ],
      },
      'templateSort': 'unknown',
    });
    expect(restored.templatesBySubject['language:en'], hasLength(1));
    expect(restored.templateSort, QuickContentTemplateSort.recent);
  });
}
