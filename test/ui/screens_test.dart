import 'dart:io';

import 'package:commonplace/config.dart';
import 'package:commonplace/data/repositories/account_repository.dart';
import 'package:commonplace/data/repositories/gemini_note_ai.dart';
import 'package:commonplace/data/repositories/instagram_repository.dart';
import 'package:commonplace/data/repositories/notes_repository.dart';
import 'package:commonplace/data/repositories/settings_repository.dart';
import 'package:commonplace/data/services/database/app_database.dart';
import 'package:commonplace/data/services/gemini_client.dart';
import 'package:commonplace/data/services/local_stores.dart';
import 'package:commonplace/domain/models/ai.dart';
import 'package:commonplace/domain/models/note.dart';
import 'package:commonplace/domain/use_cases/capture.dart';
import 'package:commonplace/domain/use_cases/note_processor.dart';
import 'package:commonplace/domain/use_cases/saved_sync.dart';
import 'package:commonplace/ui/core/media_picker.dart';
import 'package:commonplace/ui/core/theme.dart';
import 'package:commonplace/ui/core/widgets/highlighted_text.dart';
import 'package:commonplace/ui/features/home/home_screen.dart';
import 'package:commonplace/ui/features/home/home_view_model.dart';
import 'package:commonplace/ui/features/note/note_screen.dart';
import 'package:commonplace/ui/features/note/note_view_model.dart';
import 'package:commonplace/ui/features/settings/instagram_section.dart';
import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_instagram.dart';
import '../helpers/fakes.dart';

class _World {
  _World(
    this.db,
    this.notes,
    this.settings,
    this.processor,
    this.capture,
    this.instagram,
    this.sync,
    this.ai,
    this.account,
  );

  final AppDatabase db;
  final NotesRepository notes;
  final SettingsRepository settings;
  final NoteProcessor processor;
  final Capture capture;
  final InstagramRepository instagram;
  final SavedSync sync;
  final NoteAi ai;
  final AccountRepository account;

  static Future<_World> create({
    bool withKey = true,
    bool instagram = false,
  }) async {
    // Synchronous stream teardown keeps drift from leaving timers behind
    // in the widget tester's fake clock.
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    final notes = NotesRepository(db);
    final settings = SettingsRepository(
      prefs: MemoryKeyValueStore(),
      secrets: memorySecretStore({
        if (withKey) 'gemini_api_key': 'AIzaTESTKEY0123456789012345678901234',
        if (instagram) 'instagram_session': testSessionJson(),
      }),
    );
    await settings.load();
    final media = MediaStore(baseDir: () async => Directory.systemTemp);
    final ig = InstagramRepository(
      secrets: SecretStore(),
      prefs: MemoryKeyValueStore(),
      db: db,
      media: media,
      cookies: FakeWebCookies(),
      httpClient: FakeInstagram().client,
    );
    await ig.load();
    final ai = GeminiNoteAi(
      settings: settings,
      gemini: GeminiClient(
        httpClient: MockClient((_) async => http.Response('{}', 500)),
        readApiKey: settings.readGeminiKey,
        model: () => settings.geminiModel,
      ),
    );
    final processor = NoteProcessor(
      notes: notes,
      settings: settings,
      ai: ai,
      media: media,
      instagram: ig,
    );
    final capture = Capture(
      notes: notes,
      media: media,
      processor: processor,
      instagram: ig,
    );
    final sync = SavedSync(
      instagram: ig,
      notes: notes,
      processor: processor,
      enabled: () => settings.notesFromSaves,
    );
    return _World(
      db,
      notes,
      settings,
      processor,
      capture,
      ig,
      sync,
      ai,
      inertAccount(),
    );
  }

