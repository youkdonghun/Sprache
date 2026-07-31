import 'dart:io';

import 'package:sprache/src/backup/study_data_xlsx_exporter.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_group.dart';
import 'package:sprache/src/domain/learning_item.dart';

void main(List<String> arguments) {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/generate_xlsx_export_sample.dart PATH',
    );
    exitCode = 64;
    return;
  }
  final output = File(arguments.single);
  output.parent.createSync(recursive: true);
  output.writeAsBytesSync(
    const StudyDataXlsxExporter().encode([
      LearningItem(
        id: 'sample-trip-ja',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.japanese,
        subjectId: 'general:business-trip',
        text: '予約',
        translations: ['예약', '예약하기'],
        acceptedAnswers: ['예약', '예약하기', '예매'],
        readings: [
          Reading(scheme: ReadingScheme.kana, value: 'よやく'),
          Reading(scheme: ReadingScheme.romaji, value: 'yoyaku'),
        ],
        example: '予約を確認します。',
        exampleTranslation: '예약을 확인합니다.',
        partOfSpeech: PartOfSpeech.noun,
        tags: [learningGroupTag('출장 준비'), 'JLPT N4'],
        level: '초급',
        priority: 9,
      ),
      LearningItem(
        id: 'sample-baseball-en',
        kind: LearningItemKind.sentence,
        learningLanguage: LanguageTag.english,
        subjectId: 'general:baseball',
        text: 'OPS is on-base percentage plus slugging percentage.',
        translations: ['OPS는 출루율과 장타율의 합이다.'],
        acceptedAnswers: ['OPS는 출루율과 장타율의 합이다.'],
        sentenceTokens: [
          'OPS',
          'is',
          'on-base',
          'percentage',
          'plus',
          'slugging',
          'percentage.',
        ],
        tags: [learningGroupTag('야구 지표'), '기초'],
        level: '입문',
        priority: 7,
      ),
      LearningItem(
        id: 'sample-german-mail',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.german,
        subjectId: 'language:de',
        text: 'Rückmeldung',
        translations: ['회신', '피드백'],
        acceptedAnswers: ['회신', '피드백'],
        partOfSpeech: PartOfSpeech.noun,
        tags: [learningGroupTag('회사 이메일')],
        level: 'A2',
        priority: 6,
      ),
    ], exportedAt: DateTime.utc(2026, 7, 29, 12)),
  );
  stdout.writeln(output.path);
}
