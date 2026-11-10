import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const headersPath = 'deploy/security-headers.conf';
const includeLine = 'include /etc/nginx/security-headers.conf;';

String read(String path) => File(path).readAsStringSync();

String cspOf(String headers) =>
    RegExp('Content-Security-Policy "([^"]+)"').firstMatch(headers)!.group(1)!;

String directive(String csp, String name) => csp
    .split(';')
    .map((part) => part.trim())
    .firstWhere((part) => part.startsWith('$name '));

File copyHeaders() {
  final target = File(
    '${Directory.systemTemp.createTempSync('headers_').path}/headers.conf',
  );
  File(headersPath).copySync(target.path);
  return target;
}

ProcessResult prepare(File headers, String apiBaseUrl) => Process.runSync(
  'bash',
  ['tool/prepare_web_headers.sh', headers.path, apiBaseUrl],
);

void main() {
  group('nginx', () {
    final nginx = read('deploy/nginx.conf');
    final headers = read(headersPath);

    test('hides its version and sends the headers on every response', () {
      expect(nginx, contains('server_tokens off;'));
      expect(includeLine.allMatches(nginx), hasLength(2));
      final cached = RegExp(r'location ~ [^{]+\{([^}]+)\}')
          .firstMatch(nginx)!
          .group(1)!;
      expect(cached, contains(includeLine));
      expect(cached, contains('Cache-Control'));
    });

    test('sends every security header, even on errors', () {
      for (final header in [
        'Content-Security-Policy',
        'Strict-Transport-Security',
        'X-Frame-Options',
        'X-Content-Type-Options',
        'Referrer-Policy',
        'Permissions-Policy',
      ]) {
        expect(
          RegExp('add_header $header "[^"]+" always;').hasMatch(headers),
          isTrue,
          reason: header,
        );
      }
    });

    test('has a CSP that blocks framing, plugins and injected scripts', () {
      final csp = cspOf(headers);

      expect(directive(csp, 'frame-ancestors'), "frame-ancestors 'none'");
      expect(directive(csp, 'object-src'), "object-src 'none'");
      expect(directive(csp, 'base-uri'), "base-uri 'self'");
      final scripts = directive(csp, 'script-src');
      expect(scripts, isNot(contains("'unsafe-inline'")));
      expect(scripts, isNot(contains("'unsafe-eval'")));
      expect(directive(csp, 'connect-src'), contains('__API_ORIGIN__'));
    });

    test('runs a current nginx with the headers file', () {
      final dockerfile = read('Dockerfile');

      expect(dockerfile, contains('FROM nginx:1.28-alpine'));
      expect(
        dockerfile,
        contains('COPY $headersPath /etc/nginx/security-headers.conf'),
      );
    });

    test('serves no inline script the CSP would block', () {
      final html = read('web/index.html');
      final inline = RegExp(r'<script(?![^>]*\bsrc=)([^>]*)>')
          .allMatches(html)
          .map((match) => match.group(1)!.trim());

      expect(inline, everyElement('type="application/ld+json"'));
      expect(html, contains('<script src="landing.js"></script>'));
      expect(read('web/landing.js'), contains('flutter-first-frame'));
    });
  });

  group('tool/prepare_web_headers.sh', () {
    test('fills the API origin into the CSP', () {
      final headers = copyHeaders();
      addTearDown(() => headers.parent.deleteSync(recursive: true));

      final result = prepare(headers, 'https://api.example.com/api/v1');

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final csp = cspOf(headers.readAsStringSync());
      expect(
        directive(csp, 'connect-src'),
        contains("'self' https://api.example.com "),
      );
      expect(csp, isNot(contains('__API_ORIGIN__')));
    });

    test('keeps a port and accepts a URL without a path', () {
      final headers = copyHeaders();
      addTearDown(() => headers.parent.deleteSync(recursive: true));

      expect(prepare(headers, 'https://api.example.com:8443').exitCode, 0);
      expect(
        headers.readAsStringSync(),
        contains('https://api.example.com:8443 '),
      );
    });

    test('refuses an API that is not on https', () {
      final headers = copyHeaders();
      addTearDown(() => headers.parent.deleteSync(recursive: true));

      final result = prepare(headers, 'http://api.example.com/api/v1');

      expect(result.exitCode, 64);
      expect(headers.readAsStringSync(), contains('__API_ORIGIN__'));
    });
  });

  test('keeps the Android app out of device backups', () {
    final manifest = read('android/app/src/main/AndroidManifest.xml');

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
  });
}