  Future<int> addReadyNote({
    required String title,
    required DateTime created,
    String topic = 'SEO',
    String? sourceUrl,
  }) async {
    final id = await notes.create(
      status: NoteStatus.queued,
      sourceKind: SourceKind.video,
      sourceUrl: sourceUrl,
    );
    await notes.saveDistillation(
      id,
      title: title,
      summary: 'Why it matters.',
      keyPoints: const [
        KeyPoint(
          text: 'Phrase the title as the exact question people search.',
          highlight: 'exact question',
        ),
      ],
      actions: const [ActionItem(text: 'Rewrite one title')],
      topic: topic,
      tags: const ['titles'],
    );
    await db.customStatement('UPDATE notes SET created_at = ? WHERE id = ?', [
      created.millisecondsSinceEpoch ~/ 1000,
      id,
    ]);
    return id;
  }

  Widget wrap(Widget Function(BuildContext) screen) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: processor),
      Provider.value(value: Edition.personal),
      Provider<NoteAi>.value(value: ai),
      ChangeNotifierProvider.value(value: instagram),
      ChangeNotifierProvider.value(value: sync),
      ChangeNotifierProvider.value(value: account),
      Provider.value(value: notes),
      Provider.value(value: capture),
      Provider.value(value: MediaPicker()),
    ],
    child: MaterialApp.router(
      theme: buildTheme(Brightness.light),
      routerConfig: GoRouter(
        routes: [
          GoRoute(path: '/', builder: (context, _) => screen(context)),
          GoRoute(path: '/note/:id', builder: (_, _) => const Scaffold()),
          GoRoute(path: '/settings', builder: (_, _) => const Scaffold()),
          GoRoute(
            path: '/connect-instagram',
            builder: (_, _) => const Scaffold(),
          ),
        ],
      ),
    ),
  );
}

