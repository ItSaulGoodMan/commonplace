import 'dart:async';

import '../../data/repositories/instagram_repository.dart';
import '../../data/repositories/notes_repository.dart';
import '../../data/services/local_stores.dart';
import '../models/note.dart';
import '../shared_link.dart';
import 'note_processor.dart';

/// Something that arrived from the share sheet or the add menu.
class Incoming {
  const Incoming({this.texts = const [], this.filePaths = const []});

  /// Shared text: links, captions, anything typed.
  final List<String> texts;

  /// Shared or picked video/image files (temporary paths).
  final List<String> filePaths;

  bool get isEmpty => texts.every((t) => t.trim().isEmpty) && filePaths.isEmpty;
}

enum CaptureOutcome {
  /// A new note was created and is being read (for an Instagram link with
  /// a signed-in account, fetched first).
  queued,

  /// A link was saved; it still needs the video.
  waitingForVideo,

  /// The link was already saved earlier.
  alreadySaved,

  /// Media was attached to a link saved a few minutes ago.
  attachedToRecent,

  /// Nothing usable was shared.
  nothing,
}

class CaptureResult {
  const CaptureResult(this.outcome, [this.noteId]);

  final CaptureOutcome outcome;
  final int? noteId;
}

/// Turns anything shared into the app into a note.
class Capture {
  Capture({
    required NotesRepository notes,
    required MediaStore media,
    required NoteProcessor processor,
    required InstagramRepository instagram,
    DateTime Function()? clock,
  }) : _notes = notes,
       _media = media,
       _processor = processor,
       _instagram = instagram,
       _now = clock ?? DateTime.now;

  final NotesRepository _notes;
  final MediaStore _media;
  final NoteProcessor _processor;
  final InstagramRepository _instagram;
  final DateTime Function() _now;

  /// How long after saving a link a shared video is assumed to belong to it.
  static const attachWindow = Duration(minutes: 15);

  Future<CaptureResult> handle(Incoming incoming) async {
    if (incoming.isEmpty) return const CaptureResult(CaptureOutcome.nothing);

    final text = incoming.texts
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .join('\n\n');
    final link = text.isEmpty ? null : SharedLink.find(text);
    final leftover = text.isEmpty ? null : SharedLink.textWithoutLink(text);

    final files = incoming.filePaths
        .where((p) => MediaStore.isVideo(p) || MediaStore.isImage(p))
        .toList();

    if (files.isNotEmpty) {
      final kept = <String>[];
      for (final f in files) {
        kept.add(await _media.keep(f));
      }
      final kind = kept.any(MediaStore.isVideo)
          ? SourceKind.video
          : SourceKind.images;

      // Typical flow: share the link, then download and share the video.
      if (link == null) {
        final waiting = await _notes.latestNeedingMedia(
          since: _now().subtract(attachWindow),
        );
        if (waiting != null) {
          await _notes.attachMedia(waiting.id, kept, kind);
          unawaited(_processor.kick());
          return CaptureResult(CaptureOutcome.attachedToRecent, waiting.id);
        }
      } else {
        final existing = await _notes.findBySource(link);
        if (existing != null && existing.status == NoteStatus.needsMedia) {
          await _notes.attachMedia(existing.id, kept, kind);
          unawaited(_processor.kick());
          return CaptureResult(CaptureOutcome.attachedToRecent, existing.id);
        }
      }

      final id = await _notes.create(
        status: NoteStatus.queued,
        sourceKind: kind,
        sourceUrl: link?.url,
        caption: leftover,
        mediaPaths: kept,
      );
      unawaited(_processor.kick());
      return CaptureResult(CaptureOutcome.queued, id);
    }

    if (link != null) {
      final existing = await _notes.findBySource(link);
      if (existing != null) {
        return CaptureResult(CaptureOutcome.alreadySaved, existing.id);
      }
      // Signed in to Instagram: the post is fetched from there.
      final fetchable = link.isInstagram && _instagram.isConnected;
      final id = await _notes.create(
        status: fetchable ? NoteStatus.queued : NoteStatus.needsMedia,
        sourceKind: SourceKind.link,
        sourceUrl: link.url,
        caption: leftover,
      );
      if (fetchable) {
        unawaited(_processor.kick());
        return CaptureResult(CaptureOutcome.queued, id);
      }
      return CaptureResult(CaptureOutcome.waitingForVideo, id);
    }

    // Plain text: a pasted caption, a tip, anything worth keeping.
    final id = await _notes.create(
      status: NoteStatus.queued,
      sourceKind: SourceKind.text,
      caption: text,
    );
    unawaited(_processor.kick());
    return CaptureResult(CaptureOutcome.queued, id);
  }

  /// Adds the video (or images) to a note that was saved from a link.
  Future<void> attach(int noteId, List<String> filePaths) async {
    final files = filePaths
        .where((p) => MediaStore.isVideo(p) || MediaStore.isImage(p))
        .toList();
    if (files.isEmpty) return;
    final kept = <String>[];
    for (final f in files) {
      kept.add(await _media.keep(f));
    }
    final kind = kept.any(MediaStore.isVideo)
        ? SourceKind.video
        : SourceKind.images;
    await _notes.attachMedia(noteId, kept, kind);
    unawaited(_processor.kick());
  }

  /// Deletes a note and any media it still holds.
  Future<void> delete(Note note) async {
    await _media.discard(note.mediaPaths);
    await _notes.delete(note.id);
  }
}
