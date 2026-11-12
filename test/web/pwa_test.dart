import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

(int, int) pngSize(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  group('Web app manifest', () {
    final manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    test('names the app and opens standalone in the theme color', () {
      expect(manifest['name'], 'Lar em Dia');
      expect(manifest['short_name'], 'Lar em Dia');
      expect(manifest['lang'], 'pt-BR');
      expect(manifest['display'], 'standalone');
      expect(manifest['start_url'], '.');
      expect(manifest['scope'], '.');
      expect(manifest['id'], '/');
      expect(manifest['categories'], ['finance']);
      expect(manifest['theme_color'], '#5F6FD6');
      expect(manifest['background_color'], '#5F6FD6');
    });

    test('lists icons that exist with the declared sizes', () {
      final icons = (manifest['icons'] as List).cast<Map<String, dynamic>>();
      expect(icons.where((icon) => icon['purpose'] == 'maskable'), isNotEmpty);
      for (final icon in icons) {
        final size = int.parse((icon['sizes'] as String).split('x').first);
        expect(pngSize('web/${icon['src']}'), (size, size));
      }
    });
  });

  group('index.html', () {
    final html = File('web/index.html').readAsStringSync();

    test('has the iOS home screen title, icon and standalone mode', () {
      expect(
        html,
        contains(
          '<meta name="apple-mobile-web-app-title" content="Lar em Dia">',
        ),
      );
      expect(
        html,
        contains('<meta name="apple-mobile-web-app-capable" content="yes">'),
      );
      expect(
        html,
        contains(
          '<link rel="apple-touch-icon" sizes="180x180" '
          'href="icons/Icon-180.png">',
        ),
      );
      expect(pngSize('web/icons/Icon-180.png'), (180, 180));
      expect(html, contains('<link rel="manifest" href="manifest.json">'));
    });
  });
}
