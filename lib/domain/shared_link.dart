/// Finds and normalises links in text that people share into the app.
///
/// Instagram's share sheet sends text like
/// `https://www.instagram.com/reel/C9xYz12AbCd/?igsh=MWQ1ZGUxMzBkMA==`,
/// sometimes with the caption or other words around it.
class SharedLink {
  const SharedLink({
    required this.url,
    required this.isInstagram,
    this.instagramKind,
    this.shortcode,
  });

  /// The cleaned link (tracking parameters removed for Instagram).
  final String url;
  final bool isInstagram;

  /// `reel`, `p` (post) or `tv`, for Instagram links.
  final String? instagramKind;
  final String? shortcode;

  static final _urlPattern = RegExp(
    r'https?://[^\s<>"]+',
    caseSensitive: false,
  );

  static final _instagramPattern = RegExp(
    r'^https?://(?:www\.|m\.)?(?:instagram\.com|instagr\.am)/(?:[A-Za-z0-9_.]+/)?(reels?|p|tv)/([A-Za-z0-9_-]+)',
    caseSensitive: false,
  );

  /// Returns the first link in [text], or null if there is none.
  static SharedLink? find(String text) {
    final match = _urlPattern.firstMatch(text);
    if (match == null) return null;
    final raw = _trimTrailingPunctuation(match.group(0)!);

    final ig = _instagramPattern.firstMatch(raw);
    if (ig != null) {
      var kind = ig.group(1)!.toLowerCase();
      if (kind == 'reels') kind = 'reel';
      final code = ig.group(2)!;
      return SharedLink(
        url: 'https://www.instagram.com/$kind/$code/',
        isInstagram: true,
        instagramKind: kind,
        shortcode: code,
      );
    }
    return SharedLink(url: raw, isInstagram: false);
  }

  /// [text] with the link removed, tidied, or null if nothing meaningful is left.
  static String? textWithoutLink(String text) {
    final rest = text
        .replaceAll(_urlPattern, ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return rest.length < 3 ? null : rest;
  }

  static String _trimTrailingPunctuation(String url) {
    var u = url;
    while (u.isNotEmpty && '.,;:!?)]}\'"'.contains(u[u.length - 1])) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  @override
  String toString() => 'SharedLink($url)';
}
