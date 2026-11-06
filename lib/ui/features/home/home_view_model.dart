import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../config.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/instagram_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/models/ai.dart';
import '../../../domain/models/note.dart';
import '../../../domain/revisit.dart';
import '../../../domain/use_cases/capture.dart';
import '../../../domain/use_cases/note_processor.dart';
import '../../../domain/use_cases/saved_sync.dart';
import '../../core/work_status.dart';

/// A shelf on the home screen: a topic and how many notes are on it.
@immutable
class Shelf {
  const Shelf(this.name, this.count);

  final String name;
  final int count;
}

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required NotesRepository notes,
    required SettingsRepository settings,
    required NoteProcessor processor,
    required Capture capture,
    required InstagramRepository instagram,
    required SavedSync sync,
    required AccountRepository account,
    required NoteAi ai,
    this.edition = Edition.personal,
    DateTime Function()? clock,
  }) : _notes = notes,
       _account = account,
       _ai = ai,
       _settings = settings,
       _processor = processor,
       _capture = capture,
       _instagram = instagram,
       _sync = sync,
       _now = clock ?? DateTime.now {
    _sub = _notes.watchAll().listen((all) {
      _all = all;
      _loaded = true;
      notifyListeners();
    });
    _settings.addListener(notifyListeners);
    _processor.addListener(notifyListeners);
    _instagram.addListener(notifyListeners);
    _sync.addListener(notifyListeners);
    _account.addListener(notifyListeners);
  }

  final Edition edition;
  final AccountRepository _account;
  final NoteAi _ai;

  final NotesRepository _notes;
  final SettingsRepository _settings;
  final NoteProcessor _processor;
  final Capture _capture;
  final InstagramRepository _instagram;
  final SavedSync _sync;
  final DateTime Function() _now;
  late final StreamSubscription<List<Note>> _sub;

  /// Topic filter value that shows starred notes.
  static const starredShelf = '\u0000starred';

  List<Note> _all = const [];
  bool _loaded = false;
  String? _shelf;
  String _query = '';
  bool _searching = false;
  int _revisitOffset = 0;

  bool get loaded => _loaded;
  bool get isEmpty => _loaded && _all.isEmpty;
  String? get shelf => _shelf;
  String get query => _query;
  bool get searching => _searching;
  DateTime get now => _now();

  bool get hasStarred => _all.any((n) => n.starred);

  /// Topics with at least one ready note, most used first.
  List<Shelf> get shelves {
    final counts = <String, int>{};
    for (final n in _all) {
      final t = n.topic;
      if (n.isReady && t != null && t.isNotEmpty) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final list = counts.entries.map((e) => Shelf(e.key, e.value)).toList()
      ..sort((a, b) {
        final c = b.count.compareTo(a.count);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
    return list;
  }

  /// Notes that need the owner (waiting for video, failed) or are in progress.
  List<Note> get attention => _isFiltering
      ? const []
      : _all.where((n) => !n.isReady).toList(growable: false);

  /// Finished notes matching the current shelf and search.
  List<Note> get notes {
    final q = _query.trim().toLowerCase();
    return _all
        .where((n) {
          if (q.isNotEmpty) return n.searchableText.contains(q);
          if (!n.isReady) return false;
          if (_shelf == starredShelf) return n.starred;
          if (_shelf != null) return n.topic == _shelf;
          return true;
        })
        .toList(growable: false);
  }

  bool get _isFiltering => _shelf != null || _query.trim().isNotEmpty;

  /// Today's note to come back to, unless the owner is searching or filtering.
  Note? get revisit => _isFiltering || _searching
      ? null
      : Revisit.pick(_all, _now(), offset: _revisitOffset);

  bool get canShowAnotherRevisit => Revisit.candidates(_all, _now()).length > 1;

  /// Notes stuck because there's no API key yet.
  int get waitingForKey => _settings.hasGeminiKey
      ? 0
      : _all.where((n) => n.status == NoteStatus.queued).length;

  /// Why queued notes aren't being made right now, or null.
  AiFailure? get blockedReason => _ai.blocked ?? _processor.blockedBy;

  /// Notes waiting their turn.
  int get waitingCount =>
      _all.where((n) => n.status == NoteStatus.queued).length;

  bool get isPlay => edition == Edition.play;
  bool get signedIn => _account.signedIn;
  bool get isPlus => _account.account?.isPlus ?? false;
  int get notesPerDay => _account.account?.notesPerDay ?? 0;
  int get plusNotesPerDay => _account.account?.plusNotesPerDay ?? 0;

  /// Shows Google's account picker. Returns an error message, or null.
  Future<String?> signIn() async {
    try {
      await _account.signIn();
      return null;
    } on Object catch (e) {
      debugPrint('Sign-in failed: $e');
      return "Couldn't sign in with Google. Check the connection and try again.";
    }
  }

  bool get processorBlockedOnKey => _processor.blockedOnKey;

  bool get instagramConnected => _instagram.isConnected;

  /// Saves on Instagram turn into notes ("automatic by save").
  bool get notesFromSaves => _instagram.isConnected && _sync.enabled;

  /// Instagram ended the session; new saves aren't coming in.
  bool get instagramNeedsSignIn => _instagram.needsSignIn;

  /// Looking at the Saved list right now.
  bool get checkingSaves => _sync.isRunning;

  /// What is happening to [note] if it's being worked on right now.
  ProcessingStage? stageOf(Note note) => _processor.stageOf(note.id);

  /// Since when, to show how long it's been going.
  DateTime? workingSince(Note note) => _processor.stageSince(note.id);

  /// What it is doing, in words (sending, Gemini watching...).
  WorkStatus workStatus(Note note) => WorkStatus(
    stage: _processor.stageOf(note.id),
    update: _processor.readUpdateOf(note.id),
    images: note.sourceKind == SourceKind.images,
    retryReason: _processor.retryReasonOf(note.id),
    shrinkProgress: _processor.shrinkProgressOf(note.id),
  );

  /// Stops making [note]; it waits for Try again.
  void stop(Note note) => _processor.stop(note.id);

  /// What a check that found nothing new did find, in words.
  String get noNewSavesMessage => switch (_sync.newestSave) {
    _ when !_sync.enabled => 'Saves don\'t turn into notes: Settings, Instagram is set to "Just share".',
    null => 'Your Saved list on Instagram is empty.',
    (post: _, note: final note?) =>
      'No new saves. Your latest save is already here: '
          '"${note.displayTitle}".',
    (post: final post, note: null) =>
      'No new saves. Your latest save on Instagram (${post.username == null ? 'a post' : '@${post.username}'}) '
          'was there before you connected, or its note was deleted. Share it '
          'to Commonplace to make a note of it.',
  };

  /// Pull to refresh: looks at the Saved list now. Returns how many new
  /// notes were added, or null if the check failed.
  Future<int?> checkSaves() async {
    final added = await _sync.check(force: true);
    return _sync.lastFailure == null ? added : null;
  }

  String? get lastCheckFailure => _sync.lastFailure?.message;

  void selectShelf(String? shelf) {
    _shelf = _shelf == shelf ? null : shelf;
    notifyListeners();
  }

  void startSearch() {
    _searching = true;
    notifyListeners();
  }

  void stopSearch() {
    _searching = false;
    _query = '';
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void showAnotherRevisit() {
    _revisitOffset++;
    notifyListeners();
  }

  Future<void> retry(Note note) => _processor.retry(note.id);

  Future<void> attach(Note note, List<String> paths) =>
      _capture.attach(note.id, paths);

  Future<void> delete(Note note) => _capture.delete(note);

  @override
  void dispose() {
    unawaited(_sub.cancel());
    _settings.removeListener(notifyListeners);
    _processor.removeListener(notifyListeners);
    _instagram.removeListener(notifyListeners);
    _sync.removeListener(notifyListeners);
    _account.removeListener(notifyListeners);
    super.dispose();
  }
}
