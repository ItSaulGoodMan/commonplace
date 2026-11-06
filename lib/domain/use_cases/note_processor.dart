import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/repositories/instagram_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/instagram_api.dart';
import '../../data/services/local_stores.dart';
import '../../data/services/video_shrinker.dart';
import '../models/ai.dart';
import '../gemini_prices.dart';
import '../models/note.dart';
import '../prompts.dart';

/// What the processor is doing with the note in hand.
enum ProcessingStage {
  /// Getting the video or images from Instagram.
  fetching,

  /// Making a smaller copy of the video to send.
  shrinking,

  /// The AI is reading the media and writing the note.
  reading,
}

/// Works through queued notes one at a time: fetch (for Instagram posts),
/// extract, then distill.
///
/// The queue lives in the database, so nothing is lost if the app is closed
/// mid-way; [resume] picks up where it left off.
class NoteProcessor extends ChangeNotifier {
  NoteProcessor({
    required NotesRepository notes,
    required SettingsRepository settings,
    required NoteAi ai,
    required MediaStore media,
    required InstagramRepository instagram,
    VideoShrinker? shrinker,
    DateTime Function()? clock,
    this.retryDelay = const Duration(seconds: 4),
  }) : _shrinker = shrinker,
       _notes = notes,
       _settings = settings,
       _ai = ai,
       _media = media,
       _instagram = instagram,
       _now = clock ?? DateTime.now;

  final NotesRepository _notes;
  final SettingsRepository _settings;
  final NoteAi _ai;
  final MediaStore _media;
  final InstagramRepository _instagram;
  final VideoShrinker? _shrinker;
  final DateTime Function() _now;

  /// Completes when the owner taps Stop on the note in hand.
  Completer<void>? _cancel;
  bool get _stopRequested => _cancel?.isCompleted ?? false;
  double? _shrinkProgress;

  /// After a rate limit, new work waits this long instead of hitting it again.
  static const rateLimitCooldown = Duration(minutes: 2);

  /// Instagram's "slow down" is taken more seriously than Gemini's.
  static const instagramCooldown = Duration(minutes: 10);

  /// A dropped connection (Wi-Fi to mobile data, a tunnel) is tried once
  /// more after this pause before the note is marked as failed.
  final Duration retryDelay;
  DateTime? _pausedUntil;

  int? _activeId;
  ProcessingStage? _stage;
  DateTime? _stageSince;
  ReadUpdate? _update;
  String? _retryReason;

  /// How often each note has been put back in the queue without the owner
  /// asking, since the app started. Stops a note that always fails the
  /// same way from going round forever.
  final _autoRetries = <int, int>{};
  static const maxAutoRetries = 2;

  /// A note is actually being made (not just a look at an empty queue).
  bool get isWorking => _activeId != null;

  /// What is happening to note [id] right now, if it's the one in hand.
  ProcessingStage? stageOf(int id) => _activeId == id ? _stage : null;

  /// Since when that has been happening, to show how long it's taking.
  DateTime? stageSince(int id) => _activeId == id ? _stageSince : null;

  /// How far the read of note [id] has got (sending, preparing, watching).
  ReadUpdate? readUpdateOf(int id) => _activeId == id ? _update : null;

  /// Why this is a second try, if it is one.
  String? retryReasonOf(int id) => _activeId == id ? _retryReason : null;

  /// How far making the video smaller has got, 0 to 1.
  double? shrinkProgressOf(int id) => _activeId == id ? _shrinkProgress : null;

  /// Stops making note [id]: whatever it is doing (making the video
  /// smaller, sending, waiting for Gemini) ends now, and the note waits for
  /// Try again. It isn't retried on its own.
  void stop(int id) {
    final cancel = _cancel;
    if (_activeId != id || cancel == null || cancel.isCompleted) return;
    cancel.complete();
    notifyListeners();
  }

