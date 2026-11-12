import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/cubits/projection_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/finance_fixtures.dart';

void main() {
  late MockProjectionRepository repository;

  setUpAll(registerFinanceFallbacks);
  setUp(() => repository = MockProjectionRepository());

  test('flags negative months', () {
    expect(novemberProjection.isNegative, isFalse);
    expect(decemberProjection.isNegative, isTrue);
  });

  blocTest<ProjectionCubit, ProjectionState>(
    'loads twelve months from the current month',
    setUp: () => when(
      () => repository.fetch(from: november, period: ProjectionPeriod.year),
    ).thenAnswer((_) async => projection),
    build: () => ProjectionCubit(repository, FakeProjectionPreferences()),
    act: (cubit) => cubit.load(today: DateTime(2026, 11, 3)),
    expect: () => [
      const ProjectionState(),
      ProjectionState(data: LoadState.loaded(projection)),
    ],
  );

  blocTest<ProjectionCubit, ProjectionState>(
    'uses today by default and reports failures',
    setUp: () => when(
      () => repository.fetch(
        from: Dates.firstOfMonth(DateTime.now()),
        period: ProjectionPeriod.year,
      ),
    ).thenThrow(const ApiError(code: 'network_error')),
    build: () => ProjectionCubit(repository, FakeProjectionPreferences()),
    act: (cubit) => cubit.load(),
    expect: () => const [
      ProjectionState(),
      ProjectionState(data: LoadState.failure(ApiError(code: 'network_error'))),
    ],
  );

  blocTest<ProjectionCubit, ProjectionState>(
    'reloads with the selected period and ignores the current one',
    setUp: () => when(
      () => repository.fetch(from: november, period: ProjectionPeriod.all),
    ).thenAnswer((_) async => projection),
    build: () => ProjectionCubit(repository, FakeProjectionPreferences()),
    act: (cubit) async {
      await cubit.selectPeriod(ProjectionPeriod.year);
      await cubit.selectPeriod(
        ProjectionPeriod.all,
        today: DateTime(2026, 11, 3),
      );
    },
    expect: () => [
      const ProjectionState(period: ProjectionPeriod.all),
      ProjectionState(
        period: ProjectionPeriod.all,
        data: LoadState.loaded(projection),
      ),
    ],
  );

  test('knows the months of each period and its result', () {
    expect(
      [for (final period in ProjectionPeriod.values) period.query],
      ['3', '6', '12', 'all'],
    );
    expect(novemberProjection.resultCents, 370000);
  });

  test('removes the forecast income from the months that follow it', () {
    final without = investedProjection.withoutInvestmentIncome();

    expect(investedProjection.hasInvestmentIncome, isTrue);
    expect(without.hasInvestmentIncome, isFalse);
    expect(without.months.first, investedProjection.months.first);
    expect(
      without.months.last,
      decemberProjection.copyWith(
        investmentsValueCents: 330000,
        netWorthCents: 223456,
      ),
    );
    expect(without.firstNegativeMonth, DateTime(2026, 12));
    expect(without.negativeMonthsCount, 1);
    expect(projection.hasInvestmentIncome, isFalse);
    expect(investedProjection.months.first.hasInvestments, isTrue);
  });

  blocTest<ProjectionCubit, ProjectionState>(
    'remembers whether the forecast income is included',
    setUp: () => when(
      () => repository.fetch(from: november, period: ProjectionPeriod.year),
    ).thenAnswer((_) async => investedProjection),
    build: () =>
        ProjectionCubit(repository, FakeProjectionPreferences(include: false)),
    act: (cubit) async {
      await cubit.load(today: DateTime(2026, 11, 3));
      expect(cubit.state.offersInvestmentIncome, isTrue);
      expect(
        cubit.state.visible,
        LoadState.loaded(investedProjection.withoutInvestmentIncome()),
      );
      await cubit.includeInvestmentIncome(include: true);
      expect(cubit.state.visible, LoadState.loaded(investedProjection));
    },
    expect: () => [
      const ProjectionState(),
      ProjectionState(
        data: LoadState.loaded(investedProjection),
        includeInvestmentIncome: false,
      ),
      ProjectionState(data: LoadState.loaded(investedProjection)),
    ],
  );

  test('offers the switch only for a loaded projection', () {
    expect(const ProjectionState().offersInvestmentIncome, isFalse);
  });
}
