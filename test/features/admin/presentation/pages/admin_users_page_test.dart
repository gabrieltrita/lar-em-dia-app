import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/admin/domain/admin_user.dart';
import 'package:lar_em_dia/features/admin/presentation/cubits/admin_cubits.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_users_page.dart';
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

  void answerPage(int page, List<AdminUser> users, {int? next}) => when(
    () => repository.users(
      page: page,
      email: any(named: 'email'),
      status: any(named: 'status'),
    ),
  ).thenAnswer((_) async => AdminUserPage(users: users, nextPage: next));

  void failPage(int page, ApiError error) => when(
    () => repository.users(
      page: page,
      email: any(named: 'email'),
      status: any(named: 'status'),
    ),
  ).thenThrow(error);

  Future<void> pump(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    return pumpPage(
      tester,
      BlocProvider(
        create: (_) =>
            started(AdminUsersCubit(repository), (cubit) => cubit.load()),
        child: const AdminUsersPage(),
      ),
      session: harness.session,
    );
  }

  testWidgets('lists the users with their badges', (tester) async {
    answerPage(1, [carla, bruno]);
    await pump(tester);

    expect(find.text('Carla Lima'), findsOneWidget);
    expect(find.text('carla@example.com'), findsOneWidget);
    expect(find.text('Bruno Dias'), findsOneWidget);
    for (final badge in ['Admin', 'Desativado', 'Bloqueado', '2FA']) {
      expect(find.text(badge), findsOneWidget, reason: badge);
    }
    expect(find.text('Carregar mais'), findsNothing);
  });

  testWidgets('shows an empty list', (tester) async {
    answerPage(1, []);
    await pump(tester);

    expect(find.text('Nenhum usuário encontrado.'), findsOneWidget);
  });

  testWidgets('explains the missing second factor and retries', (tester) async {
    failPage(1, const ApiError(code: 'two_factor_setup_required'));
    await pump(tester);

    expect(
      find.text(
        'Ative a verificação em duas etapas para acessar a administração.',
      ),
      findsOneWidget,
    );

    answerPage(1, [carla]);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('Carla Lima'), findsOneWidget);
  });

  testWidgets('searches by email and filters by status', (tester) async {
    answerPage(1, [carla]);
    await pump(tester);

    await tester.enterText(
      find.byKey(const Key('admin_search_email')),
      'carla@example.com',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    verify(() => repository.users(page: 1, email: 'carla@example.com'))
        .called(1);

    await tester.tap(find.text('Desativados'));
    await tester.pumpAndSettle();
    verify(
      () => repository.users(
        page: 1,
        email: 'carla@example.com',
        status: AccountStatus.deactivated,
      ),
    ).called(1);
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Desativados'),
    );
    expect(chip.selected, isTrue);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    verify(() => repository.users(page: 1, email: 'carla@example.com'))
        .called(1);
  });

  testWidgets('loads more users', (tester) async {
    final pending = Completer<AdminUserPage>();
    answerPage(1, [carla], next: 2);
    when(
      () => repository.users(
        page: 2,
        email: any(named: 'email'),
        status: any(named: 'status'),
      ),
    ).thenAnswer((_) => pending.future);
    await pump(tester);

    await tester.tap(find.text('Carregar mais'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(AdminUserPage(users: [bruno]));
    await tester.pumpAndSettle();
    expect(find.text('Bruno Dias'), findsOneWidget);
    expect(find.text('Carregar mais'), findsNothing);
  });

  testWidgets('shows the error when more users fail', (tester) async {
    answerPage(1, [carla], next: 2);
    failPage(2, const ApiError(code: 'rate_limited'));
    await pump(tester);

    await tester.tap(find.text('Carregar mais'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Carregar mais'), findsOneWidget);
  });

  testWidgets('opens a user and reloads on return', (tester) async {
    answerPage(1, [carla]);
    await pump(tester);

    await tester.tap(find.text('Carla Lima'));
    await tester.pumpAndSettle();
    expect(
      find.text(routeMarker(AppRoutes.adminUser(carla.id))),
      findsOneWidget,
    );

    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();
    verify(() => repository.users(page: 1, email: '')).called(2);
  });

  testWidgets('reloads on pull to refresh', (tester) async {
    answerPage(1, [carla]);
    await pump(tester);

    await tester.fling(find.text('Carla Lima'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    verify(() => repository.users(page: 1, email: '')).called(2);
  });
}
