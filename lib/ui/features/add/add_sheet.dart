import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../config.dart';
import '../../../data/repositories/instagram_repository.dart';
import '../../../domain/models/ai.dart';
import '../../../domain/shared_link.dart';
import '../../../domain/use_cases/capture.dart';
import '../../core/media_picker.dart';
import '../../core/theme.dart';
import '../../core/capture_feedback.dart';

/// The "Add" menu: video, screenshots, a link, or text.
Future<void> showAddSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => const _AddSheet(),
);

class _AddSheet extends StatelessWidget {
  const _AddSheet();

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final instagramConnected = context.read<InstagramRepository>().isConnected;
    final personal = context.read<Edition>() == Edition.personal;

    Future<void> run(Future<Incoming?> Function() collect) async {
      final capture = context.read<Capture>();
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      final blocked = context.read<NoteAi>().blocked;
      final incoming = await collect();
      if (incoming == null || incoming.isEmpty) return;
      final result = await capture.handle(incoming);
      navigator.pop();
      announceCapture(messenger, router, result, blocked: blocked);
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, Space.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, Space.s),
              child: Text('Add to Commonplace', style: text.headlineSmall),
            ),
            _Option(
              icon: Icons.movie_outlined,
              title: 'Choose a video',
              subtitle: 'A reel you downloaded or screen-recorded',
              onTap: () => run(() async {
                final paths = await context.read<MediaPicker>().video();
                return Incoming(filePaths: paths);
              }),
            ),
            _Option(
              icon: Icons.photo_library_outlined,
              title: 'Choose screenshots',
              subtitle: 'Photos of a post or carousel',
              onTap: () => run(() async {
                final paths = await context.read<MediaPicker>().images();
                return Incoming(filePaths: paths);
              }),
            ),
            _Option(
              icon: Icons.link_rounded,
              title: 'Paste a link',
              subtitle: instagramConnected
                  ? 'Commonplace gets the reel from your Instagram'
                  : 'Saves the reel now, the video can follow',
              onTap: () => run(() async {
                final value = await _askForText(
                  context,
                  title: 'Paste a link',
                  hint: 'https://www.instagram.com/reel/...',
                  prefillFromClipboardLink: true,
                  minLines: 1,
                  action: 'Save link',
                );
                return value == null ? null : Incoming(texts: [value]);
              }),
            ),
            _Option(
              icon: Icons.notes_rounded,
              title: 'Write or paste text',
              subtitle: 'A caption, a tip, anything worth keeping',
              onTap: () => run(() async {
                final value = await _askForText(
                  context,
                  title: 'Write or paste text',
                  hint: 'Paste a caption or jot down the tip',
                  minLines: 5,
                  action: 'Make a note',
                );
                return value == null ? null : Incoming(texts: [value]);
              }),
            ),
            if (!instagramConnected) ...[
              const SizedBox(height: Space.s),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  personal
                      ? "To get a reel's video, tap Share in Instagram, then Download. It lands at the top of your gallery. Or connect your Instagram in Settings and skip this."
                      : "To get a reel's video, tap Share in Instagram, then Download. It lands at the top of your gallery.",
                  style: text.bodySmall!.copyWith(color: palette.inkSoft),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    onTap: onTap,
  );
}

Future<String?> _askForText(
  BuildContext context, {
  required String title,
  required String hint,
  required String action,
  int minLines = 1,
  bool prefillFromClipboardLink = false,
}) async {
  var initial = '';
  if (prefillFromClipboardLink) {
    final clip = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (SharedLink.find(clip) != null) initial = clip.trim();
  }
  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    builder: (context) => _TextDialog(
      title: title,
      hint: hint,
      action: action,
      minLines: minLines,
      initial: initial,
    ),
  );
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.hint,
    required this.action,
    required this.minLines,
    required this.initial,
  });

  final String title;
  final String hint;
  final String action;
  final int minLines;
  final String initial;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      minLines: widget.minLines,
      maxLines: widget.minLines == 1 ? 1 : 12,
      keyboardType: widget.minLines == 1
          ? TextInputType.url
          : TextInputType.multiline,
      decoration: InputDecoration(hintText: widget.hint),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => FilledButton(
          onPressed: _controller.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.action),
        ),
      ),
    ],
  );
}
