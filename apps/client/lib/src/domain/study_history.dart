import 'active_study_session.dart';
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

  int get attempts => correctCount + wrongCount;
  double get accuracy => attempts == 0 ? 0 : correctCount / attempts;
  bool get isDerived => origin != StudySessionOrigin.fresh || generation > 0;
  Set<String> get unresolvedWrongItemIds =>
      Set.unmodifiable(wrongItemIds.difference(finalCorrectItemIds));
  Set<String> get notCorrectItemIds =>
      Set.unmodifiable(itemIds.toSet().difference(finalCorrectItemIds));

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
    final itemIds = _summaryIds(rawItemIds);
    final itemIdSet = itemIds.toSet();
    final wrongItemIds = _summaryIds(rawWrongItemIds).toSet();
    final finalCorrectItemIds = rawFinalCorrectItemIds == null
        ? itemIdSet.difference(wrongItemIds)
        : _summaryIds(rawFinalCorrectItemIds).toSet();
    if (itemIds.length > StudyLimits.maxSessionItems ||
        wrongItemIds.length > StudyLimits.maxSessionItems ||
        finalCorrectItemIds.length > StudyLimits.maxSessionItems ||
        wrongItemIds.difference(itemIdSet).isNotEmpty ||
        finalCorrectItemIds.difference(itemIdSet).isNotEmpty) {
      throw const FormatException('Invalid study session item IDs');
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
