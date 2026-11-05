import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/features/security/domain/two_factor.dart';

part 'two_factor_dtos.freezed.dart';
part 'two_factor_dtos.g.dart';

@freezed
abstract class TwoFactorStatusDto with _$TwoFactorStatusDto {
  const factory({
    @Default(false) bool enabled,
    @JsonKey(name: 'required') @Default(false) bool mandatory,
    @Default(0) int backupCodesRemaining,
  }) = _TwoFactorStatusDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$TwoFactorStatusDtoFromJson(json);

  TwoFactorStatus toDomain() => TwoFactorStatus(
    enabled: enabled,
    mandatory: mandatory,
    backupCodesRemaining: backupCodesRemaining,
  );
}

@freezed
abstract class TwoFactorSetupDto with _$TwoFactorSetupDto {
  const factory({required String secret, required String provisioningUri}) =
      _TwoFactorSetupDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$TwoFactorSetupDtoFromJson(json);

  TwoFactorSetup toDomain() =>
      TwoFactorSetup(secret: secret, provisioningUri: provisioningUri);
}

@freezed
abstract class BackupCodesDto with _$BackupCodesDto {
  const factory({required List<String> backupCodes}) = _BackupCodesDto;

  factory fromJson(Map<String, dynamic> json) => _$BackupCodesDtoFromJson(json);
}
