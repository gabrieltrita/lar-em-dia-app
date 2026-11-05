import 'package:lar_em_dia/features/account/domain/account_repository.dart';
import 'package:lar_em_dia/features/account/domain/device_time_zone.dart';
import 'package:lar_em_dia/features/account/domain/notification_settings.dart';
import 'package:mocktail/mocktail.dart';

class MockAccountRepository extends Mock implements AccountRepository;

class MockDeviceTimeZone extends Mock implements DeviceTimeZone;

const alertsOn = NotificationSettings(enabled: true, daysBefore: 1);

const alertsOff = NotificationSettings(enabled: false, daysBefore: 1);

void registerAccountFallbacks() {
  registerFallbackValue(alertsOn);
}
