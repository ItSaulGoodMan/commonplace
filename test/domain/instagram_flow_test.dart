import 'dart:io';

import 'package:commonplace/data/repositories/gemini_note_ai.dart';
import 'package:commonplace/data/repositories/instagram_repository.dart';
import 'package:commonplace/data/repositories/notes_repository.dart';
import 'package:commonplace/data/repositories/settings_repository.dart';
import 'package:commonplace/data/services/database/app_database.dart';
import 'package:commonplace/data/services/gemini_client.dart';
import 'package:commonplace/data/services/instagram_api.dart';
import 'package:commonplace/data/services/local_stores.dart';
import 'package:commonplace/domain/models/note.dart';
import 'package:commonplace/domain/use_cases/capture.dart';
import 'package:commonplace/domain/use_cases/note_processor.dart';
import 'package:commonplace/domain/use_cases/saved_sync.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../helpers/fake_instagram.dart';
import '../helpers/fakes.dart';

/// The whole app minus the UI, with a fake Instagram and a fake Gemini.
class _World {
  _World._(
    this.db,
    this.notes,
    this.instagram,
    this.processor,
    this.capture,
    this.sync,
    this.ig,
    this.cookies,
    this.gemini,
    this.mediaDir,
    this.clock,
  );

  final AppDatabase db;
  final NotesRepository notes;
  final InstagramRepository instagram;
  final NoteProcessor processor;
  final Capture capture;
  final SavedSync sync;
  final FakeInstagram ig;
  final FakeWebCookies cookies;
  final List<http.Request> gemini;
  final Directory mediaDir;
  final _Clock clock;

  static Future<_World> create({
    bool signedIn = true,
    bool Function()? enabled,
  }) async {
    final clock = _Clock();
    final db = AppDatabase(NativeDatabase.memory());
    final notes = NotesRepository(db, clock: clock.now);
    final prefs = MemoryKeyValueStore();
    final secrets = memorySecretStore({
      'gemini_api_key': 'AIzaTESTKEY0123456789012345678901234',
      if (signedIn) 'instagram_session': testSessionJson(),
    });
    final settings = SettingsRepository(prefs: prefs, secrets: secrets);
    await settings.load();
    final mediaDir = await Directory.systemTemp.createTemp('commonplace_ig');
    final media = MediaStore(baseDir: () async => mediaDir);
    final ig = FakeInstagram();
    final cookies = FakeWebCookies();
    final instagram = InstagramRepository(
      secrets: secrets,
      prefs: prefs,
      db: db,
      media: media,
      cookies: cookies,
      httpClient: ig.client,
      clock: clock.now,
    );
    await instagram.load();
    final gemini = <http.Request>[];
    final processor = NoteProcessor(
      notes: notes,
      settings: settings,
      ai: GeminiNoteAi(
        settings: settings,
        gemini: GeminiClient(
          httpClient: fakeGemini(onRequest: gemini.add),
          readApiKey: settings.readGeminiKey,
          model: () => settings.geminiModel,
          baseUri: Uri.parse('https://example.test'),
        ),
      ),
      media: media,
      instagram: instagram,
      clock: clock.now,
      retryDelay: Duration.zero,
    );
    final capture = Capture(
      notes: notes,
      media: media,
      processor: processor,
      instagram: instagram,
      clock: clock.now,
    );
    final sync = SavedSync(
      instagram: instagram,
      notes: notes,
      processor: processor,
      clock: clock.now,
      enabled: enabled,
    );
    return _World._(
      db,
      notes,
      instagram,
      processor,
      capture,
      sync,
      ig,
      cookies,
      gemini,
      mediaDir,
      clock,
    );
  }

