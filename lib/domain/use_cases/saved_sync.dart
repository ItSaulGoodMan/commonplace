import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/instagram_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/services/instagram_api.dart';
import '../models/note.dart';
import 'note_processor.dart';

/// Turns new saves on Instagram into notes.
///
/// Instagram lists saves newest first. A check walks down from the top and
/// stops at the first post it has seen before, so a normal check is a single
/// small request, much like opening the Saved tab.
class SavedSync extends ChangeNotifier {
  SavedSync({
    required InstagramRepository instagram,
    required NotesRepository notes,
    required NoteProcessor processor,
    DateTime Function()? clock,
    bool Function()? enabled,
  }) : _instagram = instagram,
       _notes = notes,
       _processor = processor,
       _now = clock ?? DateTime.now,
       _enabled = enabled ?? (() => true);

  final InstagramRepository _instagram;
  final NotesRepository _notes;
  final NoteProcessor _processor;
  final DateTime Function() _now;

  /// Off when the owner chose "just share": the Saved list isn't read.
  final bool Function() _enabled;
  bool get enabled => _enabled();

  /// Back to "automatic by save": only saves from now on become notes, not
  /// everything saved while it was off.
  Future<void> turnedOn() => _instagram.resetBaseline();

  /// The owner switched between "just share" and "automatic by save".
  void modeChanged() => notifyListeners();

  /// Checks closer together than this are skipped unless forced.
  static const minInterval = Duration(minutes: 2);

  /// How far down the Saved list one check may walk.
  static const maxPages = 3;

  /// At most this many new notes per check, to stay inside Gemini's free
  /// daily limit if a lot was saved at once.
  static const maxNewPerCheck = 20;

  /// How many recent saves the owner is offered right after signing in.
  static const startCount = 10;

  bool _running = false;
  bool get isRunning => _running;

  InstagramFailure? _lastFailure;
  InstagramFailure? get lastFailure => _lastFailure;

  /// The newest post on the Saved list at the last check, and the note made
  /// of it if there is one, so "no new saves" can say what it did find.
  ({InstagramPost post, Note? note})? _newest;
  ({InstagramPost post, Note? note})? get newestSave => _newest;

  /// Looks for new saves. Returns how many notes were added.
  Future<int> check({bool force = false}) async {
    if (_running || !_instagram.isConnected || !_enabled()) return 0;
    final last = _instagram.lastCheckedAt;
    if (!force && last != null && _now().difference(last) < minInterval) {
      return 0;
    }
    _running = true;
    _lastFailure = null;
    notifyListeners();
    try {
      if (!_instagram.baselineDone) {
        // Signed in but the starting point was never recorded (the first
        // check failed, say). Don't flood the queue with old saves.
        final page = await _instagram.savedPage();
        await _instagram.markSeen(page.posts.map((p) => p.pk));
        await _instagram.markBaselineDone();
        await _instagram.markChecked();
        return 0;
      }

      final fresh = <InstagramPost>[];
      String? maxId;
      InstagramPost? newest;
      walk:
      for (var page = 0; page < maxPages; page++) {
        final result = await _instagram.savedPage(maxId: maxId);
        newest ??= result.posts.firstOrNull;
        for (final post in result.posts) {
          if (await _instagram.isSeen(post.pk)) break walk;
          fresh.add(post);
          if (fresh.length == maxNewPerCheck) break walk;
        }
        if (!result.moreAvailable || result.nextMaxId == null) break;
        maxId = result.nextMaxId;
      }
      final added = await _add(fresh);
      _newest = newest == null
          ? null
          : (post: newest, note: await _notes.findByShortcode(newest.code));
      await _instagram.markChecked();
      // Instagram answered, so the connection is back: retry notes that
      // failed while it was down.
      await _processor.retryTransient();
      return added;
    } on InstagramException catch (e) {
      debugPrint('Saved check failed: $e');
      _lastFailure = e.failure;
      return 0;
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  /// Right after signing in: the latest saves, for the "start with these?"
  /// choice.
  Future<List<InstagramPost>> latest() async {
    final page = await _instagram.savedPage();
    return page.posts;
  }

  /// Records where the Saved list starts and makes notes from the first
  /// [count] posts of [latest]. Everything else on that page counts as old.
  Future<int> startFrom(
    List<InstagramPost> latest, {
    required int count,
  }) async {
    await _instagram.markSeen(latest.map((p) => p.pk));
    await _instagram.markBaselineDone();
    final added = await _add(latest.take(count).toList());
    await _instagram.markChecked();
    // Links shared before signing in can now be fetched too.
    await _notes.requeueInstagramWaiting();
    unawaited(_processor.kick());
    return added;
  }

  /// After signing in again: fetch what was waiting and catch up on saves.
  Future<void> afterSignIn() async {
    await _notes.requeueInstagramWaiting();
    await _processor.retryTransient();
    unawaited(_processor.kick());
    unawaited(check(force: true));
  }

  /// [posts] are newest first; notes are created oldest first so the list
  /// in Commonplace keeps Instagram's order.
  Future<int> _add(List<InstagramPost> posts) async {
    var added = 0;
    for (final post in posts.reversed) {
      final existing = await _notes.findByShortcode(post.code);
      if (existing == null) {
        await _notes.create(
          status: NoteStatus.queued,
          sourceKind: post.hasVideo ? SourceKind.video : SourceKind.images,
          sourceUrl: post.url,
          remoteId: post.pk,
          creatorHandle: post.username,
          caption: post.caption,
        );
        added++;
      }
      await _instagram.markSeen([post.pk]);
    }
    if (added > 0) unawaited(_processor.kick());
    return added;
  }
}
