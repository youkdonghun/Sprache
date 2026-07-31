import 'study_preferences.dart';
import 'study_limits.dart';

const _keepParentSessionId = Object();

enum ActiveStudySessionPhase { active, paused }

extension ActiveStudySessionPhaseLabel on ActiveStudySessionPhase {
  String get label => switch (this) {
    ActiveStudySessionPhase.active => '진행 중',
    ActiveStudySessionPhase.paused => '일시정지',
  };
}

enum StudySessionOrigin { fresh, restarted, wrongAnswers, remaining }

extension StudySessionOriginLabel on StudySessionOrigin {
  String get label => switch (this) {
    StudySessionOrigin.fresh => '새 학습',
    StudySessionOrigin.restarted => '처음부터 다시',
    StudySessionOrigin.wrongAnswers => '오답 집중',
    StudySessionOrigin.remaining => '남은 문제 집중',
  };
}

enum StudySessionJourneyAction {
  started,
  paused,
  resumed,
  restarted,
  branchedWrongAnswers,
  branchedRemaining,
}

extension StudySessionJourneyActionLabel on StudySessionJourneyAction {
  String get label => switch (this) {
    StudySessionJourneyAction.started => '시작',
    StudySessionJourneyAction.paused => '일시정지',
    StudySessionJourneyAction.resumed => '이어하기',
    StudySessionJourneyAction.restarted => '처음부터 다시',
    StudySessionJourneyAction.branchedWrongAnswers => '오답 집중 분기',
    StudySessionJourneyAction.branchedRemaining => '남은 문제 분기',
  };
}

class StudySessionJourneyEvent {
  const StudySessionJourneyEvent({
    required this.eventId,
    required this.action,
    required this.sessionId,
    required this.occurredAt,
    required this.itemCount,
    this.sourceSessionId,
  });

  final String eventId;
  final StudySessionJourneyAction action;
  final String sessionId;
  final String? sourceSessionId;
  final DateTime occurredAt;
  final int itemCount;

  Map<String, Object?> toJson() => {
    'eventId': eventId,
    'action': action.name,
    'sessionId': sessionId,
    'sourceSessionId': sourceSessionId,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'itemCount': itemCount,
  };

  factory StudySessionJourneyEvent.fromJson(Map<String, Object?> json) {
    final eventId = json['eventId'];
    final actionName = json['action'];
    final sessionId = json['sessionId'];
    final sourceSessionId = json['sourceSessionId'];
    final occurredAt = DateTime.tryParse(json['occurredAt'] as String? ?? '');
    final itemCount = _integer(json['itemCount']);
    final action = StudySessionJourneyAction.values
        .where((value) => value.name == actionName)
        .firstOrNull;
    if (eventId is! String ||
        eventId.trim().isEmpty ||
        action == null ||
        sessionId is! String ||
        sessionId.trim().isEmpty ||
        (sourceSessionId != null &&
            (sourceSessionId is! String || sourceSessionId.trim().isEmpty)) ||
        occurredAt == null ||
        itemCount == null ||
        itemCount < 1 ||
        itemCount > StudyLimits.maxSessionItems) {
      throw const FormatException('Invalid study session journey event');
    }
    return StudySessionJourneyEvent(
      eventId: eventId,
      action: action,
      sessionId: sessionId,
      sourceSessionId: sourceSessionId as String?,
      occurredAt: occurredAt.toUtc(),
      itemCount: itemCount,
    );
  }
}

class ActiveStudySession {
  const ActiveStudySession({
    required this.sessionId,
    required this.courseId,
    required this.mode,
    required this.itemIds,
    required this.currentIndex,
    required this.correctCount,
    required this.wrongCount,
    required this.earnedXp,
    required this.startedAt,
    required this.updatedAt,
    this.unitIndex,
    this.initialItemIds = const [],
    this.wrongItemIds = const {},
    this.finalCorrectItemIds = const {},
    this.phase = ActiveStudySessionPhase.active,
    this.origin = StudySessionOrigin.fresh,
    this.rootSessionId,
    this.parentSessionId,
    this.generation = 0,
    this.pauseCount = 0,
    this.resumeCount = 0,
    this.journey = const [],
  });

