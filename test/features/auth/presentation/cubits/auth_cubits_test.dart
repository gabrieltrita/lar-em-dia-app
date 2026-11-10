import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:lar_em_dia/features/auth/domain/login_result.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';

void main() {
  late MockAuthRepository repository;

  setUpAll(registerAuthFallbacks);
  setUp(() => repository = MockAuthRepository());

  blocTest<LoginCubit, Submission<LoginResult>>(
    'LoginCubit returns the login result',
    setUp: () => when(
      () => repository.login(email: 'ana@example.com', password: 'Secret123'),
    ).thenAnswer((_) async => const LoginResult.authenticated(ana)),
    build: () => LoginCubit(repository),
    act: (cubit) =>
        cubit.submit(email: 'ana@example.com', password: 'Secret123'),
    expect: () => const [
      Submission<LoginResult>.inProgress(),
      Submission.success(LoginResult.authenticated(ana)),
    ],
  );

  blocTest<LoginCubit, Submission<LoginResult>>(
    'LoginCubit reports API errors',
    setUp: () => when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const ApiError(code: 'invalid_credentials')),
    build: () => LoginCubit(repository),
    act: (cubit) => cubit.submit(email: 'a@b.co', password: 'x'),
    expect: () => const [
      Submission<LoginResult>.inProgress(),
      Submission<LoginResult>.failure(ApiError(code: 'invalid_credentials')),
    ],
  );

  blocTest<TwoFactorCubit, Submission<AuthUser>>(
    'TwoFactorCubit verifies the code',
    setUp: () => when(
      () => repository.verifyTwoFactor(challengeToken: 'c1', code: '123456'),
    ).thenAnswer((_) async => ana),
    build: () => TwoFactorCubit(repository),
    act: (cubit) => cubit.submit(challengeToken: 'c1', code: '123456'),
    expect: () => const [
      Submission<AuthUser>.inProgress(),
      Submission.success(ana),
    ],
  );

  blocTest<RegisterCubit, Submission<String>>(
    'RegisterCubit returns the registered email',
    setUp: () =>
        when(() => repository.register(anaRegistration))
            .thenAnswer((_) async {}),
    build: () => RegisterCubit(repository),
    act: (cubit) => cubit.submit(anaRegistration),
    expect: () => const [
      Submission<String>.inProgress(),
      Submission.success('ana@example.com'),
    ],
  );

  blocTest<ResendConfirmationCubit, Submission<void>>(
    'ResendConfirmationCubit resends the link',
    setUp: () =>
        when(() => repository.resendConfirmation('ana@example.com'))
            .thenAnswer((_) async {}),
    build: () => ResendConfirmationCubit(repository),
    act: (cubit) => cubit.submit('ana@example.com'),
    expect: () => [
      const Submission<void>.inProgress(),
      isA<SubmissionSuccess<void>>(),
    ],
  );

  blocTest<ConfirmEmailCubit, Submission<AuthUser>>(
    'ConfirmEmailCubit signs in with the token',
    setUp: () =>
        when(() => repository.confirmEmail('t1')).thenAnswer((_) async => ana),
    build: () => ConfirmEmailCubit(repository),
    act: (cubit) => cubit.submit('t1'),
    expect: () => const [
      Submission<AuthUser>.inProgress(),
      Submission.success(ana),
    ],
  );

  blocTest<UnlockCubit, Submission<LoginResult>>(
    'UnlockCubit returns the session or the 2FA challenge',
    setUp: () =>
        when(() => repository.unlock('t1'))
            .thenAnswer((_) async => const LoginResult.twoFactorRequired('c1')),
    build: () => UnlockCubit(repository),
    act: (cubit) => cubit.submit('t1'),
    expect: () => const [
      Submission<LoginResult>.inProgress(),
      Submission.success(LoginResult.twoFactorRequired('c1')),
    ],
  );

  blocTest<ForgotPasswordCubit, Submission<void>>(
    'ForgotPasswordCubit requests the reset link',
    setUp: () =>
        when(() => repository.requestPasswordReset('ana@example.com'))
            .thenAnswer((_) async {}),
    build: () => ForgotPasswordCubit(repository),
    act: (cubit) => cubit.submit('ana@example.com'),
    expect: () => [
      const Submission<void>.inProgress(),
      isA<SubmissionSuccess<void>>(),
    ],
  );

  blocTest<ResetPasswordCubit, Submission<void>>(
    'ResetPasswordCubit resets the password',
    setUp: () =>
        when(() => repository.resetPassword(token: 't1', password: 'Secret123'))
            .thenAnswer((_) async {}),
    build: () => ResetPasswordCubit(repository),
    act: (cubit) => cubit.submit(token: 't1', password: 'Secret123'),
    expect: () => [
      const Submission<void>.inProgress(),
      isA<SubmissionSuccess<void>>(),
    ],
  );

  group('GoogleSignInCubit', () {
    late FakeGoogleAuth google;

    setUp(() => google = FakeGoogleAuth());
    tearDown(() => google.dispose());

    test('exposes the gateway', () async {
      final cubit = GoogleSignInCubit(repository, google);

      expect(cubit.enabled, isTrue);
      expect(cubit.rendersOwnButton, isFalse);
      expect(cubit.idTokens, emits('token'));
      google.emit('token');
      await cubit.close();
    });

    blocTest<GoogleSignInCubit, Submission<LoginResult>>(
      'starts the Google sign-in without changing the state',
      build: () => GoogleSignInCubit(repository, google),
      act: (cubit) => cubit.start(),
      expect: () => const <Submission<LoginResult>>[],
      verify: (_) => expect(google.signIns, 1),
    );

    blocTest<GoogleSignInCubit, Submission<LoginResult>>(
      'reports a failed Google sign-in',
      setUp: () =>
          google.failure = const ApiError(code: 'google_sign_in_failed'),
      build: () => GoogleSignInCubit(repository, google),
      act: (cubit) => cubit.start(),
      expect: () => const [
        Submission<LoginResult>.failure(
          ApiError(code: 'google_sign_in_failed'),
        ),
      ],
    );

    blocTest<GoogleSignInCubit, Submission<LoginResult>>(
      'sends the token, then accepts the consents with the same token',
      setUp: () {
        when(() => repository.signInWithGoogle('token')).thenThrow(
          const ApiError(
            code: 'validation_failed',
            details: {
              'accept_terms': [FieldError(code: 'required')],
            },
          ),
        );
        when(() => repository.signInWithGoogle('token', acceptConsents: true))
            .thenAnswer((_) async => const LoginResult.authenticated(ana));
      },
      build: () => GoogleSignInCubit(repository, google),
      act: (cubit) async {
        await cubit.submit('token');
        await cubit.acceptConsents();
      },
      expect: () => const [
        Submission<LoginResult>.inProgress(),
        Submission<LoginResult>.failure(
          ApiError(
            code: 'validation_failed',
            details: {
              'accept_terms': [FieldError(code: 'required')],
            },
          ),
        ),
        Submission<LoginResult>.inProgress(),
        Submission.success(LoginResult.authenticated(ana)),
      ],
    );

    test('needs the consents only for a missing accept_terms', () {
      expect(
        GoogleSignInCubit.needsConsents(
          const ApiError(
            code: 'validation_failed',
            details: {
              'accept_terms': [FieldError(code: 'required')],
            },
          ),
        ),
        isTrue,
      );
      expect(
        GoogleSignInCubit.needsConsents(
          const ApiError(code: 'validation_failed'),
        ),
        isFalse,
      );
      expect(
        GoogleSignInCubit.needsConsents(
          const ApiError(code: 'oauth_token_invalid'),
        ),
        isFalse,
      );
    });
  });
}
