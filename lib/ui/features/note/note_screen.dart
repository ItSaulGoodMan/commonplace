import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/repositories/settings_repository.dart';
import '../../../domain/models/ai.dart';
import '../../../domain/models/note.dart';
import '../../../domain/revisit.dart';
import '../../core/ai_cost.dart';
import '../../core/media_picker.dart';
import '../../core/theme.dart';
import '../../core/widgets/elapsed.dart';
import '../../core/widgets/highlighted_text.dart';
import 'note_view_model.dart';

class NoteScreen extends StatelessWidget {
  const NoteScreen({super.key, required this.viewModel});

  final NoteViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final note = viewModel.note;
        if (!viewModel.loaded) {
          return const Scaffold(body: SizedBox.shrink());
        }
        if (note == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(
                'This note was deleted.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }
        return _NoteScaffold(viewModel: viewModel, note: note);
      },
    );
  }
}

enum _Menu { share, rewrite, instagram, copyTranscript, report, delete }

class _NoteScaffold extends StatelessWidget {
  const _NoteScaffold({required this.viewModel, required this.note});

  final NoteViewModel viewModel;
  final Note note;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = Space.gutter(width);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: viewModel.toggleStar,
            icon: Icon(
              note.starred ? Icons.star_rounded : Icons.star_outline_rounded,
            ),
            tooltip: note.starred ? 'Unstar' : 'Star',
          ),
          PopupMenuButton<_Menu>(
            tooltip: 'More',
            onSelected: (choice) => _onMenu(context, choice),
            itemBuilder: (_) => [
              if (note.isReady)
                const PopupMenuItem(
                  value: _Menu.share,
                  child: Text('Share note'),
                ),
              if (note.isReady && note.hasMaterial)
                const PopupMenuItem(
                  value: _Menu.rewrite,
                  child: Text('Write the note again'),
                ),
              if (note.sourceUrl != null)
                const PopupMenuItem(
                  value: _Menu.instagram,
                  child: Text('Open the original'),
                ),
              if (note.transcript case final t? when t.isNotEmpty)
                const PopupMenuItem(
                  value: _Menu.copyTranscript,
                  child: Text('Copy transcript'),
                ),
              // Google Play asks AI apps for a way to flag a bad result.
              if (note.isReady && viewModel.reportEmail != null)
                const PopupMenuItem(
                  value: _Menu.report,
                  child: Text('Report a problem with this note'),
                ),
              const PopupMenuItem(value: _Menu.delete, child: Text('Delete')),
            ],
          ),
          SizedBox(width: gutter - 16),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Space.measure + 64),
          child: ListView(
            padding: EdgeInsets.fromLTRB(gutter, Space.s, gutter, 96),
            children: [
              if (viewModel.rewriting)
                const Padding(
                  padding: EdgeInsets.only(bottom: Space.l),
                  child: LinearProgressIndicator(),
                ),
              _Header(note: note),
              const SizedBox(height: Space.xl),
              if (note.isReady)
                ..._readyBody(context)
              else
                _StatusPanel(note: note, viewModel: viewModel),
              const SizedBox(height: Space.xxl),
              _PersonalNote(
                viewModel: viewModel,
                initial: note.personalNote ?? '',
              ),
              if (note.transcript?.isNotEmpty == true ||
                  note.onScreenText.isNotEmpty ||
                  (note.caption?.isNotEmpty == true && note.isReady)) ...[
                const SizedBox(height: Space.xl),
                const Divider(),
                _SourceMaterial(note: note),
              ],
              if (!viewModel.spend.isEmpty) ...[
                const SizedBox(height: Space.xl),
                _AiCost(spend: viewModel.spend),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _readyBody(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    return [
      if (note.summary case final s? when s.isNotEmpty) ...[
        Text(s, style: text.bodyLarge),
        const SizedBox(height: Space.xxl),
      ],
      if (note.keyPoints.isNotEmpty) ...[
        _SectionTitle('Key points'),
        const SizedBox(height: Space.m),
        for (final (i, k) in note.keyPoints.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.l),
            child: HighlightReveal(
              key: ValueKey('reveal-${viewModel.revealGeneration}-$i'),
              animate: viewModel.animateHighlights,
              delay: Motion.highlightStagger * (i + 2),
              builder: (context, progress) => HighlightedText(
                k.text,
                highlight: k.highlight,
                progress: progress,
                style: text.bodyLarge!.copyWith(color: palette.ink),
              ),
            ),
          ),
        const SizedBox(height: Space.l),
      ],
      if (note.actions.isNotEmpty) ...[
        _SectionTitle('Things to try'),
        const SizedBox(height: Space.xs),
        for (final (i, a) in note.actions.indexed)
          _ActionRow(action: a, onChanged: () => viewModel.toggleAction(i)),
      ],
      if (note.errorMessage case final e?) ...[
        const SizedBox(height: Space.l),
        Text(e, style: text.bodySmall!.copyWith(color: palette.error)),
      ],
    ];
  }

  Future<void> _onMenu(BuildContext context, _Menu choice) async {
    final messenger = ScaffoldMessenger.of(context);
    switch (choice) {
      case _Menu.share:
        await SharePlus.instance.share(
          ShareParams(text: viewModel.asMarkdown(), subject: note.displayTitle),
        );
      case _Menu.rewrite:
        final error = await viewModel.rewrite();
        messenger.showSnackBar(
          SnackBar(content: Text(error ?? 'Note written again.')),
        );
      case _Menu.instagram:
        await _openSource(messenger, note);
      case _Menu.report:
        final email = viewModel.reportEmail!;
        final url = Uri(
          scheme: 'mailto',
          path: email,
          query: _query({
            'subject': 'Problem with a Commonplace note',
            'body':
                'What is wrong with this note?\n\n\n---\n'
                '${note.displayTitle}\n${note.summary ?? ''}',
          }),
        );
        if (!await launchUrl(url)) {
          messenger.showSnackBar(
            SnackBar(content: Text('Write to $email to report it.')),
          );
        }
      case _Menu.copyTranscript:
        await Clipboard.setData(ClipboardData(text: note.transcript ?? ''));
        messenger.showSnackBar(
          const SnackBar(content: Text('Transcript copied.')),
        );
      case _Menu.delete:
        if (!context.mounted) return;
        final router = GoRouter.of(context);
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete this note?'),
            content: const Text('It will be gone from Commonplace for good.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep it'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await viewModel.delete();
          if (router.canPop()) {
            router.pop();
          } else {
            router.go('/');
          }
          messenger.showSnackBar(
            const SnackBar(content: Text('Note deleted.')),
          );
        }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    final age = relativeAge(note.createdAt, now);
    final host = Uri.tryParse(note.sourceUrl ?? '')?.host
        .replaceFirst('www.', '');
    final source = switch ((note.creatorHandle, host)) {
      (final handle?, _) => 'From @$handle, saved $age',
      (null, final h?) when h.isNotEmpty => 'Saved $age from $h',
      _ => 'Saved $age',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          note.displayTitle,
          style: TypeScale.casual(
            30,
            weight: 700,
            height: 1.18,
          ).copyWith(color: palette.ink),
        ),
        const SizedBox(height: Space.m),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Space.s,
          runSpacing: Space.xs,
          children: [
            Text(source, style: text.bodySmall),
            if (note.isReady) _TopicButton(note: note),
          ],
        ),
        if (note.sourceUrl case final url?) _SourceLink(note: note, url: url),
      ],
    );
  }
}

