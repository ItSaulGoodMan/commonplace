import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/ai.dart';
import '../../../domain/models/note.dart';
import '../../../domain/revisit.dart';
import '../../core/media_picker.dart';
import '../../core/theme.dart';
import '../../core/widgets/elapsed.dart';
import '../../core/widgets/highlighted_text.dart';
import '../add/add_sheet.dart';
import 'home_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final gutter = Space.gutter(width);
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: RefreshIndicator(
                  // Pull down to look for new saves on Instagram.
                  notificationPredicate: viewModel.notesFromSaves
                      ? defaultScrollNotificationPredicate
                      : (_) => false,
                  onRefresh: () => _checkSaves(context, viewModel),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      _TopBar(viewModel: viewModel, gutter: gutter),
                      if (viewModel.instagramNeedsSignIn)
                        SliverToBoxAdapter(
                          child: _SignInBanner(gutter: gutter),
                        ),
                      if (!viewModel.loaded)
                        const SliverFillRemaining(child: SizedBox.shrink())
                      else if (viewModel.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyState(
                            viewModel: viewModel,
                            gutter: gutter,
                          ),
                        )
                      else ...[
                        if (viewModel.waitingCount > 0 &&
                            viewModel.blockedReason != null)
                          SliverToBoxAdapter(
                            child: _WaitingBanner(
                              viewModel: viewModel,
                              gutter: gutter,
                            ),
                          ),
                        if (viewModel.revisit case final note?)
                          SliverToBoxAdapter(
                            child: _RevisitBlock(
                              note: note,
                              now: viewModel.now,
                              gutter: gutter,
                              onAnother: viewModel.canShowAnotherRevisit
                                  ? viewModel.showAnotherRevisit
                                  : null,
                            ),
                          ),
                        if (!viewModel.searching &&
                            (viewModel.shelves.length > 1 ||
                                viewModel.hasStarred))
                          SliverToBoxAdapter(
                            child: _ShelfRow(
                              viewModel: viewModel,
                              gutter: gutter,
                            ),
                          ),
                        if (viewModel.notes.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _CopyAllRow(
                              viewModel: viewModel,
                              gutter: gutter,
                            ),
                          ),
                        SliverList.list(
                          children: [
                            for (final note in viewModel.attention)
                              _AttentionItem(
                                key: ValueKey('a${note.id}'),
                                note: note,
                                viewModel: viewModel,
                                gutter: gutter,
                              ),
                            for (final note in viewModel.notes)
                              _NoteItem(
                                key: ValueKey('n${note.id}'),
                                note: note,
                                now: viewModel.now,
                                gutter: gutter,
                                onCopy: () => _copy(
                                  context,
                                  viewModel.copyText(note),
                                  'Note copied.',
                                ),
                              ),
                            if (viewModel.notes.isEmpty &&
                                viewModel.query.isNotEmpty)
                              _NoResults(
                                query: viewModel.query,
                                gutter: gutter,
                              ),
                          ],
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 120)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The empty state has its own big "Add" button; don't show two.
          floatingActionButton: viewModel.isEmpty || !viewModel.loaded
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => showAddSheet(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                  tooltip: 'Add a video, link or text',
                ),
        );
      },
    );
  }
}

Future<void> _checkSaves(BuildContext context, HomeViewModel viewModel) async {
  final messenger = ScaffoldMessenger.of(context);
  final added = await viewModel.checkSaves();
  final message = switch (added) {
    null => viewModel.lastCheckFailure ?? "Couldn't check Instagram.",
    0 => viewModel.noNewSavesMessage,
    1 => 'Found 1 new save. Making the note.',
    final n => 'Found $n new saves. Making the notes.',
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), persist: false));
}

/// Makes [note] now, ahead of the others, or says why it can't yet.
Future<void> _startNow(
  BuildContext context,
  HomeViewModel viewModel,
  Note note,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final why = await viewModel.startNow(note);
  if (why == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(why), persist: false));
}

