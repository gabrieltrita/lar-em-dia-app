import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/di/injection.dart';
import 'package:lar_em_dia/core/routing/stream_listenable.dart';
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
import 'package:lar_em_dia/features/home/presentation/home_page.dart';

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
  final isPublic = AppRoutes.public.contains(location);
  final isSplash = location == AppRoutes.splash;
  return switch (session) {
    SessionUnknown() => isPublic || isSplash ? null : AppRoutes.splash,
    SessionAuthenticated() => isPublic || isSplash ? AppRoutes.home : null,
    SessionUnauthenticated() => isPublic ? null : AppRoutes.login,
  };
}

GoRouter buildRouter(SessionCubit sessionCubit) => GoRouter(
  initialLocation: AppRoutes.home,
  refreshListenable: StreamListenable(sessionCubit.stream),
  redirect: (context, state) =>
      sessionRedirect(sessionCubit.state, state.matchedLocation),
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomePage(),
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
