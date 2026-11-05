import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/features/reminders/data/local_notifications_scheduler.dart';
import 'package:lar_em_dia/features/reminders/domain/reminder_scheduler.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../helpers/account_fixtures.dart';

class MockPlugin extends Mock implements FlutterLocalNotificationsPlugin;

class MockAndroidPlugin extends Mock
    implements AndroidFlutterLocalNotificationsPlugin;

class MockIosPlugin extends Mock implements IOSFlutterLocalNotificationsPlugin;

void main() {
  late MockPlugin plugin;
  late MockDeviceTimeZone device;
  late LocalNotificationsScheduler scheduler;

  final reminder = ScheduledReminder(
    id: 0,
    title: 'Conta a pagar: Aluguel de casa',
    body: r'R$ 2.000,00 vence amanhã',
    at: DateTime(2026, 11, 9, 9),
  );

  setUpAll(() {
    registerFallbackValue(const InitializationSettings());
    registerFallbackValue(const NotificationDetails());
    registerFallbackValue(AndroidScheduleMode.inexact);
    registerFallbackValue(tz.TZDateTime.utc(2026));
  });

  setUp(() {
    plugin = MockPlugin();
    device = MockDeviceTimeZone();
    when(device.current).thenAnswer((_) async => 'America/Sao_Paulo');
    when(() => plugin.initialize(settings: any(named: 'settings')))
        .thenAnswer((_) async => true);
    when(plugin.cancelAll).thenAnswer((_) async {});
    when(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(null);
    when(
      () => plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(null);
    scheduler = LocalNotificationsScheduler(plugin, device);
  });

  test('replaces the pending reminders in the device time zone', () async {
    await scheduler.replace([reminder]);
    await scheduler.replace([reminder]);

    verify(() => plugin.initialize(settings: any(named: 'settings'))).called(1);
    verify(plugin.cancelAll).called(2);
    final scheduled = verify(
      () => plugin.zonedSchedule(
        id: 0,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: captureAny(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      ),
    ).captured;
    final date = scheduled.first as tz.TZDateTime;
    expect(date.location.name, 'America/Sao_Paulo');
    expect((date.year, date.month, date.day, date.hour), (2026, 11, 9, 9));
  });

  test('asks Android for permission and stops when denied', () async {
    final android = MockAndroidPlugin();
    when(android.requestNotificationsPermission).thenAnswer((_) async => false);
    when(
      () => plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(android);

    await scheduler.replace([reminder]);

    verify(android.requestNotificationsPermission).called(1);
    verifyNever(
      () => plugin.zonedSchedule(
        id: any(named: 'id'),
        scheduledDate: any(named: 'scheduledDate'),
        notificationDetails: any(named: 'notificationDetails'),
        androidScheduleMode: any(named: 'androidScheduleMode'),
        title: any(named: 'title'),
        body: any(named: 'body'),
      ),
    );
  });

  test('asks iOS for permission before scheduling', () async {
    final ios = MockIosPlugin();
    when(() => ios.requestPermissions(alert: true, sound: true))
        .thenAnswer((_) async => true);
    when(
      () => plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >(),
    ).thenReturn(ios);

    await scheduler.replace([reminder]);

    verify(() => ios.requestPermissions(alert: true, sound: true)).called(1);
  });

  test('only clears the reminders when there is nothing to schedule', () async {
    await scheduler.replace([]);
    await scheduler.cancelAll();

    verify(plugin.cancelAll).called(2);
    verifyNever(
      () => plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >(),
    );
  });
}
