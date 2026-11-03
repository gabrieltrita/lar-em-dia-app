import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/di/injection.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/session/session_events.dart';
import 'package:lar_em_dia/features/auth/domain/auth_repository.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/check_email_page.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/confirm_email_page.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/login_page.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/register_page.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/reset_password_page.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/splash_page.dart';
import 'package:lar_em_dia/features/auth/presentation/pages/two_factor_page.dart';
import 'package:lar_em_dia/features/balance/domain/balance_repository.dart';
import 'package:lar_em_dia/features/balance/presentation/pages/balance_form_page.dart';
import 'package:lar_em_dia/features/balance/presentation/pages/balances_page.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/domain/entry_repository.dart';
import 'package:lar_em_dia/features/entries/presentation/pages/entry_form_page.dart';
import 'package:lar_em_dia/features/entries/presentation/pages/income_page.dart';
import 'package:lar_em_dia/features/home/presentation/home_page.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/finance_fixtures.dart';

void main() {
  group('sessionRedirect', () {
    const unknown = SessionState.unknown();
    const signedIn = SessionState.authenticated(ana);
    const signedOut = SessionState.unauthenticated();

    test('waits on the splash while the session is unknown', () {
      expect(sessionRedirect(unknown, AppRoutes.home), AppRoutes.splash);
      expect(sessionRedirect(unknown, AppRoutes.splash), isNull);
      expect(sessionRedirect(unknown, AppRoutes.resetPassword), isNull);
    });

    test('sends a signed in user away from public pages', () {
      expect(sessionRedirect(signedIn, AppRoutes.login), AppRoutes.home);
      expect(sessionRedirect(signedIn, AppRoutes.splash), AppRoutes.home);
      expect(sessionRedirect(signedIn, AppRoutes.home), isNull);
    });

    test('sends a signed out user to the login', () {
      expect(sessionRedirect(signedOut, AppRoutes.home), AppRoutes.login);
      expect(sessionRedirect(signedOut, AppRoutes.splash), AppRoutes.login);
      expect(sessionRedirect(signedOut, AppRoutes.register), isNull);
    });
  });

  group('buildRouter', () {
    late MockAuthRepository repository;
    late SessionEvents events;
    late SessionCubit session;
    late GoRouter router;

    late MockBalanceRepository balances;
    late MockEntryRepository entries;

    setUpAll(() {
      registerFinanceFallbacks();
      configureDependencies();
      getIt.allowReassignment = true;
    });

    setUp(() {
      repository = MockAuthRepository();
      balances = MockBalanceRepository();
      entries = MockEntryRepository();
      when(balances.latest).thenAnswer((_) async => null);
      when(balances.list).thenAnswer((_) async => []);
      when(() => entries.month(any(), kind: EntryKind.income))
          .thenAnswer((_) async => []);
      when(() => entries.categories(EntryKind.income))
          .thenAnswer((_) async => [salaryCategory]);
      getIt
        ..registerSingleton<AuthRepository>(repository)
        ..registerSingleton<BalanceRepository>(balances)
        ..registerSingleton<EntryRepository>(entries);
      events = SessionEvents();
      session = SessionCubit(repository, events);
      router = buildRouter(session);
    });

    tearDown(() async {
      router.dispose();
      await session.close();
      await events.dispose();
    });

    Future<void> pumpRouter(WidgetTester tester) async {
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
      await tester.pump();
    }

    Future<void> signOut(WidgetTester tester) async {
      when(repository.restoreSession).thenAnswer((_) async => null);
      await session.restore();
      await tester.pumpAndSettle();
    }

    testWidgets('follows the session from the splash to home', (tester) async {
      await pumpRouter(tester);
      expect(find.byType(SplashPage), findsOneWidget);

      session.signedIn(ana);
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('shows the login once the session cannot be restored', (
      tester,
    ) async {
      await pumpRouter(tester);
      await signOut(tester);

      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('opens every public page', (tester) async {
      when(() => repository.confirmEmail('t1'))
          .thenThrow(const ApiError(code: 'invalid_confirmation_token'));
      await pumpRouter(tester);
      await signOut(tester);

      final pages = {
        AppRoutes.register: RegisterPage,
        AppRoutes.checkEmail: CheckEmailPage,
        '${AppRoutes.confirmEmail}?token=t1': ConfirmEmailPage,
        AppRoutes.forgotPassword: ForgotPasswordPage,
        '${AppRoutes.resetPassword}?token=t1': ResetPasswordPage,
      };
      for (final MapEntry(key: location, value: page) in pages.entries) {
        router.go(location);
        await tester.pumpAndSettle();
        expect(find.byType(page), findsOneWidget, reason: location);
      }
    });

    testWidgets('opens the 2FA page only with a challenge', (tester) async {
      await pumpRouter(tester);
      await signOut(tester);

      router.go(AppRoutes.twoFactor);
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      router.go(AppRoutes.twoFactor, extra: 'c1');
      await tester.pumpAndSettle();
      expect(find.byType(TwoFactorPage), findsOneWidget);
    });

    testWidgets('opens the balance and income pages when signed in', (
      tester,
    ) async {
      await pumpRouter(tester);
      session.signedIn(ana);
      await tester.pumpAndSettle();

      final pages = {
        AppRoutes.balances: BalancesPage,
        AppRoutes.balanceForm: BalanceFormPage,
        '${AppRoutes.income}?month=2026-02': IncomePage,
        AppRoutes.incomeForm: EntryFormPage,
      };
      for (final MapEntry(key: location, value: page) in pages.entries) {
        router.go(location);
        await tester.pumpAndSettle();
        expect(find.byType(page), findsOneWidget, reason: location);
      }
      verify(() => entries.month(DateTime(2026, 2), kind: EntryKind.income))
          .called(1);

      router.go(AppRoutes.balanceForm, extra: balance);
      await tester.pumpAndSettle();
      expect(find.text('Editar saldo'), findsOneWidget);

      router.go(AppRoutes.incomeForm, extra: salary);
      await tester.pumpAndSettle();
      expect(find.text('Editar receita'), findsOneWidget);
    });
  });
}
