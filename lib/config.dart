import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;

/// Which app this build is.
enum Edition {
  /// For the owner: their own Gemini key and Instagram sign-in. Sideloaded.
  personal,

  /// For Google Play: Sign in with Google, notes made by the Commonplace
  /// server on a shared key, Commonplace Plus for more. No Instagram sign-in.
  play,
}

/// Set with `--flavor play` or `--flavor personal`. Tests and plain
/// `flutter run` get the personal edition.
const Edition buildEdition = appFlavor == 'play'
    ? Edition.play
    : Edition.personal;

/// Settings for the Play edition, passed at build time:
///
/// ```
/// flutter build appbundle --flavor play \
///   --dart-define=API_BASE_URL=https://commonplace-api.example.workers.dev \
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=1234-abc.apps.googleusercontent.com
/// ```
abstract final class PlayConfig {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Debug builds only: made-up Google sign-in and Play purchases, for the
  /// local server (`server/`, `npm run dev`, DEV_FAKES=1).
  static const _devFakes = bool.fromEnvironment('DEV_FAKES');
  static bool get devFakes => kDebugMode && _devFakes;

  /// The subscription's product id in Play Console.
  static const plusProductId = 'commonplace_plus';

  /// Where people report a problem with a note, and the Play listing's
  /// contact address: `--dart-define=SUPPORT_EMAIL=...`.
  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

  /// The app's id on Google Play (android/app/build.gradle.kts).
  static const packageName = 'com.nemanjapejic.commonplace';

  static Uri? get apiBaseUri =>
      _apiBaseUrl.isEmpty ? null : Uri.parse(_apiBaseUrl);
}
