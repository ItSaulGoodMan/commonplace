import '../../domain/models/ai.dart';
import '../../domain/use_cases/note_processor.dart';

/// What a note that is being made is doing right now, in words: the home
/// list shows [short], the note itself [headline] and [explanation].
class WorkStatus {
  const WorkStatus({
    required this.stage,
    required this.update,
    required this.images,
    this.retryReason,
    this.shrinkProgress,
  });

  final ProcessingStage? stage;
  final ReadUpdate? update;

  /// A carousel of pictures rather than a video.
  final bool images;

  /// Why this is the second try, if it is.
  final String? retryReason;

  /// How far making the video smaller has got, 0 to 1.
  final double? shrinkProgress;

  String get _shrunk =>
      shrinkProgress == null ? '' : ': ${(shrinkProgress! * 100).round()}%';

  String get _what => images ? 'the images' : 'the video';

  /// How much has been made smaller or sent, 0 to 1.
  double? get fraction => switch (update) {
    _ when stage == ProcessingStage.shrinking => shrinkProgress,
    ReadUpdate(step: ReadStep.sending, :final sent, :final total)
        when total > 0 =>
      (sent / total).clamp(0.0, 1.0),
    _ => null,
  };

  String get _sent => switch (update) {
    ReadUpdate(:final sent, :final total) => '${_mb(sent)} of ${_mb(total)} MB',
    null => '',
  };

  String get short => switch ((stage, update?.step)) {
    (ProcessingStage.fetching, _) => 'Getting it from Instagram...',
    (ProcessingStage.shrinking, _) => 'Making the video smaller$_shrunk',
    (_, ReadStep.sending) => 'Sending $_what to Gemini: $_sent',
    (_, ReadStep.preparing) => 'Gemini is getting $_what ready...',
    (_, ReadStep.watching) =>
      images ? 'Gemini is reading the images...' : 'Gemini is watching it...',
    _ => 'Getting $_what ready to send...',
  };

  String get headline => switch ((stage, update?.step)) {
    (ProcessingStage.fetching, _) => 'Getting it from Instagram',
    (ProcessingStage.shrinking, _) => 'Making the video smaller$_shrunk',
    (_, ReadStep.sending) => 'Sending $_what to Gemini',
    (_, ReadStep.preparing) => 'Gemini is getting $_what ready',
    (_, ReadStep.watching) =>
      images ? 'Gemini is reading the images' : 'Gemini is watching it',
    _ => 'Getting $_what ready to send',
  };

  String get explanation => switch ((stage, update?.step)) {
    (ProcessingStage.shrinking, _) =>
      'Gemini looks at one frame a second, at low resolution, so a smaller '
          'copy reads the same and sends two or three times faster. You can '
          'turn this off in Settings, Storage.',
    (ProcessingStage.fetching, _) =>
      'Downloading the post from your Instagram. Then it goes to Gemini. '
          'You can leave the app; it keeps going.',
    (_, ReadStep.sending) =>
      '$_sent sent. On mobile data this can take a few minutes. It only '
          'gives up if nothing moves for a minute. You can leave the app; '
          'it keeps going.',
    (_, ReadStep.preparing) =>
      'Uploaded. Gemini processes a video before it can watch it, which '
          'takes a few seconds to a minute.',
    (_, ReadStep.watching) =>
      'Everything is sent. Gemini usually answers in under a minute. If '
          'there is no answer in 3 minutes, Commonplace stops waiting and '
          'says so here and in Settings, Status.',
    _ =>
      'Packing $_what to send. This takes a moment. You can leave the app; '
          'it keeps going.',
  };

  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}
