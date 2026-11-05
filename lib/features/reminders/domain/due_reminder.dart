import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/features/account/domain/notification_settings.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';

part 'due_reminder.freezed.dart';

@freezed
abstract class DueReminder with _$DueReminder {
  const factory({
    required Entry entry,
    required DateTime at,
    required int daysBefore,
  }) = _DueReminder;
}

abstract final class DueReminders {
  static const horizonDays = 30;
  static const hour = 9;
  static const maxScheduled = 60;

  static DateTime lastDueDay(DateTime now) =>
      Dates.dateOnly(now).add(const Duration(days: horizonDays));

  static List<DueReminder> plan({
    required List<Entry> entries,
    required NotificationSettings settings,
    required DateTime now,
  }) {
    if (!settings.enabled) {
      return const [];
    }
    final today = Dates.dateOnly(now);
    final last = lastDueDay(now);
    final reminders = [
      for (final entry in entries)
        if (_isUpcomingBill(entry, today, last))
          if (_alertAt(entry.dueOn, settings.daysBefore) case final at
              when at.isAfter(now))
            DueReminder(entry: entry, at: at, daysBefore: settings.daysBefore),
    ]..sort((a, b) => a.at.compareTo(b.at));
    return reminders.take(maxScheduled).toList();
  }

  static bool _isUpcomingBill(Entry entry, DateTime today, DateTime last) =>
      entry.kind == EntryKind.expense &&
      entry.status == EntryStatus.pending &&
      !entry.dueOn.isBefore(today) &&
      !entry.dueOn.isAfter(last);

  static DateTime _alertAt(DateTime dueOn, int daysBefore) =>
      DateTime(dueOn.year, dueOn.month, dueOn.day - daysBefore, hour);
}
