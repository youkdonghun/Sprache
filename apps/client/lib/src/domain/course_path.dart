import 'dart:math';

import 'learning_item.dart';
import 'progress.dart';

enum CourseLessonKind { cards, meaning, writing, sentence, listening, speaking }

extension CourseLessonKindLabel on CourseLessonKind {
  String get label => switch (this) {
    CourseLessonKind.cards => '카드로 익히기',
    CourseLessonKind.meaning => '뜻 확인하기',
    CourseLessonKind.writing => '직접 써 보기',
    CourseLessonKind.sentence => '문장 만들기',
    CourseLessonKind.listening => '듣고 이해하기',
    CourseLessonKind.speaking => '소리 내어 말하기',
  };

  String get description => switch (this) {
    CourseLessonKind.cards => '새 표현을 뜻과 발음부터 살펴봐요.',
    CourseLessonKind.meaning => '표현을 보고 알맞은 뜻을 골라요.',
    CourseLessonKind.writing => '뜻을 보고 외국어로 직접 입력해요.',
    CourseLessonKind.sentence => '빈칸과 배열로 문장 구조를 익혀요.',
    CourseLessonKind.listening => '소리를 듣고 문장을 받아써요.',
    CourseLessonKind.speaking => '목표 발음을 듣고 직접 따라 말해요.',
  };
}

class CourseUnitSnapshot {
  const CourseUnitSnapshot({
    required this.index,
    required this.title,
    required this.goal,
    required this.items,
    required this.progress,
    required this.studiedCount,
    required this.masteredCount,
    required this.accuracy,
    required this.nextLesson,
  });

  final int index;
  final String title;
  final String goal;
  final List<LearningItem> items;
  final double progress;
  final int studiedCount;
  final int masteredCount;
  final double accuracy;
  final CourseLessonKind nextLesson;

  bool get started => studiedCount > 0;
  bool get completed => progress >= 0.85;
  int get progressPercent => (progress * 100).round();

  List<LearningItem> get words => items
      .where((item) => item.kind == LearningItemKind.word)
      .toList(growable: false);

  List<LearningItem> get sentences => items
      .where((item) => item.kind == LearningItemKind.sentence)
      .toList(growable: false);
}

class CoursePathSnapshot {
  const CoursePathSnapshot({required this.units});

  final List<CourseUnitSnapshot> units;

  CourseUnitSnapshot get recommendedUnit {
    for (final unit in units) {
      if (!unit.completed) return unit;
    }
    return units.last;
  }

  double get progress {
    if (units.isEmpty) return 0;
    return units.fold<double>(0, (sum, unit) => sum + unit.progress) /
        units.length;
  }

  int get progressPercent => (progress * 100).round();
}

class CoursePathBuilder {
  const CoursePathBuilder();

  static const _definitions = [
    (title: '인사와 첫 만남', goal: '인사하고 내 이름을 소개할 수 있어요.'),
    (title: '사람과 일상', goal: '가족과 주변 사람에 대해 말할 수 있어요.'),
    (title: '시간과 하루', goal: '시간과 일상적인 행동을 표현할 수 있어요.'),
    (title: '음식과 주문', goal: '원하는 음식과 물건을 부탁할 수 있어요.'),
    (title: '이동과 여행', goal: '장소를 묻고 이동에 필요한 말을 할 수 있어요.'),
    (title: '실전 대화', goal: '도움을 요청하고 짧은 대화를 이어갈 수 있어요.'),
  ];

