import 'language.dart';

enum StudySubjectKind { language, general }

const _languageSubjectPrefix = 'language:';

String languageSubjectId(LanguageTag language) =>
    '$_languageSubjectPrefix${language.code.toLowerCase()}';

String normalizeStudySubjectId(String value) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[a-z0-9][a-z0-9._:-]{0,79}$').hasMatch(normalized)) {
    throw const FormatException(
      '학습 주제 ID는 영문 소문자·숫자로 시작하고 영문, 숫자, 점, 밑줄, 콜론, 하이픈만 사용할 수 있습니다.',
    );
  }
  return normalized;
}

String courseIdForSubject(String subjectId) {
  final normalized = normalizeStudySubjectId(subjectId);
  if (normalized.startsWith(_languageSubjectPrefix)) {
    final languageCode = normalized.substring(_languageSubjectPrefix.length);
    for (final language in LanguageTag.values) {
      if (language.code.toLowerCase() == languageCode) {
        return language.courseId;
      }
    }
    return 'ko-$languageCode';
  }
  return 'subject:$normalized';
}

bool isSupportedCourseId(String value) {
  if (LanguageTag.values.any((language) => language.courseId == value)) {
    return true;
  }
  const prefix = 'subject:';
  if (!value.startsWith(prefix)) return false;
  try {
    normalizeStudySubjectId(value.substring(prefix.length));
    return true;
  } on FormatException {
    return false;
  }
}

class StudySubject {
  const StudySubject({
    required this.id,
    required this.kind,
    required this.name,
    required this.description,
    required this.symbol,
    required this.contentLanguage,
    this.createdAt,
    this.updatedAt,
  });

  factory StudySubject.language(LanguageTag language) => StudySubject(
    id: languageSubjectId(language),
    kind: StudySubjectKind.language,
    name: language.koreanName,
    description: '${language.nativeName} 언어 코스',
    symbol: language.symbol,
    contentLanguage: language,
  );

  final String id;
  final StudySubjectKind kind;
  final String name;
  final String description;
  final String symbol;
  final LanguageTag contentLanguage;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLanguage => kind == StudySubjectKind.language;
  String get courseId => courseIdForSubject(id);

  StudySubject copyWith({
    String? id,
    StudySubjectKind? kind,
    String? name,
    String? description,
    String? symbol,
    LanguageTag? contentLanguage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudySubject(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      description: description ?? this.description,
      symbol: symbol ?? this.symbol,
      contentLanguage: contentLanguage ?? this.contentLanguage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'name': name,
    'description': description,
    'symbol': symbol,
    'contentLanguage': contentLanguage.code,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };

  factory StudySubject.fromJson(Map<String, Object?> json) {
    final id = normalizeStudySubjectId(json['id'] as String? ?? '');
    final name = (json['name'] as String? ?? '').trim();
    final description = (json['description'] as String? ?? '').trim();
    final symbol = (json['symbol'] as String? ?? '').trim();
    if (name.isEmpty || name.runes.length > 60) {
      throw const FormatException('학습 주제 이름은 1~60자여야 합니다.');
    }
    if (description.runes.length > 240) {
      throw const FormatException('학습 주제 설명은 240자 이하여야 합니다.');
    }
    if (symbol.isEmpty || symbol.runes.length > 4) {
      throw const FormatException('학습 주제 기호는 1~4자여야 합니다.');
    }
    final kindName = json['kind'] as String? ?? StudySubjectKind.general.name;
    final kind = StudySubjectKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => throw FormatException('지원하지 않는 학습 주제 종류입니다: $kindName'),
    );
    final languageCode = json['contentLanguage'] as String? ?? 'ko';
    final contentLanguage = LanguageTag.values.firstWhere(
      (value) => value.code == languageCode,
      orElse: () => throw FormatException('지원하지 않는 콘텐츠 언어입니다: $languageCode'),
    );
    if (kind == StudySubjectKind.language &&
        id != languageSubjectId(contentLanguage)) {
      throw const FormatException('언어 주제 ID와 콘텐츠 언어가 일치하지 않습니다.');
    }
    return StudySubject(
      id: id,
      kind: kind,
      name: name,
      description: description,
      symbol: symbol,
      contentLanguage: contentLanguage,
      createdAt: _optionalDate(json['createdAt']),
      updatedAt: _optionalDate(json['updatedAt']),
    );
  }
}

List<StudySubject> get builtInLanguageSubjects => [
  for (final language in LanguageTag.values)
    if (language.available) StudySubject.language(language),
];

DateTime? _optionalDate(Object? value) {
  if (value == null) return null;
  if (value is! String || DateTime.tryParse(value) == null) {
    throw const FormatException('학습 주제 날짜는 ISO 8601 형식이어야 합니다.');
  }
  return DateTime.parse(value).toUtc();
}
