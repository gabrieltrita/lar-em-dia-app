import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/cubits/simulation_cubit.dart';
import 'package:lar_em_dia/features/projection/presentation/pages/simulation_page.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/negative_months_alert.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/finance_fixtures.dart';

void main() {
  late MockProjectionRepository projections;
  late MockEntryRepository entries;
  late List<Object?> popped;
  const failure = ApiError(code: ApiError.networkErrorCode);

  void simulateWith(Future<ProjectionComparison> Function() answer) => when(
    () => projections.simulate(
      any(),
      from: any(named: 'from'),
      months: any(named: 'months'),
    ),
  ).thenAnswer((_) => answer());

  setUpAll(registerFinanceFallbacks);

  setUp(() {
    projections = MockProjectionRepository();
    entries = MockEntryRepository();
    popped = [];
    simulateWith(() async => comparison);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => TextButton(
            onPressed: () async =>
                popped.add(await context.push<bool>(AppRoutes.simulation)),
            child: const Text('open'),
          ),
        ),
        GoRoute(
          path: AppRoutes.simulation,
          builder: (_, _) => BlocProvider(
            create: (_) => SimulationCubit(projections, entries),
            child: const SimulationPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.simulationEntry(EntryKind.expense),
          builder: (context, _) => TextButton(
            onPressed: () => context.pop(tvPlan),
            child: const Text('plan TV'),
          ),
        ),
        GoRoute(
          path: AppRoutes.simulationEntry(EntryKind.income),
          builder: (context, _) => TextButton(
            onPressed: () => context.pop(),
            child: const Text('close form'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  SimulationCubit cubitOf(WidgetTester tester) =>
      tester.element(find.byType(SimulationPage)).read<SimulationCubit>();

  Future<void> addTv(WidgetTester tester) async {
    await tester.tap(find.text('Adicionar despesa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('plan TV'));
    await tester.pumpAndSettle();
  }

  testWidgets('starts empty, without actions', (tester) async {
    await pump(tester);

    expect(find.textContaining('Nada é gravado'), findsOneWidget);
    expect(find.text('Efetivar'), findsNothing);

    await tester.tap(find.text('Adicionar receita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('close form'));
    await tester.pumpAndSettle();

    expect(cubitOf(tester).state.plans, isEmpty);
    verifyNever(
      () => projections.simulate(
        any(),
        from: any(named: 'from'),
        months: any(named: 'months'),
      ),
    );
  });

  testWidgets('compares the projections after adding a plan', (tester) async {
    await pump(tester);

    await addTv(tester);

    expect(find.text('TV'), findsOneWidget);
    expect(find.text(r'R$ 3.000,00 · 05/12/2026'), findsOneWidget);
    expect(find.byType(NegativeMonthsAlert), findsOneWidget);
    expect(find.text('No fim de dezembro de 2026'), findsOneWidget);
    expect(find.text(r'Atual: -R$ 1.065,44'), findsOneWidget);
    expect(find.text(r'Simulado: -R$ 4.065,44'), findsOneWidget);
    final difference = find.text(r'Diferença: -R$ 3.000,00');
    final context = tester.element(difference);
    expect(
      tester.widget<Text>(difference).style?.color,
      Theme.of(context).colorScheme.error,
    );
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(2));
    expect(find.text('Atual'), findsOneWidget);
    expect(find.text('Simulado'), findsOneWidget);
  });

  testWidgets('describes series, removes plans and stops at ten', (
    tester,
  ) async {
    simulateWith(
      () async => ProjectionComparison(
        baseline: projection.copyWith(firstNegativeMonth: null),
        simulated: projection.copyWith(firstNegativeMonth: null),
      ),
    );
    await pump(tester);
    final cubit = cubitOf(tester);
    await cubit.add(freelancePlan);
    await cubit.add(sofaPlan);
    await tester.pumpAndSettle();

    expect(find.textContaining('3 vezes · A cada 3 meses'), findsOneWidget);
    expect(find.textContaining('4x'), findsOneWidget);
    expect(find.byType(NegativeMonthsAlert), findsNothing);
    final difference = find.text(r'Diferença: R$ 0,00');
    expect(
      tester.widget<Text>(difference).style?.color,
      isNot(Theme.of(tester.element(difference)).colorScheme.error),
    );

    await tester.tap(find.byTooltip('Remover').first);
    await tester.pumpAndSettle();
    expect(find.text('Freelance'), findsNothing);
    await tester.tap(find.byTooltip('Remover'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nada é gravado'), findsOneWidget);

    for (var i = 0; i < SimulationState.maxPlans; i++) {
      await cubit.add(tvPlan);
    }
    await tester.pumpAndSettle();
    expect(find.text('Limite de 10 itens por simulação.'), findsOneWidget);
    expect(find.text('Adicionar despesa'), findsNothing);
  });

  testWidgets('shows a loading state and retries a failed simulation', (
    tester,
  ) async {
    final pending = Completer<ProjectionComparison>();
    simulateWith(() => pending.future);
    await pump(tester);

    await tester.tap(find.text('Adicionar despesa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('plan TV'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(failure);
    await tester.pumpAndSettle();
    expect(find.byType(RetryMessage), findsOneWidget);

    simulateWith(() async => comparison);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('commits and returns true', (tester) async {
    when(() => entries.create(any())).thenAnswer((_) async => groceries);
    await pump(tester);
    await addTv(tester);

    await tester.tap(find.text('Efetivar'));
    await tester.pumpAndSettle();

    verify(() => entries.create(tvPlan.draft)).called(1);
    expect(popped, [true]);
  });

  testWidgets('keeps the plan and explains a failed commit', (tester) async {
    when(() => entries.create(any())).thenThrow(failure);
    await pump(tester);
    await addTv(tester);

    await tester.tap(find.text('Efetivar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível conectar. Verifique sua internet.'),
      findsOneWidget,
    );
    expect(find.text('TV'), findsOneWidget);
    expect(popped, isEmpty);
  });

  testWidgets('discards and returns false', (tester) async {
    await pump(tester);
    await addTv(tester);

    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(popped, [false]);
    verifyNever(() => entries.create(any()));
  });
}
