import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/features/account/domain/device_time_zone.dart';
import 'package:lar_em_dia/features/reminders/domain/reminder_scheduler.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

@LazySingleton(as: ReminderScheduler)
class LocalNotificationsScheduler implements ReminderScheduler {
  new(this._plugin, this._timeZone);

  static const channelId = 'due_reminders';
  static const icon = '@mipmap/ic_launcher';

  final FlutterLocalNotificationsPlugin _plugin;
  final DeviceTimeZone _timeZone;
  bool _ready = false;

  @override
  Future<void> replace(List<ScheduledReminder> reminders) async {
    await _initialize();
    await _plugin.cancelAll();
    if (reminders.isEmpty || !await _requestPermission()) {
      return;
    }
    final l10n = lookupAppLocalizations(const Locale('pt'));
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        l10n.dueReminderChannel,
        channelDescription: l10n.dueReminderChannelDescription,
      ),
      iOS: const DarwinNotificationDetails(),
    );
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime(
          tz.local,
          reminder.at.year,
          reminder.at.month,
          reminder.at.day,
          reminder.at.hour,
          reminder.at.minute,
        ),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _initialize();
    await _plugin.cancelAll();
  }

  Future<void> _initialize() async {
    if (_ready) {
      return;
    }
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(await _timeZone.current()));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(icon),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  Future<bool> _requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted =
        await android?.requestNotificationsPermission() ??
        await ios?.requestPermissions(alert: true, sound: true);
    return granted ?? true;
  }
}
