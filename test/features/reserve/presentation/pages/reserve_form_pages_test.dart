import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/reserve/presentation/cubits/reserve_cubits.dart';
import 'package:lar_em_dia/features/reserve/presentation/pages/reserve_account_form_page.dart';
import 'package:lar_em_dia/features/reserve/presentation/pages/reserve_movement_form_page.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/reserve_fixtures.dart';

void main() {
  late MockReserveRepository repository;
  late List<Object?> popped;
  final today = DateTime(2026, 11, 12);
  final save = find.text('Salvar');

  setUpAll(registerReserveFallbacks);
  setUp(() {
    repository = MockReserveRepository();
    popped = [];
    when(() => repository.createAccount(any()))
        .thenAnswer((_) async => treasury);
    when(() => repository.updateAccount(any(), any()))
        .thenAnswer((_) async => treasury);
    when(() => repository.createMovement(any()))
        .thenAnswer((_) async => depositMovement);
    when(() => repository.updateMovement(any(), any()))
        .thenAnswer((_) async => depositMovement);
  });

  Future<void> pumpForm(WidgetTester tester, Widget form) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => TextButton(
            onPressed: () async =>
                popped.add(await context.push<bool>('/form')),
            child: const Text('open'),
          ),
        ),
        GoRoute(path: '/form', builder: (_, _) => form),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String key, String label) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  group('ReserveAccountFormPage', () {
    Future<void> pump(WidgetTester tester, [ReserveAccount? existing]) =>
        pumpForm(
          tester,
          BlocProvider(
            create: (_) => ReserveAccountFormCubit(repository),
            child: ReserveAccountFormPage(existing: existing, today: today),
          ),
        );

    final name = find.byKey(const Key('reserve_account_name'));
    final anchor = find.byKey(const Key('reserve_account_anchor'));

    testWidgets('creates an account with the balance of today', (tester) async {
      await pump(tester);
      expect(find.text('Novo pote'), findsOneWidget);
      expect(find.byKey(const Key('reserve_account_cdi')), findsNothing);
      expect(find.byKey(const Key('reserve_account_exempt')), findsNothing);

      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Campo obrigatório'), findsOneWidget);

      await tester.enterText(name, '  Tesouro Selic ');
      await tester.enterText(anchor, '12.000,00');
      await tester.tap(save);
      await tester.pumpAndSettle();

      verify(() => repository.createAccount(treasuryDraft)).called(1);
      verify(
        () => repository.createMovement(
          ReserveMovementDraft(
            accountId: treasury.id,
            kind: ReserveMovementKind.anchor,
            movedOn: today,
            amountCents: 1200000,
          ),
        ),
      ).called(1);
      expect(popped, [true]);
    });

    testWidgets('creates an exempt CDB without a balance', (tester) async {
      await pump(tester);

      await tester.enterText(name, 'CDB do banco');
      await choose(tester, 'reserve_account_kind', 'CDB/LCI/LCA');
      expect(find.byKey(const Key('reserve_account_rate')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('reserve_account_cdi')),
        '110,5',
      );
      await tester.tap(find.byKey(const Key('reserve_account_exempt')));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      verify(
        () => repository.createAccount(
          const ReserveAccountDraft(
            name: 'CDB do banco',
            kind: ReserveKind.cdb,
            cdiPercentBps: 11050,
            taxExempt: true,
          ),
        ),
      ).called(1);
      verifyNever(() => repository.createMovement(any()));
    });

    testWidgets('asks for a valid fixed rate and a valid balance', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(name, 'Prefixado');
      await choose(tester, 'reserve_account_kind', 'Taxa fixa');
      final rate = find.byKey(const Key('reserve_account_rate'));
      await tester.enterText(anchor, '-');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Informe uma taxa válida'), findsOneWidget);

      await tester.enterText(rate, '0');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Informe uma taxa válida'), findsOneWidget);

      await tester.enterText(rate, '12.25');
      await tester.enterText(anchor, '');
      await tester.tap(save);
      await tester.pumpAndSettle();

      verify(
        () => repository.createAccount(
          const ReserveAccountDraft(
            name: 'Prefixado',
            kind: ReserveKind.fixedRate,
            annualRateBps: 1225,
          ),
        ),
      ).called(1);
    });

    testWidgets('edits an account without the balance field', (tester) async {
      await pump(tester, cdb.copyWith(cdiPercentBps: 10050));

      expect(find.text('Editar pote'), findsOneWidget);
      expect(anchor, findsNothing);
      expect(find.text('100,50'), findsOneWidget);
      await choose(tester, 'reserve_account_kind', 'Poupança');
      await tester.tap(save);
      await tester.pumpAndSettle();

      verify(
        () => repository.updateAccount(
          cdb.id,
          const ReserveAccountDraft(
            name: 'CDB do banco',
            kind: ReserveKind.savings,
          ),
        ),
      ).called(1);
      expect(popped, [true]);
    });

    testWidgets('shows a whole rate and the field errors', (tester) async {
      when(() => repository.updateAccount(any(), any())).thenThrow(
        const ApiError(
          code: 'validation_failed',
          details: {
            'cdi_percent_bps': [FieldError(code: 'rate_required')],
          },
        ),
      );
      await pump(tester, cdb);

      expect(find.text('110'), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('% do CDI: Informe a taxa deste tipo'), findsOneWidget);
      expect(popped, isEmpty);
    });
  });

  group('ReserveMovementFormPage', () {
    Future<void> pump(WidgetTester tester, ReserveMovementFormArgs args) =>
        pumpForm(
          tester,
          BlocProvider(
            create: (_) => ReserveMovementFormCubit(repository),
            child: ReserveMovementFormPage(args: args, today: today),
          ),
        );

    final amount = find.byKey(const Key('reserve_movement_amount'));
    final debit = find.byKey(const Key('reserve_movement_debit_balance'));

    testWidgets('registers a deposit that debits the balance', (tester) async {
      await pump(
        tester,
        const ReserveMovementFormArgs(accounts: [treasury, idle]),
      );
      expect(find.text('Registrar movimento'), findsOneWidget);
      expect(find.text('Descontar do saldo'), findsOneWidget);

      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Campo obrigatório'), findsOneWidget);

      await choose(tester, 'reserve_movement_account', 'Conta corrente');
      await tester.enterText(amount, '200,00');
      await tester.tap(find.byKey(const Key('reserve_movement_moved_on')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();

      verify(
        () => repository.createMovement(
          ReserveMovementDraft(
            accountId: idle.id,
            kind: ReserveMovementKind.deposit,
            movedOn: DateTime(2026, 11),
            amountCents: 20000,
            debitBalance: true,
          ),
        ),
      ).called(1);
      expect(popped, [true]);
    });

    testWidgets('registers a withdrawal kept out of the balance', (
      tester,
    ) async {
      await pump(
        tester,
        ReserveMovementFormArgs(
          accounts: const [treasury],
          accountId: treasury.id,
        ),
      );

      await choose(tester, 'reserve_movement_kind', 'Resgate');
      expect(find.text('Somar ao saldo'), findsOneWidget);
      await tester.tap(debit);
      await tester.pumpAndSettle();
      await tester.enterText(amount, '0,00');
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Informe um valor maior que zero'), findsOneWidget);

      await tester.enterText(amount, '50,00');
      await tester.tap(save);
      await tester.pumpAndSettle();

      verify(
        () => repository.createMovement(
          ReserveMovementDraft(
            accountId: treasury.id,
            kind: ReserveMovementKind.withdrawal,
            movedOn: today,
            amountCents: 5000,
          ),
        ),
      ).called(1);
    });

    testWidgets('registers a zero balance as an anchor without the switch', (
      tester,
    ) async {
      await pump(tester, const ReserveMovementFormArgs(accounts: [treasury]));

      await choose(tester, 'reserve_movement_kind', 'Saldo atual');
      expect(debit, findsNothing);
      expect(find.textContaining('substitui o que veio antes'), findsOneWidget);
      await tester.enterText(amount, '0,00');
      await tester.tap(save);
      await tester.pumpAndSettle();

      verify(
        () => repository.createMovement(
          ReserveMovementDraft(
            accountId: treasury.id,
            kind: ReserveMovementKind.anchor,
            movedOn: today,
            amountCents: 0,
          ),
        ),
      ).called(1);
    });

    testWidgets('edits a linked movement and explains a refusal', (
      tester,
    ) async {
      when(() => repository.updateMovement(any(), any())).thenThrow(
        const ApiError(
          code: 'validation_failed',
          details: {
            'amount_cents': [FieldError(code: 'insufficient_reserve')],
          },
        ),
      );
      await pump(
        tester,
        ReserveMovementFormArgs(
          accounts: const [treasury],
          existing: depositMovement,
        ),
      );

      expect(find.text('Editar movimento'), findsOneWidget);
      expect(find.text('200,00'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(debit).value, isTrue);
      await tester.tap(save);
      await tester.pumpAndSettle();

      verify(() => repository.updateMovement(depositMovement, depositDraft))
          .called(1);
      expect(
        find.text('Valor: O pote não tem esse valor nesta data'),
        findsOneWidget,
      );
      expect(popped, isEmpty);
    });
  });
}