/// Puts [text] on the clipboard and says [done], or that it didn't work.
Future<void> _copy(BuildContext context, String text, String done) async {
  final messenger = ScaffoldMessenger.of(context);
  var message = done;
  try {
    await Clipboard.setData(ClipboardData(text: text));
  } on Object catch (e) {
    debugPrint('Copy failed: $e');
    message = "Couldn't copy that. Pick a topic to copy fewer notes.";
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), persist: false));
}

Future<void> _copyAll(BuildContext context, HomeViewModel viewModel) {
  final total = viewModel.notes.length;
  final copied = viewModel.copyAll();
  final String done;
  if (copied.count < total) {
    done =
        'Copied the newest ${copied.count} of $total notes, without what '
        "was said. That's as much as fits at once.";
  } else if (!copied.withMaterial) {
    done =
        'Copied $total notes, without what was said: with it they are too '
        'long to copy at once.';
  } else {
    done = total == 1 ? 'Note copied.' : 'Copied $total notes.';
  }
  return _copy(context, copied.text, done);
}

/// How many notes are listed, and one tap to copy them all, to paste into
/// an AI chat.
class _CopyAllRow extends StatelessWidget {
  const _CopyAllRow({required this.viewModel, required this.gutter});

  final HomeViewModel viewModel;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      // The button's own padding lines its label up with the page edge.
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter - 16, Space.xs),
      child: Row(
        children: [
          Expanded(child: Text(viewModel.listLabel, style: text.bodySmall)),
          TextButton.icon(
            onPressed: () => _copyAll(context, viewModel),
            icon: const Icon(Icons.copy_all_rounded, size: 20),
            label: const Text('Copy all'),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar({required this.viewModel, required this.gutter});

  final HomeViewModel viewModel;
  final double gutter;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final text = Theme.of(context).textTheme;
    final palette = Palette.of(context);

    if (vm.searching) {
      return SliverAppBar(
        pinned: true,
        automaticallyImplyLeading: false,
        titleSpacing: widget.gutter - 8,
        title: TextField(
          controller: _search,
          autofocus: true,
          onChanged: vm.setQuery,
          textInputAction: TextInputAction.search,
          style: text.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Search your notes',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: palette.sheet,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(999)),
              borderSide: BorderSide.none,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(999)),
              borderSide: BorderSide.none,
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(999)),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _search.clear();
              vm.stopSearch();
            },
            child: const Text('Done'),
          ),
          SizedBox(width: widget.gutter - 12),
        ],
      );
    }

    return SliverAppBar(
      pinned: false,
      floating: true,
      toolbarHeight: 72,
      titleSpacing: widget.gutter,
      title: Text(
        'Commonplace',
        style: text.displaySmall!.copyWith(fontSize: 30),
      ),
      actions: [
        if (!vm.isEmpty)
          IconButton(
            onPressed: vm.startSearch,
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
          ),
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'Settings',
        ),
        SizedBox(width: widget.gutter - 12),
      ],
    );
  }
}

/// The one loud element: an old key point, brought back.
class _RevisitBlock extends StatelessWidget {
  const _RevisitBlock({
    required this.note,
    required this.now,
    required this.gutter,
    required this.onAnother,
  });

