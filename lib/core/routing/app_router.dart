import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/di/injection.dart';
import 'package:lar_em_dia/core/routing/stream_listenable.dart';
import 'package:lar_em_dia/features/account/presentation/cubits/account_cubits.dart';
import 'package:lar_em_dia/features/account/presentation/pages/notification_settings_page.dart';
import 'package:lar_em_dia/features/account/presentation/pages/unsubscribe_page.dart';
import 'package:lar_em_dia/features/admin/domain/admin_category.dart';
import 'package:lar_em_dia/features/admin/presentation/cubits/admin_cubits.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_categories_page.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_category_form_page.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_metrics_page.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_user_detail_page.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_users_page.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/check_email_page.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/confirm_email_page.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/login_page.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/register_page.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/reset_password_page.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/splash_page.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/two_factor_page.dart';
import 'package:lar_em_dia/features/balance/domain/balance.dart';
import 'package:lar_em_dia/features/balance/presentation/cubits/balance_cubits.dart';
import 'package:lar_em_dia/features/balance/presentation/pages/balance_form_page.dart';
import 'package:lar_em_dia/features/balance/presentation/pages/balances_page.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/cubits/entry_cubits.dart';
import 'package:lar_em_dia/features/entries/presentation/pages/due_page.dart';
import 'package:lar_em_dia/features/entries/presentation/pages/entries_page.dart';
import 'package:lar_em_dia/features/entries/presentation/pages/entry_form_page.dart';
import 'package:lar_em_dia/features/home/presentation/cubits/home_cubit.dart';
import 'package:lar_em_dia/features/home/presentation/home_page.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/cubits/projection_cubit.dart';
import 'package:lar_em_dia/features/projection/presentation/cubits/simulation_cubit.dart';
import 'package:lar_em_dia/features/projection/presentation/pages/projection_details_page.dart';
import 'package:lar_em_dia/features/projection/presentation/pages/projection_page.dart';
import 'package:lar_em_dia/features/projection/presentation/pages/simulation_page.dart';
import 'package:lar_em_dia/features/security/presentation/cubits/security_cubits.dart';
import 'package:lar_em_dia/features/security/presentation/pages/security_page.dart';
import 'package:lar_em_dia/features/security/presentation/pages/two_factor_enrollment_page.dart';
import 'package:lar_em_dia/features/shell/presentation/app_shell.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:lar_em_dia/features/shell/presentation/more_page.dart';

abstract final class AppRoutes {
  static const home = '/';
  static const splash = '/splash';
  static const login = '/login';
  static const twoFactor = '/two-factor';
  static const register = '/register';
  static const checkEmail = '/check-email';
  static const confirmEmail = '/confirm-email';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const balances = '/balances';
  static const balanceForm = '/balances/form';
  static const entries = '/entries';
  static const entry = '/entry';
  static const due = '/due';
  static const more = '/more';
  static const projection = '/projection';
  static const simulation = '$projection/simulate';
  static const projectionDetails = '$projection/details';
  static const admin = '/admin';
  static const adminUsers = '$admin/users';
  static const adminMetrics = '$admin/metrics';
  static const adminCategories = '$admin/categories';
  static const adminCategoryForm = '$adminCategories/form';
  static const account = '/account';
  static const twoFactorEnrollment = '$account/two-factor';
  static const notificationSettings = '$account/notifications';
  static const unsubscribe = '/unsubscribe';

  static String adminUser(String id) => '$adminUsers/$id';

  static String simulationEntry(EntryKind kind) => '$simulation/${kind.name}';

  static String entryForm(EntryKind kind) => '$entry/${kind.name}';

  static const Set<String> public = {
    login,
    twoFactor,
    register,
    checkEmail,
    confirmEmail,
    forgotPassword,
    resetPassword,
  };
}

String? sessionRedirect(SessionState session, String location) {
  if (location == AppRoutes.unsubscribe) {
    return null;
  }
  final isPublic = AppRoutes.public.contains(location);
  final isSplash = location == AppRoutes.splash;
  return switch (session) {
    SessionUnknown() => isPublic || isSplash ? null : AppRoutes.splash,
    SessionAuthenticated(:final user) =>
      isPublic || isSplash || (_isAdminArea(location) && !user.isAdmin)
          ? AppRoutes.home
          : null,
    SessionUnauthenticated() => isPublic ? null : AppRoutes.login,
  };
}

bool _isAdminArea(String location) =>
    location == AppRoutes.admin || location.startsWith('${AppRoutes.admin}/');

C _started<C>(C cubit, Future<void> Function(C cubit) start) {
  unawaited(start(cubit));
  return cubit;
}

GoRoute _entryFormRoute(EntryKind kind) => GoRoute(
  path: AppRoutes.entryForm(kind),
  builder: (context, state) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => getIt<EntryFormCubit>()),
      BlocProvider(
        create: (_) =>
            _started(getIt<CategoriesCubit>(), (cubit) => cubit.load(kind)),
      ),
    ],
    child: switch (state.extra) {
      EntryEdit(:final entry, :final scope) => EntryFormPage(
        kind: kind,
        existing: entry,
        scope: scope,
      ),
      _ => EntryFormPage(kind: kind),
    },
  ),
);

Widget _reloading<C extends StateStreamableSource<Object?>>({
  required C Function() create,
  required Future<void> Function(C cubit) reload,
  required Widget child,
  Future<void> Function(C cubit)? start,
}) => BlocProvider<C>(
  create: (_) => _started(create(), start ?? reload),
  child: ReloadOnChange(
    changes: getIt<FinanceChanges>(),
    onChange: (context) => unawaited(reload(context.read<C>())),
    child: child,
  ),
);

StatefulShellBranch _branch(
  String path,
  Widget Function(GoRouterState state) page,
) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (context, state) => page(state))],
);