/// Opens the post the note came from (in the Instagram app when it's an
/// Instagram link).
Future<void> _openSource(ScaffoldMessengerState messenger, Note note) async {
  final url = Uri.tryParse(note.sourceUrl ?? '');
  if (url != null &&
      !await launchUrl(url, mode: LaunchMode.externalApplication)) {
    messenger.showSnackBar(
      const SnackBar(content: Text("Couldn't open the link.")),
    );
  }
}

/// The link to the reel, right under the title: tap opens it, a long press
/// copies it.
class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.note, required this.url});

  final Note note;
  final String url;

  @override
  Widget build(BuildContext context) {
    final shown = url
        .replaceFirst(RegExp(r'^https?://(www\.)?'), '')
        .replaceFirst(RegExp(r'/$'), '');
    return Padding(
      padding: const EdgeInsets.only(top: Space.xs),
      child: Semantics(
        link: true,
        hint: 'Long press to copy the link',
        child: TextButton.icon(
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          onPressed: () => _openSource(ScaffoldMessenger.of(context), note),
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link copied.'), persist: false),
            );
          },
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(shown, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

class _TopicButton extends StatelessWidget {
  const _TopicButton({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final vm = context.read<NoteViewModel>();
    return Semantics(
      button: true,
      label: 'Topic ${note.topic ?? 'none'}. Change topic',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () async {
          final topic = await _pickTopic(context, vm, note.topic);
          if (topic != null) await vm.setTopic(topic);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: palette.rule),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(note.topic ?? 'No topic', style: text.labelMedium),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 16, color: palette.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _pickTopic(
  BuildContext context,
  NoteViewModel vm,
  String? current,
) async {
  final topics = await vm.topics();
  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _TopicSheet(topics: topics, current: current),
  );
}

class _TopicSheet extends StatefulWidget {
  const _TopicSheet({required this.topics, required this.current});

  final List<String> topics;
  final String? current;

  @override
  State<_TopicSheet> createState() => _TopicSheetState();
}

class _TopicSheetState extends State<_TopicSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, Space.s),
              child: Text('Move to shelf', style: text.headlineSmall),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in widget.topics)
                    ListTile(
                      title: Text(t),
                      trailing: t == widget.current
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.pop(context, t),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, Space.s, 20, Space.l),
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'New shelf',
                  hintText: 'For example Recipes',
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      label,
      style: TypeScale.casual(
        20,
        weight: 680,
      ).copyWith(color: Palette.of(context).ink),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action, required this.onChanged});

  final ActionItem action;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: InkWell(
        onTap: onChanged,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Checkbox(
                    value: action.done,
                    onChanged: (_) => onChanged(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -4,
                      vertical: -4,
                    ),
                  ),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: AnimatedDefaultTextStyle(
                      duration: Motion.quick,
                      style: text.bodyLarge!.copyWith(
                        color: action.done ? palette.inkSoft : palette.ink,
                        decoration: action.done
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: palette.inkSoft,
                      ),
                      child: Text(action.text),
                    ),
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

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.note, required this.viewModel});

  final Note note;
  final NoteViewModel viewModel;

  Future<void> _pickVideo(BuildContext context) async {
    final paths = await context.read<MediaPicker>().video();
    if (paths.isNotEmpty) await viewModel.attach(paths);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;

    final (
      String headline,
      String body,
      Widget? action,
    ) = switch (note.status) {
      NoteStatus.needsMedia => (
        'Waiting for the video',
        note.errorMessage ??
            (viewModel.instagramConnected || !viewModel.offersInstagram
                ? 'Add the video to make the note. In Instagram, tap Share on this reel, then Download; it lands at the top of your gallery.'
                : 'Connect your Instagram and Commonplace gets the reel by itself. Or, in Instagram, tap Share on it, then Download, and add the video here.'),
        Wrap(
          spacing: Space.m,
          runSpacing: Space.s,
          children: viewModel.instagramConnected || !viewModel.offersInstagram
              ? [
                  FilledButton.icon(
                    onPressed: () => _pickVideo(context),
                    icon: const Icon(Icons.movie_outlined),
                    label: const Text('Add the video'),
                  ),
                  if (note.instagramShortcode != null &&
                      viewModel.instagramConnected)
                    TextButton(
                      onPressed: viewModel.retry,
                      child: const Text('Try Instagram again'),
                    ),
                ]
              : [
                  FilledButton(
                    onPressed: () => context.push('/connect-instagram'),
                    child: Text(
                      note.errorMessage == null
                          ? 'Connect Instagram'
                          : 'Sign in to Instagram',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickVideo(context),
                    icon: const Icon(Icons.movie_outlined),
                    label: const Text('Add the video'),
                  ),
                ],
        ),
      ),
      NoteStatus.queued => (
        'Waiting its turn',
        'This note will be made as soon as the ones before it are done. If you have no Gemini key yet, add it in Settings.',
        null,
      ),
      NoteStatus.processing => (
        viewModel.workStatus.headline,
        viewModel.workStatus.explanation,
        OutlinedButton(onPressed: viewModel.stop, child: const Text('Stop')),
      ),
      NoteStatus.failed => (
        "Couldn't make this note",
        note.errorMessage ?? 'Something went wrong.',
        FilledButton(
          onPressed: viewModel.retry,
          child: const Text('Try again'),
        ),
      ),
      NoteStatus.ready => ('', '', null),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.sheet,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (note.status == NoteStatus.processing) ...[
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: Space.m),
              ],
              Expanded(child: Text(headline, style: text.titleMedium)),
              if (note.status == NoteStatus.processing)
                if (viewModel.workingSince case final since?)
                  Elapsed(
                    since,
                    style: text.titleMedium!.copyWith(color: palette.inkSoft),
                  ),
            ],
          ),
          if (note.status == NoteStatus.processing)
            if (viewModel.workStatus.fraction case final sent?)
              Padding(
                padding: const EdgeInsets.only(top: Space.m),
                child: LinearProgressIndicator(
                  value: sent,
                  semanticsLabel: 'Sent',
                  semanticsValue: '${(sent * 100).round()}%',
                ),
              ),
          const SizedBox(height: Space.s),
          Text(
            body,
            style: text.bodyMedium!.copyWith(
              color: note.status == NoteStatus.failed
                  ? palette.error
                  : palette.ink,
            ),
          ),
          if (note.status == NoteStatus.processing)
            if (viewModel.workStatus.retryReason case final why?)
              Padding(
                padding: const EdgeInsets.only(top: Space.s),
                child: Text(
                  'Second try. The first one: $why',
                  style: text.bodyMedium!.copyWith(color: palette.error),
                ),
              ),
          if (action != null) ...[const SizedBox(height: Space.l), action],
        ],
      ),
    );
  }
}