  /// [work], unless Stop is tapped first.
  Future<T> _unlessStopped<T>(Future<T> work) {
    final cancel = _cancel;
    if (cancel == null) return work;
    return Future.any([
      work,
      cancel.future.then<T>((_) => throw const WorkStopped()),
    ]);
  }

  bool _running = false;
  bool get isRunning => _running;

  /// Something was queued while the loop was running; look once more
  /// before stopping, or it would wait for the next kick.
  bool _lookAgain = false;

  /// Why the queue stopped and notes are waiting (no key, signed out, the
  /// day's notes used up), or null.
  AiFailure? _blockedBy;
  AiFailure? get blockedBy => _blockedBy;
  bool get blockedOnKey => _blockedBy == AiFailure.missingKey;

  /// Failures that say nothing about the note itself: the connection dropped
  /// or a service was busy. Such notes are retried without asking.
  static final _transientMessages = {
    AiFailure.network.message,
    AiFailure.overloaded.message,
    InstagramFailure.network.message,
  };

  /// Call at startup: requeues anything interrupted, then starts work.
  Future<void> resume() async {
    await _notes.requeueInterrupted();
    await _requeueTransient();
    unawaited(kick());
  }

  /// Retries notes that failed because the connection dropped. Called when
  /// the app comes back to the front and after Instagram answered.
  Future<void> retryTransient() async {
    if (await _requeueTransient() > 0) unawaited(kick());
  }

  /// A note gets [maxAutoRetries] of these; after that it stays failed, with
  /// its reason showing, until the owner taps Try again.
  Future<int> _requeueTransient() async {
    var count = 0;
    for (final id in await _notes.failedWith(_transientMessages)) {
      final tries = _autoRetries[id] ?? 0;
      if (tries >= maxAutoRetries) continue;
      _autoRetries[id] = tries + 1;
      await _notes.setStatus(id, NoteStatus.queued);
      count++;
    }
    return count;
  }

  /// Starts processing if it isn't already running. Safe to call any time.
  Future<void> kick() async {
    if (_running) {
      _lookAgain = true;
      return;
    }
    final pausedUntil = _pausedUntil;
    if (pausedUntil != null && _now().isBefore(pausedUntil)) return;
    _pausedUntil = null;
    _running = true;
    _blockedBy = null;
    notifyListeners();
    try {
      while (true) {
        _lookAgain = false;
        final next = await _notes.nextQueued();
        if (next == null) {
          if (_lookAgain) continue;
          break;
        }
        final blocked = _ai.blocked;
        if (blocked != null) {
          // Don't download or upload anything until it can be read.
          _blockedBy = blocked;
          break;
        }
        _retryReason = null;
        _cancel = Completer<void>();
        final keepGoing = await _process(next);
        if (!keepGoing) break;
      }
    } finally {
      _running = false;
      _activeId = null;
      _stage = null;
      _update = null;
      _retryReason = null;
      _cancel = null;
      _shrinkProgress = null;
      notifyListeners();
    }
  }

  /// Puts a failed (or finished) note back in the queue and starts work.
  /// An explicit retry from the owner overrides any cooldown.
  Future<void> retry(int id) async {
    _autoRetries.remove(id);
    await _notes.setStatus(id, NoteStatus.queued);
    _pausedUntil = null;
    unawaited(kick());
  }

  /// Writes the note again from the stored transcript, without re-uploading.
  Future<void> rewrite(int id) async {
    final note = await _notes.find(id);
    if (note == null) return;
    await _notes.setStatus(id, NoteStatus.processing);
    try {
      await _distill(note, rewrite: true);
    } on AiException catch (e) {
      // The note itself is still fine; show it again with the reason.
      await _notes.setStatus(id, NoteStatus.ready, error: e.failure.message);
      rethrow;
    }
  }

  void _enter(int id, ProcessingStage stage) {
    _activeId = id;
    _stage = stage;
    _stageSince = _now();
    _update = null;
    _shrinkProgress = null;
    notifyListeners();
  }

