import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/links/site_pages.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:lar_em_dia/features/shell/presentation/more_page.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/fake_url_launcher.dart';
import '../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;

  setUp(() => harness = AuthHarness());
  tearDown(() => harness.dispose());

  Future<void> pump(
    WidgetTester tester,
    AuthUser user, {
    MorePage page = const MorePage(),
  }) {
    harness.session.signedIn(user);
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    return pumpPage(tester, page, session: harness.session);
  }

  testWidgets('shows the user and opens the finance and account pages', (
    tester,
  ) async {
    await pump(tester, ana.copyWith(lastName: 'Souza'));

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.text('Gerenciar usuários'), findsNothing);
    expect(find.text('Apoie o Lar em Dia'), findsNothing);

    for (final (label, route) in [
      ('Saldo e histórico', AppRoutes.balances),
      ('Vencimentos', AppRoutes.due),
      ('Distribuir sobra do mês', AppRoutes.allocation),
      ('Segurança', AppRoutes.account),
      ('Alertas de vencimento', AppRoutes.notificationSettings),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(routeMarker(route)), findsOneWidget);
      await tester.tap(find.text(closedAndBack));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('opens the administration for admins', (tester) async {
    await pump(tester, ana.copyWith(role: UserRole.admin));

    for (final (label, route) in [
      ('Gerenciar usuários', AppRoutes.adminUsers),
      ('Métricas de uso', AppRoutes.adminMetrics),
      ('Categorias', AppRoutes.adminCategories),
    ]) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text(routeMarker(route)), findsOneWidget);
      await tester.tap(find.text(closedAndBack));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('opens the support page outside the app on the web', (
    tester,
  ) async {
    final launcher = FakeUrlLauncher.install();
    await pump(tester, ana, page: const MorePage(showSupport: true));

    await tester.tap(find.text('Apoie o Lar em Dia'));
    await tester.pumpAndSettle();

    expect(launcher.launched, [
      (
        SitePage.support.uri.toString(),
        PreferredLaunchMode.externalApplication,
      ),
    ]);
  });

  testWidgets('shows the copyright and the app version', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Lar em Dia',
      packageName: 'dev.trita.laremdia',
      version: '1.2.3',
      buildNumber: '45',
      buildSignature: '',
    );
    await pump(tester, ana);

    expect(find.text('© ${DateTime.now().year} Lar em Dia'), findsOneWidget);
    expect(find.text('Versão 1.2.3 (45)'), findsOneWidget);
  });

  testWidgets('logs out', (tester) async {
    when(harness.repository.logout).thenAnswer((_) async {});
    await pump(tester, ana);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    verify(harness.repository.logout).called(1);
  });
}
