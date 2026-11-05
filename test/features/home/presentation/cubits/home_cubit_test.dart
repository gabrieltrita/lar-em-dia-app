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
      when(() => entries.month(november, kind: EntryKind.income))
          .thenAnswer((_) async => [salary, rent]);
      when(() => entries.month(november, kind: EntryKind.expense))
          .thenAnswer((_) async => [housing, groceries]);
      when(() => projections.fetch(from: november, months: 12))
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
          horizon: decemberProjection,
          firstNegativeMonth: DateTime(2026, 12),
          negativeMonthsCount: 1,
          upcoming: [housing],
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
    'skips the projection without a balance',
    setUp: () {
      when(balances.latest).thenAnswer((_) async => null);
      when(() => entries.month(november, kind: any(named: 'kind')))
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

  group('markPaid', () {
    final today = DateTime(2026, 11, 3);

    setUp(() {
      when(balances.latest).thenAnswer((_) async => null);
      when(() => entries.month(any(), kind: any(named: 'kind')))
          .thenAnswer((_) async => []);
      when(() => entries.between(any(), any(), kind: any(named: 'kind')))
          .thenAnswer((_) async => []);
    });

    blocTest<HomeCubit, LoadState<HomeSummary>>(
      'marks a bill as paid today and reloads',
      setUp: () =>
          when(() => entries.markPaid(housing.id, paidOn: today))
              .thenAnswer((_) async => housing),
      build: () => HomeCubit(balances, entries, projections),
      act: (cubit) async {
        expect(await cubit.markPaid(housing, today: today), isNull);
      },
      expect: () => [
        const LoadState<HomeSummary>.loading(),
        isA<Loaded<HomeSummary>>(),
      ],
      verify: (_) =>
          verify(() => entries.markPaid(housing.id, paidOn: today)).called(1),
    );

    blocTest<HomeCubit, LoadState<HomeSummary>>(
      'returns the error without reloading',
      setUp: () =>
          when(() => entries.markPaid(any(), paidOn: any(named: 'paidOn')))
              .thenThrow(const ApiError(code: 'network_error')),
      build: () => HomeCubit(balances, entries, projections),
      act: (cubit) async {
        expect(
          await cubit.markPaid(housing),
          const ApiError(code: 'network_error'),
        );
      },
      expect: () => const <LoadState<HomeSummary>>[],
    );
  });
}
