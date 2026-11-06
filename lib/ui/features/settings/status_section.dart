import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/repositories/notes_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/models/ai.dart';
import '../../core/ai_cost.dart';
import '../../core/theme.dart';

/// Settings: when a note was last made, and exactly what last went wrong.
class StatusSection extends StatelessWidget {
  const StatusSection({super.key, required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final success = settings.lastSuccessAt;
    final problem = settings.lastProblem;
    String when(DateTime t) => DateFormat('d MMM, HH:mm').format(t);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            success == null
                ? 'No note has been made yet.'
                : 'Last note made ${when(success)}.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: Space.m),
          if (problem == null)
            Text(
              'Nothing has gone wrong so far.',
              style: text.bodyMedium!.copyWith(color: palette.inkSoft),
            )
          else ...[
            Text(
              success != null && success.isAfter(problem.at)
                  ? 'Last problem, ${when(problem.at)} (a note was made since):'
                  : 'Last problem, ${when(problem.at)}:',
              style: text.bodySmall!.copyWith(color: palette.inkSoft),
            ),
            const SizedBox(height: Space.xs),
            Text(
              problem.message,
              style: text.bodyMedium!.copyWith(color: palette.error),
            ),
            if (problem.detail case final detail?
                when detail.trim().isNotEmpty) ...[
              const SizedBox(height: Space.xs),
              SelectableText(
                detail.trim(),
                style: text.bodySmall!.copyWith(color: palette.inkSoft),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text:
                            '${when(problem.at)}\n${problem.message}\n${detail.trim()}',
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied.'), persist: false),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy details'),
                ),
              ),
            ],
          ],
          const _MonthSpend(),
        ],
      ),
    );
  }
}

/// This month's Gemini use with the owner's key, and what it would cost.
class _MonthSpend extends StatefulWidget {
  const _MonthSpend();

  @override
  State<_MonthSpend> createState() => _MonthSpendState();
}

class _MonthSpendState extends State<_MonthSpend> {
  late final Stream<AiSpend> _spend;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _spend = context.read<NotesRepository>().watchSpendSince(
      DateTime(now.year, now.month),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsRepository>();
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    return StreamBuilder<AiSpend>(
      stream: _spend,
      builder: (context, snapshot) {
        final spend = snapshot.data;
        if (spend == null || spend.isEmpty) return const SizedBox.shrink();
        final words = AiCostText(spend, usdPerEur: settings.usdPerEur);
        final notes = spend.notes == 1 ? '1 note' : '${spend.notes} notes';
        final day = DateFormat('d MMM').format(settings.usdPerEurDay);
        return Padding(
          padding: const EdgeInsets.only(top: Space.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gemini this month: $notes, ${words.usage}.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: Space.xs),
              Text(
                '${words.cost}. On a free-tier key (no billing) you pay '
                'nothing. Euros at the ECB rate of $day: '
                '1 € = ${settings.usdPerEur.toStringAsFixed(4)} \$.',
                style: text.bodySmall!.copyWith(color: palette.inkSoft),
              ),
            ],
          ),
        );
      },
    );
  }
}
