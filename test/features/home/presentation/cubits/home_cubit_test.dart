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
    'summarizes the latest balance and the month income and expenses',
    setUp: () {
      when(balances.latest).thenAnswer((_) async => balance);
      when(() => entries.month(november, kind: EntryKind.income))
          .thenAnswer((_) async => [salary, rent]);
      when(() => entries.month(november, kind: EntryKind.expense))
          .thenAnswer((_) async => [housing, groceries]);
    },
    build: () => HomeCubit(balances, entries),
    act: (cubit) => cubit.load(today: DateTime(2026, 11, 3)),
    expect: () => [
      const LoadState<HomeSummary>.loading(),
      LoadState.loaded(
        HomeSummary(
          month: november,
          latestBalance: balance,
          income: const MonthTotals(settledCents: 500000, pendingCents: 150000),
          expenses: const MonthTotals(
            settledCents: 80000,
            pendingCents: 200000,
          ),
        ),
      ),
    ],
    verify: (cubit) {
      final summary = (cubit.state as Loaded<HomeSummary>).value;
      expect(summary.totalsOf(EntryKind.income).totalCents, 650000);
      expect(summary.totalsOf(EntryKind.expense).totalCents, 280000);
    },
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
