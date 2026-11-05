import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/admin/domain/admin_user.dart';
import 'package:lar_em_dia/features/admin/presentation/cubits/admin_cubits.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_user_detail_page.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;
  late MockAdminRepository repository;

  setUpAll(registerAdminFallbacks);

  setUp(() {
    harness = AuthHarness()..session.signedIn(rafaelAdmin);
    repository = MockAdminRepository();
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester, AdminUser user) {
    when(() => repository.user(user.id)).thenAnswer((_) async => user);
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    return pumpPage(
      tester,
      BlocProvider(
        create: (_) => started(
          AdminUserCubit(repository, user.id),
          (cubit) => cubit.load(),
        ),
        child: const AdminUserDetailPage(),
      ),
      session: harness.session,
    );
  }

  Future<void> confirm(WidgetTester tester, String action) async {
    final button = find.widgetWithText(OutlinedButton, action);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the account details of an active user', (tester) async {
    await pump(tester, carla);

    expect(find.text('Carla Lima'), findsOneWidget);
    expect(find.text('Usuário'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.textContaining('03/11/2026'), findsOneWidget);
    expect(find.textContaining('01/10/2026'), findsOneWidget);
    expect(find.text('Tornar administrador'), findsOneWidget);
    expect(find.text('Desativar conta'), findsOneWidget);
    expect(find.text('Desbloquear'), findsNothing);
    expect(find.text('Redefinir verificação em duas etapas'), findsNothing);
  });

  testWidgets('offers every recovery action for a blocked admin', (
    tester,
  ) async {
    await pump(tester, bruno);

    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Nunca'), findsOneWidget);
    for (final action in [
      'Desbloquear',
      'Redefinir verificação em duas etapas',
      'Remover administrador',
      'Reativar conta',
    ]) {
      expect(find.text(action), findsOneWidget, reason: action);
    }
  });

  testWidgets('hides the actions on the signed in admin', (tester) async {
    await pump(tester, rafaelRecord);

    expect(find.text('Rafael Souza'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('runs a confirmed action and shows the result', (tester) async {
    when(() => repository.deactivate(carla.id))
        .thenAnswer((_) async => carla.copyWith(deactivated: true));
    await pump(tester, carla);

    await confirm(tester, 'Desativar conta');

    expect(find.text('Feito.'), findsOneWidget);
    expect(find.text('Reativar conta'), findsOneWidget);
  });

  testWidgets('does nothing when the action is cancelled', (tester) async {
    await pump(tester, carla);

    await tester.tap(find.text('Tornar administrador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => repository.changeRole(any(), any()));
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('shows the error of a failed action', (tester) async {
    when(() => repository.changeRole(carla.id, UserRole.admin))
        .thenThrow(const ApiError(code: 'forbidden'));
    await pump(tester, carla);

    await confirm(tester, 'Tornar administrador');

    expect(
      find.text('Você não tem permissão para fazer isso.'),
      findsOneWidget,
    );
  });

  for (final (action, stub) in [
    (
      'Desbloquear',
      (MockAdminRepository r) =>
          when(() => r.unlock(bruno.id)).thenAnswer((_) async => bruno),
    ),
    (
      'Redefinir verificação em duas etapas',
      (MockAdminRepository r) =>
          when(() => r.resetTwoFactor(bruno.id)).thenAnswer((_) async {}),
    ),
    (
      'Remover administrador',
      (MockAdminRepository r) =>
          when(() => r.changeRole(bruno.id, UserRole.user))
              .thenAnswer((_) async => bruno),
    ),
    (
      'Reativar conta',
      (MockAdminRepository r) =>
          when(() => r.reactivate(bruno.id)).thenAnswer((_) async => bruno),
    ),
  ]) {
    testWidgets('runs $action', (tester) async {
      stub(repository);
      await pump(tester, bruno);

      await confirm(tester, action);

      expect(find.text('Feito.'), findsOneWidget);
    });
  }

  testWidgets('retries a failed load', (tester) async {
    when(() => repository.user(carla.id))
        .thenThrow(const ApiError(code: 'not_found'));
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPage(
      tester,
      BlocProvider(
        create: (_) => started(
          AdminUserCubit(repository, carla.id),
          (cubit) => cubit.load(),
        ),
        child: const AdminUserDetailPage(),
      ),
      session: harness.session,
    );

    when(() => repository.user(carla.id)).thenAnswer((_) async => carla);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Carla Lima'), findsOneWidget);
  });
}
