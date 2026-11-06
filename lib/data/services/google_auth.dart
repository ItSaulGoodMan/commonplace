import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';

/// "Sign in with Google": gets an ID token the server can check.
abstract interface class GoogleAuth {
  /// Shows Google's account picker. Null when the person backs out.
  Future<String?> idToken();

  Future<void> signOut();
}

/// The real thing: Android's Credential Manager offers the Google accounts
/// already on the phone, so signing in is usually one tap.
class PlayServicesGoogleAuth implements GoogleAuth {
  PlayServicesGoogleAuth({required this.serverClientId});

  /// The OAuth "Web application" client ID the server accepts tokens for.
  final String serverClientId;

  Future<void>? _initialized;

  Future<void> _init() => _initialized ??= GoogleSignIn.instance.initialize(
    serverClientId: serverClientId,
  );

  @override
  Future<String?> idToken() async {
    await _init();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _init();
    await GoogleSignIn.instance.signOut();
  }
}

/// Debug builds against the local server only (DEV_FAKES): a made-up
/// account the server accepts when its own DEV_FAKES is on.
class DevGoogleAuth implements GoogleAuth {
  DevGoogleAuth({this.email = 'tester@example.com', this.name = 'Test Person'});

  final String email;
  final String name;

  @override
  Future<String?> idToken() async =>
      'dev:${jsonEncode({'sub': email, 'email': email, 'name': name})}';

  @override
  Future<void> signOut() async {}
}
