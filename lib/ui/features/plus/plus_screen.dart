import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/account_repository.dart';
import '../../../data/services/billing.dart';
import '../../core/theme.dart';
import '../../core/widgets/highlighted_text.dart';
import '../settings/account_section.dart';

/// Commonplace Plus: what it gives, its price from Google Play, and buying.
class PlusScreen extends StatefulWidget {
  const PlusScreen({super.key});

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  late final Future<PlusOffer?> _offer = context
      .read<AccountRepository>()
      .plusOffer();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AccountRepository>();
    final account = repo.account;
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final gutter = Space.gutter(MediaQuery.sizeOf(context).width);
    final free = account?.freeNotesPerDay ?? 3;
    final plus = account?.plusNotesPerDay ?? 25;

    Widget point(String body) => Padding(
      padding: const EdgeInsets.only(bottom: Space.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: Space.m),
            child: Icon(Icons.check_rounded, size: 20, color: palette.ink),
          ),
          Expanded(child: Text(body, style: text.bodyLarge)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Commonplace Plus')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Space.measure + 64),
          child: ListView(
            padding: EdgeInsets.fromLTRB(gutter, Space.xl, gutter, Space.huge),
            children: [
              HighlightedText(
                'Make $plus notes a day instead of $free.',
                highlight: '$plus notes a day',
                style: TypeScale.casual(
                  26,
                  weight: 680,
                  height: 1.25,
                ).copyWith(color: palette.ink),
              ),
              const SizedBox(height: Space.xl),
              point(
                'Everything you save that day becomes a note, not just the first $free.',
              ),
              point(
                'It pays for the AI that reads your reels, so Commonplace can keep going.',
              ),
              point(
                'Cancel any time in Google Play. Your notes stay either way.',
              ),
              const SizedBox(height: Space.xl),
              if (!repo.signedIn) ...[
                Text(
                  'Sign in first, so Plus is tied to your account.',
                  style: text.bodyLarge,
                ),
                const SizedBox(height: Space.l),
                FilledButton(
                  onPressed: () => signInWithGoogle(context),
                  child: const Text('Sign in with Google'),
                ),
              ] else if (account?.isPlus ?? false) ...[
                Text(
                  account!.plusUntil == null
                      ? 'You have Commonplace Plus.'
                      : 'You have Commonplace Plus. It renews or ends on ${DateFormat.yMMMd().format(account.plusUntil!)}.',
                  style: text.bodyLarge,
                ),
                const SizedBox(height: Space.l),
                OutlinedButton(
                  onPressed: openPlaySubscriptions,
                  child: const Text('Manage subscription'),
                ),
              ] else
                FutureBuilder<PlusOffer?>(
                  future: _offer,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(Space.l),
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      );
                    }
                    final offer = snapshot.data;
                    if (offer == null) {
                      return Text(
                        "Google Play isn't available on this phone, so Plus can't be bought here.",
                        style: text.bodyLarge,
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton(
                          onPressed: repo.verifyingPurchase
                              ? null
                              : () => repo.buyPlus(offer),
                          child: Text('Subscribe for ${offer.price} a month'),
                        ),
                        const SizedBox(height: Space.s),
                        TextButton(
                          onPressed: repo.verifyingPurchase
                              ? null
                              : repo.restorePlus,
                          child: const Text('I already have Plus'),
                        ),
                      ],
                    );
                  },
                ),
              if (repo.verifyingPurchase) ...[
                const SizedBox(height: Space.l),
                Row(
                  children: [
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: Space.m),
                    Text('Confirming the purchase...', style: text.bodyMedium),
                  ],
                ),
              ],
              if (repo.purchaseProblem case final problem?) ...[
                const SizedBox(height: Space.l),
                Text(
                  problem,
                  style: text.bodyMedium!.copyWith(color: palette.error),
                ),
              ],
              const SizedBox(height: Space.xl),
              Text(
                'The subscription renews every month until you cancel it. Google Play handles the payment.',
                style: text.bodySmall!.copyWith(color: palette.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
