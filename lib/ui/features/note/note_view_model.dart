import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../config.dart';
import '../../../data/repositories/instagram_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../domain/models/ai.dart';
import '../../../domain/models/note.dart';
import '../../../domain/use_cases/capture.dart';
import '../../../domain/use_cases/note_processor.dart';
import '../../core/work_status.dart';

class NoteViewModel extends ChangeNotifier {
  NoteViewModel({
    required this.id,
    required NotesRepository notes,
    required NoteProcessor processor,
    required Capture capture,
    required InstagramRepository instagram,
    this.edition = Edition.personal,
  }) : _notes = notes,
       _processor = processor,
       _capture = capture,
       _instagram = instagram {
    _processor.addListener(notifyListeners);
    _instagram.addListener(notifyListeners);
    _sub = _notes.watch(id).listen((note) {
      final first = !_loaded;
      final wasReady = _note?.isReady ?? false;
      _note = note;
      _loaded = true;
      if (note != null) {
        if (first) unawaited(_notes.markOpened(id));
        // Play the highlighter once, when a finished note is first seen,
        // including when it finishes (or is rewritten) while open.
        if (note.isReady && !note.highlightsRevealed && (first || !wasReady)) {
          _animateHighlights = true;
          _revealGeneration++;
          unawaited(_notes.markHighlightsRevealed(id));
        }
      }
      notifyListeners();
    });
    _spendSub = _notes.watchSpendForNote(id).listen((spend) {
      _spend = spend;
      notifyListeners();
    });
  }

  /// What Gemini used for this note, with the owner's key.
  AiSpend get spend => _spend;
  AiSpend _spend = AiSpend.none;
  late final StreamSubscription<AiSpend> _spendSub;

  final int id;
  final NotesRepository _notes;
  final NoteProcessor _processor;
  final Capture _capture;
  final InstagramRepository _instagram;
  late final StreamSubscription<Note?> _sub;
  Timer? _saveTimer;
  String? _pendingPersonalNote;

  Note? _note;
  bool _loaded = false;
  bool _animateHighlights = false;
  bool _rewriting = false;

  Note? get note => _note;

  final Edition edition;

  /// Whether Instagram sign-in exists in this build at all.
  bool get offersInstagram => edition == Edition.personal;

  /// Where "Report a problem with this note" writes to (Play edition).
  String? get reportEmail =>
      edition == Edition.play && PlayConfig.supportEmail.isNotEmpty
      ? PlayConfig.supportEmail
      : null;

  bool get instagramConnected => _instagram.isConnected;

  /// Being fetched from Instagram right now.
  bool get fetching => _processor.stageOf(id) == ProcessingStage.fetching;

  /// Since when the current step has been running, if it's this note's turn.
  DateTime? get workingSince => _processor.stageSince(id);

  /// What it is doing, in words (sending, Gemini watching...).
  WorkStatus get workStatus => WorkStatus(
    stage: _processor.stageOf(id),
    update: _processor.readUpdateOf(id),
    images: _note?.sourceKind == SourceKind.images,
    retryReason: _processor.retryReasonOf(id),
    shrinkProgress: _processor.shrinkProgressOf(id),
  );

  /// Stops making this note; it waits for Try again.
  void stop() => _processor.stop(id);
  bool get loaded => _loaded;
  bool get animateHighlights => _animateHighlights;

  /// Changes each time a reveal should replay; use it in widget keys.
  int get revealGeneration => _revealGeneration;
  int _revealGeneration = 0;
  bool get rewriting => _rewriting;

  Future<void> toggleStar() async {
    final n = _note;
    if (n != null) await _notes.setStarred(id, !n.starred);
  }

  Future<void> toggleAction(int index) async {
    final n = _note;
    if (n == null || index >= n.actions.length) return;
    final actions = [...n.actions];
    actions[index] = actions[index].copyWith(done: !actions[index].done);
    await _notes.setActions(id, actions);
  }

  Future<void> setTopic(String topic) async {
    if (topic.trim().isEmpty) return;
    await _notes.setTopic(id, topic);
  }

  Future<List<String>> topics() => _notes.topics();

  /// Saves the owner's own note shortly after they stop typing.
  void editPersonalNote(String text) {
    _pendingPersonalNote = text;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), flushPersonalNote);
  }

  Future<void> flushPersonalNote() async {
    _saveTimer?.cancel();
    final text = _pendingPersonalNote;
    _pendingPersonalNote = null;
    if (text != null) await _notes.setPersonalNote(id, text);
  }

  Future<void> attach(List<String> paths) => _capture.attach(id, paths);

  Future<void> retry() => _processor.retry(id);

  /// Rewrites the note from the saved transcript. Returns an error message, or null.
  Future<String?> rewrite() async {
    _rewriting = true;
    notifyListeners();
    try {
      await _processor.rewrite(id);
      return null;
    } on AiException catch (e) {
      return e.failure.message;
    } finally {
      _rewriting = false;
      notifyListeners();
    }
  }

  Future<void> delete() async {
    final n = _note;
    if (n != null) await _capture.delete(n);
  }

  /// The note as plain Markdown, for sharing.
  String asMarkdown() {
    final n = _note;
    if (n == null) return '';
    final b = StringBuffer('# ${n.displayTitle}\n');
    if (n.summary case final s? when s.isNotEmpty) b.write('\n$s\n');
    if (n.keyPoints.isNotEmpty) {
      b.write('\n## Key points\n');
      for (final k in n.keyPoints) {
        b.write('- ${k.text}\n');
      }
    }
    if (n.actions.isNotEmpty) {
      b.write('\n## Things to try\n');
      for (final a in n.actions) {
        b.write('- [${a.done ? 'x' : ' '}] ${a.text}\n');
      }
    }
    if (n.personalNote case final p? when p.trim().isNotEmpty) {
      b.write('\n## My notes\n$p\n');
    }
    if (n.sourceUrl case final u?) b.write('\nSource: $u\n');
    return b.toString();
  }

  @override
  void dispose() {
    unawaited(flushPersonalNote());
    unawaited(_sub.cancel());
    unawaited(_spendSub.cancel());
    _processor.removeListener(notifyListeners);
    _instagram.removeListener(notifyListeners);
    super.dispose();
  }
}
