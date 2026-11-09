import 'package:lar_em_dia/core/config/env.dart';
import 'package:url_launcher/url_launcher.dart';

enum SitePage {
  privacy('privacy.html'),
  terms('terms.html'),
  accountDeletion('account-deletion.html');

  new(this.path);

  final String path;

  Uri get uri => (Env.siteUrl.isEmpty ? Uri.base : Uri.parse(Env.siteUrl))
      .resolve('/$path');
}

Future<bool> openSitePage(SitePage page) =>
    launchUrl(page.uri, mode: LaunchMode.externalApplication);
