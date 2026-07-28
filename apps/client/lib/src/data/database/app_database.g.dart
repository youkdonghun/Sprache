// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ContentItemsTable extends ContentItems
    with TableInfo<$ContentItemsTable, ContentItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseLanguageTagMeta = const VerificationMeta(
    'baseLanguageTag',
  );
  @override
  late final GeneratedColumn<String> baseLanguageTag = GeneratedColumn<String>(
    'base_language_tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ko'),
  );
  static const VerificationMeta _learningLanguageTagMeta =
      const VerificationMeta('learningLanguageTag');
  @override
  late final GeneratedColumn<String> learningLanguageTag =
      GeneratedColumn<String>(
        'learning_language_tag',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _textValueMeta = const VerificationMeta(
    'textValue',
  );
  @override
  late final GeneratedColumn<String> textValue = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _translationsJsonMeta = const VerificationMeta(
    'translationsJson',
  );
  @override
  late final GeneratedColumn<String> translationsJson = GeneratedColumn<String>(
    'translations_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acceptedAnswersJsonMeta =
      const VerificationMeta('acceptedAnswersJson');
  @override
  late final GeneratedColumn<String> acceptedAnswersJson =
      GeneratedColumn<String>(
        'accepted_answers_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _readingsJsonMeta = const VerificationMeta(
    'readingsJson',
  );
  @override
  late final GeneratedColumn<String> readingsJson = GeneratedColumn<String>(
    'readings_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _sentenceTokensJsonMeta =
      const VerificationMeta('sentenceTokensJson');
  @override
  late final GeneratedColumn<String> sentenceTokensJson =
      GeneratedColumn<String>(
        'sentence_tokens_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _tagsJsonMeta = const VerificationMeta(
    'tagsJson',
  );
  @override
  late final GeneratedColumn<String> tagsJson = GeneratedColumn<String>(
    'tags_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('입문'),
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _selectedForStudyMeta = const VerificationMeta(
    'selectedForStudy',
  );
  @override
  late final GeneratedColumn<bool> selectedForStudy = GeneratedColumn<bool>(
    'selected_for_study',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("selected_for_study" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _suspendedMeta = const VerificationMeta(
    'suspended',
  );
  @override
  late final GeneratedColumn<bool> suspended = GeneratedColumn<bool>(
    'suspended',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("suspended" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sourceJsonMeta = const VerificationMeta(
    'sourceJson',
  );
  @override
  late final GeneratedColumn<String> sourceJson = GeneratedColumn<String>(
    'source_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    baseLanguageTag,
    learningLanguageTag,
    textValue,
    translationsJson,
    acceptedAnswersJson,
    readingsJson,
    sentenceTokensJson,
    tagsJson,
    level,
    enabled,
    selectedForStudy,
    suspended,
    priority,
    sourceJson,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('base_language_tag')) {
      context.handle(
        _baseLanguageTagMeta,
        baseLanguageTag.isAcceptableOrUnknown(
          data['base_language_tag']!,
          _baseLanguageTagMeta,
        ),
      );
    }
    if (data.containsKey('learning_language_tag')) {
      context.handle(
        _learningLanguageTagMeta,
        learningLanguageTag.isAcceptableOrUnknown(
          data['learning_language_tag']!,
          _learningLanguageTagMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_learningLanguageTagMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _textValueMeta,
        textValue.isAcceptableOrUnknown(data['text']!, _textValueMeta),
      );
    } else if (isInserting) {
      context.missing(_textValueMeta);
    }
    if (data.containsKey('translations_json')) {
      context.handle(
        _translationsJsonMeta,
        translationsJson.isAcceptableOrUnknown(
          data['translations_json']!,
          _translationsJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_translationsJsonMeta);
    }
    if (data.containsKey('accepted_answers_json')) {
      context.handle(
        _acceptedAnswersJsonMeta,
        acceptedAnswersJson.isAcceptableOrUnknown(
          data['accepted_answers_json']!,
          _acceptedAnswersJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_acceptedAnswersJsonMeta);
    }
    if (data.containsKey('readings_json')) {
      context.handle(
        _readingsJsonMeta,
        readingsJson.isAcceptableOrUnknown(
          data['readings_json']!,
          _readingsJsonMeta,
        ),
      );
    }
    if (data.containsKey('sentence_tokens_json')) {
      context.handle(
        _sentenceTokensJsonMeta,
        sentenceTokensJson.isAcceptableOrUnknown(
          data['sentence_tokens_json']!,
          _sentenceTokensJsonMeta,
        ),
      );
    }
    if (data.containsKey('tags_json')) {
      context.handle(
        _tagsJsonMeta,
        tagsJson.isAcceptableOrUnknown(data['tags_json']!, _tagsJsonMeta),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('selected_for_study')) {
      context.handle(
        _selectedForStudyMeta,
        selectedForStudy.isAcceptableOrUnknown(
          data['selected_for_study']!,
          _selectedForStudyMeta,
        ),
      );
    }
    if (data.containsKey('suspended')) {
      context.handle(
        _suspendedMeta,
        suspended.isAcceptableOrUnknown(data['suspended']!, _suspendedMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('source_json')) {
      context.handle(
        _sourceJsonMeta,
        sourceJson.isAcceptableOrUnknown(data['source_json']!, _sourceJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContentItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentItemRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      baseLanguageTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_language_tag'],
      )!,
      learningLanguageTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}learning_language_tag'],
      )!,
      textValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      translationsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}translations_json'],
      )!,
      acceptedAnswersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accepted_answers_json'],
      )!,
      readingsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}readings_json'],
      )!,
      sentenceTokensJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sentence_tokens_json'],
      )!,
      tagsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags_json'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      selectedForStudy: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}selected_for_study'],
      )!,
      suspended: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}suspended'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      sourceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ContentItemsTable createAlias(String alias) {
    return $ContentItemsTable(attachedDatabase, alias);
  }
}

class ContentItemRow extends DataClass implements Insertable<ContentItemRow> {
  final String id;
  final String kind;
  final String baseLanguageTag;
  final String learningLanguageTag;
  final String textValue;
  final String translationsJson;
  final String acceptedAnswersJson;
  final String readingsJson;
  final String sentenceTokensJson;
  final String tagsJson;
  final String level;
  final bool enabled;
  final bool selectedForStudy;
  final bool suspended;
  final int priority;
  final String sourceJson;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const ContentItemRow({
    required this.id,
    required this.kind,
    required this.baseLanguageTag,
    required this.learningLanguageTag,
    required this.textValue,
    required this.translationsJson,
    required this.acceptedAnswersJson,
    required this.readingsJson,
    required this.sentenceTokensJson,
    required this.tagsJson,
    required this.level,
    required this.enabled,
    required this.selectedForStudy,
    required this.suspended,
    required this.priority,
    required this.sourceJson,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    map['base_language_tag'] = Variable<String>(baseLanguageTag);
    map['learning_language_tag'] = Variable<String>(learningLanguageTag);
    map['text'] = Variable<String>(textValue);
    map['translations_json'] = Variable<String>(translationsJson);
    map['accepted_answers_json'] = Variable<String>(acceptedAnswersJson);
    map['readings_json'] = Variable<String>(readingsJson);
    map['sentence_tokens_json'] = Variable<String>(sentenceTokensJson);
    map['tags_json'] = Variable<String>(tagsJson);
    map['level'] = Variable<String>(level);
    map['enabled'] = Variable<bool>(enabled);
    map['selected_for_study'] = Variable<bool>(selectedForStudy);
    map['suspended'] = Variable<bool>(suspended);
    map['priority'] = Variable<int>(priority);
    map['source_json'] = Variable<String>(sourceJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ContentItemsCompanion toCompanion(bool nullToAbsent) {
    return ContentItemsCompanion(
      id: Value(id),
      kind: Value(kind),
      baseLanguageTag: Value(baseLanguageTag),
      learningLanguageTag: Value(learningLanguageTag),
      textValue: Value(textValue),
      translationsJson: Value(translationsJson),
      acceptedAnswersJson: Value(acceptedAnswersJson),
      readingsJson: Value(readingsJson),
      sentenceTokensJson: Value(sentenceTokensJson),
      tagsJson: Value(tagsJson),
      level: Value(level),
      enabled: Value(enabled),
      selectedForStudy: Value(selectedForStudy),
      suspended: Value(suspended),
      priority: Value(priority),
      sourceJson: Value(sourceJson),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ContentItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentItemRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      baseLanguageTag: serializer.fromJson<String>(json['baseLanguageTag']),
      learningLanguageTag: serializer.fromJson<String>(
        json['learningLanguageTag'],
      ),
      textValue: serializer.fromJson<String>(json['textValue']),
      translationsJson: serializer.fromJson<String>(json['translationsJson']),
      acceptedAnswersJson: serializer.fromJson<String>(
        json['acceptedAnswersJson'],
      ),
      readingsJson: serializer.fromJson<String>(json['readingsJson']),
      sentenceTokensJson: serializer.fromJson<String>(
        json['sentenceTokensJson'],
      ),
      tagsJson: serializer.fromJson<String>(json['tagsJson']),
      level: serializer.fromJson<String>(json['level']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      selectedForStudy: serializer.fromJson<bool>(json['selectedForStudy']),
      suspended: serializer.fromJson<bool>(json['suspended']),
      priority: serializer.fromJson<int>(json['priority']),
      sourceJson: serializer.fromJson<String>(json['sourceJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'baseLanguageTag': serializer.toJson<String>(baseLanguageTag),
      'learningLanguageTag': serializer.toJson<String>(learningLanguageTag),
      'textValue': serializer.toJson<String>(textValue),
      'translationsJson': serializer.toJson<String>(translationsJson),
      'acceptedAnswersJson': serializer.toJson<String>(acceptedAnswersJson),
      'readingsJson': serializer.toJson<String>(readingsJson),
      'sentenceTokensJson': serializer.toJson<String>(sentenceTokensJson),
      'tagsJson': serializer.toJson<String>(tagsJson),
      'level': serializer.toJson<String>(level),
      'enabled': serializer.toJson<bool>(enabled),
      'selectedForStudy': serializer.toJson<bool>(selectedForStudy),
      'suspended': serializer.toJson<bool>(suspended),
      'priority': serializer.toJson<int>(priority),
      'sourceJson': serializer.toJson<String>(sourceJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ContentItemRow copyWith({
    String? id,
    String? kind,
    String? baseLanguageTag,
    String? learningLanguageTag,
    String? textValue,
    String? translationsJson,
    String? acceptedAnswersJson,
    String? readingsJson,
    String? sentenceTokensJson,
    String? tagsJson,
    String? level,
    bool? enabled,
    bool? selectedForStudy,
    bool? suspended,
    int? priority,
    String? sourceJson,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ContentItemRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    baseLanguageTag: baseLanguageTag ?? this.baseLanguageTag,
    learningLanguageTag: learningLanguageTag ?? this.learningLanguageTag,
    textValue: textValue ?? this.textValue,
    translationsJson: translationsJson ?? this.translationsJson,
    acceptedAnswersJson: acceptedAnswersJson ?? this.acceptedAnswersJson,
    readingsJson: readingsJson ?? this.readingsJson,
    sentenceTokensJson: sentenceTokensJson ?? this.sentenceTokensJson,
    tagsJson: tagsJson ?? this.tagsJson,
    level: level ?? this.level,
    enabled: enabled ?? this.enabled,
    selectedForStudy: selectedForStudy ?? this.selectedForStudy,
    suspended: suspended ?? this.suspended,
    priority: priority ?? this.priority,
    sourceJson: sourceJson ?? this.sourceJson,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ContentItemRow copyWithCompanion(ContentItemsCompanion data) {
    return ContentItemRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      baseLanguageTag: data.baseLanguageTag.present
          ? data.baseLanguageTag.value
          : this.baseLanguageTag,
      learningLanguageTag: data.learningLanguageTag.present
          ? data.learningLanguageTag.value
          : this.learningLanguageTag,
      textValue: data.textValue.present ? data.textValue.value : this.textValue,
      translationsJson: data.translationsJson.present
          ? data.translationsJson.value
          : this.translationsJson,
      acceptedAnswersJson: data.acceptedAnswersJson.present
          ? data.acceptedAnswersJson.value
          : this.acceptedAnswersJson,
      readingsJson: data.readingsJson.present
          ? data.readingsJson.value
          : this.readingsJson,
      sentenceTokensJson: data.sentenceTokensJson.present
          ? data.sentenceTokensJson.value
          : this.sentenceTokensJson,
      tagsJson: data.tagsJson.present ? data.tagsJson.value : this.tagsJson,
      level: data.level.present ? data.level.value : this.level,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      selectedForStudy: data.selectedForStudy.present
          ? data.selectedForStudy.value
          : this.selectedForStudy,
      suspended: data.suspended.present ? data.suspended.value : this.suspended,
      priority: data.priority.present ? data.priority.value : this.priority,
      sourceJson: data.sourceJson.present
          ? data.sourceJson.value
          : this.sourceJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentItemRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('baseLanguageTag: $baseLanguageTag, ')
          ..write('learningLanguageTag: $learningLanguageTag, ')
          ..write('textValue: $textValue, ')
          ..write('translationsJson: $translationsJson, ')
          ..write('acceptedAnswersJson: $acceptedAnswersJson, ')
          ..write('readingsJson: $readingsJson, ')
          ..write('sentenceTokensJson: $sentenceTokensJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('level: $level, ')
          ..write('enabled: $enabled, ')
          ..write('selectedForStudy: $selectedForStudy, ')
          ..write('suspended: $suspended, ')
          ..write('priority: $priority, ')
          ..write('sourceJson: $sourceJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    baseLanguageTag,
    learningLanguageTag,
    textValue,
    translationsJson,
    acceptedAnswersJson,
    readingsJson,
    sentenceTokensJson,
    tagsJson,
    level,
    enabled,
    selectedForStudy,
    suspended,
    priority,
    sourceJson,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentItemRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.baseLanguageTag == this.baseLanguageTag &&
          other.learningLanguageTag == this.learningLanguageTag &&
          other.textValue == this.textValue &&
          other.translationsJson == this.translationsJson &&
          other.acceptedAnswersJson == this.acceptedAnswersJson &&
          other.readingsJson == this.readingsJson &&
          other.sentenceTokensJson == this.sentenceTokensJson &&
          other.tagsJson == this.tagsJson &&
          other.level == this.level &&
          other.enabled == this.enabled &&
          other.selectedForStudy == this.selectedForStudy &&
          other.suspended == this.suspended &&
          other.priority == this.priority &&
          other.sourceJson == this.sourceJson &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ContentItemsCompanion extends UpdateCompanion<ContentItemRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String> baseLanguageTag;
  final Value<String> learningLanguageTag;
  final Value<String> textValue;
  final Value<String> translationsJson;
  final Value<String> acceptedAnswersJson;
  final Value<String> readingsJson;
  final Value<String> sentenceTokensJson;
  final Value<String> tagsJson;
  final Value<String> level;
  final Value<bool> enabled;
  final Value<bool> selectedForStudy;
  final Value<bool> suspended;
  final Value<int> priority;
  final Value<String> sourceJson;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ContentItemsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.baseLanguageTag = const Value.absent(),
    this.learningLanguageTag = const Value.absent(),
    this.textValue = const Value.absent(),
    this.translationsJson = const Value.absent(),
    this.acceptedAnswersJson = const Value.absent(),
    this.readingsJson = const Value.absent(),
    this.sentenceTokensJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.level = const Value.absent(),
    this.enabled = const Value.absent(),
    this.selectedForStudy = const Value.absent(),
    this.suspended = const Value.absent(),
    this.priority = const Value.absent(),
    this.sourceJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentItemsCompanion.insert({
    required String id,
    required String kind,
    this.baseLanguageTag = const Value.absent(),
    required String learningLanguageTag,
    required String textValue,
    required String translationsJson,
    required String acceptedAnswersJson,
    this.readingsJson = const Value.absent(),
    this.sentenceTokensJson = const Value.absent(),
    this.tagsJson = const Value.absent(),
    this.level = const Value.absent(),
    this.enabled = const Value.absent(),
    this.selectedForStudy = const Value.absent(),
    this.suspended = const Value.absent(),
    this.priority = const Value.absent(),
    required String sourceJson,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       learningLanguageTag = Value(learningLanguageTag),
       textValue = Value(textValue),
       translationsJson = Value(translationsJson),
       acceptedAnswersJson = Value(acceptedAnswersJson),
       sourceJson = Value(sourceJson),
       updatedAt = Value(updatedAt);
  static Insertable<ContentItemRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? baseLanguageTag,
    Expression<String>? learningLanguageTag,
    Expression<String>? textValue,
    Expression<String>? translationsJson,
    Expression<String>? acceptedAnswersJson,
    Expression<String>? readingsJson,
    Expression<String>? sentenceTokensJson,
    Expression<String>? tagsJson,
    Expression<String>? level,
    Expression<bool>? enabled,
    Expression<bool>? selectedForStudy,
    Expression<bool>? suspended,
    Expression<int>? priority,
    Expression<String>? sourceJson,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (baseLanguageTag != null) 'base_language_tag': baseLanguageTag,
      if (learningLanguageTag != null)
        'learning_language_tag': learningLanguageTag,
      if (textValue != null) 'text': textValue,
      if (translationsJson != null) 'translations_json': translationsJson,
      if (acceptedAnswersJson != null)
        'accepted_answers_json': acceptedAnswersJson,
      if (readingsJson != null) 'readings_json': readingsJson,
      if (sentenceTokensJson != null)
        'sentence_tokens_json': sentenceTokensJson,
      if (tagsJson != null) 'tags_json': tagsJson,
      if (level != null) 'level': level,
      if (enabled != null) 'enabled': enabled,
      if (selectedForStudy != null) 'selected_for_study': selectedForStudy,
      if (suspended != null) 'suspended': suspended,
      if (priority != null) 'priority': priority,
      if (sourceJson != null) 'source_json': sourceJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String>? baseLanguageTag,
    Value<String>? learningLanguageTag,
    Value<String>? textValue,
    Value<String>? translationsJson,
    Value<String>? acceptedAnswersJson,
    Value<String>? readingsJson,
    Value<String>? sentenceTokensJson,
    Value<String>? tagsJson,
    Value<String>? level,
    Value<bool>? enabled,
    Value<bool>? selectedForStudy,
    Value<bool>? suspended,
    Value<int>? priority,
    Value<String>? sourceJson,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ContentItemsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      baseLanguageTag: baseLanguageTag ?? this.baseLanguageTag,
      learningLanguageTag: learningLanguageTag ?? this.learningLanguageTag,
      textValue: textValue ?? this.textValue,
      translationsJson: translationsJson ?? this.translationsJson,
      acceptedAnswersJson: acceptedAnswersJson ?? this.acceptedAnswersJson,
      readingsJson: readingsJson ?? this.readingsJson,
      sentenceTokensJson: sentenceTokensJson ?? this.sentenceTokensJson,
      tagsJson: tagsJson ?? this.tagsJson,
      level: level ?? this.level,
      enabled: enabled ?? this.enabled,
      selectedForStudy: selectedForStudy ?? this.selectedForStudy,
      suspended: suspended ?? this.suspended,
      priority: priority ?? this.priority,
      sourceJson: sourceJson ?? this.sourceJson,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (baseLanguageTag.present) {
      map['base_language_tag'] = Variable<String>(baseLanguageTag.value);
    }
    if (learningLanguageTag.present) {
      map['learning_language_tag'] = Variable<String>(
        learningLanguageTag.value,
      );
    }
    if (textValue.present) {
      map['text'] = Variable<String>(textValue.value);
    }
    if (translationsJson.present) {
      map['translations_json'] = Variable<String>(translationsJson.value);
    }
    if (acceptedAnswersJson.present) {
      map['accepted_answers_json'] = Variable<String>(
        acceptedAnswersJson.value,
      );
    }
    if (readingsJson.present) {
      map['readings_json'] = Variable<String>(readingsJson.value);
    }
    if (sentenceTokensJson.present) {
      map['sentence_tokens_json'] = Variable<String>(sentenceTokensJson.value);
    }
    if (tagsJson.present) {
      map['tags_json'] = Variable<String>(tagsJson.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (selectedForStudy.present) {
      map['selected_for_study'] = Variable<bool>(selectedForStudy.value);
    }
    if (suspended.present) {
      map['suspended'] = Variable<bool>(suspended.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (sourceJson.present) {
      map['source_json'] = Variable<String>(sourceJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentItemsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('baseLanguageTag: $baseLanguageTag, ')
          ..write('learningLanguageTag: $learningLanguageTag, ')
          ..write('textValue: $textValue, ')
          ..write('translationsJson: $translationsJson, ')
          ..write('acceptedAnswersJson: $acceptedAnswersJson, ')
          ..write('readingsJson: $readingsJson, ')
          ..write('sentenceTokensJson: $sentenceTokensJson, ')
          ..write('tagsJson: $tagsJson, ')
          ..write('level: $level, ')
          ..write('enabled: $enabled, ')
          ..write('selectedForStudy: $selectedForStudy, ')
          ..write('suspended: $suspended, ')
          ..write('priority: $priority, ')
          ..write('sourceJson: $sourceJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProgressRowsTable extends ProgressRows
    with TableInfo<$ProgressRowsTable, ProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProgressRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctCountMeta = const VerificationMeta(
    'correctCount',
  );
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
    'correct_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wrongCountMeta = const VerificationMeta(
    'wrongCount',
  );
  @override
  late final GeneratedColumn<int> wrongCount = GeneratedColumn<int>(
    'wrong_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lapseCountMeta = const VerificationMeta(
    'lapseCount',
  );
  @override
  late final GeneratedColumn<int> lapseCount = GeneratedColumn<int>(
    'lapse_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentIntervalDaysMeta =
      const VerificationMeta('currentIntervalDays');
  @override
  late final GeneratedColumn<int> currentIntervalDays = GeneratedColumn<int>(
    'current_interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextReviewAtMeta = const VerificationMeta(
    'nextReviewAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextReviewAt = GeneratedColumn<DateTime>(
    'next_review_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastStudiedAtMeta = const VerificationMeta(
    'lastStudiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastStudiedAt =
      GeneratedColumn<DateTime>(
        'last_studied_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _lastResultMeta = const VerificationMeta(
    'lastResult',
  );
  @override
  late final GeneratedColumn<String> lastResult = GeneratedColumn<String>(
    'last_result',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    courseId,
    itemId,
    status,
    correctCount,
    wrongCount,
    lapseCount,
    currentIntervalDays,
    nextReviewAt,
    lastStudiedAt,
    lastResult,
    deviceId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('correct_count')) {
      context.handle(
        _correctCountMeta,
        correctCount.isAcceptableOrUnknown(
          data['correct_count']!,
          _correctCountMeta,
        ),
      );
    }
    if (data.containsKey('wrong_count')) {
      context.handle(
        _wrongCountMeta,
        wrongCount.isAcceptableOrUnknown(data['wrong_count']!, _wrongCountMeta),
      );
    }
    if (data.containsKey('lapse_count')) {
      context.handle(
        _lapseCountMeta,
        lapseCount.isAcceptableOrUnknown(data['lapse_count']!, _lapseCountMeta),
      );
    }
    if (data.containsKey('current_interval_days')) {
      context.handle(
        _currentIntervalDaysMeta,
        currentIntervalDays.isAcceptableOrUnknown(
          data['current_interval_days']!,
          _currentIntervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('next_review_at')) {
      context.handle(
        _nextReviewAtMeta,
        nextReviewAt.isAcceptableOrUnknown(
          data['next_review_at']!,
          _nextReviewAtMeta,
        ),
      );
    }
    if (data.containsKey('last_studied_at')) {
      context.handle(
        _lastStudiedAtMeta,
        lastStudiedAt.isAcceptableOrUnknown(
          data['last_studied_at']!,
          _lastStudiedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_result')) {
      context.handle(
        _lastResultMeta,
        lastResult.isAcceptableOrUnknown(data['last_result']!, _lastResultMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {courseId, itemId};
  @override
  ProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProgressRow(
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      correctCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_count'],
      )!,
      wrongCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wrong_count'],
      )!,
      lapseCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lapse_count'],
      )!,
      currentIntervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_interval_days'],
      )!,
      nextReviewAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_review_at'],
      ),
      lastStudiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_studied_at'],
      ),
      lastResult: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_result'],
      ),
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProgressRowsTable createAlias(String alias) {
    return $ProgressRowsTable(attachedDatabase, alias);
  }
}

class ProgressRow extends DataClass implements Insertable<ProgressRow> {
  final String courseId;
  final String itemId;
  final String status;
  final int correctCount;
  final int wrongCount;
  final int lapseCount;
  final int currentIntervalDays;
  final DateTime? nextReviewAt;
  final DateTime? lastStudiedAt;
  final String? lastResult;
  final String deviceId;
  final DateTime updatedAt;
  const ProgressRow({
    required this.courseId,
    required this.itemId,
    required this.status,
    required this.correctCount,
    required this.wrongCount,
    required this.lapseCount,
    required this.currentIntervalDays,
    this.nextReviewAt,
    this.lastStudiedAt,
    this.lastResult,
    required this.deviceId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['course_id'] = Variable<String>(courseId);
    map['item_id'] = Variable<String>(itemId);
    map['status'] = Variable<String>(status);
    map['correct_count'] = Variable<int>(correctCount);
    map['wrong_count'] = Variable<int>(wrongCount);
    map['lapse_count'] = Variable<int>(lapseCount);
    map['current_interval_days'] = Variable<int>(currentIntervalDays);
    if (!nullToAbsent || nextReviewAt != null) {
      map['next_review_at'] = Variable<DateTime>(nextReviewAt);
    }
    if (!nullToAbsent || lastStudiedAt != null) {
      map['last_studied_at'] = Variable<DateTime>(lastStudiedAt);
    }
    if (!nullToAbsent || lastResult != null) {
      map['last_result'] = Variable<String>(lastResult);
    }
    map['device_id'] = Variable<String>(deviceId);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProgressRowsCompanion toCompanion(bool nullToAbsent) {
    return ProgressRowsCompanion(
      courseId: Value(courseId),
      itemId: Value(itemId),
      status: Value(status),
      correctCount: Value(correctCount),
      wrongCount: Value(wrongCount),
      lapseCount: Value(lapseCount),
      currentIntervalDays: Value(currentIntervalDays),
      nextReviewAt: nextReviewAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextReviewAt),
      lastStudiedAt: lastStudiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStudiedAt),
      lastResult: lastResult == null && nullToAbsent
          ? const Value.absent()
          : Value(lastResult),
      deviceId: Value(deviceId),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProgressRow(
      courseId: serializer.fromJson<String>(json['courseId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      status: serializer.fromJson<String>(json['status']),
      correctCount: serializer.fromJson<int>(json['correctCount']),
      wrongCount: serializer.fromJson<int>(json['wrongCount']),
      lapseCount: serializer.fromJson<int>(json['lapseCount']),
      currentIntervalDays: serializer.fromJson<int>(
        json['currentIntervalDays'],
      ),
      nextReviewAt: serializer.fromJson<DateTime?>(json['nextReviewAt']),
      lastStudiedAt: serializer.fromJson<DateTime?>(json['lastStudiedAt']),
      lastResult: serializer.fromJson<String?>(json['lastResult']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'courseId': serializer.toJson<String>(courseId),
      'itemId': serializer.toJson<String>(itemId),
      'status': serializer.toJson<String>(status),
      'correctCount': serializer.toJson<int>(correctCount),
      'wrongCount': serializer.toJson<int>(wrongCount),
      'lapseCount': serializer.toJson<int>(lapseCount),
      'currentIntervalDays': serializer.toJson<int>(currentIntervalDays),
      'nextReviewAt': serializer.toJson<DateTime?>(nextReviewAt),
      'lastStudiedAt': serializer.toJson<DateTime?>(lastStudiedAt),
      'lastResult': serializer.toJson<String?>(lastResult),
      'deviceId': serializer.toJson<String>(deviceId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProgressRow copyWith({
    String? courseId,
    String? itemId,
    String? status,
    int? correctCount,
    int? wrongCount,
    int? lapseCount,
    int? currentIntervalDays,
    Value<DateTime?> nextReviewAt = const Value.absent(),
    Value<DateTime?> lastStudiedAt = const Value.absent(),
    Value<String?> lastResult = const Value.absent(),
    String? deviceId,
    DateTime? updatedAt,
  }) => ProgressRow(
    courseId: courseId ?? this.courseId,
    itemId: itemId ?? this.itemId,
    status: status ?? this.status,
    correctCount: correctCount ?? this.correctCount,
    wrongCount: wrongCount ?? this.wrongCount,
    lapseCount: lapseCount ?? this.lapseCount,
    currentIntervalDays: currentIntervalDays ?? this.currentIntervalDays,
    nextReviewAt: nextReviewAt.present ? nextReviewAt.value : this.nextReviewAt,
    lastStudiedAt: lastStudiedAt.present
        ? lastStudiedAt.value
        : this.lastStudiedAt,
    lastResult: lastResult.present ? lastResult.value : this.lastResult,
    deviceId: deviceId ?? this.deviceId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProgressRow copyWithCompanion(ProgressRowsCompanion data) {
    return ProgressRow(
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      status: data.status.present ? data.status.value : this.status,
      correctCount: data.correctCount.present
          ? data.correctCount.value
          : this.correctCount,
      wrongCount: data.wrongCount.present
          ? data.wrongCount.value
          : this.wrongCount,
      lapseCount: data.lapseCount.present
          ? data.lapseCount.value
          : this.lapseCount,
      currentIntervalDays: data.currentIntervalDays.present
          ? data.currentIntervalDays.value
          : this.currentIntervalDays,
      nextReviewAt: data.nextReviewAt.present
          ? data.nextReviewAt.value
          : this.nextReviewAt,
      lastStudiedAt: data.lastStudiedAt.present
          ? data.lastStudiedAt.value
          : this.lastStudiedAt,
      lastResult: data.lastResult.present
          ? data.lastResult.value
          : this.lastResult,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProgressRow(')
          ..write('courseId: $courseId, ')
          ..write('itemId: $itemId, ')
          ..write('status: $status, ')
          ..write('correctCount: $correctCount, ')
          ..write('wrongCount: $wrongCount, ')
          ..write('lapseCount: $lapseCount, ')
          ..write('currentIntervalDays: $currentIntervalDays, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('lastStudiedAt: $lastStudiedAt, ')
          ..write('lastResult: $lastResult, ')
          ..write('deviceId: $deviceId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    courseId,
    itemId,
    status,
    correctCount,
    wrongCount,
    lapseCount,
    currentIntervalDays,
    nextReviewAt,
    lastStudiedAt,
    lastResult,
    deviceId,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProgressRow &&
          other.courseId == this.courseId &&
          other.itemId == this.itemId &&
          other.status == this.status &&
          other.correctCount == this.correctCount &&
          other.wrongCount == this.wrongCount &&
          other.lapseCount == this.lapseCount &&
          other.currentIntervalDays == this.currentIntervalDays &&
          other.nextReviewAt == this.nextReviewAt &&
          other.lastStudiedAt == this.lastStudiedAt &&
          other.lastResult == this.lastResult &&
          other.deviceId == this.deviceId &&
          other.updatedAt == this.updatedAt);
}

class ProgressRowsCompanion extends UpdateCompanion<ProgressRow> {
  final Value<String> courseId;
  final Value<String> itemId;
  final Value<String> status;
  final Value<int> correctCount;
  final Value<int> wrongCount;
  final Value<int> lapseCount;
  final Value<int> currentIntervalDays;
  final Value<DateTime?> nextReviewAt;
  final Value<DateTime?> lastStudiedAt;
  final Value<String?> lastResult;
  final Value<String> deviceId;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProgressRowsCompanion({
    this.courseId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.status = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.wrongCount = const Value.absent(),
    this.lapseCount = const Value.absent(),
    this.currentIntervalDays = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.lastStudiedAt = const Value.absent(),
    this.lastResult = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProgressRowsCompanion.insert({
    required String courseId,
    required String itemId,
    required String status,
    this.correctCount = const Value.absent(),
    this.wrongCount = const Value.absent(),
    this.lapseCount = const Value.absent(),
    this.currentIntervalDays = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.lastStudiedAt = const Value.absent(),
    this.lastResult = const Value.absent(),
    required String deviceId,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : courseId = Value(courseId),
       itemId = Value(itemId),
       status = Value(status),
       deviceId = Value(deviceId),
       updatedAt = Value(updatedAt);
  static Insertable<ProgressRow> custom({
    Expression<String>? courseId,
    Expression<String>? itemId,
    Expression<String>? status,
    Expression<int>? correctCount,
    Expression<int>? wrongCount,
    Expression<int>? lapseCount,
    Expression<int>? currentIntervalDays,
    Expression<DateTime>? nextReviewAt,
    Expression<DateTime>? lastStudiedAt,
    Expression<String>? lastResult,
    Expression<String>? deviceId,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (courseId != null) 'course_id': courseId,
      if (itemId != null) 'item_id': itemId,
      if (status != null) 'status': status,
      if (correctCount != null) 'correct_count': correctCount,
      if (wrongCount != null) 'wrong_count': wrongCount,
      if (lapseCount != null) 'lapse_count': lapseCount,
      if (currentIntervalDays != null)
        'current_interval_days': currentIntervalDays,
      if (nextReviewAt != null) 'next_review_at': nextReviewAt,
      if (lastStudiedAt != null) 'last_studied_at': lastStudiedAt,
      if (lastResult != null) 'last_result': lastResult,
      if (deviceId != null) 'device_id': deviceId,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProgressRowsCompanion copyWith({
    Value<String>? courseId,
    Value<String>? itemId,
    Value<String>? status,
    Value<int>? correctCount,
    Value<int>? wrongCount,
    Value<int>? lapseCount,
    Value<int>? currentIntervalDays,
    Value<DateTime?>? nextReviewAt,
    Value<DateTime?>? lastStudiedAt,
    Value<String?>? lastResult,
    Value<String>? deviceId,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProgressRowsCompanion(
      courseId: courseId ?? this.courseId,
      itemId: itemId ?? this.itemId,
      status: status ?? this.status,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      lapseCount: lapseCount ?? this.lapseCount,
      currentIntervalDays: currentIntervalDays ?? this.currentIntervalDays,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      lastStudiedAt: lastStudiedAt ?? this.lastStudiedAt,
      lastResult: lastResult ?? this.lastResult,
      deviceId: deviceId ?? this.deviceId,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    if (wrongCount.present) {
      map['wrong_count'] = Variable<int>(wrongCount.value);
    }
    if (lapseCount.present) {
      map['lapse_count'] = Variable<int>(lapseCount.value);
    }
    if (currentIntervalDays.present) {
      map['current_interval_days'] = Variable<int>(currentIntervalDays.value);
    }
    if (nextReviewAt.present) {
      map['next_review_at'] = Variable<DateTime>(nextReviewAt.value);
    }
    if (lastStudiedAt.present) {
      map['last_studied_at'] = Variable<DateTime>(lastStudiedAt.value);
    }
    if (lastResult.present) {
      map['last_result'] = Variable<String>(lastResult.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProgressRowsCompanion(')
          ..write('courseId: $courseId, ')
          ..write('itemId: $itemId, ')
          ..write('status: $status, ')
          ..write('correctCount: $correctCount, ')
          ..write('wrongCount: $wrongCount, ')
          ..write('lapseCount: $lapseCount, ')
          ..write('currentIntervalDays: $currentIntervalDays, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('lastStudiedAt: $lastStudiedAt, ')
          ..write('lastResult: $lastResult, ')
          ..write('deviceId: $deviceId, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudyEventsTable extends StudyEvents
    with TableInfo<$StudyEventsTable, StudyEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudyEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exerciseTypeMeta = const VerificationMeta(
    'exerciseType',
  );
  @override
  late final GeneratedColumn<String> exerciseType = GeneratedColumn<String>(
    'exercise_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _studiedAtMeta = const VerificationMeta(
    'studiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> studiedAt = GeneratedColumn<DateTime>(
    'studied_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    courseId,
    itemId,
    exerciseType,
    result,
    studiedAt,
    deviceId,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudyEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('exercise_type')) {
      context.handle(
        _exerciseTypeMeta,
        exerciseType.isAcceptableOrUnknown(
          data['exercise_type']!,
          _exerciseTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exerciseTypeMeta);
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    } else if (isInserting) {
      context.missing(_resultMeta);
    }
    if (data.containsKey('studied_at')) {
      context.handle(
        _studiedAtMeta,
        studiedAt.isAcceptableOrUnknown(data['studied_at']!, _studiedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_studiedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  StudyEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudyEventRow(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      exerciseType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_type'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      )!,
      studiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}studied_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $StudyEventsTable createAlias(String alias) {
    return $StudyEventsTable(attachedDatabase, alias);
  }
}

class StudyEventRow extends DataClass implements Insertable<StudyEventRow> {
  final String eventId;
  final String courseId;
  final String itemId;
  final String exerciseType;
  final String result;
  final DateTime studiedAt;
  final String deviceId;
  final bool synced;
  const StudyEventRow({
    required this.eventId,
    required this.courseId,
    required this.itemId,
    required this.exerciseType,
    required this.result,
    required this.studiedAt,
    required this.deviceId,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['course_id'] = Variable<String>(courseId);
    map['item_id'] = Variable<String>(itemId);
    map['exercise_type'] = Variable<String>(exerciseType);
    map['result'] = Variable<String>(result);
    map['studied_at'] = Variable<DateTime>(studiedAt);
    map['device_id'] = Variable<String>(deviceId);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  StudyEventsCompanion toCompanion(bool nullToAbsent) {
    return StudyEventsCompanion(
      eventId: Value(eventId),
      courseId: Value(courseId),
      itemId: Value(itemId),
      exerciseType: Value(exerciseType),
      result: Value(result),
      studiedAt: Value(studiedAt),
      deviceId: Value(deviceId),
      synced: Value(synced),
    );
  }

  factory StudyEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudyEventRow(
      eventId: serializer.fromJson<String>(json['eventId']),
      courseId: serializer.fromJson<String>(json['courseId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      exerciseType: serializer.fromJson<String>(json['exerciseType']),
      result: serializer.fromJson<String>(json['result']),
      studiedAt: serializer.fromJson<DateTime>(json['studiedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'courseId': serializer.toJson<String>(courseId),
      'itemId': serializer.toJson<String>(itemId),
      'exerciseType': serializer.toJson<String>(exerciseType),
      'result': serializer.toJson<String>(result),
      'studiedAt': serializer.toJson<DateTime>(studiedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  StudyEventRow copyWith({
    String? eventId,
    String? courseId,
    String? itemId,
    String? exerciseType,
    String? result,
    DateTime? studiedAt,
    String? deviceId,
    bool? synced,
  }) => StudyEventRow(
    eventId: eventId ?? this.eventId,
    courseId: courseId ?? this.courseId,
    itemId: itemId ?? this.itemId,
    exerciseType: exerciseType ?? this.exerciseType,
    result: result ?? this.result,
    studiedAt: studiedAt ?? this.studiedAt,
    deviceId: deviceId ?? this.deviceId,
    synced: synced ?? this.synced,
  );
  StudyEventRow copyWithCompanion(StudyEventsCompanion data) {
    return StudyEventRow(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      exerciseType: data.exerciseType.present
          ? data.exerciseType.value
          : this.exerciseType,
      result: data.result.present ? data.result.value : this.result,
      studiedAt: data.studiedAt.present ? data.studiedAt.value : this.studiedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudyEventRow(')
          ..write('eventId: $eventId, ')
          ..write('courseId: $courseId, ')
          ..write('itemId: $itemId, ')
          ..write('exerciseType: $exerciseType, ')
          ..write('result: $result, ')
          ..write('studiedAt: $studiedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    eventId,
    courseId,
    itemId,
    exerciseType,
    result,
    studiedAt,
    deviceId,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudyEventRow &&
          other.eventId == this.eventId &&
          other.courseId == this.courseId &&
          other.itemId == this.itemId &&
          other.exerciseType == this.exerciseType &&
          other.result == this.result &&
          other.studiedAt == this.studiedAt &&
          other.deviceId == this.deviceId &&
          other.synced == this.synced);
}

class StudyEventsCompanion extends UpdateCompanion<StudyEventRow> {
  final Value<String> eventId;
  final Value<String> courseId;
  final Value<String> itemId;
  final Value<String> exerciseType;
  final Value<String> result;
  final Value<DateTime> studiedAt;
  final Value<String> deviceId;
  final Value<bool> synced;
  final Value<int> rowid;
  const StudyEventsCompanion({
    this.eventId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.exerciseType = const Value.absent(),
    this.result = const Value.absent(),
    this.studiedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudyEventsCompanion.insert({
    required String eventId,
    required String courseId,
    required String itemId,
    required String exerciseType,
    required String result,
    required DateTime studiedAt,
    required String deviceId,
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       courseId = Value(courseId),
       itemId = Value(itemId),
       exerciseType = Value(exerciseType),
       result = Value(result),
       studiedAt = Value(studiedAt),
       deviceId = Value(deviceId);
  static Insertable<StudyEventRow> custom({
    Expression<String>? eventId,
    Expression<String>? courseId,
    Expression<String>? itemId,
    Expression<String>? exerciseType,
    Expression<String>? result,
    Expression<DateTime>? studiedAt,
    Expression<String>? deviceId,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (courseId != null) 'course_id': courseId,
      if (itemId != null) 'item_id': itemId,
      if (exerciseType != null) 'exercise_type': exerciseType,
      if (result != null) 'result': result,
      if (studiedAt != null) 'studied_at': studiedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudyEventsCompanion copyWith({
    Value<String>? eventId,
    Value<String>? courseId,
    Value<String>? itemId,
    Value<String>? exerciseType,
    Value<String>? result,
    Value<DateTime>? studiedAt,
    Value<String>? deviceId,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return StudyEventsCompanion(
      eventId: eventId ?? this.eventId,
      courseId: courseId ?? this.courseId,
      itemId: itemId ?? this.itemId,
      exerciseType: exerciseType ?? this.exerciseType,
      result: result ?? this.result,
      studiedAt: studiedAt ?? this.studiedAt,
      deviceId: deviceId ?? this.deviceId,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (exerciseType.present) {
      map['exercise_type'] = Variable<String>(exerciseType.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (studiedAt.present) {
      map['studied_at'] = Variable<DateTime>(studiedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudyEventsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('courseId: $courseId, ')
          ..write('itemId: $itemId, ')
          ..write('exerciseType: $exerciseType, ')
          ..write('result: $result, ')
          ..write('studiedAt: $studiedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudySessionsTable extends StudySessions
    with TableInfo<$StudySessionsTable, StudySessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudySessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _courseIdMeta = const VerificationMeta(
    'courseId',
  );
  @override
  late final GeneratedColumn<String> courseId = GeneratedColumn<String>(
    'course_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _correctCountMeta = const VerificationMeta(
    'correctCount',
  );
  @override
  late final GeneratedColumn<int> correctCount = GeneratedColumn<int>(
    'correct_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wrongCountMeta = const VerificationMeta(
    'wrongCount',
  );
  @override
  late final GeneratedColumn<int> wrongCount = GeneratedColumn<int>(
    'wrong_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _earnedXpMeta = const VerificationMeta(
    'earnedXp',
  );
  @override
  late final GeneratedColumn<int> earnedXp = GeneratedColumn<int>(
    'earned_xp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    courseId,
    startedAt,
    endedAt,
    correctCount,
    wrongCount,
    earnedXp,
    metadataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudySessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('course_id')) {
      context.handle(
        _courseIdMeta,
        courseId.isAcceptableOrUnknown(data['course_id']!, _courseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_courseIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('correct_count')) {
      context.handle(
        _correctCountMeta,
        correctCount.isAcceptableOrUnknown(
          data['correct_count']!,
          _correctCountMeta,
        ),
      );
    }
    if (data.containsKey('wrong_count')) {
      context.handle(
        _wrongCountMeta,
        wrongCount.isAcceptableOrUnknown(data['wrong_count']!, _wrongCountMeta),
      );
    }
    if (data.containsKey('earned_xp')) {
      context.handle(
        _earnedXpMeta,
        earnedXp.isAcceptableOrUnknown(data['earned_xp']!, _earnedXpMeta),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId};
  @override
  StudySessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudySessionRow(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      courseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}course_id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      correctCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct_count'],
      )!,
      wrongCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wrong_count'],
      )!,
      earnedXp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}earned_xp'],
      )!,
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
    );
  }

  @override
  $StudySessionsTable createAlias(String alias) {
    return $StudySessionsTable(attachedDatabase, alias);
  }
}

class StudySessionRow extends DataClass implements Insertable<StudySessionRow> {
  final String sessionId;
  final String courseId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int correctCount;
  final int wrongCount;
  final int earnedXp;
  final String metadataJson;
  const StudySessionRow({
    required this.sessionId,
    required this.courseId,
    required this.startedAt,
    this.endedAt,
    required this.correctCount,
    required this.wrongCount,
    required this.earnedXp,
    required this.metadataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['course_id'] = Variable<String>(courseId);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['correct_count'] = Variable<int>(correctCount);
    map['wrong_count'] = Variable<int>(wrongCount);
    map['earned_xp'] = Variable<int>(earnedXp);
    map['metadata_json'] = Variable<String>(metadataJson);
    return map;
  }

  StudySessionsCompanion toCompanion(bool nullToAbsent) {
    return StudySessionsCompanion(
      sessionId: Value(sessionId),
      courseId: Value(courseId),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      correctCount: Value(correctCount),
      wrongCount: Value(wrongCount),
      earnedXp: Value(earnedXp),
      metadataJson: Value(metadataJson),
    );
  }

  factory StudySessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudySessionRow(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      courseId: serializer.fromJson<String>(json['courseId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      correctCount: serializer.fromJson<int>(json['correctCount']),
      wrongCount: serializer.fromJson<int>(json['wrongCount']),
      earnedXp: serializer.fromJson<int>(json['earnedXp']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'courseId': serializer.toJson<String>(courseId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'correctCount': serializer.toJson<int>(correctCount),
      'wrongCount': serializer.toJson<int>(wrongCount),
      'earnedXp': serializer.toJson<int>(earnedXp),
      'metadataJson': serializer.toJson<String>(metadataJson),
    };
  }

  StudySessionRow copyWith({
    String? sessionId,
    String? courseId,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    int? correctCount,
    int? wrongCount,
    int? earnedXp,
    String? metadataJson,
  }) => StudySessionRow(
    sessionId: sessionId ?? this.sessionId,
    courseId: courseId ?? this.courseId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    correctCount: correctCount ?? this.correctCount,
    wrongCount: wrongCount ?? this.wrongCount,
    earnedXp: earnedXp ?? this.earnedXp,
    metadataJson: metadataJson ?? this.metadataJson,
  );
  StudySessionRow copyWithCompanion(StudySessionsCompanion data) {
    return StudySessionRow(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      courseId: data.courseId.present ? data.courseId.value : this.courseId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      correctCount: data.correctCount.present
          ? data.correctCount.value
          : this.correctCount,
      wrongCount: data.wrongCount.present
          ? data.wrongCount.value
          : this.wrongCount,
      earnedXp: data.earnedXp.present ? data.earnedXp.value : this.earnedXp,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudySessionRow(')
          ..write('sessionId: $sessionId, ')
          ..write('courseId: $courseId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('correctCount: $correctCount, ')
          ..write('wrongCount: $wrongCount, ')
          ..write('earnedXp: $earnedXp, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sessionId,
    courseId,
    startedAt,
    endedAt,
    correctCount,
    wrongCount,
    earnedXp,
    metadataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudySessionRow &&
          other.sessionId == this.sessionId &&
          other.courseId == this.courseId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.correctCount == this.correctCount &&
          other.wrongCount == this.wrongCount &&
          other.earnedXp == this.earnedXp &&
          other.metadataJson == this.metadataJson);
}

class StudySessionsCompanion extends UpdateCompanion<StudySessionRow> {
  final Value<String> sessionId;
  final Value<String> courseId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int> correctCount;
  final Value<int> wrongCount;
  final Value<int> earnedXp;
  final Value<String> metadataJson;
  final Value<int> rowid;
  const StudySessionsCompanion({
    this.sessionId = const Value.absent(),
    this.courseId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.wrongCount = const Value.absent(),
    this.earnedXp = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudySessionsCompanion.insert({
    required String sessionId,
    required String courseId,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.correctCount = const Value.absent(),
    this.wrongCount = const Value.absent(),
    this.earnedXp = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       courseId = Value(courseId),
       startedAt = Value(startedAt);
  static Insertable<StudySessionRow> custom({
    Expression<String>? sessionId,
    Expression<String>? courseId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? correctCount,
    Expression<int>? wrongCount,
    Expression<int>? earnedXp,
    Expression<String>? metadataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (courseId != null) 'course_id': courseId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (correctCount != null) 'correct_count': correctCount,
      if (wrongCount != null) 'wrong_count': wrongCount,
      if (earnedXp != null) 'earned_xp': earnedXp,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudySessionsCompanion copyWith({
    Value<String>? sessionId,
    Value<String>? courseId,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int>? correctCount,
    Value<int>? wrongCount,
    Value<int>? earnedXp,
    Value<String>? metadataJson,
    Value<int>? rowid,
  }) {
    return StudySessionsCompanion(
      sessionId: sessionId ?? this.sessionId,
      courseId: courseId ?? this.courseId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      earnedXp: earnedXp ?? this.earnedXp,
      metadataJson: metadataJson ?? this.metadataJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (courseId.present) {
      map['course_id'] = Variable<String>(courseId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (correctCount.present) {
      map['correct_count'] = Variable<int>(correctCount.value);
    }
    if (wrongCount.present) {
      map['wrong_count'] = Variable<int>(wrongCount.value);
    }
    if (earnedXp.present) {
      map['earned_xp'] = Variable<int>(earnedXp.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudySessionsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('courseId: $courseId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('correctCount: $correctCount, ')
          ..write('wrongCount: $wrongCount, ')
          ..write('earnedXp: $earnedXp, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueJsonMeta = const VerificationMeta(
    'valueJson',
  );
  @override
  late final GeneratedColumn<String> valueJson = GeneratedColumn<String>(
    'value_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, valueJson, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value_json')) {
      context.handle(
        _valueJsonMeta,
        valueJson.isAcceptableOrUnknown(data['value_json']!, _valueJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_valueJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      valueJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSettingRow extends DataClass implements Insertable<AppSettingRow> {
  final String key;
  final String valueJson;
  final DateTime updatedAt;
  const AppSettingRow({
    required this.key,
    required this.valueJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value_json'] = Variable<String>(valueJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      valueJson: Value(valueJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingRow(
      key: serializer.fromJson<String>(json['key']),
      valueJson: serializer.fromJson<String>(json['valueJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'valueJson': serializer.toJson<String>(valueJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSettingRow copyWith({
    String? key,
    String? valueJson,
    DateTime? updatedAt,
  }) => AppSettingRow(
    key: key ?? this.key,
    valueJson: valueJson ?? this.valueJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AppSettingRow copyWithCompanion(AppSettingsCompanion data) {
    return AppSettingRow(
      key: data.key.present ? data.key.value : this.key,
      valueJson: data.valueJson.present ? data.valueJson.value : this.valueJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingRow(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, valueJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingRow &&
          other.key == this.key &&
          other.valueJson == this.valueJson &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSettingRow> {
  final Value<String> key;
  final Value<String> valueJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.valueJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String valueJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       valueJson = Value(valueJson),
       updatedAt = Value(updatedAt);
  static Insertable<AppSettingRow> custom({
    Expression<String>? key,
    Expression<String>? valueJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (valueJson != null) 'value_json': valueJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? valueJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      valueJson: valueJson ?? this.valueJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (valueJson.present) {
      map['value_json'] = Variable<String>(valueJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('valueJson: $valueJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fileKeyMeta = const VerificationMeta(
    'fileKey',
  );
  @override
  late final GeneratedColumn<String> fileKey = GeneratedColumn<String>(
    'file_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<String> fileId = GeneratedColumn<String>(
    'file_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<String> revision = GeneratedColumn<String>(
    'revision',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPulledAtMeta = const VerificationMeta(
    'lastPulledAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPulledAt = GeneratedColumn<DateTime>(
    'last_pulled_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPushedAtMeta = const VerificationMeta(
    'lastPushedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastPushedAt = GeneratedColumn<DateTime>(
    'last_pushed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    fileKey,
    fileId,
    revision,
    sha256,
    lastPulledAt,
    lastPushedAt,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('file_key')) {
      context.handle(
        _fileKeyMeta,
        fileKey.isAcceptableOrUnknown(data['file_key']!, _fileKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_fileKeyMeta);
    }
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('last_pulled_at')) {
      context.handle(
        _lastPulledAtMeta,
        lastPulledAt.isAcceptableOrUnknown(
          data['last_pulled_at']!,
          _lastPulledAtMeta,
        ),
      );
    }
    if (data.containsKey('last_pushed_at')) {
      context.handle(
        _lastPushedAtMeta,
        lastPushedAt.isAcceptableOrUnknown(
          data['last_pushed_at']!,
          _lastPushedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fileKey};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      fileKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_key'],
      )!,
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_id'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}revision'],
      ),
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      lastPulledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_pulled_at'],
      ),
      lastPushedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_pushed_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final String fileKey;
  final String? fileId;
  final String? revision;
  final String? sha256;
  final DateTime? lastPulledAt;
  final DateTime? lastPushedAt;
  final String? lastError;
  const SyncStateRow({
    required this.fileKey,
    this.fileId,
    this.revision,
    this.sha256,
    this.lastPulledAt,
    this.lastPushedAt,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['file_key'] = Variable<String>(fileKey);
    if (!nullToAbsent || fileId != null) {
      map['file_id'] = Variable<String>(fileId);
    }
    if (!nullToAbsent || revision != null) {
      map['revision'] = Variable<String>(revision);
    }
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    if (!nullToAbsent || lastPulledAt != null) {
      map['last_pulled_at'] = Variable<DateTime>(lastPulledAt);
    }
    if (!nullToAbsent || lastPushedAt != null) {
      map['last_pushed_at'] = Variable<DateTime>(lastPushedAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      fileKey: Value(fileKey),
      fileId: fileId == null && nullToAbsent
          ? const Value.absent()
          : Value(fileId),
      revision: revision == null && nullToAbsent
          ? const Value.absent()
          : Value(revision),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
      lastPulledAt: lastPulledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPulledAt),
      lastPushedAt: lastPushedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPushedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      fileKey: serializer.fromJson<String>(json['fileKey']),
      fileId: serializer.fromJson<String?>(json['fileId']),
      revision: serializer.fromJson<String?>(json['revision']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      lastPulledAt: serializer.fromJson<DateTime?>(json['lastPulledAt']),
      lastPushedAt: serializer.fromJson<DateTime?>(json['lastPushedAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fileKey': serializer.toJson<String>(fileKey),
      'fileId': serializer.toJson<String?>(fileId),
      'revision': serializer.toJson<String?>(revision),
      'sha256': serializer.toJson<String?>(sha256),
      'lastPulledAt': serializer.toJson<DateTime?>(lastPulledAt),
      'lastPushedAt': serializer.toJson<DateTime?>(lastPushedAt),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncStateRow copyWith({
    String? fileKey,
    Value<String?> fileId = const Value.absent(),
    Value<String?> revision = const Value.absent(),
    Value<String?> sha256 = const Value.absent(),
    Value<DateTime?> lastPulledAt = const Value.absent(),
    Value<DateTime?> lastPushedAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
  }) => SyncStateRow(
    fileKey: fileKey ?? this.fileKey,
    fileId: fileId.present ? fileId.value : this.fileId,
    revision: revision.present ? revision.value : this.revision,
    sha256: sha256.present ? sha256.value : this.sha256,
    lastPulledAt: lastPulledAt.present ? lastPulledAt.value : this.lastPulledAt,
    lastPushedAt: lastPushedAt.present ? lastPushedAt.value : this.lastPushedAt,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  SyncStateRow copyWithCompanion(SyncStatesCompanion data) {
    return SyncStateRow(
      fileKey: data.fileKey.present ? data.fileKey.value : this.fileKey,
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      revision: data.revision.present ? data.revision.value : this.revision,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      lastPulledAt: data.lastPulledAt.present
          ? data.lastPulledAt.value
          : this.lastPulledAt,
      lastPushedAt: data.lastPushedAt.present
          ? data.lastPushedAt.value
          : this.lastPushedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('fileKey: $fileKey, ')
          ..write('fileId: $fileId, ')
          ..write('revision: $revision, ')
          ..write('sha256: $sha256, ')
          ..write('lastPulledAt: $lastPulledAt, ')
          ..write('lastPushedAt: $lastPushedAt, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    fileKey,
    fileId,
    revision,
    sha256,
    lastPulledAt,
    lastPushedAt,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.fileKey == this.fileKey &&
          other.fileId == this.fileId &&
          other.revision == this.revision &&
          other.sha256 == this.sha256 &&
          other.lastPulledAt == this.lastPulledAt &&
          other.lastPushedAt == this.lastPushedAt &&
          other.lastError == this.lastError);
}

class SyncStatesCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> fileKey;
  final Value<String?> fileId;
  final Value<String?> revision;
  final Value<String?> sha256;
  final Value<DateTime?> lastPulledAt;
  final Value<DateTime?> lastPushedAt;
  final Value<String?> lastError;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.fileKey = const Value.absent(),
    this.fileId = const Value.absent(),
    this.revision = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.lastPulledAt = const Value.absent(),
    this.lastPushedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String fileKey,
    this.fileId = const Value.absent(),
    this.revision = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.lastPulledAt = const Value.absent(),
    this.lastPushedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : fileKey = Value(fileKey);
  static Insertable<SyncStateRow> custom({
    Expression<String>? fileKey,
    Expression<String>? fileId,
    Expression<String>? revision,
    Expression<String>? sha256,
    Expression<DateTime>? lastPulledAt,
    Expression<DateTime>? lastPushedAt,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fileKey != null) 'file_key': fileKey,
      if (fileId != null) 'file_id': fileId,
      if (revision != null) 'revision': revision,
      if (sha256 != null) 'sha256': sha256,
      if (lastPulledAt != null) 'last_pulled_at': lastPulledAt,
      if (lastPushedAt != null) 'last_pushed_at': lastPushedAt,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith({
    Value<String>? fileKey,
    Value<String?>? fileId,
    Value<String?>? revision,
    Value<String?>? sha256,
    Value<DateTime?>? lastPulledAt,
    Value<DateTime?>? lastPushedAt,
    Value<String?>? lastError,
    Value<int>? rowid,
  }) {
    return SyncStatesCompanion(
      fileKey: fileKey ?? this.fileKey,
      fileId: fileId ?? this.fileId,
      revision: revision ?? this.revision,
      sha256: sha256 ?? this.sha256,
      lastPulledAt: lastPulledAt ?? this.lastPulledAt,
      lastPushedAt: lastPushedAt ?? this.lastPushedAt,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fileKey.present) {
      map['file_key'] = Variable<String>(fileKey.value);
    }
    if (fileId.present) {
      map['file_id'] = Variable<String>(fileId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<String>(revision.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (lastPulledAt.present) {
      map['last_pulled_at'] = Variable<DateTime>(lastPulledAt.value);
    }
    if (lastPushedAt.present) {
      map['last_pushed_at'] = Variable<DateTime>(lastPushedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('fileKey: $fileKey, ')
          ..write('fileId: $fileId, ')
          ..write('revision: $revision, ')
          ..write('sha256: $sha256, ')
          ..write('lastPulledAt: $lastPulledAt, ')
          ..write('lastPushedAt: $lastPushedAt, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingSyncsTable extends PendingSyncs
    with TableInfo<$PendingSyncsTable, PendingSyncRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingSyncsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _operationIdMeta = const VerificationMeta(
    'operationId',
  );
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
    'operation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    operationId,
    entityType,
    entityId,
    payloadJson,
    attempts,
    nextAttemptAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_syncs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingSyncRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('operation_id')) {
      context.handle(
        _operationIdMeta,
        operationId.isAcceptableOrUnknown(
          data['operation_id']!,
          _operationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {operationId};
  @override
  PendingSyncRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingSyncRow(
      operationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingSyncsTable createAlias(String alias) {
    return $PendingSyncsTable(attachedDatabase, alias);
  }
}

class PendingSyncRow extends DataClass implements Insertable<PendingSyncRow> {
  final String operationId;
  final String entityType;
  final String entityId;
  final String payloadJson;
  final int attempts;
  final DateTime nextAttemptAt;
  final DateTime createdAt;
  const PendingSyncRow({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.payloadJson,
    required this.attempts,
    required this.nextAttemptAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['operation_id'] = Variable<String>(operationId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['attempts'] = Variable<int>(attempts);
    map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingSyncsCompanion toCompanion(bool nullToAbsent) {
    return PendingSyncsCompanion(
      operationId: Value(operationId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      payloadJson: Value(payloadJson),
      attempts: Value(attempts),
      nextAttemptAt: Value(nextAttemptAt),
      createdAt: Value(createdAt),
    );
  }

  factory PendingSyncRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingSyncRow(
      operationId: serializer.fromJson<String>(json['operationId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<DateTime>(json['nextAttemptAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'operationId': serializer.toJson<String>(operationId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<DateTime>(nextAttemptAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingSyncRow copyWith({
    String? operationId,
    String? entityType,
    String? entityId,
    String? payloadJson,
    int? attempts,
    DateTime? nextAttemptAt,
    DateTime? createdAt,
  }) => PendingSyncRow(
    operationId: operationId ?? this.operationId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    payloadJson: payloadJson ?? this.payloadJson,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingSyncRow copyWithCompanion(PendingSyncsCompanion data) {
    return PendingSyncRow(
      operationId: data.operationId.present
          ? data.operationId.value
          : this.operationId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingSyncRow(')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    operationId,
    entityType,
    entityId,
    payloadJson,
    attempts,
    nextAttemptAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingSyncRow &&
          other.operationId == this.operationId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.payloadJson == this.payloadJson &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.createdAt == this.createdAt);
}

class PendingSyncsCompanion extends UpdateCompanion<PendingSyncRow> {
  final Value<String> operationId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> payloadJson;
  final Value<int> attempts;
  final Value<DateTime> nextAttemptAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PendingSyncsCompanion({
    this.operationId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingSyncsCompanion.insert({
    required String operationId,
    required String entityType,
    required String entityId,
    required String payloadJson,
    this.attempts = const Value.absent(),
    required DateTime nextAttemptAt,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : operationId = Value(operationId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       payloadJson = Value(payloadJson),
       nextAttemptAt = Value(nextAttemptAt),
       createdAt = Value(createdAt);
  static Insertable<PendingSyncRow> custom({
    Expression<String>? operationId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? payloadJson,
    Expression<int>? attempts,
    Expression<DateTime>? nextAttemptAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (operationId != null) 'operation_id': operationId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingSyncsCompanion copyWith({
    Value<String>? operationId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? payloadJson,
    Value<int>? attempts,
    Value<DateTime>? nextAttemptAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return PendingSyncsCompanion(
      operationId: operationId ?? this.operationId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      payloadJson: payloadJson ?? this.payloadJson,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingSyncsCompanion(')
          ..write('operationId: $operationId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportedFilesTable extends ImportedFiles
    with TableInfo<$ImportedFilesTable, ImportedFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportedFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _importIdMeta = const VerificationMeta(
    'importId',
  );
  @override
  late final GeneratedColumn<String> importId = GeneratedColumn<String>(
    'import_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedRowsMeta = const VerificationMeta(
    'importedRows',
  );
  @override
  late final GeneratedColumn<int> importedRows = GeneratedColumn<int>(
    'imported_rows',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rejectedRowsMeta = const VerificationMeta(
    'rejectedRows',
  );
  @override
  late final GeneratedColumn<int> rejectedRows = GeneratedColumn<int>(
    'rejected_rows',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    importId,
    fileName,
    sha256,
    importedRows,
    rejectedRows,
    importedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'imported_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportedFileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('import_id')) {
      context.handle(
        _importIdMeta,
        importId.isAcceptableOrUnknown(data['import_id']!, _importIdMeta),
      );
    } else if (isInserting) {
      context.missing(_importIdMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('imported_rows')) {
      context.handle(
        _importedRowsMeta,
        importedRows.isAcceptableOrUnknown(
          data['imported_rows']!,
          _importedRowsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_importedRowsMeta);
    }
    if (data.containsKey('rejected_rows')) {
      context.handle(
        _rejectedRowsMeta,
        rejectedRows.isAcceptableOrUnknown(
          data['rejected_rows']!,
          _rejectedRowsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rejectedRowsMeta);
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {importId};
  @override
  ImportedFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportedFileRow(
      importId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}import_id'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      importedRows: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}imported_rows'],
      )!,
      rejectedRows: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rejected_rows'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
    );
  }

  @override
  $ImportedFilesTable createAlias(String alias) {
    return $ImportedFilesTable(attachedDatabase, alias);
  }
}

class ImportedFileRow extends DataClass implements Insertable<ImportedFileRow> {
  final String importId;
  final String fileName;
  final String sha256;
  final int importedRows;
  final int rejectedRows;
  final DateTime importedAt;
  const ImportedFileRow({
    required this.importId,
    required this.fileName,
    required this.sha256,
    required this.importedRows,
    required this.rejectedRows,
    required this.importedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['import_id'] = Variable<String>(importId);
    map['file_name'] = Variable<String>(fileName);
    map['sha256'] = Variable<String>(sha256);
    map['imported_rows'] = Variable<int>(importedRows);
    map['rejected_rows'] = Variable<int>(rejectedRows);
    map['imported_at'] = Variable<DateTime>(importedAt);
    return map;
  }

  ImportedFilesCompanion toCompanion(bool nullToAbsent) {
    return ImportedFilesCompanion(
      importId: Value(importId),
      fileName: Value(fileName),
      sha256: Value(sha256),
      importedRows: Value(importedRows),
      rejectedRows: Value(rejectedRows),
      importedAt: Value(importedAt),
    );
  }

  factory ImportedFileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportedFileRow(
      importId: serializer.fromJson<String>(json['importId']),
      fileName: serializer.fromJson<String>(json['fileName']),
      sha256: serializer.fromJson<String>(json['sha256']),
      importedRows: serializer.fromJson<int>(json['importedRows']),
      rejectedRows: serializer.fromJson<int>(json['rejectedRows']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'importId': serializer.toJson<String>(importId),
      'fileName': serializer.toJson<String>(fileName),
      'sha256': serializer.toJson<String>(sha256),
      'importedRows': serializer.toJson<int>(importedRows),
      'rejectedRows': serializer.toJson<int>(rejectedRows),
      'importedAt': serializer.toJson<DateTime>(importedAt),
    };
  }

  ImportedFileRow copyWith({
    String? importId,
    String? fileName,
    String? sha256,
    int? importedRows,
    int? rejectedRows,
    DateTime? importedAt,
  }) => ImportedFileRow(
    importId: importId ?? this.importId,
    fileName: fileName ?? this.fileName,
    sha256: sha256 ?? this.sha256,
    importedRows: importedRows ?? this.importedRows,
    rejectedRows: rejectedRows ?? this.rejectedRows,
    importedAt: importedAt ?? this.importedAt,
  );
  ImportedFileRow copyWithCompanion(ImportedFilesCompanion data) {
    return ImportedFileRow(
      importId: data.importId.present ? data.importId.value : this.importId,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      importedRows: data.importedRows.present
          ? data.importedRows.value
          : this.importedRows,
      rejectedRows: data.rejectedRows.present
          ? data.rejectedRows.value
          : this.rejectedRows,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportedFileRow(')
          ..write('importId: $importId, ')
          ..write('fileName: $fileName, ')
          ..write('sha256: $sha256, ')
          ..write('importedRows: $importedRows, ')
          ..write('rejectedRows: $rejectedRows, ')
          ..write('importedAt: $importedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    importId,
    fileName,
    sha256,
    importedRows,
    rejectedRows,
    importedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportedFileRow &&
          other.importId == this.importId &&
          other.fileName == this.fileName &&
          other.sha256 == this.sha256 &&
          other.importedRows == this.importedRows &&
          other.rejectedRows == this.rejectedRows &&
          other.importedAt == this.importedAt);
}

class ImportedFilesCompanion extends UpdateCompanion<ImportedFileRow> {
  final Value<String> importId;
  final Value<String> fileName;
  final Value<String> sha256;
  final Value<int> importedRows;
  final Value<int> rejectedRows;
  final Value<DateTime> importedAt;
  final Value<int> rowid;
  const ImportedFilesCompanion({
    this.importId = const Value.absent(),
    this.fileName = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.importedRows = const Value.absent(),
    this.rejectedRows = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportedFilesCompanion.insert({
    required String importId,
    required String fileName,
    required String sha256,
    required int importedRows,
    required int rejectedRows,
    required DateTime importedAt,
    this.rowid = const Value.absent(),
  }) : importId = Value(importId),
       fileName = Value(fileName),
       sha256 = Value(sha256),
       importedRows = Value(importedRows),
       rejectedRows = Value(rejectedRows),
       importedAt = Value(importedAt);
  static Insertable<ImportedFileRow> custom({
    Expression<String>? importId,
    Expression<String>? fileName,
    Expression<String>? sha256,
    Expression<int>? importedRows,
    Expression<int>? rejectedRows,
    Expression<DateTime>? importedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (importId != null) 'import_id': importId,
      if (fileName != null) 'file_name': fileName,
      if (sha256 != null) 'sha256': sha256,
      if (importedRows != null) 'imported_rows': importedRows,
      if (rejectedRows != null) 'rejected_rows': rejectedRows,
      if (importedAt != null) 'imported_at': importedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportedFilesCompanion copyWith({
    Value<String>? importId,
    Value<String>? fileName,
    Value<String>? sha256,
    Value<int>? importedRows,
    Value<int>? rejectedRows,
    Value<DateTime>? importedAt,
    Value<int>? rowid,
  }) {
    return ImportedFilesCompanion(
      importId: importId ?? this.importId,
      fileName: fileName ?? this.fileName,
      sha256: sha256 ?? this.sha256,
      importedRows: importedRows ?? this.importedRows,
      rejectedRows: rejectedRows ?? this.rejectedRows,
      importedAt: importedAt ?? this.importedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (importId.present) {
      map['import_id'] = Variable<String>(importId.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (importedRows.present) {
      map['imported_rows'] = Variable<int>(importedRows.value);
    }
    if (rejectedRows.present) {
      map['rejected_rows'] = Variable<int>(rejectedRows.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportedFilesCompanion(')
          ..write('importId: $importId, ')
          ..write('fileName: $fileName, ')
          ..write('sha256: $sha256, ')
          ..write('importedRows: $importedRows, ')
          ..write('rejectedRows: $rejectedRows, ')
          ..write('importedAt: $importedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ContentItemsTable contentItems = $ContentItemsTable(this);
  late final $ProgressRowsTable progressRows = $ProgressRowsTable(this);
  late final $StudyEventsTable studyEvents = $StudyEventsTable(this);
  late final $StudySessionsTable studySessions = $StudySessionsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final $PendingSyncsTable pendingSyncs = $PendingSyncsTable(this);
  late final $ImportedFilesTable importedFiles = $ImportedFilesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    contentItems,
    progressRows,
    studyEvents,
    studySessions,
    appSettings,
    syncStates,
    pendingSyncs,
    importedFiles,
  ];
}

typedef $$ContentItemsTableCreateCompanionBuilder =
    ContentItemsCompanion Function({
      required String id,
      required String kind,
      Value<String> baseLanguageTag,
      required String learningLanguageTag,
      required String textValue,
      required String translationsJson,
      required String acceptedAnswersJson,
      Value<String> readingsJson,
      Value<String> sentenceTokensJson,
      Value<String> tagsJson,
      Value<String> level,
      Value<bool> enabled,
      Value<bool> selectedForStudy,
      Value<bool> suspended,
      Value<int> priority,
      required String sourceJson,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$ContentItemsTableUpdateCompanionBuilder =
    ContentItemsCompanion Function({
      Value<String> id,
      Value<String> kind,
      Value<String> baseLanguageTag,
      Value<String> learningLanguageTag,
      Value<String> textValue,
      Value<String> translationsJson,
      Value<String> acceptedAnswersJson,
      Value<String> readingsJson,
      Value<String> sentenceTokensJson,
      Value<String> tagsJson,
      Value<String> level,
      Value<bool> enabled,
      Value<bool> selectedForStudy,
      Value<bool> suspended,
      Value<int> priority,
      Value<String> sourceJson,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$ContentItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ContentItemsTable> {
  $$ContentItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseLanguageTag => $composableBuilder(
    column: $table.baseLanguageTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get learningLanguageTag => $composableBuilder(
    column: $table.learningLanguageTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textValue => $composableBuilder(
    column: $table.textValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get translationsJson => $composableBuilder(
    column: $table.translationsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get acceptedAnswersJson => $composableBuilder(
    column: $table.acceptedAnswersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readingsJson => $composableBuilder(
    column: $table.readingsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentenceTokensJson => $composableBuilder(
    column: $table.sentenceTokensJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get selectedForStudy => $composableBuilder(
    column: $table.selectedForStudy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get suspended => $composableBuilder(
    column: $table.suspended,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContentItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentItemsTable> {
  $$ContentItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseLanguageTag => $composableBuilder(
    column: $table.baseLanguageTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get learningLanguageTag => $composableBuilder(
    column: $table.learningLanguageTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textValue => $composableBuilder(
    column: $table.textValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get translationsJson => $composableBuilder(
    column: $table.translationsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get acceptedAnswersJson => $composableBuilder(
    column: $table.acceptedAnswersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readingsJson => $composableBuilder(
    column: $table.readingsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentenceTokensJson => $composableBuilder(
    column: $table.sentenceTokensJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagsJson => $composableBuilder(
    column: $table.tagsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get selectedForStudy => $composableBuilder(
    column: $table.selectedForStudy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get suspended => $composableBuilder(
    column: $table.suspended,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContentItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentItemsTable> {
  $$ContentItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get baseLanguageTag => $composableBuilder(
    column: $table.baseLanguageTag,
    builder: (column) => column,
  );

  GeneratedColumn<String> get learningLanguageTag => $composableBuilder(
    column: $table.learningLanguageTag,
    builder: (column) => column,
  );

  GeneratedColumn<String> get textValue =>
      $composableBuilder(column: $table.textValue, builder: (column) => column);

  GeneratedColumn<String> get translationsJson => $composableBuilder(
    column: $table.translationsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get acceptedAnswersJson => $composableBuilder(
    column: $table.acceptedAnswersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get readingsJson => $composableBuilder(
    column: $table.readingsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sentenceTokensJson => $composableBuilder(
    column: $table.sentenceTokensJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tagsJson =>
      $composableBuilder(column: $table.tagsJson, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<bool> get selectedForStudy => $composableBuilder(
    column: $table.selectedForStudy,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get suspended =>
      $composableBuilder(column: $table.suspended, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get sourceJson => $composableBuilder(
    column: $table.sourceJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ContentItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContentItemsTable,
          ContentItemRow,
          $$ContentItemsTableFilterComposer,
          $$ContentItemsTableOrderingComposer,
          $$ContentItemsTableAnnotationComposer,
          $$ContentItemsTableCreateCompanionBuilder,
          $$ContentItemsTableUpdateCompanionBuilder,
          (
            ContentItemRow,
            BaseReferences<_$AppDatabase, $ContentItemsTable, ContentItemRow>,
          ),
          ContentItemRow,
          PrefetchHooks Function()
        > {
  $$ContentItemsTableTableManager(_$AppDatabase db, $ContentItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> baseLanguageTag = const Value.absent(),
                Value<String> learningLanguageTag = const Value.absent(),
                Value<String> textValue = const Value.absent(),
                Value<String> translationsJson = const Value.absent(),
                Value<String> acceptedAnswersJson = const Value.absent(),
                Value<String> readingsJson = const Value.absent(),
                Value<String> sentenceTokensJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> selectedForStudy = const Value.absent(),
                Value<bool> suspended = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<String> sourceJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentItemsCompanion(
                id: id,
                kind: kind,
                baseLanguageTag: baseLanguageTag,
                learningLanguageTag: learningLanguageTag,
                textValue: textValue,
                translationsJson: translationsJson,
                acceptedAnswersJson: acceptedAnswersJson,
                readingsJson: readingsJson,
                sentenceTokensJson: sentenceTokensJson,
                tagsJson: tagsJson,
                level: level,
                enabled: enabled,
                selectedForStudy: selectedForStudy,
                suspended: suspended,
                priority: priority,
                sourceJson: sourceJson,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                Value<String> baseLanguageTag = const Value.absent(),
                required String learningLanguageTag,
                required String textValue,
                required String translationsJson,
                required String acceptedAnswersJson,
                Value<String> readingsJson = const Value.absent(),
                Value<String> sentenceTokensJson = const Value.absent(),
                Value<String> tagsJson = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<bool> selectedForStudy = const Value.absent(),
                Value<bool> suspended = const Value.absent(),
                Value<int> priority = const Value.absent(),
                required String sourceJson,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContentItemsCompanion.insert(
                id: id,
                kind: kind,
                baseLanguageTag: baseLanguageTag,
                learningLanguageTag: learningLanguageTag,
                textValue: textValue,
                translationsJson: translationsJson,
                acceptedAnswersJson: acceptedAnswersJson,
                readingsJson: readingsJson,
                sentenceTokensJson: sentenceTokensJson,
                tagsJson: tagsJson,
                level: level,
                enabled: enabled,
                selectedForStudy: selectedForStudy,
                suspended: suspended,
                priority: priority,
                sourceJson: sourceJson,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContentItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContentItemsTable,
      ContentItemRow,
      $$ContentItemsTableFilterComposer,
      $$ContentItemsTableOrderingComposer,
      $$ContentItemsTableAnnotationComposer,
      $$ContentItemsTableCreateCompanionBuilder,
      $$ContentItemsTableUpdateCompanionBuilder,
      (
        ContentItemRow,
        BaseReferences<_$AppDatabase, $ContentItemsTable, ContentItemRow>,
      ),
      ContentItemRow,
      PrefetchHooks Function()
    >;
typedef $$ProgressRowsTableCreateCompanionBuilder =
    ProgressRowsCompanion Function({
      required String courseId,
      required String itemId,
      required String status,
      Value<int> correctCount,
      Value<int> wrongCount,
      Value<int> lapseCount,
      Value<int> currentIntervalDays,
      Value<DateTime?> nextReviewAt,
      Value<DateTime?> lastStudiedAt,
      Value<String?> lastResult,
      required String deviceId,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProgressRowsTableUpdateCompanionBuilder =
    ProgressRowsCompanion Function({
      Value<String> courseId,
      Value<String> itemId,
      Value<String> status,
      Value<int> correctCount,
      Value<int> wrongCount,
      Value<int> lapseCount,
      Value<int> currentIntervalDays,
      Value<DateTime?> nextReviewAt,
      Value<DateTime?> lastStudiedAt,
      Value<String?> lastResult,
      Value<String> deviceId,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ProgressRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ProgressRowsTable> {
  $$ProgressRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lapseCount => $composableBuilder(
    column: $table.lapseCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentIntervalDays => $composableBuilder(
    column: $table.currentIntervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastStudiedAt => $composableBuilder(
    column: $table.lastStudiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastResult => $composableBuilder(
    column: $table.lastResult,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProgressRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ProgressRowsTable> {
  $$ProgressRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lapseCount => $composableBuilder(
    column: $table.lapseCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentIntervalDays => $composableBuilder(
    column: $table.currentIntervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastStudiedAt => $composableBuilder(
    column: $table.lastStudiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastResult => $composableBuilder(
    column: $table.lastResult,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProgressRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProgressRowsTable> {
  $$ProgressRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lapseCount => $composableBuilder(
    column: $table.lapseCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentIntervalDays => $composableBuilder(
    column: $table.currentIntervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextReviewAt => $composableBuilder(
    column: $table.nextReviewAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastStudiedAt => $composableBuilder(
    column: $table.lastStudiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastResult => $composableBuilder(
    column: $table.lastResult,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProgressRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProgressRowsTable,
          ProgressRow,
          $$ProgressRowsTableFilterComposer,
          $$ProgressRowsTableOrderingComposer,
          $$ProgressRowsTableAnnotationComposer,
          $$ProgressRowsTableCreateCompanionBuilder,
          $$ProgressRowsTableUpdateCompanionBuilder,
          (
            ProgressRow,
            BaseReferences<_$AppDatabase, $ProgressRowsTable, ProgressRow>,
          ),
          ProgressRow,
          PrefetchHooks Function()
        > {
  $$ProgressRowsTableTableManager(_$AppDatabase db, $ProgressRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProgressRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProgressRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProgressRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> courseId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> correctCount = const Value.absent(),
                Value<int> wrongCount = const Value.absent(),
                Value<int> lapseCount = const Value.absent(),
                Value<int> currentIntervalDays = const Value.absent(),
                Value<DateTime?> nextReviewAt = const Value.absent(),
                Value<DateTime?> lastStudiedAt = const Value.absent(),
                Value<String?> lastResult = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProgressRowsCompanion(
                courseId: courseId,
                itemId: itemId,
                status: status,
                correctCount: correctCount,
                wrongCount: wrongCount,
                lapseCount: lapseCount,
                currentIntervalDays: currentIntervalDays,
                nextReviewAt: nextReviewAt,
                lastStudiedAt: lastStudiedAt,
                lastResult: lastResult,
                deviceId: deviceId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String courseId,
                required String itemId,
                required String status,
                Value<int> correctCount = const Value.absent(),
                Value<int> wrongCount = const Value.absent(),
                Value<int> lapseCount = const Value.absent(),
                Value<int> currentIntervalDays = const Value.absent(),
                Value<DateTime?> nextReviewAt = const Value.absent(),
                Value<DateTime?> lastStudiedAt = const Value.absent(),
                Value<String?> lastResult = const Value.absent(),
                required String deviceId,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProgressRowsCompanion.insert(
                courseId: courseId,
                itemId: itemId,
                status: status,
                correctCount: correctCount,
                wrongCount: wrongCount,
                lapseCount: lapseCount,
                currentIntervalDays: currentIntervalDays,
                nextReviewAt: nextReviewAt,
                lastStudiedAt: lastStudiedAt,
                lastResult: lastResult,
                deviceId: deviceId,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProgressRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProgressRowsTable,
      ProgressRow,
      $$ProgressRowsTableFilterComposer,
      $$ProgressRowsTableOrderingComposer,
      $$ProgressRowsTableAnnotationComposer,
      $$ProgressRowsTableCreateCompanionBuilder,
      $$ProgressRowsTableUpdateCompanionBuilder,
      (
        ProgressRow,
        BaseReferences<_$AppDatabase, $ProgressRowsTable, ProgressRow>,
      ),
      ProgressRow,
      PrefetchHooks Function()
    >;
typedef $$StudyEventsTableCreateCompanionBuilder =
    StudyEventsCompanion Function({
      required String eventId,
      required String courseId,
      required String itemId,
      required String exerciseType,
      required String result,
      required DateTime studiedAt,
      required String deviceId,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$StudyEventsTableUpdateCompanionBuilder =
    StudyEventsCompanion Function({
      Value<String> eventId,
      Value<String> courseId,
      Value<String> itemId,
      Value<String> exerciseType,
      Value<String> result,
      Value<DateTime> studiedAt,
      Value<String> deviceId,
      Value<bool> synced,
      Value<int> rowid,
    });

class $$StudyEventsTableFilterComposer
    extends Composer<_$AppDatabase, $StudyEventsTable> {
  $$StudyEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseType => $composableBuilder(
    column: $table.exerciseType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get studiedAt => $composableBuilder(
    column: $table.studiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StudyEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $StudyEventsTable> {
  $$StudyEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseType => $composableBuilder(
    column: $table.exerciseType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get studiedAt => $composableBuilder(
    column: $table.studiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudyEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudyEventsTable> {
  $$StudyEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get exerciseType => $composableBuilder(
    column: $table.exerciseType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<DateTime> get studiedAt =>
      $composableBuilder(column: $table.studiedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$StudyEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudyEventsTable,
          StudyEventRow,
          $$StudyEventsTableFilterComposer,
          $$StudyEventsTableOrderingComposer,
          $$StudyEventsTableAnnotationComposer,
          $$StudyEventsTableCreateCompanionBuilder,
          $$StudyEventsTableUpdateCompanionBuilder,
          (
            StudyEventRow,
            BaseReferences<_$AppDatabase, $StudyEventsTable, StudyEventRow>,
          ),
          StudyEventRow,
          PrefetchHooks Function()
        > {
  $$StudyEventsTableTableManager(_$AppDatabase db, $StudyEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudyEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudyEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudyEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> exerciseType = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<DateTime> studiedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudyEventsCompanion(
                eventId: eventId,
                courseId: courseId,
                itemId: itemId,
                exerciseType: exerciseType,
                result: result,
                studiedAt: studiedAt,
                deviceId: deviceId,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                required String courseId,
                required String itemId,
                required String exerciseType,
                required String result,
                required DateTime studiedAt,
                required String deviceId,
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudyEventsCompanion.insert(
                eventId: eventId,
                courseId: courseId,
                itemId: itemId,
                exerciseType: exerciseType,
                result: result,
                studiedAt: studiedAt,
                deviceId: deviceId,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudyEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudyEventsTable,
      StudyEventRow,
      $$StudyEventsTableFilterComposer,
      $$StudyEventsTableOrderingComposer,
      $$StudyEventsTableAnnotationComposer,
      $$StudyEventsTableCreateCompanionBuilder,
      $$StudyEventsTableUpdateCompanionBuilder,
      (
        StudyEventRow,
        BaseReferences<_$AppDatabase, $StudyEventsTable, StudyEventRow>,
      ),
      StudyEventRow,
      PrefetchHooks Function()
    >;
typedef $$StudySessionsTableCreateCompanionBuilder =
    StudySessionsCompanion Function({
      required String sessionId,
      required String courseId,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<int> correctCount,
      Value<int> wrongCount,
      Value<int> earnedXp,
      Value<String> metadataJson,
      Value<int> rowid,
    });
typedef $$StudySessionsTableUpdateCompanionBuilder =
    StudySessionsCompanion Function({
      Value<String> sessionId,
      Value<String> courseId,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int> correctCount,
      Value<int> wrongCount,
      Value<int> earnedXp,
      Value<String> metadataJson,
      Value<int> rowid,
    });

class $$StudySessionsTableFilterComposer
    extends Composer<_$AppDatabase, $StudySessionsTable> {
  $$StudySessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get earnedXp => $composableBuilder(
    column: $table.earnedXp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StudySessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $StudySessionsTable> {
  $$StudySessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get courseId => $composableBuilder(
    column: $table.courseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get earnedXp => $composableBuilder(
    column: $table.earnedXp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudySessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudySessionsTable> {
  $$StudySessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get courseId =>
      $composableBuilder(column: $table.courseId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get correctCount => $composableBuilder(
    column: $table.correctCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wrongCount => $composableBuilder(
    column: $table.wrongCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get earnedXp =>
      $composableBuilder(column: $table.earnedXp, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );
}

class $$StudySessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudySessionsTable,
          StudySessionRow,
          $$StudySessionsTableFilterComposer,
          $$StudySessionsTableOrderingComposer,
          $$StudySessionsTableAnnotationComposer,
          $$StudySessionsTableCreateCompanionBuilder,
          $$StudySessionsTableUpdateCompanionBuilder,
          (
            StudySessionRow,
            BaseReferences<_$AppDatabase, $StudySessionsTable, StudySessionRow>,
          ),
          StudySessionRow,
          PrefetchHooks Function()
        > {
  $$StudySessionsTableTableManager(_$AppDatabase db, $StudySessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudySessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudySessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudySessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<String> courseId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> correctCount = const Value.absent(),
                Value<int> wrongCount = const Value.absent(),
                Value<int> earnedXp = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudySessionsCompanion(
                sessionId: sessionId,
                courseId: courseId,
                startedAt: startedAt,
                endedAt: endedAt,
                correctCount: correctCount,
                wrongCount: wrongCount,
                earnedXp: earnedXp,
                metadataJson: metadataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required String courseId,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> correctCount = const Value.absent(),
                Value<int> wrongCount = const Value.absent(),
                Value<int> earnedXp = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudySessionsCompanion.insert(
                sessionId: sessionId,
                courseId: courseId,
                startedAt: startedAt,
                endedAt: endedAt,
                correctCount: correctCount,
                wrongCount: wrongCount,
                earnedXp: earnedXp,
                metadataJson: metadataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudySessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudySessionsTable,
      StudySessionRow,
      $$StudySessionsTableFilterComposer,
      $$StudySessionsTableOrderingComposer,
      $$StudySessionsTableAnnotationComposer,
      $$StudySessionsTableCreateCompanionBuilder,
      $$StudySessionsTableUpdateCompanionBuilder,
      (
        StudySessionRow,
        BaseReferences<_$AppDatabase, $StudySessionsTable, StudySessionRow>,
      ),
      StudySessionRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String valueJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> valueJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueJson => $composableBuilder(
    column: $table.valueJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get valueJson =>
      $composableBuilder(column: $table.valueJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSettingRow,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSettingRow,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>,
          ),
          AppSettingRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> valueJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String valueJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                valueJson: valueJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSettingRow,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSettingRow,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSettingRow>,
      ),
      AppSettingRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStatesTableCreateCompanionBuilder =
    SyncStatesCompanion Function({
      required String fileKey,
      Value<String?> fileId,
      Value<String?> revision,
      Value<String?> sha256,
      Value<DateTime?> lastPulledAt,
      Value<DateTime?> lastPushedAt,
      Value<String?> lastError,
      Value<int> rowid,
    });
typedef $$SyncStatesTableUpdateCompanionBuilder =
    SyncStatesCompanion Function({
      Value<String> fileKey,
      Value<String?> fileId,
      Value<String?> revision,
      Value<String?> sha256,
      Value<DateTime?> lastPulledAt,
      Value<DateTime?> lastPushedAt,
      Value<String?> lastError,
      Value<int> rowid,
    });

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fileKey => $composableBuilder(
    column: $table.fileKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastPushedAt => $composableBuilder(
    column: $table.lastPushedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fileKey => $composableBuilder(
    column: $table.fileKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileId => $composableBuilder(
    column: $table.fileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastPushedAt => $composableBuilder(
    column: $table.lastPushedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fileKey =>
      $composableBuilder(column: $table.fileKey, builder: (column) => column);

  GeneratedColumn<String> get fileId =>
      $composableBuilder(column: $table.fileId, builder: (column) => column);

  GeneratedColumn<String> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPulledAt => $composableBuilder(
    column: $table.lastPulledAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastPushedAt => $composableBuilder(
    column: $table.lastPushedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStatesTable,
          SyncStateRow,
          $$SyncStatesTableFilterComposer,
          $$SyncStatesTableOrderingComposer,
          $$SyncStatesTableAnnotationComposer,
          $$SyncStatesTableCreateCompanionBuilder,
          $$SyncStatesTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDatabase, $SyncStatesTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStatesTableTableManager(_$AppDatabase db, $SyncStatesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fileKey = const Value.absent(),
                Value<String?> fileId = const Value.absent(),
                Value<String?> revision = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<DateTime?> lastPulledAt = const Value.absent(),
                Value<DateTime?> lastPushedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion(
                fileKey: fileKey,
                fileId: fileId,
                revision: revision,
                sha256: sha256,
                lastPulledAt: lastPulledAt,
                lastPushedAt: lastPushedAt,
                lastError: lastError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fileKey,
                Value<String?> fileId = const Value.absent(),
                Value<String?> revision = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<DateTime?> lastPulledAt = const Value.absent(),
                Value<DateTime?> lastPushedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStatesCompanion.insert(
                fileKey: fileKey,
                fileId: fileId,
                revision: revision,
                sha256: sha256,
                lastPulledAt: lastPulledAt,
                lastPushedAt: lastPushedAt,
                lastError: lastError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStatesTable,
      SyncStateRow,
      $$SyncStatesTableFilterComposer,
      $$SyncStatesTableOrderingComposer,
      $$SyncStatesTableAnnotationComposer,
      $$SyncStatesTableCreateCompanionBuilder,
      $$SyncStatesTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$AppDatabase, $SyncStatesTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;
typedef $$PendingSyncsTableCreateCompanionBuilder =
    PendingSyncsCompanion Function({
      required String operationId,
      required String entityType,
      required String entityId,
      required String payloadJson,
      Value<int> attempts,
      required DateTime nextAttemptAt,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$PendingSyncsTableUpdateCompanionBuilder =
    PendingSyncsCompanion Function({
      Value<String> operationId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> payloadJson,
      Value<int> attempts,
      Value<DateTime> nextAttemptAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$PendingSyncsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingSyncsTable> {
  $$PendingSyncsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingSyncsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingSyncsTable> {
  $$PendingSyncsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingSyncsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingSyncsTable> {
  $$PendingSyncsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get operationId => $composableBuilder(
    column: $table.operationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingSyncsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingSyncsTable,
          PendingSyncRow,
          $$PendingSyncsTableFilterComposer,
          $$PendingSyncsTableOrderingComposer,
          $$PendingSyncsTableAnnotationComposer,
          $$PendingSyncsTableCreateCompanionBuilder,
          $$PendingSyncsTableUpdateCompanionBuilder,
          (
            PendingSyncRow,
            BaseReferences<_$AppDatabase, $PendingSyncsTable, PendingSyncRow>,
          ),
          PendingSyncRow,
          PrefetchHooks Function()
        > {
  $$PendingSyncsTableTableManager(_$AppDatabase db, $PendingSyncsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingSyncsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingSyncsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingSyncsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> operationId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> nextAttemptAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingSyncsCompanion(
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                payloadJson: payloadJson,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String operationId,
                required String entityType,
                required String entityId,
                required String payloadJson,
                Value<int> attempts = const Value.absent(),
                required DateTime nextAttemptAt,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PendingSyncsCompanion.insert(
                operationId: operationId,
                entityType: entityType,
                entityId: entityId,
                payloadJson: payloadJson,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingSyncsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingSyncsTable,
      PendingSyncRow,
      $$PendingSyncsTableFilterComposer,
      $$PendingSyncsTableOrderingComposer,
      $$PendingSyncsTableAnnotationComposer,
      $$PendingSyncsTableCreateCompanionBuilder,
      $$PendingSyncsTableUpdateCompanionBuilder,
      (
        PendingSyncRow,
        BaseReferences<_$AppDatabase, $PendingSyncsTable, PendingSyncRow>,
      ),
      PendingSyncRow,
      PrefetchHooks Function()
    >;
typedef $$ImportedFilesTableCreateCompanionBuilder =
    ImportedFilesCompanion Function({
      required String importId,
      required String fileName,
      required String sha256,
      required int importedRows,
      required int rejectedRows,
      required DateTime importedAt,
      Value<int> rowid,
    });
typedef $$ImportedFilesTableUpdateCompanionBuilder =
    ImportedFilesCompanion Function({
      Value<String> importId,
      Value<String> fileName,
      Value<String> sha256,
      Value<int> importedRows,
      Value<int> rejectedRows,
      Value<DateTime> importedAt,
      Value<int> rowid,
    });

class $$ImportedFilesTableFilterComposer
    extends Composer<_$AppDatabase, $ImportedFilesTable> {
  $$ImportedFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get importId => $composableBuilder(
    column: $table.importId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get importedRows => $composableBuilder(
    column: $table.importedRows,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rejectedRows => $composableBuilder(
    column: $table.rejectedRows,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImportedFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportedFilesTable> {
  $$ImportedFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get importId => $composableBuilder(
    column: $table.importId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get importedRows => $composableBuilder(
    column: $table.importedRows,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rejectedRows => $composableBuilder(
    column: $table.rejectedRows,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportedFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportedFilesTable> {
  $$ImportedFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get importId =>
      $composableBuilder(column: $table.importId, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get importedRows => $composableBuilder(
    column: $table.importedRows,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rejectedRows => $composableBuilder(
    column: $table.rejectedRows,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );
}

class $$ImportedFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportedFilesTable,
          ImportedFileRow,
          $$ImportedFilesTableFilterComposer,
          $$ImportedFilesTableOrderingComposer,
          $$ImportedFilesTableAnnotationComposer,
          $$ImportedFilesTableCreateCompanionBuilder,
          $$ImportedFilesTableUpdateCompanionBuilder,
          (
            ImportedFileRow,
            BaseReferences<_$AppDatabase, $ImportedFilesTable, ImportedFileRow>,
          ),
          ImportedFileRow,
          PrefetchHooks Function()
        > {
  $$ImportedFilesTableTableManager(_$AppDatabase db, $ImportedFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportedFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportedFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportedFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> importId = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<int> importedRows = const Value.absent(),
                Value<int> rejectedRows = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportedFilesCompanion(
                importId: importId,
                fileName: fileName,
                sha256: sha256,
                importedRows: importedRows,
                rejectedRows: rejectedRows,
                importedAt: importedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String importId,
                required String fileName,
                required String sha256,
                required int importedRows,
                required int rejectedRows,
                required DateTime importedAt,
                Value<int> rowid = const Value.absent(),
              }) => ImportedFilesCompanion.insert(
                importId: importId,
                fileName: fileName,
                sha256: sha256,
                importedRows: importedRows,
                rejectedRows: rejectedRows,
                importedAt: importedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImportedFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportedFilesTable,
      ImportedFileRow,
      $$ImportedFilesTableFilterComposer,
      $$ImportedFilesTableOrderingComposer,
      $$ImportedFilesTableAnnotationComposer,
      $$ImportedFilesTableCreateCompanionBuilder,
      $$ImportedFilesTableUpdateCompanionBuilder,
      (
        ImportedFileRow,
        BaseReferences<_$AppDatabase, $ImportedFilesTable, ImportedFileRow>,
      ),
      ImportedFileRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ContentItemsTableTableManager get contentItems =>
      $$ContentItemsTableTableManager(_db, _db.contentItems);
  $$ProgressRowsTableTableManager get progressRows =>
      $$ProgressRowsTableTableManager(_db, _db.progressRows);
  $$StudyEventsTableTableManager get studyEvents =>
      $$StudyEventsTableTableManager(_db, _db.studyEvents);
  $$StudySessionsTableTableManager get studySessions =>
      $$StudySessionsTableTableManager(_db, _db.studySessions);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
  $$PendingSyncsTableTableManager get pendingSyncs =>
      $$PendingSyncsTableTableManager(_db, _db.pendingSyncs);
  $$ImportedFilesTableTableManager get importedFiles =>
      $$ImportedFilesTableTableManager(_db, _db.importedFiles);
}