class _PersonalNote extends StatefulWidget {
  const _PersonalNote({required this.viewModel, required this.initial});

  final NoteViewModel viewModel;
  final String initial;

  @override
  State<_PersonalNote> createState() => _PersonalNoteState();
}

class _PersonalNoteState extends State<_PersonalNote> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Your notes'),
        const SizedBox(height: Space.m),
        TextField(
          controller: _controller,
          onChanged: widget.viewModel.editPersonalNote,
          onTapOutside: (_) {
            FocusScope.of(context).unfocus();
            widget.viewModel.flushPersonalNote();
          },
          minLines: 3,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Where would you use this? Saved as you type.',
            fillColor: palette.sheet,
          ),
        ),
      ],
    );
  }
}

class _SourceMaterial extends StatelessWidget {
  const _SourceMaterial({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final palette = Palette.of(context);
    Widget section(String title, String body) => ExpansionTile(
      title: Text(title, style: text.titleSmall),
      childrenPadding: const EdgeInsets.only(bottom: Space.l),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          body,
          style: text.bodyMedium!.copyWith(color: palette.inkSoft),
        ),
      ],
    );

    return Column(
      children: [
        if (note.transcript case final t? when t.isNotEmpty)
          section('What was said', t),
        if (note.onScreenText.isNotEmpty)
          section('Text on screen', note.onScreenText.join('\n')),
        if (note.caption case final c? when c.isNotEmpty)
          section('Caption and your text', c),
      ],
    );
  }
}

/// What Gemini used for this note, and what that costs.
class _AiCost extends StatelessWidget {
  const _AiCost({required this.spend});

  final AiSpend spend;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final palette = Palette.of(context);
    final settings = context.watch<SettingsRepository>();
    final words = AiCostText(spend, usdPerEur: settings.usdPerEur);
    final requests = spend.calls == 1 ? '' : ' over ${spend.calls} requests';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What Gemini used', style: text.titleSmall),
        const SizedBox(height: Space.xs),
        Text(
          '${words.models}: ${words.usage}$requests. '
          '${words.cost}. On a free-tier key (no billing) you pay nothing.',
          style: text.bodySmall!.copyWith(color: palette.inkSoft),
        ),
      ],
    );
  }
}

/// mailto: wants %20, not +, for spaces.
String _query(Map<String, String> params) => params.entries
    .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
    .join('&');
