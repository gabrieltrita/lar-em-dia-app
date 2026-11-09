import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/security/domain/two_factor.dart';
import 'package:lar_em_dia/features/security/presentation/cubits/security_cubits.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/security_fixtures.dart';

void main() {
  late MockSecurityRepository repository;

  setUpAll(registerSecurityFallbacks);
  setUp(() => repository = MockSecurityRepository());

  const wrongPassword = ApiError(code: 'invalid_current_password');

  group('SecurityCubit', () {
    blocTest<SecurityCubit, LoadState<TwoFactorStatus>>(
      'loads the status',
      setUp: () =>
          when(repository.twoFactorStatus).thenAnswer((_) async => twoFactorOn),
      build: () => SecurityCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => const [
        LoadState<TwoFactorStatus>.loading(),
        LoadState.loaded(twoFactorOn),
      ],
    );

    blocTest<SecurityCubit, LoadState<TwoFactorStatus>>(
      'reports a failed load',
      setUp: () => when(repository.twoFactorStatus).thenThrow(wrongPassword),
      build: () => SecurityCubit(repository),
      act: (cubit) => cubit.load(),
      expect: () => const [
        LoadState<TwoFactorStatus>.loading(),
        LoadState<TwoFactorStatus>.failure(wrongPassword),
      ],
    );

    test('disables and reloads, or returns the error', () async {
      when(repository.twoFactorStatus).thenAnswer((_) async => twoFactorOff);
      when(() => repository.disableTwoFactor(passwordAndCode))
          .thenAnswer((_) async {});
      final cubit = SecurityCubit(repository);

      expect(await cubit.disable(passwordAndCode), isNull);
      expect(cubit.state, const LoadState.loaded(twoFactorOff));

      when(() => repository.disableTwoFactor(any())).thenThrow(wrongPassword);
      expect(await cubit.disable(passwordAndCode), wrongPassword);
      await cubit.close();
    });

    test('deletes the account or returns the error', () async {
      when(() => repository.deleteAccount(passwordAndCode))
          .thenAnswer((_) async {});
      final cubit = SecurityCubit(repository);

      expect(await cubit.deleteAccount(passwordAndCode), isNull);

      when(() => repository.deleteAccount(any())).thenThrow(wrongPassword);
      expect(await cubit.deleteAccount(passwordAndCode), wrongPassword);
      await cubit.close();
    });

    test('regenerates the backup codes or returns the error', () async {
      when(repository.twoFactorStatus).thenAnswer((_) async => twoFactorOn);
      when(() => repository.regenerateBackupCodes(passwordAndCode))
          .thenAnswer((_) async => backupCodes);
      final cubit = SecurityCubit(repository);

      expect(await cubit.regenerateBackupCodes(passwordAndCode), (
        codes: backupCodes,
        error: null,
      ));
      verify(repository.twoFactorStatus).called(1);

      when(() => repository.regenerateBackupCodes(any()))
          .thenThrow(wrongPassword);
      expect(await cubit.regenerateBackupCodes(passwordAndCode), (
        codes: null,
        error: wrongPassword,
      ));
      await cubit.close();
    });
  });

  group('TwoFactorEnrollmentCubit', () {
    blocTest<TwoFactorEnrollmentCubit, EnrollmentState>(
      'goes from the password to the code and to the backup codes',
      setUp: () {
        when(() => repository.setupTwoFactor(passwordOnly))
            .thenAnswer((_) async => twoFactorSetup);
        when(() => repository.enableTwoFactor('123456'))
            .thenAnswer((_) async => backupCodes);
      },
      build: () => TwoFactorEnrollmentCubit(repository),
      act: (cubit) async {
        await cubit.start('Secret123');
        await cubit.confirm('123456');
      },
      expect: () => const [
        EnrollmentState.password(busy: true),
        EnrollmentState.code(twoFactorSetup),
        EnrollmentState.code(twoFactorSetup, busy: true),
        EnrollmentState.done(backupCodes),
      ],
    );

    blocTest<TwoFactorEnrollmentCubit, EnrollmentState>(
      'keeps each step with its error',
      setUp: () {
        when(() => repository.setupTwoFactor(any())).thenThrow(wrongPassword);
        when(() => repository.enableTwoFactor(any()))
            .thenThrow(const ApiError(code: 'invalid_two_factor_code'));
      },
      seed: () => const EnrollmentState.code(twoFactorSetup),
      build: () => TwoFactorEnrollmentCubit(repository),
      act: (cubit) async {
        await cubit.confirm('000000');
        await cubit.start('wrong');
      },
      expect: () => const [
        EnrollmentState.code(twoFactorSetup, busy: true),
        EnrollmentState.code(
          twoFactorSetup,
          error: ApiError(code: 'invalid_two_factor_code'),
        ),
        EnrollmentState.password(busy: true),
        EnrollmentState.password(error: wrongPassword),
      ],
    );

    blocTest<TwoFactorEnrollmentCubit, EnrollmentState>(
      'ignores a code before the setup',
      build: () => TwoFactorEnrollmentCubit(repository),
      act: (cubit) => cubit.confirm('123456'),
      expect: () => const <EnrollmentState>[],
    );
  });
}
