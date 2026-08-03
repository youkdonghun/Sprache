import 'learning_item.dart';

enum QuizHintMode { recognition, production, cloze, sentenceOrder, listening }

class QuizChoiceBuilder {
  const QuizChoiceBuilder();

  List<String> recognitionChoices({
    required LearningItem target,
    required Iterable<LearningItem> candidates,
    int count = 4,
  }) {
    final ranked = candidates
        .where((candidate) => candidate.id != target.id)
        .map(
          (candidate) => (
            value: candidate.primaryTranslation.trim(),
            score: _itemSimilarity(target, candidate),
            tie: candidate.id,
          ),
        )
        .where(
          (candidate) =>
              candidate.value.isNotEmpty &&
              _normalized(candidate.value) !=
                  _normalized(target.primaryTranslation),
        )
        .toList();
    ranked.sort((left, right) {
      final score = right.score.compareTo(left.score);
      return score != 0 ? score : left.tie.compareTo(right.tie);
    });
    return _stableChoiceOrder(
      target.id,
      target.primaryTranslation,
      ranked.map((candidate) => candidate.value),
      count,
    );
  }

  List<String> clozeChoices({
    required LearningItem target,
    required String answer,
    required Iterable<LearningItem> candidates,
    int count = 4,
  }) {
    final bestByToken = <String, ({String value, int score, String tie})>{};
    for (final candidate in candidates) {
      if (candidate.id == target.id ||
          candidate.kind != LearningItemKind.sentence) {
        continue;
      }
      final itemScore = _itemSimilarity(target, candidate);
      for (final token in candidate.sentenceTokens) {
        final value = token.trim();
        final normalized = _normalized(value);
        if (value.isEmpty ||
            normalized == _normalized(answer) ||
            !_containsLetterOrNumber(value)) {
          continue;
        }
        final lengthScore =
            8 - (value.runes.length - answer.runes.length).abs().clamp(0, 8);
        final scored = (
          value: value,
          score: itemScore + lengthScore,
          tie: '${candidate.id}|$value',
        );
        final previous = bestByToken[normalized];
        if (previous == null ||
            scored.score > previous.score ||
            (scored.score == previous.score &&
                scored.tie.compareTo(previous.tie) < 0)) {
          bestByToken[normalized] = scored;
        }
      }
    }
    final ranked = bestByToken.values.toList()
      ..sort((left, right) {
        final score = right.score.compareTo(left.score);
        return score != 0 ? score : left.tie.compareTo(right.tie);
      });
    return _stableChoiceOrder(
      target.id,
      answer,
      ranked.map((candidate) => candidate.value),
      count,
    );
  }

  int _itemSimilarity(LearningItem target, LearningItem candidate) {
    var score = 0;
    if (candidate.learningLanguage == target.learningLanguage) score += 30;
    if (candidate.kind == target.kind) score += 18;
    if (candidate.level == target.level) score += 12;
    if (candidate.partOfSpeech != null &&
        candidate.partOfSpeech == target.partOfSpeech) {
      score += 10;
    }
    score +=
        target.tags.toSet().intersection(candidate.tags.toSet()).length * 4;
    score +=
        10 -
        (candidate.text.runes.length - target.text.runes.length).abs().clamp(
          0,
          10,
        );
    return score;
  }

  List<String> _stableChoiceOrder(
    String seed,
    String answer,
    Iterable<String> alternatives,
    int count,
  ) {
    final byNormalized = <String, String>{_normalized(answer): answer};
    for (final value in alternatives) {
      if (byNormalized.length >= count) break;
      byNormalized.putIfAbsent(_normalized(value), () => value);
    }
    final values = byNormalized.values.toList();
    values.sort(
      (left, right) =>
          _stableHash('$seed|$left').compareTo(_stableHash('$seed|$right')),
    );
    return values;
  }
}

class QuizHintBuilder {
  const QuizHintBuilder();

  String build({
    required LearningItem item,
    required QuizHintMode mode,
    required int level,
    String? clozeAnswer,
    int orderedTokenCount = 0,
    String? readingAidsLabel,
  }) {
    final safeLevel = level.clamp(1, 2);
    return switch (mode) {
      QuizHintMode.recognition =>
        safeLevel == 1
            ? _readingOrMetadata(item, readingAidsLabel)
            : '뜻은 ${_firstCharacter(item.primaryTranslation)}로 시작하고 '
                  '${item.primaryTranslation.runes.length}글자예요.',
      QuizHintMode.production =>
        safeLevel == 1
            ? _readingOrMetadata(item, readingAidsLabel)
            : '표현은 ${_firstCharacter(item.text)}로 시작하고 '
                  '${item.text.runes.length}글자예요.',
      QuizHintMode.cloze =>
        safeLevel == 1
            ? '문장 뜻: ${item.primaryTranslation}'
            : '빈칸은 ${_firstCharacter(clozeAnswer ?? '')}로 시작하고 '
                  '${(clozeAnswer ?? '').runes.length}글자예요.',
      QuizHintMode.sentenceOrder => _sentenceOrderHint(
        item,
        safeLevel,
        orderedTokenCount,
      ),
      QuizHintMode.listening =>
        safeLevel == 1
            ? '${_unitCount(item.text)}로 이루어진 표현이에요.'
            : '첫 글자는 ${_firstCharacter(item.text)}이고, '
                  '${_readingOrMetadata(item, readingAidsLabel)}',
    };
  }

  String _sentenceOrderHint(
    LearningItem item,
    int level,
    int orderedTokenCount,
  ) {
    if (orderedTokenCount >= item.sentenceTokens.length) {
      return '배열을 마쳤어요. 조사·어순을 한 번 더 확인해 보세요.';
    }
    final next = item.sentenceTokens[orderedTokenCount];
    if (level == 1) {
      return '다음 토큰은 ${_firstCharacter(next)}로 시작해요.';
    }
    return '다음 토큰은 “$next”예요.';
  }

  String _readingOrMetadata(
    LearningItem item,
    String? filteredReadingAidsLabel,
  ) {
    final label = filteredReadingAidsLabel ?? item.readingAidsLabel;
    if (label.trim().isNotEmpty) {
      return '읽기 도움: ${label.replaceAll('\n', ' · ')}';
    }
    final kind = item.kind == LearningItemKind.word ? '단어' : '문장';
    return '${item.level} 단계의 $kind예요.';
  }

  String _unitCount(String value) {
    final words = value.trim().split(RegExp(r'\s+'));
    if (words.length > 1) return '${words.length}개 단어';
    return '${value.runes.length}글자';
  }

  String _firstCharacter(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty
        ? '빈칸'
        : '“${String.fromCharCode(trimmed.runes.first)}”';
  }
}

String _normalized(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

bool _containsLetterOrNumber(String value) =>
    RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(value);

int _stableHash(String value) {
  var hash = 17;
  for (final codeUnit in value.codeUnits) {
    hash = (37 * hash + codeUnit) & 0x7fffffff;
  }
  return hash;
}