  final Note note;
  final DateTime now;
  final double gutter;
  final VoidCallback? onAnother;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final point = note.keyPoints.first;
    final seen = note.lastOpenedAt ?? note.createdAt;

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, Space.s, gutter, Space.xl),
      child: Material(
        color: palette.sheet,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/note/${note.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  revisitHeading(seen, now),
                  style: text.bodySmall!.copyWith(color: palette.inkSoft),
                ),
                const SizedBox(height: Space.m),
                HighlightedText(
                  point.text,
                  highlight: point.highlight,
                  style: TypeScale.casual(
                    24,
                    weight: 640,
                    height: 1.3,
                  ).copyWith(color: palette.ink),
                ),
                const SizedBox(height: Space.m),
                Text(
                  note.displayTitle,
                  style: text.bodyMedium!.copyWith(color: palette.inkSoft),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Space.xs),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => context.push('/note/${note.id}'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        alignment: Alignment.centerLeft,
                      ),
                      child: const Text('Open note'),
                    ),
                    const Spacer(),
                    if (onAnother != null)
                      TextButton(
                        onPressed: onAnother,
                        child: const Text('Show another'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShelfRow extends StatelessWidget {
  const _ShelfRow({required this.viewModel, required this.gutter});

  final HomeViewModel viewModel;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final shelves = viewModel.shelves;
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;

    Widget chip(String label, String? value, {IconData? icon}) {
      final selected = viewModel.shelf == value;
      return Padding(
        padding: const EdgeInsets.only(right: Space.s),
        child: ChoiceChip(
          selected: selected,
          onSelected: (_) => viewModel.selectShelf(value),
          avatar: icon == null
              ? null
              : Icon(
                  icon,
                  size: 18,
                  color: selected ? palette.paper : palette.ink,
                ),
          label: Text(
            label,
            style: text.labelLarge!.copyWith(
              color: selected ? palette.paper : palette.ink,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 4),
        children: [
          chip('All', null),
          if (viewModel.hasStarred)
            chip(
              'Starred',
              HomeViewModel.starredShelf,
              icon: Icons.star_rounded,
            ),
          for (final s in shelves) chip(s.name, s.name),
        ],
      ),
    );
  }
}

class _NoteItem extends StatelessWidget {
  const _NoteItem({
    super.key,
    required this.note,
    required this.now,
    required this.gutter,
    required this.onCopy,
  });

  final Note note;
  final DateTime now;
  final double gutter;
  final VoidCallback onCopy;

  /// How far the copy button's 48 dp tap area reaches past its 20 dp icon.
  static const _iconInset = 14.0;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return InkWell(
      onTap: () => context.push('/note/${note.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: Divider(height: 1, thickness: 1, color: palette.rule),
          ),
          Padding(
            // The copy icon sits on the title's first line and the page
            // edge; the rest of its tap area reaches into the padding.
            padding: EdgeInsets.fromLTRB(
              gutter,
              Space.l + 2 - Space.m,
              gutter - _iconInset,
              Space.l + 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: Space.m),
                    child: _content(context),
                  ),
                ),
                IconButton(
                  onPressed: onCopy,
                  icon: const Icon(Icons.content_copy_rounded, size: 20),
                  color: palette.inkSoft,
                  tooltip: 'Copy note',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final first = note.keyPoints.isNotEmpty ? note.keyPoints.first : null;
    final meta = [
      if (note.topic case final t? when t.isNotEmpty) t,
      'saved ${relativeAge(note.createdAt, now)}',
    ].join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                note.displayTitle,
                style: TypeScale.casual(
                  19,
                  weight: 660,
                  height: 1.25,
                ).copyWith(color: palette.ink),
              ),
            ),
            if (note.starred)
              Padding(
                padding: const EdgeInsets.only(left: Space.s, top: 2),
                child: Icon(
                  Icons.star_rounded,
                  size: 20,
                  color: palette.ink,
                  semanticLabel: 'Starred',
                ),
              ),
          ],
        ),
        const SizedBox(height: Space.s),
        if (first != null)
          HighlightedText(
            first.text,
            highlight: first.highlight,
            maxLines: 3,
            style: text.bodyMedium!.copyWith(color: palette.ink),
          )
        else if (note.summary case final s? when s.isNotEmpty)
          Text(
            s,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium,
          ),
        const SizedBox(height: Space.s),
        Text(meta, style: text.bodySmall),
      ],
    );
  }
}

/// A note that isn't finished: waiting for video, being read, or failed.
class _AttentionItem extends StatelessWidget {
  const _AttentionItem({
    super.key,
    required this.note,
    required this.viewModel,
    required this.gutter,
  });

