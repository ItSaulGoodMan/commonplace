/// Prompts and JSON schemas for the AI.
///
/// A note from a video or images is made in **one** request ([read]): the
/// model watches once and returns both what it read (transcript, on-screen
/// text, visuals) and the note. One request instead of two halves what a
/// note costs against Gemini's free daily request limit.
///
/// What it read is stored, so writing the note again (say, in another
/// language) is a cheap text-only request ([distill]) with no re-upload.
/// [extract] is the read-only half, kept for the server's older endpoint.
abstract final class Prompts {
  static const _readFields = '''
- transcript: everything spoken, verbatim, in the original language. Drop filler sounds (um, uh). Use an empty string if nobody speaks or there is only music.
- on_screen_text: each distinct piece of text that appears on screen or in the images, in order of appearance, without duplicates. Skip watermarks, usernames burned in by the app, and UI chrome.
- visual_notes: one or two sentences about what is shown, only if it carries information the words don't (a demo, a recipe step, a chart, a place). Otherwise an empty string.
- language: BCP-47 code of the main language, for example "en" or "sr".
- creator_handle: the creator's @handle without the @ if it is visible or spoken, otherwise an empty string.''';

  static const _noteFields = '''
- title: specific and plain, at most 60 characters, sentence case, no emoji, no clickbait, no trailing period.
- summary: one or two sentences on what this teaches and why it's useful.
- key_points: 2 to 6 standalone takeaways, one sentence each, most important first. For each one, "highlight" is the 2 to 6 word phrase from that same sentence that carries the idea, copied exactly, character for character.
- actions: 0 to 4 concrete things to try, phrased as short imperatives. Use an empty list if the reel isn't actionable.
- topic: the one broad shelf it belongs on, 1 or 2 words in Title Case, for example SEO, Cooking, Fitness, Career, Money, Productivity, Design, Travel.
- tags: 1 to 4 lowercase specifics.''';

  static const extract = '''
You are transcribing a short social media video or post (usually an Instagram reel) for someone's personal notes.

Return:
$_readFields''';

  /// One request: read the media and write the note. [language] is a
  /// human language name, or null for "same as the video".
  static String read({String? language}) {
    final lang = language ?? 'the same language as the video';
    return '''
You are making a personal note from a short social media video or post (usually an Instagram reel).

First, read everything in it:
$_readFields

Then turn it into a note its owner will actually come back to. Write like a sharp friend summarising it, not like marketing copy. Keep the creator's concrete specifics: numbers, names, tools, steps, quantities. Do not invent anything that isn't in it. If there is little in it, the note is short.
$_noteFields

Keep transcript and on_screen_text in their original language. Write title, summary, key_points, actions, topic and tags in $lang.''';
  }

  /// Added to [read] when the owner shared words along with the media.
  static String readCaption(String caption) =>
      '\n\nThe owner added this caption or note when saving it:\n$caption';

  static const extractSchema = <String, Object?>{
    'type': 'object',
    'properties': {
      'transcript': {'type': 'string'},
      'on_screen_text': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'visual_notes': {'type': 'string'},
      'language': {'type': 'string'},
      'creator_handle': {'type': 'string'},
    },
    'required': [
      'transcript',
      'on_screen_text',
      'visual_notes',
      'language',
      'creator_handle',
    ],
  };

  /// [language] is a human language name ("English") or null for "same as the material".
  static String distill({required String material, String? language}) {
    final lang = language ?? 'the same language as the material';
    return '''
Turn this saved reel into a note its owner will actually come back to.

Write like a sharp friend summarising it, not like marketing copy. Keep the creator's concrete specifics: numbers, names, tools, steps, quantities. Do not invent anything that isn't in the material. If the material is thin, the note is short.

Fields:
$_noteFields

Write every field in $lang.

Material:
$material''';
  }

  static const distillSchema = <String, Object?>{
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      'summary': {'type': 'string'},
      'key_points': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'text': {'type': 'string'},
            'highlight': {'type': 'string'},
          },
          'required': ['text', 'highlight'],
        },
      },
      'actions': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'topic': {'type': 'string'},
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['title', 'summary', 'key_points', 'actions', 'topic', 'tags'],
  };

  /// Schema for [read]: everything [extractSchema] and [distillSchema] ask.
  static final readSchema = <String, Object?>{
    'type': 'object',
    'properties': {
      ...(extractSchema['properties']! as Map<String, Object?>),
      ...(distillSchema['properties']! as Map<String, Object?>),
    },
    'required': [
      ...(extractSchema['required']! as List<Object?>),
      ...(distillSchema['required']! as List<Object?>),
    ],
  };

  /// Everything known about a reel, laid out for the distill step.
  static String material({
    String? transcript,
    List<String> onScreenText = const [],
    String? visualNotes,
    String? caption,
    String? creatorHandle,
  }) {
    final parts = <String>[];
    if (_has(creatorHandle)) parts.add('Creator: @$creatorHandle');
    if (_has(transcript)) parts.add('Spoken:\n${transcript!.trim()}');
    if (onScreenText.isNotEmpty) {
      parts.add('Text on screen:\n${onScreenText.join('\n')}');
    }
    if (_has(visualNotes)) parts.add('What the video shows:\n$visualNotes');
    if (_has(caption)) parts.add('Caption or notes from the owner:\n$caption');
    return parts.join('\n\n');
  }

  static bool _has(String? s) => s != null && s.trim().isNotEmpty;
}
