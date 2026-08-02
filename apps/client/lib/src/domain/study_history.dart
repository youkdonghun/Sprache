import 'active_study_session.dart';
import 'adaptive_study_session.dart';
import 'study_limits.dart';
import 'study_preferences.dart';

class StudyEventEntry {
  const StudyEventEntry({
    required this.eventId,
    required this.courseId,
    required this.itemId,
    required this.exerciseType,
    required this.result,
    required this.studiedAt,
  });

  final String eventId;
  final String courseId;
  final String itemId;
  final String exerciseType;
  final String result;
  final DateTime studiedAt;
}

enum PronunciationEvaluationMethod { speechRecognition, selfAssessment }

class PronunciationAttemptMetric {
  const PronunciationAttemptMetric({
    required this.score,
    required this.recordedAt,
    required this.method,
  });

  factory PronunciationAttemptMetric.fromJson(Map<String, Object?> json) {
    final score = _summaryInteger(json['score']);
    final recordedAt = DateTime.tryParse(json['recordedAt'] as String? ?? '');
    final method = PronunciationEvaluationMethod.values
        .where((value) => value.name == json['method'])
        .firstOrNull;
    if (score == null ||
        score < 0 ||
        score > 100 ||
        recordedAt == null ||
        method == null) {
      throw const FormatException('Invalid pronunciation attempt metric');
    }
    return PronunciationAttemptMetric(
      score: score,
      recordedAt: recordedAt.toUtc(),
      method: method,
    );
  }

  final int score;
  final DateTime recordedAt;
  final PronunciationEvaluationMethod method;

  Map<String, Object?> toJson() => {
    'score': score,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'method': method.name,
  };
}

class StudySessionSummary {
  const StudySessionSummary({
    required this.sessionId,
    required this.courseId,
    required this.startedAt,
    required this.endedAt,
    required this.correctCount,
    required this.wrongCount,
    required this.earnedXp,
    this.origin = StudySessionOrigin.fresh,
    this.rootSessionId,
    this.parentSessionId,
    this.generation = 0,
    this.pauseCount = 0,
    this.resumeCount = 0,
    this.journey = const [],
    this.itemIds = const [],
    this.wrongItemIds = const {},
    this.finalCorrectItemIds = const {},
    this.mode = StudyMode.mixed,
    this.historyFilter = StudyHistoryFilter.all,
    this.recordProgress = true,
    this.backlogRecovery = false,
    this.pronunciationMetrics = const [],
    this.attemptMetrics = const [],
  });

  final String sessionId;
  final String courseId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int correctCount;
  final int wrongCount;
  final int earnedXp;
  final StudySessionOrigin origin;
  final String? rootSessionId;
  final String? parentSessionId;
  final int generation;
  final int pauseCount;
  final int resumeCount;
  final List<StudySessionJourneyEvent> journey;
  final List<String> itemIds;
  final Set<String> wrongItemIds;
  final Set<String> finalCorrectItemIds;
  final StudyMode mode;
  final StudyHistoryFilter historyFilter;
  final bool recordProgress;
  final bool backlogRecovery;
  final List<PronunciationAttemptMetric> pronunciationMetrics;
  final List<StudyAttemptMetric> attemptMetrics;

  int get attempts => correctCount + wrongCount;
  double get accuracy => attempts == 0 ? 0 : correctCount / attempts;
  bool get isDerived => origin != StudySessionOrigin.fresh || generation > 0;
  Set<String> get unresolvedWrongItemIds =>
      Set.unmodifiable(wrongItemIds.difference(finalCorrectItemIds));
  Set<String> get notCorrectItemIds =>
      Set.unmodifiable(itemIds.toSet().difference(finalCorrectItemIds));

  StudySessionSummary withPronunciationMetrics(
    List<PronunciationAttemptMetric> metrics,
  ) => StudySessionSummary(
    sessionId: sessionId,
    courseId: courseId,
    startedAt: startedAt,
    endedAt: endedAt,
    correctCount: correctCount,
    wrongCount: wrongCount,
    earnedXp: earnedXp,
    origin: origin,
    rootSessionId: rootSessionId,
    parentSessionId: parentSessionId,
    generation: generation,
    pauseCount: pauseCount,
    resumeCount: resumeCount,
    journey: journey,
    itemIds: itemIds,
    wrongItemIds: wrongItemIds,
    finalCorrectItemIds: finalCorrectItemIds,
    mode: mode,
    historyFilter: historyFilter,
    recordProgress: recordProgress,
    backlogRecovery: backlogRecovery,
    pronunciationMetrics: List.unmodifiable(
      metrics.take(StudyLimits.maxSessionItems),
    ),
    attemptMetrics: attemptMetrics,
  );

