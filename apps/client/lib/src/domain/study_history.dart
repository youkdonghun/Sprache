import 'active_study_session.dart';

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

  int get attempts => correctCount + wrongCount;
  double get accuracy => attempts == 0 ? 0 : correctCount / attempts;
  bool get isDerived => origin != StudySessionOrigin.fresh || generation > 0;

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
        (rawJourney != null && rawJourney is! List<Object?>)) {
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
    );
  }
}

int? _summaryInteger(Object? raw) {
  if (raw is! num || !raw.isFinite || raw != raw.round()) return null;
  return raw.toInt();
}
