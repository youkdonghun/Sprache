import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/mission_script.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test('mission progress survives restart and completion clears it', () async {
    final firstStore = MemoryStudyStore();
    final first = AppController(firstStore);
    await _waitFor(() => first.state.isHydrated);
    final checkpoint = MissionProgressCheckpoint(
      courseId: first.state.activeCourseId,
      unitIndex: 0,
      phraseIndex: 1,
      sceneId: 'unit-0-scene-0-coached',
      coachedTurns: 1,
      decision: MissionCheckpointDecision.coachedHelp,
      updatedAt: DateTime.utc(2026, 8, 3, 11),
    );

    first.saveMissionProgress(checkpoint);
    await _waitFor(
      () => firstStore.savedPreferences.missionProgressCheckpoints.containsKey(
        checkpoint.storageKey,
      ),
    );
    final persisted = StudyPreferences.fromJson(
      firstStore.savedPreferences.toJson(),
    );
    first.dispose();

    final restarted = AppController(MemoryStudyStore(preferences: persisted));
    await _waitFor(() => restarted.state.isHydrated);

    expect(restarted.missionProgressFor(0)?.phraseIndex, 1);
    expect(restarted.missionProgressFor(0)?.coachedTurns, 1);
    expect(
      restarted.missionProgressFor(0)?.decision,
      MissionCheckpointDecision.coachedHelp,
    );

    restarted.completeMission(0);
    expect(restarted.missionProgressFor(0), isNull);
    expect(restarted.hasCompletedMission(0), isTrue);
    restarted.dispose();
  });

  test('invalid mission checkpoint records do not discard healthy records', () {
    final healthy = MissionProgressCheckpoint(
      courseId: 'ko-en',
      unitIndex: 0,
      phraseIndex: 0,
      sceneId: 'unit-0-scene-0',
      coachedTurns: 0,
      updatedAt: DateTime.utc(2026, 8, 3, 11),
    );
    final json = const StudyPreferences().toJson()
      ..['missionProgressCheckpoints'] = {
        healthy.storageKey: healthy.toJson(),
        'ko-en:1': <String, Object?>{'courseId': 'ko-en', 'unitIndex': -1},
      };

    final restored = StudyPreferences.fromJson(json);

    expect(restored.missionProgressCheckpoints, {
      healthy.storageKey: isA<MissionProgressCheckpoint>(),
    });
  });
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(condition(), isTrue);
}
