import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/app.dart';
import 'package:lar_em_dia/core/di/injection.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/features/auth/domain/auth_repository.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/balance/domain/balance_repository.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/domain/entry_repository.dart';
import 'package:lar_em_dia/features/home/presentation/cubits/home_cubit.dart';
import 'package:lar_em_dia/features/home/presentation/home_page.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve_dismissal.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve_repository.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/auth_fixtures.dart';
import '../../helpers/finance_fixtures.dart';
import '../../helpers/pump_page.dart';
import '../../helpers/reserve_fixtures.dart';

void main() {
  setUpAll(registerFinanceFallbacks);

  group('HomePage', () {
    late AuthHarness harness;
    late MockBalanceRepository balances;
    late MockEntryRepository entries;
    late MockProjectionRepository projections;
    late FinanceChanges changes;
    late int notified;

    setUp(() {
      harness = AuthHarness()..session.signedIn(ana);
      balances = MockBalanceRepository();
      entries = MockEntryRepository();
      projections = MockProjectionRepository();
      notified = 0;
      changes = FinanceChanges(FinanceCache())..addListener(() => notified++);
      when(balances.latest).thenAnswer((_) async => balance);
      when(
        () => projections.fetch(
          from: any(named: 'from'),
          period: any(named: 'period'),
        ),
      ).thenAnswer(
        (_) async => projection.copyWith(months: [decemberProjection]),
      );
      when(() => entries.between(any(), any(), kind: any(named: 'kind')))
          .thenAnswer((_) async => []);
      when(() => entries.categories(EntryKind.expense))
          .thenAnswer((_) async => [housingCategory, groceriesCategory]);
      when(() => entries.month(any()))
          .thenAnswer((_) async => [salary, rent, housing, groceries]);
    });
    tearDown(() => harness.dispose());

    Future<void> pump(
      WidgetTester tester, {
      ReserveSummary reserveCard = emptyReserve,
    }) {
      tester.view.physicalSize = const Size(1200, 4200);
      addTearDown(tester.view.resetPhysicalSize);
      return pumpPage(
        tester,
        withReserveCard(
          BlocProvider(
            create: (_) => started(
              HomeCubit(balances, entries, projections),
              (cubit) => cubit.load(today: DateTime(2026, 11, 6)),
            ),
            child: const HomePage(),
          ),
          summary: reserveCard,
        ),
        session: harness.session,
        changes: changes,
      );
    }

    testWidgets('shows the reserve card below the indicators', (tester) async {
      await pump(tester, reserveCard: reserveSummary);

      expect(find.byKey(const Key('reserve_card')), findsOneWidget);
      expect(find.text('4,5 de 6 meses'), findsOneWidget);
    });

    testWidgets('leads with the result of the month', (tester) async {
      await pump(tester);

      expect(find.text('Olá, Ana!'), findsOneWidget);
      expect(find.text('Balanço de novembro de 2026'), findsOneWidget);
      final result = tester.widget<Text>(find.text(r'+R$ 3.700,00'));
      final context = tester.element(find.byType(HomePage));
      expect(result.style?.color, FinanceColors.of(context).positive);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
      expect(find.text(r'R$ 6.500,00'), findsOneWidget);
      expect(find.text(r'R$ 2.800,00'), findsOneWidget);
      expect(find.text(r'Sobram R$ 3.700,00 até 30/11/2026'), findsOneWidget);
    });

    testWidgets('says what is missing when the month spends more', (
      tester,
    ) async {
      when(() => entries.month(any()))
          .thenAnswer((_) async => [rent, housing, groceries]);
      await pump(tester);

      expect(find.text(r'-R$ 1.300,00'), findsOneWidget);
      expect(find.byIcon(Icons.trending_down), findsOneWidget);
      expect(find.text(r'Faltam R$ 1.300,00 até 30/11/2026'), findsOneWidget);
    });

    testWidgets('switches months', (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Balanço de outubro de 2026'), findsOneWidget);
      verify(() => entries.month(DateTime(2026, 10))).called(1);

      await tester.tap(find.byTooltip('Próximo mês'));
      await tester.pumpAndSettle();
      expect(find.text('Balanço de novembro de 2026'), findsOneWidget);
    });

    testWidgets('shows the balance and the projected end of the month', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Saldo informado'), findsOneWidget);
      expect(find.text(r'R$ 1.234,56'), findsOneWidget);
      expect(find.text('em 03/11/2026'), findsOneWidget);
      expect(find.text('Fim do mês'), findsOneWidget);
      expect(find.text(r'-R$ 1.065,44'), findsOneWidget);

      await tester.tap(find.text(r'R$ 1.234,56'));
      await tester.pumpAndSettle();
      expect(find.text(routeMarker(AppRoutes.balances)), findsOneWidget);
      await tester.tap(find.text(savedAndBack));
      await tester.pumpAndSettle();
      expect(notified, 1);

      await tester.tap(find.text('Fim do mês'));
      await tester.pumpAndSettle();
      expect(find.text(routeMarker(AppRoutes.projection)), findsOneWidget);
    });

    testWidgets('invites to inform the first balance', (tester) async {
      when(balances.latest).thenAnswer((_) async => null);
      await pump(tester);

      expect(find.text('—'), findsOneWidget);
      verifyNever(
        () => projections.fetch(
          from: any(named: 'from'),
          period: any(named: 'period'),
        ),
      );
      await tester.tap(find.text('Informar saldo'));
      await tester.pumpAndSettle();
      expect(find.text(routeMarker(AppRoutes.balanceForm)), findsOneWidget);
    });

    testWidgets('shows where the money goes', (tester) async {
      await pump(tester);

      expect(find.text('Para onde vai o dinheiro'), findsOneWidget);
      expect(find.text('Moradia'), findsOneWidget);
      expect(find.text('71%'), findsOneWidget);
      expect(find.text('Mercado'), findsOneWidget);
      expect(find.text('29%'), findsOneWidget);
      expect(find.text(r'Fixas R$ 2.000,00'), findsOneWidget);
      expect(find.text(r'Variáveis R$ 800,00'), findsOneWidget);
      expect(find.text('Outras'), findsNothing);
    });

    testWidgets('groups the smaller categories as others', (tester) async {
      when(() => entries.month(any())).thenAnswer(
        (_) async => [
          for (var index = 0; index < 7; index++)
            housing.copyWith(
              id: 'entry-$index',
              categoryId: 'key_$index',
              amountCents: 10000 * (7 - index),
            ),
        ],
      );
      await pump(tester);

      expect(find.text('key_0'), findsOneWidget);
      expect(find.text('key_5'), findsNothing);
      expect(find.text('Outras'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
    });

    testWidgets('says when the month has no expenses', (tester) async {
      when(() => entries.month(any())).thenAnswer((_) async => [salary]);
      await pump(tester);

      expect(find.text('Nenhuma despesa neste mês.'), findsOneWidget);
    });

    testWidgets('opens the bills due in the next days', (tester) async {
      when(() => entries.between(any(), any(), kind: EntryKind.expense))
          .thenAnswer((_) async => [housing, groceries]);
      await pump(tester);

      expect(find.text('1 conta vence nos próximos 7 dias'), findsOneWidget);
      expect(find.text(r'R$ 2.000,00'), findsOneWidget);
      await tester.tap(find.text('1 conta vence nos próximos 7 dias'));
      await tester.pumpAndSettle();
      expect(find.text(routeMarker(AppRoutes.due)), findsOneWidget);
    });

    testWidgets('says when nothing is due', (tester) async {
      await pump(tester);

      expect(
        find.text('Nenhuma conta vence nos próximos 7 dias'),
        findsOneWidget,
      );
    });

    testWidgets('warns about a negative month and opens the projection', (
      tester,
    ) async {
      await pump(tester);

      final alert = find.text('Em dezembro de 2026 o saldo fica negativo.');
      expect(alert, findsOneWidget);
      await tester.tap(alert);
      await tester.pumpAndSettle();

      expect(find.text(routeMarker(AppRoutes.projection)), findsOneWidget);
    });

    testWidgets('has no warning when every month stays positive', (
      tester,
    ) async {
      when(
        () => projections.fetch(
          from: any(named: 'from'),
          period: any(named: 'period'),
        ),
      ).thenAnswer(
        (_) async => projection.copyWith(
          months: [novemberProjection],
          firstNegativeMonth: null,
        ),
      );
      await pump(tester);

      expect(find.textContaining('saldo fica negativo'), findsNothing);
    });

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

      await tester.fling(find.byType(ListView), const Offset(0, 3000), 1000);
      await tester.pumpAndSettle();

      verify(balances.latest).called(2);
      expect(notified, 1);
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
      when(() => entries.categories(any())).thenAnswer((_) async => []);
      when(() => entries.between(any(), any(), kind: any(named: 'kind')))
          .thenAnswer((_) async => []);
      getIt
        ..allowReassignment = true
        ..registerSingleton<AuthRepository>(repository)
        ..registerSingleton<BalanceRepository>(balances)
        ..registerSingleton<EntryRepository>(entries)
        ..registerSingleton<ReserveRepository>(
          reserveRepositoryWith(emptyReserve),
        )
        ..registerSingleton<ReserveDismissal>(dismissalUntil(null));
    });

    testWidgets('greets the signed in user and logs out from Mais', (
      tester,
    ) async {
      when(repository.logout).thenAnswer((_) async {});
      await tester.pumpWidget(const App());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      getIt<SessionCubit>().signedIn(ana);
      await tester.pumpAndSettle();
      expect(find.text('Olá, Ana!'), findsOneWidget);

      await tester.tap(find.text('Mais'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Sair'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      verify(repository.logout).called(1);
      expect(find.text('Entrar'), findsWidgets);
    });
  });
}