/// Lets stream queries deliver and animations finish.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _teardown(WidgetTester tester, _World world) async {
  await tester.pumpWidget(const SizedBox());
  await world.db.close();
  await tester.pump();
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('highlighted text keeps its words readable to screen readers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.light),
        home: const Scaffold(
          body: SizedBox(
            width: 220,
            child: HighlightedText(
              'Answer the question in your first hundred words.',
              highlight: 'first hundred words',
            ),
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('Answer the question in your first hundred words.'),
      findsOneWidget,
    );
    // Wraps onto several lines at this width rather than overflowing.
    expect(
      tester.getSize(find.byType(HighlightedText)).height,
      greaterThan(30),
    );
  });

  testWidgets('an empty home explains how to start', (tester) async {
    final world = await _World.create();
    await tester.pumpWidget(
      world.wrap(
        (context) => ChangeNotifierProvider(
          create: (_) => HomeViewModel(
            notes: world.notes,
            settings: world.settings,
            processor: world.processor,
            capture: world.capture,
            instagram: world.instagram,
            sync: world.sync,
            account: world.account,
            ai: world.ai,
          ),
          child: Consumer<HomeViewModel>(
            builder: (_, vm, _) => HomeScreen(viewModel: vm),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Commonplace'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Start with one reel you saved for later.'),
      findsOneWidget,
    );
    expect(find.text('Connect Instagram'), findsOneWidget);
    expect(find.text('Add a reel'), findsOneWidget);
    expect(
      find.byType(FloatingActionButton),
      findsNothing,
      reason: 'the empty state has its own Add button',
    );
    await _teardown(tester, world);
  });

  testWidgets('signed in to Instagram, an empty home says to go save', (
    tester,
  ) async {
    final world = await _World.create(instagram: true);
    await tester.pumpWidget(
      world.wrap(
        (_) => ChangeNotifierProvider(
          create: (_) => HomeViewModel(
            notes: world.notes,
            settings: world.settings,
            processor: world.processor,
            capture: world.capture,
            instagram: world.instagram,
            sync: world.sync,
            account: world.account,
            ai: world.ai,
          ),
          child: Consumer<HomeViewModel>(
            builder: (_, vm, _) => HomeScreen(viewModel: vm),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(
      find.bySemanticsLabel('Save a reel on Instagram, then come back here.'),
      findsOneWidget,
    );
    expect(find.text('Look now'), findsOneWidget);
    expect(find.text('Connect Instagram'), findsNothing);
    await _teardown(tester, world);
  });

  testWidgets('home brings back an old note and lists the rest by shelf', (
    tester,
  ) async {
    final world = await _World.create();
    await world.addReadyNote(
      title: 'Write titles like questions',
      created: DateTime.now().subtract(const Duration(days: 21)),
    );
    await world.addReadyNote(
      title: 'Batch cook on Sundays',
      topic: 'Cooking',
      created: DateTime.now().subtract(const Duration(days: 9)),
    );

    await tester.pumpWidget(
      world.wrap(
        (context) => ChangeNotifierProvider(
          create: (_) => HomeViewModel(
            notes: world.notes,
            settings: world.settings,
            processor: world.processor,
            capture: world.capture,
            instagram: world.instagram,
            sync: world.sync,
            account: world.account,
            ai: world.ai,
          ),
          child: Consumer<HomeViewModel>(
            builder: (_, vm, _) => HomeScreen(viewModel: vm),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(find.textContaining(RegExp(r'^From ')), findsOneWidget);
    expect(find.text('Show another'), findsOneWidget);
    expect(find.text('Write titles like questions'), findsWidgets);
    expect(find.text('Batch cook on Sundays'), findsWidgets);

    // Shelves filter the list.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Cooking'));
    await tester.pump();
    expect(find.text('Write titles like questions'), findsNothing);
    expect(find.text('Batch cook on Sundays'), findsOneWidget);
    await _teardown(tester, world);
  });

  testWidgets('a note shows its points and actions can be ticked off', (
    tester,
  ) async {
    final world = await _World.create();
    final id = await world.addReadyNote(
      title: 'Write titles like questions',
      created: DateTime.now().subtract(const Duration(days: 2)),
    );

    await tester.pumpWidget(
      world.wrap(
        (context) => ChangeNotifierProvider(
          create: (_) => NoteViewModel(
            id: id,
            notes: world.notes,
            processor: world.processor,
            capture: world.capture,
            instagram: world.instagram,
          ),
          child: Consumer<NoteViewModel>(
            builder: (_, vm, _) => NoteScreen(viewModel: vm),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Write titles like questions'), findsOneWidget);
    expect(find.text('Key points'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Phrase the title as the exact question people search.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(Checkbox));
    await _settle(tester);
    final note = (await world.notes.find(id))!;
    expect(note.actions.single.done, isTrue);
    expect(note.openCount, 1);
    await _teardown(tester, world);
  });

  testWidgets('Settings: "Just share" or "Automatic by save"', (tester) async {
    final world = await _World.create(instagram: true);
    await tester.pumpWidget(
      world.wrap(
        (_) => const Scaffold(
          body: SingleChildScrollView(child: InstagramSection(gutter: 16)),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Automatic by save'), findsOneWidget);
    expect(world.settings.notesFromSaves, isTrue);
    expect(find.text('Look now'), findsOneWidget);

    await tester.tap(find.text('Just share'));
    await _settle(tester);
    expect(world.settings.notesFromSaves, isFalse);
    expect(find.textContaining('Only reels you share'), findsOneWidget);
    expect(find.text('Look now'), findsNothing);
    expect(await world.sync.check(force: true), 0);

    await _teardown(tester, world);
  });

  testWidgets('a note links to its reel', (tester) async {
    final world = await _World.create();
    final id = await world.addReadyNote(
      title: 'Learn German conjugations',
      created: DateTime.now(),
      sourceUrl: 'https://www.instagram.com/reel/Deo4XyRM2yC/',
    );
    await tester.pumpWidget(
      world.wrap(
        (context) => ChangeNotifierProvider(
          create: (_) => NoteViewModel(
            id: id,
            notes: world.notes,
            processor: world.processor,
            capture: world.capture,
            instagram: world.instagram,
          ),
          child: Consumer<NoteViewModel>(
            builder: (_, vm, _) => NoteScreen(viewModel: vm),
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('instagram.com/reel/Deo4XyRM2yC'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    await _teardown(tester, world);
  });
}
