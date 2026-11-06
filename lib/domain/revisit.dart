import 'models/note.dart';

/// Picks the note to bring back on the home screen.
///
/// Favours notes you haven't looked at for the longest time. The pick is
/// stable for a whole day, so it feels like a daily page rather than a
/// slot machine; "Show another" steps through the next few.
abstract final class Revisit {
  /// Notes eligible for revisiting, stalest first.
  static List<Note> candidates(List<Note> notes, DateTime now) {
    final ready = notes
        .where((n) => n.isReady && n.keyPoints.isNotEmpty)
        .toList();
    if (ready.length < 2) return const [];

    DateTime lastSeen(Note n) => n.lastOpenedAt ?? n.createdAt;
    final today = DateTime(now.year, now.month, now.day);

    // Skip anything seen or saved today: you remember it already.
    final stale = ready.where((n) => lastSeen(n).isBefore(today)).toList()
      ..sort((a, b) => lastSeen(a).compareTo(lastSeen(b)));
    return stale;
  }

  /// The note for today, shifted by [offset] when the owner asks for another.
  static Note? pick(List<Note> notes, DateTime now, {int offset = 0}) {
    final pool = candidates(notes, now);
    if (pool.isEmpty) return null;
    final window = pool.take(7).toList();
    final day = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(2024)).inDays;
    return window[(day + offset) % window.length];
  }
}

/// "today", "yesterday", "3 days ago", "last month"...
String relativeAge(DateTime then, DateTime now) {
  final a = DateTime(then.year, then.month, then.day);
  final b = DateTime(now.year, now.month, now.day);
  final days = b.difference(a).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return '$days days ago';
  if (days < 14) return 'last week';
  if (days < 31) return '${days ~/ 7} weeks ago';
  if (days < 61) return 'last month';
  if (days < 365) return '${days ~/ 30} months ago';
  if (days < 730) return 'last year';
  return '${days ~/ 365} years ago';
}

/// "From three weeks ago" style phrasing for the revisit block.
String revisitHeading(DateTime then, DateTime now) =>
    'From ${relativeAge(then, now)}';
