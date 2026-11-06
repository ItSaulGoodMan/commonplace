import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../../domain/models/note.dart';

part 'app_database.g.dart';

/// Stores a list of strings as a JSON array.
class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const [];
    final decoded = jsonDecode(fromDb);
    return decoded is List ? decoded.whereType<String>().toList() : const [];
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}

class KeyPointListConverter extends TypeConverter<List<KeyPoint>, String> {
  const KeyPointListConverter();

  @override
  List<KeyPoint> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const [];
    final decoded = jsonDecode(fromDb);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, Object?>>()
        .map(KeyPoint.fromJson)
        .toList();
  }

  @override
  String toSql(List<KeyPoint> value) =>
      jsonEncode([for (final k in value) k.toJson()]);
}

class ActionListConverter extends TypeConverter<List<ActionItem>, String> {
  const ActionListConverter();

  @override
  List<ActionItem> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const [];
    final decoded = jsonDecode(fromDb);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, Object?>>()
        .map(ActionItem.fromJson)
        .toList();
  }

  @override
  String toSql(List<ActionItem> value) =>
      jsonEncode([for (final a in value) a.toJson()]);
}

@DataClassName('NoteRow')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get status => textEnum<NoteStatus>()();
  TextColumn get sourceKind => textEnum<SourceKind>()();
  TextColumn get sourceUrl => text().nullable()();

  /// Instagram's numeric id for the post, when the note came from Instagram.
  TextColumn get remoteId => text().nullable()();
  TextColumn get creatorHandle => text().nullable()();
  TextColumn get caption => text().nullable()();
  TextColumn get mediaPaths => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get transcript => text().nullable()();
  TextColumn get onScreenText => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get visualNotes => text().nullable()();
  TextColumn get language => text().nullable()();
  TextColumn get title => text().nullable()();
  TextColumn get summary => text().nullable()();
  TextColumn get keyPoints => text()
      .map(const KeyPointListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get actions => text()
      .map(const ActionListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get topic => text().nullable()();

  /// True once the owner moves the note to a shelf by hand; rewrites keep it.
  BoolColumn get topicChosen => boolean().withDefault(const Constant(false))();
  TextColumn get tags => text()
      .map(const StringListConverter())
      .withDefault(const Constant('[]'))();
  TextColumn get personalNote => text().nullable()();
  BoolColumn get starred => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();
  IntColumn get openCount => integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();
  BoolColumn get highlightsRevealed =>
      boolean().withDefault(const Constant(false))();
}

/// Instagram saves that have already been looked at, so a note the owner
/// deleted doesn't come back on the next check.
@DataClassName('SeenPostRow')
class SeenPosts extends Table {
  TextColumn get pk => text()();
  DateTimeColumn get seenAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {pk};
}

/// Every answer from Gemini with the owner's key: what it used and what it
/// would cost on a paid key. Kept when a note is deleted, so the month's
/// total stays true.
@DataClassName('AiCallRow')
class AiCalls extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get noteId => integer().nullable()();
  DateTimeColumn get at => dateTime()();
  TextColumn get model => text()();
  IntColumn get inputTokens => integer()();
  IntColumn get outputTokens => integer()();

  /// Null when the model's price isn't known to Commonplace.
  IntColumn get costMicroUsd => integer().nullable()();
}

@DriftDatabase(tables: [Notes, SeenPosts, AiCalls])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'commonplace'));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX IF NOT EXISTS notes_status ON notes (status)',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // Version 2: Instagram sign-in.
        await m.addColumn(notes, notes.remoteId);
        await m.createTable(seenPosts);
      }
      if (from < 3) {
        // Version 3: tokens and cost of each AI answer.
        await m.createTable(aiCalls);
      }
    },
  );
}