  void _onShrink(int id, double fraction) {
    if (_activeId != id || _stage != ProcessingStage.shrinking) return;
    final before = ((_shrinkProgress ?? 0) * 100).floor();
    _shrinkProgress = fraction;
    if ((fraction * 100).floor() != before) notifyListeners();
  }

  /// Smaller copies of the note's videos, or null to send them as they are.
  Future<List<String>?> _smaller(Note note) async {
    final shrinker = _shrinker;
    if (shrinker == null || !_settings.shrinkVideos) return null;
    var changed = false;
    final paths = <String>[];
    for (final path in note.mediaPaths) {
      if (!MediaStore.mimeTypeFor(path).startsWith('video/')) {
        paths.add(path);
        continue;
      }
      _enter(note.id, ProcessingStage.shrinking);
      final small = await _unlessStopped(
        shrinker.shrink(
          path,
          onProgress: (f) => _onShrink(note.id, f),
          cancel: _cancel?.future,
        ),
      );
      changed |= small != null;
      paths.add(small ?? path);
    }
    return changed ? paths : null;
  }

  /// The note waits for Try again; Stop is never retried on its own.
  Future<bool> _stopped(Note note) async {
    await _notes.setStatus(
      note.id,
      NoteStatus.failed,
      error: WorkStopped.message,
    );
    return true;
  }

  /// Progress from the AI. A new step restarts the clock on screen; while
  /// sending, the screen hears about each whole percent, not every chunk.
  void _onUpdate(int id, ReadUpdate update) {
    if (_activeId != id) return;
    final previous = _update;
    if (previous != null && previous.step == update.step) {
      if (update.step != ReadStep.sending || update.total == 0) return;
      final before = previous.sent * 100 ~/ previous.total;
      final now = update.sent * 100 ~/ update.total;
      _update = update;
      if (now != before) notifyListeners();
      return;
    }
    _update = update;
    _stageSince = _now();
    notifyListeners();
  }

  /// Keeps the tokens an answer used and what they cost at Gemini's paid
  /// price, for the note and the month's total.
  void _used(int noteId, AiUsage usage) {
    final price = GeminiPrice.of(usage.model, _now());
    unawaited(
      _notes.recordAiCall(noteId, usage, costMicroUsd: price?.microUsd(usage)),
    );
  }

  /// Keeps what went wrong, with the technical detail, for Settings.
  void _problem(String message, Object? detail) {
    unawaited(_settings.recordProblem(message, detail?.toString()));
  }

  /// Tries [note] again after [retryDelay], once, with what was saved so far.
  /// The first try's problem is kept and shown, so a restart never looks
  /// like nothing happened.
  Future<bool> _again(Note note, int attempt, String why, String detail) async {
    if (_stopRequested) return _stopped(note);
    _retryReason = why;
    _problem(why, '$detail (trying once more)');
    notifyListeners();
    await _unlessStopped(Future<void>.delayed(retryDelay));
    return _process((await _notes.find(note.id)) ?? note, attempt: attempt + 1);
  }