  /// Lets the fire-and-forget queue finish.
  Future<void> settle() async {
    for (
      var i = 0;
      i < 100 && (processor.isRunning || await notes.nextQueued() != null);
      i++
    ) {
      await processor.kick();
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// Waits for the queue run that's in progress, without starting another.
  Future<void> idle() async {
    for (var i = 0; i < 200 && processor.isRunning; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<List<Note>> all() => notes.watchAll().first;

  Future<void> dispose() async {
    await settle();
    await db.close();
    if (await mediaDir.exists()) await mediaDir.delete(recursive: true);
  }
}

class _Clock {
  DateTime value = DateTime(2026, 11, 6, 9);
  DateTime now() => value;
  void advance(Duration d) => value = value.add(d);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('right after signing in, the latest saves can become notes', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    w.ig
      ..save('3300000000000000004', caption: 'Old one about SEO')
      ..save('3300000000000000003', kind: 'photo', caption: 'Interview tips')
      ..save('3300000000000000002', caption: 'Pasta: salt the water hard')
      ..save('3300000000000000001', kind: 'carousel', caption: 'Newest save');

    final latest = await w.sync.latest();
    expect(latest, hasLength(4));
    final added = await w.sync.startFrom(latest, count: 2);
    expect(added, 2);
    await w.settle();

    final notes = await w.all();
    expect(notes, hasLength(2));
    // Created oldest first, so the newest save is on top, like on Instagram.
    expect(notes.first.caption, 'Newest save');
    expect(notes.last.caption, 'Pasta: salt the water hard');
    for (final n in notes) {
      expect(n.status, NoteStatus.ready, reason: n.errorMessage);
      expect(n.creatorHandle, 'cook.with.ana', reason: 'Instagram knows best');
      expect(n.remoteId, isNotNull);
      expect(n.mediaPaths, isEmpty, reason: 'downloads are deleted after');
    }
    expect(notes.first.sourceUrl, startsWith('https://www.instagram.com/p/'));
    expect(notes.last.sourceUrl, startsWith('https://www.instagram.com/reel/'));
    expect(
      w.ig.cdnCalls,
      3,
      reason: 'one reel video, plus a carousel photo and video',
    );
    expect(w.mediaDir.listSync(recursive: true).whereType<File>(), isEmpty);

    // The other two were already saved before: they never become notes.
    w.clock.advance(const Duration(minutes: 5));
    expect(await w.sync.check(), 0);
  });

  test('only new saves turn into notes, once', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    w.ig
      ..save('3300000000000000002')
      ..save('3300000000000000001');
    await w.sync.startFrom(await w.sync.latest(), count: 0);
    expect(await w.all(), isEmpty);

    // Later, two reels are saved on Instagram.
    w.ig
      ..save('3300000000000000010', caption: 'Interview: tell a story')
      ..save('3300000000000000011', caption: 'Pasta water');
    w.clock.advance(const Duration(minutes: 10));
    expect(await w.sync.check(), 2);
    await w.settle();
    expect(
      (await w.all()).map((n) => n.status),
      everyElement(NoteStatus.ready),
    );

    // Nothing new: one small request, no new notes.
    final before = w.ig.savedListCalls;
    w.clock.advance(const Duration(minutes: 10));
    expect(await w.sync.check(), 0);
    expect(w.ig.savedListCalls, before + 1);
  });

  test('checks are spaced out unless the owner asks', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    await w.sync.startFrom(await w.sync.latest(), count: 0);
    final before = w.ig.savedListCalls;

    expect(await w.sync.check(), 0);
    expect(w.ig.savedListCalls, before, reason: 'checked a moment ago');
    await w.sync.check(force: true);
    expect(w.ig.savedListCalls, before + 1);
  });

  test('a deleted note does not come back', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    await w.sync.startFrom(await w.sync.latest(), count: 0);
    w.ig.save('3300000000000000020');
    await w.sync.check(force: true);
    await w.settle();
    final note = (await w.all()).single;

    await w.capture.delete(note);
    await w.sync.check(force: true);
    expect(await w.all(), isEmpty);
  });

