import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/device_preferences.dart';
import 'package:sprache/src/domain/global_search.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_subject.dart';
import 'package:sprache/src/import/content_import_parser.dart';
import 'package:sprache/src/services/study_notification_service.dart';
import 'package:sprache/src/sync/snapshot_validator.dart';

void main() {
  final corpus = _loadCorpus();

  test('fixed corpus identity prevents silent random-seed drift', () {
    expect(corpus['format'], 'sprache-fixed-fuzz-corpus-v1');
    expect(corpus['seed'], 131055);
  });

  test('snapshot validator survives every fixed fuzz case', () {
    const validator = SyncSnapshotValidator();
    for (final raw in corpus['snapshot']! as List<Object?>) {
      final fuzzCase = _map(raw);
      final value = _map(fuzzCase['value']);
      final accepted = fuzzCase['accepted']! as bool;
      if (accepted) {
        expect(
          () => validator.validate(value),
          returnsNormally,
          reason: fuzzCase['id']! as String,
        );
      } else {
        expect(
          () => validator.validate(value),
          throwsA(isA<RemoteSnapshotValidationException>()),
          reason: fuzzCase['id']! as String,
        );
      }
    }
  });

  test('all import decoders survive every fixed fuzz case', () {
    const parser = ContentImportParser();
    for (final raw in corpus['imports']! as List<Object?>) {
      final fuzzCase = _map(raw);
      final format = fuzzCase['format']! as String;
      final payload = fuzzCase['payload']! as String;
      final accepted = fuzzCase['accepted']! as bool;

      ImportPreview parse() => switch (format) {
        'csv' => parser.parseCsv(payload, defaultLanguage: LanguageTag.english),
        'tsv' => parser.parseCsv(
          payload,
          defaultLanguage: LanguageTag.english,
          delimiter: '\t',
        ),
        'json' => parser.parseJson(
          payload,
          defaultLanguage: LanguageTag.english,
        ),
        'jsonl' => parser.parseJsonLines(
          payload,
          defaultLanguage: LanguageTag.english,
        ),
        _ => throw StateError('Unknown corpus format: $format'),
      };

      if (!accepted) {
        ImportPreview? rejectedPreview;
        Object? rejection;
        try {
          rejectedPreview = parse();
        } on Object catch (error) {
          rejection = error;
        }
        if (rejection == null) {
          expect(
            rejectedPreview!.entries,
            isEmpty,
            reason: fuzzCase['id']! as String,
          );
          expect(rejectedPreview.issues, isNotEmpty);
        }
        continue;
      }
      final preview = parse();
      expect(
        preview.entries.length,
        greaterThanOrEqualTo(fuzzCase['minimumEntries']! as int),
        reason: fuzzCase['id']! as String,
      );
    }
  });

  test('global search survives every fixed query and stays deterministic', () {
    final subject = StudySubject.language(LanguageTag.english);
    const items = [
      LearningItem(
        id: 'item-cafe',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'café',
        translations: ['카페'],
        acceptedAnswers: ['카페'],
      ),
      LearningItem(
        id: 'item-book',
        kind: LearningItemKind.word,
        learningLanguage: LanguageTag.english,
        text: 'book',
        translations: ['책'],
        acceptedAnswers: ['책'],
      ),
    ];
    for (final raw in corpus['search']! as List<Object?>) {
      final fuzzCase = _map(raw);
      final first = searchAcrossSubjects(
        query: fuzzCase['query']! as String,
        subjects: [subject],
        items: items,
        favoriteItemIds: const {'item-cafe'},
      );
      final second = searchAcrossSubjects(
        query: fuzzCase['query']! as String,
        subjects: [subject],
        items: items,
        favoriteItemIds: const {'item-cafe'},
      );
      final firstIds = [
        for (final result in first.whereType<GlobalItemSearchResult>())
          result.item.id,
      ];
      final secondIds = [
        for (final result in second.whereType<GlobalItemSearchResult>())
          result.item.id,
      ];
      expect(
        firstIds,
        fuzzCase['expectedIds'],
        reason: fuzzCase['id'] as String,
      );
      expect(secondIds, firstIds, reason: '${fuzzCase['id']} determinism');
    }
  });

  test('notification action parser survives every fixed payload', () {
    final receivedAt = DateTime.utc(2026, 8, 3, 3, 10);
    for (final raw in corpus['notificationActions']! as List<Object?>) {
      final fuzzCase = _map(raw);
      final action = parseStudyNotificationAction(
        actionId: fuzzCase['actionId'] as String?,
        payload: fuzzCase['payload'] as String?,
        receivedAt: receivedAt,
        notificationId: 31,
      );
      expect(
        action?.kind.name,
        fuzzCase['expectedKind'],
        reason: fuzzCase['id']! as String,
      );
      if (action != null) {
        expect(action.receivedAt, receivedAt);
        expect(action.notificationId, 31);
      }
    }
  });

  test('device-only settings survive every fixed malformed shape', () {
    for (final raw in corpus['deviceSettings']! as List<Object?>) {
      final fuzzCase = _map(raw);
      final restored = DevicePreferences.fromJson(_map(fuzzCase['value']));
      final expected = _map(fuzzCase['expected']);
      expect(
        restored.notifications.enabled,
        expected['enabled'],
        reason: fuzzCase['id']! as String,
      );
      expect(
        restored.notifications.quietStartMinutes,
        expected['quietStartMinutes'],
      );
      expect(
        restored.notifications.quietEndMinutes,
        expected['quietEndMinutes'],
      );
      expect(restored.voice.pitch, expected['pitch']);
      expect(restored.privacy.privacyMode, expected['privacyMode']);
      expect(
        () => DevicePreferences.fromJson(restored.toJson()),
        returnsNormally,
      );
    }
  });
}

Map<String, Object?> _loadCorpus() {
  final file = File('test/fixtures/qa/fuzz-corpus-v1.json');
  final decoded = jsonDecode(file.readAsStringSync());
  return _map(decoded);
}

Map<String, Object?> _map(Object? value) =>
    Map<String, Object?>.from(value! as Map);
