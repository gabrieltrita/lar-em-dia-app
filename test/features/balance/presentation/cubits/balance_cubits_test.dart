import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/balance/domain/balance.dart';
import 'package:lar_em_dia/features/balance/presentation/cubits/balance_cubits.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/finance_fixtures.dart';

void main() {
  late MockBalanceRepository repository;

  setUp(() => repository = MockBalanceRepository());

  const failure = ApiError(code: 'network_error');

  blocTest<BalancesCubit, LoadState<List<Balance>>>(
    'loads the balances',
    setUp: () => when(repository.list).thenAnswer((_) async => [balance]),
    build: () => BalancesCubit(repository),
    act: (cubit) => cubit.load(),
    expect: () => [
      const LoadState<List<Balance>>.loading(),
      LoadState.loaded([balance]),
    ],
  );

  blocTest<BalancesCubit, LoadState<List<Balance>>>(
    'reports a failed load',
    setUp: () => when(repository.list).thenThrow(failure),
    build: () => BalancesCubit(repository),
    act: (cubit) => cubit.load(),
    expect: () => const [
      LoadState<List<Balance>>.loading(),
      LoadState<List<Balance>>.failure(failure),
    ],
  );

  test('delete reloads on success and returns the error otherwise', () async {
    when(repository.list).thenAnswer((_) async => []);
    when(() => repository.delete('balance-1')).thenAnswer((_) async {});
    final cubit = BalancesCubit(repository);

    expect(await cubit.delete(balance), isNull);
    expect(cubit.state, const LoadState<List<Balance>>.loaded([]));

    when(() => repository.delete('balance-1')).thenThrow(failure);
    expect(await cubit.delete(balance), failure);
    await cubit.close();
  });

  blocTest<LatestBalanceCubit, Balance?>(
    'loads the latest balance',
    setUp: () => when(repository.latest).thenAnswer((_) async => balance),
    build: () => LatestBalanceCubit(repository),
    act: (cubit) => cubit.load(),
    expect: () => [balance],
  );

  blocTest<LatestBalanceCubit, Balance?>(
    'stays empty when the latest balance fails to load',
    setUp: () => when(repository.latest).thenThrow(failure),
    build: () => LatestBalanceCubit(repository),
    seed: () => balance,
    act: (cubit) => cubit.load(),
    expect: () => const <Balance?>[null],
  );

  blocTest<BalanceFormCubit, Submission<Balance>>(
    'creates a new balance',
    setUp: () =>
        when(() => repository.create(amountCents: 100, asOf: balance.asOf))
            .thenAnswer((_) async => balance),
    build: () => BalanceFormCubit(repository),
    act: (cubit) => cubit.save(amountCents: 100, asOf: balance.asOf),
    expect: () => [
      const Submission<Balance>.inProgress(),
      Submission.success(balance),
    ],
  );

  blocTest<BalanceFormCubit, Submission<Balance>>(
    'updates an existing balance',
    setUp: () => when(
      () =>
          repository.update('balance-1', amountCents: 100, asOf: balance.asOf),
    ).thenAnswer((_) async => balance),
    build: () => BalanceFormCubit(repository),
    act: (cubit) =>
        cubit.save(existing: balance, amountCents: 100, asOf: balance.asOf),
    expect: () => [
      const Submission<Balance>.inProgress(),
      Submission.success(balance),
    ],
  );
}
