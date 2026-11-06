import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme.dart';
import 'connect_view_model.dart';

/// Signs in to Instagram on Instagram's own page, then asks whether recent
/// saves should become notes.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, required this.viewModel});

  final ConnectViewModel viewModel;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late final WebViewController _web;
  Timer? _poll;
  bool _loading = true;
  bool _offline = false;
  bool _left = false;

  ConnectViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => _setLoading(true),
          onPageFinished: (url) {
            _setLoading(false);
            _vm.pageChanged(url, _web.getUserAgent);
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) _vm.pageChanged(url, _web.getUserAgent);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? false) {
              setState(() => _offline = true);
            }
          },
          onNavigationRequest: _navigate,
        ),
      )
      ..loadRequest(_vm.signInUri);
    // Instagram's sign-in is a single-page app; not every step is a page
    // load. A light poll of the local cookie store catches the moment the
    // session appears. Nothing is sent anywhere by this.
    _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
      final url = await _web.currentUrl();
      if (url != null) await _vm.pageChanged(url, _web.getUserAgent);
    });
    _vm.addListener(_onStep);
  }

  @override
  void dispose() {
    _poll?.cancel();
    _vm.removeListener(_onStep);
    super.dispose();
  }

  void _setLoading(bool value) {
    if (mounted && _loading != value) setState(() => _loading = value);
  }

  FutureOr<NavigationDecision> _navigate(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      // "Open in the Instagram app" links and the like.
      return NavigationDecision.prevent;
    }
    final host = uri.host.toLowerCase();
    final allowed =
        host == _vm.baseUri.host ||
        host == 'instagram.com' ||
        host.endsWith('.instagram.com') ||
        host == 'facebook.com' ||
        host.endsWith('.facebook.com');
    if (allowed) return NavigationDecision.navigate;
    // Help pages and the like open in the browser instead.
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
    return NavigationDecision.prevent;
  }

  void _onStep() {
    if (_vm.step != ConnectStep.signIn) _poll?.cancel();
    if (_vm.step == ConnectStep.done && !_left) {
      _left = true;
      final name = _vm.username;
      final who = name == null ? '' : ' as @$name';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _vm.reconnected
                ? 'Signed in again$who. Catching up on your saves.'
                : 'Connected to Instagram$who.',
          ),
          persist: false,
        ),
      );
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _vm.step;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          step == ConnectStep.signIn ? 'Sign in to Instagram' : 'Instagram',
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () =>
              context.canPop() ? context.pop(false) : context.go('/'),
        ),
        bottom: step == ConnectStep.signIn && _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: switch (step) {
        ConnectStep.signIn => _offline ? _offlineView() : _signInView(),
        ConnectStep.loading || ConnectStep.done => const _Busy(),
        ConnectStep.choose => _ChooseView(viewModel: _vm),
        ConnectStep.failed => _FailedView(viewModel: _vm),
      },
    );
  }

  Widget _signInView() {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final gutter = Space.gutter(MediaQuery.sizeOf(context).width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: palette.sheet,
          child: Padding(
            padding: EdgeInsets.fromLTRB(gutter, Space.m, gutter, Space.m),
            child: Text(
              "This is Instagram's own sign-in page. Commonplace reads only your Saved list and the posts you share with it.",
              style: text.bodySmall!.copyWith(color: palette.ink),
            ),
          ),
        ),
        Expanded(child: WebViewWidget(controller: _web)),
      ],
    );
  }

  Widget _offlineView() {
    final text = Theme.of(context).textTheme;
    final gutter = Space.gutter(MediaQuery.sizeOf(context).width);
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, Space.xxl, gutter, Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Couldn't open Instagram", style: text.titleLarge),
          const SizedBox(height: Space.s),
          Text('Check your connection, then try again.', style: text.bodyLarge),
          const SizedBox(height: Space.xl),
          FilledButton(
            onPressed: () {
              setState(() => _offline = false);
              _web.loadRequest(_vm.signInUri);
            },
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(height: Space.l),
        Text(
          'Looking at your saves...',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    ),
  );
}

class _ChooseView extends StatelessWidget {
  const _ChooseView({required this.viewModel});

  final ConnectViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final text = Theme.of(context).textTheme;
    final gutter = Space.gutter(MediaQuery.sizeOf(context).width);
    final name = viewModel.username;
    final count = viewModel.offerCount;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Space.measure + 64),
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutter, Space.xxl, gutter, Space.huge),
          children: [
            Text(
              name == null ? "You're signed in" : 'Signed in as @$name',
              style: TypeScale.casual(
                26,
                weight: 700,
                height: 1.2,
              ).copyWith(color: palette.ink),
            ),
            const SizedBox(height: Space.l),
            Text(
              'From now on, every post you save on Instagram turns into a note here. Commonplace checks your Saved list each time you open it.',
              style: text.bodyLarge,
            ),
            const SizedBox(height: Space.xxl),
            if (count > 0) ...[
              Text(
                count == 1
                    ? 'Make a note from the post you saved last, too?'
                    : 'Make notes from the $count posts you saved last, too?',
                style: text.titleMedium,
              ),
              const SizedBox(height: Space.xs),
              Text(
                'Older saves stay on Instagram. You can always share one here.',
                style: text.bodyMedium!.copyWith(color: palette.inkSoft),
              ),
              const SizedBox(height: Space.xl),
              FilledButton(
                onPressed: () => viewModel.choose(includeRecent: true),
                child: Text(
                  count == 1 ? 'Yes, make that note' : 'Yes, make $count notes',
                ),
              ),
              const SizedBox(height: Space.m),
              OutlinedButton(
                onPressed: () => viewModel.choose(includeRecent: false),
                child: const Text('No, only new saves'),
              ),
            ] else
              FilledButton(
                onPressed: () => viewModel.choose(includeRecent: false),
                child: const Text('Done'),
              ),
          ],
        ),
      ),
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({required this.viewModel});

  final ConnectViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final gutter = Space.gutter(MediaQuery.sizeOf(context).width);
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, Space.xxl, gutter, Space.huge),
      children: [
        Text("Signed in, but your saves didn't load", style: text.titleLarge),
        const SizedBox(height: Space.s),
        Text(
          viewModel.failure?.message ?? 'Something went wrong.',
          style: text.bodyLarge,
        ),
        const SizedBox(height: Space.xl),
        FilledButton(
          onPressed: viewModel.loadLatest,
          child: const Text('Try again'),
        ),
        const SizedBox(height: Space.m),
        TextButton(
          onPressed: viewModel.skip,
          child: const Text('Skip, only new saves'),
        ),
      ],
    );
  }
}
