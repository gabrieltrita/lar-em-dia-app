import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:lar_em_dia/features/auth/domain/login_result.dart';
import 'package:lar_em_dia/features/auth/domain/registration.dart';

abstract interface class AuthRepository {
  Future<LoginResult> login({required String email, required String password});

  Future<LoginResult> signInWithGoogle(
    String idToken, {
    bool acceptConsents = false,
  });

  Future<AuthUser> verifyTwoFactor({
    required String challengeToken,
    required String code,
  });

  Future<void> register(Registration registration);

  Future<void> resendConfirmation(String email);

  Future<AuthUser> confirmEmail(String token);

  Future<LoginResult> unlock(String token);

  Future<void> requestPasswordReset(String email);

  Future<void> resetPassword({required String token, required String password});

  Future<AuthUser?> restoreSession();

  Future<void> logout();
}