  Map<String, Object?> toJson() => {
    'sessionId': sessionId,
    'courseId': courseId,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'correctCount': correctCount,
    'wrongCount': wrongCount,
    'earnedXp': earnedXp,
    'origin': origin.name,
    'rootSessionId': rootSessionId ?? sessionId,
    'parentSessionId': parentSessionId,
    'generation': generation,
    'pauseCount': pauseCount,
    'resumeCount': resumeCount,
    'journey': [for (final event in journey) event.toJson()],
    'itemIds': itemIds,
    'wrongItemIds': wrongItemIds.toList()..sort(),
    'finalCorrectItemIds': finalCorrectItemIds.toList()..sort(),
    'mode': mode.name,
    'historyFilter': historyFilter.name,
    'recordProgress': recordProgress,
    'backlogRecovery': backlogRecovery,
    if (pronunciationMetrics.isNotEmpty)
      'pronunciationMetrics': [
        for (final metric in pronunciationMetrics) metric.toJson(),
      ],
    if (attemptMetrics.isNotEmpty)
      'attemptMetrics': [for (final metric in attemptMetrics) metric.toJson()],
  };

  factory StudySessionSummary.fromJson(Map<String, Object?> json) {
    final sessionId = json['sessionId'];
    final courseId = json['courseId'];
    final startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
    final endedAt = DateTime.tryParse(json['endedAt'] as String? ?? '');
    final correctCount = _summaryInteger(json['correctCount']);
    final wrongCount = _summaryInteger(json['wrongCount']);
    final earnedXp = _summaryInteger(json['earnedXp']);
    final originName = json['origin'];
    final origin = originName == null
        ? StudySessionOrigin.fresh
        : StudySessionOrigin.values
              .where((value) => value.name == originName)
              .firstOrNull;
    final generation = _summaryInteger(json['generation']) ?? 0;
    final pauseCount = _summaryInteger(json['pauseCount']) ?? 0;
    final resumeCount = _summaryInteger(json['resumeCount']) ?? 0;
    final rootSessionId = json['rootSessionId'];
    final parentSessionId = json['parentSessionId'];
    final rawJourney = json['journey'];
    final rawItemIds = json['itemIds'];
    final rawWrongItemIds = json['wrongItemIds'];
    final rawFinalCorrectItemIds = json['finalCorrectItemIds'];
    final rawPronunciationMetrics = json['pronunciationMetrics'];
    final rawAttemptMetrics = json['attemptMetrics'];
    if (sessionId is! String ||
        sessionId.trim().isEmpty ||
        courseId is! String ||
        courseId.trim().isEmpty ||
        startedAt == null ||
        endedAt == null ||
        correctCount == null ||
        wrongCount == null ||
        earnedXp == null ||
        correctCount < 0 ||
        wrongCount < 0 ||
        earnedXp < 0 ||
        origin == null ||
        generation < 0 ||
        pauseCount < 0 ||
        resumeCount < 0 ||
        (rootSessionId != null &&
            (rootSessionId is! String || rootSessionId.trim().isEmpty)) ||
        (parentSessionId != null &&
            (parentSessionId is! String || parentSessionId.trim().isEmpty)) ||
        (rawJourney != null && rawJourney is! List<Object?>) ||
        (rawItemIds != null && rawItemIds is! List<Object?>) ||
        (rawWrongItemIds != null && rawWrongItemIds is! List<Object?>) ||
        (rawFinalCorrectItemIds != null &&
            rawFinalCorrectItemIds is! List<Object?>) ||
        (rawPronunciationMetrics != null &&
            rawPronunciationMetrics is! List<Object?>) ||
        (rawAttemptMetrics != null && rawAttemptMetrics is! List<Object?>) ||
        (json['recordProgress'] != null && json['recordProgress'] is! bool) ||
        (json['backlogRecovery'] != null && json['backlogRecovery'] is! bool)) {
      throw const FormatException('Invalid study session summary');
    }
    final journey = rawJourney == null
        ? const <StudySessionJourneyEvent>[]
        : [
            for (final value in rawJourney as List<Object?>)
              if (value is Map)
                StudySessionJourneyEvent.fromJson(
                  Map<String, Object?>.from(value),
                )
              else
                throw const FormatException('Invalid session journey'),
          ];
    final pronunciationMetrics = rawPronunciationMetrics == null
        ? const <PronunciationAttemptMetric>[]
        : [
            for (final value in rawPronunciationMetrics as List<Object?>)
              if (value is Map)
                PronunciationAttemptMetric.fromJson(
                  Map<String, Object?>.from(value),
                )
              else
                throw const FormatException(
                  'Invalid pronunciation attempt metric',
                ),
          ];
    final attemptMetrics = rawAttemptMetrics == null
        ? const <StudyAttemptMetric>[]
        : [
            for (final value in rawAttemptMetrics as List<Object?>)
              if (value is Map)
                StudyAttemptMetric.fromJson(Map<String, Object?>.from(value))
              else
                throw const FormatException('Invalid study attempt metric'),
          ];
    final itemIds = _summaryIds(rawItemIds);
    final itemIdSet = itemIds.toSet();
    final wrongItemIds = _summaryIds(rawWrongItemIds).toSet();
    final finalCorrectItemIds = rawFinalCorrectItemIds == null
        ? itemIdSet.difference(wrongItemIds)
        : _summaryIds(rawFinalCorrectItemIds).toSet();
    if (itemIds.length > StudyLimits.maxSessionItems ||
        pronunciationMetrics.length > StudyLimits.maxSessionItems ||
        attemptMetrics.length > StudyLimits.maxActiveQueueEntries ||
        wrongItemIds.length > StudyLimits.maxSessionItems ||
        finalCorrectItemIds.length > StudyLimits.maxSessionItems ||
        wrongItemIds.difference(itemIdSet).isNotEmpty ||
        finalCorrectItemIds.difference(itemIdSet).isNotEmpty) {
      throw const FormatException('Invalid study session item IDs');
    }
    if (itemIdSet.isNotEmpty &&
        attemptMetrics.any((metric) => !itemIdSet.contains(metric.itemId))) {
      throw const FormatException('Unknown study attempt metric item');
    }
    return StudySessionSummary(
      sessionId: sessionId,
      courseId: courseId,
      startedAt: startedAt.toUtc(),
      endedAt: endedAt.toUtc(),
      correctCount: correctCount,
      wrongCount: wrongCount,
      earnedXp: earnedXp,
      origin: origin,
      rootSessionId: rootSessionId as String?,
      parentSessionId: parentSessionId as String?,
      generation: generation,
      pauseCount: pauseCount,
      resumeCount: resumeCount,
      journey: List.unmodifiable(journey),
      itemIds: List.unmodifiable(itemIds),
      wrongItemIds: Set.unmodifiable(wrongItemIds),
      finalCorrectItemIds: Set.unmodifiable(finalCorrectItemIds),
      mode: StudyMode.values.firstWhere(
        (value) => value.name == json['mode'],
        orElse: () => StudyMode.mixed,
      ),
      historyFilter: StudyHistoryFilter.values.firstWhere(
        (value) => value.name == json['historyFilter'],
        orElse: () => StudyHistoryFilter.all,
      ),
      recordProgress: json['recordProgress'] != false,
      backlogRecovery: json['backlogRecovery'] == true,
      pronunciationMetrics: List.unmodifiable(pronunciationMetrics),
      attemptMetrics: List.unmodifiable(attemptMetrics),
    );
  }
}

List<String> _summaryIds(Object? raw) {
  if (raw == null) return const [];
  final values = raw as List<Object?>;
  if (values.any(
    (value) =>
        value is! String || value.trim().isEmpty || value.runes.length > 160,
  )) {
    throw const FormatException('Invalid study session item ID');
  }
  final ids = values.cast<String>();
  if (ids.toSet().length != ids.length) {
    throw const FormatException('Duplicate study session item ID');
  }
  return ids;
}

int? _summaryInteger(Object? raw) {
  if (raw is! num || !raw.isFinite || raw != raw.round()) return null;
  return raw.toInt();
}