  final Note note;
  final HomeViewModel viewModel;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;

    final work = viewModel.workStatus(note);
    final instagramWait = note.needsInstagramFetch && viewModel.instagramPaused;
    final (String status, Widget? action) = switch (note.status) {
      NoteStatus.needsMedia => (
        note.errorMessage ?? 'Waiting for the video',
        FilledButton.icon(
          onPressed: () async {
            final paths = await context.read<MediaPicker>().video();
            if (paths.isNotEmpty) await viewModel.attach(note, paths);
          },
          icon: const Icon(Icons.movie_outlined, size: 20),
          label: const Text('Add the video'),
        ),
      ),
      NoteStatus.queued => (
        switch (viewModel.blockedReason) {
          AiFailure.missingKey => 'Waiting for your Gemini key',
          AiFailure.signedOut => 'Waiting for you to sign in',
          AiFailure.dailyLimit || AiFailure.sharedLimit => 'Made tomorrow',
          AiFailure.notConfigured => 'Waiting for the server',
          _ when instagramWait =>
            'Instagram asked to slow down. '
                'Made in a few minutes',
          _ => 'Waiting its turn',
        },
        Wrap(
          spacing: Space.s,
          runSpacing: Space.s,
          children: [
            // Nothing can start while the whole queue waits (no key...).
            if (viewModel.blockedReason == null && !instagramWait)
              OutlinedButton(
                onPressed: () => _startNow(context, viewModel, note),
                child: const Text('Start now'),
              ),
            TextButton(
              onPressed: () => viewModel.cancel(note),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
      NoteStatus.processing => (
        work.short,
        OutlinedButton(
          onPressed: () => viewModel.cancel(note),
          child: const Text('Cancel'),
        ),
      ),
      NoteStatus.failed => (
        note.errorMessage ?? "Couldn't make this note.",
        OutlinedButton(
          onPressed: () => viewModel.retry(note),
          child: const Text('Try again'),
        ),
      ),
      NoteStatus.ready => ('', null),
    };

    final busy = note.isBusy;
    final failed = note.status == NoteStatus.failed;

    return InkWell(
      onTap: () => context.push('/note/${note.id}'),
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.rule)),
        ),
        margin: EdgeInsets.symmetric(horizontal: gutter),
        padding: const EdgeInsets.symmetric(vertical: Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              note.displayTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TypeScale.casual(
                18,
                weight: 620,
                height: 1.25,
              ).copyWith(color: palette.ink),
            ),
            if (note.sourceUrl case final url? when note.title == null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  url.replaceFirst(RegExp(r'^https?://(www\.)?'), ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ),
            const SizedBox(height: Space.s),
            Row(
              children: [
                if (busy)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.s),
                    child: SizedBox.square(
                      dimension: 14,
                      child: note.status == NoteStatus.processing
                          ? const CircularProgressIndicator(strokeWidth: 2)
                          : Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: palette.inkSoft,
                            ),
                    ),
                  ),
                if (failed)
                  Padding(
                    padding: const EdgeInsets.only(right: Space.s),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: palette.error,
                    ),
                  ),
                if (note.status == NoteStatus.processing)
                  if (viewModel.workingSince(note) case final since?)
                    Padding(
                      padding: const EdgeInsets.only(right: Space.s),
                      child: Elapsed(
                        since,
                        style: text.bodySmall!.copyWith(color: palette.inkSoft),
                      ),
                    ),
                Expanded(
                  child: Text(
                    status,
                    style: text.bodySmall!.copyWith(
                      color: failed ? palette.error : palette.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
            if (note.status == NoteStatus.processing)
              if (work.retryReason case final why?)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xs),
                  child: Text(
                    'Second try. The first one: $why',
                    style: text.bodySmall!.copyWith(color: palette.error),
                  ),
                ),
            if (action != null) ...[const SizedBox(height: Space.m), action],
          ],
        ),
      ),
    );
  }
}

