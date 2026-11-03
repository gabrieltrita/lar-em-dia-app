import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';

@freezed
abstract class AuthUser with _$AuthUser {
  const factory({
    required String id,
    required String email,
    required String firstName,
    required bool twoFactorEnabled,
    String? lastName,
  }) = _AuthUser;
}
