/// A compact, route-oriented command exposed by the global command palette.
///
/// [route] is null only for commands that are handled in-place by the shell,
/// such as opening the quick-add sheet.
class CommandPaletteCommand {
  const CommandPaletteCommand({
    required this.id,
    required this.title,
    required this.description,
    required this.keywords,
    this.route,
    this.practiceActivityId,
  });

  final String id;
  final String title;
  final String description;
  final List<String> keywords;
  final String? route;
  final String? practiceActivityId;
}

/// Commands shared by desktop and mobile entry points.
///
/// Korean and English aliases are deliberately included so people can type
/// the words they already use (for example `drive`, `local`, or `match`).
const appCommandPaletteCommands = <CommandPaletteCommand>[
  CommandPaletteCommand(
    id: 'quick-add',
    title: '빠른 자료 추가',
    description: '단어·문장을 바로 등록',
    keywords: ['추가', '등록', '단어', '문장', 'quick add', 'new'],
  ),
  CommandPaletteCommand(
    id: 'home',
    title: '오늘로 이동',
    description: '오늘의 학습 현황과 이어하기',
    keywords: ['홈', '오늘', 'home', 'dashboard'],
    route: '/home',
  ),
  CommandPaletteCommand(
    id: 'library',
    title: '자료실 열기',
    description: '등록한 단어·문장 검색과 정리',
    keywords: ['자료실', '단어장', '목록', 'library', 'vocabulary'],
    route: '/library',
  ),
  CommandPaletteCommand(
    id: 'learning-hub',
    title: '학습 허브 열기',
    description: '추천 학습, 게임, 미션 한곳에서 보기',
    keywords: ['학습', '게임', '퀴즈', '연습', 'learn', 'practice'],
    route: '/learn',
  ),
  CommandPaletteCommand(
    id: 'stats',
    title: '학습 기록 열기',
    description: 'XP, 연속 학습일, 학습 추세 확인',
    keywords: ['기록', '통계', '진도', 'stats', 'progress', 'xp'],
    route: '/stats',
  ),
  CommandPaletteCommand(
    id: 'import',
    title: '파일로 자료 가져오기',
    description: 'Excel·CSV·JSON을 검토한 뒤 등록',
    keywords: ['가져오기', '엑셀', 'csv', 'json', 'import', '파일'],
    route: '/import',
  ),
  CommandPaletteCommand(
    id: 'language-packs',
    title: 'GitHub 언어팩 받기',
    description: '공개 언어팩을 확인하고 내 자료에 추가',
    keywords: [
      '언어팩',
      '어휘팩',
      '단어팩',
      '다운로드',
      'github',
      'language pack',
      'vocabulary pack',
    ],
    route: '/library/language-packs',
  ),
  CommandPaletteCommand(
    id: 'new-item',
    title: '상세 편집기로 등록',
    description: '뜻·예문·태그까지 새 자료 작성',
    keywords: ['새 자료', '편집기', '등록', 'new item', 'editor'],
    route: '/library/new',
  ),
  CommandPaletteCommand(
    id: 'settings',
    title: '설정 열기',
    description: '화면, 학습, 접근성 환경 설정',
    keywords: ['설정', '환경설정', '테마', 'settings', 'preferences'],
    route: '/settings',
  ),
  CommandPaletteCommand(
    id: 'storage-settings',
    title: 'Google Drive · 로컬 저장 위치',
    description: '동기화 연결과 현재 저장 폴더 확인',
    keywords: [
      '저장',
      '동기화',
      '구글 드라이브',
      'google drive',
      'drive',
      '로컬',
      'local',
      '폴더',
      'folder',
      '백업',
    ],
    route: '/settings?focus=storage',
  ),
  CommandPaletteCommand(
    id: 'course-path',
    title: '코스 경로 열기',
    description: '단원별 진행과 마스터리 확인',
    keywords: ['코스', '단원', '경로', 'course', 'path', 'mastery'],
    route: '/path',
  ),
  CommandPaletteCommand(
    id: 'missions',
    title: '상황 미션 열기',
    description: '분기형 실전 회화 미션',
    keywords: ['미션', '상황', '회화', 'mission', 'scenario'],
    route: '/missions',
  ),
  CommandPaletteCommand(
    id: 'mixed-quiz',
    title: '혼합 퀴즈 시작',
    description: '여러 문제 유형을 섞어 복습',
    keywords: ['혼합', '퀴즈', '문제', 'mixed quiz', 'game'],
    practiceActivityId: 'mixed-quiz',
  ),
  CommandPaletteCommand(
    id: 'exam-simulator',
    title: '시험 시뮬레이터 시작',
    description: '시간·문항·합격선을 정해 실전 점검',
    keywords: ['시험', '모의고사', '합격선', 'exam', 'test', 'simulator'],
    practiceActivityId: 'exam-simulator',
  ),
  CommandPaletteCommand(
    id: 'meaning-choice',
    title: '뜻 고르기 시작',
    description: '보기에서 알맞은 뜻 선택',
    keywords: ['뜻', '고르기', '객관식', 'meaning', 'choice', 'quiz'],
    practiceActivityId: 'meaning-choice',
  ),
  CommandPaletteCommand(
    id: 'production-writing',
    title: '직접 입력 시작',
    description: '힌트를 보고 정답을 직접 작성',
    keywords: ['직접 입력', '타이핑', '쓰기', 'production', 'typing'],
    practiceActivityId: 'production-writing',
  ),
  CommandPaletteCommand(
    id: 'listening-discrimination',
    title: '소리 구별 시작',
    description: '소리를 듣고 표현 구별하기',
    keywords: ['듣기', '소리 구별', '청해', 'listening', 'audio', 'minimal pair'],
    practiceActivityId: 'listening-discrimination',
  ),
  CommandPaletteCommand(
    id: 'sentence-order',
    title: '문장 배열 시작',
    description: '토큰을 순서대로 조립',
    keywords: ['문장 배열', '순서', '조립', 'sentence order', 'tokens'],
    practiceActivityId: 'sentence-order',
  ),
  CommandPaletteCommand(
    id: 'match-sprint',
    title: '매치 스프린트 시작',
    description: '단어와 뜻을 빠르게 짝맞추기',
    keywords: ['매치', '짝맞추기', '스프린트', 'match', 'matching', 'game'],
    practiceActivityId: 'match-sprint',
  ),
  CommandPaletteCommand(
    id: 'flashcards',
    title: '플래시카드 시작',
    description: '카드를 넘기며 빠르게 복습',
    keywords: ['카드', '플래시카드', '암기', 'flashcard', 'cards'],
    practiceActivityId: 'word-cards',
  ),
  CommandPaletteCommand(
    id: 'pronunciation',
    title: '발음 따라하기 시작',
    description: '듣고 녹음하며 발음 연습',
    keywords: ['발음', '말하기', '녹음', 'pronunciation', 'speaking'],
    practiceActivityId: 'pronunciation',
  ),
];

