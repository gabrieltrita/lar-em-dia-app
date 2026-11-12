import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/asset_detail_page.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/investment_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;
  late MockInvestmentRepository repository;
  late FinanceChanges changes;
  late int notified;

  setUpAll(registerInvestmentFallbacks);
  setUp(() {
    harness = AuthHarness();
    repository = MockInvestmentRepository();
    when(() => repository.asset('HGLG11')).thenAnswer((_) async => hglg);
    when(repository.portfolio).thenAnswer((_) async => portfolio);
    when(() => repository.transactions('HGLG11'))
        .thenAnswer((_) async => [hglgBuy, hglgSplit]);
    changes = FinanceChanges(FinanceCache());
    notified = 0;
    changes.addListener(() => notified++);
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 4800);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPage(
      tester,
      BlocProvider(
        create: (_) => started(
          AssetDetailCubit(repository, 'HGLG11'),
          (cubit) => cubit.load(),
        ),
        child: const AssetDetailPage(),
      ),
      session: harness.session,
      changes: changes,
    );
  }

  testWidgets('shows the asset, the position and the transactions', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('PATRIA LOG FII'), findsOneWidget);
    expect(find.text('FII · Logística'), findsOneWidget);
    expect(find.text(r'R$ 160,00 em 11/11/2026'), findsOneWidget);
    expect(find.text(r'R$ 150,50'), findsOneWidget);
    expect(find.text(r'R$ 1.505,00'), findsOneWidget);
    expect(find.text(r'+R$ 95,00'), findsOneWidget);
    expect(find.text('+6,31%'), findsOneWidget);
    expect(find.text('Lucro realizado'), findsNothing);
    expect(find.text('Desdobramento · 10 cotas'), findsOneWidget);
    expect(find.text('Compra · 10 cotas'), findsOneWidget);
    expect(
      find.text(r'05/10/2026 · R$ 150,00 por cota · no saldo'),
      findsOneWidget,
    );
  });

  testWidgets('shows a sold out asset without position', (tester) async {
    when(repository.portfolio).thenAnswer((_) async => emptyPortfolio);
    when(() => repository.asset('HGLG11'))
        .thenAnswer((_) async => petr.copyWith(ticker: 'HGLG11'));
    when(() => repository.transactions('HGLG11')).thenAnswer((_) async => []);
    await pump(tester);

    expect(find.text('Ação'), findsOneWidget);
    expect(find.text('sem cotação'), findsOneWidget);
    expect(find.byKey(const Key('asset_goal')), findsNothing);
    expect(find.text('Nenhuma operação deste papel.'), findsOneWidget);
  });

  testWidgets('changes the goal and tells the other screens', (tester) async {
    when(() => repository.updateGoal('HGLG11', InvestmentGoal.growth))
        .thenAnswer((_) async {});
    await pump(tester);

    await tester.tap(find.text('Crescimento'));
    await tester.pumpAndSettle();

    verify(() => repository.updateGoal('HGLG11', InvestmentGoal.growth))
        .called(1);
    expect(notified, 1);
  });

  testWidgets('explains a refused deletion', (tester) async {
    when(() => repository.delete(hglgBuy))
        .thenThrow(const ApiError(code: 'insufficient_quantity'));
    await pump(tester);

    await tester.tap(find.byTooltip('Mais opções').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir operação?'), findsOneWidget);
    expect(find.textContaining('Compra de 05/10/2026'), findsOneWidget);
    await tester.tap(find.text('Apagar').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ficaria sem cotas suficientes'),
      findsOneWidget,
    );
    expect(notified, 0);
  });

  testWidgets('deletes after confirming and keeps it when cancelled', (
    tester,
  ) async {
    when(() => repository.delete(hglgSplit)).thenAnswer((_) async {});
    await pump(tester);

    await tester.tap(find.byTooltip('Mais opções').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.delete(any()));

    await tester.tap(find.byTooltip('Mais opções').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar').last);
    await tester.pumpAndSettle();

    verify(() => repository.delete(hglgSplit)).called(1);
    expect(notified, 1);
  });

  testWidgets('opens the form to edit or register', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Compra · 10 cotas'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('route:${AppRoutes.investmentForm}'),
      findsOneWidget,
    );
    await tester.tap(find.text(savedAndBack));
    await tester.pumpAndSettle();
    expect(notified, 1);

    await tester.tap(find.text('Registrar operação'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('route:${AppRoutes.investmentForm}'),
      findsOneWidget,
    );
  });

  testWidgets('shows the FII report and its CVM income', (tester) async {
    when(() => repository.asset('HGLG11'))
        .thenAnswer((_) async => hglgWithIncome);
    await pump(tester);

    expect(find.text('Informe mensal de setembro de 2026'), findsOneWidget);
    expect(find.text(r'R$ 165,4766'), findsOneWidget);
    expect(find.text('0,97'), findsOneWidget);
    expect(find.text('613.837'), findsOneWidget);
    expect(find.text(r'Rendimento · R$ 1,1669'), findsOneWidget);
    expect(
      find.text('Data com 30/09/2026 · pago no mês seguinte'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('distribution_add')), findsNothing);
  });

  testWidgets('says when an FII has no income in the period', (tester) async {
    await pump(tester);

    expect(find.textContaining('rendimentos informados'), findsOneWidget);
  });

  group('a stock in the portfolio', () {
    setUp(() {
      when(() => repository.asset('HGLG11')).thenAnswer(
        (_) async => itsa.copyWith(ticker: 'HGLG11', distributions: [itsaJcp]),
      );
      when(repository.portfolio).thenAnswer(
        (_) async => portfolio.copyWith(
          positions: [itsaPosition.copyWith(ticker: 'HGLG11')],
        ),
      );
    });

    testWidgets('lists its distributions and opens the form', (tester) async {
      await pump(tester);

      expect(find.text(r'JCP · R$ 0,2833'), findsOneWidget);
      expect(
        find.text('Data com 20/08/2026 · pago em 25/11/2026'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('distribution_add')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('route:${AppRoutes.distributionForm}'),
        findsOneWidget,
      );
      await tester.tap(find.text(closedAndBack));
      await tester.pumpAndSettle();
      expect(notified, 0);

      await tester.tap(find.text(r'JCP · R$ 0,2833'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(savedAndBack));
      await tester.pumpAndSettle();
      expect(notified, 1);
    });

    testWidgets('deletes a distribution after confirming', (tester) async {
      when(() => repository.deleteDistribution(itsaJcp))
          .thenAnswer((_) async {});
      await pump(tester);

      await tester.tap(find.byTooltip('Mais opções').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apagar'));
      await tester.pumpAndSettle();
      expect(find.text('Excluir provento?'), findsOneWidget);
      await tester.tap(find.text('Apagar').last);
      await tester.pumpAndSettle();

      verify(() => repository.deleteDistribution(itsaJcp)).called(1);
      expect(notified, 1);
    });

    testWidgets('invites to record the first distribution', (tester) async {
      when(() => repository.asset('HGLG11'))
          .thenAnswer((_) async => itsa.copyWith(ticker: 'HGLG11'));
      await pump(tester);

      expect(find.textContaining('Nenhum provento registrado'), findsOneWidget);
    });
  });

  testWidgets('retries a failed load', (tester) async {
    when(() => repository.asset('HGLG11'))
        .thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);
    expect(find.text('Registrar operação'), findsNothing);

    when(() => repository.asset('HGLG11')).thenAnswer((_) async => hglg);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('PATRIA LOG FII'), findsOneWidget);
  });
}
