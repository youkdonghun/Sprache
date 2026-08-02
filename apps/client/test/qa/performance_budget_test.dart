import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/domain/global_search.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/learning_insights.dart';
import 'package:sprache/src/domain/learning_item.dart';
import 'package:sprache/src/domain/study_history.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/domain/study_subject.dart';
import 'package:sprache/src/import/content_import_parser.dart';

const _importBudget = Duration(seconds: 20);
const _searchBudget = Duration(seconds: 15);
const _statisticsBudget = Duration(seconds: 5);

void main() {
  test(
    '20,000-row CSV import stays within the release performance budget',
    () {
      final csv = StringBuffer('type,term,meaning,part_of_speech\n');
      for (var index = 0; index < 20000; index++) {
        csv.writeln('word,term-$index,뜻-$index,noun');
      }

      final stopwatch = Stopwatch()..start();
      final preview = const ContentImportParser().parseCsv(
        csv.toString(),
        defaultLanguage: LanguageTag.english,
      );
      stopwatch.stop();

      expect(preview.entries, hasLength(20000));
      expect(preview.issues, isEmpty);
      expect(
        stopwatch.elapsed,
        lessThanOrEqualTo(_importBudget),
        reason: '20k import took ${stopwatch.elapsedMilliseconds} ms',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    '50,000-item global search stays within the release performance budget',
    () {
      final subject = StudySubject.language(LanguageTag.english);
      final items = List<LearningItem>.generate(
        50000,
        (index) => LearningItem(
          id: 'search-$index',
          kind: LearningItemKind.word,
          learningLanguage: LanguageTag.english,
          text: index == 49999 ? 'release needle' : 'ordinary term $index',
          translations: ['검색 $index'],
          acceptedAnswers: ['검색 $index'],
          tags: [index.isEven ? 'even' : 'odd'],
        ),
        growable: false,
      );

      final stopwatch = Stopwatch()..start();
      final results = searchAcrossSubjects(
        query: 'release needle',
        subjects: [subject],
        items: items,
      );
      stopwatch.stop();

      expect(results.whereType<GlobalItemSearchResult>(), hasLength(1));
      expect(
        (results.single as GlobalItemSearchResult).item.id,
        'search-49999',
      );
      expect(
        stopwatch.elapsed,
        lessThanOrEqualTo(_searchBudget),
        reason: '50k search took ${stopwatch.elapsedMilliseconds} ms',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    '10,000-session statistics stay within the release performance budget',
    () {
      final now = DateTime.utc(2026, 8, 3, 12);
      final sessions = List<StudySessionSummary>.generate(10000, (index) {
        final startedAt = now.subtract(
          Duration(days: index % 365, minutes: (index % 12) + 1),
        );
        return StudySessionSummary(
          sessionId: 'stats-$index',
          courseId: index.isEven ? 'ko-en' : 'ko-ja',
          startedAt: startedAt,
          endedAt: startedAt.add(Duration(minutes: (index % 12) + 1)),
          correctCount: (index % 8) + 1,
          wrongCount: index % 3,
          earnedXp: (index % 20) + 1,
          mode: StudyMode.values[index % StudyMode.values.length],
        );
      }, growable: false);

      final stopwatch = Stopwatch()..start();
      final insights = LearningInsights.build(
        sessions: sessions,
        items: const [],
        progress: const {},
        now: now,
        range: LearningInsightRange.all,
      );
      stopwatch.stop();

      expect(insights.sessionCount, 10000);
      expect(insights.subjects, hasLength(2));
      expect(insights.attempts, greaterThan(0));
      expect(
        stopwatch.elapsed,
        lessThanOrEqualTo(_statisticsBudget),
        reason: '10k statistics took ${stopwatch.elapsedMilliseconds} ms',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
