import 'dart:io';

import 'package:commonplace/data/repositories/account_repository.dart';
import 'package:commonplace/data/repositories/instagram_repository.dart';
import 'package:commonplace/data/repositories/notes_repository.dart';
import 'package:commonplace/data/repositories/settings_repository.dart';
import 'package:commonplace/data/services/billing.dart';
import 'package:commonplace/data/services/commonplace_api.dart';
import 'package:commonplace/data/services/database/app_database.dart';
import 'package:commonplace/data/services/google_auth.dart';
import 'package:commonplace/data/services/local_stores.dart';
import 'package:commonplace/domain/models/ai.dart';
import 'package:commonplace/domain/models/note.dart';
import 'package:commonplace/domain/use_cases/capture.dart';
import 'package:commonplace/domain/use_cases/note_processor.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../helpers/fake_instagram.dart';
import '../helpers/fake_server.dart';
import '../helpers/fakes.dart';

/// The Play edition minus the UI: notes made by the (fake) server.
class _World {
  _World._(
    this.db,
    this.notes,
    this.account,
    this.processor,
    this.capture,
    this.server,
    this.billing,
    this.mediaDir,
  );

  final AppDatabase db;
  final NotesRepository notes;
  final AccountRepository account;
  final NoteProcessor processor;
  final Capture capture;
  final FakeServer server;
  final FakeBilling billing;
  final Directory mediaDir;

  static Future<_World> create() async {
    final db = AppDatabase(NativeDatabase.memory());
    final notes = NotesRepository(db);
    final secrets = memorySecretStore();
    final prefs = MemoryKeyValueStore();
    final settings = SettingsRepository(prefs: prefs, secrets: secrets);
    await settings.load();
    final mediaDir = await Directory.systemTemp.createTemp('commonplace_cloud');
    final media = MediaStore(baseDir: () async => mediaDir);
    final server = FakeServer();
    final billing = FakeBilling();
    final api = CommonplaceApi(
      httpClient: server.client,
      baseUri: Uri.parse('https://api.test'),
      readSession: secrets.readSession,
    );
    final account = AccountRepository(
      api: api,
      secrets: secrets,
      google: DevGoogleAuth(),
      billing: billing,
    );
    await account.load();
    final instagram = InstagramRepository(
      secrets: secrets,
      prefs: prefs,
      db: db,
      media: media,
      cookies: FakeWebCookies(),
      httpClient: MockClient((_) async => http.Response('', 500)),
    );
    final processor = NoteProcessor(
      notes: notes,
      settings: settings,
      ai: CloudNoteAi(
        api: api,
        account: account,
        mimeTypeFor: MediaStore.mimeTypeFor,
      ),
      media: media,
      instagram: instagram,
      retryDelay: Duration.zero,
    );
    final capture = Capture(
      notes: notes,
      media: media,
      processor: processor,
      instagram: instagram,
    );
    return _World._(
      db,
      notes,
      account,
      processor,
      capture,
      server,
      billing,
      mediaDir,
    );
  }

  Future<void> idle() async {
    for (var i = 0; i < 200 && processor.isRunning; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<Note> addVideo() async {
    final video = await tempFile('reel.mp4', 4096);
    final result = await capture.handle(Incoming(filePaths: [video.path]));
    await idle();
    return (await notes.find(result.noteId!))!;
  }

  Future<void> dispose() async {
    await idle();
    await db.close();
    if (await mediaDir.exists()) await mediaDir.delete(recursive: true);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('signed out, a saved video waits and nothing is sent', () async {
    final w = await _World.create();
    addTearDown(w.dispose);

    final note = await w.addVideo();
    expect(note.status, NoteStatus.queued);
    expect(w.processor.blockedBy, AiFailure.signedOut);
    expect(w.server.requests, isEmpty);
  });

  test('after Sign in with Google, the server makes the note', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    final waiting = await w.addVideo();

    expect(await w.account.signIn(), isTrue);
    expect(w.account.account?.email, 'tester@example.com');
    await w.processor.kick();
    await w.idle();

    final note = (await w.notes.find(waiting.id))!;
    expect(note.status, NoteStatus.ready, reason: note.errorMessage);
    expect(note.title, 'Salt pasta water like the sea');
    expect(note.creatorHandle, 'cook.with.ana');

    final upload = w.server.calls('/v1/files').single;
    expect(upload.headers['Content-Type'], 'video/mp4');
    expect(upload.bodyBytes, hasLength(4096));
    expect(upload.headers['Authorization'], 'Bearer session-1');
    // One request makes the note; nothing is written separately.
    final made = w.server.calls('/v1/note').single.body;
    expect(made, contains('"files":["files/f1"]'));
    expect(w.server.calls('/v1/write'), isEmpty);
    expect(w.server.calls('/v1/extract'), isEmpty);
    expect(note.transcript, contains('Salt the pasta water'));
    expect(w.server.notesToday, 1);
  });

  test("when today's notes are used up, the rest wait for tomorrow", () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    await w.account.signIn();
    w.server.mode = 'daily_limit';

    final note = await w.addVideo();
    expect(note.status, NoteStatus.queued);
    expect(w.processor.blockedBy, AiFailure.dailyLimit);
    await w.account.refresh();
    expect(w.account.blocked, AiFailure.dailyLimit);

    // Nothing more is tried today.
    final calls = w.server.requests.length;
    await w.addVideo();
    expect(w.server.requests.length, calls);
  });

  test('when the shared free AI time is used up, notes wait', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    await w.account.signIn();
    w.server.mode = 'shared_limit';

    final note = await w.addVideo();
    expect(note.status, NoteStatus.queued);
    expect(w.account.blocked, AiFailure.sharedLimit);
    expect(w.account.sharedLimitUntil, isNotNull);
  });

  test('an expired session signs out and the note waits for sign-in', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    await w.account.signIn();
    w.server.mode = 'signed_out';

    final note = await w.addVideo();
    expect(note.status, NoteStatus.queued);
    expect(w.account.signedIn, isFalse);
    expect(w.processor.blockedBy, AiFailure.signedOut);

    w.server.mode = 'ok';
    await w.account.signIn();
    await w.processor.kick();
    await w.idle();
    expect((await w.notes.find(note.id))!.status, NoteStatus.ready);
  });

  test(
    'a busy server is tried once more, then the note can be retried',
    () async {
      final w = await _World.create();
      addTearDown(w.dispose);
      await w.account.signIn();
      w.server.mode = 'busy';

      final note = await w.addVideo();
      expect(note.status, NoteStatus.failed);
      expect(w.server.calls('/v1/note'), hasLength(2));

      w.server.mode = 'ok';
      await w.processor.retry(note.id);
      await w.idle();
      expect((await w.notes.find(note.id))!.status, NoteStatus.ready);
    },
  );

  test('buying Plus is checked by the server, tied to the account', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    await w.account.signIn();

    final offer = await w.account.plusOffer();
    expect(offer?.price, r'$2.99');
    await w.account.buyPlus(offer!);
    for (var i = 0; i < 50 && w.server.lastPurchaseToken == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(
      w.server.lastPurchaseToken,
      startsWith('fake-${FakeServer.accountRef}-'),
    );
    expect(w.account.account?.isPlus, isTrue);
    expect(w.account.account?.notesPerDay, 25);
    expect(w.account.purchaseProblem, isNull);
  });

  test('deleting the account signs out', () async {
    final w = await _World.create();
    addTearDown(w.dispose);
    await w.account.signIn();
    await w.account.deleteAccount();
    expect(w.account.signedIn, isFalse);
    expect(w.server.requests.last.method, 'DELETE');
  });
}
