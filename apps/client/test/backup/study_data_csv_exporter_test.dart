import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/backup/study_data_csv_exporter.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/import/content_import_parser.dart';

void main() {
  test('CSV export can be imported again with groups and readings intact', () {
    final item = LearningItem(
      id: 'csv-roundtrip',
      kind: LearningItemKind.word,
      learningLanguage: LanguageTag.japanese,
      subjectId: 'general:business-trip',
      text: '予約',
      translations: const ['예약', '예약하기'],
      acceptedAnswers: const ['예약', '예약하기', '예매'],
      readings: const [
        Reading(scheme: ReadingScheme.kana, value: 'よやく'),
        Reading(scheme: ReadingScheme.romaji, value: 'yoyaku'),
        Reading(scheme: ReadingScheme.hangul, value: '요야쿠'),
      ],
      partOfSpeech: PartOfSpeech.noun,
      tags: [learningGroupTag('여행'), 'JLPT N4'],
      level: '초급',
      priority: 7,
      source: const ContentSource(
        name: '내 노트',
        license: 'private',
        sourceVersion: '2026-07',
        contentVersion: 3,
        sourceId: 'note-7',
        sourceUrl: 'https://example.com/notes/7',
        author: '학습자',
        attribution: '학습자 · 내 노트 · private',
      ),
    );

    final csv = const StudyDataCsvExporter().encode([item]);
    final preview = const ContentImportParser().parseCsv(
      csv,
      defaultLanguage: LanguageTag.english,
    );
    final restored = preview.items.single;

    expect(csv.codeUnitAt(0), 0xFEFF);
    expect(restored.id, item.id);
    expect(restored.effectiveSubjectId, 'general:business-trip');
    expect(restored.translations, containsAll(item.translations));
    expect(restored.acceptedAnswers, containsAll(item.acceptedAnswers));
    expect(restored.reading(ReadingScheme.kana), 'よやく');
    expect(restored.reading(ReadingScheme.hangul), '요야쿠');
    expect(learningGroupsOf(restored), {'여행'});
    expect(restored.tags, contains('JLPT N4'));
    expect(restored.source.contentVersion, 3);
    expect(restored.source.sourceId, 'note-7');
    expect(restored.source.sourceUrl, 'https://example.com/notes/7');
    expect(restored.source.author, '학습자');
    expect(restored.source.attribution, '학습자 · 내 노트 · private');
  });
}
