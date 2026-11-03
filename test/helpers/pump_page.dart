import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

String routeMarker(String path, [Object? extra]) => 'route:$path extra:$extra';

Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  required SessionCubit session,
  bool settle = true,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => page),
      for (final path in AppRoutes.public)
        GoRoute(
          path: path,
          builder: (_, state) => Text(routeMarker(path, state.extra)),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider.value(
      value: session,
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await (settle ? tester.pumpAndSettle() : tester.pump());
}
