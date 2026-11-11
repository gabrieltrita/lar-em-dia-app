import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:lar_em_dia/app.dart';
import 'package:lar_em_dia/core/config/env.dart';
import 'package:lar_em_dia/core/di/injection.dart';
import 'package:lar_em_dia/features/account/presentation/time_zone_sync.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/reminders/presentation/due_reminders_sync.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_cache_reset.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Env.demo) {
    usePathUrlStrategy();
  }
  configureDependencies();
  getIt<FinanceCacheReset>().start();
  getIt<TimeZoneSync>().start();
  if (DueRemindersSync.supported) {
    getIt<DueRemindersSync>().start();
  }
  unawaited(getIt<SessionCubit>().restore());
  runApp(const App());
}
