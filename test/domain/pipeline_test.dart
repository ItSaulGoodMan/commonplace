import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:commonplace/data/repositories/gemini_note_ai.dart';
import 'package:commonplace/data/repositories/instagram_repository.dart';
import 'package:commonplace/data/repositories/notes_repository.dart';
import 'package:commonplace/data/repositories/settings_repository.dart';
import 'package:commonplace/data/services/database/app_database.dart';
import 'package:commonplace/data/services/gemini_client.dart';
import 'package:commonplace/data/services/local_stores.dart';
import 'package:commonplace/data/services/video_shrinker.dart';
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
import '../helpers/fakes.dart';

class _Harness {
  _Harness._(
    this.db,
    this.notes,
    this.settings,
    this.processor,
    this.capture,
    this.requests,
    this.mediaDir,
  );

  final AppDatabase db;
  final NotesRepository notes;
  final SettingsRepository settings;
  final NoteProcessor processor;
  final Capture capture;
  final List<http.Request> requests;
  final Directory mediaDir;

  static Future<_Harness> create({
    String? key = 'AIzaTESTKEY0123456789012345678901234',
    http.Response Function(http.Request)? override,
    DateTime Function()? clock,
    http.Client? client,
    VideoShrinker? shrinker,
    bool shrinkVideos = true,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    final notes = NotesRepository(db, clock: clock);
    final settings = SettingsRepository(
      prefs: MemoryKeyValueStore(),
      secrets: memorySecretStore(key == null ? {} : {'gemini_api_key': key}),
    );
    await settings.load();
    await settings.setShrinkVideos(shrinkVideos);
    final requests = <http.Request>[];
    final mediaDir = await Directory.systemTemp.createTemp('commonplace_media');
    final media = MediaStore(baseDir: () async => mediaDir);
    // Not signed in to Instagram: these tests cover sharing by hand.
    final instagram = InstagramRepository(
      secrets: SecretStore(),
      prefs: MemoryKeyValueStore(),
      db: db,
      media: media,
      cookies: FakeWebCookies(),
      httpClient: MockClient((_) async => http.Response('', 500)),
    );
    final gemini = GeminiClient(
      httpClient:
          client ?? fakeGemini(onRequest: requests.add, override: override),
      readApiKey: settings.readGeminiKey,
      model: () => settings.geminiModel,
      baseUri: Uri.parse('https://example.test'),
    );
    final processor = NoteProcessor(
      notes: notes,
      settings: settings,
      ai: GeminiNoteAi(gemini: gemini, settings: settings),
      media: media,
      instagram: instagram,
      shrinker: shrinker,
      retryDelay: Duration.zero,
    );
    final capture = Capture(
      notes: notes,
      media: media,
      processor: processor,
      instagram: instagram,
      clock: clock,
    );
    return _Harness._(
      db,
      notes,
      settings,
      processor,
      capture,
      requests,
      mediaDir,
    );
  }

  /// Lets the fire-and-forget queue finish.
  Future<void> settle() async {
    for (
      var i = 0;
      i < 50 &&
          !processor.blockedOnKey &&
          (processor.isRunning || await notes.nextQueued() != null);
      i++
    ) {
      await processor.kick();
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<void> dispose() async {
    await db.close();
    if (await mediaDir.exists()) await mediaDir.delete(recursive: true);
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'a shared video becomes a finished note and the copy is cleaned up',
    () async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      final video = await tempFile('reel.mp4', 2048);

      final result = await h.capture.handle(Incoming(filePaths: [video.path]));
      expect(result.outcome, CaptureOutcome.queued);
      await h.settle();

      final note = (await h.notes.find(result.noteId!))!;
      expect(note.status, NoteStatus.ready);
      expect(note.title, 'Write titles like the question people search');
      expect(note.creatorHandle, 'seo.with.sam');
      expect(note.topic, 'SEO', reason: 'acronyms keep their case');
      expect(note.tags, ['titles', 'snippets']);
      expect(note.transcript, startsWith('Three SEO tips'));
      expect(note.onScreenText, hasLength(2));
      // A highlight that isn't really in its sentence is dropped, not shown wrong.
      expect(note.keyPoints[0].highlight, 'exact question people type');
      expect(note.keyPoints[1].highlight, '');
      expect(note.actions.single.text, 'Rewrite one old title as a question');
      expect(note.mediaPaths, isEmpty);
      expect(Directory('${h.mediaDir.path}/media').listSync(), isEmpty);

      // One request: the video goes inline once, and the answer has both
      // what was read and the note. Thinking is kept low (it costs output).
      expect(h.settings.lastSuccessAt, isNotNull, reason: 'Settings, Status');
      expect(h.settings.lastProblem, isNull);
      expect(h.requests, hasLength(1));
      final sent = jsonDecode(h.requests.single.body) as Map<String, Object?>;
      final parts = ((sent['contents'] as List).single as Map)['parts'] as List;
      expect((parts.first as Map)['inlineData'], isNotNull);
      final config = sent['generationConfig']! as Map<String, Object?>;
      expect(config['thinkingConfig'], {'thinkingLevel': 'LOW'});
      expect(config['maxOutputTokens'], 8192);
      expect(note.transcript, contains('exact question people type'));

      // What Gemini used, by its own count, and the price on a paid key:
      // 6000 tokens in at $0.75 and 1000 out (800 + 200 thinking) at $3.75
      // per million.
      final spend = await h.notes.watchSpendForNote(note.id).first;
      expect(spend.calls, 1);
      expect(spend.inputTokens, 6000);
      expect(spend.outputTokens, 1000);
      expect(spend.microUsd, 8250);
      expect(spend.models, ['gemini-3.8-flash']);
      final month = await h.notes
          .watchSpendSince(DateTime.now().subtract(const Duration(days: 1)))
          .first;
      expect(month.notes, 1);
      expect(month.microUsd, 8250);
    },
  );

  test('a shared link waits for its video, and the video joins it', () async {
    var now = DateTime(2026, 11, 6, 10);
    final h = await _Harness.create(clock: () => now);
    addTearDown(h.dispose);

    final saved = await h.capture.handle(
      const Incoming(
        texts: ['https://www.instagram.com/reel/C9xYz12AbCd/?igsh=abc'],
      ),
    );
    expect(saved.outcome, CaptureOutcome.waitingForVideo);
    expect(h.requests, isEmpty, reason: 'nothing to read yet, so no API call');

    final again = await h.capture.handle(
      const Incoming(texts: ['https://instagram.com/reel/C9xYz12AbCd/']),
    );
    expect(again.outcome, CaptureOutcome.alreadySaved);
    expect(again.noteId, saved.noteId);

    now = now.add(const Duration(minutes: 3));
    final video = await tempFile('download.mp4', 1024);
    final joined = await h.capture.handle(Incoming(filePaths: [video.path]));
    expect(joined.outcome, CaptureOutcome.attachedToRecent);
    expect(joined.noteId, saved.noteId);
    await h.settle();

    final note = (await h.notes.find(saved.noteId!))!;
    expect(note.status, NoteStatus.ready);
    expect(note.sourceUrl, 'https://www.instagram.com/reel/C9xYz12AbCd/');
  });

  test('a video shared long after a link starts its own note', () async {
    var now = DateTime(2026, 11, 6, 10);
    final h = await _Harness.create(clock: () => now);
    addTearDown(h.dispose);

    await h.capture.handle(
      const Incoming(texts: ['https://www.instagram.com/reel/OLD123/']),
    );
    now = now.add(const Duration(hours: 2));
    final video = await tempFile('later.mp4', 512);
    final result = await h.capture.handle(Incoming(filePaths: [video.path]));
    expect(result.outcome, CaptureOutcome.queued);
    await h.settle();
  });

  test(
    'without a key, notes wait in the queue and no request is made',
    () async {
      final h = await _Harness.create(key: null);
      addTearDown(h.dispose);

      final result = await h.capture.handle(
        const Incoming(texts: ['Tip: batch your errands on one day']),
      );
      await h.settle();

      expect((await h.notes.find(result.noteId!))!.status, NoteStatus.queued);
      expect(h.processor.blockedOnKey, isTrue);
      expect(h.requests, isEmpty);

      await h.settings.setGeminiKey('AIzaTESTKEY0123456789012345678901234');
      await h.processor.kick();
      await h.settle();
      expect((await h.notes.find(result.noteId!))!.status, NoteStatus.ready);
    },
  );

  test(
    'a rate limit fails the note with a clear message and pauses the queue',
    () async {
      final h = await _Harness.create(
        override: (_) => geminiError(429, 'RESOURCE_EXHAUSTED', 'quota'),
      );
      addTearDown(h.dispose);

      final first = await h.capture.handle(
        const Incoming(texts: ['first tip']),
      );
      await h.settle();
      // Shared during the cooldown: waits instead of hitting the limit again.
      final second = await h.capture.handle(
        const Incoming(texts: ['second tip']),
      );
      await h.processor.kick();

      final a = (await h.notes.find(first.noteId!))!;
      final b = (await h.notes.find(second.noteId!))!;
      expect(a.status, NoteStatus.failed);
      expect(a.errorMessage, AiFailure.rateLimited.message);
      // Settings, Status says exactly what Gemini answered.
      await Future<void>.delayed(Duration.zero);
      expect(h.settings.lastProblem?.message, AiFailure.rateLimited.message);
      expect(h.settings.lastProblem?.detail, contains('429'));
      expect(
        b.status,
        NoteStatus.queued,
        reason: 'the queue pauses instead of burning through',
      );
      expect(h.requests, hasLength(1));

      // Asking explicitly overrides the cooldown.
      await h.processor.retry(first.noteId!);
      await h.settle();
      expect(h.requests.length, greaterThan(1));
    },
  );

  test('rewrite replaces the AI topic but keeps one the owner chose', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);

    final r = await h.capture.handle(
      const Incoming(texts: ['A tip about titles']),
    );
    await h.settle();
    await h.db.customStatement(
      "UPDATE notes SET topic = 'Cooking' WHERE id = ${r.noteId}",
    );
    await h.processor.rewrite(r.noteId!);
    expect(
      (await h.notes.find(r.noteId!))!.topic,
      'SEO',
      reason: 'AI topics are rewritten',
    );
  });

