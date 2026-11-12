import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/cubits/projection_cubit.dart';
import 'package:lar_em_dia/features/projection/presentation/pages/projection_page.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/cash_flow_chart.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/negative_months_alert.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/finance_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;
  late MockProjectionRepository repository;

  void answer(Projection Function() value) => when(
    () => repository.fetch(
      from: any(named: 'from'),
      period: any(named: 'period'),
    ),
  ).thenAnswer((_) async => value());

  setUpAll(registerFinanceFallbacks);
  setUp(() {
    harness = AuthHarness();
    repository = MockProjectionRepository();
    answer(() => projection);
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPage(
      tester,
      BlocProvider(
        create: (_) =>
            started(ProjectionCubit(repository), (cubit) => cubit.load()),
        child: const ProjectionPage(),
      ),
      session: harness.session,
    );
  }

  Future<void> reload(WidgetTester tester) async {
    await tester
        .element(find.byType(ProjectionPage))
        .read<ProjectionCubit>()
        .load();
    await tester.pumpAndSettle();
  }

  void verifyLoads(int times) => verify(
    () => repository.fetch(
      from: any(named: 'from'),
      period: any(named: 'period'),
    ),
  ).called(times);

  testWidgets('leads with what is saved or lost and charts the months', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Até dezembro de 2026 você vai perder'), findsOneWidget);
    final context = tester.element(find.byType(ProjectionPage));
    final colors = FinanceColors.of(context);
    expect(
      tester.widget<Text>(find.text(r'R$ 2.300,00')).style?.color,
      colors.negative,
    );
    expect(
      find.text(r'Saldo previsto em dezembro de 2026: -R$ 1.065,44'),
      findsOneWidget,
    );
    expect(find.byType(CashFlowChart), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Gráfico de entradas')),
      findsOneWidget,
    );
    expect(find.text('Dezembro de 2026'), findsOneWidget);
    expect(find.text(Money.compact(370000, signed: true)), findsOneWidget);
    expect(find.text(Money.compact(-600000)), findsOneWidget);

    answer(() => projection.copyWith(months: [novemberProjection]));
    await reload(tester);

    expect(find.text('Até novembro de 2026 você vai guardar'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(r'R$ 3.700,00')).style?.color,
      colors.positive,
    );
  });

  testWidgets('selects the month under the finger', (tester) async {
    await pump(tester);

    final chart = find.byType(CashFlowChart);
    await tester.tapAt(tester.getTopLeft(chart) + const Offset(60, 100));
    await tester.pump();
    expect(find.text('Novembro de 2026'), findsOneWidget);
    expect(tester.widget<CashFlowChart>(chart).selected, 0);

    await tester.dragFrom(
      tester.getTopLeft(chart) + const Offset(60, 100),
      Offset(tester.getSize(chart).width - 70, 0),
    );
    await tester.pump();
    expect(tester.widget<CashFlowChart>(chart).selected, 1);
  });

  testWidgets('turns the series on and off, keeping one on', (tester) async {
    await pump(tester);

    await tester.tap(find.widgetWithText(FilterChip, 'Saldo'));
    await tester.pump();
    var chart = tester.widget<CashFlowChart>(find.byType(CashFlowChart));
    expect(chart.showBalance, isFalse);
    expect(
      tester
          .widget<FilterChip>(
            find.widgetWithText(FilterChip, 'Entradas e saídas'),
          )
          .onSelected,
      isNull,
    );

    await tester.tap(find.widgetWithText(FilterChip, 'Saldo'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Entradas e saídas'));
    await tester.pump();
    chart = tester.widget<CashFlowChart>(find.byType(CashFlowChart));
    expect(chart.showBalance, isTrue);
    expect(chart.showFlow, isFalse);
  });

  testWidgets('changes the period', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Tudo'));
    await tester.pumpAndSettle();

    verify(
      () => repository.fetch(
        from: any(named: 'from'),
        period: ProjectionPeriod.all,
      ),
    ).called(1);
  });

  testWidgets('adds the reserve to the balance when there is one', (
    tester,
  ) async {
    answer(
      () => projection.copyWith(
        months: [
          for (final month in projection.months)
            month.copyWith(reserveCents: 1390000),
        ],
      ),
    );
    await pump(tester);

    expect(find.text(r'Saldo + reserva: R$ 12.834,56'), findsOneWidget);
    expect(find.text('Saldo + reserva'), findsOneWidget);
    expect(find.text(r'R$ 13.900,00'), findsOneWidget);

    await tester.tap(find.text('dezembro de 2026'));
    await tester.pump();
    expect(find.text('Reserva'), findsNWidgets(2));
  });

  testWidgets('leaves the reserve out when there is none', (tester) async {
    await pump(tester);

    expect(find.textContaining('Saldo + reserva'), findsNothing);
    expect(find.text('Reserva'), findsNothing);
  });

  testWidgets('expands a month with its details', (tester) async {
    await pump(tester);

    expect(find.text(r'Fixas R$ 2.000,00'), findsNothing);
    await tester.tap(find.text('novembro de 2026'));
    await tester.pump();

    expect(find.text(r'Entrou R$ 6.500,00'), findsOneWidget);
    expect(find.text(r'Saiu R$ 2.800,00'), findsOneWidget);
    expect(find.text(r'Fixas R$ 2.000,00'), findsOneWidget);
    expect(find.text(r'Variáveis R$ 800,00'), findsOneWidget);
    expect(find.text(r'+R$ 3.700,00'), findsOneWidget);

    await tester.tap(find.text('novembro de 2026'));
    await tester.pump();
    expect(find.text(r'Fixas R$ 2.000,00'), findsNothing);
  });

  testWidgets('hides the nature bar of a month without expenses', (
    tester,
  ) async {
    answer(
      () => projection.copyWith(
        months: [
          novemberProjection.copyWith(
            expenseCents: 0,
            fixedExpenseCents: 0,
            variableExpenseCents: 0,
          ),
        ],
      ),
    );
    await pump(tester);

    await tester.tap(find.text('novembro de 2026'));
    await tester.pump();

    expect(find.byType(ColoredBox), findsNothing);
  });

  testWidgets('opens the details with the loaded projection', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Ver mais ›'));
    await tester.pumpAndSettle();

    expect(
      find.text(routeMarker(AppRoutes.projectionDetails, projection)),
      findsOneWidget,
    );
  });

  testWidgets('warns about the months that close below zero', (tester) async {
    await pump(tester);

    expect(
      find.text('Em dezembro de 2026 o saldo fica negativo.'),
      findsOneWidget,
    );

    answer(() => projection.copyWith(firstNegativeMonth: null));
    await reload(tester);
    expect(find.byType(NegativeMonthsAlert), findsNothing);
  });

  testWidgets('asks for a balance first and reloads after it', (tester) async {
    answer(() => const Projection(months: []));
    await pump(tester);

    expect(find.textContaining('Informe seu saldo'), findsOneWidget);
    answer(() => projection);
    await tester.tap(find.text('Informar saldo'));
    await tester.pumpAndSettle();
    expect(find.text(routeMarker(AppRoutes.balanceForm)), findsOneWidget);
    await tester.tap(find.text(savedAndBack));
    await tester.pumpAndSettle();

    expect(find.byType(CashFlowChart), findsOneWidget);
    verifyLoads(2);
  });

  testWidgets('retries a failed load', (tester) async {
    when(
      () => repository.fetch(
        from: any(named: 'from'),
        period: any(named: 'period'),
      ),
    ).thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    answer(() => projection);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.byType(CashFlowChart), findsOneWidget);
  });

  testWidgets('reloads on pull to refresh', (tester) async {
    await pump(tester);

    await tester.fling(find.byType(ListView), const Offset(0, 3000), 1000);
    await tester.pumpAndSettle();

    verifyLoads(2);
  });

  testWidgets('opens the simulation and reloads only after a commit', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Simular gasto'));
    await tester.pumpAndSettle();
    expect(find.text(routeMarker(AppRoutes.simulation)), findsOneWidget);
    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();
    verifyLoads(1);

    await tester.tap(find.byTooltip('Simular gasto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(savedAndBack));
    await tester.pumpAndSettle();
    verifyLoads(1);
  });
}
