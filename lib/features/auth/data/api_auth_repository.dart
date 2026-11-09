import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/network/token_transport.dart';
import 'package:lar_em_dia/core/storage/token_storage.dart';
import 'package:lar_em_dia/features/auth/data/auth_user_dto.dart';
import 'package:lar_em_dia/features/auth/domain/auth_repository.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:lar_em_dia/features/auth/domain/login_result.dart';
import 'package:lar_em_dia/features/auth/domain/registration.dart';

@LazySingleton(as: AuthRepository)
class ApiAuthRepository implements AuthRepository {
  new(this._client, this._tokenStorage, this._transport);

  final ApiClient _client;
  final TokenStorage _tokenStorage;
  final TokenTransport _transport;

  @override
  Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post<Json>(
      '/auth/login',
      decode: _json,
      body: {'email': email, 'password': password},
    );
    return await _loginResult(response.data);
  }

  @override
  Future<LoginResult> signInWithGoogle(
    String idToken, {
    bool acceptConsents = false,
  }) async {
    final response = await _client.post<Json>(
      '/auth/oauth/google',
      decode: _json,
      body: {
        'id_token': idToken,
        if (acceptConsents) ...{'accept_terms': true, 'accept_privacy': true},
      },
    );
    return await _loginResult(response.data);
  }

  Future<LoginResult> _loginResult(Json data) async {
    if (data['two_factor_required'] == true) {
      return LoginResult.twoFactorRequired(data['challenge_token'] as String);
    }
    return LoginResult.authenticated(await _startSession(data));
  }

  @override
  Future<AuthUser> verifyTwoFactor({
    required String challengeToken,
    required String code,
  }) => _session('/auth/two_factor', {
    'challenge_token': challengeToken,
    'code': code,
  });

  @override
  Future<void> register(Registration registration) => _client.post<void>(
    '/auth/register',
    decode: _ignore,
    body: {
      'first_name': registration.firstName,
      'last_name': ?registration.lastName,
      'email': registration.email,
      'password': registration.password,
      'password_confirmation': registration.password,
      'accept_terms': registration.acceptTerms,
      'accept_privacy': registration.acceptPrivacy,
    },
  );

  @override
  Future<void> resendConfirmation(String email) => _client.post<void>(
    '/auth/confirm/resend',
    decode: _ignore,
    body: {'email': email},
  );

  @override
  Future<AuthUser> confirmEmail(String token) =>
      _session('/auth/confirm', {'token': token});

  @override
  Future<void> requestPasswordReset(String email) => _client.post<void>(
    '/auth/password/forgot',
    decode: _ignore,
    body: {'email': email},
  );

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) => _client.post<void>(
    '/auth/password/reset',
    decode: _ignore,
    body: {
      'token': token,
      'password': password,
      'password_confirmation': password,
    },
  );

  @override
  Future<AuthUser?> restoreSession() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null && !_transport.usesCookie) {
      return null;
    }
    try {
      return await _session('/auth/refresh', {'refresh_token': ?refreshToken});
    } on ApiError {
      await _tokenStorage.clear();
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _client.delete('/auth/logout');
    } on ApiError {
      return;
    } finally {
      await _tokenStorage.clear();
    }
  }

  Future<AuthUser> _session(String path, Json body) async {
    final response = await _client.post<Json>(path, decode: _json, body: body);
    return await _startSession(response.data);
  }

  Future<AuthUser> _startSession(Json data) async {
    final tokens = data['tokens'] as Json;
    await _tokenStorage.save(
      accessToken: tokens['access_token'] as String,
      refreshToken: tokens['refresh_token'] as String?,
    );
    return AuthUserDto.fromJson(data['user'] as Json).toDomain();
  }

  static Json _json(Object? data) => data! as Json;

  static void _ignore(Object? _) {}
}
