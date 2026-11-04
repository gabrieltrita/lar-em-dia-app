import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/features/admin/domain/admin_user.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';

part 'admin_user_dto.freezed.dart';
part 'admin_user_dto.g.dart';

@freezed
abstract class AdminUserDto with _$AdminUserDto {
  const factory({
    required String id,
    required String email,
    required String fullName,
    required DateTime createdAt,
    @JsonKey(unknownEnumValue: UserRole.user)
    @Default(UserRole.user)
    UserRole role,
    @Default(false) bool emailConfirmed,
    @Default(false) bool twoFactorEnabled,
    @Default(false) bool locked,
    @Default(false) bool deactivated,
    @Default(0) int signInCount,
    DateTime? lastSignInAt,
  }) = _AdminUserDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$AdminUserDtoFromJson(json);

  AdminUser toDomain() => AdminUser(
    id: id,
    email: email,
    fullName: fullName,
    role: role,
    emailConfirmed: emailConfirmed,
    twoFactorEnabled: twoFactorEnabled,
    locked: locked,
    deactivated: deactivated,
    signInCount: signInCount,
    createdAt: createdAt,
    lastSignInAt: lastSignInAt,
  );
}
