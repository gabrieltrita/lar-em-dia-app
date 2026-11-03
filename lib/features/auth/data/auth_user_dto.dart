import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';

part 'auth_user_dto.freezed.dart';
part 'auth_user_dto.g.dart';

@freezed
abstract class AuthUserDto with _$AuthUserDto {
  const factory({
    required String id,
    required String email,
    required String firstName,
    @Default(false) bool twoFactorEnabled,
    String? lastName,
  }) = _AuthUserDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$AuthUserDtoFromJson(json);

  AuthUser toDomain() => AuthUser(
    id: id,
    email: email,
    firstName: firstName,
    lastName: lastName,
    twoFactorEnabled: twoFactorEnabled,
  );
}
