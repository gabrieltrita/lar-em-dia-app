import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/investments/domain/simulation.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/simulator_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/investment_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;
  late MockInvestmentRepository repository;

  setUpAll(registerInvestmentFallbacks);

  setUp(() {
    harness = AuthHarness();
    repository = MockInvestmentRepository();
    when(() => repository.simulateIncome(any()))
        .thenAnswer((_) async => incomeSimulation);
    when(() => repository.simulateGrowth(any()))
        .thenAnswer((_) async => growthSimulation);
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPage(
      tester,
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => IncomeSimulatorCubit(repository)),
          BlocProvider(create: (_) => GrowthSimulatorCubit(repository)),
        ],
        child: const SimulatorPage(),
      ),
      session: harness.session,
    );
  }

  Future<void> run(WidgetTester tester) async {
    await tester.tap(find.text('Simular'));
    await tester.pumpAndSettle();
  }

  IncomeSimulationInput incomeSent() =>
      verify(() => repository.simulateIncome(captureAny())).captured.last
          as IncomeSimulationInput;

  testWidgets('simulates the income of an asset towards a target', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byKey(const Key('income_ticker')), 'hglg11');
    await tester.enterText(find.byKey(const Key('income_initial')), '100000');
    await tester.enterText(find.byKey(const Key('income_monthly')), '15000');
    await tester.enterText(find.byKey(const Key('income_years')), '2');
    await tester.enterText(find.byKey(const Key('income_target')), '1000');
    await run(tester);

    expect(incomeSent(), incomeInput);
    expect(
      find.text(r'Preço R$ 100,00 · rendimento por cota R$ 1,00 ao mês'),
      findsOneWidget,
    );
    expect(find.text(r'R$ 48,00'), findsWidgets);
    expect(find.text('48 cotas ao final'), findsOneWidget);
    expect(
      find.text(
        r'Para R$ 10,00 por mês: 10 cotas, ou R$ 1.000,00 investidos hoje',
      ),
      findsOneWidget,
    );
    expect(find.text('Meta atingida no mês 1'), findsOneWidget);
    expect(find.text('Ano 1'), findsOneWidget);
    expect(find.text('Ano 2'), findsOneWidget);
    expect(find.textContaining('não garantem resultados futuros'), findsOne);
  });

  testWidgets('simulates a monthly yield without reinvesting', (tester) async {
    when(() => repository.simulateIncome(any())).thenAnswer(
      (_) async => const IncomeSimulation(
        reinvest: false,
        monthlyYieldBps: 80,
        capitalForTargetCents: 1250000,
        targetMonthlyIncomeCents: 10000,
        months: [
          IncomeSimulationMonth(
            month: 7,
            contributedCents: 100000,
            valueCents: 100000,
            incomeCents: 800,
            receivedCents: 5600,
          ),
        ],
      ),
    );
    await pump(tester);

    await tester.enterText(find.byKey(const Key('income_yield')), '0,8');
    await tester.enterText(find.byKey(const Key('income_initial')), '100000');
    await tester.enterText(find.byKey(const Key('income_target')), '10000');
    await tester.tap(find.byKey(const Key('income_reinvest')));
    await run(tester);

    expect(
      incomeSent(),
      const IncomeSimulationInput(
        months: 120,
        initialCents: 100000,
        monthlyYieldBps: 80,
        reinvest: false,
        targetMonthlyIncomeCents: 10000,
      ),
    );
    expect(
      find.text(r'Para R$ 100,00 por mês: R$ 12.500,00 investidos hoje'),
      findsOneWidget,
    );
    expect(find.text('A meta não é atingida no prazo simulado'), findsOne);
    expect(find.textContaining('cotas ao final'), findsNothing);
    expect(find.text('Ano 1'), findsOneWidget);
  });

  testWidgets('checks the income inputs before simulating', (tester) async {
    await pump(tester);

    await tester.enterText(find.byKey(const Key('income_years')), '0');
    await tester.enterText(find.byKey(const Key('income_yield')), 'x');
    await tester.enterText(find.byKey(const Key('income_initial')), 'abc');
    await run(tester);
    expect(find.text('Informe de 1 a 50 anos'), findsOneWidget);
    expect(find.text('Informe um percentual válido'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('income_years')), '10');
    await tester.enterText(find.byKey(const Key('income_yield')), '');
    await tester.enterText(find.byKey(const Key('income_initial')), '');
    await run(tester);
    expect(find.text('Informe um papel ou o rendimento mensal'), findsOne);

    await tester.enterText(find.byKey(const Key('income_ticker')), 'XXXX11');
    await run(tester);
    expect(find.text('Informe o valor inicial ou o aporte mensal'), findsOne);
    verifyNever(() => repository.simulateIncome(any()));

    when(() => repository.simulateIncome(any())).thenThrow(
      const ApiError(
        code: 'validation_failed',
        details: {
          'ticker': [FieldError(code: 'no_income_data')],
        },
      ),
    );
    await tester.enterText(find.byKey(const Key('income_monthly')), '10000');
    await run(tester);
    expect(
      find.textContaining('Esse papel ainda não tem cotação'),
      findsOneWidget,
    );
  });

  testWidgets('compounds contributions at the chosen rate', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Crescimento'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simular'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um percentual válido'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('growth_rate')), '12');
    await tester.enterText(find.byKey(const Key('growth_years')), '1');
    await run(tester);
    expect(find.text('Informe o valor inicial ou o aporte mensal'), findsOne);

    await tester.enterText(find.byKey(const Key('growth_initial')), '100000');
    await tester.enterText(find.byKey(const Key('growth_monthly')), '10000');
    await run(tester);

    verify(() => repository.simulateGrowth(growthInput)).called(1);
    expect(find.text('Equivale a 0,95% ao mês'), findsOneWidget);
    expect(find.text(r'R$ 2.384,65'), findsWidgets);
    expect(find.text(r'R$ 184,65'), findsOneWidget);
    expect(find.text('Ano 1'), findsOneWidget);

    when(() => repository.simulateGrowth(any()))
        .thenThrow(const ApiError(code: 'network_error'));
    await run(tester);
    expect(find.byKey(const Key('growth_result')), findsNothing);

    await tester.tap(find.text('Renda'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('income_ticker')), findsOneWidget);
  });
}
