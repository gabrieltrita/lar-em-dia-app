import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:lar_em_dia/app.dart';
import 'package:lar_em_dia/core/config/env.dart';
import 'package:lar_em_dia/core/di/injection.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!Env.demo) {
    usePathUrlStrategy();
  }
  configureDependencies();
  unawaited(getIt<SessionCubit>().restore());
  runApp(const App());
}