  test('walks more than one page when a lot was saved', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    w.ig.pageSize = 3;
    w.ig.save('3300000000000000100');
    await w.sync.startFrom(await w.sync.latest(), count: 0);
    for (var i = 1; i <= 7; i++) {
      w.ig.save('33000000000000001${i.toString().padLeft(2, '0')}');
    }
    expect(await w.sync.check(force: true), 7);
    expect(w.ig.savedListCalls, 1 + 3, reason: 'pages of 3: 3 + 3 + 1, stop');
  });

  test('without a recorded start, the first check makes no notes', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    w.ig
      ..save('3300000000000000001')
      ..save('3300000000000000002');
    expect(await w.sync.check(), 0);
    expect(await w.all(), isEmpty);
    expect(w.instagram.baselineDone, isTrue);

    w.ig.save('3300000000000000003');
    expect(await w.sync.check(force: true), 1);
  });

  test('a shared link is fetched from Instagram when signed in', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    w.ig.post(
      '3300000000000000050',
      caption: 'How to answer "tell me about yourself" in an interview',
    );
    final code = w.ig.codeOf('3300000000000000050');

    final result = await w.capture.handle(
      Incoming(texts: ['https://www.instagram.com/reel/$code/?igsh=abc']),
    );
    expect(result.outcome, CaptureOutcome.queued);
    await w.settle();

    final note = (await w.notes.find(result.noteId!))!;
    expect(note.status, NoteStatus.ready, reason: note.errorMessage);
    expect(note.caption, contains('tell me about yourself'));
    expect(note.sourceKind, SourceKind.video);
    expect(note.remoteId, '3300000000000000050');

    // Saving the same reel later doesn't make a second note.
    await w.sync.startFrom(const [], count: 0);
    w.ig.save('3300000000000000050');
    await w.sync.check(force: true);
    expect(await w.all(), hasLength(1));
  });

  test('a link to a post Instagram won\'t show waits for the video', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    final result = await w.capture.handle(
      const Incoming(texts: ['https://www.instagram.com/p/DAAAAAAAAAB/']),
    );
    await w.settle();
    final note = (await w.notes.find(result.noteId!))!;
    expect(note.status, NoteStatus.needsMedia);
    expect(note.errorMessage, InstagramFailure.notFound.message);
    expect(w.gemini, isEmpty);

    // The owner can still add it by hand.
    final video = await tempFile('reel.mp4', 2048);
    await w.capture.attach(note.id, [video.path]);
    await w.settle();
    expect((await w.notes.find(note.id))!.status, NoteStatus.ready);
  });

  test(
    'when Instagram signs the app out, notes wait and resume after sign-in',
    () async {
      final w = await _World.create();
      addTearDown(w.dispose);
      await w.sync.startFrom(await w.sync.latest(), count: 0);
      w.ig.post('3300000000000000060', caption: 'Pasta, one more time');
      final code = w.ig.codeOf('3300000000000000060');

      w.ig.signedOut = true;
      await w.sync.check(force: true);
      expect(w.sync.lastFailure, InstagramFailure.signedOut);
      expect(w.instagram.needsSignIn, isTrue);
      expect(w.instagram.isConnected, isFalse);

      // A link shared now can't be fetched: it waits, like before connecting.
      final result = await w.capture.handle(
        Incoming(texts: ['https://www.instagram.com/reel/$code/']),
      );
      expect(result.outcome, CaptureOutcome.waitingForVideo);

      // The owner signs in again in the web view.
      w.ig.signedOut = false;
      w.cookies.header = testCookieHeader;
      expect(
        await w.instagram.completeSignIn(userAgent: testUserAgent),
        isTrue,
      );
      expect(w.instagram.isConnected, isTrue);
      expect(w.instagram.username, 'nemanja.saves');
      await w.sync.afterSignIn();
      await w.settle();
      expect((await w.notes.find(result.noteId!))!.status, NoteStatus.ready);
    },
  );

  test('a challenge is never answered by the app', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    await w.sync.startFrom(await w.sync.latest(), count: 0);
    w.ig.challenge = true;
    await w.sync.check(force: true);
    expect(w.instagram.needsSignIn, isTrue);
    final calls = w.ig.requests.length;
    await w.sync.check(force: true);
    expect(w.ig.requests.length, calls, reason: 'no retries while signed out');
  });

  test('"slow down" from Instagram pauses the queue', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    w.ig.post('3300000000000000070');
    final code = w.ig.codeOf('3300000000000000070');
    w.ig.rateLimited = true;

    final result = await w.capture.handle(
      Incoming(texts: ['https://www.instagram.com/reel/$code/']),
    );
    await w.idle();
    final note = (await w.notes.find(result.noteId!))!;
    expect(note.status, NoteStatus.queued, reason: 'tried again later');

    final calls = w.ig.requests.length;
    await w.processor.kick();
    expect(w.ig.requests.length, calls, reason: 'paused');

    w.ig.rateLimited = false;
    w.clock.advance(NoteProcessor.instagramCooldown);
    await w.settle();
    expect((await w.notes.find(note.id))!.status, NoteStatus.ready);
  });

  test('a dropped connection is tried once more right away', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    w.ig.post('3300000000000000095');
    final code = w.ig.codeOf('3300000000000000095');
    var drops = 1;
    w.ig.beforeRequest = () {
      if (drops > 0) {
        drops--;
        throw http.ClientException('Software caused connection abort');
      }
    };

    final result = await w.capture.handle(
      Incoming(texts: ['https://www.instagram.com/reel/$code/']),
    );
    await w.settle();
    final note = (await w.notes.find(result.noteId!))!;
    expect(note.status, NoteStatus.ready, reason: note.errorMessage);
  });

  test(
    'a note that failed on a dropped connection is retried by itself',
    () async {
      final w = await _World.create();
      addTearDown(w.dispose);
      w.ig.post('3300000000000000090');
      final code = w.ig.codeOf('3300000000000000090');
      w.ig.offline = true;

      final result = await w.capture.handle(
        Incoming(texts: ['https://www.instagram.com/reel/$code/']),
      );
      await w.idle();
      var note = (await w.notes.find(result.noteId!))!;
      expect(note.status, NoteStatus.failed);
      expect(note.errorMessage, InstagramFailure.network.message);

      // Back online: the next successful look at Instagram retries it.
      w.ig.offline = false;
      await w.sync.startFrom(const [], count: 0);
      w.clock.advance(const Duration(minutes: 5));
      await w.sync.check();
      await w.settle();
      note = (await w.notes.find(note.id))!;
      expect(note.status, NoteStatus.ready, reason: note.errorMessage);
    },
  );

  test('without Instagram, a link waits for the video as before', () async {
    final w = await _World.create(signedIn: false);
    addTearDown(w.dispose);
    final result = await w.capture.handle(
      const Incoming(texts: ['https://www.instagram.com/reel/C9xYz12AbCd/']),
    );
    expect(result.outcome, CaptureOutcome.waitingForVideo);
    expect(await w.sync.check(force: true), 0);
    expect(w.ig.requests, isEmpty);
  });

  test('disconnecting forgets the sign-in but keeps the notes', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    await w.sync.startFrom(await w.sync.latest(), count: 0);
    w.ig.save('3300000000000000080');
    await w.sync.check(force: true);
    await w.settle();

    await w.instagram.disconnect();
    expect(w.instagram.isConnected, isFalse);
    expect(w.instagram.hasAccount, isFalse);
    expect(w.cookies.cleared, isTrue);
    expect(await w.all(), hasLength(1));
  });

  test('"Just share" leaves the Saved list alone', () async {
    var fromSaves = true;
    final w = await _World.create(enabled: () => fromSaves);
    addTearDown(w.dispose);
    await w.sync.startFrom(await w.sync.latest(), count: 0);

    fromSaves = false;
    w.ig.save('3300000000000000101');
    final before = w.ig.requests.length;
    expect(await w.sync.check(force: true), 0);
    expect(w.ig.requests.length, before, reason: 'Instagram is not asked');

    // Back to "automatic by save": what was saved meanwhile stays out, what
    // is saved from now on comes in.
    await w.sync.turnedOn();
    fromSaves = true;
    expect(await w.sync.check(force: true), 0);
    w.ig.save('3300000000000000102');
    w.clock.advance(const Duration(minutes: 5));
    expect(await w.sync.check(force: true), 1);
    await w.settle();
    final notes = await w.all();
    expect(notes, hasLength(1));
    expect(notes.single.remoteId, '3300000000000000102');
  });

  test('"No new saves" knows the latest save is already a note', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    await w.sync.startFrom(await w.sync.latest(), count: 0);
    w.ig.save('3300000000000000111');
    expect(await w.sync.check(force: true), 1);
    await w.settle();

    w.clock.advance(const Duration(minutes: 5));
    expect(await w.sync.check(force: true), 0);
    final newest = w.sync.newestSave!;
    expect(newest.post.pk, '3300000000000000111');
    expect(newest.note, isNotNull);
  });
}
