import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config.dart';
import '../../../data/repositories/account_repository.dart';
import '../../core/theme.dart';

/// Settings (Play edition): the Google account, today's notes, and Plus.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key, required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AccountRepository>();
    final account = repo.account;
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;

    if (!repo.signedIn) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign in with Google to turn what you save into notes. A few notes a day are free.',
              style: text.bodyMedium,
            ),
            const SizedBox(height: Space.l),
            FilledButton(
              onPressed: () => signInWithGoogle(context),
              child: const Text('Sign in with Google'),
            ),
          ],
        ),
      );
    }

    final plusUntil = account?.plusUntil;
    final plan = account == null
        ? ''
        : account.isPlus
        ? 'Commonplace Plus, ${account.plusNotesPerDay} notes a day'
              '${plusUntil == null ? '' : ', renews or ends ${DateFormat.yMMMd().format(plusUntil)}'}'
        : 'Free, ${account.freeNotesPerDay} notes a day';
    final left = account == null
        ? ''
        : '${account.notesLeft} of ${account.notesPerDay} notes left today.';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account?.name ?? account?.email ?? 'Signed in',
            style: text.titleMedium,
          ),
          if (account?.name != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              account!.email,
              style: text.bodyMedium!.copyWith(color: palette.inkSoft),
            ),
          ],
          if (account != null) ...[
            const SizedBox(height: Space.m),
            Text(plan, style: text.bodyMedium),
            const SizedBox(height: Space.xs),
            Text(
              left,
              style: text.bodyMedium!.copyWith(color: palette.inkSoft),
            ),
          ],
          const SizedBox(height: Space.l),
          Wrap(
            spacing: Space.m,
            runSpacing: Space.s,
            children: [
              if (account != null && !account.isPlus)
                FilledButton(
                  onPressed: () => context.push('/plus'),
                  child: const Text('Get Commonplace Plus'),
                ),
              if (account != null && account.isPlus)
                OutlinedButton(
                  onPressed: openPlaySubscriptions,
                  child: const Text('Manage subscription'),
                ),
              TextButton(
                onPressed: () => context.read<AccountRepository>().signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          TextButton(
            onPressed: () => _confirmDelete(context),
            // Flush with the text above, like the welcome screen's "Skip".
            style: TextButton.styleFrom(
              foregroundColor: palette.error,
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 48),
              alignment: Alignment.centerLeft,
            ),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final repo = context.read<AccountRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'Commonplace deletes your account and everything its server keeps about you. '
          'The notes on this phone stay. '
          'A Commonplace Plus subscription is not cancelled by this; cancel it in Google Play.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    try {
      await repo.deleteAccount();
      messenger.showSnackBar(
        const SnackBar(content: Text('Account deleted.'), persist: false),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't delete the account. Check the connection and try again.",
          ),
          persist: false,
        ),
      );
    }
  }
}

/// Shows Google's account picker; tells the person if it didn't work.
Future<bool> signInWithGoogle(BuildContext context) async {
  final repo = context.read<AccountRepository>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    return await repo.signIn();
  } on Object catch (e) {
    debugPrint('Sign-in failed: $e');
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          "Couldn't sign in with Google. Check the connection and try again.",
        ),
        persist: false,
      ),
    );
    return false;
  }
}

/// Google Play's own page for managing (and cancelling) the subscription.
Future<void> openPlaySubscriptions() => launchUrl(
  Uri.https('play.google.com', '/store/account/subscriptions', {
    'sku': PlayConfig.plusProductId,
    'package': PlayConfig.packageName,
  }),
  mode: LaunchMode.externalApplication,
);