  factory ActiveStudySession.started({
    required String sessionId,
    required String courseId,
    required StudyMode mode,
    required int? unitIndex,
    required List<String> itemIds,
    required DateTime startedAt,
  }) {
    if (itemIds.isEmpty ||
        itemIds.length > StudyLimits.maxSessionItems ||
        itemIds.toSet().length != itemIds.length) {
      throw ArgumentError(
        'A session needs 1-${StudyLimits.maxSessionItems} unique items.',
      );
    }
    final immutableItems = List<String>.unmodifiable(itemIds);
    final at = startedAt.toUtc();
    return ActiveStudySession(
      sessionId: sessionId,
      courseId: courseId,
      mode: mode,
      unitIndex: unitIndex,
      itemIds: immutableItems,
      initialItemIds: immutableItems,
      currentIndex: 0,
      correctCount: 0,
      wrongCount: 0,
      earnedXp: 0,
      startedAt: at,
      updatedAt: at,
      rootSessionId: sessionId,
      journey: [
        StudySessionJourneyEvent(
          eventId: _eventId(
            sessionId,
            StudySessionJourneyAction.started,
            at,
            0,
          ),
          action: StudySessionJourneyAction.started,
          sessionId: sessionId,
          occurredAt: at,
          itemCount: immutableItems.length,
        ),
      ],
    );
  }

  final String sessionId;
  final String courseId;
  final StudyMode mode;
  final int? unitIndex;
  final List<String> itemIds;
  final List<String> initialItemIds;
  final Set<String> wrongItemIds;
  final Set<String> finalCorrectItemIds;
  final int currentIndex;
  final int correctCount;
  final int wrongCount;
  final int earnedXp;
  final DateTime startedAt;
  final DateTime updatedAt;
  final ActiveStudySessionPhase phase;
  final StudySessionOrigin origin;
  final String? rootSessionId;
  final String? parentSessionId;
  final int generation;
  final int pauseCount;
  final int resumeCount;
  final List<StudySessionJourneyEvent> journey;

  String get lineageRootId => rootSessionId ?? sessionId;
  List<String> get originalItemIds =>
      initialItemIds.isEmpty ? itemIds : initialItemIds;
  int get completedCount => currentIndex.clamp(0, itemIds.length);
  int get remainingCount =>
      (itemIds.length - completedCount).clamp(0, itemIds.length);
  double get progress => itemIds.isEmpty ? 0 : completedCount / itemIds.length;
  int get attempts => correctCount + wrongCount;
  double get accuracy => attempts == 0 ? 0 : correctCount / attempts;
  bool get isDerived => origin != StudySessionOrigin.fresh || generation > 0;
  Set<String> get unresolvedWrongItemIds =>
      Set.unmodifiable(wrongItemIds.difference(finalCorrectItemIds));

  ActiveStudySession copyWith({
    String? sessionId,
    List<String>? itemIds,
    List<String>? initialItemIds,
    Set<String>? wrongItemIds,
    Set<String>? finalCorrectItemIds,
    int? currentIndex,
    int? correctCount,
    int? wrongCount,
    int? earnedXp,
    DateTime? startedAt,
    DateTime? updatedAt,
    ActiveStudySessionPhase? phase,
    StudySessionOrigin? origin,
    String? rootSessionId,
    Object? parentSessionId = _keepParentSessionId,
    int? generation,
    int? pauseCount,
    int? resumeCount,
    List<StudySessionJourneyEvent>? journey,
  }) {
    return ActiveStudySession(
      sessionId: sessionId ?? this.sessionId,
      courseId: courseId,
      mode: mode,
      unitIndex: unitIndex,
      itemIds: itemIds ?? this.itemIds,
      initialItemIds: initialItemIds ?? this.initialItemIds,
      wrongItemIds: wrongItemIds ?? this.wrongItemIds,
      finalCorrectItemIds: finalCorrectItemIds ?? this.finalCorrectItemIds,
      currentIndex: currentIndex ?? this.currentIndex,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      earnedXp: earnedXp ?? this.earnedXp,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      phase: phase ?? this.phase,
      origin: origin ?? this.origin,
      rootSessionId: rootSessionId ?? this.rootSessionId,
      parentSessionId: identical(parentSessionId, _keepParentSessionId)
          ? this.parentSessionId
          : parentSessionId as String?,
      generation: generation ?? this.generation,
      pauseCount: pauseCount ?? this.pauseCount,
      resumeCount: resumeCount ?? this.resumeCount,
      journey: journey ?? this.journey,
    );
  }

