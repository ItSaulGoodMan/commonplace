import 'package:commonplace/domain/models/note.dart';
import 'package:commonplace/domain/revisit.dart';
import 'package:flutter_test/flutter_test.dart';

Note _note(
  int id, {
  required DateTime created,
  DateTime? opened,
  NoteStatus status = NoteStatus.ready,
  bool withPoints = true,
}) => Note(
  id: id,
  createdAt: created,
  updatedAt: created,
  status: status,
  sourceKind: SourceKind.video,
  title: 'Note $id',
  lastOpenedAt: opened,
  keyPoints: withPoints
      ? const [KeyPoint(text: 'A point', highlight: 'point')]
      : const [],
);

void main() {
  final now = DateTime(2026, 11, 6, 9);

  group('Revisit.candidates', () {
    test('needs at least two finished notes', () {
      expect(
        Revisit.candidates([_note(1, created: DateTime(2026, 10, 1))], now),
        isEmpty,
      );
    });

    test(
      'skips unfinished notes, notes without points, and anything from today',
      () {
        final notes = [
          _note(1, created: DateTime(2026, 10, 1)),
          _note(2, created: DateTime(2026, 10, 2), status: NoteStatus.failed),
          _note(3, created: DateTime(2026, 10, 3), withPoints: false),
          _note(4, created: DateTime(2026, 11, 6, 8)),
          _note(
            5,
            created: DateTime(2026, 9, 1),
            opened: DateTime(2026, 11, 6, 7),
          ),
          _note(6, created: DateTime(2026, 10, 20)),
        ];
        expect(Revisit.candidates(notes, now).map((n) => n.id), [1, 6]);
      },
    );

    test('orders by when you last looked, stalest first', () {
      final notes = [
        _note(1, created: DateTime(2026, 8, 1), opened: DateTime(2026, 11, 1)),
        _note(2, created: DateTime(2026, 10, 1)),
        _note(3, created: DateTime(2026, 9, 1)),
      ];
      expect(Revisit.candidates(notes, now).map((n) => n.id), [3, 2, 1]);
    });
  });

  group('Revisit.pick', () {
    final notes = [
      for (var i = 1; i <= 4; i++) _note(i, created: DateTime(2026, 9, i)),
    ];

    test('is stable through the day', () {
      final morning = Revisit.pick(notes, DateTime(2026, 11, 6, 7));
      final evening = Revisit.pick(notes, DateTime(2026, 11, 6, 22));
      expect(morning!.id, evening!.id);
    });

    test('"show another" moves to a different note', () {
      final first = Revisit.pick(notes, now);
      final second = Revisit.pick(notes, now, offset: 1);
      expect(first!.id, isNot(second!.id));
    });
  });

  group('relativeAge', () {
    test('reads naturally', () {
      expect(relativeAge(DateTime(2026, 11, 6, 1), now), 'today');
      expect(relativeAge(DateTime(2026, 11, 5, 23), now), 'yesterday');
      expect(relativeAge(DateTime(2026, 11, 2), now), '4 days ago');
      expect(relativeAge(DateTime(2026, 10, 28), now), 'last week');
      expect(relativeAge(DateTime(2026, 10, 15), now), '3 weeks ago');
      expect(relativeAge(DateTime(2026, 9, 20), now), 'last month');
      expect(relativeAge(DateTime(2026, 6, 1), now), '5 months ago');
      expect(relativeAge(DateTime(2025, 6, 1), now), 'last year');
      expect(revisitHeading(DateTime(2026, 10, 15), now), 'From 3 weeks ago');
    });
  });
}
