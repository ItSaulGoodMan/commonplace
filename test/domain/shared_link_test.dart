import 'package:commonplace/domain/shared_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SharedLink.find', () {
    test('cleans an Instagram reel link and drops tracking parameters', () {
      final link = SharedLink.find(
        'https://www.instagram.com/reel/C9xYz12AbCd/?igsh=MWQ1ZGUxMzBkMA==',
      )!;
      expect(link.isInstagram, isTrue);
      expect(link.instagramKind, 'reel');
      expect(link.shortcode, 'C9xYz12AbCd');
      expect(link.url, 'https://www.instagram.com/reel/C9xYz12AbCd/');
    });

    test('normalises /reels/, posts, m. and username-prefixed paths', () {
      expect(
        SharedLink.find('https://instagram.com/reels/ABC_123-x/')!.url,
        'https://www.instagram.com/reel/ABC_123-x/',
      );
      expect(
        SharedLink.find('http://m.instagram.com/p/Cs9iEotsiGY')!.url,
        'https://www.instagram.com/p/Cs9iEotsiGY/',
      );
      expect(
        SharedLink.find('https://www.instagram.com/seo.sam/reel/DA1b2C3/')!.url,
        'https://www.instagram.com/reel/DA1b2C3/',
      );
    });

    test('finds the link inside surrounding text', () {
      final link = SharedLink.find(
        'Check this out: https://www.instagram.com/reel/XYZ987/?utm_source=ig_web. So good',
      )!;
      expect(link.shortcode, 'XYZ987');
    });

    test('keeps other links as they are, minus trailing punctuation', () {
      final link = SharedLink.find('see https://example.com/tips?a=1).')!;
      expect(link.isInstagram, isFalse);
      expect(link.url, 'https://example.com/tips?a=1');
    });

    test('returns null when there is no link', () {
      expect(SharedLink.find('just a caption, no url'), isNull);
    });
  });

  group('SharedLink.textWithoutLink', () {
    test('keeps the caption around a link', () {
      expect(
        SharedLink.textWithoutLink(
          '3 SEO tips\nhttps://www.instagram.com/reel/XYZ987/',
        ),
        '3 SEO tips',
      );
    });

    test('returns null when only the link was shared', () {
      expect(
        SharedLink.textWithoutLink('https://www.instagram.com/reel/XYZ987/ '),
        isNull,
      );
    });
  });
}
