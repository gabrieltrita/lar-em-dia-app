import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/home/presentation/cubits/home_cubit.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/finance_fixtures.dart';

void main() {
  late MockBalanceRepository balances;
  late MockEntryRepository entries;
  late MockProjectionRepository projections;

  setUpAll(registerFinanceFallbacks);
  setUp(() {
    balances = MockBalanceRepository();
    entries = MockEntryRepository();
    projections = MockProjectionRepository();
  });

  blocTest<HomeCubit, LoadState<HomeSummary>>(
    'summarizes the latest balance and the month income and expenses',
    setUp: () {
      when(balances.latest).thenAnswer((_) async => balance);
      when(
        () => entries.between(
          DateTime(2026, 11, 3),
          DateTime(2026, 11, 10),
          kind: EntryKind.expense,
        ),
      ).thenAnswer((_) async => [housing, groceries]);
      when(() => entries.month(november))
          .thenAnswer((_) async => [salary, rent, housing, groceries]);
      when(() => entries.categories(EntryKind.expense))
          .thenAnswer((_) async => [housingCategory]);
      when(() => projections.fetch(from: november))
          .thenAnswer((_) async => projection);
    },
    build: () => HomeCubit(balances, entries, projections),
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
          projected: novemberProjection,
          firstNegativeMonth: DateTime(2026, 12),
          negativeMonthsCount: 1,
          upcoming: [housing],
          expenseByCategory: [
            const CategoryAmount(categoryKey: 'housing', amountCents: 200000),
            CategoryAmount(
              categoryKey: groceries.categoryId,
              amountCents: 80000,
            ),
          ],
          fixedCents: 200000,
          variableCents: 80000,
          months: projection.months,
        ),
      ),
    ],
    verify: (cubit) {
      final summary = (cubit.state as Loaded<HomeSummary>).value;
      expect(summary.resultCents, 370000);
      expect(summary.upcomingCents, 200000);
    },
  );

  blocTest<HomeCubit, LoadState<HomeSummary>>(
    'moves between months and reloads quietly',
    setUp: () {
      when(balances.latest).thenAnswer((_) async => null);
      when(() => entries.month(any())).thenAnswer((_) async => []);
      when(() => entries.categories(EntryKind.expense))
          .thenAnswer((_) async => []);
      when(() => entries.between(any(), any(), kind: any(named: 'kind')))
          .thenAnswer((_) async => []);
    },
    build: () => HomeCubit(balances, entries, projections),
    act: (cubit) async {
      await cubit.load(today: DateTime(2026, 11, 3));
      await cubit.previous();
      await cubit.next();
      await cubit.next();
      await cubit.load(quiet: true);
    },
    verify: (cubit) {
      expect(
        (cubit.state as Loaded<HomeSummary>).value.month,
        DateTime(2026, 12),
      );
      verify(() => entries.month(DateTime(2026, 10))).called(1);
      verify(() => entries.month(DateTime(2026, 12))).called(2);
    },
  );

  blocTest<HomeCubit, LoadState<HomeSummary>>(
    'ignores a month that is no longer selected',
    setUp: () {
      when(balances.latest).thenAnswer((_) async => null);
      when(() => entries.month(any())).thenAnswer((_) async => []);
      when(() => entries.categories(EntryKind.expense))
          .thenAnswer((_) async => []);
      when(() => entries.between(any(), any(), kind: any(named: 'kind')))
          .thenAnswer((_) async => []);
    },
    build: () => HomeCubit(balances, entries, projections),
    act: (cubit) async {
      final first = cubit.load(month: DateTime(2026, 10));
      await cubit.load(month: november);
      await first;
    },
    verify: (cubit) =>
        expect((cubit.state as Loaded<HomeSummary>).value.month, november),
  );

  blocTest<HomeCubit, LoadState<HomeSummary>>(
    'skips the projection without a balance',
    setUp: () {
      when(balances.latest).thenAnswer((_) async => null);
      when(() => entries.month(november)).thenAnswer((_) async => []);
      when(() => entries.categories(EntryKind.expense))
          .thenAnswer((_) async => []);
      when(() => entries.between(any(), any(), kind: any(named: 'kind')))
          .thenAnswer((_) async => []);
    },
    build: () => HomeCubit(balances, entries, projections),
    act: (cubit) => cubit.load(today: DateTime(2026, 11, 3)),
    skip: 1,
    expect: () => [
      LoadState.loaded(
        HomeSummary(
          month: november,
          income: const MonthTotals(settledCents: 0, pendingCents: 0),
          expenses: const MonthTotals(settledCents: 0, pendingCents: 0),
        ),
      ),
    ],
    verify: (_) => verifyZeroInteractions(projections),
  );

  blocTest<HomeCubit, LoadState<HomeSummary>>(
    'uses the current month by default and reports failures',
    setUp: () =>
        when(balances.latest).thenThrow(const ApiError(code: 'network_error')),
    build: () => HomeCubit(balances, entries, projections),
    act: (cubit) => cubit.load(),
    expect: () => const [
      LoadState<HomeSummary>.loading(),
      LoadState<HomeSummary>.failure(ApiError(code: 'network_error')),
    ],
  );
}
