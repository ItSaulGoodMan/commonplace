import 'models/note.dart';

/// [note] as Markdown, to paste into an AI chat or anywhere else.
///
/// [withDetails] adds the topic, creator, date and link at the top.
/// [withMaterial] adds what the note was made from (what was said, the text
/// on screen, the caption), so whoever reads it has the whole reel, not only
/// the summary. Without both, it's the short version for sharing with a
/// person.
String noteMarkdown(
  Note note, {
  bool withDetails = true,
  bool withMaterial = true,
}) {
  final b = StringBuffer('# ${note.displayTitle}\n');

  if (withDetails) {
    final details = [
      if (note.topic case final t? when t.isNotEmpty) 'Topic: $t',
      if (note.creatorHandle case final h? when h.isNotEmpty) 'From: @$h',
      'Saved: ${_day(note.createdAt)}',
      if (note.sourceUrl case final u?) 'Source: $u',
    ];
    b.write('\n${details.join('\n')}\n');
  }

  if (note.summary case final s? when s.trim().isNotEmpty) {
    b.write('\n${s.trim()}\n');
  }
  if (note.keyPoints.isNotEmpty) {
    b.write('\n## Key points\n');
    for (final k in note.keyPoints) {
      b.write('- ${k.text}\n');
    }
  }
  if (note.actions.isNotEmpty) {
    b.write('\n## Things to try\n');
    for (final a in note.actions) {
      b.write('- [${a.done ? 'x' : ' '}] ${a.text}\n');
    }
  }
  if (note.personalNote case final p? when p.trim().isNotEmpty) {
    b.write('\n## My notes\n${p.trim()}\n');
  }

  if (withMaterial) {
    if (note.transcript case final t? when t.trim().isNotEmpty) {
      b.write('\n## What was said\n${t.trim()}\n');
    }
    if (note.onScreenText.isNotEmpty) {
      b.write('\n## Text on screen\n');
      for (final line in note.onScreenText) {
        b.write('- $line\n');
      }
    }
    if (note.visualNotes case final v? when v.trim().isNotEmpty) {
      b.write('\n## What the video shows\n${v.trim()}\n');
    }
    if (note.caption case final c? when c.trim().isNotEmpty) {
      b.write('\n## Caption\n${c.trim()}\n');
    }
  }

  if (!withDetails) {
    if (note.sourceUrl case final u?) b.write('\nSource: $u\n');
  }
  return b.toString();
}

/// What Copy all put on the clipboard.
typedef CopiedNotes = ({String text, int count, bool withMaterial});

/// [notes] as one Markdown text of at most [maxChars] characters.
///
/// Android's clipboard goes through a 1 MB message, so a very long text
/// can't be copied at all. If everything doesn't fit, the notes go without
/// their material (transcripts and so on); if that still doesn't fit, only
/// as many of the first notes as do (the list is newest first).
CopiedNotes notesMarkdown(List<Note> notes, {int maxChars = 300000}) {
  final full = [for (final n in notes) noteMarkdown(n)].join(_separator);
  if (full.length <= maxChars) {
    return (text: full, count: notes.length, withMaterial: true);
  }

  final short = [for (final n in notes) noteMarkdown(n, withMaterial: false)];
  var length = 0;
  var count = 0;
  for (final part in short) {
    final next = length + (count == 0 ? 0 : _separator.length) + part.length;
    if (next > maxChars) break;
    length = next;
    count++;
  }
  return (
    text: short.take(count).join(_separator),
    count: count,
    withMaterial: false,
  );
}

const _separator = '\n---\n\n';

String _day(DateTime d) {
  final local = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}
