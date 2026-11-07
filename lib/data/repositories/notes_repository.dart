import 'package:drift/drift.dart';

import '../../domain/models/ai.dart';
import '../../domain/models/note.dart';
import '../../domain/shared_link.dart';
import '../services/database/app_database.dart';

/// Single source of truth for notes. Everything the UI shows comes from the
/// streams here, so screens update by themselves when a note changes.
class NotesRepository {
  NotesRepository(this._db, {DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _now;

  Stream<List<Note>> watchAll() =>
      (_db.select(_db.notes)..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ]))
          .watch()
          .map((rows) => rows.map(_toNote).toList(growable: false));

  Stream<Note?> watch(int id) =>
      (_db.select(_db.notes)..where((t) => t.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : _toNote(row));

  Future<Note?> find(int id) async {
    final row = await (_db.select(
      _db.notes,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toNote(row);
  }

  /// Oldest note waiting for the AI, if any.
  Future<Note?> nextQueued() async {
    final row =
        await (_db.select(_db.notes)
              ..where((t) => t.status.equalsValue(NoteStatus.queued))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toNote(row);
  }

  /// Every note waiting its turn, oldest first.
  Future<List<Note>> queued() async {
    final rows =
        await (_db.select(_db.notes)
              ..where((t) => t.status.equalsValue(NoteStatus.queued))
              ..orderBy([
                (t) => OrderingTerm.asc(t.createdAt),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return rows.map(_toNote).toList(growable: false);
  }

  Future<int> countQueued() async {
    final count = _db.notes.id.count();
    final query = _db.selectOnly(_db.notes)
      ..addColumns([count])
      ..where(_db.notes.status.equalsValue(NoteStatus.queued));
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// The most recent note still waiting for its video, saved after [since].
  Future<Note?> latestNeedingMedia({required DateTime since}) async {
    final row =
        await (_db.select(_db.notes)
              ..where(
                (t) =>
                    t.status.equalsValue(NoteStatus.needsMedia) &
                    t.createdAt.isBiggerOrEqualValue(since),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toNote(row);
  }

  Future<Note?> findBySourceUrl(String url) async {
    final row =
        await (_db.select(_db.notes)
              ..where((t) => t.sourceUrl.equals(url))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toNote(row);
  }

  /// The note for this link, matching an Instagram post by its shortcode
  /// whether it was shared as a reel or a post link.
  Future<Note?> findBySource(SharedLink link) async {
    final code = link.shortcode;
    if (!link.isInstagram || code == null) return findBySourceUrl(link.url);
    return findByShortcode(code);
  }

  Future<Note?> findByShortcode(String code) async {
    final urls = [
      for (final kind in const ['reel', 'p', 'tv'])
        'https://www.instagram.com/$kind/$code/',
    ];
    final row =
        await (_db.select(_db.notes)
              ..where((t) => t.sourceUrl.isIn(urls))
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : _toNote(row);
  }

  Future<int> create({
    required NoteStatus status,
    required SourceKind sourceKind,
    String? sourceUrl,
    String? remoteId,
    String? creatorHandle,
    String? caption,
    List<String> mediaPaths = const [],
  }) {
    final now = _now();
    return _db
        .into(_db.notes)
        .insert(
          NotesCompanion.insert(
            createdAt: now,
            updatedAt: now,
            status: status,
            sourceKind: sourceKind,
            sourceUrl: Value(sourceUrl),
            remoteId: Value(remoteId),
            creatorHandle: Value(creatorHandle),
            caption: Value(caption),
            mediaPaths: Value(mediaPaths),
          ),
        );
  }

  /// Stores what was fetched from Instagram, without changing the status.
  Future<void> saveFetched(
    int id, {
    required List<String> mediaPaths,
    required SourceKind kind,
    required String remoteId,
    String? caption,
    String? creatorHandle,
  }) => _update(
    id,
    NotesCompanion(
      mediaPaths: Value(mediaPaths),
      sourceKind: Value(kind),
      remoteId: Value(remoteId),
      caption: caption == null ? const Value.absent() : Value(caption),
      creatorHandle: creatorHandle == null
          ? const Value.absent()
          : Value(creatorHandle),
      errorMessage: const Value(null),
    ),
  );

  /// Keeps what one AI answer for note [noteId] used and would cost.
  Future<void> recordAiCall(
    int? noteId,
    AiUsage usage, {
    required int? costMicroUsd,
  }) => _db
      .into(_db.aiCalls)
      .insert(
        AiCallsCompanion.insert(
          noteId: Value(noteId),
          at: _now(),
          model: usage.model,
          inputTokens: usage.inputTokens,
          outputTokens: usage.outputTokens,
          costMicroUsd: Value(costMicroUsd),
        ),
      );

  /// Everything the AI used for note [noteId], kept up to date.
  Stream<AiSpend> watchSpendForNote(int noteId) =>
      (_db.select(_db.aiCalls)
            ..where((t) => t.noteId.equals(noteId))
            ..orderBy([(t) => OrderingTerm.desc(t.at)]))
          .watch()
          .map(_sum);

  /// Everything the AI used since [from] (the start of the month, say).
  Stream<AiSpend> watchSpendSince(DateTime from) =>
      (_db.select(_db.aiCalls)
            ..where((t) => t.at.isBiggerOrEqualValue(from))
            ..orderBy([(t) => OrderingTerm.desc(t.at)]))
          .watch()
          .map(_sum);

  static AiSpend _sum(List<AiCallRow> rows) {
    if (rows.isEmpty) return AiSpend.none;
    var input = 0, output = 0, micro = 0, unpriced = 0;
    final models = <String>[];
    final notes = <int>{};
    for (final r in rows) {
      input += r.inputTokens;
      output += r.outputTokens;
      if (r.costMicroUsd case final c?) {
        micro += c;
      } else {
        unpriced++;
      }
      if (!models.contains(r.model)) models.add(r.model);
      if (r.noteId case final id?) notes.add(id);
    }
    return AiSpend(
      calls: rows.length,
      notes: notes.length,
      inputTokens: input,
      outputTokens: output,
      microUsd: micro,
      unpriced: unpriced,
      models: models,
    );
  }

  /// Ids of failed notes whose error is one of [messages].
  Future<List<int>> failedWith(Set<String> messages) async {
    final rows =
        await (_db.selectOnly(_db.notes)
              ..addColumns([_db.notes.id])
              ..where(
                _db.notes.status.equalsValue(NoteStatus.failed) &
                    _db.notes.errorMessage.isIn(messages),
              ))
            .get();
    return [for (final r in rows) r.read(_db.notes.id)!];
  }

  /// After signing in to Instagram: notes that were waiting for a video only
  /// because Commonplace couldn't fetch it go back in the queue.
  Future<int> requeueInstagramWaiting() =>
      (_db.update(_db.notes)..where(
            (t) =>
                t.status.equalsValue(NoteStatus.needsMedia) &
                t.mediaPaths.equals('[]') &
                t.sourceUrl.like('https://www.instagram.com/%'),
          ))
          .write(
            const NotesCompanion(
              status: Value(NoteStatus.queued),
              errorMessage: Value(null),
            ),
          );

  /// Attaches media to a note that was waiting for it and queues it.
  Future<void> attachMedia(int id, List<String> mediaPaths, SourceKind kind) =>
      _update(
        id,
        NotesCompanion(
          mediaPaths: Value(mediaPaths),
          sourceKind: Value(kind),
          status: const Value(NoteStatus.queued),
          errorMessage: const Value(null),
        ),
      );

  Future<void> setStatus(int id, NoteStatus status, {String? error}) => _update(
    id,
    NotesCompanion(status: Value(status), errorMessage: Value(error)),
  );

  /// Puts every note that was interrupted mid-read back in the queue, and
  /// says which they were.
  Future<List<int>> requeueInterrupted() async {
    final rows =
        await (_db.selectOnly(_db.notes)
              ..addColumns([_db.notes.id])
              ..where(_db.notes.status.equalsValue(NoteStatus.processing)))
            .get();
    final ids = [for (final r in rows) r.read(_db.notes.id)!];
    if (ids.isNotEmpty) {
      await (_db.update(_db.notes)..where((t) => t.id.isIn(ids))).write(
        const NotesCompanion(status: Value(NoteStatus.queued)),
      );
    }
    return ids;
  }

  Future<void> saveExtraction(
    int id, {
    required String transcript,
    required List<String> onScreenText,
    required String visualNotes,
    required String language,
    required String? creatorHandle,
  }) => _update(
    id,
    NotesCompanion(
      transcript: Value(transcript),
      onScreenText: Value(onScreenText),
      visualNotes: Value(visualNotes),
      language: Value(language),
      creatorHandle: creatorHandle == null
          ? const Value.absent()
          : Value(creatorHandle),
    ),
  );

  Future<void> saveDistillation(
    int id, {
    required String title,
    required String summary,
    required List<KeyPoint> keyPoints,
    required List<ActionItem> actions,
    required String topic,
    required List<String> tags,
    String? chosenTopic,
  }) => _update(
    id,
    NotesCompanion(
      title: Value(title),
      summary: Value(summary),
      keyPoints: Value(keyPoints),
      actions: Value(actions),
      // A topic the owner picked by hand survives a rewrite.
      topic: Value(chosenTopic ?? topic),
      tags: Value(tags),
      status: const Value(NoteStatus.ready),
      errorMessage: const Value(null),
      highlightsRevealed: const Value(false),
    ),
  );

  Future<void> clearMedia(int id) =>
      _update(id, const NotesCompanion(mediaPaths: Value([])));

  Future<void> setTopic(int id, String topic) => _update(
    id,
    NotesCompanion(topic: Value(topic.trim()), topicChosen: const Value(true)),
  );

  Future<void> setStarred(int id, bool starred) =>
      _update(id, NotesCompanion(starred: Value(starred)));

  Future<void> setActions(int id, List<ActionItem> actions) =>
      _update(id, NotesCompanion(actions: Value(actions)));

  Future<void> setPersonalNote(int id, String text) => _update(
    id,
    NotesCompanion(personalNote: Value(text.trim().isEmpty ? null : text)),
  );

  Future<void> markHighlightsRevealed(int id) =>
      (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
        const NotesCompanion(highlightsRevealed: Value(true)),
      );

  /// Records a visit without bumping `updatedAt`.
  Future<void> markOpened(int id) => _db.customUpdate(
    'UPDATE notes SET last_opened_at = ?, open_count = open_count + 1 WHERE id = ?',
    variables: [Variable.withDateTime(_now()), Variable.withInt(id)],
    updates: {_db.notes},
  );

  Future<void> delete(int id) =>
      (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();

  /// Topic names in use, most used first.
  Future<List<String>> topics() async {
    final rows = await _db
        .customSelect(
          "SELECT topic, COUNT(*) AS n FROM notes WHERE topic IS NOT NULL AND topic != '' GROUP BY topic ORDER BY n DESC, topic ASC",
          readsFrom: {_db.notes},
        )
        .get();
    return [for (final r in rows) r.read<String>('topic')];
  }

  Future<void> _update(int id, NotesCompanion changes) =>
      (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
        changes.copyWith(updatedAt: Value(_now())),
      );

  static Note _toNote(NoteRow r) => Note(
    id: r.id,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    status: r.status,
    sourceKind: r.sourceKind,
    sourceUrl: r.sourceUrl,
    remoteId: r.remoteId,
    creatorHandle: r.creatorHandle,
    caption: r.caption,
    mediaPaths: r.mediaPaths,
    transcript: r.transcript,
    onScreenText: r.onScreenText,
    visualNotes: r.visualNotes,
    language: r.language,
    title: r.title,
    summary: r.summary,
    keyPoints: r.keyPoints,
    actions: r.actions,
    topic: r.topic,
    topicChosen: r.topicChosen,
    tags: r.tags,
    personalNote: r.personalNote,
    starred: r.starred,
    lastOpenedAt: r.lastOpenedAt,
    openCount: r.openCount,
    errorMessage: r.errorMessage,
    highlightsRevealed: r.highlightsRevealed,
  );
}
