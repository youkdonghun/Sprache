import 'study_preferences.dart';

enum OfflineReadinessLevel { ready, deviceService, unavailable, unknown }

class OfflineReadinessCheck {
  const OfflineReadinessCheck({
    required this.id,
    required this.label,
    required this.level,
    required this.detail,
  });

  final String id;
  final String label;
  final OfflineReadinessLevel level;
  final String detail;
}

class OfflineReadinessReport {
  const OfflineReadinessReport({required this.checks});

  final List<OfflineReadinessCheck> checks;

  bool get canStudy => checks.every(
    (check) =>
        check.level != OfflineReadinessLevel.unavailable ||
        check.id != 'database' && check.id != 'content',
  );
  int get readyCount => checks
      .where((check) => check.level == OfflineReadinessLevel.ready)
      .length;
}

class OfflineReadinessBuilder {
  const OfflineReadinessBuilder();

  OfflineReadinessReport build({
    required bool databaseReady,
    required int localItemCount,
    required bool? offlineTtsAvailable,
    required bool? speechPackAvailable,
    required int pendingWrites,
  }) => OfflineReadinessReport(
    checks: List.unmodifiable([
      OfflineReadinessCheck(
        id: 'database',
        label: '로컬 데이터베이스',
        level: databaseReady
            ? OfflineReadinessLevel.ready
            : OfflineReadinessLevel.unavailable,
        detail: databaseReady ? '기기 로컬 저장 준비 완료' : '로컬 DB를 열지 못했어요.',
      ),
      OfflineReadinessCheck(
        id: 'content',
        label: '학습 콘텐츠',
        level: localItemCount > 0
            ? OfflineReadinessLevel.ready
            : OfflineReadinessLevel.unavailable,
        detail: localItemCount > 0
            ? '오프라인 항목 $localItemCount개'
            : '오프라인에서 학습할 자료가 없어요.',
      ),
      _optionalCheck(
        id: 'tts',
        label: '오프라인 음성',
        available: offlineTtsAvailable,
        ready: '기기 음성으로 들을 수 있어요.',
        missing: '읽기 표기로 전환할 수 있어요.',
      ),
      _optionalCheck(
        id: 'speech',
        label: '음성 인식 언어팩',
        available: speechPackAvailable,
        ready: '마이크 채점을 사용할 수 있어요.',
        missing: '자기 평가로 전환할 수 있어요.',
      ),
      OfflineReadinessCheck(
        id: 'pending',
        label: '대기 저장',
        level: OfflineReadinessLevel.ready,
        detail: pendingWrites == 0
            ? '대기 작업 없음'
            : '재연결 때 저장할 작업 $pendingWrites개',
      ),
    ]),
  );

  OfflineReadinessCheck _optionalCheck({
    required String id,
    required String label,
    required bool? available,
    required String ready,
    required String missing,
  }) => OfflineReadinessCheck(
    id: id,
    label: label,
    level: available == null
        ? OfflineReadinessLevel.unknown
        : available
        ? OfflineReadinessLevel.ready
        : OfflineReadinessLevel.deviceService,
    detail: available == null
        ? '기기에서 시작할 때 확인합니다.'
        : available
        ? ready
        : missing,
  );
}

class OfflineStudyModePlan {
  const OfflineStudyModePlan({
    required this.mode,
    required this.level,
    required this.fallbackMode,
    required this.reason,
  });

  final StudyMode mode;
  final OfflineReadinessLevel level;
  final StudyMode? fallbackMode;
  final String reason;
}

OfflineStudyModePlan offlinePlanForMode(
  StudyMode mode, {
  required bool ttsAvailable,
  required bool speechAvailable,
}) {
  if (mode == StudyMode.pronunciation && !speechAvailable) {
    return const OfflineStudyModePlan(
      mode: StudyMode.pronunciation,
      level: OfflineReadinessLevel.deviceService,
      fallbackMode: StudyMode.production,
      reason: '음성팩이 없어 직접 쓰기 또는 자기 평가로 바꿀 수 있어요.',
    );
  }
  if (mode == StudyMode.listening && !ttsAvailable) {
    return const OfflineStudyModePlan(
      mode: StudyMode.listening,
      level: OfflineReadinessLevel.deviceService,
      fallbackMode: StudyMode.meaning,
      reason: '오프라인 음성이 없어 뜻 고르기로 바꿀 수 있어요.',
    );
  }
  return OfflineStudyModePlan(
    mode: mode,
    level: OfflineReadinessLevel.ready,
    fallbackMode: null,
    reason: '완전 오프라인으로 진행할 수 있어요.',
  );
}

class OfflineCompletionReceipt {
  const OfflineCompletionReceipt({
    required this.savedAt,
    required this.earnedXp,
    required this.streakDays,
    required this.pendingSyncCount,
  });

  final DateTime savedAt;
  final int earnedXp;
  final int streakDays;
  final int pendingSyncCount;
}
