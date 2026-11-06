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
    build: () => ProjectionCubit(repository),
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
    build: () => ProjectionCubit(repository),
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
    build: () => ProjectionCubit(repository),
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
}
