import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/account/domain/account_repository.dart';
import 'package:lar_em_dia/features/account/domain/notification_settings.dart';

@LazySingleton(as: AccountRepository)
class ApiAccountRepository implements AccountRepository {
  new(this._client);

  static const mePath = '/me';
  static const settingsPath = '/me/notification_settings';

  final ApiClient _client;

  @override
  Future<String?> timeZone() async => (await _client.get(
    mePath,
    decode: (data) => (data! as Json)['time_zone'] as String?,
  )).data;

  @override
  Future<void> updateTimeZone(String timeZone) =>
      _client.patch(mePath, decode: (_) {}, body: {'time_zone': timeZone});

  @override
  Future<NotificationSettings> notificationSettings() async =>
      (await _client.get(settingsPath, decode: _decode)).data;

  @override
  Future<NotificationSettings> updateNotificationSettings(
    NotificationSettings settings,
  ) async => (await _client.patch(
    settingsPath,
    decode: _decode,
    body: {
      'due_alerts_enabled': settings.enabled,
      'due_alert_days_before': settings.daysBefore,
    },
  )).data;

  @override
  Future<NotificationSettings> unsubscribe(String token) async =>
      (await _client.post(
        '$settingsPath/unsubscribe',
        decode: _decode,
        body: {'token': token},
      )).data;

  static NotificationSettings _decode(Object? data) {
    final json = data! as Json;
    return NotificationSettings(
      enabled: json['due_alerts_enabled']! as bool,
      daysBefore: json['due_alert_days_before']! as int,
    );
  }
}
