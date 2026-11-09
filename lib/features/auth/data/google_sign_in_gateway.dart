import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/config/env.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/auth/domain/google_auth_gateway.dart';

@LazySingleton(as: GoogleAuthGateway)
class GoogleSignInGateway implements GoogleAuthGateway {
  new(
    this._signIn, {
    @ignoreParam this._clientId = Env.googleClientId,
    @ignoreParam this._web = kIsWeb,
  });

  static const failedCode = 'google_sign_in_failed';

  final GoogleSignIn _signIn;
  final String _clientId;
  final bool _web;
  Future<void>? _initialized;

  Future<void> _initialize() => _initialized ??= _signIn.initialize(
    clientId: _web ? _clientId : null,
    serverClientId: _web ? null : _clientId,
  );

  @override
  bool get enabled => _clientId.isNotEmpty;

  @override
  bool get rendersOwnButton => !_signIn.supportsAuthenticate();

  @override
  Stream<String> get idTokens async* {
    await _initialize();
    yield* _signIn.authenticationEvents
        .handleError((Object _) {})
        .map(
          (event) => switch (event) {
            GoogleSignInAuthenticationEventSignIn(:final user) =>
              user.authentication.idToken,
            GoogleSignInAuthenticationEventSignOut() => null,
          },
        )
        .where((token) => token != null)
        .cast<String>();
  }

  @override
  Future<void> signIn() async {
    await _initialize();
    try {
      await _signIn.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return;
      }
      throw const ApiError(code: failedCode);
    }
  }
}
