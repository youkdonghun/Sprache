import 'learning_item.dart';

enum ExerciseReadinessKind {
  recognition,
  production,
  listening,
  cloze,
  sentenceOrder,
  pronunciation,
}

class ExerciseReadinessStatus {
  const ExerciseReadinessStatus({
    required this.kind,
    required this.ready,
    required this.reason,
  });

  final ExerciseReadinessKind kind;
  final bool ready;
  final String reason;
}

class ExerciseReadinessInspector {
  const ExerciseReadinessInspector();

  List<ExerciseReadinessStatus> inspect(LearningItem item) {
    final hasMeaning = item.translations.any(
      (value) => value.trim().isNotEmpty,
    );
    final hasTokens =
        item.kind == LearningItemKind.sentence &&
        item.sentenceTokens.length >= 2;
    final hasListening = item.capabilities.contains(
      ExerciseCapability.listening,
    );
    return [
      ExerciseReadinessStatus(
        kind: ExerciseReadinessKind.recognition,
        ready:
            hasMeaning &&
            item.capabilities.contains(ExerciseCapability.recognition),
        reason: !hasMeaning
            ? '뜻이 필요해요.'
            : item.capabilities.contains(ExerciseCapability.recognition)
            ? '뜻 고르기 가능'
            : '뜻 고르기 기능이 꺼져 있어요.',
      ),
      ExerciseReadinessStatus(
        kind: ExerciseReadinessKind.production,
        ready:
            hasMeaning &&
            item.capabilities.contains(ExerciseCapability.production),
        reason: !hasMeaning
            ? '뜻이 필요해요.'
            : item.capabilities.contains(ExerciseCapability.production)
            ? '직접 쓰기 가능'
            : '직접 쓰기 기능이 꺼져 있어요.',
      ),
      ExerciseReadinessStatus(
        kind: ExerciseReadinessKind.listening,
        ready: hasListening,
        reason: hasListening ? '기기 음성으로 듣기 가능' : '듣기 기능이 꺼져 있어요.',
      ),
      ExerciseReadinessStatus(
        kind: ExerciseReadinessKind.cloze,
        ready:
            hasTokens && item.capabilities.contains(ExerciseCapability.cloze),
        reason: !hasTokens
            ? '문장 토큰이 2개 이상 필요해요.'
            : item.capabilities.contains(ExerciseCapability.cloze)
            ? '문장 빈칸 가능'
            : '빈칸 기능이 꺼져 있어요.',
      ),
      ExerciseReadinessStatus(
        kind: ExerciseReadinessKind.sentenceOrder,
        ready:
            hasTokens &&
            item.capabilities.contains(ExerciseCapability.sentenceOrder),
        reason: !hasTokens
            ? '명시된 배열 토큰이 필요해요.'
            : item.capabilities.contains(ExerciseCapability.sentenceOrder)
            ? '문장 배열 가능'
            : '문장 배열 기능이 꺼져 있어요.',
      ),
      ExerciseReadinessStatus(
        kind: ExerciseReadinessKind.pronunciation,
        ready: hasListening && item.text.trim().isNotEmpty,
        reason: !hasListening
            ? '듣기 가능한 원문이 필요해요.'
            : item.text.trim().isEmpty
            ? '발음할 원문이 필요해요.'
            : '듣고 따라 말하기 가능',
      ),
    ];
  }
}

extension ExerciseReadinessKindLabel on ExerciseReadinessKind {
  String get label => switch (this) {
    ExerciseReadinessKind.recognition => '뜻',
    ExerciseReadinessKind.production => '쓰기',
    ExerciseReadinessKind.listening => '듣기',
    ExerciseReadinessKind.cloze => '빈칸',
    ExerciseReadinessKind.sentenceOrder => '배열',
    ExerciseReadinessKind.pronunciation => '발음',
  };
}
