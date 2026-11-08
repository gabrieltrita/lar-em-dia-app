import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'pwa_test.dart' show pngSize;

const placeholder = '__SITE_URL__';

Directory copyWeb() {
  final target = Directory.systemTemp.createTempSync('web_');
  for (final file in [
    'index.html',
    'robots.txt',
    'sitemap.xml',
    'manifest.json',
  ]) {
    File('web/$file').copySync('${target.path}/$file');
  }
  return target;
}

ProcessResult prepare(Directory web, String siteUrl, String indexable) =>
    Process.runSync('bash', [
      'tool/prepare_web_build.sh',
      web.path,
      siteUrl,
      indexable,
    ]);

String read(Directory web, String file) =>
    File('${web.path}/$file').readAsStringSync();

void main() {
  group('index.html for search engines', () {
    final html = File('web/index.html').readAsStringSync();

    test('has a descriptive title, description and canonical URL', () {
      expect(
        html,
        contains(
          '<title>Lar em Dia: orçamento familiar '
          'e projeção do saldo</title>',
        ),
      );
      expect(html, contains('<meta name="description" content="'));
      expect(html, contains('<meta name="robots" content="index, follow">'));
      expect(html, contains('<link rel="canonical" href="$placeholder/">'));
    });

    test('previews links with Open Graph and a 1200x630 image', () {
      for (final property in [
        'og:type',
        'og:title',
        'og:description',
        'og:url',
        'og:image',
        'og:locale',
      ]) {
        expect(html, contains('<meta property="$property" content="'));
      }
      expect(
        html,
        contains(
          '<meta property="og:image" content="$placeholder/og-image.png">',
        ),
      );
      expect(
        html,
        contains('<meta name="twitter:card" content="summary_large_image">'),
      );
      expect(pngSize('web/og-image.png'), (1200, 630));
    });

    test('describes the app as a free finance web application', () {
      final json = RegExp(
        r'<script type="application/ld\+json">(.*?)</script>',
        dotAll: true,
      ).firstMatch(html)!.group(1)!;
      final data = jsonDecode(json) as Map<String, dynamic>;
      expect(data['@type'], 'WebApplication');
      expect(data['name'], 'Lar em Dia');
      expect(data['applicationCategory'], 'FinanceApplication');
      expect(data['url'], '$placeholder/');
      expect((data['offers'] as Map<String, dynamic>)['price'], '0');
    });

    test('shows readable text until the first Flutter frame', () {
      expect(html, contains('<main id="landing">'));
      expect(html, contains('<h1>Lar em Dia</h1>'));
      expect(html, contains("addEventListener('flutter-first-frame'"));
      expect(
        html.indexOf("'flutter-first-frame'"),
        lessThan(html.indexOf('flutter_bootstrap.js')),
      );
    });
  });

  group('tool/prepare_web_build.sh', () {
    test('points production at its own URL and keeps it indexable', () {
      final web = copyWeb();
      addTearDown(() => web.deleteSync(recursive: true));

      final result = prepare(web, 'https://app.example.com', 'true');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final html = read(web, 'index.html');
      expect(
        html,
        contains('<link rel="canonical" href="https://app.example.com/">'),
      );
      expect(html, contains('<meta name="robots" content="index, follow">'));
      expect(
        read(web, 'robots.txt'),
        'User-agent: *\nAllow: /\n\n'
        'Sitemap: https://app.example.com/sitemap.xml\n',
      );
      expect(
        read(web, 'sitemap.xml'),
        contains('<loc>https://app.example.com/</loc>'),
      );
      for (final file in ['index.html', 'robots.txt', 'sitemap.xml']) {
        expect(read(web, file), isNot(contains(placeholder)));
      }
    });

    test('keeps staging out of search results', () {
      final web = copyWeb();
      addTearDown(() => web.deleteSync(recursive: true));

      final result = prepare(web, 'https://staging.example.com/', 'false');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final html = read(web, 'index.html');
      expect(
        html,
        contains('<meta name="robots" content="noindex, nofollow">'),
      );
      expect(
        html,
        contains('<link rel="canonical" href="https://staging.example.com/">'),
      );
      expect(read(web, 'robots.txt'), 'User-agent: *\nAllow: /\n');
      expect(File('${web.path}/sitemap.xml').existsSync(), isFalse);
    });

    test('refuses a URL that is not https://host', () {
      final web = copyWeb();
      addTearDown(() => web.deleteSync(recursive: true));

      for (final url in ['http://app.example.com', 'https://a.com/x"y']) {
        expect(prepare(web, url, 'true').exitCode, 64);
      }
      expect(prepare(web, 'https://app.example.com', 'maybe').exitCode, 64);
      expect(read(web, 'index.html'), contains(placeholder));
    });
  });
}
