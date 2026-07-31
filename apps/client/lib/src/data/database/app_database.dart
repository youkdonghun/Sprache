import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('ContentItemRow')
class ContentItems extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get baseLanguageTag => text().withDefault(const Constant('ko'))();
  TextColumn get learningLanguageTag => text()();
  TextColumn get textValue => text().named('text')();
  TextColumn get translationsJson => text()();
  TextColumn get acceptedAnswersJson => text()();
  TextColumn get readingsJson => text().withDefault(const Constant('[]'))();
  TextColumn get sentenceTokensJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get level => text().withDefault(const Constant('입문'))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get selectedForStudy =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get suspended => boolean().withDefault(const Constant(false))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  TextColumn get sourceJson => text()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ProgressRow')
class ProgressRows extends Table {
  TextColumn get courseId => text()();
  TextColumn get itemId => text()();
  TextColumn get status => text()();
  IntColumn get correctCount => integer().withDefault(const Constant(0))();
  IntColumn get wrongCount => integer().withDefault(const Constant(0))();
  IntColumn get lapseCount => integer().withDefault(const Constant(0))();
  IntColumn get currentIntervalDays =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get nextReviewAt => dateTime().nullable()();
  DateTimeColumn get lastStudiedAt => dateTime().nullable()();
  TextColumn get lastResult => text().nullable()();
  TextColumn get deviceId => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'progress';

  @override
  Set<Column<Object>> get primaryKey => {courseId, itemId};
}

@DataClassName('StudyEventRow')
class StudyEvents extends Table {
  TextColumn get eventId => text()();
  TextColumn get courseId => text()();
  TextColumn get itemId => text()();
  TextColumn get exerciseType => text()();
  TextColumn get result => text()();
  DateTimeColumn get studiedAt => dateTime()();
  TextColumn get deviceId => text()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {eventId};
}

@DataClassName('StudySessionRow')
class StudySessions extends Table {
  TextColumn get sessionId => text()();
  TextColumn get courseId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get correctCount => integer().withDefault(const Constant(0))();
  IntColumn get wrongCount => integer().withDefault(const Constant(0))();
  IntColumn get earnedXp => integer().withDefault(const Constant(0))();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {sessionId};
}

@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get valueJson => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DataClassName('SyncStateRow')
class SyncStates extends Table {
  TextColumn get fileKey => text()();
  TextColumn get fileId => text().nullable()();
  TextColumn get revision => text().nullable()();
  TextColumn get sha256 => text().nullable()();
  DateTimeColumn get lastPulledAt => dateTime().nullable()();
  DateTimeColumn get lastPushedAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {fileKey};
}

@DataClassName('PendingSyncRow')
class PendingSyncs extends Table {
  TextColumn get operationId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get payloadJson => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {operationId};
}

@DataClassName('ImportedFileRow')
class ImportedFiles extends Table {
  TextColumn get importId => text()();
  TextColumn get fileName => text()();
  TextColumn get sha256 => text()();
  IntColumn get importedRows => integer()();
  IntColumn get rejectedRows => integer()();
  DateTimeColumn get importedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {importId};
}

@DriftDatabase(
  tables: [
    ContentItems,
    ProgressRows,
    StudyEvents,
    StudySessions,
    AppSettings,
    SyncStates,
    PendingSyncs,
    ImportedFiles,
  ],
)
final class AppDatabase extends _$AppDatabase {
  static const currentSchemaVersion = 2;

  AppDatabase(super.executor);

  AppDatabase.defaults() : super(driftDatabase(name: 'sprache'));

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(studySessions, studySessions.metadataJson);
      }
      await _createIndexes();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_content_type '
      'ON content_items(kind)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_content_selected '
      'ON content_items(selected_for_study)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_content_enabled '
      'ON content_items(enabled)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_progress_next_review '
      'ON progress(next_review_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_progress_status '
      'ON progress(status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_study_events_synced '
      'ON study_events(synced)',
    );
  }
}
