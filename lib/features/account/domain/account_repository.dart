import 'package:lar_em_dia/features/account/domain/notification_settings.dart';

abstract interface class AccountRepository {
  Future<String?> timeZone();

  Future<void> updateTimeZone(String timeZone);

  Future<NotificationSettings> notificationSettings();

  Future<NotificationSettings> updateNotificationSettings(
    NotificationSettings settings,
  );

  Future<NotificationSettings> unsubscribe(String token);
}
