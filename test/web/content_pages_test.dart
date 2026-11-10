import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const contentPages = [
  'guias.html',
  'calculadora-fim-do-mes.html',
  'calculadora-juros-compostos.html',
  'planilha-orcamento-familiar.html',
  'guia-orcamento-familiar.html',
  'guia-13-salario.html',
  'guia-contas-de-janeiro.html',
];

const placeholder = '__SITE_URL__';

String read(String path) => File('web/$path').readAsStringSync();

Map<String, dynamic> structuredData(String html) {
  final json = RegExp(
    r'<script type="application/ld\+json">(.*?)</script>',
    dotAll: true,
  ).firstMatch(html)!.group(1)!;
  return jsonDecode(json) as Map<String, dynamic>;
}

void main() {
  final pages = {for (final page in contentPages) page: read(page)};

  test('every content page is a pt-BR document ready for search', () {
    pages.forEach((page, html) {
      expect(html, startsWith('<!DOCTYPE html>\n<html lang="pt-BR">'));
      expect(html, contains('<meta charset="UTF-8">'));
      expect(html, contains('name="viewport"'));
      expect(html, contains('| Lar em Dia</title>'));
      expect(html, contains('<meta name="description" content="'));
      expect(html, contains('<meta name="robots" content="index, follow">'));
      expect(
        html,
        contains('<link rel="canonical" href="$placeholder/$page">'),
      );
      expect(
        html,
        contains('<meta property="og:url" content="$placeholder/$page">'),
      );
      expect(html, contains('<link rel="stylesheet" href="conteudo.css">'));
      expect(structuredData(html)['inLanguage'], 'pt-BR');
    });
  });

  test('every content page invites to the app and links the others', () {
    pages.forEach((page, html) {
      expect(html, contains('<aside class="cta">'), reason: page);
      expect(html, contains('<a class="button" href="/">'), reason: page);
      expect(html, contains('mailto:contato@trita.dev'), reason: page);
      expect(html, contains('href="guias.html"'), reason: page);
    });
    for (final page in contentPages.skip(1)) {
      expect(pages['guias.html'], contains('href="$page"'));
    }
  });

  test('scripts are local modules, never inline code', () {
    pages.forEach((page, html) {
      final scripts = RegExp('<script([^>]*)>').allMatches(html);
      for (final script in scripts) {
        final attributes = script.group(1)!;
        if (attributes.contains('application/ld+json')) continue;
        expect(
          attributes,
          matches(RegExp(r' type="module" src="js/[a-z-]+\.js"')),
        );
        expect(
          File(
            'web/${RegExp('src="([^"]+)"').firstMatch(attributes)!.group(1)}',
          ).existsSync(),
          isTrue,
        );
      }
    });
  });

  test('calculators are described as free finance tools', () {
    for (final page in [
      'calculadora-fim-do-mes.html',
      'calculadora-juros-compostos.html',
    ]) {
      final data = structuredData(pages[page]!);
      expect(data['@type'], 'WebApplication');
      expect(data['applicationCategory'], 'FinanceApplication');
      expect((data['offers'] as Map<String, dynamic>)['price'], '0');
    }
  });

  test('guides are articles', () {
    for (final page in contentPages.where((page) => page.startsWith('guia-'))) {
      expect(structuredData(pages[page]!)['@type'], 'Article');
    }
  });

  test('the compound interest page warns it is not advice', () {
    expect(
      pages['calculadora-juros-compostos.html'],
      contains('Não é recomendação de investimento'),
    );
  });

  test('the spreadsheet download is a real xlsx file', () {
    expect(
      pages['planilha-orcamento-familiar.html'],
      contains('href="planilha-orcamento-familiar.xlsx" download'),
    );
    final bytes = File('web/planilha-orcamento-familiar.xlsx')
        .readAsBytesSync();
    expect(bytes.sublist(0, 4), [0x50, 0x4B, 0x03, 0x04]);
    expect(latin1.decode(bytes), contains('xl/workbook.xml'));
  });

  test('the sitemap lists every content page', () {
    final sitemap = read('sitemap.xml');
    for (final page in contentPages) {
      expect(sitemap, contains('<loc>$placeholder/$page</loc>'));
    }
  });

  test('the landing text links the guides', () {
    expect(read('index.html'), contains('<a href="guias.html">'));
  });
}
