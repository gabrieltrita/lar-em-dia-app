import 'package:freezed_annotation/freezed_annotation.dart';

part 'two_factor.freezed.dart';

typedef GoogleReauthentication = ({
  bool rendersOwnButton,
  Stream<String> idTokens,
  Future<void> Function() start,
});

@freezed
abstract class TwoFactorStatus with _$TwoFactorStatus {
  const factory({
    required bool enabled,
    required bool mandatory,
    required int backupCodesRemaining,
    @Default(true) bool passwordSet,
  }) = _TwoFactorStatus;
}

@freezed
abstract class TwoFactorSetup with _$TwoFactorSetup {
  const factory({required String secret, required String provisioningUri}) =
      _TwoFactorSetup;
}

@freezed
abstract class Reauthentication with _$Reauthentication {
  const factory({String? password, String? code, String? idToken}) =
      _Reauthentication;
}
