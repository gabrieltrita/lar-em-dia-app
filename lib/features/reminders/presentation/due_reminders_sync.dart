import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/config/env.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/features/account/domain/account_repository.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/domain/entry_repository.dart';
import 'package:lar_em_dia/features/reminders/domain/due_reminder.dart';
import 'package:lar_em_dia/features/reminders/domain/reminder_scheduler.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

@lazySingleton
class DueRemindersSync {
  new(this._session, this._account, this._entries, this._scheduler);

  static bool get supported =>
      !Env.demo &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final SessionCubit _session;
  final AccountRepository _account;
  final EntryRepository _entries;
  final ReminderScheduler _scheduler;
  StreamSubscription<SessionState>? _subscription;
  String? _syncedUserId;

  void start() {
    _subscription ??= _session.stream.listen(
      (state) => unawaited(_onSession(state)),
    );
    unawaited(_onSession(_session.state));
  }

  Future<void> _onSession(SessionState state) async {
    switch (state) {
      case SessionAuthenticated(:final user) when user.id != _syncedUserId:
        _syncedUserId = user.id;
        await sync();
      case SessionUnauthenticated() when _syncedUserId != null:
        _syncedUserId = null;
        await _guard(_scheduler.cancelAll);
      case _:
        return;
    }
  }

  Future<void> sync([DateTime? now]) => _guard(() async {
    final moment = now ?? DateTime.now();
    final settings = await _account.notificationSettings();
    final entries = settings.enabled ? await _upcoming(moment) : <Entry>[];
    final reminders = DueReminders.plan(
      entries: entries,
      settings: settings,
      now: moment,
    );
    await _scheduler.replace(_scheduled(reminders));
  });

  Future<List<Entry>> _upcoming(DateTime now) async {
    final first = Dates.firstOfMonth(now);
    final last = Dates.firstOfMonth(DueReminders.lastDueDay(now));
    return [
      for (
        var month = first;
        !month.isAfter(last);
        month = Dates.addMonths(month, 1)
      )
        ...await _entries.month(month, kind: EntryKind.expense),
    ];
  }

  static List<ScheduledReminder> _scheduled(List<DueReminder> reminders) {
    final l10n = lookupAppLocalizations(const Locale('pt'));
    return [
      for (final (index, reminder) in reminders.indexed)
        ScheduledReminder(
          id: index,
          title: l10n.dueReminderTitle(reminder.entry.description),
          body: l10n.dueReminderBody(
            reminder.daysBefore,
            Money.format(reminder.entry.amountCents),
            Dates.display(reminder.entry.dueOn),
          ),
          at: reminder.at,
        ),
    ];
  }

  static Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Exception {
      return;
    }
  }

  @disposeMethod
  Future<void> dispose() async => await _subscription?.cancel();
}
