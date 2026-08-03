import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/sample_content.dart';
import 'package:sprache/src/domain/course_path.dart';
import 'package:sprache/src/domain/language.dart';
import 'package:sprache/src/domain/mission_script.dart';
import 'package:sprache/src/domain/progress.dart';

void main() {
  const pathBuilder = CoursePathBuilder();
  const scriptBuilder = MissionScriptBuilder();

  CourseUnitSnapshot firstEnglishUnit() => pathBuilder
      .build(
        items: sampleContent
            .where((item) => item.learningLanguage == LanguageTag.english)
            .toList(growable: false),
        progress: const {},
      )
      .units
      .first;

  test('builds deterministic local-data scenes with two outcome branches', () {
    final unit = firstEnglishUnit();
    final first = scriptBuilder.build(
      unit: unit,
      setting: '첫 만남',
      goal: '인사하기',
    );
    final second = scriptBuilder.build(
      unit: unit,
      setting: '첫 만남',
      goal: '인사하기',
    );

    expect(first.scenes, hasLength(greaterThanOrEqualTo(3)));
    expect(
      first.scenes.map((scene) => scene.options.map((option) => option.id)),
      second.scenes.map((scene) => scene.options.map((option) => option.id)),
    );
    final scene = first.scenes.first;
    final goal = scene.options.singleWhere((option) => option.isGoal);
    final alternative = scene.options.singleWhere((option) => !option.isGoal);
    expect(scene.choose(goal.id).branch, MissionBranch.fluent);
    expect(scene.choose(alternative.id).branch, MissionBranch.coached);
    expect(scene.requestCoaching().usedCoaching, isTrue);
    expect(first.endingFor(coachedTurns: 0).title, contains('막힘없이'));
    expect(first.endingFor(coachedTurns: 1).title, contains('도움'));
  });

  test('prioritizes a weak local phrase in the first mission scene', () {
    final unit = firstEnglishUnit();
    final weak = unit.sentences[1];
    final script = scriptBuilder.build(
      unit: unit,
      setting: '첫 만남',
      goal: '인사하기',
      progress: {
        weak.id: ProgressRecord(
          itemId: weak.id,
          status: LearningStatus.learning,
          wrongCount: 2,
          lastResult: ReviewRating.again,
        ),
      },
    );

    expect(script.scenes.first.target.id, weak.id);
    expect(
      script.scenes.first.situationPrompt,
      contains(weak.primaryTranslation),
    );
  });
}