  /// Returns false when the whole queue should pause (no key, rate limit).
  Future<bool> _process(Note note, {int attempt = 1}) async {
    await _notes.setStatus(note.id, NoteStatus.processing);
    try {
      var current = note;
      if (note.needsInstagramFetch) {
        if (!_instagram.isConnected) {
          await _notes.setStatus(
            note.id,
            NoteStatus.needsMedia,
            error: _instagram.needsSignIn
                ? InstagramFailure.signedOut.message
                : null,
          );
          return true;
        }
        _enter(note.id, ProcessingStage.fetching);
        current = await _unlessStopped(_fetch(note));
      }
      if (current.mediaPaths.isNotEmpty) {
        final smaller = await _smaller(current);
        _enter(note.id, ProcessingStage.reading);
        // One request: watch once, get what was read and the note.
        try {
          current = await _unlessStopped(_read(current, send: smaller));
        } finally {
          for (final path in smaller ?? const <String>[]) {
            if (!current.mediaPaths.contains(path)) {
              await _media.discard([path]);
            }
          }
        }
        if (!_settings.keepMedia) {
          await _media.discard(current.mediaPaths);
          await _notes.clearMedia(note.id);
        }
        unawaited(_settings.recordSuccess());
        return true;
      }
      if (!current.hasMaterial) {
        await _notes.setStatus(
          note.id,
          NoteStatus.failed,
          error: 'There was nothing to read in this one.',
        );
        return true;
      }
      _enter(note.id, ProcessingStage.reading);
      await _unlessStopped(_distill(current));
      unawaited(_settings.recordSuccess());
      return true;
    } on WorkStopped {
      return _stopped(note);
    } on InstagramException catch (e) {
      // Stop dropped the connection; that isn't a failure to report.
      if (_stopRequested) return _stopped(note);
      debugPrint('Note ${note.id}: Instagram said $e');
      if (e.failure == InstagramFailure.network && attempt == 1) {
        return _again(
          note,
          attempt,
          e.failure.message,
          'Instagram: ${e.failure.name} ${e.detail ?? ''}',
        );
      }
      _problem(
        e.failure.message,
        'Instagram: ${e.failure.name} ${e.detail ?? ''}',
      );
      switch (e.failure) {
        case InstagramFailure.rateLimited:
          await _notes.setStatus(note.id, NoteStatus.queued);
          _pausedUntil = _now().add(instagramCooldown);
          return false;
        case InstagramFailure.signedOut || InstagramFailure.notFound:
          // The owner can still add the video by hand.
          await _notes.setStatus(
            note.id,
            NoteStatus.needsMedia,
            error: e.failure.message,
          );
          return true;
        case InstagramFailure.network || InstagramFailure.badResponse:
          await _notes.setStatus(
            note.id,
            NoteStatus.failed,
            error: e.failure.message,
          );
          return true;
      }
    } on AiException catch (e) {
      if (_stopRequested) return _stopped(note);
      debugPrint('Note ${note.id} failed: $e');
      if ((e.failure == AiFailure.network ||
              e.failure == AiFailure.overloaded) &&
          attempt == 1) {
        return _again(
          note,
          attempt,
          e.message ?? e.failure.message,
          'AI: ${e.failure.name} ${e.detail ?? ''}',
        );
      }
      _problem(
        e.message ?? e.failure.message,
        'AI: ${e.failure.name} ${e.detail ?? ''}',
      );
      if (e.failure.waits) {
        // Not the note's fault: it waits for a key, a sign-in or tomorrow.
        await _notes.setStatus(note.id, NoteStatus.queued);
        _blockedBy = e.failure;
        notifyListeners();
        return false;
      }
      await _notes.setStatus(
        note.id,
        NoteStatus.failed,
        error: e.failure.message,
      );
      if (e.failure == AiFailure.rateLimited) {
        _pausedUntil = _now().add(rateLimitCooldown);
      }
      // Rate limits and invalid keys will fail every other note too.
      return !(e.failure == AiFailure.rateLimited ||
          e.failure == AiFailure.invalidKey ||
          e.failure == AiFailure.unavailableHere);
    } on FileSystemException catch (e) {
      if (_stopRequested) return _stopped(note);
      debugPrint('Note ${note.id} media missing: $e');
      _problem('The video file is gone. Add it again to make the note.', e);
      await _notes.setStatus(
        note.id,
        NoteStatus.failed,
        error: 'The video file is gone. Add it again to make the note.',
      );
      return true;
    } catch (e, st) {
      if (_stopRequested) return _stopped(note);
      debugPrint('Note ${note.id} crashed: $e\n$st');
      _problem('Something went wrong while making this note.', e);
      await _notes.setStatus(
        note.id,
        NoteStatus.failed,
        error: 'Something went wrong while making this note. Try again.',
      );
      return true;
    }
  }

