import 'package:flutter/services.dart';

/// Reads the cookies the in-app web view holds (Android `CookieManager`).
///
/// Used once, right after the owner signs in to Instagram in the web view.
class WebCookies {
  static const _channel = MethodChannel('commonplace/web_cookies');

  /// The `Cookie` header the web view would send to [url], or null.
  Future<String?> read(Uri url) =>
      _channel.invokeMethod<String>('get', {'url': url.toString()});

  /// Signs the web view out of everything.
  Future<void> clear() => _channel.invokeMethod<void>('clear');
}
