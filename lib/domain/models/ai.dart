import 'package:flutter/foundation.dart';

/// Why the AI couldn't make a note, phrased for the person using the app.
enum AiFailure {
  // Bring-your-own-key (personal edition).
  missingKey('Add your free Gemini key in Settings to turn this into a note.'),
  invalidKey('Gemini rejected the API key. Check it in Settings.'),
  rateLimited(
    'Gemini says the free limit is used up for now. Try again in a minute, or tomorrow if it keeps happening.',
  ),
  modelUnavailable(
    "That Gemini model isn't available to this key. Pick another one in Settings.",
  ),
  unavailableHere(
    "Gemini's free tier isn't available for this account or country.",
  ),

  // Commonplace account (Play edition).
  signedOut('Sign in with Google to turn this into a note.'),
  dailyLimit("You've made today's notes. This one is made tomorrow."),
  sharedLimit(
    "Commonplace has used today's free AI time. This one is made tomorrow.",
  ),
  notConfigured("This build of Commonplace isn't connected to its server."),

  // Either.
  overloaded('Gemini is busy right now. Try again in a minute.'),
  blocked('Gemini declined to read this one.'),
  tooLarge('This video is too large for Gemini. Try a shorter clip.'),
  network("Couldn't reach Gemini. Check the connection and try again."),
  timedOut(
    "Gemini got the reel but didn't answer in time. Try again in a few minutes.",
  ),
  badResponse('Gemini sent back something unreadable. Try again.');

  const AiFailure(this.message);

  final String message;

  /// Failures that are worth retrying later without the owner doing anything.
  bool get isTransient =>
      this == rateLimited || this == overloaded || this == network;

  /// Not the note's fault: it waits in the queue until this clears.
  bool get waits =>
      this == missingKey ||
      this == signedOut ||
      this == dailyLimit ||
      this == sharedLimit ||
      this == notConfigured;
}

/// The owner tapped Stop while a note was being made.
class WorkStopped implements Exception {
  const WorkStopped();

  static const message = 'Stopped. Tap Try again to make this note.';

  @override
  String toString() => 'WorkStopped';
}

class AiException implements Exception {
  AiException(this.failure, [this.detail, this.message]);

  final AiFailure failure;

  /// Raw detail for logs. Never contains a key or a token.
  final String? detail;

  /// A message from the server that says more than [failure] does.
  final String? message;

  @override
  String toString() =>
      'AiException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// What the AI read out of a video or images.
@immutable
class Extraction {
  const Extraction(this.fields, {this.ticket});

  /// Splits a one-request answer into what was read and the note.
  static (Extraction, Map<String, Object?>) split(Map<String, Object?> answer) {
    const readKeys = {
      'transcript',
      'on_screen_text',
      'visual_notes',
      'language',
      'creator_handle',
    };
    final read = <String, Object?>{};
    final note = <String, Object?>{};
    for (final e in answer.entries) {
      (readKeys.contains(e.key) ? read : note)[e.key] = e.value;
    }
    return (Extraction(read), note);
  }

  /// `transcript`, `on_screen_text`, `visual_notes`, `language`,
  /// `creator_handle`, as in [Prompts.extractSchema].
  final Map<String, Object?> fields;

  /// Server proof that this note was already counted (Play edition).
  final String? ticket;
}

/// What one Gemini answer used, by Gemini's own count (`usageMetadata`).
@immutable
class AiUsage {
  const AiUsage({
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
  });

  /// The model that answered, e.g. `gemini-3.8-flash`.
  final String model;

  /// Everything sent: the video, images and the prompt.
  final int inputTokens;

  /// The answer plus Gemini's thinking; both are billed as output.
  final int outputTokens;
}

/// What the AI has cost, added up: for one note, or for a month.
@immutable
class AiSpend {
  const AiSpend({
    this.calls = 0,
    this.notes = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.microUsd = 0,
    this.unpriced = 0,
    this.models = const [],
  });

  static const none = AiSpend();

  final int calls;

  /// How many different notes the calls were for.
  final int notes;
  final int inputTokens;
  final int outputTokens;

  /// At Google's paid price, in millionths of a dollar.
  final int microUsd;

  /// Calls to a model whose price isn't known here (left out of [microUsd]).
  final int unpriced;

  /// The models that answered, most recent first.
  final List<String> models;

  bool get isEmpty => calls == 0;
}

/// What a read is doing, for the screen.
enum ReadStep {
  /// The video (or images) going up; [ReadUpdate.sent] of [ReadUpdate.total].
  sending,

  /// Uploaded; Gemini is getting the video ready to watch.
  preparing,

  /// Everything is there; waiting for Gemini to watch it and write.
  watching,
}

@immutable
class ReadUpdate {
  const ReadUpdate.sending(this.sent, this.total) : step = ReadStep.sending;
  const ReadUpdate.preparing() : step = ReadStep.preparing, sent = 0, total = 0;
  const ReadUpdate.watching() : step = ReadStep.watching, sent = 0, total = 0;

  final ReadStep step;
  final int sent;
  final int total;

  @override
  bool operator ==(Object other) =>
      other is ReadUpdate &&
      other.step == step &&
      other.sent == sent &&
      other.total == total;

  @override
  int get hashCode => Object.hash(step, sent, total);
}

/// Something that turns media into notes: Gemini with the owner's own key,
/// or the Commonplace server.
abstract interface class NoteAi {
  /// Why notes can't be made right now, or null when they can.
  AiFailure? get blocked;

  /// One request: watches [mediaPaths] once and returns what it read and
  /// the note (shaped like [Prompts.distillSchema]). [onUpdate] hears how
  /// far it has got.
  ///
  /// [onUsage] hears the tokens each answer used, when they are known
  /// (with the owner's own key; the server keeps its own count).
  Future<(Extraction, Map<String, Object?>)> read(
    List<String> mediaPaths, {
    String? caption,
    String? language,
    void Function(ReadUpdate update)? onUpdate,
    void Function(AiUsage usage)? onUsage,
    Future<void>? cancel,
  });

  /// Reads speech, on-screen text and visuals out of [mediaPaths].
  Future<Extraction> extract(
    List<String> mediaPaths, {
    void Function(AiUsage usage)? onUsage,
  });

  /// Writes the note from [material]; JSON shaped like [Prompts.distillSchema].
  Future<Map<String, Object?>> write({
    required String material,
    String? language,
    Extraction? from,
    bool rewrite = false,
    void Function(AiUsage usage)? onUsage,
  });
}
