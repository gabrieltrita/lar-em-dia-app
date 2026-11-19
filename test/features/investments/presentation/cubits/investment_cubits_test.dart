import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/distribution.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
import 'package:lar_em_dia/features/investments/domain/screener.dart';
import 'package:lar_em_dia/features/investments/domain/simulation.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/investment_fixtures.dart';

void main() {
  late MockInvestmentRepository repository;

  setUpAll(registerInvestmentFallbacks);

  setUp(() {
    repository = MockInvestmentRepository();
    when(repository.portfolio).thenAnswer((_) async => portfolio);
    when(repository.history).thenAnswer((_) async => history);
    when(repository.income).thenAnswer((_) async => noIncome);
    when(() => repository.asset('HGLG11')).thenAnswer((_) async => hglg);
    when(() => repository.transactions('HGLG11'))
        .thenAnswer((_) async => [hglgBuy, hglgSplit]);
  });

  const failure = ApiError(code: 'network_error');
  final view = PortfolioView(
    portfolio: portfolio,
    history: history,
    income: noIncome,
  );

  group('PortfolioCubit', () {
    blocTest<PortfolioCubit, LoadState<PortfolioView>>(
      'loads the portfolio and its history',
      build: () => PortfolioCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const LoadState<PortfolioView>.loading(),
        LoadState.loaded(view),
      ],
    );

    blocTest<PortfolioCubit, LoadState<PortfolioView>>(
      'reports a failure of either call',
      setUp: () => when(repository.history).thenThrow(failure),
      build: () => PortfolioCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => const [
        LoadState<PortfolioView>.loading(),
        LoadState<PortfolioView>.failure(failure),
      ],
    );

    blocTest<PortfolioCubit, LoadState<PortfolioView>>(
      'filters by goal and keeps the filter on a quiet reload',
      build: () => PortfolioCubit(repository),
      seed: () => LoadState.loaded(view),
      act: (cubit) async {
        cubit.filter(InvestmentGoal.growth);
        await cubit.load(quiet: true);
      },
      expect: () => [
        LoadState.loaded(view.copyWith(filter: InvestmentGoal.growth)),
      ],
      verify: (cubit) {
        final value = (cubit.state as Loaded<PortfolioView>).value;
        expect(value.visiblePositions, [itsaPosition]);
        expect(value.copyWith(filter: null).visiblePositions, hasLength(2));
      },
    );

    blocTest<PortfolioCubit, LoadState<PortfolioView>>(
      'ignores the filter before loading',
      build: () => PortfolioCubit(repository),
      act: (cubit) => cubit.filter(InvestmentGoal.income),
      expect: () => const <LoadState<PortfolioView>>[],
    );

    blocTest<PortfolioCubit, LoadState<PortfolioView>>(
      'shows the portfolio without income when the income fails',
      setUp: () => when(repository.income).thenThrow(failure),
      build: () => PortfolioCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const LoadState<PortfolioView>.loading(),
        LoadState.loaded(PortfolioView(portfolio: portfolio, history: history)),
      ],
    );

    test('keeps only the last 12 months for the summary', () {
      expect(view.recentHistory, hasLength(12));
      expect(view.recentHistory.last, history.last);
      expect(
        view.copyWith(history: history.take(3).toList()).recentHistory,
        hasLength(3),
      );
    });
  });

  group('PortfolioHistoryCubit', () {
    blocTest<PortfolioHistoryCubit, LoadState<List<PortfolioMonth>>>(
      'loads every month',
      build: () => PortfolioHistoryCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const LoadState<List<PortfolioMonth>>.loading(),
        LoadState.loaded(history),
      ],
    );

    blocTest<PortfolioHistoryCubit, LoadState<List<PortfolioMonth>>>(
      'reports a failed load',
      setUp: () => when(repository.history).thenThrow(failure),
      build: () => PortfolioHistoryCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => const [
        LoadState<List<PortfolioMonth>>.loading(),
        LoadState<List<PortfolioMonth>>.failure(failure),
      ],
    );
  });

  group('AssetDetailCubit', () {
    final detail = AssetDetail(
      asset: hglg,
      position: hglgPosition,
      transactions: [hglgSplit, hglgBuy],
    );

    blocTest<AssetDetailCubit, LoadState<AssetDetail>>(
      'loads the asset, its position and the newest transactions first',
      build: () => AssetDetailCubit(repository, 'HGLG11'),
      act: (cubit) => cubit.load(),
      expect: () => [
        const LoadState<AssetDetail>.loading(),
        LoadState.loaded(detail),
      ],
    );

    blocTest<AssetDetailCubit, LoadState<AssetDetail>>(
      'reports a failed load',
      setUp: () => when(() => repository.asset('HGLG11')).thenThrow(failure),
      build: () => AssetDetailCubit(repository, 'HGLG11'),
      act: (cubit) => cubit.load(),
      expect: () => const [
        LoadState<AssetDetail>.loading(),
        LoadState<AssetDetail>.failure(failure),
      ],
    );

    test('changes the goal and reloads quietly', () async {
      when(() => repository.updateGoal('HGLG11', InvestmentGoal.growth))
          .thenAnswer((_) async {});
      final cubit = AssetDetailCubit(repository, 'HGLG11');
      final states = <LoadState<AssetDetail>>[];
      final subscription = cubit.stream.listen(states.add);

      expect(await cubit.changeGoal(InvestmentGoal.growth), isNull);
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(states, [
        const LoadState<AssetDetail>.loading(),
        LoadState.loaded(detail),
      ]);
      verify(() => repository.updateGoal('HGLG11', InvestmentGoal.growth))
          .called(1);
      await cubit.close();
    });

    test('deletes a distribution and reloads quietly', () async {
      when(() => repository.deleteDistribution(itsaJcp))
          .thenAnswer((_) async {});
      final cubit = AssetDetailCubit(repository, 'HGLG11');

      expect(await cubit.deleteDistribution(itsaJcp), isNull);

      verify(() => repository.deleteDistribution(itsaJcp)).called(1);
      await cubit.close();
    });

    test('returns the error of a refused deletion', () async {
      const refused = ApiError(code: 'insufficient_quantity');
      when(() => repository.delete(hglgBuy)).thenThrow(refused);
      final cubit = AssetDetailCubit(repository, 'HGLG11');
      await cubit.load();

      expect(await cubit.delete(hglgBuy), refused);

      when(() => repository.delete(hglgBuy)).thenAnswer((_) async {});
      expect(await cubit.delete(hglgBuy), isNull);
      await cubit.close();
    });
  });

  group('PassiveIncomeCubit', () {
    blocTest<PassiveIncomeCubit, LoadState<PassiveIncome>>(
      'loads the passive income',
      setUp: () =>
          when(repository.income).thenAnswer((_) async => passiveIncome),
      build: () => PassiveIncomeCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const LoadState<PassiveIncome>.loading(),
        LoadState.loaded(passiveIncome),
      ],
    );

    blocTest<PassiveIncomeCubit, LoadState<PassiveIncome>>(
      'reports a failed load',
      setUp: () => when(repository.income).thenThrow(failure),
      build: () => PassiveIncomeCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => const [
        LoadState<PassiveIncome>.loading(),
        LoadState<PassiveIncome>.failure(failure),
      ],
    );

    test('sums the year and knows when there is nothing', () {
      expect(passiveIncome.received12mCents, 15000);
      expect(passiveIncome.nextMonthCents, 1167);
      expect(passiveIncome.isEmpty, isFalse);
      expect(noIncome.nextMonthCents, isNull);
      expect(noIncome.isEmpty, isTrue);
    });
  });

  group('AssetSearchCubit', () {
    blocTest<AssetSearchCubit, List<Asset>>(
      'waits between keystrokes and searches the last text',
      setUp: () =>
          when(() => repository.searchAssets('PET'))
              .thenAnswer((_) async => [petr]),
      build: () => AssetSearchCubit(repository),
      act: (cubit) {
        cubit
          ..search('PE')
          ..search(' PET ');
      },
      wait: const Duration(milliseconds: 400),
      expect: () => [
        [petr],
      ],
      verify: (_) {
        verify(() => repository.searchAssets('PET')).called(1);
        verifyNever(() => repository.searchAssets('PE'));
      },
    );

    blocTest<AssetSearchCubit, List<Asset>>(
      'clears the results for short texts and failed searches',
      setUp: () => when(() => repository.searchAssets('XX')).thenThrow(failure),
      build: () => AssetSearchCubit(repository),
      seed: () => [petr],
      act: (cubit) async {
        cubit.search('P');
        await Future<void>.delayed(Duration.zero);
        cubit.search('XX');
      },
      wait: const Duration(milliseconds: 400),
      expect: () => [const <Asset>[]],
    );

    test('stops waiting when closed', () async {
      final cubit = AssetSearchCubit(repository)..search('HGLG');
      await cubit.close();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      verifyNever(() => repository.searchAssets(any()));
    });
  });

  group('InvestmentFormCubit', () {
    blocTest<InvestmentFormCubit, Submission<InvestmentTransaction>>(
      'creates a transaction',
      setUp: () =>
          when(() => repository.create(hglgDraft))
              .thenAnswer((_) async => hglgBuy),
      build: () => InvestmentFormCubit(repository),
      act: (cubit) => cubit.save(hglgDraft),
      expect: () => [
        const Submission<InvestmentTransaction>.inProgress(),
        Submission.success(hglgBuy),
      ],
    );

    blocTest<InvestmentFormCubit, Submission<InvestmentTransaction>>(
      'updates an existing transaction',
      setUp: () =>
          when(() => repository.update(hglgBuy, hglgDraft))
              .thenAnswer((_) async => hglgBuy),
      build: () => InvestmentFormCubit(repository),
      act: (cubit) => cubit.save(hglgDraft, existing: hglgBuy),
      expect: () => [
        const Submission<InvestmentTransaction>.inProgress(),
        Submission.success(hglgBuy),
      ],
    );
  });

  group('DistributionFormCubit', () {
    blocTest<DistributionFormCubit, Submission<AssetDistribution>>(
      'creates a distribution',
      setUp: () =>
          when(() => repository.createDistribution(itsaJcpDraft))
              .thenAnswer((_) async => itsaJcp),
      build: () => DistributionFormCubit(repository),
      act: (cubit) => cubit.save(itsaJcpDraft),
      expect: () => [
        const Submission<AssetDistribution>.inProgress(),
        Submission.success(itsaJcp),
      ],
    );

    blocTest<DistributionFormCubit, Submission<AssetDistribution>>(
      'updates an existing distribution',
      setUp: () =>
          when(() => repository.updateDistribution(itsaJcp, itsaJcpDraft))
              .thenAnswer((_) async => itsaJcp),
      build: () => DistributionFormCubit(repository),
      act: (cubit) => cubit.save(itsaJcpDraft, existing: itsaJcp),
      expect: () => [
        const Submission<AssetDistribution>.inProgress(),
        Submission.success(itsaJcp),
      ],
    );
  });

  group('ExploreCubit', () {
    const query = ScreenerQuery();
    const stocks = ScreenerQuery(type: AssetType.stock);
    const initial = ExploreState(
      query: query,
      results: LoadState<List<Asset>>.loading(),
    );

    blocTest<ExploreCubit, ExploreState>(
      'loads the first page of the default query',
      setUp: () => when(() => repository.screen(query)).thenAnswer(
        (_) async =>
            ScreenerPage(assets: [hglgScreened], nextPage: 2, total: 51),
      ),
      build: () => ExploreCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        initial,
        ExploreState(
          query: query,
          results: LoadState.loaded([hglgScreened]),
          nextPage: 2,
          total: 51,
        ),
      ],
    );

    blocTest<ExploreCubit, ExploreState>(
      'appends the next page and stops at the last one',
      setUp: () {
        when(() => repository.screen(query)).thenAnswer(
          (_) async => ScreenerPage(assets: [hglgScreened], nextPage: 2),
        );
        when(() => repository.screen(query, page: 2))
            .thenAnswer((_) async => const ScreenerPage(assets: [btlg]));
      },
      build: () => ExploreCubit(repository),
      act: (cubit) async {
        await cubit.load();
        await cubit.loadMore();
        await cubit.loadMore();
      },
      skip: 2,
      expect: () => [
        ExploreState(
          query: query,
          results: LoadState.loaded([hglgScreened]),
          nextPage: 2,
          loadingMore: true,
        ),
        ExploreState(
          query: query,
          results: LoadState.loaded([hglgScreened, btlg]),
        ),
      ],
    );

    blocTest<ExploreCubit, ExploreState>(
      'keeps the page when the next one fails and waits for the first',
      setUp: () {
        when(() => repository.screen(query)).thenAnswer(
          (_) async => ScreenerPage(assets: [hglgScreened], nextPage: 2),
        );
        when(() => repository.screen(query, page: 2)).thenThrow(failure);
      },
      build: () => ExploreCubit(repository),
      act: (cubit) async {
        await cubit.loadMore();
        await cubit.load();
        await cubit.loadMore();
      },
      skip: 2,
      expect: () => [
        ExploreState(
          query: query,
          results: LoadState.loaded([hglgScreened]),
          nextPage: 2,
          loadingMore: true,
        ),
        ExploreState(
          query: query,
          results: LoadState.loaded([hglgScreened]),
          nextPage: 2,
        ),
      ],
    );

    blocTest<ExploreCubit, ExploreState>(
      'shows only the latest query and reports a failure',
      setUp: () {
        when(() => repository.screen(query)).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return ScreenerPage(assets: [hglgScreened]);
        });
        when(() => repository.screen(stocks)).thenThrow(failure);
      },
      build: () => ExploreCubit(repository),
      act: (cubit) async {
        final first = cubit.load();
        await cubit.apply(stocks);
        await first;
      },
      expect: () => const [
        initial,
        ExploreState(query: stocks, results: LoadState<List<Asset>>.loading()),
        ExploreState(
          query: stocks,
          results: LoadState<List<Asset>>.failure(failure),
        ),
      ],
    );

    blocTest<ExploreCubit, ExploreState>(
      'drops a stale page or failure after the query changed',
      setUp: () {
        when(() => repository.screen(query)).thenAnswer(
          (_) async => ScreenerPage(assets: [hglgScreened], nextPage: 2),
        );
        when(() => repository.screen(query, page: 2)).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return const ScreenerPage(assets: [btlg]);
        });
        when(() => repository.screen(stocks)).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          throw failure;
        });
      },
      build: () => ExploreCubit(repository),
      act: (cubit) async {
        await cubit.load();
        final more = cubit.loadMore();
        final stale = cubit.apply(stocks);
        await more;
        await cubit.apply(query);
        await stale;
      },
      verify: (cubit) => expect(
        cubit.state,
        ExploreState(
          query: query,
          results: LoadState.loaded([hglgScreened]),
          nextPage: 2,
        ),
      ),
    );

    blocTest<ExploreCubit, ExploreState>(
      'drops a stale next page failure after the query changed',
      setUp: () {
        when(() => repository.screen(query)).thenAnswer(
          (_) async => ScreenerPage(assets: [hglgScreened], nextPage: 2),
        );
        when(() => repository.screen(query, page: 2)).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          throw failure;
        });
        when(() => repository.screen(stocks))
            .thenAnswer((_) async => const ScreenerPage(assets: []));
      },
      build: () => ExploreCubit(repository),
      act: (cubit) async {
        await cubit.load();
        final more = cubit.loadMore();
        await cubit.apply(stocks);
        await more;
      },
      verify: (cubit) => expect(
        cubit.state,
        const ExploreState(
          query: stocks,
          results: LoadState<List<Asset>>.loaded([]),
        ),
      ),
    );

    test('keeps only the ranges of the query type and resets its sort', () {
      const mixed = ScreenerQuery(
        sort: Indicator.priceToBook,
        ranges: {
          Indicator.dividendYield: IndicatorRange(min: 600),
          Indicator.roe: IndicatorRange(min: 1500),
          Indicator.liquidity: IndicatorRange(),
        },
      );

      expect(mixed.activeRanges.keys, [Indicator.dividendYield]);
      expect(mixed.withType(AssetType.stock).activeRanges.keys, [
        Indicator.dividendYield,
        Indicator.roe,
      ]);
      expect(mixed.withType(AssetType.stock).sort, Indicator.priceToBook);
      expect(
        mixed
            .copyWith(type: AssetType.stock, sort: Indicator.roe)
            .withType(AssetType.fii)
            .sort,
        Indicator.dividendYield,
      );
      expect(Indicator.forType(AssetType.fii), [
        Indicator.dividendYield,
        Indicator.monthsPaying,
        Indicator.yearsPaying,
        Indicator.priceToBook,
        Indicator.propertiesCount,
        Indicator.largestProperty,
        Indicator.largestTenant,
        Indicator.vacancy,
        Indicator.delinquency,
        Indicator.development,
        Indicator.liquidity,
      ]);
      for (final indicator in Indicator.forType(AssetType.stock)) {
        expect(petrIndicators.value(indicator), isNotNull);
      }
      for (final indicator in Indicator.forType(AssetType.fii)) {
        expect(hglgIndicators.value(indicator), isNotNull);
      }
    });
  });

  group('simulators', () {
    blocTest<IncomeSimulatorCubit, Submission<IncomeSimulation>>(
      'simulates income',
      setUp: () =>
          when(() => repository.simulateIncome(incomeInput))
              .thenAnswer((_) async => incomeSimulation),
      build: () => IncomeSimulatorCubit(repository),
      act: (cubit) => cubit.simulate(incomeInput),
      expect: () => const [
        Submission<IncomeSimulation>.inProgress(),
        Submission.success(incomeSimulation),
      ],
    );

    blocTest<GrowthSimulatorCubit, Submission<GrowthSimulation>>(
      'simulates growth',
      setUp: () =>
          when(() => repository.simulateGrowth(growthInput))
              .thenAnswer((_) async => growthSimulation),
      build: () => GrowthSimulatorCubit(repository),
      act: (cubit) => cubit.simulate(growthInput),
      expect: () => const [
        Submission<GrowthSimulation>.inProgress(),
        Submission.success(growthSimulation),
      ],
    );

    test('reads the last month', () {
      expect(incomeSimulation.last.month, 24);
      expect(growthSimulation.last.valueCents, 238465);
    });
  });
}
