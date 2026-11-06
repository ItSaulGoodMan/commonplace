import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'app.dart';
import 'config.dart';
import 'data/repositories/account_repository.dart';
import 'data/repositories/gemini_note_ai.dart';
import 'data/repositories/instagram_repository.dart';
import 'data/repositories/key_check.dart';
import 'data/repositories/notes_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/background_work.dart';
import 'data/services/billing.dart';
import 'data/services/commonplace_api.dart';
import 'data/services/database/app_database.dart';
import 'data/services/exchange_rates.dart';
import 'data/services/gemini_client.dart';
import 'data/services/google_auth.dart';
import 'data/services/local_stores.dart';
import 'data/services/share_inbox.dart';
import 'data/services/video_shrinker.dart';
import 'data/services/web_cookies.dart';
import 'domain/models/ai.dart';
import 'domain/use_cases/capture.dart';
import 'domain/use_cases/note_processor.dart';
import 'domain/use_cases/saved_sync.dart';
import 'ui/core/media_picker.dart';

/// Debug builds only: point the app at a local mock of the Gemini API with
/// `--dart-define=GEMINI_BASE_URL=http://10.0.2.2:8787`. Release builds
/// always talk to Google.
const _debugGeminiBaseUrl = String.fromEnvironment('GEMINI_BASE_URL');

/// Debug builds only: a local mock of instagram.com,
/// `--dart-define=INSTAGRAM_BASE_URL=http://10.0.2.2:8788`.
const _debugInstagramBaseUrl = String.fromEnvironment('INSTAGRAM_BASE_URL');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const edition = buildEdition;

  final prefs = await PreferencesStore.open();
  final secrets = SecretStore();
  final settings = SettingsRepository(prefs: prefs, secrets: secrets);
  await settings.load();

  final db = AppDatabase();
  final notes = NotesRepository(db);
  final media = MediaStore();
  final httpClient = http.Client();
  final instagram = InstagramRepository(
    secrets: secrets,
    prefs: prefs,
    db: db,
    media: media,
    cookies: WebCookies(),
    httpClient: httpClient,
    baseUri: kDebugMode && _debugInstagramBaseUrl.isNotEmpty
        ? Uri.parse(_debugInstagramBaseUrl)
        : null,
  );
  await instagram.load();

  // The Play edition's account. The personal edition never signs in, so
  // this stays empty there.
  final api = CommonplaceApi(
    httpClient: httpClient,
    baseUri: edition == Edition.play ? PlayConfig.apiBaseUri : null,
    readSession: secrets.readSession,
  );
  final account = AccountRepository(
    api: api,
    secrets: secrets,
    google: PlayConfig.devFakes
        ? DevGoogleAuth()
        : PlayServicesGoogleAuth(
            serverClientId: PlayConfig.googleServerClientId,
          ),
    billing: edition != Edition.play
        ? FakeBilling()
        : PlayConfig.devFakes
        ? FakeBilling()
        : PlayBilling(),
  );
  if (edition == Edition.play) await account.load();

  final gemini = GeminiClient(
    httpClient: httpClient,
    readApiKey: settings.readGeminiKey,
    model: () => settings.geminiModel,
    baseUri: kDebugMode && _debugGeminiBaseUrl.isNotEmpty
        ? Uri.parse(_debugGeminiBaseUrl)
        : null,
  );
  final keyCheck = KeyCheck(gemini: gemini, settings: settings);
  final NoteAi ai = switch (edition) {
    Edition.play => CloudNoteAi(
      api: api,
      account: account,
      mimeTypeFor: MediaStore.mimeTypeFor,
    ),
    Edition.personal => GeminiNoteAi(settings: settings, gemini: gemini),
  };
  final processor = NoteProcessor(
    notes: notes,
    settings: settings,
    ai: ai,
    media: media,
    instagram: instagram,
    shrinker: VideoShrinker(),
  );
  // While notes are being made, keep running when the owner leaves the app.
  final background = BackgroundWork();
  var working = false;
  processor.addListener(() {
    if (processor.isWorking && !working) {
      working = true;
      unawaited(background.start('Making your note'));
      if (!settings.askedForNotifications) {
        unawaited(settings.setAskedForNotifications());
        unawaited(background.askForNotifications());
      }
    } else if (!processor.isWorking && working) {
      working = false;
      unawaited(background.stop());
    }
  });

  // Signing in, or a new day's notes, lets waiting notes go.
  account.addListener(() {
    if (processor.blockedBy != null && ai.blocked == null) {
      unawaited(processor.kick());
    }
  });
  final capture = Capture(
    notes: notes,
    media: media,
    processor: processor,
    instagram: instagram,
  );
  final savedSync = SavedSync(
    instagram: instagram,
    notes: notes,
    processor: processor,
    enabled: () => settings.notesFromSaves,
  );
  final inbox = ShareInbox();
  final initialShare = await inbox.start();

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: edition),
        Provider.value(value: ai),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: processor),
        ChangeNotifierProvider.value(value: instagram),
        ChangeNotifierProvider.value(value: savedSync),
        ChangeNotifierProvider.value(value: account),
        ChangeNotifierProvider.value(value: keyCheck),
        Provider.value(value: notes),
        Provider.value(value: capture),
        Provider.value(value: MediaPicker()),
      ],
      child: CommonplaceApp(inbox: inbox, initialShare: initialShare),
    ),
  );

  unawaited(processor.resume());
  // New saves on Instagram since last time (personal edition only).
  if (edition == Edition.personal) unawaited(savedSync.check());
  // For showing what each note would cost in euros (personal edition).
  if (edition == Edition.personal) {
    unawaited(settings.refreshUsdPerEur(EcbRates(httpClient).usdPerEur));
  }
}
