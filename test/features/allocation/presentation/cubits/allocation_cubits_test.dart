import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/allocation/domain/allocation.dart';
import 'package:lar_em_dia/features/allocation/presentation/cubits/allocation_cubits.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/allocation_fixtures.dart';
import '../../../../helpers/reserve_fixtures.dart';

void main() {
  late MockAllocationRepository repository;
  late MockReserveRepository reserve;

  setUpAll(registerAllocationFallbacks);
  setUp(() {
    repository = allocationRepositoryWith(novemberPlan);
    reserve = reserveRepositoryWith(reserveSummary);
  });

  const failure = ApiError(code: 'network_error');
  const refused = ApiError(code: 'insufficient_reserve');
  final november = DateTime(2026, 11);
  final view = AllocationView(
    plan: novemberPlan,
    targets: allocationTargets,
    accounts: reserveSummary.accounts,
  );
  final loaded = AllocationState(month: november, view: LoadState.loaded(view));

  AllocationCubit build() => AllocationCubit(repository, reserve);

  group('AllocationCubit', () {
    test('starts in the current month', () {
      final now = DateTime.now();
      expect(build().state.month, DateTime(now.year, now.month));
    });

    blocTest<AllocationCubit, AllocationState>(
      'loads the plan, the targets and the reserve accounts of a month',
      build: build,
      act: (cubit) => cubit.load(month: november),
      expect: () => [AllocationState(month: november), loaded],
    );

    blocTest<AllocationCubit, AllocationState>(
      'reports a failure',
      setUp: () => when(repository.targets).thenThrow(failure),
      build: build,
      act: (cubit) => cubit.load(month: november),
      expect: () => [
        AllocationState(month: november),
        AllocationState(
          month: november,
          view: const LoadState.failure(failure),
        ),
      ],
    );

    blocTest<AllocationCubit, AllocationState>(
      'moves between months',
      build: build,
      seed: () => loaded,
      act: (cubit) async {
        await cubit.previous();
        await cubit.next();
      },
      verify: (_) {
        verify(() => repository.plan(DateTime(2026, 10))).called(1);
        verify(() => repository.plan(november)).called(1);
      },
    );

    blocTest<AllocationCubit, AllocationState>(
      'uses a target and reloads quietly',
      build: build,
      seed: () => loaded,
      act: (cubit) async {
        expect(
          await cubit.use(novemberPlan.items.first, amountCents: 900),
          isNull,
        );
      },
      expect: () => <AllocationState>[],
      verify: (_) =>
          verify(() => repository.use('target-1', november, amountCents: 900))
              .called(1),
    );

    blocTest<AllocationCubit, AllocationState>(
      'undoes an allocation and deletes a target',
      build: build,
      seed: () => loaded,
      act: (cubit) async {
        await cubit.undo(novemberPlan.items[1]);
        await cubit.deleteTarget('target-3');
      },
      verify: (_) {
        verify(() => repository.undo('allocation-1')).called(1);
        verify(() => repository.deleteTarget('target-3')).called(1);
      },
    );

    blocTest<AllocationCubit, AllocationState>(
      'returns the error when undoing is refused',
      setUp: () => when(() => repository.undo(any())).thenThrow(refused),
      build: build,
      seed: () => loaded,
      act: (cubit) async =>
          expect(await cubit.undo(novemberPlan.items[1]), refused),
      expect: () => <AllocationState>[],
    );
  });

  test('finds targets and account names in the view', () {
    expect(view.target('target-2'), charity);
    expect(view.target('missing'), isNull);
    expect(view.accountName('reserve-account-1'), 'Tesouro Selic');
    expect(view.accountName(null), isNull);
    expect(novemberPlan.hasRemainder, isTrue);
  });

  group('AllocationTargetFormCubit', () {
    blocTest<AllocationTargetFormCubit, Submission<AllocationTarget>>(
      'creates a target',
      build: () => AllocationTargetFormCubit(repository),
      act: (cubit) => cubit.save(targetDraft),
      expect: () => const [
        Submission<AllocationTarget>.inProgress(),
        Submission<AllocationTarget>.success(fixedIncome),
      ],
    );

    blocTest<AllocationTargetFormCubit, Submission<AllocationTarget>>(
      'updates a target',
      build: () => AllocationTargetFormCubit(repository),
      act: (cubit) => cubit.save(targetDraft, id: 'target-1'),
      verify: (_) =>
          verify(() => repository.updateTarget('target-1', targetDraft))
              .called(1),
    );
  });
}
