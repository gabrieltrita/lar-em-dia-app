import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/home/presentation/cubits/home_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/finance_fixtures.dart';

void main() {
  late MockBalanceRepository balances;
  late MockEntryRepository entries;

  setUpAll(registerFinanceFallbacks);
  setUp(() {
    balances = MockBalanceRepository();
    entries = MockEntryRepository();
  });

  blocTest<HomeCubit, LoadState<HomeSummary>>(
    'summarizes the latest balance and the month income',
    setUp: () {
      when(balances.latest).thenAnswer((_) async => balance);
      when(() => entries.month(november, kind: EntryKind.income))
          .thenAnswer((_) async => [salary, rent]);
    },
    build: () => HomeCubit(balances, entries),
    act: (cubit) => cubit.load(today: DateTime(2026, 11, 3)),
    expect: () => [
      const LoadState<HomeSummary>.loading(),
      LoadState.loaded(
        HomeSummary(
          month: november,
          latestBalance: balance,
          receivedCents: 500000,
          pendingCents: 150000,
        ),
      ),
    ],
    verify: (cubit) =>
        expect((cubit.state as Loaded<HomeSummary>).value.incomeCents, 650000),
  );

  blocTest<HomeCubit, LoadState<HomeSummary>>(
    'uses the current month by default and reports failures',
    setUp: () =>
        when(balances.latest).thenThrow(const ApiError(code: 'network_error')),
    build: () => HomeCubit(balances, entries),
    act: (cubit) => cubit.load(),
    expect: () => const [
      LoadState<HomeSummary>.loading(),
      LoadState<HomeSummary>.failure(ApiError(code: 'network_error')),
    ],
  );
}
