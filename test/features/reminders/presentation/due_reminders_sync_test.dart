import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/account/domain/notification_settings.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/reminders/domain/reminder_scheduler.dart';
import 'package:lar_em_dia/features/reminders/presentation/due_reminders_sync.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/account_fixtures.dart';
import '../../../helpers/auth_fixtures.dart';
import '../../../helpers/finance_fixtures.dart';

class MockReminderScheduler extends Mock implements ReminderScheduler;

void main() {
  late AuthHarness harness;
  late MockAccountRepository account;
  late MockEntryRepository entries;
  late MockReminderScheduler scheduler;
  late DueRemindersSync sync;

  final now = DateTime(2026, 11, 20, 10);

  setUpAll(() {
    registerFallbackValue(EntryKind.expense);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    harness = AuthHarness();
    account = MockAccountRepository();
    entries = MockEntryRepository();
    scheduler = MockReminderScheduler();
    when(account.notificationSettings).thenAnswer((_) async => alertsOn);
    when(() => entries.month(any(), kind: any(named: 'kind')))
        .thenAnswer((_) async => []);
    when(() => scheduler.replace(any())).thenAnswer((_) async {});
    when(scheduler.cancelAll).thenAnswer((_) async {});
    sync = DueRemindersSync(harness.session, account, entries, scheduler);
  });

  tearDown(() async {
    await sync.dispose();
    await harness.dispose();
  });

  test('runs only on Android and iOS', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final (platform, supported) in [
      (TargetPlatform.android, true),
      (TargetPlatform.iOS, true),
      (TargetPlatform.macOS, false),
      (TargetPlatform.linux, false),
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(DueRemindersSync.supported, supported, reason: '$platform');
    }
  });

  test('schedules the expenses of this and the next month', () async {
    final rentDue = housing.copyWith(dueOn: DateTime(2026, 12, 10));
    final market = housing.copyWith(
      id: 'market',
      description: 'Feira',
      amountCents: 12345,
      dueOn: DateTime(2026, 11, 21),
    );
    when(() => entries.month(DateTime(2026, 11), kind: EntryKind.expense))
        .thenAnswer((_) async => [market]);
    when(() => entries.month(DateTime(2026, 12), kind: EntryKind.expense))
        .thenAnswer((_) async => [rentDue]);
    when(account.notificationSettings).thenAnswer(
      (_) async => const NotificationSettings(enabled: true, daysBefore: 3),
    );

    await sync.sync(now);

    verify(
      () => scheduler.replace([
        ScheduledReminder(
          id: 0,
          title: 'Conta a pagar: Aluguel de casa',
          body: r'R$ 2.000,00 vence em 3 dias, no dia 10/12/2026',
          at: DateTime(2026, 12, 7, 9),
        ),
      ]),
    ).called(1);
  });

  test('describes bills due today and tomorrow', () async {
    when(() => entries.month(DateTime(2026, 11), kind: EntryKind.expense))
        .thenAnswer(
          (_) async => [housing.copyWith(dueOn: DateTime(2026, 11, 22))],
        );

    await sync.sync(now);
    when(account.notificationSettings).thenAnswer(
      (_) async => const NotificationSettings(enabled: true, daysBefore: 0),
    );
    await sync.sync(now);

    final bodies = verify(() => scheduler.replace(captureAny())).captured
        .map((reminders) => (reminders as List<ScheduledReminder>).single.body);
    expect(bodies, [r'R$ 2.000,00 vence amanhã', r'R$ 2.000,00 vence hoje']);
  });

  test('clears the reminders when the alerts are off', () async {
    when(account.notificationSettings).thenAnswer((_) async => alertsOff);

    await sync.sync(now);

    verify(() => scheduler.replace([])).called(1);
    verifyNever(() => entries.month(any(), kind: any(named: 'kind')));
  });

  test('syncs once per signed in user and clears on sign out', () async {
    sync.start();
    await pumpEventQueue();
    verifyNever(account.notificationSettings);
    verifyNever(scheduler.cancelAll);

    harness.session.signedIn(ana);
    await pumpEventQueue();
    harness.session.signedIn(ana.copyWith(firstName: 'Aninha'));
    await pumpEventQueue();
    verify(
      () => entries.month(
        Dates.firstOfMonth(DateTime.now()),
        kind: EntryKind.expense,
      ),
    ).called(1);
    verify(() => scheduler.replace(any())).called(1);

    when(harness.repository.logout).thenAnswer((_) async {});
    await harness.session.logout();
    await pumpEventQueue();
    verify(scheduler.cancelAll).called(1);
  });

  test('syncs a session that is already signed in when it starts', () async {
    harness.session.signedIn(ana);
    sync
      ..start()
      ..start();
    await pumpEventQueue();

    verify(account.notificationSettings).called(1);
  });

  test('ignores API failures', () async {
    when(account.notificationSettings)
        .thenThrow(const ApiError(code: ApiError.networkErrorCode));

    await sync.sync(now);

    verifyNever(() => scheduler.replace(any()));
  });
}
