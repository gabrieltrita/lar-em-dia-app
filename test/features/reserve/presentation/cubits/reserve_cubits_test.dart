import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/reserve/presentation/cubits/reserve_cubits.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/reserve_fixtures.dart';

void main() {
  late MockReserveRepository repository;

  setUpAll(registerReserveFallbacks);

  setUp(() {
    repository = reserveRepositoryWith(reserveSummary);
    when(() => repository.projection(any()))
        .thenAnswer((_) async => reserveProjection);
    when(() => repository.movements(treasury.id))
        .thenAnswer((_) async => [anchorMovement, depositMovement]);
  });

  const failure = ApiError(code: 'network_error');
  const refused = ApiError(code: 'insufficient_reserve');
  final view = ReserveView(
    summary: reserveSummary,
    projection: reserveProjection,
  );

  group('ReserveCubit', () {
    blocTest<ReserveCubit, LoadState<ReserveView>>(
      'loads the summary and a year of projection',
      build: () => ReserveCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const LoadState<ReserveView>.loading(),
        LoadState.loaded(view),
      ],
      verify: (_) => verify(() => repository.projection(12)).called(1),
    );

    blocTest<ReserveCubit, LoadState<ReserveView>>(
      'reports a failure',
      setUp: () => when(() => repository.projection(any())).thenThrow(failure),
      build: () => ReserveCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => const [
        LoadState<ReserveView>.loading(),
        LoadState<ReserveView>.failure(failure),
      ],
    );

    blocTest<ReserveCubit, LoadState<ReserveView>>(
      'switches the period quietly and keeps it on reload',
      build: () => ReserveCubit(repository),
      seed: () => LoadState.loaded(view),
      act: (cubit) async {
        await cubit.selectPeriod(ReservePeriod.fiveYears);
        await cubit.load(quiet: true);
      },
      expect: () => [
        LoadState.loaded(view.copyWith(period: ReservePeriod.fiveYears)),
      ],
      verify: (_) => verify(() => repository.projection(60)).called(2),
    );

    blocTest<ReserveCubit, LoadState<ReserveView>>(
      'updates the goal and reloads',
      setUp: () =>
          when(() => repository.updateGoal(months: 8, cents: 2000000))
              .thenAnswer((_) async => reserveSummary),
      build: () => ReserveCubit(repository),
      seed: () => LoadState.loaded(view),
      act: (cubit) async {
        expect(await cubit.updateGoal(months: 8, cents: 2000000), isNull);
      },
      verify: (_) => verify(repository.summary).called(1),
    );

    blocTest<ReserveCubit, LoadState<ReserveView>>(
      'returns the error of a refused goal',
      setUp: () =>
          when(() => repository.updateGoal(months: 30))
              .thenThrow(const ApiError(code: 'validation_failed')),
      build: () => ReserveCubit(repository),
      act: (cubit) async {
        final error = await cubit.updateGoal(months: 30);
        expect(error?.code, 'validation_failed');
      },
      expect: () => const <LoadState<ReserveView>>[],
    );
  });

  group('ReserveAccountCubit', () {
    final detail = ReserveAccountDetail(
      account: treasury,
      movements: [depositMovement, anchorMovement],
    );

    blocTest<ReserveAccountCubit, LoadState<ReserveAccountDetail>>(
      'loads the account with the latest movements first',
      build: () => ReserveAccountCubit(repository, treasury.id),
      act: (cubit) => cubit.load(),
      expect: () => [
        const LoadState<ReserveAccountDetail>.loading(),
        LoadState.loaded(detail),
      ],
    );

    blocTest<ReserveAccountCubit, LoadState<ReserveAccountDetail>>(
      'reports an account that no longer exists',
      setUp: () =>
          when(() => repository.movements('gone')).thenAnswer((_) async => []),
      build: () => ReserveAccountCubit(repository, 'gone'),
      act: (cubit) => cubit.load(),
      expect: () => const [
        LoadState<ReserveAccountDetail>.loading(),
        LoadState<ReserveAccountDetail>.failure(ApiError(code: 'not_found')),
      ],
    );

    blocTest<ReserveAccountCubit, LoadState<ReserveAccountDetail>>(
      'reports a failure',
      setUp: () => when(repository.summary).thenThrow(failure),
      build: () => ReserveAccountCubit(repository, treasury.id),
      act: (cubit) => cubit.load(),
      expect: () => const [
        LoadState<ReserveAccountDetail>.loading(),
        LoadState<ReserveAccountDetail>.failure(failure),
      ],
    );

    blocTest<ReserveAccountCubit, LoadState<ReserveAccountDetail>>(
      'deletes a movement and reloads quietly',
      setUp: () =>
          when(() => repository.deleteMovement(depositMovement))
              .thenAnswer((_) async {}),
      build: () => ReserveAccountCubit(repository, treasury.id),
      seed: () => LoadState.loaded(detail),
      act: (cubit) async {
        expect(await cubit.deleteMovement(depositMovement), isNull);
      },
      verify: (_) => verify(repository.summary).called(1),
    );

    blocTest<ReserveAccountCubit, LoadState<ReserveAccountDetail>>(
      'returns the refusal of a movement deletion',
      setUp: () =>
          when(() => repository.deleteMovement(depositMovement))
              .thenThrow(refused),
      build: () => ReserveAccountCubit(repository, treasury.id),
      act: (cubit) async {
        expect(await cubit.deleteMovement(depositMovement), refused);
      },
      expect: () => const <LoadState<ReserveAccountDetail>>[],
    );

    blocTest<ReserveAccountCubit, LoadState<ReserveAccountDetail>>(
      'deletes the account',
      setUp: () =>
          when(() => repository.deleteAccount(treasury.id))
              .thenAnswer((_) async {}),
      build: () => ReserveAccountCubit(repository, treasury.id),
      act: (cubit) async {
        expect(await cubit.deleteAccount(), isNull);
      },
      expect: () => const <LoadState<ReserveAccountDetail>>[],
    );

    blocTest<ReserveAccountCubit, LoadState<ReserveAccountDetail>>(
      'returns the error of an account deletion',
      setUp: () =>
          when(() => repository.deleteAccount(treasury.id)).thenThrow(failure),
      build: () => ReserveAccountCubit(repository, treasury.id),
      act: (cubit) async {
        expect(await cubit.deleteAccount(), failure);
      },
      expect: () => const <LoadState<ReserveAccountDetail>>[],
    );
  });

  group('ReserveCardCubit', () {
    final now = DateTime(2026, 11, 12);

    blocTest<ReserveCardCubit, ReserveCard?>(
      'shows the totals of a reserve',
      build: () => ReserveCardCubit(repository, dismissalUntil(null)),
      act: (cubit) => cubit.load(now: now),
      expect: () => [ReserveCard(summary: reserveSummary, dismissed: false)],
      verify: (cubit) => expect(cubit.state!.visible, isTrue),
    );

    blocTest<ReserveCardCubit, ReserveCard?>(
      'hides the invitation while dismissed and shows it after 30 days',
      build: () => ReserveCardCubit(
        reserveRepositoryWith(noReserve),
        dismissalUntil(DateTime(2026, 11, 20)),
      ),
      act: (cubit) async {
        await cubit.load(now: now);
        expect(cubit.state!.visible, isFalse);
        await cubit.load(now: DateTime(2026, 11, 21));
        expect(cubit.state!.visible, isTrue);
      },
      expect: () => const [
        ReserveCard(summary: noReserve, dismissed: true),
        ReserveCard(summary: noReserve, dismissed: false),
      ],
    );

    blocTest<ReserveCardCubit, ReserveCard?>(
      'hides itself without fixed expenses or accounts',
      build: () => ReserveCardCubit(
        reserveRepositoryWith(emptyReserve),
        dismissalUntil(null),
      ),
      act: (cubit) => cubit.load(now: now),
      verify: (cubit) => expect(cubit.state!.visible, isFalse),
    );

    late MockReserveDismissal dismissal;
    blocTest<ReserveCardCubit, ReserveCard?>(
      'dismisses the invitation',
      setUp: () => dismissal = dismissalUntil(null),
      build: () =>
          ReserveCardCubit(reserveRepositoryWith(noReserve), dismissal),
      act: (cubit) async {
        await cubit.dismiss(now: now);
        await cubit.load(now: now);
        await cubit.dismiss(now: now);
      },
      expect: () => const [
        ReserveCard(summary: noReserve, dismissed: false),
        ReserveCard(summary: noReserve, dismissed: true),
      ],
      verify: (_) => verify(() => dismissal.dismiss(now)).called(2),
    );

    blocTest<ReserveCardCubit, ReserveCard?>(
      'shows nothing when the summary fails',
      setUp: () => when(repository.summary).thenThrow(failure),
      build: () => ReserveCardCubit(repository, dismissalUntil(null)),
      seed: () => const ReserveCard(summary: noReserve, dismissed: false),
      act: (cubit) => cubit.load(),
      expect: () => const <ReserveCard?>[null],
    );
  });

  group('ReserveAccountFormCubit', () {
    blocTest<ReserveAccountFormCubit, Submission<ReserveAccount>>(
      'creates the account with its balance of today',
      setUp: () {
        when(() => repository.createAccount(treasuryDraft))
            .thenAnswer((_) async => treasury);
        when(() => repository.createMovement(any()))
            .thenAnswer((_) async => anchorMovement);
      },
      build: () => ReserveAccountFormCubit(repository),
      act: (cubit) => cubit.save(
        treasuryDraft,
        anchorCents: 1200000,
        today: DateTime(2026, 11, 12),
      ),
      expect: () => const [
        Submission<ReserveAccount>.inProgress(),
        Submission<ReserveAccount>.success(treasury),
      ],
      verify: (_) => verify(
        () => repository.createMovement(
          ReserveMovementDraft(
            accountId: treasury.id,
            kind: ReserveMovementKind.anchor,
            movedOn: DateTime(2026, 11, 12),
            amountCents: 1200000,
          ),
        ),
      ).called(1),
    );

    blocTest<ReserveAccountFormCubit, Submission<ReserveAccount>>(
      'creates the account alone without a balance',
      setUp: () =>
          when(() => repository.createAccount(treasuryDraft))
              .thenAnswer((_) async => treasury),
      build: () => ReserveAccountFormCubit(repository),
      act: (cubit) => cubit.save(treasuryDraft),
      expect: () => const [
        Submission<ReserveAccount>.inProgress(),
        Submission<ReserveAccount>.success(treasury),
      ],
      verify: (_) => verifyNever(() => repository.createMovement(any())),
    );

    blocTest<ReserveAccountFormCubit, Submission<ReserveAccount>>(
      'updates an existing account',
      setUp: () =>
          when(() => repository.updateAccount(treasury.id, treasuryDraft))
              .thenAnswer((_) async => treasury),
      build: () => ReserveAccountFormCubit(repository),
      act: (cubit) =>
          cubit.save(treasuryDraft, accountId: treasury.id, anchorCents: 100),
      expect: () => const [
        Submission<ReserveAccount>.inProgress(),
        Submission<ReserveAccount>.success(treasury),
      ],
      verify: (_) => verifyNever(() => repository.createMovement(any())),
    );
  });

  group('ReserveMovementFormCubit', () {
    blocTest<ReserveMovementFormCubit, Submission<ReserveMovement>>(
      'creates a movement',
      setUp: () =>
          when(() => repository.createMovement(depositDraft))
              .thenAnswer((_) async => depositMovement),
      build: () => ReserveMovementFormCubit(repository),
      act: (cubit) => cubit.save(depositDraft),
      expect: () => [
        const Submission<ReserveMovement>.inProgress(),
        Submission<ReserveMovement>.success(depositMovement),
      ],
    );

    blocTest<ReserveMovementFormCubit, Submission<ReserveMovement>>(
      'updates a movement',
      setUp: () =>
          when(() => repository.updateMovement(depositMovement, depositDraft))
              .thenAnswer((_) async => depositMovement),
      build: () => ReserveMovementFormCubit(repository),
      act: (cubit) => cubit.save(depositDraft, existing: depositMovement),
      expect: () => [
        const Submission<ReserveMovement>.inProgress(),
        Submission<ReserveMovement>.success(depositMovement),
      ],
    );
  });
}
