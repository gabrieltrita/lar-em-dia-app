import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/links/site_pages.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/fake_url_launcher.dart';

void main() {
  test('resolves each page at the root of the site', () {
    expect(SitePage.values.map((page) => page.uri.path), [
      '/privacy.html',
      '/terms.html',
      '/account-deletion.html',
      '/apoie.html',
    ]);
    expect(SitePage.privacy.uri, Uri.base.resolve('/privacy.html'));
  });

  test('opens a page outside the app', () async {
    final launcher = FakeUrlLauncher.install();

    expect(await openSitePage(SitePage.terms), isTrue);

    expect(launcher.launched, [
      (SitePage.terms.uri.toString(), PreferredLaunchMode.externalApplication),
    ]);
  });
}
