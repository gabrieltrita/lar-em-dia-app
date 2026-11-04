import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';

part 'admin_user.freezed.dart';

enum AccountStatus { active, deactivated }

@freezed
abstract class AdminUser with _$AdminUser {
  const factory({
    required String id,
    required String email,
    required String fullName,
    required UserRole role,
    required bool emailConfirmed,
    required bool twoFactorEnabled,
    required bool locked,
    required bool deactivated,
    required int signInCount,
    required DateTime createdAt,
    DateTime? lastSignInAt,
  }) = _AdminUser;

  const new _();

  bool get isAdmin => role == UserRole.admin;
}

@freezed
abstract class AdminUserPage with _$AdminUserPage {
  const factory({required List<AdminUser> users, int? nextPage}) =
      _AdminUserPage;
}