  ActiveStudySession pause(DateTime occurredAt) {
    if (phase == ActiveStudySessionPhase.paused) return this;
    final at = occurredAt.toUtc();
    return copyWith(
      phase: ActiveStudySessionPhase.paused,
      pauseCount: pauseCount + 1,
      updatedAt: at,
      journey: _appendEvent(
        StudySessionJourneyEvent(
          eventId: _eventId(
            sessionId,
            StudySessionJourneyAction.paused,
            at,
            pauseCount + 1,
          ),
          action: StudySessionJourneyAction.paused,
          sessionId: sessionId,
          occurredAt: at,
          itemCount: originalItemIds.length,
        ),
      ),
    );
  }

  ActiveStudySession resume(DateTime occurredAt) {
    if (phase == ActiveStudySessionPhase.active) return this;
    final at = occurredAt.toUtc();
    return copyWith(
      phase: ActiveStudySessionPhase.active,
      resumeCount: resumeCount + 1,
      updatedAt: at,
      journey: _appendEvent(
        StudySessionJourneyEvent(
          eventId: _eventId(
            sessionId,
            StudySessionJourneyAction.resumed,
            at,
            resumeCount + 1,
          ),
          action: StudySessionJourneyAction.resumed,
          sessionId: sessionId,
          occurredAt: at,
          itemCount: originalItemIds.length,
        ),
      ),
    );
  }

  ActiveStudySession derive({
    required String newSessionId,
    required StudySessionOrigin nextOrigin,
    required List<String> selectedItemIds,
    required DateTime startedAt,
  }) {
    if (nextOrigin == StudySessionOrigin.fresh || selectedItemIds.isEmpty) {
      throw ArgumentError('A derived session needs an origin and items.');
    }
    if (selectedItemIds.length > StudyLimits.maxSessionItems ||
        selectedItemIds.toSet().length != selectedItemIds.length) {
      throw ArgumentError(
        'A derived session needs at most '
        '${StudyLimits.maxSessionItems} unique items.',
      );
    }
    final at = startedAt.toUtc();
    final immutableItems = List<String>.unmodifiable(selectedItemIds);
    final action = switch (nextOrigin) {
      StudySessionOrigin.restarted => StudySessionJourneyAction.restarted,
      StudySessionOrigin.wrongAnswers =>
        StudySessionJourneyAction.branchedWrongAnswers,
      StudySessionOrigin.remaining =>
        StudySessionJourneyAction.branchedRemaining,
      StudySessionOrigin.fresh => throw StateError('Unreachable origin'),
    };
    final event = StudySessionJourneyEvent(
      eventId: _eventId(newSessionId, action, at, generation + 1),
      action: action,
      sessionId: newSessionId,
      sourceSessionId: sessionId,
      occurredAt: at,
      itemCount: immutableItems.length,
    );
    return ActiveStudySession(
      sessionId: newSessionId,
      courseId: courseId,
      mode: mode,
      unitIndex: unitIndex,
      itemIds: immutableItems,
      initialItemIds: immutableItems,
      currentIndex: 0,
      correctCount: 0,
      wrongCount: 0,
      earnedXp: 0,
      startedAt: at,
      updatedAt: at,
      phase: ActiveStudySessionPhase.active,
      origin: nextOrigin,
      rootSessionId: lineageRootId,
      parentSessionId: sessionId,
      generation: generation + 1,
      pauseCount: pauseCount,
      resumeCount: resumeCount,
      journey: _appendEvent(event),
    );
  }

  List<StudySessionJourneyEvent> _appendEvent(StudySessionJourneyEvent event) {
    final next = [...journey, event];
    return List.unmodifiable(
      next.length <= 50 ? next : next.sublist(next.length - 50),
    );
  }

