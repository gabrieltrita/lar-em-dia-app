import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/balance/domain/balance.dart';
import 'package:lar_em_dia/features/balance/presentation/cubits/balance_cubits.dart';
import 'package:lar_em_dia/features/balance/presentation/pages/balance_form_page.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/finance_fixtures.dart';

void main() {
  late MockBalanceRepository repository;
  late List<Object?> popped;

  setUpAll(registerFinanceFallbacks);
  setUp(() {
    repository = MockBalanceRepository();
    popped = [];
  });

  Future<void> pump(WidgetTester tester, {Balance? existing}) async {
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
        GoRoute(
          path: '/form',
          builder: (_, _) => BlocProvider(
            create: (_) => BalanceFormCubit(repository),
            child: BalanceFormPage(
              existing: existing,
              today: DateTime(2026, 11, 3),
            ),
          ),
        ),
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

  final amount = find.byKey(const Key('balance_amount'));
  final save = find.text('Salvar');

  testWidgets('requires an amount', (tester) async {
    await pump(tester);

    await tester.tap(save);
    await tester.pump();

    expect(find.text('Campo obrigatório'), findsOneWidget);
    expect(find.text('03/11/2026'), findsOneWidget);
  });

  testWidgets('creates a negative balance for today and closes', (
    tester,
  ) async {
    when(
      () => repository.create(amountCents: -25000, asOf: DateTime(2026, 11, 3)),
    ).thenAnswer((_) async => balance);
    await pump(tester);

    await tester.enterText(amount, '-25000');
    expect(find.text('-250,00'), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(popped, [true]);
  });

  testWidgets('edits an existing balance on another date', (tester) async {
    when(
      () => repository.update('balance-1', amountCents: 123456, asOf: november),
    ).thenAnswer((_) async => balance);
    await pump(tester, existing: balance);
    expect(find.text('Editar saldo'), findsOneWidget);
    expect(find.text('1.234,56'), findsOneWidget);

    await tester.tap(find.byKey(const Key('balance_as_of')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(popped, [true]);
  });

  testWidgets('explains a date that already has a balance', (tester) async {
    when(
      () => repository.create(
        amountCents: any(named: 'amountCents'),
        asOf: any(named: 'asOf'),
      ),
    ).thenThrow(
      const ApiError(
        code: 'validation_failed',
        details: {
          'as_of': [FieldError(code: 'taken')],
          'amount_cents': [FieldError(code: 'not_an_integer')],
        },
      ),
    );
    await pump(tester);

    await tester.enterText(amount, '100');
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Data: Já existe um saldo nessa data'), findsOneWidget);
    expect(find.text('Valor: Informe um valor maior que zero'), findsOneWidget);
    expect(popped, isEmpty);
  });

  testWidgets('explains a date in the future', (tester) async {
    when(
      () => repository.create(
        amountCents: any(named: 'amountCents'),
        asOf: any(named: 'asOf'),
      ),
    ).thenThrow(
      const ApiError(
        code: 'validation_failed',
        details: {
          'as_of': [FieldError(code: 'in_future')],
        },
      ),
    );
    await pump(tester);

    await tester.enterText(amount, '100');
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Data: A data não pode estar no futuro'), findsOneWidget);
  });
}