  test('rewrite keeps a topic the owner chose', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);

    final r = await h.capture.handle(
      const Incoming(texts: ['A tip about titles']),
    );
    await h.settle();
    await h.notes.setTopic(r.noteId!, 'Writing');
    await h.processor.rewrite(r.noteId!);

    final note = (await h.notes.find(r.noteId!))!;
    expect(note.status, NoteStatus.ready);
    expect(note.topic, 'Writing');
  });

  test(
    'notes interrupted mid-read are put back in the queue on resume',
    () async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      final id = await h.notes.create(
        status: NoteStatus.processing,
        sourceKind: SourceKind.text,
        caption: 'was being read when the app closed',
      );
      await h.processor.resume();
      await h.settle();
      expect((await h.notes.find(id))!.status, NoteStatus.ready);
    },
  );

  test('the screen hears the video going up, then Gemini watching', () async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    final video = await tempFile('reel.mp4', 300 * 1024);

    final result = await h.capture.handle(Incoming(filePaths: [video.path]));
    final id = result.noteId!;
    final steps = <ReadStep>[];
    void listen() {
      final step = h.processor.readUpdateOf(id)?.step;
      if (step != null && (steps.isEmpty || steps.last != step)) {
        steps.add(step);
      }
    }

    h.processor.addListener(listen);
    await h.settle();
    h.processor.removeListener(listen);

    expect(steps, [ReadStep.sending, ReadStep.watching]);
    expect((await h.notes.find(id))!.status, NoteStatus.ready);
    expect(h.processor.readUpdateOf(id), isNull, reason: 'done');
  });

  test('a dropped connection is tried again, says so, and does not go round forever', () async {
    final h = await _Harness.create(
      override: (r) =>
          throw http.ClientException('Connection reset by peer', r.url),
    );
    addTearDown(h.dispose);
    final video = await tempFile('reel.mp4', 2048);

    final result = await h.capture.handle(Incoming(filePaths: [video.path]));
    final id = result.noteId!;
    final reasons = <String>[];
    void listen() {
      if (h.processor.retryReasonOf(id) case final why?
          when reasons.isEmpty || reasons.last != why) {
        reasons.add(why);
      }
    }

    h.processor.addListener(listen);
    await h.settle();
    h.processor.removeListener(listen);

    var note = (await h.notes.find(id))!;
    expect(note.status, NoteStatus.failed);
    expect(note.errorMessage, AiFailure.network.message);
    expect(h.requests, hasLength(2), reason: 'the first try and one more');
    expect(reasons, [
      AiFailure.network.message,
    ], reason: 'the second try shows why');
    await Future<void>.delayed(Duration.zero);
    expect(h.settings.lastProblem?.detail, contains('Connection reset'));

    // Coming back to the app, or after a look at Instagram: tried again
    // on its own, but only so often.
    for (var i = 0; i < NoteProcessor.maxAutoRetries + 2; i++) {
      await h.processor.retryTransient();
      await h.settle();
    }
    final automatic = 2 + 2 * NoteProcessor.maxAutoRetries;
    expect(h.requests, hasLength(automatic));
    note = (await h.notes.find(id))!;
    expect(note.status, NoteStatus.failed);
    expect(note.errorMessage, AiFailure.network.message);

    // Try again by hand always goes.
    await h.processor.retry(id);
    await h.settle();
    expect(h.requests, hasLength(automatic + 2));
  });

  group('Stop', () {
    test(
      'ends the wait for Gemini, and the note waits for Try again',
      () async {
        var hang = true;
        final real = fakeGemini();
        final h = await _Harness.create(
          client: MockClient((r) async {
            if (hang) return Completer<http.Response>().future;
            // A copy: a request that was sent once can't be sent again.
            final copy = http.Request(r.method, r.url)
              ..headers.addAll(r.headers)
              ..bodyBytes = r.bodyBytes;
            return http.Response.fromStream(await real.send(copy));
          }),
        );
        addTearDown(h.dispose);
        final video = await tempFile('reel.mp4', 2048);

        final result = await h.capture.handle(
          Incoming(filePaths: [video.path]),
        );
        final id = result.noteId!;
        for (
          var i = 0;
          i < 200 && h.processor.readUpdateOf(id)?.step != ReadStep.watching;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(h.processor.readUpdateOf(id)?.step, ReadStep.watching);

        h.processor.stop(id);
        await h.settle();
        var note = (await h.notes.find(id))!;
        expect(note.status, NoteStatus.failed);
        expect(note.errorMessage, WorkStopped.message);
        expect(
          h.settings.lastProblem,
          isNull,
          reason: 'stopping is no problem',
        );

        // Not tried again on its own...
        await h.processor.retryTransient();
        await h.settle();
        expect((await h.notes.find(id))!.status, NoteStatus.failed);

        // ...only when the owner asks.
        hang = false;
        await h.processor.retry(id);
        await h.settle();
        note = (await h.notes.find(id))!;
        expect(note.status, NoteStatus.ready);
      },
    );

    test('ends making the video smaller', () async {
      final shrinker = _FakeShrinker(waitForStop: true);
      final h = await _Harness.create(shrinker: shrinker);
      addTearDown(h.dispose);
      final video = await tempFile('reel.mp4', 4096);

      final result = await h.capture.handle(Incoming(filePaths: [video.path]));
      final id = result.noteId!;
      for (
        var i = 0;
        i < 200 && h.processor.stageOf(id) != ProcessingStage.shrinking;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(h.processor.stageOf(id), ProcessingStage.shrinking);
      expect(h.processor.shrinkProgressOf(id), 0.4);

      h.processor.stop(id);
      await h.settle();
      expect((await h.notes.find(id))!.errorMessage, WorkStopped.message);
      expect(h.requests, isEmpty, reason: 'nothing was sent');
    });
  });

  group('making videos smaller', () {
    test(
      'the smaller copy is what goes to Gemini, and is cleaned up',
      () async {
        final shrinker = _FakeShrinker();
        final h = await _Harness.create(shrinker: shrinker);
        addTearDown(h.dispose);
        final video = await tempFile('reel.mp4', 4096);

        final result = await h.capture.handle(
          Incoming(filePaths: [video.path]),
        );
        await h.settle();

        expect((await h.notes.find(result.noteId!))!.status, NoteStatus.ready);
        final sent = jsonDecode(h.requests.single.body) as Map<String, Object?>;
        final parts =
            ((sent['contents'] as List).single as Map)['parts'] as List;
        final data =
            ((parts.first as Map)['inlineData'] as Map)['data'] as String;
        expect(base64Decode(data), hasLength(1024), reason: 'the small copy');
        expect(File(shrinker.made.single).existsSync(), isFalse);
      },
    );

    test('can be turned off', () async {
      final shrinker = _FakeShrinker();
      final h = await _Harness.create(shrinker: shrinker, shrinkVideos: false);
      addTearDown(h.dispose);
      final video = await tempFile('reel.mp4', 4096);

      await h.capture.handle(Incoming(filePaths: [video.path]));
      await h.settle();
      expect(shrinker.made, isEmpty);
      final sent = jsonDecode(h.requests.single.body) as Map<String, Object?>;
      final parts = ((sent['contents'] as List).single as Map)['parts'] as List;
      final data =
          ((parts.first as Map)['inlineData'] as Map)['data'] as String;
      expect(base64Decode(data), hasLength(4096));
    });
  });
}

/// Stands in for Android's Transformer: writes a 1 KB "smaller" copy.
class _FakeShrinker extends VideoShrinker {
  _FakeShrinker({this.waitForStop = false});

  final bool waitForStop;
  final made = <String>[];

  @override
  Future<String?> shrink(
    String path, {
    void Function(double fraction)? onProgress,
    Future<void>? cancel,
  }) async {
    onProgress?.call(0.4);
    if (waitForStop) {
      await cancel;
      throw const WorkStopped();
    }
    final out = '$path.small.mp4';
    await File(out).writeAsBytes(List.filled(1024, 7));
    made.add(out);
    return out;
  }
}
