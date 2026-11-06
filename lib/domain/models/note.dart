import 'package:flutter/foundation.dart';

import '../shared_link.dart';

/// Where a note is in its life.
enum NoteStatus {
  /// Saved from a link; the reel's video hasn't been added yet.
  needsMedia,

  /// Has material and is waiting its turn to be read by the AI.
  queued,

  /// The AI is reading it right now.
  processing,

  /// Finished note.
  ready,

  /// The AI step failed; [Note.errorMessage] says why.
  failed,
}

/// What the note was made from.
enum SourceKind { video, images, link, text }

@immutable
class KeyPoint {
  const KeyPoint({required this.text, required this.highlight});

  final String text;

  /// The phrase inside [text] that carries the idea. May be empty.
  final String highlight;

  Map<String, Object?> toJson() => {'text': text, 'highlight': highlight};

  factory KeyPoint.fromJson(Map<String, Object?> json) => KeyPoint(
    text: (json['text'] as String? ?? '').trim(),
    highlight: (json['highlight'] as String? ?? '').trim(),
  );

  @override
  bool operator ==(Object other) =>
      other is KeyPoint && other.text == text && other.highlight == highlight;

  @override
  int get hashCode => Object.hash(text, highlight);
}

@immutable
class ActionItem {
  const ActionItem({required this.text, this.done = false});

  final String text;
  final bool done;

  ActionItem copyWith({bool? done}) =>
      ActionItem(text: text, done: done ?? this.done);

  Map<String, Object?> toJson() => {'text': text, 'done': done};

  factory ActionItem.fromJson(Map<String, Object?> json) => ActionItem(
    text: (json['text'] as String? ?? '').trim(),
    done: json['done'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is ActionItem && other.text == text && other.done == done;

  @override
  int get hashCode => Object.hash(text, done);
}

/// One saved reel, post or snippet and everything learned from it.
@immutable
class Note {
  const Note({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.sourceKind,
    this.sourceUrl,
    this.remoteId,
    this.creatorHandle,
    this.caption,
    this.mediaPaths = const [],
    this.transcript,
    this.onScreenText = const [],
    this.visualNotes,
    this.language,
    this.title,
    this.summary,
    this.keyPoints = const [],
    this.actions = const [],
    this.topic,
    this.topicChosen = false,
    this.tags = const [],
    this.personalNote,
    this.starred = false,
    this.lastOpenedAt,
    this.openCount = 0,
    this.errorMessage,
    this.highlightsRevealed = false,
  });

  final int id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final NoteStatus status;
  final SourceKind sourceKind;

  /// Link to the original post, if known.
  final String? sourceUrl;

  /// Instagram's numeric id for the post, if known.
  final String? remoteId;

  /// Creator's @handle without the @, if known.
  final String? creatorHandle;

  /// Caption or any text the user shared or typed.
  final String? caption;

  /// Local copies of shared video/image files, kept until the AI has read them.
  final List<String> mediaPaths;

  final String? transcript;
  final List<String> onScreenText;
  final String? visualNotes;
  final String? language;

  final String? title;
  final String? summary;
  final List<KeyPoint> keyPoints;
  final List<ActionItem> actions;
  final String? topic;

  /// Whether the owner picked [topic] by hand (rewrites keep it).
  final bool topicChosen;
  final List<String> tags;

  /// The owner's own thoughts. Never touched by the AI.
  final String? personalNote;

  final bool starred;
  final DateTime? lastOpenedAt;
  final int openCount;
  final String? errorMessage;

  /// Whether the one-time highlighter animation has played.
  final bool highlightsRevealed;

  bool get isReady => status == NoteStatus.ready;

  /// The post's shortcode, when this note points at Instagram.
  String? get instagramShortcode {
    final url = sourceUrl;
    if (url == null) return null;
    final link = SharedLink.find(url);
    return link != null && link.isInstagram ? link.shortcode : null;
  }

  /// Whether the post itself still has to be fetched from Instagram.
  bool get needsInstagramFetch =>
      instagramShortcode != null &&
      mediaPaths.isEmpty &&
      (transcript?.trim().isEmpty ?? true) &&
      onScreenText.isEmpty;

  bool get isBusy =>
      status == NoteStatus.queued || status == NoteStatus.processing;

  /// Whether the AI has anything to read.
  bool get hasMaterial =>
      mediaPaths.isNotEmpty ||
      (caption?.trim().isNotEmpty ?? false) ||
      (transcript?.trim().isNotEmpty ?? false) ||
      onScreenText.isNotEmpty;

  /// A title that is always safe to show.
  String get displayTitle {
    final t = title?.trim();
    if (t != null && t.isNotEmpty) return t;
    final c = caption?.trim();
    if (c != null && c.isNotEmpty) {
      final firstLine = c.split('\n').first;
      return firstLine.length > 70
          ? '${firstLine.substring(0, 67).trimRight()}...'
          : firstLine;
    }
    return switch (sourceKind) {
      SourceKind.link => 'Saved reel',
      SourceKind.video => sourceUrl == null ? 'Saved video' : 'Saved reel',
      SourceKind.images => 'Saved post',
      SourceKind.text => 'Saved text',
    };
  }

  /// All text a search should look through, lowercased.
  String get searchableText => [
    title,
    summary,
    topic,
    creatorHandle,
    caption,
    transcript,
    visualNotes,
    personalNote,
    ...onScreenText,
    ...tags,
    for (final k in keyPoints) k.text,
    for (final a in actions) a.text,
  ].whereType<String>().join('\n').toLowerCase();

  Note copyWith({
    DateTime? updatedAt,
    NoteStatus? status,
    String? topic,
    bool? starred,
    List<ActionItem>? actions,
    String? personalNote,
  }) => Note(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    status: status ?? this.status,
    sourceKind: sourceKind,
    sourceUrl: sourceUrl,
    remoteId: remoteId,
    creatorHandle: creatorHandle,
    caption: caption,
    mediaPaths: mediaPaths,
    transcript: transcript,
    onScreenText: onScreenText,
    visualNotes: visualNotes,
    language: language,
    title: title,
    summary: summary,
    keyPoints: keyPoints,
    actions: actions ?? this.actions,
    topic: topic ?? this.topic,
    topicChosen: topicChosen,
    tags: tags,
    personalNote: personalNote ?? this.personalNote,
    starred: starred ?? this.starred,
    lastOpenedAt: lastOpenedAt,
    openCount: openCount,
    errorMessage: errorMessage,
    highlightsRevealed: highlightsRevealed,
  );
}
