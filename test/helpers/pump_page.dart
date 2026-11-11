import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

const savedAndBack = 'saved and back';
const closedAndBack = 'closed and back';

String routeMarker(String path, [Object? extra]) => 'route:$path extra:$extra';

Future<void> pumpPage(
  WidgetTester tester,
  Widget page, {
  required SessionCubit session,
  FinanceChanges? changes,
  bool settle = true,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => page),
      for (final path in [
        ...AppRoutes.public,
        AppRoutes.balances,
        AppRoutes.balanceForm,
        AppRoutes.entries,
        AppRoutes.entryForm(EntryKind.income),
        AppRoutes.entryForm(EntryKind.expense),
        AppRoutes.due,
        AppRoutes.more,
        AppRoutes.projection,
        AppRoutes.simulation,
        AppRoutes.projectionDetails,
        AppRoutes.adminUsers,
        AppRoutes.adminMetrics,
        AppRoutes.adminCategories,
        AppRoutes.adminCategoryForm,
        AppRoutes.account,
        AppRoutes.twoFactorEnrollment,
        AppRoutes.notificationSettings,
        AppRoutes.adminUser(':id'),
      ])
        GoRoute(
          path: path,
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                Text(routeMarker(state.uri.path, state.extra)),
                TextButton(
                  onPressed: () => context.pop(true),
                  child: const Text(savedAndBack),
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text(closedAndBack),
                ),
              ],
            ),
          ),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    RepositoryProvider.value(
      value: changes ?? FinanceChanges(FinanceCache()),
      child: BlocProvider.value(
        value: session,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    ),
  );
  await (settle ? tester.pumpAndSettle() : tester.pump());
}

C started<C>(C cubit, Future<void> Function(C cubit) start) {
  unawaited(start(cubit));
  return cubit;
}
