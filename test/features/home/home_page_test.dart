import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/app.dart';
import 'package:lar_em_dia/core/di/injection.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/domain/auth_repository.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/balance/domain/balance_repository.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/domain/entry_repository.dart';
import 'package:lar_em_dia/features/home/presentation/cubits/home_cubit.dart';
import 'package:lar_em_dia/features/home/presentation/home_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/finance_fixtures.dart';
import '../../helpers/pump_page.dart';

void main() {
  setUpAll(registerFinanceFallbacks);

  group('HomePage', () {
    late AuthHarness harness;
    late MockBalanceRepository balances;
    late MockEntryRepository entries;
    late MockProjectionRepository projections;

    setUp(() {
      harness = AuthHarness()..session.signedIn(ana);
      balances = MockBalanceRepository();
      entries = MockEntryRepository();
      projections = MockProjectionRepository();
      when(balances.latest).thenAnswer((_) async => balance);
      when(
        () => projections.fetch(
          from: any(named: 'from'),
          months: any(named: 'months'),
        ),
      ).thenAnswer(
        (_) async => projection.copyWith(months: [decemberProjection]),
      );
      when(() => entries.month(any(), kind: EntryKind.income))
          .thenAnswer((_) async => [salary, rent]);
      when(() => entries.month(any(), kind: EntryKind.expense))
          .thenAnswer((_) async => [housing, groceries]);
    });
    tearDown(() => harness.dispose());

    Future<void> pump(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 3000);
      addTearDown(tester.view.resetPhysicalSize);
      return pumpPage(
        tester,
        BlocProvider(
          create: (_) => started(
            HomeCubit(balances, entries, projections),
            (cubit) => cubit.load(),
          ),
          child: const HomePage(),
        ),
        session: harness.session,
      );
    }

    testWidgets('shows the projected end of the month in red when negative', (
      tester,
    ) async {
      await pump(tester);

      expect(
        find.text('Saldo previsto no fim de dezembro de 2026'),
        findsOneWidget,
      );
      expect(
        find.text(r'Economia acumulada até dezembro de 2026: -R$ 2.300,00'),
        findsOneWidget,
      );
      final closing = tester.widget<Text>(find.text(r'-R$ 1.065,44'));
      final context = tester.element(find.text(r'-R$ 1.065,44'));
      expect(closing.style?.color, Theme.of(context).colorScheme.error);
    });

    testWidgets('shows a positive projection in the default color', (
      tester,
    ) async {
      when(
        () => projections.fetch(
          from: any(named: 'from'),
          months: any(named: 'months'),
        ),
      ).thenAnswer((_) async => projection);
      await pump(tester);

      final closing = tester.widget<Text>(find.text(r'R$ 4.934,56'));
      final context = tester.element(find.text(r'R$ 4.934,56'));
      expect(closing.style?.color, isNot(Theme.of(context).colorScheme.error));
    });

    testWidgets('hides the projection without a balance', (tester) async {
      when(balances.latest).thenAnswer((_) async => null);
      await pump(tester);

      expect(find.text('Ver projeção'), findsNothing);
    });

    testWidgets('shows the month expenses', (tester) async {
      await pump(tester);

      expect(find.textContaining('Despesas de '), findsOneWidget);
      expect(find.text(r'R$ 2.800,00'), findsOneWidget);
      expect(
        find.text(r'Pagas R$ 800,00 · A pagar R$ 2.000,00'),
        findsOneWidget,
      );
    });

    testWidgets('shows the balance and the month income', (tester) async {
      await pump(tester);

      expect(find.text('Olá, Ana!'), findsOneWidget);
      expect(find.text(r'R$ 1.234,56'), findsOneWidget);
      expect(find.text('em 03/11/2026'), findsOneWidget);
      expect(find.text(r'R$ 6.500,00'), findsOneWidget);
      expect(
        find.text(r'Recebidas R$ 5.000,00 · A receber R$ 1.500,00'),
        findsOneWidget,
      );
    });

    testWidgets('invites to inform the first balance', (tester) async {
      when(balances.latest).thenAnswer((_) async => null);
      await pump(tester);

      expect(find.textContaining('ainda não informou'), findsOneWidget);
      expect(find.text('Histórico'), findsNothing);
    });

    for (final (button, route) in [
      ('Informar saldo', AppRoutes.balanceForm),
      ('Histórico', AppRoutes.balances),
      ('Nova receita', AppRoutes.incomeForm),
      ('Ver receitas', AppRoutes.income),
      ('Nova despesa', AppRoutes.expensesForm),
      ('Ver despesas', AppRoutes.expenses),
      ('Ver projeção', AppRoutes.projection),
    ]) {
      testWidgets('$button opens $route and reloads on return', (tester) async {
        await pump(tester);

        await tester.ensureVisible(find.text(button));
        await tester.pumpAndSettle();
        await tester.tap(find.text(button));
        await tester.pumpAndSettle();
        expect(find.text(routeMarker(route)), findsOneWidget);
        await tester.tap(find.text(savedAndBack));
        await tester.pumpAndSettle();

        verify(balances.latest).called(2);
      });
    }

    testWidgets('retries after a failure', (tester) async {
      when(balances.latest).thenThrow(const ApiError(code: 'network_error'));
      await pump(tester);
      expect(find.text('Tentar de novo'), findsOneWidget);

      when(balances.latest).thenAnswer((_) async => balance);
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text(r'R$ 1.234,56'), findsOneWidget);
    });

    testWidgets('reloads on pull to refresh', (tester) async {
      await pump(tester);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      verify(balances.latest).called(2);
    });
  });

  group('App', () {
    late MockAuthRepository repository;

    setUpAll(() {
      configureDependencies();
      repository = MockAuthRepository();
      final balances = MockBalanceRepository();
      final entries = MockEntryRepository();
      when(balances.latest).thenAnswer((_) async => null);
      when(() => entries.month(any(), kind: any(named: 'kind')))
          .thenAnswer((_) async => []);
      getIt
        ..allowReassignment = true
        ..registerSingleton<AuthRepository>(repository)
        ..registerSingleton<BalanceRepository>(balances)
        ..registerSingleton<EntryRepository>(entries);
    });

    testWidgets('greets the signed in user and logs out', (tester) async {
      when(repository.logout).thenAnswer((_) async {});
      await tester.pumpWidget(const App());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      getIt<SessionCubit>().signedIn(ana);
      await tester.pumpAndSettle();
      expect(find.text('Olá, Ana!'), findsOneWidget);

      await tester.tap(find.byTooltip('Sair'));
      await tester.pumpAndSettle();

      verify(repository.logout).called(1);
      expect(find.text('Entrar'), findsWidgets);
    });
  });
}
