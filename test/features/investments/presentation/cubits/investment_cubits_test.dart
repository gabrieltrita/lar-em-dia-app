import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
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
    when(() => repository.asset('HGLG11')).thenAnswer((_) async => hglg);
    when(() => repository.transactions('HGLG11'))
        .thenAnswer((_) async => [hglgBuy, hglgSplit]);
  });

  const failure = ApiError(code: 'network_error');
  final view = PortfolioView(portfolio: portfolio, history: history);

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
}
