import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/cubits/simulation_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/finance_fixtures.dart';

void main() {
  late MockProjectionRepository projections;
  late MockEntryRepository entries;
  const failure = ApiError(code: ApiError.networkErrorCode);

  setUpAll(registerFinanceFallbacks);

  setUp(() {
    projections = MockProjectionRepository();
    entries = MockEntryRepository();
    when(
      () => projections.simulate(
        any(),
        from: any(named: 'from'),
        months: any(named: 'months'),
      ),
    ).thenAnswer((_) async => comparison);
    when(() => entries.create(any())).thenAnswer((_) async => groceries);
    when(() => entries.createSeries(any(), any()))
        .thenAnswer((_) async => [salary]);
    when(() => entries.createInstallments(any(), any()))
        .thenAnswer((_) async => [groceries]);
  });

  SimulationCubit build() => SimulationCubit(projections, entries);

  const loading = LoadState<ProjectionComparison>.loading();

  blocTest<SimulationCubit, SimulationState>(
    'simulates every time a plan is added or removed',
    build: build,
    act: (cubit) async {
      await cubit.add(tvPlan);
      await cubit.add(freelancePlan);
      await cubit.remove(0);
      await cubit.remove(0);
    },
    expect: () => [
      SimulationState(plans: [tvPlan]),
      SimulationState(plans: [tvPlan], result: loading),
      SimulationState(plans: [tvPlan], result: LoadState.loaded(comparison)),
      SimulationState(
        plans: [tvPlan, freelancePlan],
        result: LoadState.loaded(comparison),
      ),
      SimulationState(plans: [tvPlan, freelancePlan], result: loading),
      SimulationState(
        plans: [tvPlan, freelancePlan],
        result: LoadState.loaded(comparison),
      ),
      SimulationState(
        plans: [freelancePlan],
        result: LoadState.loaded(comparison),
      ),
      SimulationState(plans: [freelancePlan], result: loading),
      SimulationState(
        plans: [freelancePlan],
        result: LoadState.loaded(comparison),
      ),
      SimulationState(result: LoadState.loaded(comparison)),
      const SimulationState(),
    ],
    verify: (_) => verify(
      () => projections.simulate(
        any(),
        from: any(named: 'from'),
        months: SimulationCubit.months,
      ),
    ).called(3),
  );

  blocTest<SimulationCubit, SimulationState>(
    'keeps the failure and retries',
    build: build,
    setUp: () => when(
      () => projections.simulate(
        any(),
        from: any(named: 'from'),
        months: any(named: 'months'),
      ),
    ).thenThrow(failure),
    act: (cubit) async {
      await cubit.add(tvPlan);
      await cubit.retry();
    },
    skip: 2,
    expect: () => [
      SimulationState(
        plans: [tvPlan],
        result: const LoadState.failure(failure),
      ),
      SimulationState(plans: [tvPlan], result: loading),
      SimulationState(
        plans: [tvPlan],
        result: const LoadState.failure(failure),
      ),
    ],
  );

  test('ignores a result for plans that already changed', () async {
    final pending = Completer<ProjectionComparison>();
    final failing = Completer<ProjectionComparison>();
    final answers = [
      pending.future,
      failing.future,
      Completer<ProjectionComparison>().future,
    ];
    when(
      () => projections.simulate(
        any(),
        from: any(named: 'from'),
        months: any(named: 'months'),
      ),
    ).thenAnswer((_) => answers.removeAt(0));
    final cubit = build();
    unawaited(cubit.add(tvPlan));
    unawaited(cubit.add(freelancePlan));
    unawaited(cubit.remove(1));
    pending.complete(comparison);
    failing.completeError(failure);
    await pumpEventQueue();

    expect(cubit.state.plans, [tvPlan]);
    expect(cubit.state.result, loading);
    await cubit.close();
  });

  blocTest<SimulationCubit, SimulationState>(
    'commits each plan through the matching endpoint',
    build: build,
    seed: () => SimulationState(plans: [tvPlan, freelancePlan, sofaPlan]),
    act: (cubit) => cubit.commit(),
    expect: () => [
      SimulationState(
        plans: [tvPlan, freelancePlan, sofaPlan],
        committing: true,
      ),
      const SimulationState(committed: true),
    ],
    verify: (_) {
      verify(() => entries.create(tvPlan.draft)).called(1);
      verify(
        () => entries.createSeries(
          freelancePlan.draft,
          freelancePlan.recurrence!,
        ),
      ).called(1);
      verify(
        () =>
            entries.createInstallments(sofaPlan.draft, sofaPlan.installments!),
      ).called(1);
    },
  );

  blocTest<SimulationCubit, SimulationState>(
    'keeps the plans that failed and simulates the rest again',
    build: build,
    setUp: () =>
        when(() => entries.createSeries(any(), any())).thenThrow(failure),
    seed: () => SimulationState(plans: [tvPlan, freelancePlan]),
    act: (cubit) => cubit.commit(),
    expect: () => [
      SimulationState(plans: [tvPlan, freelancePlan], committing: true),
      SimulationState(plans: [freelancePlan], commitError: failure),
      SimulationState(
        plans: [freelancePlan],
        commitError: failure,
        result: loading,
      ),
      SimulationState(
        plans: [freelancePlan],
        commitError: failure,
        result: LoadState.loaded(comparison),
      ),
    ],
  );

  blocTest<SimulationCubit, SimulationState>(
    'keeps every plan when the first one fails',
    build: build,
    setUp: () => when(() => entries.create(any())).thenThrow(failure),
    seed: () => SimulationState(plans: [tvPlan]),
    act: (cubit) => cubit.commit(),
    expect: () => [
      SimulationState(plans: [tvPlan], committing: true),
      SimulationState(plans: [tvPlan], commitError: failure),
    ],
  );

  test('is full at ten plans', () {
    expect(SimulationState(plans: List.filled(9, tvPlan)).isFull, isFalse);
    expect(SimulationState(plans: List.filled(10, tvPlan)).isFull, isTrue);
  });
}
