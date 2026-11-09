import 'package:lar_em_dia/features/security/domain/two_factor.dart';

abstract interface class SecurityRepository {
  Future<TwoFactorStatus> twoFactorStatus();

  Future<TwoFactorSetup> setupTwoFactor(Reauthentication reauthentication);

  Future<List<String>> enableTwoFactor(String code);

  Future<void> disableTwoFactor(Reauthentication reauthentication);

  Future<List<String>> regenerateBackupCodes(Reauthentication reauthentication);

  Future<void> deleteAccount(Reauthentication reauthentication);
}
