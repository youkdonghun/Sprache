import 'package:flutter_test/flutter_test.dart';
import 'package:sprache/src/data/study_store.dart';
import 'package:sprache/src/domain/content_management.dart';
import 'package:sprache/src/domain/onboarding_profile.dart';
import 'package:sprache/src/domain/session_enhancements.dart';
import 'package:sprache/src/domain/smart_collection.dart';
import 'package:sprache/src/domain/study_interaction_preferences.dart';
import 'package:sprache/src/domain/study_preferences.dart';
import 'package:sprache/src/state/app_state.dart';

void main() {
  test('snapshot v2 writes new preferences and keeps reading v1', () async {
    final controller = AppController(
      MemoryStudyStore(
        preferences: StudyPreferences(
          onboardingCompleted: true,
          onboardingProfile: const OnboardingProfile(
            purpose: LearningPurpose.exam,
            level: SelfAssessedLevel.intermediate,
            dailyMinutes: 15,
            entryChoice: OnboardingEntryChoice.importMyData,
          ),
          sessionPlan: StudySessionPlan(
            subjectId: 'language:en',
            groupIds: const {'group-a', 'group-b'},
            lengthMode: StudySessionLengthMode.timeBudget,
            timeBudgetMinutes: 10,
            recordProgress: false,
            answerDirectionOverride: StudyAnswerDirection.mixed,
            gradingStrictness: StudyGradingStrictness.strict,
            examSchedule: ExamSchedule(
              targetDate: DateTime.utc(2026, 9, 1),
              dailyCap: 40,
            ),
            backlogRecovery: const BacklogRecoverySettings(
              enabled: true,
              dailyLimit: 18,
            ),
          ),
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final v2 = controller.exportSyncSnapshot();
    expect(v2['schemaVersion'], 2);
    final settings = StudyPreferences.fromJson(
      Map<String, Object?>.from(v2['settings']! as Map),
    );
    expect(settings.onboardingProfile.purpose, LearningPurpose.exam);
    expect(settings.sessionPlan.groupIds, {'group-a', 'group-b'});
    expect(settings.sessionPlan.lengthMode, StudySessionLengthMode.timeBudget);
    expect(settings.sessionPlan.recordProgress, isFalse);
    expect(
      settings.sessionPlan.answerDirectionOverride,
      StudyAnswerDirection.mixed,
    );
    expect(settings.sessionPlan.examSchedule?.dailyCap, 40);
    expect(settings.sessionPlan.backlogRecovery.dailyLimit, 18);

    final v1 = Map<String, Object?>.from(v2)..['schemaVersion'] = 1;
    await expectLater(controller.mergeRemoteSnapshot(v1), completes);

    controller.dispose();
  });

  test('v2 merge preserves structured records and import undo state', () async {
    final early = DateTime.utc(2026, 7, 30, 8);
    final later = DateTime.utc(2026, 7, 31, 8);
    final localReceipt = ImportBatchReceipt(
      importId: 'import-shared',
      fileName: 'words.xlsx',
      subjectId: 'language:en',
      distributionKey: 'office',
      addedCount: 1,
      mergedCount: 0,
      skippedCount: 0,
      errorCount: 0,
      changes: const [
        ImportBatchChange(
          itemId: 'word-1',
          kind: ImportChangeKind.added,
          after: {'id': 'word-1'},
        ),
      ],
      createdAt: early,
    );
    final localPreferences = StudyPreferences(
      settingsUpdatedAt: early,
      smartCollections: [
        SmartCollectionDefinition(
          id: 'smart-local',
          subjectId: 'language:en',
          name: '로컬 취약',
          updatedAt: early,
        ),
      ],
      trashEntries: [
        TrashEntry(
          entryId: 'trash-local',
          itemId: 'word-deleted',
          subjectId: 'language:en',
          item: const {'id': 'word-deleted'},
          wasFavorite: false,
          wasExcluded: false,
          deletedAt: early,
        ),
      ],
      importMappingPresets: [
        ImportMappingPreset(
          id: 'mapping-local',
          name: '로컬 매핑',
          columns: const {'question': 'A', 'answer': 'B'},
          updatedAt: early,
        ),
      ],
      importReceipts: [localReceipt],
      contentCorrections: [
        ContentCorrection(
          itemId: 'pack-word',
          field: 'translation',
          note: '로컬 교정',
          updatedAt: early,
        ),
      ],
    );
    final remotePreferences = StudyPreferences(
      onboardingCompleted: true,
      onboardingProfile: const OnboardingProfile(
        purpose: LearningPurpose.travel,
        level: SelfAssessedLevel.elementary,
        dailyMinutes: 10,
      ),
      settingsUpdatedAt: later,
      smartCollections: [
        SmartCollectionDefinition(
          id: 'smart-drive',
          subjectId: 'language:en',
          name: 'Drive 복습',
          updatedAt: later,
        ),
      ],
      trashEntries: [
        TrashEntry(
          entryId: 'trash-drive',
          itemId: 'word-drive-deleted',
          subjectId: 'language:en',
          item: const {'id': 'word-drive-deleted'},
          wasFavorite: true,
          wasExcluded: false,
          deletedAt: later,
        ),
      ],
      importMappingPresets: [
        ImportMappingPreset(
          id: 'mapping-drive',
          name: 'Drive 매핑',
          columns: const {'question': '표현', 'answer': '뜻'},
          updatedAt: later,
        ),
      ],
      importReceipts: [localReceipt.markUndone(later)],
      contentCorrections: [
        ContentCorrection(
          itemId: 'pack-sentence',
          field: 'reading',
          note: 'Drive 교정',
          updatedAt: later,
        ),
      ],
    );
    final controller = AppController(
      MemoryStudyStore(preferences: localPreferences),
    );
    await Future<void>.delayed(Duration.zero);
    final remote = controller.exportSyncSnapshot()
      ..['schemaVersion'] = 2
      ..['updatedAt'] = later.toIso8601String()
      ..['settings'] = remotePreferences.toJson();

    await controller.mergeRemoteSnapshot(remote);
    final merged = controller.state.preferences;

    expect(
      merged.smartCollections.map((value) => value.id),
      containsAll(['smart-local', 'smart-drive']),
    );
    expect(
      merged.trashEntries.map((value) => value.entryId),
      containsAll(['trash-local', 'trash-drive']),
    );
    expect(
      merged.importMappingPresets.map((value) => value.id),
      containsAll(['mapping-local', 'mapping-drive']),
    );
    expect(merged.importReceipts.single.undoneAt, later);
    expect(
      merged.contentCorrections.map((value) => value.itemId),
      containsAll(['pack-word', 'pack-sentence']),
    );
    expect(merged.onboardingProfile.purpose, LearningPurpose.travel);

    final roundTrip = StudyPreferences.fromJson(
      Map<String, Object?>.from(
        controller.exportSyncSnapshot()['settings']! as Map,
      ),
    );
    expect(roundTrip.importReceipts.single.canUndo, isFalse);
    expect(roundTrip.smartCollections, hasLength(2));
    expect(roundTrip.trashEntries, hasLength(2));

    controller.dispose();
  });
}