  Future<Note> _fetch(Note note) async {
    final fetched = await _instagram.fetch(
      pk: note.remoteId,
      shortcode: note.instagramShortcode,
    );
    final post = fetched.post;
    await _notes.saveFetched(
      note.id,
      mediaPaths: fetched.mediaPaths,
      kind: post.hasVideo ? SourceKind.video : SourceKind.images,
      remoteId: post.pk,
      // Keep words the owner shared along with the link.
      caption: (note.caption?.trim().isNotEmpty ?? false) ? null : post.caption,
      creatorHandle: post.username,
    );
    await _instagram.markSeen([post.pk]);
    return (await _notes.find(note.id))!;
  }

  /// [send] are smaller copies of the note's media, when there are some.
  Future<Note> _read(Note note, {List<String>? send}) async {
    for (final path in note.mediaPaths) {
      if (!await File(path).exists()) {
        throw FileSystemException('missing', path);
      }
    }
    final (extraction, written) = await _ai.read(
      send ?? note.mediaPaths,
      caption: note.caption,
      language: _settings.noteLanguage,
      onUpdate: (update) => _onUpdate(note.id, update),
      onUsage: (usage) => _used(note.id, usage),
      cancel: _cancel?.future,
    );
    await _saveExtraction(note, extraction);
    final updated = (await _notes.find(note.id))!;
    await _saveNote(updated, written);
    return updated;
  }

  Future<void> _saveExtraction(Note note, Extraction extraction) async {
    final json = extraction.fields;
    final handle = _str(json['creator_handle']).replaceFirst('@', '').trim();
    await _notes.saveExtraction(
      note.id,
      transcript: _str(json['transcript']),
      onScreenText: _strList(json['on_screen_text']),
      visualNotes: _str(json['visual_notes']),
      language: _str(json['language']),
      // A handle Instagram gave us beats one the model read off the video.
      creatorHandle: handle.isEmpty || note.creatorHandle != null
          ? null
          : handle,
    );
  }

  Future<void> _distill(Note note, {bool rewrite = false}) async {
    final material = Prompts.material(
      transcript: note.transcript,
      onScreenText: note.onScreenText,
      visualNotes: note.visualNotes,
      caption: note.caption,
      creatorHandle: note.creatorHandle,
    );
    final json = await _ai.write(
      material: material,
      language: _settings.noteLanguage,
      rewrite: rewrite,
      onUsage: (usage) => _used(note.id, usage),
    );
    await _saveNote(note, json);
  }

  Future<void> _saveNote(Note note, Map<String, Object?> json) async {
    final keyPoints = <KeyPoint>[];
    final rawPoints = json['key_points'];
    if (rawPoints is List) {
      for (final p in rawPoints.whereType<Map<String, Object?>>()) {
        final k = KeyPoint.fromJson(p);
        if (k.text.isEmpty) continue;
        // Drop highlights the model didn't copy exactly.
        keyPoints.add(
          k.text.contains(k.highlight)
              ? k
              : KeyPoint(text: k.text, highlight: ''),
        );
      }
    }
    final title = _str(json['title']);
    await _notes.saveDistillation(
      note.id,
      title: title.length > 90 ? '${title.substring(0, 87)}...' : title,
      summary: _str(json['summary']),
      keyPoints: keyPoints,
      actions: [for (final a in _strList(json['actions'])) ActionItem(text: a)],
      topic: _titleCase(_str(json['topic'])),
      tags: _strList(json['tags']).map((t) => t.toLowerCase()).toList(),
      chosenTopic: note.topicChosen ? note.topic : null,
    );
  }

  static String _str(Object? v) => v is String ? v.trim() : '';

  static List<String> _strList(Object? v) => v is List
      ? v
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
      : const [];

  static String _titleCase(String s) {
    if (s.isEmpty) return 'Other';
    // Keep acronyms like SEO or AI as written.
    return s
        .split(RegExp(r'\s+'))
        .map(
          (w) => w.toUpperCase() == w
              ? w
              : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