  CoursePathSnapshot build({
    required List<LearningItem> items,
    required Map<String, ProgressRecord> progress,
  }) {
    final starterWords = items
        .where(
          (item) =>
              item.kind == LearningItemKind.word &&
              item.id.contains('-starter-word-'),
        )
        .toList(growable: false);
    final starterSentences = items
        .where(
          (item) =>
              item.kind == LearningItemKind.sentence &&
              item.id.contains('-starter-sentence-'),
        )
        .toList(growable: false);
    final personalItems = items
        .where((item) => !item.id.contains('-starter-'))
        .toList(growable: false);
    final wordBuckets = _groupByUnit(starterWords);
    final sentenceBuckets = _groupByUnit(starterSentences);

    final units = <CourseUnitSnapshot>[];
    for (var index = 0; index < _definitions.length; index++) {
      final unitItems = <LearningItem>[
        ...wordBuckets[index],
        ...sentenceBuckets[index],
        if (index == _definitions.length - 1) ...personalItems,
      ];
      final records = unitItems
          .map((item) => progress[item.id])
          .whereType<ProgressRecord>()
          .where((record) => record.attempts > 0)
          .toList(growable: false);
      final studiedCount = records.length;
      final masteredCount = records
          .where((record) => record.status == LearningStatus.mastered)
          .length;
      final attempts = records.fold<int>(
        0,
        (sum, record) => sum + record.attempts,
      );
      final correct = records.fold<int>(
        0,
        (sum, record) => sum + record.correctCount,
      );
      final unitProgress = unitItems.isEmpty
          ? 0.0
          : unitItems.fold<double>(
                  0,
                  (sum, item) => sum + _itemMastery(progress[item.id]),
                ) /
                unitItems.length;
      final accuracy = attempts == 0 ? 0.0 : correct / attempts;
      final definition = _definitions[index];
      units.add(
        CourseUnitSnapshot(
          index: index,
          title: definition.title,
          goal: definition.goal,
          items: List.unmodifiable(unitItems),
          progress: unitProgress.clamp(0, 1),
          studiedCount: studiedCount,
          masteredCount: masteredCount,
          accuracy: accuracy,
          nextLesson: _nextLesson(
            progress: unitProgress,
            accuracy: accuracy,
            hasSentences: unitItems.any(
              (item) => item.kind == LearningItemKind.sentence,
            ),
          ),
        ),
      );
    }
    return CoursePathSnapshot(units: List.unmodifiable(units));
  }

  List<List<LearningItem>> _groupByUnit(List<LearningItem> items) {
    final buckets = List.generate(
      _definitions.length,
      (_) => <LearningItem>[],
      growable: false,
    );
    var fallbackIndex = 0;
    for (final item in items) {
      final unitTag = item.tags
          .where((tag) => tag.startsWith('unit-'))
          .firstOrNull;
      final taggedIndex = unitTag == null
          ? null
          : int.tryParse(unitTag.substring('unit-'.length));
      final index =
          taggedIndex != null &&
              taggedIndex >= 0 &&
              taggedIndex < buckets.length
          ? taggedIndex
          : fallbackIndex++ % buckets.length;
      buckets[index].add(item);
    }
    return buckets;
  }

  double _itemMastery(ProgressRecord? record) {
    if (record == null || record.attempts == 0) return 0;
    final statusScore = switch (record.status) {
      LearningStatus.newItem => 0.15,
      LearningStatus.learning => 0.35,
      LearningStatus.review => 0.65,
      LearningStatus.mastered => 1.0,
      LearningStatus.suspended => 0.0,
    };
    final accuracyBonus = record.accuracy * 0.15;
    return min(1.0, statusScore + accuracyBonus);
  }

  CourseLessonKind _nextLesson({
    required double progress,
    required double accuracy,
    required bool hasSentences,
  }) {
    if (progress < 0.08) return CourseLessonKind.cards;
    if (progress < 0.25 || accuracy < 0.6) return CourseLessonKind.meaning;
    if (progress < 0.45) return CourseLessonKind.writing;
    if (progress < 0.62 && hasSentences) return CourseLessonKind.sentence;
    if (progress < 0.78) return CourseLessonKind.listening;
    return CourseLessonKind.speaking;
  }
}

String courseLessonRoute(CourseLessonKind lesson, int unitIndex) {
  final unitQuery = 'unit=$unitIndex';
  return switch (lesson) {
    CourseLessonKind.cards => '/cards?kind=mixed&$unitQuery',
    CourseLessonKind.meaning => '/study?mode=meaning&$unitQuery',
    CourseLessonKind.writing => '/study?mode=production&$unitQuery',
    CourseLessonKind.sentence => '/study?mode=cloze&$unitQuery',
    CourseLessonKind.listening => '/study?mode=listening&$unitQuery',
    CourseLessonKind.speaking => '/pronunciation?$unitQuery',
  };
}
