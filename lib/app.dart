import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'data/repositories/account_repository.dart';
import 'data/repositories/instagram_repository.dart';
import 'data/repositories/notes_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/share_inbox.dart';
import 'domain/models/ai.dart';
import 'domain/use_cases/capture.dart';
import 'domain/use_cases/note_processor.dart';
import 'domain/use_cases/saved_sync.dart';
import 'ui/core/capture_feedback.dart';
import 'ui/core/theme.dart';
import 'ui/features/home/home_screen.dart';
import 'ui/features/home/home_view_model.dart';
import 'ui/features/instagram/connect_screen.dart';
import 'ui/features/instagram/connect_view_model.dart';
import 'ui/features/note/note_screen.dart';
import 'ui/features/note/note_view_model.dart';
import 'ui/features/plus/plus_screen.dart';
import 'ui/features/settings/settings_screen.dart';
import 'ui/features/welcome/play_welcome_screen.dart';
import 'ui/features/welcome/welcome_screen.dart';

GoRouter buildRouter(SettingsRepository settings) => GoRouter(
  refreshListenable: settings,
  redirect: (context, state) {
    final location = state.matchedLocation;
    final atWelcome = location == '/welcome';
    // Signing in to Instagram is part of the welcome, so it's always open.
    if (location == '/connect-instagram') return null;
    if (!settings.welcomeDone && !atWelcome) return '/welcome';
    if (settings.welcomeDone && atWelcome) return '/';
    return null;
  },
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (context, state) => context.read<Edition>() == Edition.play
          ? const PlayWelcomeScreen()
          : const WelcomeScreen(),
    ),
    GoRoute(
      path: '/connect-instagram',
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) => ConnectViewModel(
          instagram: context.read<InstagramRepository>(),
          sync: context.read<SavedSync>(),
        ),
        child: Consumer<ConnectViewModel>(
          builder: (context, vm, _) => ConnectScreen(viewModel: vm),
        ),
      ),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) => HomeViewModel(
          notes: context.read<NotesRepository>(),
          settings: context.read<SettingsRepository>(),
          processor: context.read<NoteProcessor>(),
          capture: context.read<Capture>(),
          instagram: context.read<InstagramRepository>(),
          sync: context.read<SavedSync>(),
          account: context.read<AccountRepository>(),
          ai: context.read<NoteAi>(),
          edition: context.read<Edition>(),
        ),
        child: Consumer<HomeViewModel>(
          builder: (context, vm, _) => HomeScreen(viewModel: vm),
        ),
      ),
      routes: [
        GoRoute(
          path: 'note/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? -1;
            return ChangeNotifierProvider(
              key: ValueKey('note-$id'),
              create: (context) => NoteViewModel(
                id: id,
                notes: context.read<NotesRepository>(),
                processor: context.read<NoteProcessor>(),
                capture: context.read<Capture>(),
                instagram: context.read<InstagramRepository>(),
                edition: context.read<Edition>(),
              ),
              child: Consumer<NoteViewModel>(
                builder: (context, vm, _) => NoteScreen(viewModel: vm),
              ),
            );
          },
        ),
        GoRoute(
          path: 'settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(path: 'plus', builder: (context, state) => const PlusScreen()),
      ],
    ),
  ],
);

class CommonplaceApp extends StatefulWidget {
  const CommonplaceApp({super.key, required this.inbox, this.initialShare});

  final ShareInbox inbox;
  final Incoming? initialShare;

  @override
  State<CommonplaceApp> createState() => _CommonplaceAppState();
}

class _CommonplaceAppState extends State<CommonplaceApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final GoRouter _router;
  StreamSubscription<Incoming>? _shares;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(context.read<SettingsRepository>());
    _shares = widget.inbox.stream.listen(_onShare);
    _lifecycle = AppLifecycleListener(
      // Coming back, often from Instagram, is the moment to look for new
      // saves and retry the queue.
      onResume: () {
        context.read<NoteProcessor>()
          ..retryTransient()
          ..kick();
        context.read<SavedSync>().check();
        // A new day may have brought new notes (Play edition).
        context.read<AccountRepository>().refresh();
      },
    );
    final initial = widget.initialShare;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onShare(initial));
    }
  }

  Future<void> _onShare(Incoming incoming) async {
    final capture = context.read<Capture>();
    final settings = context.read<SettingsRepository>();
    final blocked = context.read<NoteAi>().blocked;
    final result = await capture.handle(incoming);
    final id = result.noteId;
    if (id != null && settings.welcomeDone) {
      _router.go('/note/$id');
    }
    final messenger = _messengerKey.currentState;
    if (messenger != null && result.outcome != CaptureOutcome.waitingForVideo) {
      announceCapture(messenger, _router, result, blocked: blocked);
    }
  }

  @override
  void dispose() {
    unawaited(_shares?.cancel());
    _lifecycle.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<SettingsRepository, ThemeMode>(
      (s) => s.themeMode,
    );
    return MaterialApp.router(
      title: 'Commonplace',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      routerConfig: _router,
    );
  }
}
