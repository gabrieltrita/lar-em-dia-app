import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';

enum UserRole { user, admin }

@freezed
abstract class AuthUser with _$AuthUser {
  const factory({
    required String id,
    required String email,
    required String firstName,
    required bool twoFactorEnabled,
    String? lastName,
    @Default(UserRole.user) UserRole role,
  }) = _AuthUser;

  const new _();

  bool get isAdmin => role == UserRole.admin;
}
