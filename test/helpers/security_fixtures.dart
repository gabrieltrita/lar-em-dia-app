import 'package:lar_em_dia/features/security/domain/security_repository.dart';
import 'package:lar_em_dia/features/security/domain/two_factor.dart';
import 'package:mocktail/mocktail.dart';

class MockSecurityRepository extends Mock implements SecurityRepository;

const twoFactorOff = TwoFactorStatus(
  enabled: false,
  mandatory: false,
  backupCodesRemaining: 0,
);

const twoFactorOn = TwoFactorStatus(
  enabled: true,
  mandatory: false,
  backupCodesRemaining: 10,
);

const twoFactorSetup = TwoFactorSetup(
  secret: 'JBSWY3DPEHPK3PXP',
  provisioningUri:
      'otpauth://totp/LarEmDia:ana@example.com?secret=JBSWY3DPEHPK3PXP',
);

const backupCodes = ['aaaa-1111', 'bbbb-2222'];

const passwordOnly = Reauthentication(password: 'Secret123');

const passwordAndCode = Reauthentication(password: 'Secret123', code: '123456');

void registerSecurityFallbacks() {
  registerFallbackValue(passwordOnly);
}
