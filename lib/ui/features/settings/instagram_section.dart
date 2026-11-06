import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/instagram_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/revisit.dart';
import '../../../domain/use_cases/saved_sync.dart';
import '../../core/theme.dart';

/// Settings: the Instagram sign-in and the Saved-list check.
class InstagramSection extends StatelessWidget {
  const InstagramSection({super.key, required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) {
    final instagram = context.watch<InstagramRepository>();
    final sync = context.watch<SavedSync>();
    final settings = context.watch<SettingsRepository>();
    final fromSaves = settings.notesFromSaves;
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;

    final checked = instagram.lastCheckedAt;
    final status = !fromSaves
        ? 'Only reels you share to Commonplace become notes. Your Saved '
              "list isn't read."
        : sync.isRunning
        ? 'Looking at your saves...'
        : sync.lastFailure?.message ??
              (checked == null
                  ? 'New saves turn into notes.'
                  : 'Last looked ${_since(checked, DateTime.now())}.');

    final Widget body;
    if (instagram.isConnected) {
      final name = instagram.username;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name == null ? 'Connected' : 'Connected as @$name',
            style: text.titleMedium,
          ),
          const SizedBox(height: Space.m),
          Text('Make notes from', style: text.titleSmall),
          const SizedBox(height: Space.s),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Just share')),
              ButtonSegment(value: true, label: Text('Automatic by save')),
            ],
            selected: {fromSaves},
            onSelectionChanged: (choice) async {
              final on = choice.single;
              if (on == fromSaves) return;
              final sync = context.read<SavedSync>();
              if (on) await sync.turnedOn();
              await settings.setNotesFromSaves(on);
              sync.modeChanged();
              if (on) await sync.check(force: true);
            },
          ),
          const SizedBox(height: Space.s),
          Text(
            status,
            style: text.bodyMedium!.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: Space.l),
          Wrap(
            spacing: Space.m,
            runSpacing: Space.s,
            children: [
              if (fromSaves)
                OutlinedButton(
                  onPressed: sync.isRunning
                      ? null
                      : () => context.read<SavedSync>().check(force: true),
                  child: const Text('Look now'),
                ),
              TextButton(
                onPressed: () => _confirmDisconnect(context),
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ],
      );
    } else if (instagram.needsSignIn) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Signed out by Instagram', style: text.titleMedium),
          const SizedBox(height: Space.xs),
          Text(
            "New saves aren't coming in until you sign in again.",
            style: text.bodyMedium!.copyWith(color: palette.inkSoft),
          ),
          const SizedBox(height: Space.l),
          Wrap(
            spacing: Space.m,
            runSpacing: Space.s,
            children: [
              FilledButton(
                onPressed: () => context.push('/connect-instagram'),
                child: const Text('Sign in again'),
              ),
              TextButton(
                onPressed: () => _confirmDisconnect(context),
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sign in once, and every reel you save on Instagram turns into a note here. Sharing a reel to Commonplace works too.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: Space.l),
          FilledButton(
            onPressed: () => context.push('/connect-instagram'),
            child: const Text('Connect Instagram'),
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          const SizedBox(height: Space.l),
          Text(
            'Instagram has no official way for apps to read saved posts, so Commonplace reads your Saved list the way instagram.com does, with your sign-in. It looks only when you open the app, and the sign-in stays on this phone.',
            style: text.bodySmall!.copyWith(color: palette.inkSoft),
          ),
        ],
      ),
    );
  }

  static String _since(DateTime then, DateTime now) {
    final d = now.difference(then);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes == 1) return 'a minute ago';
    if (d.inHours < 1) return '${d.inMinutes} minutes ago';
    if (d.inHours == 1) return 'an hour ago';
    if (d.inHours < 24) return '${d.inHours} hours ago';
    return relativeAge(then, now);
  }

  Future<void> _confirmDisconnect(BuildContext context) async {
    final instagram = context.read<InstagramRepository>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Instagram?'),
        content: const Text(
          'Commonplace signs out of Instagram on this phone and stops looking at your saves. Your notes stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (ok ?? false) await instagram.disconnect();
  }
}
