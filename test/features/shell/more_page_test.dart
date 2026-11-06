import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:lar_em_dia/features/shell/presentation/more_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;

  setUp(() => harness = AuthHarness());
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester, AuthUser user) {
    harness.session.signedIn(user);
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    return pumpPage(tester, const MorePage(), session: harness.session);
  }

  testWidgets('shows the user and opens the finance and account pages', (
    tester,
  ) async {
    await pump(tester, ana.copyWith(lastName: 'Souza'));

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.text('Gerenciar usuários'), findsNothing);

    for (final (label, route) in [
      ('Saldo e histórico', AppRoutes.balances),
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

  testWidgets('logs out', (tester) async {
    when(harness.repository.logout).thenAnswer((_) async {});
    await pump(tester, ana);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    verify(harness.repository.logout).called(1);
  });
}
