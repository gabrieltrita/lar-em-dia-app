import 'package:freezed_annotation/freezed_annotation.dart';

part 'reminder_scheduler.freezed.dart';

@freezed
abstract class ScheduledReminder with _$ScheduledReminder {
  const factory({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) = _ScheduledReminder;
}

abstract interface class ReminderScheduler {
  Future<void> replace(List<ScheduledReminder> reminders);

  Future<void> cancelAll();
}
