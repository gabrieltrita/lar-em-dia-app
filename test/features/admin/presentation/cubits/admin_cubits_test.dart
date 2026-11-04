import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/admin/domain/admin_metrics.dart';
import 'package:lar_em_dia/features/admin/domain/admin_user.dart';
import 'package:lar_em_dia/features/admin/presentation/cubits/admin_cubits.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/admin_fixtures.dart';

void main() {
  late MockAdminRepository repository;

  setUpAll(registerAdminFallbacks);
  setUp(() => repository = MockAdminRepository());

  const failure = ApiError(code: 'two_factor_setup_required');
  const loading = LoadState<List<AdminUser>>.loading();

  void answerPage(int page, List<AdminUser> users, {int? next}) => when(
    () => repository.users(
      page: page,
      email: any(named: 'email'),
      status: any(named: 'status'),
    ),
  ).thenAnswer((_) async => AdminUserPage(users: users, nextPage: next));

  group('AdminUsersCubit', () {
    blocTest<AdminUsersCubit, AdminUsersState>(
      'loads the first page',
      setUp: () => answerPage(1, [carla], next: 2),
      build: () => AdminUsersCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => [
        const AdminUsersState(users: loading),
        AdminUsersState(users: LoadState.loaded([carla]), nextPage: 2),
      ],
    );

    blocTest<AdminUsersCubit, AdminUsersState>(
      'reports a failed load',
      setUp: () => when(
        () => repository.users(
          page: 1,
          email: any(named: 'email'),
          status: any(named: 'status'),
        ),
      ).thenThrow(failure),
      build: () => AdminUsersCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => const [
        AdminUsersState(users: loading),
        AdminUsersState(users: LoadState.failure(failure)),
      ],
    );

    blocTest<AdminUsersCubit, AdminUsersState>(
      'searches by the trimmed email and filters by status',
      setUp: () => answerPage(1, [bruno]),
      build: () => AdminUsersCubit(repository),
      act: (cubit) async {
        await cubit.search(' bruno@example.com ');
        await cubit.filter(AccountStatus.deactivated);
      },
      skip: 1,
      expect: () => [
        AdminUsersState(
          users: LoadState.loaded([bruno]),
          email: 'bruno@example.com',
        ),
        AdminUsersState(
          users: LoadState.loaded([bruno]),
          email: 'bruno@example.com',
          status: AccountStatus.deactivated,
        ),
        const AdminUsersState(
          users: loading,
          email: 'bruno@example.com',
          status: AccountStatus.deactivated,
        ),
        AdminUsersState(
          users: LoadState.loaded([bruno]),
          email: 'bruno@example.com',
          status: AccountStatus.deactivated,
        ),
      ],
      verify: (_) => verify(
        () => repository.users(
          page: 1,
          email: 'bruno@example.com',
          status: AccountStatus.deactivated,
        ),
      ).called(1),
    );

    test('appends the next page', () async {
      answerPage(1, [carla], next: 2);
      answerPage(2, [bruno]);
      final cubit = AdminUsersCubit(repository);
      await cubit.load();

      expect(await cubit.loadMore(), isNull);
      expect(cubit.state.users, LoadState.loaded([carla, bruno]));
      expect(cubit.state.nextPage, isNull);
      expect(cubit.state.loadingMore, isFalse);

      expect(await cubit.loadMore(), isNull);
      verify(
        () => repository.users(
          page: any(named: 'page'),
          email: any(named: 'email'),
          status: any(named: 'status'),
        ),
      ).called(2);
      await cubit.close();
    });

    test('keeps the list when the next page fails', () async {
      answerPage(1, [carla], next: 2);
      when(
        () => repository.users(
          page: 2,
          email: any(named: 'email'),
          status: any(named: 'status'),
        ),
      ).thenThrow(failure);
      final cubit = AdminUsersCubit(repository);
      await cubit.load();

      expect(await cubit.loadMore(), failure);
      expect(cubit.state.users, LoadState.loaded([carla]));
      expect(cubit.state.nextPage, 2);
      expect(cubit.state.loadingMore, isFalse);
      await cubit.close();
    });

    test('ignores more while loading or not loaded', () async {
      final pending = Completer<AdminUserPage>();
      answerPage(1, [carla], next: 2);
      final cubit = AdminUsersCubit(repository);
      expect(await cubit.loadMore(), isNull);
      await cubit.load();
      when(
        () => repository.users(
          page: 2,
          email: any(named: 'email'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) => pending.future);

      final first = cubit.loadMore();
      expect(await cubit.loadMore(), isNull);
      pending.complete(AdminUserPage(users: [bruno]));
      expect(await first, isNull);

      expect(cubit.state.users, LoadState.loaded([carla, bruno]));
      await cubit.close();
    });
  });

  group('AdminMetricsCubit', () {
    blocTest<AdminMetricsCubit, LoadState<AdminMetrics>>(
      'loads the metrics',
      setUp: () => when(repository.metrics).thenAnswer((_) async => metrics),
      build: () => AdminMetricsCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => const [
        LoadState<AdminMetrics>.loading(),
        LoadState.loaded(metrics),
      ],
    );

    blocTest<AdminMetricsCubit, LoadState<AdminMetrics>>(
      'reports a failed load',
      setUp: () => when(repository.metrics).thenThrow(failure),
      build: () => AdminMetricsCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => const [
        LoadState<AdminMetrics>.loading(),
        LoadState<AdminMetrics>.failure(failure),
      ],
    );
  });

  group('AdminUserCubit', () {
    blocTest<AdminUserCubit, LoadState<AdminUser>>(
      'loads the user',
      setUp: () =>
          when(() => repository.user('user-2')).thenAnswer((_) async => carla),
      build: () => AdminUserCubit(repository, 'user-2'),
      act: (cubit) => cubit.load(),
      expect: () => [
        const LoadState<AdminUser>.loading(),
        LoadState.loaded(carla),
      ],
    );

    blocTest<AdminUserCubit, LoadState<AdminUser>>(
      'reports a failed load',
      setUp: () => when(() => repository.user('user-2')).thenThrow(failure),
      build: () => AdminUserCubit(repository, 'user-2'),
      act: (cubit) => cubit.load(),
      expect: () => const [
        LoadState<AdminUser>.loading(),
        LoadState<AdminUser>.failure(failure),
      ],
    );

    final updated = carla.copyWith(signInCount: 5);
    final actions = <String, Future<ApiError?> Function(AdminUserCubit)>{
      'unlock': (cubit) => cubit.unlock(),
      'resetTwoFactor': (cubit) => cubit.resetTwoFactor(),
      'deactivate': (cubit) => cubit.deactivate(),
      'reactivate': (cubit) => cubit.reactivate(),
      'changeRole': (cubit) => cubit.changeRole(UserRole.admin),
    };

    void answerActions(Future<AdminUser> Function(Invocation) answer) {
      when(() => repository.unlock('user-2')).thenAnswer(answer);
      when(() => repository.deactivate('user-2')).thenAnswer(answer);
      when(() => repository.reactivate('user-2')).thenAnswer(answer);
      when(() => repository.changeRole('user-2', UserRole.admin))
          .thenAnswer(answer);
      when(() => repository.resetTwoFactor('user-2'))
          .thenAnswer((invocation) async {
            await answer(invocation);
          });
      when(() => repository.user('user-2')).thenAnswer(answer);
    }

    for (final MapEntry(key: name, value: run) in actions.entries) {
      test('$name shows the updated user', () async {
        answerActions((_) async => updated);
        final cubit = AdminUserCubit(repository, 'user-2');

        expect(await run(cubit), isNull);
        expect(cubit.state, LoadState.loaded(updated));
        await cubit.close();
      });

      test('$name returns the error and keeps the user', () async {
        when(() => repository.user('user-2')).thenAnswer((_) async => carla);
        final cubit = AdminUserCubit(repository, 'user-2');
        await cubit.load();
        answerActions((_) async => throw failure);

        expect(await run(cubit), failure);
        expect(cubit.state, LoadState.loaded(carla));
        await cubit.close();
      });
    }
  });
}
