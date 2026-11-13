import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/investment_form_page.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/investments_page.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/investment_fixtures.dart';
import '../../../../helpers/pump_page.dart';
import '../../../../helpers/reserve_fixtures.dart';

void main() {
  late AuthHarness harness;
  late MockInvestmentRepository repository;
  late FinanceChanges changes;
  late int notified;

  setUp(() {
    harness = AuthHarness();
    repository = MockInvestmentRepository();
    when(repository.portfolio).thenAnswer((_) async => portfolio);
    when(repository.history).thenAnswer((_) async => history);
    when(repository.income).thenAnswer((_) async => noIncome);
    changes = FinanceChanges(FinanceCache());
    notified = 0;
    changes.addListener(() => notified++);
  });
  tearDown(() => harness.dispose());

  Future<void> pump(
    WidgetTester tester, {
    ReserveSummary reserveCard = emptyReserve,
  }) async {
    tester.view.physicalSize = const Size(2400, 4800);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPage(
      tester,
      withReserveCard(
        BlocProvider(
          create: (_) =>
              started(PortfolioCubit(repository), (cubit) => cubit.load()),
          child: const InvestmentsPage(),
        ),
        summary: reserveCard,
      ),
      session: harness.session,
      changes: changes,
    );
  }

  testWidgets('opens the reserve from the top card', (tester) async {
    await pump(tester, reserveCard: reserveSummary);

    expect(find.byKey(const Key('reserve_card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reserve_card')));
    await tester.pumpAndSettle();
    expect(find.text(routeMarker(AppRoutes.reserve)), findsOneWidget);
  });

  testWidgets('introduces the reserve on an empty portfolio', (tester) async {
    when(repository.portfolio).thenAnswer((_) async => emptyPortfolio);
    await pump(tester, reserveCard: noReserve);

    expect(find.textContaining('cobre imprevistos'), findsOneWidget);
  });

  testWidgets('shows the summary, the goal split and the positions', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Patrimônio'), findsOneWidget);
    expect(find.text(r'R$ 2.600,00'), findsOneWidget);
    expect(find.text(r'R$ 2.580,00'), findsOneWidget);
    expect(find.text(r'-R$ 5,00'), findsOneWidget);
    expect(find.text('−0,19%'), findsOneWidget);
    expect(find.text('Lucro realizado'), findsOneWidget);
    expect(find.textContaining('Renda 61,54%'), findsOneWidget);
    expect(find.textContaining('Crescimento 38,46%'), findsOneWidget);
    expect(find.text('HGLG11  PATRIA LOG FII'), findsOneWidget);
    expect(
      find.text(r'10 cotas · PM R$ 150,50 · R$ 160,00 em 11/11/2026'),
      findsOneWidget,
    );
    expect(find.text('+6,31%'), findsOneWidget);
    expect(find.textContaining('sem cotação'), findsOneWidget);
    expect(find.textContaining('Não são recomendação'), findsOneWidget);
  });

  testWidgets('filters the positions by goal', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Crescimento').first);
    await tester.pumpAndSettle();
    expect(find.text('HGLG11  PATRIA LOG FII'), findsNothing);
    expect(find.text('ITSA4  ITAUSA'), findsOneWidget);

    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(find.text('HGLG11  PATRIA LOG FII'), findsOneWidget);
  });

  testWidgets('says when no position has the chosen goal', (tester) async {
    when(repository.portfolio)
        .thenAnswer((_) async => portfolio.copyWith(positions: [hglgPosition]));
    await pump(tester);

    await tester.tap(find.text('Crescimento').first);
    await tester.pumpAndSettle();

    expect(find.text('Nenhum papel com este objetivo.'), findsOneWidget);
  });

  testWidgets('opens a position, the evolution and the form', (tester) async {
    await pump(tester);

    await tester.tap(find.text('HGLG11  PATRIA LOG FII'));
    await tester.pumpAndSettle();
    expect(
      find.text(routeMarker(AppRoutes.assetDetail('HGLG11'))),
      findsOneWidget,
    );
    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ver tudo'));
    await tester.pumpAndSettle();
    expect(find.text(routeMarker(AppRoutes.investmentHistory)), findsOneWidget);
    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrar operação'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('route:${AppRoutes.investmentForm}'),
      findsOneWidget,
    );
    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();
    expect(notified, 0);

    await tester.tap(find.text('Registrar operação'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(savedAndBack));
    await tester.pumpAndSettle();
    expect(notified, 1);
  });

  testWidgets('summarizes the passive income and opens it', (tester) async {
    when(repository.income).thenAnswer((_) async => passiveIncome);
    await pump(tester);

    expect(find.text(r'Média de R$ 12,50 por mês'), findsOneWidget);
    expect(find.text(r'Previsão para o próximo mês: R$ 11,67'), findsOneWidget);
    await tester.tap(find.byKey(const Key('investments_income')));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.passiveIncome)), findsOneWidget);
  });

  testWidgets('opens the screener and the simulators', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('investments_explore')));
    await tester.pumpAndSettle();
    expect(find.text(routeMarker(AppRoutes.explore)), findsOneWidget);
    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('investments_simulator')));
    await tester.pumpAndSettle();
    expect(
      find.text(routeMarker(AppRoutes.investmentSimulator)),
      findsOneWidget,
    );
  });

  testWidgets('hides the income card without income', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('investments_income')), findsNothing);
  });

  testWidgets('explains the tab when there is nothing yet', (tester) async {
    when(repository.portfolio).thenAnswer((_) async => emptyPortfolio);
    when(repository.history).thenAnswer((_) async => []);
    await pump(tester);

    expect(find.text('Acompanhe seus investimentos'), findsOneWidget);
    expect(find.text('Registrar operação'), findsNothing);

    await tester.tap(find.text('Registrar compra'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('route:${AppRoutes.investmentForm}'),
      findsOneWidget,
    );
    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Já tenho investimentos'));
    await tester.pumpAndSettle();
    final marker = tester.widget<Text>(
      find.textContaining('route:${AppRoutes.investmentForm}'),
    );
    expect(marker.data, contains('InvestmentFormArgs'));
  });

  testWidgets('retries a failed load', (tester) async {
    when(repository.portfolio).thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    when(repository.portfolio).thenAnswer((_) async => portfolio);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Patrimônio'), findsOneWidget);
  });

  test('passes the held quantities to the form', () {
    const args = InvestmentFormArgs(held: {'HGLG11': 10});
    expect(args.held['HGLG11'], 10);
    expect(args.existingHoldings, isFalse);
  });
}
