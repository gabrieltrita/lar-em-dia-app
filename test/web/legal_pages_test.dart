import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/links/site_pages.dart';

void main() {
  final pages = {
    for (final page in SitePage.values)
      page: File('web/${page.path}').readAsStringSync(),
  };

  test('every page is a standalone pt-BR document for phones', () {
    for (final html in pages.values) {
      expect(html, startsWith('<!DOCTYPE html>\n<html lang="pt-BR">'));
      expect(html, contains('<meta charset="UTF-8">'));
      expect(html, contains('name="viewport"'));
      expect(html, contains('<meta name="description" content="'));
      expect(html, contains('prefers-color-scheme: dark'));
      expect(html, isNot(contains('<script')));
    }
  });

  test('every page names the app, a contact and links the others', () {
    for (final html in pages.values) {
      expect(html, contains('| Lar em Dia</title>'));
      expect(html, contains('mailto:contato@trita.dev'));
      for (final page in SitePage.values) {
        expect(html, contains('href="${page.path}"'));
      }
    }
  });

  test('the privacy policy covers what the stores ask for', () {
    final html = pages[SitePage.privacy]!;
    for (final topic in [
      'LGPD',
      'Quais dados usamos',
      'Login com Google',
      'Com quem compartilhamos',
      'Por quanto tempo guardamos',
      'Os seus direitos',
      'Excluir conta',
    ]) {
      expect(html, contains(topic));
    }
  });

  test('the account deletion page explains the steps and what is kept', () {
    final html = pages[SitePage.accountDeletion]!;
    for (final topic in [
      'Pelo app',
      'Sem acesso ao app',
      'Apagados na hora',
      'Mantidos',
    ]) {
      expect(html, contains(topic));
    }
  });

  test('the sitemap lists every page', () {
    final sitemap = File('web/sitemap.xml').readAsStringSync();
    for (final page in SitePage.values) {
      expect(sitemap, contains('<loc>__SITE_URL__/${page.path}</loc>'));
    }
  });
}
