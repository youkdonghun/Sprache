import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/backup/study_data_xlsx_exporter.dart';
import 'package:sprache/src/domain/import_distribution.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/import/content_import_parser.dart';

void main() {
  test('XLSX export is a styled workbook that round-trips every field', () {
    final items = [
      LearningItem(
        id: 'xlsx-word',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.japanese,
        subjectId: 'general:business-trip',
        text: '予約 & <確認>',
        translations: const ['예약', '예약 확인'],
        acceptedAnswers: const ['예약', '예약 확인', '예매'],
        readings: const [
          Reading(scheme: ReadingScheme.kana, value: 'よやく'),
          Reading(scheme: ReadingScheme.romaji, value: 'yoyaku'),
          Reading(scheme: ReadingScheme.hangul, value: '요야쿠'),
        ],
        example: '予約を確認します。',
        exampleTranslation: '예약을 확인합니다.',
        partOfSpeech: PartOfSpeech.noun,
        tags: [
          learningGroupTag('출장 준비'),
          importDistributionTag('business-trip'),
          'JLPT N4',
        ],
        level: '초급',
        priority: 9,
        source: const ContentSource(
          name: '내 노트',
          license: 'private',
          sourceVersion: '2026-07',
          contentVersion: 4,
          sourceId: 'note-7',
          sourceUrl: 'https://example.com/notes/7?x=1&y=2',
          author: '학습자',
          attribution: '학습자 · 내 노트 · private',
        ),
      ),
      LearningItem(
        id: 'xlsx-sentence',
        kind: LearningItemKind.sentence,
        learningLanguage: LanguageTag.english,
        subjectId: 'general:baseball',
        text: 'OPS is on-base plus slugging.',
        translations: const ['OPS는 출루율과 장타율의 합이다.'],
        acceptedAnswers: const ['OPS는 출루율과 장타율의 합이다.'],
        sentenceTokens: const ['OPS', 'is', 'on-base', 'plus', 'slugging.'],
        tags: [learningGroupTag('야구 지표'), '기초'],
        level: '입문',
        priority: 6,
      ),
    ];

    final bytes = const StudyDataXlsxExporter().encode(
      items,
      exportedAt: DateTime.utc(2026, 7, 29, 12),
    );
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final names = archive.files.map((file) => file.name).toSet();
    final sheetXml = utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
    );

    expect(bytes.take(4), [0x50, 0x4B, 0x03, 0x04]);
    expect(
      names,
      containsAll({
        '[Content_Types].xml',
        '_rels/.rels',
        'docProps/app.xml',
        'docProps/core.xml',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/styles.xml',
        'xl/worksheets/sheet1.xml',
      }),
    );
    expect(sheetXml, contains('<pane ySplit="1"'));
    expect(sheetXml, contains('<autoFilter ref="A1:AB3"/>'));
    expect(sheetXml, contains('&amp;'));
    expect(sheetXml, contains('<c r="R2" s="3" t="n"><v>9</v></c>'));
    expect(sheetXml, contains('<c r="Z2" s="3" t="n"><v>4</v></c>'));
    expect(sheetXml, isNot(contains('<f>')));

    final preview = const ContentImportParser().parseExcel(
      bytes,
      defaultLanguage: LanguageTag.korean,
    );

    expect(preview.issues, isEmpty);
    expect(preview.duplicates, isEmpty);
    expect(preview.items, hasLength(3));

    final word = preview.items.firstWhere((item) => item.id == 'xlsx-word');
    expect(word.effectiveSubjectId, 'general:business-trip');
    expect(word.text, '予約 & <確認>');
    expect(word.translations, containsAll(['예약', '예약 확인']));
    expect(word.acceptedAnswers, containsAll(['예약', '예약 확인', '예매']));
    expect(word.reading(ReadingScheme.kana), 'よやく');
    expect(word.reading(ReadingScheme.romaji), 'yoyaku');
    expect(word.reading(ReadingScheme.hangul), '요야쿠');
    expect(word.example, '予約を確認します。');
    expect(word.exampleTranslation, '예약을 확인합니다.');
    expect(word.partOfSpeech, PartOfSpeech.noun);
    expect(learningGroupsOf(word), {'출장 준비'});
    expect(importDistributionKeyOf(word), 'business-trip');
    expect(word.tags, contains('JLPT N4'));
    expect(word.level, '초급');
    expect(word.priority, 9);
    expect(word.source.sourceId, 'note-7');
    expect(word.source.sourceUrl, 'https://example.com/notes/7?x=1&y=2');
    expect(word.source.contentVersion, 4);
    expect(
      preview.items.where(
        (item) =>
            item.kind == LearningItemKind.sentence && item.text == '予約を確認します。',
      ),
      hasLength(1),
    );

    final sentence = preview.items.firstWhere(
      (item) => item.id == 'xlsx-sentence',
    );
    expect(sentence.effectiveSubjectId, 'general:baseball');
    expect(sentence.sentenceTokens, [
      'OPS',
      'is',
      'on-base',
      'plus',
      'slugging.',
    ]);
    expect(learningGroupsOf(sentence), {'야구 지표'});
  });
}