/// Why the saved things aren't notes yet, and the one thing that fixes it.
class _WaitingBanner extends StatelessWidget {
  const _WaitingBanner({required this.viewModel, required this.gutter});

  final HomeViewModel viewModel;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final count = viewModel.waitingCount;
    final what = count == 1 ? 'the one thing' : 'the $count things';
    final rest = count == 1
        ? 'The one waiting is made tomorrow.'
        : 'The $count waiting are made tomorrow.';

    final (String message, Widget? action) = switch (viewModel.blockedReason) {
      AiFailure.missingKey => (
        'Add your free Gemini key to turn $what you saved into notes.',
        FilledButton(
          onPressed: () => context.push('/settings'),
          child: const Text('Add key'),
        ),
      ),
      AiFailure.signedOut => (
        'Sign in with Google to turn $what you saved into notes.',
        FilledButton(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final error = await viewModel.signIn();
            if (error != null) {
              messenger.showSnackBar(
                SnackBar(content: Text(error), persist: false),
              );
            }
          },
          child: const Text('Sign in with Google'),
        ),
      ),
      AiFailure.dailyLimit => (
        "You've made today's ${viewModel.notesPerDay} notes. $rest",
        viewModel.isPlus
            ? null
            : FilledButton(
                onPressed: () => context.push('/plus'),
                child: Text(
                  'Make ${viewModel.plusNotesPerDay} a day with Plus',
                ),
              ),
      ),
      AiFailure.sharedLimit => (
        "Commonplace has used today's free AI time. $rest",
        null,
      ),
      AiFailure.notConfigured => (
        "This build of Commonplace isn't connected to its server.",
        null,
      ),
      _ => ('', null),
    };
    if (message.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, Space.l),
      child: Container(
        padding: const EdgeInsets.all(Space.l),
        decoration: BoxDecoration(
          color: palette.highlighter.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: text.titleSmall!.copyWith(color: palette.ink)),
            if (action != null) ...[const SizedBox(height: Space.m), action],
          ],
        ),
      ),
    );
  }
}

class _SignInBanner extends StatelessWidget {
  const _SignInBanner({required this.gutter});

