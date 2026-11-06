import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/instagram_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/use_cases/note_processor.dart';
import '../../core/theme.dart';
import '../../core/widgets/highlighted_text.dart';
import '../settings/gemini_key_field.dart';

/// First run: what this is, the Instagram sign-in, and the free Gemini key.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final gutter = Space.gutter(MediaQuery.sizeOf(context).width);
    final settings = context.watch<SettingsRepository>();
    final instagram = context.watch<InstagramRepository>();

    Future<void> finish() async {
      final router = GoRouter.of(context);
      await settings.setWelcomeDone();
      router.go('/');
    }

    Widget step(int n, String title, String? body, [Widget? child]) => Padding(
      padding: const EdgeInsets.only(bottom: Space.xxl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '$n',
              style: TypeScale.casual(
                26,
                weight: 720,
              ).copyWith(color: palette.ink),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium),
                if (body != null) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    body,
                    style: text.bodyMedium!.copyWith(color: palette.inkSoft),
                  ),
                ],
                if (child != null) ...[const SizedBox(height: Space.l), child],
              ],
            ),
          ),
        ],
      ),
    );

    final connected = instagram.isConnected;
    final name = instagram.username;

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Space.measure + 64),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                gutter,
                Space.huge,
                gutter,
                Space.huge,
              ),
              children: [
                Text('Commonplace', style: text.displaySmall),
                const SizedBox(height: Space.l),
                HighlightedText(
                  'The reels you save, turned into notes you actually reread.',
                  highlight: 'notes you actually reread',
                  style: TypeScale.casual(
                    22,
                    weight: 560,
                    height: 1.35,
                  ).copyWith(color: palette.ink),
                ),
                const SizedBox(height: Space.huge),
                step(
                  1,
                  'Connect Instagram',
                  'Sign in once. Every reel you save after that turns into a note here, with nothing to download.',
                  connected
                      ? Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: palette.ink,
                              size: 20,
                            ),
                            const SizedBox(width: Space.s),
                            Expanded(
                              child: Text(
                                name == null
                                    ? 'Connected'
                                    : 'Connected as @$name',
                                style: text.bodyLarge,
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton(
                            onPressed: () => context.push('/connect-instagram'),
                            child: const Text('Connect Instagram'),
                          ),
                        ),
                ),
                step(
                  2,
                  'Add your free Gemini key',
                  // The key field explains Gemini itself.
                  null,
                  GeminiKeyField(
                    onSaved: () {
                      context.read<NoteProcessor>().kick();
                      if (connected) finish();
                    },
                  ),
                ),
                step(
                  3,
                  'Save reels as usual',
                  'Each time you open Commonplace, new saves become notes: a title, the key points and things to try, sorted onto shelves. To keep a single reel without saving it, tap Share in Instagram, then Commonplace.',
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: connected && settings.hasGeminiKey
                      ? FilledButton(
                          onPressed: finish,
                          child: const Text('Start'),
                        )
                      : TextButton(
                          onPressed: finish,
                          // Sit flush with the text column above.
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: const Size(48, 48),
                          ),
                          child: const Text('Skip for now'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