/// Fuzzy-ranks commands while keeping the authored order for equal scores.
List<CommandPaletteCommand> searchCommandPalette(
  String query, {
  List<CommandPaletteCommand> commands = appCommandPaletteCommands,
  int? limit,
}) {
  final normalizedQuery = _normalize(query);
  if (normalizedQuery.isEmpty) {
    return List.unmodifiable(limit == null ? commands : commands.take(limit));
  }
  final queryTokens = normalizedQuery.split(' ');
  final ranked = <({CommandPaletteCommand command, int score, int index})>[];
  for (final (index, command) in commands.indexed) {
    final title = _normalize(command.title);
    final aliases = command.keywords.map(_normalize).toList(growable: false);
    final searchable =
        '$title ${_normalize(command.description)} ${aliases.join(' ')}';
    var score = 0;
    var allTokensMatched = true;
    for (final token in queryTokens) {
      final tokenScore = _tokenScore(token, title, aliases, searchable);
      if (tokenScore == 0) {
        allTokensMatched = false;
        break;
      }
      score += tokenScore;
    }
    if (!allTokensMatched) continue;
    if (title == normalizedQuery) score += 1000;
    if (title.startsWith(normalizedQuery)) score += 500;
    ranked.add((command: command, score: score, index: index));
  }
  ranked.sort((left, right) {
    final byScore = right.score.compareTo(left.score);
    return byScore != 0 ? byScore : left.index.compareTo(right.index);
  });
  final values = ranked.map((entry) => entry.command);
  return List.unmodifiable(limit == null ? values : values.take(limit));
}

int _tokenScore(
  String token,
  String title,
  List<String> aliases,
  String searchable,
) {
  if (title == token) return 900;
  if (aliases.contains(token)) return 850;
  if (title.startsWith(token)) return 700;
  if (aliases.any((alias) => alias.startsWith(token))) return 650;
  if (title.contains(token)) return 500;
  if (aliases.any((alias) => alias.contains(token))) return 450;
  if (searchable.contains(token)) return 350;
  if (token.length >= 2 && _isSubsequence(token, title)) return 180;
  if (token.length >= 3 &&
      aliases.any((alias) => _isSubsequence(token, alias))) {
    return 140;
  }
  return 0;
}

bool _isSubsequence(String needle, String haystack) {
  var index = 0;
  for (final rune in haystack.runes) {
    if (rune == needle.runes.elementAt(index)) {
      index += 1;
      if (index == needle.runes.length) return true;
    }
  }
  return false;
}

String _normalize(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[\s·,./?…:;()\[\]{}_\-]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ');
