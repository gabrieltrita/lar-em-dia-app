import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/features/account/domain/device_time_zone.dart';

@LazySingleton(as: DeviceTimeZone)
class PlatformDeviceTimeZone implements DeviceTimeZone {
  @override
  Future<String> current() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;
}