  Map<String, Object?> toJson() => {
    'sessionId': sessionId,
    'courseId': courseId,
    'mode': mode.name,
    'unitIndex': unitIndex,
    'itemIds': itemIds,
    'initialItemIds': originalItemIds,
    'wrongItemIds': wrongItemIds.toList()..sort(),
    'finalCorrectItemIds': finalCorrectItemIds.toList()..sort(),
    'currentIndex': currentIndex,
    'correctCount': correctCount,
    'wrongCount': wrongCount,
    'earnedXp': earnedXp,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'phase': phase.name,
    'origin': origin.name,
    'rootSessionId': lineageRootId,
    'parentSessionId': parentSessionId,
    'generation': generation,
    'pauseCount': pauseCount,
    'resumeCount': resumeCount,
    'journey': [for (final event in journey) event.toJson()],
  };

  factory ActiveStudySession.fromJson(Map<String, Object?> json) {
    final sessionId = json['sessionId'] as String?;
    final courseId = json['courseId'] as String?;
    final startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    final itemIds = _stringList(
      json['itemIds'],
      field: 'itemIds',
      maximum: StudyLimits.maxActiveQueueEntries,
    );
    if (sessionId == null ||
        sessionId.isEmpty ||
        courseId == null ||
        courseId.isEmpty ||
        startedAt == null ||
        updatedAt == null ||
        itemIds.isEmpty) {
      throw const FormatException('Invalid active study session');
    }
    final initialItemIds = json.containsKey('initialItemIds')
        ? _stringList(
            json['initialItemIds'],
            field: 'initialItemIds',
            maximum: StudyLimits.maxSessionItems,
            unique: true,
          )
        : _orderedUnique(itemIds);
    if (initialItemIds.isEmpty ||
        initialItemIds.length > StudyLimits.maxSessionItems) {
      throw const FormatException('Invalid initial study session items');
    }
    final wrongItemIds = json.containsKey('wrongItemIds')
        ? _stringList(
            json['wrongItemIds'],
            field: 'wrongItemIds',
            maximum: StudyLimits.maxSessionItems,
            unique: true,
          ).toSet()
        : <String>{};
    final currentIndex = (_integer(json['currentIndex']) ?? 0).clamp(
      0,
      itemIds.length,
    );
    final finalCorrectItemIds = json.containsKey('finalCorrectItemIds')
        ? _stringList(
            json['finalCorrectItemIds'],
            field: 'finalCorrectItemIds',
            maximum: StudyLimits.maxSessionItems,
            unique: true,
          ).toSet()
        : itemIds.take(currentIndex).toSet().difference(wrongItemIds);
    final knownItemIds = itemIds.toSet();
    if (!knownItemIds.containsAll(initialItemIds) ||
        !knownItemIds.containsAll(wrongItemIds) ||
        !knownItemIds.containsAll(finalCorrectItemIds)) {
      throw const FormatException('Invalid active study session outcome IDs');
    }
    final modeName = json['mode'] as String?;
    final mode = StudyMode.values.firstWhere(
      (value) => value.name == modeName,
      orElse: () => StudyMode.mixed,
    );
    final phase = _enumValue(
      ActiveStudySessionPhase.values,
      json['phase'],
      fallback: ActiveStudySessionPhase.active,
    );
    final origin = _enumValue(
      StudySessionOrigin.values,
      json['origin'],
      fallback: StudySessionOrigin.fresh,
    );
    final generation = _boundedInteger(
      json['generation'],
      fallback: 0,
      maximum: 1000,
    );
    final pauseCount = _boundedInteger(
      json['pauseCount'],
      fallback: 0,
      maximum: 1000000,
    );
    final resumeCount = _boundedInteger(
      json['resumeCount'],
      fallback: 0,
      maximum: 1000000,
    );
    final rootSessionId = json['rootSessionId'];
    final parentSessionId = json['parentSessionId'];
    if ((rootSessionId != null &&
            (rootSessionId is! String || rootSessionId.trim().isEmpty)) ||
        (parentSessionId != null &&
            (parentSessionId is! String || parentSessionId.trim().isEmpty))) {
      throw const FormatException('Invalid study session lineage');
    }
    final journey = _journeyFromJson(
      json['journey'],
      legacySessionId: sessionId,
      legacyStartedAt: startedAt,
      legacyItemCount: initialItemIds.length,
    );
    return ActiveStudySession(
      sessionId: sessionId,
      courseId: courseId,
      mode: mode,
      unitIndex: _integer(json['unitIndex']),
      itemIds: List.unmodifiable(itemIds),
      initialItemIds: List.unmodifiable(initialItemIds),
      wrongItemIds: Set.unmodifiable(wrongItemIds),
      finalCorrectItemIds: Set.unmodifiable(finalCorrectItemIds),
      currentIndex: currentIndex,
      correctCount: (_integer(json['correctCount']) ?? 0).clamp(0, 1000000),
      wrongCount: (_integer(json['wrongCount']) ?? 0).clamp(0, 1000000),
      earnedXp: (_integer(json['earnedXp']) ?? 0).clamp(0, 10000000),
      startedAt: startedAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
      phase: phase,
      origin: origin,
      rootSessionId: (rootSessionId as String?) ?? sessionId,
      parentSessionId: parentSessionId as String?,
      generation: generation,
      pauseCount: pauseCount,
      resumeCount: resumeCount,
      journey: journey,
    );
  }
}

