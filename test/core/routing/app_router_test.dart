import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/di/injection.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/session/session_events.dart';
import 'package:lar_em_dia/features/account/domain/account_repository.dart';
import 'package:lar_em_dia/features/account/presentation/pages/notification_settings_page.dart';
import 'package:lar_em_dia/features/account/presentation/pages/unsubscribe_page.dart';
import 'package:lar_em_dia/features/admin/domain/admin_repository.dart';
import 'package:lar_em_dia/features/admin/domain/admin_user.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_categories_page.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_category_form_page.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_metrics_page.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_user_detail_page.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_users_page.dart';
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
import 'package:lar_em_dia/features/entries/presentation/pages/entries_page.dart';
import 'package:lar_em_dia/features/entries/presentation/pages/entry_form_page.dart';
import 'package:lar_em_dia/features/home/presentation/home_page.dart';
import 'package:lar_em_dia/features/projection/domain/projection_repository.dart';
import 'package:lar_em_dia/features/projection/presentation/pages/projection_page.dart';
import 'package:lar_em_dia/features/projection/presentation/pages/simulation_page.dart';
import 'package:lar_em_dia/features/security/domain/security_repository.dart';
import 'package:lar_em_dia/features/security/presentation/pages/security_page.dart';
import 'package:lar_em_dia/features/security/presentation/pages/two_factor_enrollment_page.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/account_fixtures.dart';
import '../../helpers/admin_fixtures.dart';
import '../../helpers/auth_fixtures.dart';
import '../../helpers/finance_fixtures.dart';
import '../../helpers/security_fixtures.dart';

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

    test('keeps the administration to admins', () {
      const admin = SessionState.authenticated(rafaelAdmin);
      final detail = AppRoutes.adminUser('user-2');

      expect(sessionRedirect(signedIn, AppRoutes.adminUsers), AppRoutes.home);
      expect(sessionRedirect(signedIn, detail), AppRoutes.home);
      expect(sessionRedirect(signedIn, AppRoutes.admin), AppRoutes.home);
      expect(sessionRedirect(signedIn, '/administrative'), isNull);
      expect(sessionRedirect(admin, AppRoutes.adminUsers), isNull);
      expect(sessionRedirect(admin, detail), isNull);
    });

    test('opens the unsubscribe link in every session state', () {
      for (final state in [unknown, signedIn, signedOut]) {
        expect(sessionRedirect(state, AppRoutes.unsubscribe), isNull);
      }
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
    late MockProjectionRepository projections;
    late MockAdminRepository admin;
    late MockSecurityRepository security;
    late MockAccountRepository account;

    setUpAll(() {
      registerFinanceFallbacks();
      configureDependencies();
      getIt.allowReassignment = true;
    });

    setUp(() {
      repository = MockAuthRepository();
      balances = MockBalanceRepository();
      entries = MockEntryRepository();
      projections = MockProjectionRepository();
      admin = MockAdminRepository();
      when(
        () => admin.users(
          page: 1,
          email: any(named: 'email'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) async => AdminUserPage(users: [carla]));
      when(() => admin.user(carla.id)).thenAnswer((_) async => carla);
      when(admin.metrics).thenAnswer((_) async => metrics);
      when(admin.categories).thenAnswer((_) async => [adminPets]);
      security = MockSecurityRepository();
      account = MockAccountRepository();
      when(account.notificationSettings).thenAnswer((_) async => alertsOn);
      when(() => account.unsubscribe('abc')).thenAnswer((_) async => alertsOff);
      when(security.twoFactorStatus).thenAnswer((_) async => twoFactorOff);
      when(
        () => projections.fetch(
          from: any(named: 'from'),
          months: any(named: 'months'),
        ),
      ).thenAnswer((_) async => projection);
      when(balances.latest).thenAnswer((_) async => null);
      when(balances.list).thenAnswer((_) async => []);
      when(() => entries.between(any(), any(), kind: any(named: 'kind')))
          .thenAnswer((_) async => []);
      when(() => entries.month(any(), kind: any(named: 'kind')))
          .thenAnswer((_) async => []);
      when(() => entries.categories(EntryKind.income))
          .thenAnswer((_) async => [salaryCategory]);
      when(() => entries.categories(EntryKind.expense))
          .thenAnswer((_) async => [housingCategory]);
      getIt
        ..registerSingleton<AuthRepository>(repository)
        ..registerSingleton<BalanceRepository>(balances)
        ..registerSingleton<EntryRepository>(entries)
        ..registerSingleton<ProjectionRepository>(projections)
        ..registerSingleton<AdminRepository>(admin)
        ..registerSingleton<SecurityRepository>(security)
        ..registerSingleton<AccountRepository>(account);
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
        '${AppRoutes.income}?month=2026-02': EntriesPage,
        AppRoutes.incomeForm: EntryFormPage,
        '${AppRoutes.expenses}?month=2026-03': EntriesPage,
        AppRoutes.expensesForm: EntryFormPage,
        AppRoutes.projection: ProjectionPage,
        AppRoutes.simulation: SimulationPage,
        AppRoutes.simulationEntry(EntryKind.income): EntryFormPage,
        AppRoutes.simulationEntry(EntryKind.expense): EntryFormPage,
      };
      for (final MapEntry(key: location, value: page) in pages.entries) {
        router.go(location);
        await tester.pumpAndSettle();
        expect(find.byType(page), findsOneWidget, reason: location);
      }
      verify(() => entries.month(DateTime(2026, 2), kind: EntryKind.income))
          .called(1);
      verify(() => entries.month(DateTime(2026, 3), kind: EntryKind.expense))
          .called(1);

      router.go(AppRoutes.balanceForm, extra: balance);
      await tester.pumpAndSettle();
      expect(find.text('Editar saldo'), findsOneWidget);

      router.go(AppRoutes.incomeForm, extra: EntryEdit(entry: salary));
      await tester.pumpAndSettle();
      expect(find.text('Editar receita'), findsOneWidget);

      router.go(
        AppRoutes.expensesForm,
        extra: EntryEdit(entry: housing, scope: EntryScope.all),
      );
      await tester.pumpAndSettle();
      expect(find.text('Editar despesa'), findsOneWidget);
      expect(find.textContaining('todos os lançamentos'), findsOneWidget);
    });

    testWidgets('opens the administration only for admins', (tester) async {
      await pumpRouter(tester);
      session.signedIn(ana);
      await tester.pumpAndSettle();

      router.go(AppRoutes.adminUsers);
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);

      session.signedIn(rafaelAdmin);
      await tester.pumpAndSettle();
      router.go(AppRoutes.adminUsers);
      await tester.pumpAndSettle();
      expect(find.byType(AdminUsersPage), findsOneWidget);
      expect(find.text('Carla Lima'), findsOneWidget);

      router.go(AppRoutes.adminUser(carla.id));
      await tester.pumpAndSettle();
      expect(find.byType(AdminUserDetailPage), findsOneWidget);

      router.go(AppRoutes.adminMetrics);
      await tester.pumpAndSettle();
      expect(find.byType(AdminMetricsPage), findsOneWidget);
      expect(find.text('Métricas de uso'), findsWidgets);

      router.go(AppRoutes.adminCategories);
      await tester.pumpAndSettle();
      expect(find.byType(AdminCategoriesPage), findsOneWidget);
      expect(find.text('Pets'), findsOneWidget);

      unawaited(router.push(AppRoutes.adminCategoryForm, extra: adminPets));
      await tester.pumpAndSettle();
      expect(find.byType(AdminCategoryFormPage), findsOneWidget);
      expect(find.text('Editar categoria'), findsOneWidget);
    });

    testWidgets('opens the security pages when signed in', (tester) async {
      await pumpRouter(tester);
      session.signedIn(ana);
      await tester.pumpAndSettle();

      router.go(AppRoutes.account);
      await tester.pumpAndSettle();
      expect(find.byType(SecurityPage), findsOneWidget);

      router.go(AppRoutes.twoFactorEnrollment);
      await tester.pumpAndSettle();
      expect(find.byType(TwoFactorEnrollmentPage), findsOneWidget);

      router.go(AppRoutes.notificationSettings);
      await tester.pumpAndSettle();
      expect(find.byType(NotificationSettingsPage), findsOneWidget);
    });

    testWidgets('opens the unsubscribe link signed out', (tester) async {
      await pumpRouter(tester);
      session.signedIn(ana);
      await tester.pumpAndSettle();
      when(repository.logout).thenAnswer((_) async {});
      await session.logout();
      await tester.pumpAndSettle();

      router.go('${AppRoutes.unsubscribe}?token=abc');
      await tester.pumpAndSettle();

      expect(find.byType(UnsubscribePage), findsOneWidget);
      verify(() => account.unsubscribe('abc')).called(1);
    });
  });
}
