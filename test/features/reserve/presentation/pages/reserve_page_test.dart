import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/reserve/presentation/cubits/reserve_cubits.dart';
import 'package:lar_em_dia/features/reserve/presentation/pages/reserve_page.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/pump_page.dart';
import '../../../../helpers/reserve_fixtures.dart';

void main() {
  late AuthHarness harness;
  late MockReserveRepository repository;
  late FinanceChanges changes;
  late int notified;

  setUpAll(registerReserveFallbacks);
  setUp(() {
    harness = AuthHarness();
    repository = reserveRepositoryWith(reserveSummary);
    when(() => repository.projection(any()))
        .thenAnswer((_) async => reserveProjection);
    changes = FinanceChanges(FinanceCache());
    notified = 0;
    changes.addListener(() => notified++);
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester, {Size size = const Size(1200, 4000)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    return pumpPage(
      tester,
      BlocProvider(
        create: (_) =>
            started(ReserveCubit(repository), (cubit) => cubit.load()),
        child: const ReservePage(),
      ),
      session: harness.session,
      changes: changes,
    );
  }

  testWidgets('shows the totals, the goal, the alerts and the accounts', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Reserva de emergência'), findsOneWidget);
    expect(find.text(r'R$ 13.900,00'), findsOneWidget);
    expect(find.text(r'R$ 14.000,00'), findsOneWidget);
    expect(find.text(r'R$ 500,00'), findsOneWidget);
    expect(find.text(r'R$ 100,00'), findsOneWidget);
    expect(
      find.text(
        r'Sugestão baseada nos seus lançamentos: R$ 18.600,00, '
        r'6 meses dos seus R$ 3.100,00 de custos fixos',
      ),
      findsOneWidget,
    );
    expect(find.text('4,5 de 6 meses'), findsOneWidget);
    expect(
      find.text(r'Sua reserva está abaixo da meta de R$ 18.600,00'),
      findsOneWidget,
    );
    expect(find.text('Dinheiro em conta parada não rende'), findsOneWidget);
    expect(find.text('Tesouro Selic'), findsWidgets);
    expect(find.text('Conta parada'), findsOneWidget);
    expect(
      find.text(
        'Estimativa: Selic de 13,75% ao ano, CDI de 13,65%, '
        'sem feriados e sem IOF. Taxas de 11/11/2026.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(r'No fim do período: R$ 15.650,00 bruto, R$ 15.220,00 líquido'),
      findsOneWidget,
    );
    expect(find.textContaining('Não são recomendação'), findsOneWidget);
  });

  testWidgets('fits a narrow screen', (tester) async {
    await pump(tester, size: const Size(640, 2400));

    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an own goal and missing rates', (tester) async {
    when(repository.summary).thenAnswer(
      (_) async => reserveSummary.copyWith(
        goal: const ReserveGoal(
          months: 6,
          cents: 2000000,
          targetCents: 2000000,
        ),
        alerts: const [],
      ),
    );
    when(() => repository.projection(any())).thenAnswer(
      (_) async => ReserveProjection(
        months: [reserveProjection.months.first],
        assumptions: const ReserveAssumptions(),
      ),
    );
    await pump(tester);

    expect(find.text(r'Sua meta: R$ 20.000,00'), findsOneWidget);
    expect(find.textContaining('Taxas ainda não carregadas'), findsOneWidget);
    expect(find.textContaining('No fim do período'), findsNothing);
  });

  testWidgets('asks for fixed expenses without a suggestion', (tester) async {
    when(repository.summary).thenAnswer(
      (_) async => reserveSummary.copyWith(
        suggestion: null,
        goal: const ReserveGoal(months: 6),
        alerts: const [],
      ),
    );
    await pump(tester);

    expect(
      find.text('Lance suas contas fixas para ver uma sugestão de reserva'),
      findsOneWidget,
    );
    expect(find.textContaining('de 6 meses'), findsNothing);
  });

  testWidgets('explains the reserve when there is no account', (tester) async {
    when(repository.summary).thenAnswer((_) async => noReserve);
    await pump(tester);

    expect(find.text('Informe sua reserva de emergência'), findsOneWidget);
    expect(find.textContaining(r'R$ 3.100,00 por mês'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('Informar minha reserva'));
    await tester.pumpAndSettle();
    expect(
      find.text(routeMarker(AppRoutes.reserveAccountForm)),
      findsOneWidget,
    );
    await tester.tap(find.text(savedAndBack));
    await tester.pumpAndSettle();
    expect(notified, 1);
  });

  testWidgets('explains the reserve without fixed expenses', (tester) async {
    when(repository.summary).thenAnswer((_) async => emptyReserve);
    await pump(tester);

    expect(
      find.textContaining('dinheiro guardado para imprevistos'),
      findsOneWidget,
    );
  });

  testWidgets('switches the projection period', (tester) async {
    await pump(tester);

    await tester.tap(find.text('5 anos'));
    await tester.pumpAndSettle();

    verify(() => repository.projection(60)).called(1);
    expect(find.text('1 ano'), findsOneWidget);
  });

  testWidgets('adjusts the goal in months', (tester) async {
    when(() => repository.updateGoal(months: any(named: 'months')))
        .thenAnswer((_) async => reserveSummary);
    await pump(tester);

    await tester.tap(find.text('Ajustar meta'));
    await tester.pumpAndSettle();
    expect(find.text('6 meses de custos fixos'), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('reserve_goal_months')),
      const Offset(-2000, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 mês de custos fixos'), findsOneWidget);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    verify(() => repository.updateGoal(months: 1)).called(1);
    expect(notified, 1);
  });

  testWidgets('adjusts the goal to an amount and reports a refusal', (
    tester,
  ) async {
    when(() => repository.updateGoal(months: 6, cents: 2500000))
        .thenThrow(const ApiError(code: 'validation_failed'));
    await pump(tester);

    await tester.tap(find.text('Ajustar meta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Campo obrigatório'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('reserve_goal_amount')),
      '25.000,00',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    verify(() => repository.updateGoal(months: 6, cents: 2500000)).called(1);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(notified, 0);
  });

  testWidgets('keeps the goal when the sheet is closed', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Ajustar meta'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    verifyNever(() => repository.updateGoal(months: any(named: 'months')));
  });

  testWidgets('opens an account, a new account and a new movement', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Conta corrente').first);
    await tester.pumpAndSettle();
    expect(
      find.text(routeMarker(AppRoutes.reserveAccount(idle.id))),
      findsOneWidget,
    );
    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Novo pote'));
    await tester.pumpAndSettle();
    expect(
      find.text(routeMarker(AppRoutes.reserveAccountForm)),
      findsOneWidget,
    );
    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('route:${AppRoutes.reserveMovementForm}'),
      findsOneWidget,
    );
    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();
    expect(notified, 0);
  });

  testWidgets('retries after a failure', (tester) async {
    when(repository.summary).thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    expect(find.text('Tentar de novo'), findsOneWidget);
    when(repository.summary).thenAnswer((_) async => reserveSummary);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text(r'R$ 13.900,00'), findsOneWidget);
  });
}
