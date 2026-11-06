import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/ai.dart';
import '../../domain/use_cases/capture.dart';

/// Tells the owner what happened to the thing they just shared or added.
///
/// Takes the messenger and router rather than a context, so callers grab them
/// before any `await` and never touch a stale context.
void announceCapture(
  ScaffoldMessengerState messenger,
  GoRouter router,
  CaptureResult result, {
  required AiFailure? blocked,
}) {
  final id = result.noteId;
  final message = switch (result.outcome) {
    CaptureOutcome.queued => switch (blocked) {
      AiFailure.missingKey =>
        'Saved. Add your Gemini key in Settings to make the note.',
      AiFailure.signedOut => 'Saved. Sign in with Google to make the note.',
      AiFailure.dailyLimit ||
      AiFailure.sharedLimit => "Saved. It's made tomorrow.",
      _ => 'Saved. Making the note now.',
    },
    CaptureOutcome.waitingForVideo =>
      'Link saved. Add the video to make the note.',
    CaptureOutcome.alreadySaved => 'You saved this one already.',
    CaptureOutcome.attachedToRecent =>
      'Video added to the reel you just saved.',
    CaptureOutcome.nothing => 'There was nothing to save in that share.',
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        // A confirmation, not a question: let it go away by itself.
        persist: false,
        action: id == null
            ? null
            : SnackBarAction(
                label: 'Open',
                onPressed: () => router.push('/note/$id'),
              ),
      ),
    );
}
