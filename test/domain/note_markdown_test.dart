import 'package:commonplace/domain/models/note.dart';
import 'package:commonplace/domain/note_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

Note _note(int id, {String? transcript}) => Note(
  id: id,
  createdAt: DateTime(2026, 11, 3, 9),
  updatedAt: DateTime(2026, 11, 3, 9),
  status: NoteStatus.ready,
  sourceKind: SourceKind.video,
  sourceUrl: 'https://www.instagram.com/reel/ABC$id/',
  creatorHandle: 'seo.with.sam',
  title: 'Write titles like questions $id',
  summary: 'People search in questions.',
  keyPoints: const [
    KeyPoint(text: 'Use the exact question.', highlight: 'exact question'),
  ],
  actions: const [ActionItem(text: 'Rewrite one title', done: true)],
  topic: 'SEO',
  personalNote: 'Try on the blog.',
  transcript: transcript,
  onScreenText: const ['3 title tips'],
);

void main() {
  test('a note for an AI chat has its details and everything said', () {
    final text = noteMarkdown(_note(1, transcript: 'Hi, here are tips.'));
    expect(text, startsWith('# Write titles like questions 1\n'));
    expect(
      text,
      contains('Topic: SEO\nFrom: @seo.with.sam\nSaved: 2026-11-03'),
    );
    expect(text, contains('Source: https://www.instagram.com/reel/ABC1/'));
    expect(text, contains('## Key points\n- Use the exact question.\n'));
    expect(text, contains('## Things to try\n- [x] Rewrite one title\n'));
    expect(text, contains('## My notes\nTry on the blog.\n'));
    expect(text, contains('## What was said\nHi, here are tips.\n'));
    expect(text, contains('## Text on screen\n- 3 title tips\n'));
  });

  test('the short version for sharing leaves out the material', () {
    final text = noteMarkdown(
      _note(1, transcript: 'Hi, here are tips.'),
      withDetails: false,
      withMaterial: false,
    );
    expect(text, isNot(contains('What was said')));
    expect(text, isNot(contains('Topic:')));
    expect(text, endsWith('\nSource: https://www.instagram.com/reel/ABC1/\n'));
  });

  test('Copy all joins the notes, and fits the clipboard', () {
    final notes = [
      for (var i = 1; i <= 3; i++) _note(i, transcript: 'word ' * 200),
    ];

    final all = notesMarkdown(notes);
    expect(all.count, 3);
    expect(all.withMaterial, isTrue);
    expect('\n---\n'.allMatches(all.text), hasLength(2));

    // Too long with the transcripts: the notes go without them.
    final short = noteMarkdown(notes.first, withMaterial: false).length;
    final noMaterial = notesMarkdown(notes, maxChars: short * 3 + 20);
    expect(noMaterial.count, 3);
    expect(noMaterial.withMaterial, isFalse);
    expect(noMaterial.text, isNot(contains('What was said')));

    // Still too long: as many of the newest as fit.
    final some = notesMarkdown(notes, maxChars: short * 2 + 10);
    expect(some.count, 2);
    expect(some.text.length, lessThanOrEqualTo(short * 2 + 10));
    expect(some.text, contains('questions 1'));
    expect(some.text, isNot(contains('questions 3')));
  });
}
