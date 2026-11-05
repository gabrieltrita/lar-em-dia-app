import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/features/account/domain/notification_settings.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/reminders/domain/due_reminder.dart';

import '../../../helpers/account_fixtures.dart';
import '../../../helpers/finance_fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 5, 10);

  Entry bill(String id, DateTime dueOn) =>
      housing.copyWith(id: id, dueOn: dueOn);

  test('reminds of pending bills at 9h on the alert day', () {
    final later = bill('later', DateTime(2026, 11, 20));
    final reminders = DueReminders.plan(
      entries: [later, housing, salary, rent, groceries],
      settings: alertsOn,
      now: now,
    );

    expect(reminders, [
      DueReminder(entry: housing, at: DateTime(2026, 11, 9, 9), daysBefore: 1),
      DueReminder(entry: later, at: DateTime(2026, 11, 19, 9), daysBefore: 1),
    ]);
  });

  test('skips alerts already past and bills outside the 30 days', () {
    final reminders = DueReminders.plan(
      entries: [
        bill('tomorrow', DateTime(2026, 11, 6)),
        bill('overdue', DateTime(2026, 11, 4)),
        bill('last day', DateTime(2026, 12, 5)),
        bill('too far', DateTime(2026, 12, 6)),
      ],
      settings: const NotificationSettings(enabled: true, daysBefore: 0),
      now: now,
    );

    expect(reminders.map((reminder) => reminder.entry.id), [
      'tomorrow',
      'last day',
    ]);
  });

  test('keeps an alert for later today', () {
    final reminders = DueReminders.plan(
      entries: [bill('today', DateTime(2026, 11, 5))],
      settings: const NotificationSettings(enabled: true, daysBefore: 0),
      now: DateTime(2026, 11, 5, 8),
    );

    expect(reminders.single.at, DateTime(2026, 11, 5, 9));
  });

  test('limits how many reminders are scheduled', () {
    final reminders = DueReminders.plan(
      entries: [
        for (var i = 0; i < 70; i++) bill('bill-$i', DateTime(2026, 11, 20)),
      ],
      settings: alertsOn,
      now: now,
    );

    expect(reminders, hasLength(DueReminders.maxScheduled));
  });

  test('plans nothing when the alerts are off', () {
    expect(
      DueReminders.plan(entries: [housing], settings: alertsOff, now: now),
      isEmpty,
    );
  });
}
