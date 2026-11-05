import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';

part 'login_result.freezed.dart';

@freezed
sealed class LoginResult with _$LoginResult {
  const factory authenticated(AuthUser user) = LoginAuthenticated;
  const factory twoFactorRequired(String challengeToken) =
      LoginTwoFactorRequired;
}
