import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/reserve/presentation/cubits/reserve_cubits.dart';
import 'package:lar_em_dia/features/reserve/presentation/pages/reserve_account_page.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/pump_page.dart';
import '../../../../helpers/reserve_fixtures.dart';

void main() {
  late MockReserveRepository repository;
  late FinanceChanges changes;
  late int notified;

  setUpAll(registerReserveFallbacks);
  setUp(() {
    repository = reserveRepositoryWith(reserveSummary);
    when(() => repository.movements(treasury.id)).thenAnswer(
      (_) async => [anchorMovement, depositMovement, withdrawalMovement],
    );
    changes = FinanceChanges(FinanceCache());
    notified = 0;
    changes.addListener(() => notified++);
  });

  Widget marker(BuildContext context, GoRouterState state) => Scaffold(
    body: Column(
      children: [
        Text(routeMarker(state.uri.path, state.extra)),
        TextButton(
          onPressed: () => context.pop(true),
          child: const Text(savedAndBack),
        ),
      ],
    ),
  );

  Future<void> pump(
    WidgetTester tester, {
    String id = 'reserve-account-1',
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => TextButton(
            onPressed: () => context.push('/account'),
            child: const Text('open'),
          ),
        ),
        GoRoute(
          path: '/account',
          builder: (_, _) => BlocProvider(
            create: (_) => started(
              ReserveAccountCubit(repository, id),
              (cubit) => cubit.load(),
            ),
            child: const ReserveAccountPage(),
          ),
        ),
        GoRoute(path: AppRoutes.reserveAccountForm, builder: marker),
        GoRoute(path: AppRoutes.reserveMovementForm, builder: marker),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: changes,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the values and the latest movements first', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Tesouro Selic'), findsWidgets);
    expect(find.text(r'R$ 12.400,00'), findsOneWidget);
    expect(find.text(r'R$ 12.500,00'), findsOneWidget);
    expect(find.text(r'R$ 12.000,00'), findsWidgets);
    expect(find.text(r'R$ 500,00'), findsOneWidget);
    expect(find.text(r'R$ 100,00'), findsOneWidget);
    expect(find.text('Saldo atual'), findsOneWidget);
    expect(find.text('05/07/2026 · no saldo'), findsOneWidget);
    expect(find.text(r'-R$ 50,00'), findsOneWidget);
    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();
    expect(titles, ['Resgate', 'Depósito', 'Saldo atual']);
  });

  testWidgets('shows an account without movements', (tester) async {
    when(() => repository.movements(treasury.id)).thenAnswer((_) async => []);
    await pump(tester);

    expect(find.text('Nenhum movimento ainda.'), findsOneWidget);
  });

  testWidgets('opens the movement form to add and to edit', (tester) async {
    await pump(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('route:${AppRoutes.reserveMovementForm}'),
      findsOneWidget,
    );
    await tester.tap(find.text(savedAndBack));
    await tester.pumpAndSettle();
    expect(notified, 1);

    await tester.tap(find.text('Depósito'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('route:${AppRoutes.reserveMovementForm}'),
      findsOneWidget,
    );
  });

  testWidgets('deletes a movement after confirmation', (tester) async {
    when(() => repository.deleteMovement(depositMovement))
        .thenAnswer((_) async {});
    await pump(tester);

    await tester.tap(
      find.descendant(
        of: find.byKey(Key('reserve_movement_${depositMovement.id}')),
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Excluir movimento?'), findsOneWidget);
    expect(find.textContaining('Depósito de 05/07/2026'), findsOneWidget);
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();

    verify(() => repository.deleteMovement(depositMovement)).called(1);
    expect(notified, 1);
  });

  testWidgets('keeps a movement when the deletion is cancelled', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(() => repository.deleteMovement(any()));
  });

  testWidgets('explains a refused movement deletion', (tester) async {
    when(() => repository.deleteMovement(anchorMovement))
        .thenThrow(const ApiError(code: 'insufficient_reserve'));
    await pump(tester);

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('ficaria sem dinheiro suficiente'),
      findsOneWidget,
    );
    expect(notified, 0);
  });

  testWidgets('edits the account from the menu', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('reserve_account_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('route:${AppRoutes.reserveAccountForm}'),
      findsOneWidget,
    );
  });

  testWidgets('deletes the account and goes back', (tester) async {
    when(() => repository.deleteAccount(treasury.id)).thenAnswer((_) async {});
    await pump(tester);

    await tester.tap(find.byKey(const Key('reserve_account_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir pote'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Os lançamentos ligados'), findsOneWidget);
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(notified, 1);
  });

  testWidgets('keeps the account when the deletion is cancelled or fails', (
    tester,
  ) async {
    when(() => repository.deleteAccount(treasury.id))
        .thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    Future<void> openDeletion() async {
      await tester.tap(find.byKey(const Key('reserve_account_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir pote'));
      await tester.pumpAndSettle();
    }

    await openDeletion();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    verifyNever(() => repository.deleteAccount(any()));

    await openDeletion();
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(notified, 0);
  });

  testWidgets('retries an account that failed to load', (tester) async {
    when(() => repository.movements('gone')).thenAnswer((_) async => []);
    await pump(tester, id: 'gone');

    expect(find.text('Tentar de novo'), findsOneWidget);
    expect(find.byKey(const Key('reserve_account_menu')), findsNothing);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar de novo'), findsOneWidget);
  });
}
