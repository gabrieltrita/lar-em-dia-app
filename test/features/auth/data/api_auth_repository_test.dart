import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/network/token_transport.dart';
import 'package:lar_em_dia/features/auth/data/api_auth_repository.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:lar_em_dia/features/auth/domain/login_result.dart';

import '../../../helpers/auth_fixtures.dart';
import '../../../helpers/fake_adapter.dart';
import '../../../helpers/memory_token_storage.dart';

void main() {
  late MemoryTokenStorage storage;
  late FakeAdapter adapter;

  const userJson = {
    'id': 'user-1',
    'email': 'ana@example.com',
    'first_name': 'Ana',
    'last_name': 'Souza',
    'two_factor_enabled': true,
  };

  ResponseBody session({String refresh = 'r2'}) => FakeAdapter.json(200, {
    'data': {
      'user': userJson,
      'tokens': {'access_token': 'a2', 'refresh_token': refresh},
    },
  });

  ResponseBody accepted() => FakeAdapter.json(202, {
    'data': {'message': 'ok'},
  });

  ResponseBody failure(int status, String code) => FakeAdapter.json(status, {
    'error': {'code': code},
  });

  ApiAuthRepository build(
    FakeHandler handler, {
    TokenTransport transport = TokenTransport.body,
  }) {
    adapter = FakeAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return ApiAuthRepository(ApiClient(dio), storage, transport);
  }

  RequestOptions lastRequest() => adapter.requests.last;

  setUp(() => storage = MemoryTokenStorage());

  test('login stores the tokens and returns the user', () async {
    final repository = build((_) => session());

    final result = await repository.login(
      email: 'ana@example.com',
      password: 'Secret123',
    );

    expect(
      result,
      const LoginResult.authenticated(
        AuthUser(
          id: 'user-1',
          email: 'ana@example.com',
          firstName: 'Ana',
          lastName: 'Souza',
          twoFactorEnabled: true,
        ),
      ),
    );
    expect(lastRequest().path, '/auth/login');
    expect(lastRequest().data, {
      'email': 'ana@example.com',
      'password': 'Secret123',
    });
    expect(storage.accessToken, 'a2');
    expect(storage.refreshToken, 'r2');
  });

  test('signs in with a Google ID token', () async {
    final repository = build((_) => session());

    final result = await repository.signInWithGoogle('google-token');

    expect(result, isA<LoginAuthenticated>());
    expect(lastRequest().path, '/auth/oauth/google');
    expect(lastRequest().data, {'id_token': 'google-token'});
    expect(storage.refreshToken, 'r2');
  });

  test('accepts the consents when Google creates the account', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': {'two_factor_required': true, 'challenge_token': 'c1'},
      }),
    );

    final result = await repository.signInWithGoogle(
      'google-token',
      acceptConsents: true,
    );

    expect(result, const LoginResult.twoFactorRequired('c1'));
    expect(lastRequest().data, {
      'id_token': 'google-token',
      'accept_terms': true,
      'accept_privacy': true,
    });
  });

  test('login reads the role and falls back to user', () async {
    for (final (role, expected) in [
      ('admin', UserRole.admin),
      ('owner', UserRole.user),
    ]) {
      final repository = build(
        (_) => FakeAdapter.json(200, {
          'data': {
            'user': {...userJson, 'role': role},
            'tokens': {'access_token': 'a2', 'refresh_token': 'r2'},
          },
        }),
      );

      final result = await repository.login(
        email: 'ana@example.com',
        password: 'Secret123',
      );

      expect(
        result,
        isA<LoginAuthenticated>().having(
          (result) => result.user.role,
          'role',
          expected,
        ),
      );
    }
  });

  test('login returns the 2FA challenge without storing tokens', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': {'two_factor_required': true, 'challenge_token': 'c1'},
      }),
    );

    final result = await repository.login(email: 'a@b.co', password: 'x');

    expect(result, const LoginResult.twoFactorRequired('c1'));
    expect(storage.accessToken, isNull);
  });

  test('login surfaces API errors', () async {
    final repository = build((_) => failure(401, 'invalid_credentials'));

    await expectLater(
      repository.login(email: 'a@b.co', password: 'x'),
      throwsA(
        isA<ApiError>().having((e) => e.code, 'code', 'invalid_credentials'),
      ),
    );
  });

  test('verifyTwoFactor finishes the login', () async {
    final repository = build((_) => session());

    final user = await repository.verifyTwoFactor(
      challengeToken: 'c1',
      code: '123456',
    );

    expect(user.firstName, 'Ana');
    expect(lastRequest().path, '/auth/two_factor');
    expect(lastRequest().data, {'challenge_token': 'c1', 'code': '123456'});
  });

  test('register sends the consents and the confirmation', () async {
    final repository = build((_) => accepted());

    await repository.register(anaRegistration);

    expect(lastRequest().path, '/auth/register');
    expect(lastRequest().data, {
      'first_name': 'Ana',
      'last_name': 'Souza',
      'email': 'ana@example.com',
      'password': 'Secret123',
      'password_confirmation': 'Secret123',
      'accept_terms': true,
      'accept_privacy': true,
    });
  });

  test('register omits a missing last name', () async {
    final repository = build((_) => accepted());

    await repository.register(anaRegistration.copyWith(lastName: null));

    expect(lastRequest().data, isNot(contains('last_name')));
  });

  test('resendConfirmation and requestPasswordReset send the email', () async {
    final repository = build((_) => accepted());

    await repository.resendConfirmation('ana@example.com');
    expect(lastRequest().path, '/auth/confirm/resend');
    expect(lastRequest().data, {'email': 'ana@example.com'});

    await repository.requestPasswordReset('ana@example.com');
    expect(lastRequest().path, '/auth/password/forgot');
    expect(lastRequest().data, {'email': 'ana@example.com'});
  });

  test('confirmEmail signs in with the emailed token', () async {
    final repository = build((_) => session());

    final user = await repository.confirmEmail('t1');

    expect(user.id, 'user-1');
    expect(lastRequest().path, '/auth/confirm');
    expect(lastRequest().data, {'token': 't1'});
    expect(storage.accessToken, 'a2');
  });

  test('resetPassword sends the token and the confirmation', () async {
    final repository = build((_) => accepted());

    await repository.resetPassword(token: 't1', password: 'Secret123');

    expect(lastRequest().path, '/auth/password/reset');
    expect(lastRequest().data, {
      'token': 't1',
      'password': 'Secret123',
      'password_confirmation': 'Secret123',
    });
  });

  group('restoreSession', () {
    test('returns null without a refresh token in body mode', () async {
      final repository = build((_) => throw StateError('no request'));

      expect(await repository.restoreSession(), isNull);
      expect(adapter.requests, isEmpty);
    });

    test('refreshes with the stored token', () async {
      storage = MemoryTokenStorage(refreshToken: 'r1');
      final repository = build((_) => session());

      final user = await repository.restoreSession();

      expect(user?.id, 'user-1');
      expect(lastRequest().path, '/auth/refresh');
      expect(lastRequest().data, {'refresh_token': 'r1'});
      expect(storage.refreshToken, 'r2');
    });

    test('relies on the cookie in cookie mode', () async {
      final repository = build(
        (_) => FakeAdapter.json(200, {
          'data': {
            'user': userJson,
            'tokens': {'access_token': 'a2'},
          },
        }),
        transport: TokenTransport.cookie,
      );

      final user = await repository.restoreSession();

      expect(user?.id, 'user-1');
      expect(lastRequest().data, isEmpty);
      expect(storage.refreshToken, isNull);
    });

    test('clears the tokens when the refresh fails', () async {
      storage = MemoryTokenStorage(refreshToken: 'r1');
      final repository = build((_) => failure(401, 'invalid_token'));

      expect(await repository.restoreSession(), isNull);
      expect(storage.refreshToken, isNull);
    });
  });

  group('logout', () {
    test('revokes the session and clears the tokens', () async {
      storage = MemoryTokenStorage(accessToken: 'a1', refreshToken: 'r1');
      final repository = build((_) => FakeAdapter.json(204, null));

      await repository.logout();

      expect(lastRequest().method, 'DELETE');
      expect(lastRequest().path, '/auth/logout');
      expect(storage.accessToken, isNull);
      expect(storage.refreshToken, isNull);
    });

    test('clears the tokens even when the API fails', () async {
      storage = MemoryTokenStorage(accessToken: 'a1', refreshToken: 'r1');
      final repository = build((_) => failure(401, 'token_revoked'));

      await repository.logout();

      expect(storage.accessToken, isNull);
    });
  });
}
