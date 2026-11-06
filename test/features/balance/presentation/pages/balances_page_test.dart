import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/balance/presentation/cubits/balance_cubits.dart';
import 'package:lar_em_dia/features/balance/presentation/pages/balances_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/finance_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;
  late MockBalanceRepository repository;

  setUp(() {
    harness = AuthHarness();
    repository = MockBalanceRepository();
    when(repository.list).thenAnswer((_) async => [balance]);
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester) => pumpPage(
    tester,
    BlocProvider(
      create: (_) =>
          started(BalancesCubit(repository), (cubit) => cubit.load()),
      child: const BalancesPage(),
    ),
    session: harness.session,
  );

  testWidgets('lists the balances', (tester) async {
    when(repository.list).thenAnswer(
      (_) async => [
        balance,
        balance.copyWith(id: 'balance-0', asOf: DateTime(2026, 10)),
      ],
    );
    await pump(tester);

    expect(find.text(r'R$ 1.234,56'), findsNWidgets(2));
    expect(find.text('03/11/2026'), findsOneWidget);
    expect(find.text('01/10/2026'), findsOneWidget);
  });

  testWidgets('says when there is no balance', (tester) async {
    when(repository.list).thenAnswer((_) async => []);
    await pump(tester);

    expect(find.text('Nenhum saldo informado ainda.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Informar saldo'));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.balanceForm)), findsOneWidget);
  });

  testWidgets('retries a failed load', (tester) async {
    when(repository.list).thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    when(repository.list).thenAnswer((_) async => [balance]);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text(r'R$ 1.234,56'), findsOneWidget);
  });

  testWidgets('opens the form to edit and reloads after saving', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text(r'R$ 1.234,56'));
    await tester.pumpAndSettle();
    expect(
      find.text(routeMarker(AppRoutes.balanceForm, balance)),
      findsOneWidget,
    );
    await tester.tap(find.text(savedAndBack));
    await tester.pumpAndSettle();

    verify(repository.list).called(2);
  });

  testWidgets('does not reload when the form is closed', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Informar saldo'));
    await tester.pumpAndSettle();
    expect(find.text(routeMarker(AppRoutes.balanceForm)), findsOneWidget);
    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();

    verify(repository.list).called(1);
  });

  testWidgets('deletes after confirmation', (tester) async {
    when(() => repository.delete('balance-1')).thenAnswer((_) async {});
    await pump(tester);

    await tester.tap(find.byTooltip('Apagar'));
    await tester.pumpAndSettle();
    expect(find.text('O saldo de 03/11/2026 será apagado.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await tester.pumpAndSettle();

    verify(() => repository.delete('balance-1')).called(1);
  });

  testWidgets('keeps the balance when the deletion is cancelled', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Apagar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => repository.delete(any()));
  });

  testWidgets('shows a failed deletion', (tester) async {
    when(() => repository.delete('balance-1'))
        .thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    await tester.tap(find.byTooltip('Apagar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível conectar. Verifique sua internet.'),
      findsOneWidget,
    );
  });
}