GoRouter buildRouter(SessionCubit sessionCubit) => GoRouter(
  initialLocation: AppRoutes.home,
  refreshListenable: StreamListenable(sessionCubit.stream),
  redirect: (context, state) =>
      sessionRedirect(sessionCubit.state, state.matchedLocation),
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          AppShell(shell: shell, changes: getIt<FinanceChanges>()),
      branches: [
        _branch(
          AppRoutes.home,
          (_) => _reloading(
            create: getIt.get<HomeCubit>,
            start: (cubit) => cubit.load(),
            reload: (cubit) => cubit.load(quiet: true),
            child: const HomePage(),
          ),
        ),
        _branch(
          AppRoutes.entries,
          (state) => _reloading(
            create: getIt.get<MonthEntriesCubit>,
            start: (cubit) => cubit.load(
              month: Dates.parseMonth(state.uri.queryParameters['month']),
            ),
            reload: (cubit) => cubit.load(quiet: true),
            child: const EntriesPage(),
          ),
        ),
        _branch(
          AppRoutes.due,
          (_) => _reloading(
            create: getIt.get<DueCubit>,
            start: (cubit) => cubit.load(),
            reload: (cubit) => cubit.load(quiet: true),
            child: const DuePage(),
          ),
        ),
        _branch(
          AppRoutes.projection,
          (_) => _reloading(
            create: getIt.get<ProjectionCubit>,
            start: (cubit) => cubit.load(),
            reload: (cubit) => cubit.load(quiet: true),
            child: const ProjectionPage(),
          ),
        ),
        _branch(AppRoutes.more, (_) => const MorePage()),
      ],
    ),
    GoRoute(
      path: AppRoutes.balances,
      builder: (context, state) => BlocProvider(
        create: (_) =>
            _started(getIt<BalancesCubit>(), (cubit) => cubit.load()),
        child: const BalancesPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.balanceForm,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<BalanceFormCubit>(),
        child: BalanceFormPage(existing: state.extra as Balance?),
      ),
    ),
    for (final kind in EntryKind.values) _entryFormRoute(kind),
    GoRoute(
      path: AppRoutes.projectionDetails,
      redirect: (context, state) =>
          state.extra is Projection ? null : AppRoutes.projection,
      builder: (context, state) =>
          ProjectionDetailsPage(projection: state.extra! as Projection),
    ),
    GoRoute(
      path: AppRoutes.simulation,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<SimulationCubit>(),
        child: const SimulationPage(),
      ),
    ),
    for (final kind in EntryKind.values)
      GoRoute(
        path: AppRoutes.simulationEntry(kind),
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => getIt<EntryFormCubit>()),
            BlocProvider(
              create: (_) => _started(
                getIt<CategoriesCubit>(),
                (cubit) => cubit.load(kind),
              ),
            ),
          ],
          child: EntryFormPage(kind: kind, simulation: true),
        ),
      ),
    GoRoute(
      path: AppRoutes.adminMetrics,
      builder: (context, state) => BlocProvider(
        create: (_) =>
            _started(getIt<AdminMetricsCubit>(), (cubit) => cubit.load()),
        child: const AdminMetricsPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminCategories,
      builder: (context, state) => BlocProvider(
        create: (_) =>
            _started(getIt<AdminCategoriesCubit>(), (cubit) => cubit.load()),
        child: const AdminCategoriesPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminCategoryForm,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<AdminCategoryFormCubit>(),
        child: AdminCategoryFormPage(existing: state.extra as AdminCategory?),
      ),
    ),
    GoRoute(
      path: AppRoutes.account,
      builder: (context, state) => BlocProvider(
        create: (_) =>
            _started(getIt<SecurityCubit>(), (cubit) => cubit.load()),
        child: const SecurityPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.notificationSettings,
      builder: (context, state) => BlocProvider(
        create: (_) => _started(
          getIt<NotificationSettingsCubit>(),
          (cubit) => cubit.load(),
        ),
        child: const NotificationSettingsPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.unsubscribe,
      builder: (context, state) => BlocProvider(
        create: (_) => _started(
          getIt<UnsubscribeCubit>(),
          (cubit) => cubit.unsubscribe(state.uri.queryParameters['token']),
        ),
        child: const UnsubscribePage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.twoFactorEnrollment,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<TwoFactorEnrollmentCubit>(),
        child: const TwoFactorEnrollmentPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.adminUsers,
      builder: (context, state) => BlocProvider(
        create: (_) =>
            _started(getIt<AdminUsersCubit>(), (cubit) => cubit.load()),
        child: const AdminUsersPage(),
      ),
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) => BlocProvider(
            create: (_) => _started(
              getIt<AdminUserCubit>(param1: state.pathParameters['id']),
              (cubit) => cubit.load(),
            ),
            child: const AdminUserDetailPage(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<LoginCubit>(),
        child: const LoginPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.twoFactor,
      redirect: (context, state) =>
          state.extra is String ? null : AppRoutes.login,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<TwoFactorCubit>(),
        child: TwoFactorPage(challengeToken: state.extra! as String),
      ),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<RegisterCubit>(),
        child: const RegisterPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.checkEmail,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<ResendConfirmationCubit>(),
        child: CheckEmailPage(email: state.extra as String?),
      ),
    ),
    GoRoute(
      path: AppRoutes.confirmEmail,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<ConfirmEmailCubit>(),
        child: ConfirmEmailPage(token: state.uri.queryParameters['token']),
      ),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<ForgotPasswordCubit>(),
        child: const ForgotPasswordPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.resetPassword,
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<ResetPasswordCubit>(),
        child: ResetPasswordPage(token: state.uri.queryParameters['token']),
      ),
    ),
  ],
);
