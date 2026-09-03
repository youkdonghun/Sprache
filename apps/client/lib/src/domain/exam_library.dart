import 'exam_pack.dart';
import 'exam_session.dart';

class ExamLibrary {
  const ExamLibrary({
    this.installedPacks = const {},
    this.attempts = const [],
    this.activeSession,
  });

  final Map<String, ExamPack> installedPacks;
  final List<ExamAttemptSummary> attempts;
  final ActiveExamSession? activeSession;

  ExamPack? get primaryPack => installedPacks.values.firstOrNull;

  Set<String> get wrongQuestionIds {
    final latestResultByQuestion = <String, bool>{};
    final ordered = [...attempts]
      ..sort((left, right) => left.completedAt.compareTo(right.completedAt));
    for (final attempt in ordered) {
      for (final questionId in attempt.questionIds) {
        latestResultByQuestion[questionId] =
            attempt.answers[questionId]?.correct ?? false;
      }
    }
    return {
      for (final entry in latestResultByQuestion.entries)
        if (!entry.value) entry.key,
    };
  }

  ExamLibrary copyWith({
    Map<String, ExamPack>? installedPacks,
    List<ExamAttemptSummary>? attempts,
    ActiveExamSession? activeSession,
    bool clearActiveSession = false,
  }) => ExamLibrary(
    installedPacks: installedPacks ?? this.installedPacks,
    attempts: attempts ?? this.attempts,
    activeSession: clearActiveSession
        ? null
        : activeSession ?? this.activeSession,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'installedPacks': {
      for (final entry in installedPacks.entries)
        entry.key: entry.value.toJson(),
    },
    'attempts': [for (final attempt in attempts.take(100)) attempt.toJson()],
    if (activeSession != null) 'activeSession': activeSession!.toJson(),
  };

  factory ExamLibrary.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) return const ExamLibrary();
    final rawPacks = json['installedPacks'];
    final rawAttempts = json['attempts'];
    if (rawPacks is! Map || rawAttempts is! List<Object?>) {
      return const ExamLibrary();
    }
    final packs = <String, ExamPack>{};
    for (final entry in rawPacks.entries) {
      if (entry.key is! String || entry.value is! Map) continue;
      try {
        final pack = ExamPack.fromJson(
          Map<String, Object?>.from(entry.value as Map),
        );
        if (pack.id == entry.key) packs[pack.id] = pack;
      } on FormatException {
        // Keep other installed packs usable if one local entry is damaged.
      }
    }
    final attempts = <ExamAttemptSummary>[];
    for (final raw in rawAttempts.take(100)) {
      if (raw is! Map) continue;
      try {
        attempts.add(
          ExamAttemptSummary.fromJson(Map<String, Object?>.from(raw)),
        );
      } on FormatException {
        // Keep valid history rows.
      }
    }
    ActiveExamSession? active;
    if (json['activeSession'] case final Map rawActive) {
      try {
        active = ActiveExamSession.fromJson(
          Map<String, Object?>.from(rawActive),
        );
      } on FormatException {
        active = null;
      }
    }
    return ExamLibrary(
      installedPacks: Map.unmodifiable(packs),
      attempts: List.unmodifiable(attempts),
      activeSession: active,
    );
  }
}