  final double gutter;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, Space.l),
      child: Container(
        padding: const EdgeInsets.all(Space.l),
        decoration: BoxDecoration(
          color: palette.sheet,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Instagram signed Commonplace out, so new saves aren't coming in.",
              style: text.titleSmall!.copyWith(color: palette.ink),
            ),
            const SizedBox(height: Space.m),
            FilledButton(
              onPressed: () => context.push('/connect-instagram'),
              child: const Text('Sign in again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.viewModel, required this.gutter});

  final HomeViewModel viewModel;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;

    if (viewModel.instagramConnected && !viewModel.notesFromSaves) {
      return Padding(
        padding: EdgeInsets.fromLTRB(gutter, Space.xl, gutter, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HighlightedText(
              'Share a reel to Commonplace, and it becomes a note.',
              highlight: 'Share a reel',
              style: TypeScale.casual(
                28,
                weight: 680,
                height: 1.25,
              ).copyWith(color: palette.ink),
            ),
            const SizedBox(height: Space.l),
            Text(
              'In Instagram, tap Share on a reel, then Commonplace. Saving a '
              'reel does nothing here: Settings, Instagram is set to "Just '
              'share".',
              style: text.bodyLarge,
            ),
            const SizedBox(height: Space.xl),
            OutlinedButton.icon(
              onPressed: () => showAddSheet(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add something else'),
            ),
          ],
        ),
      );
    }

    if (viewModel.instagramConnected) {
      return Padding(
        padding: EdgeInsets.fromLTRB(gutter, Space.xl, gutter, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HighlightedText(
              'Save a reel on Instagram, then come back here.',
              highlight: 'Save a reel',
              style: TypeScale.casual(
                28,
                weight: 680,
                height: 1.25,
              ).copyWith(color: palette.ink),
            ),
            const SizedBox(height: Space.l),
            Text(
              'Commonplace looks at your Saved list each time you open it. Pull down to look now.',
              style: text.bodyLarge,
            ),
            const SizedBox(height: Space.xl),
            Wrap(
              spacing: Space.m,
              runSpacing: Space.s,
              children: [
                FilledButton(
                  onPressed: viewModel.checkingSaves
                      ? null
                      : () => _checkSaves(context, viewModel),
                  child: Text(
                    viewModel.checkingSaves ? 'Looking...' : 'Look now',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => showAddSheet(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add something else'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (viewModel.isPlay) {
      return _PlayEmptyState(viewModel: viewModel, gutter: gutter);
    }

    Widget step(int n, String body) => Padding(
      padding: const EdgeInsets.only(bottom: Space.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$n',
              style: TypeScale.casual(
                22,
                weight: 700,
              ).copyWith(color: palette.ink),
            ),
          ),
          Expanded(child: Text(body, style: text.bodyLarge)),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, Space.xl, gutter, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HighlightedText(
            'Start with one reel you saved for later.',
            highlight: 'one reel',
            style: TypeScale.casual(
              28,
              weight: 680,
              height: 1.25,
            ).copyWith(color: palette.ink),
          ),
          const SizedBox(height: Space.xl),
          step(
            1,
            'Connect your Instagram. Every reel you save after that turns into a note here.',
          ),
          step(
            2,
            'Or share a single reel: in Instagram, tap Share, then Commonplace.',
          ),
          step(
            3,
            'Gemini reads what is said and what is written on screen, and Commonplace keeps the note.',
          ),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.m,
            runSpacing: Space.s,
            children: [
              FilledButton(
                onPressed: () => context.push('/connect-instagram'),
                child: const Text('Connect Instagram'),
              ),
              OutlinedButton.icon(
                onPressed: () => showAddSheet(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add a reel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.gutter});

  final String query;
  final double gutter;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(gutter, Space.xl, gutter, 0),
    child: Text(
      'Nothing mentions "$query" yet.',
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  );
}

/// Play edition: no Instagram sign-in, so the reel's video comes from
/// Instagram's own Download button.
class _PlayEmptyState extends StatelessWidget {
  const _PlayEmptyState({required this.viewModel, required this.gutter});

  final HomeViewModel viewModel;
  final double gutter;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;

    Widget step(int n, String body) => Padding(
      padding: const EdgeInsets.only(bottom: Space.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$n',
              style: TypeScale.casual(
                22,
                weight: 700,
              ).copyWith(color: palette.ink),
            ),
          ),
          Expanded(child: Text(body, style: text.bodyLarge)),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, Space.xl, gutter, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HighlightedText(
            'Start with one reel you saved for later.',
            highlight: 'one reel',
            style: TypeScale.casual(
              28,
              weight: 680,
              height: 1.25,
            ).copyWith(color: palette.ink),
          ),
          const SizedBox(height: Space.xl),
          step(1, 'In Instagram, open the reel and tap Share, then Download.'),
          step(
            2,
            'Share that video to Commonplace, or tap Add here and pick it from your gallery.',
          ),
          step(
            3,
            'Gemini reads what is said and what is written on screen, and Commonplace keeps the note.',
          ),
          const SizedBox(height: Space.s),
          Wrap(
            spacing: Space.m,
            runSpacing: Space.s,
            children: [
              if (!viewModel.signedIn)
                FilledButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final error = await viewModel.signIn();
                    if (error != null) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(error), persist: false),
                      );
                    }
                  },
                  child: const Text('Sign in with Google'),
                ),
              if (viewModel.signedIn)
                FilledButton.icon(
                  onPressed: () => showAddSheet(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add your first reel'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => showAddSheet(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add your first reel'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