String _eventId(
  String sessionId,
  StudySessionJourneyAction action,
  DateTime occurredAt,
  int sequence,
) =>
    '$sessionId:${action.name}:$sequence:'
    '${occurredAt.toUtc().microsecondsSinceEpoch}';

int? _integer(Object? raw) {
  if (raw == null) return null;
  if (raw is! num || !raw.isFinite || raw != raw.round()) return null;
  return raw.toInt();
}

int _boundedInteger(
  Object? raw, {
  required int fallback,
  required int maximum,
}) {
  if (raw == null) return fallback;
  final value = _integer(raw);
  if (value == null || value < 0 || value > maximum) {
    throw const FormatException('Invalid study session counter');
  }
  return value;
}

List<String> _stringList(
  Object? raw, {
  required String field,
  int? maximum,
  bool unique = false,
}) {
  if (raw is! List<Object?> ||
      (maximum != null && raw.length > maximum) ||
      raw.any(
        (value) =>
            value is! String ||
            value.trim().isEmpty ||
            value.runes.length > 160,
      )) {
    throw FormatException('Invalid $field');
  }
  final values = raw.cast<String>().toList(growable: false);
  if (unique && values.toSet().length != values.length) {
    throw FormatException('Duplicate $field');
  }
  return values;
}

List<String> _orderedUnique(Iterable<String> values) {
  final seen = <String>{};
  return [
    for (final value in values)
      if (seen.add(value)) value,
  ];
}

T _enumValue<T extends Enum>(
  List<T> values,
  Object? raw, {
  required T fallback,
}) {
  if (raw == null) return fallback;
  if (raw is! String) throw const FormatException('Invalid session enum');
  return values.where((value) => value.name == raw).firstOrNull ??
      (throw const FormatException('Invalid session enum'));
}

List<StudySessionJourneyEvent> _journeyFromJson(
  Object? raw, {
  required String legacySessionId,
  required DateTime legacyStartedAt,
  required int legacyItemCount,
}) {
  if (raw == null) {
    return [
      StudySessionJourneyEvent(
        eventId: 'legacy:$legacySessionId:started',
        action: StudySessionJourneyAction.started,
        sessionId: legacySessionId,
        occurredAt: legacyStartedAt.toUtc(),
        itemCount: legacyItemCount,
      ),
    ];
  }
  if (raw is! List<Object?> || raw.length > 50) {
    throw const FormatException('Invalid study session journey');
  }
  final events = [
    for (final value in raw)
      if (value is Map)
        StudySessionJourneyEvent.fromJson(Map<String, Object?>.from(value))
      else
        throw const FormatException('Invalid study session journey'),
  ];
  if (events.map((event) => event.eventId).toSet().length != events.length) {
    throw const FormatException('Duplicate study session journey event');
  }
  return List.unmodifiable(events);
}
