import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/screener.dart';
import 'package:lar_em_dia/features/investments/domain/screener_presets.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/explore_page.dart';
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
    when(() => repository.screen(any())).thenAnswer(
      (_) async => ScreenerPage(
        assets: [hglgScreened, ajfiScreened, btlg],
        nextPage: 2,
        total: 4,
      ),
    );
    when(() => repository.screen(any(), page: 2))
        .thenAnswer((_) async => ScreenerPage(assets: [petrScreened]));
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPage(
      tester,
      BlocProvider(
        create: (_) =>
            started(ExploreCubit(repository), (cubit) => cubit.load()),
        child: const ExplorePage(),
      ),
      session: harness.session,
    );
  }

  ScreenerQuery lastQuery() =>
      verify(() => repository.screen(captureAny())).captured.last
          as ScreenerQuery;

  testWidgets('shows cards with key figures and alerts and opens one', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('4 papéis'), findsOneWidget);
    expect(find.text('HGLG11'), findsOneWidget);
    expect(find.text('Tijolo · Logística'), findsOneWidget);
    expect(find.text('8,25%'), findsOneWidget);
    expect(find.text('36 imóveis'), findsOneWidget);
    expect(find.text('Monoativo'), findsOneWidget);
    expect(find.text('Rendimento irregular'), findsOneWidget);
    expect(find.text('Pouca liquidez'), findsOneWidget);
    expect(find.text('BTG LOG'), findsOneWidget);
    expect(find.textContaining('Não é ranking'), findsOneWidget);
    expect(find.text('Sem critérios: mostrando todos os papéis.'), findsOne);

    await tester.scrollUntilVisible(find.text('Carregar mais'), 300);
    await tester.tap(find.text('Carregar mais'));
    await tester.pumpAndSettle();
    expect(find.text('PETR4'), findsOneWidget);
    expect(find.text('Carregar mais'), findsNothing);

    await tester.tap(find.text('HGLG11'));
    await tester.pumpAndSettle();
    expect(
      find.text(routeMarker('/investments/assets/HGLG11')),
      findsOneWidget,
    );
  });

  testWidgets('applies a strategy, removes a criterion and clears it', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('strategy_diversifiedBrick')));
    await tester.pumpAndSettle();
    expect(lastQuery(), ScreenerStrategy.diversifiedBrick.query);
    expect(find.textContaining('5 ou mais imóveis'), findsOneWidget);
    expect(find.text('Tijolo'), findsOneWidget);
    expect(find.text('Esconder monoativos'), findsOneWidget);
    expect(find.text('Vacância ≤ 10%'), findsOneWidget);
    expect(find.text('Imóveis para renda ≥ 5 imóveis'), findsOneWidget);

    final vacancy = find.ancestor(
      of: find.text('Vacância ≤ 10%'),
      matching: find.byType(InputChip),
    );
    await tester.tap(
      find.descendant(of: vacancy, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();
    expect(lastQuery().activeRanges.containsKey(Indicator.vacancy), isFalse);
    expect(find.textContaining('5 ou mais imóveis'), findsNothing);

    for (final label in ['Tijolo', 'Esconder monoativos']) {
      final chip = find.ancestor(
        of: find.text(label),
        matching: find.byType(InputChip),
      );
      await tester.tap(
        find.descendant(of: chip, matching: find.byIcon(Icons.clear)),
      );
      await tester.pumpAndSettle();
    }
    final cleared = lastQuery();
    expect(cleared.categories, isEmpty);
    expect(cleared.hideSingleProperty, isFalse);

    await tester.tap(find.byKey(const Key('strategy_steadyIncome')));
    await tester.pumpAndSettle();
    expect(find.text('Esconder fundos em desenvolvimento'), findsOneWidget);
    final development = find.ancestor(
      of: find.text('Esconder fundos em desenvolvimento'),
      matching: find.byType(InputChip),
    );
    await tester.tap(
      find.descendant(of: development, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();
    expect(lastQuery().hideDevelopment, isFalse);

    await tester.tap(find.byKey(const Key('strategy_steadyIncome')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('strategy_steadyIncome')));
    await tester.pumpAndSettle();
    expect(lastQuery(), const ScreenerQuery());
  });

  testWidgets('switches to stocks, sorts and flips the direction', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Ações'));
    await tester.pumpAndSettle();
    expect(lastQuery().type, AssetType.stock);
    expect(find.byKey(const Key('strategy_growth')), findsOneWidget);
    expect(find.byKey(const Key('strategy_steadyIncome')), findsNothing);

    await tester.tap(find.byKey(const Key('explore_sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('P/L').last);
    await tester.pumpAndSettle();
    expect(lastQuery().sort, Indicator.priceToEarnings);

    await tester.tap(find.byKey(const Key('explore_direction')));
    await tester.pumpAndSettle();
    expect(lastQuery().ascending, isTrue);
    expect(find.byTooltip('Menor primeiro'), findsOneWidget);
  });

  testWidgets('picks criteria by tapping thresholds in the filters', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('explore_filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category_paper')));
    await tester.tap(find.byKey(const Key('category_brick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category_paper')));
    await tester.tap(find.byKey(const Key('explore_single_property')));
    await tester.tap(find.byKey(const Key('explore_development')));
    await tester.tap(find.byKey(const Key('explore_paying')));
    await tester.ensureVisible(find.byKey(const Key('option_dividendYield_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('option_dividendYield_1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Diversificação e risco'));
    await tester.ensureVisible(find.byKey(const Key('option_liquidity_2')));
    await tester.tap(find.byKey(const Key('option_liquidity_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('explore_apply')));
    await tester.pumpAndSettle();

    final query = lastQuery();
    expect(query.categories, {FundCategory.brick});
    expect(query.hideSingleProperty, isTrue);
    expect(query.hideDevelopment, isTrue);
    expect(query.payingOnly, isTrue);
    expect(query.activeRanges, {
      Indicator.dividendYield: const IndicatorRange(min: 800),
      Indicator.liquidity: const IndicatorRange(min: 100000000),
    });
    expect(find.text('DY 12 meses ≥ 8%'), findsOneWidget);
    expect(find.text('Só os que pagaram nos últimos 12 meses'), findsOneWidget);

    await tester.tap(find.byKey(const Key('explore_filters')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('option_dividendYield_any')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('option_dividendYield_any')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('explore_apply')));
    await tester.pumpAndSettle();
    expect(lastQuery().activeRanges.keys, [Indicator.liquidity]);

    final paying = find.ancestor(
      of: find.text('Só os que pagaram nos últimos 12 meses'),
      matching: find.byType(InputChip),
    );
    await tester.tap(
      find.descendant(of: paying, matching: find.byIcon(Icons.clear)),
    );
    await tester.pumpAndSettle();
    expect(lastQuery().payingOnly, isFalse);

    await tester.tap(find.byKey(const Key('explore_filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar'));
    await tester.tap(find.byKey(const Key('explore_apply')));
    await tester.pumpAndSettle();
    expect(lastQuery().criteriaCount, 0);

    await tester.tap(find.byKey(const Key('explore_filters')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    verifyNoMoreInteractions(repository);
  });

  testWidgets('keeps a criterion that is not among the thresholds', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('strategy_steadyIncome')));
    await tester.pumpAndSettle();
    final cubit = BlocProvider.of<ExploreCubit>(
      tester.element(find.byType(ExplorePage)),
    );
    await cubit.apply(
      const ScreenerQuery(
        ranges: {Indicator.dividendYield: IndicatorRange(min: 850)},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('explore_filters')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('≥ 8,5%'));
    await tester.pumpAndSettle();
    expect(find.text('≥ 8,5%'), findsOneWidget);
    await tester.tap(find.text('≥ 8,5%'));
    await tester.pumpAndSettle();
    expect(find.text('≥ 8,5%'), findsOneWidget);
  });

  testWidgets('explains an empty result and retries a failure', (tester) async {
    when(() => repository.screen(any()))
        .thenAnswer((_) async => const ScreenerPage(assets: []));
    await pump(tester);
    expect(find.text('Nenhum papel encontrado'), findsOneWidget);

    when(() => repository.screen(any()))
        .thenThrow(const ApiError(code: 'invalid_filter'));
    await tester.tap(find.text('Ações'));
    await tester.pumpAndSettle();
    expect(find.text('Os filtros precisam ser números.'), findsOneWidget);

    when(() => repository.screen(any()))
        .thenAnswer((_) async => ScreenerPage(assets: [petrScreened]));
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('PETR4'), findsOneWidget);
  });
}
