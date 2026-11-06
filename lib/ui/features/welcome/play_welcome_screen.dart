import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/account_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets/highlighted_text.dart';
import '../settings/account_section.dart';

/// First run of the Play edition: what it does, and Sign in with Google.
class PlayWelcomeScreen extends StatelessWidget {
  const PlayWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final gutter = Space.gutter(MediaQuery.sizeOf(context).width);
    final settings = context.watch<SettingsRepository>();
    final repo = context.watch<AccountRepository>();
    final account = repo.account;

    Future<void> finish() async {
      final router = GoRouter.of(context);
      await settings.setWelcomeDone();
      router.go('/');
    }

    Widget step(int n, String title, String body, [Widget? child]) => Padding(
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
                const SizedBox(height: Space.xs),
                Text(
                  body,
                  style: text.bodyMedium!.copyWith(color: palette.inkSoft),
                ),
                if (child != null) ...[const SizedBox(height: Space.l), child],
              ],
            ),
          ),
        ],
      ),
    );

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
                  'Sign in with Google',
                  account == null
                      ? 'So your notes are yours. A few notes a day are free, and Commonplace Plus makes more.'
                      : 'You get ${account.freeNotesPerDay} notes a day for free, and ${account.plusNotesPerDay} with Commonplace Plus.',
                  repo.signedIn
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
                                'Signed in as ${account?.email ?? 'you'}',
                                style: text.bodyLarge,
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton(
                            onPressed: () => signInWithGoogle(context),
                            child: const Text('Sign in with Google'),
                          ),
                        ),
                ),
                step(
                  2,
                  'Save the reel as a video',
                  'In Instagram, tap Share on a reel, then Download. Share that video to Commonplace, or pick it with Add.',
                ),
                step(
                  3,
                  'Read the note',
                  'Gemini reads what is said and what is written on screen. You get a title, the key points and things to try, sorted onto shelves.',
                ),
                Text(
                  "You need to be 18 or older to use Commonplace. To make a note, the video is sent to Google's Gemini AI, and Google may review it to improve its products, so don't add anything private.",
                  style: text.bodySmall!.copyWith(color: palette.inkSoft),
                ),
                const SizedBox(height: Space.xl),
                Align(
                  alignment: Alignment.centerLeft,
                  child: repo.signedIn
                      ? FilledButton(
                          onPressed: finish,
                          child: const Text('Start'),
                        )
                      : TextButton(
                          onPressed: finish,
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
