import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/account/data/api_account_repository.dart';
import 'package:lar_em_dia/features/account/data/platform_device_time_zone.dart';

import '../../../helpers/account_fixtures.dart';
import '../../../helpers/fake_adapter.dart';

void main() {
  late FakeAdapter adapter;

  ApiAccountRepository build(Object? data) {
    adapter = FakeAdapter((_) => FakeAdapter.json(200, {'data': data}));
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return ApiAccountRepository(ApiClient(dio));
  }

  const settingsJson = {'due_alerts_enabled': true, 'due_alert_days_before': 1};

  test('reads and updates the time zone through /me', () async {
    final repository = build({'time_zone': 'Europe/Lisbon'});

    expect(await repository.timeZone(), 'Europe/Lisbon');
    await repository.updateTimeZone('America/Manaus');

    final [read, update] = adapter.requests;
    expect(read.path, '/me');
    expect(update.method, 'PATCH');
    expect(update.data, {'time_zone': 'America/Manaus'});
  });

  test('reads, updates and unsubscribes the notification settings', () async {
    final repository = build(settingsJson);

    expect(await repository.notificationSettings(), alertsOn);
    expect(
      await repository.updateNotificationSettings(
        alertsOn.copyWith(daysBefore: 3),
      ),
      alertsOn,
    );
    expect(await repository.unsubscribe('abc'), alertsOn);

    final [read, update, unsubscribe] = adapter.requests;
    expect(read.path, '/me/notification_settings');
    expect(update.method, 'PATCH');
    expect(update.data, {
      'due_alerts_enabled': true,
      'due_alert_days_before': 3,
    });
    expect(unsubscribe.path, '/me/notification_settings/unsubscribe');
    expect(unsubscribe.data, {'token': 'abc'});
  });

  testWidgets('reads the device time zone from the platform', (tester) async {
    const channel = MethodChannel('flutter_timezone');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => 'America/Recife',
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    expect(await PlatformDeviceTimeZone().current(), 'America/Recife');
  });
}
