import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/investment_form_page.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/investment_fixtures.dart';

void main() {
  late MockInvestmentRepository repository;
  late List<Object?> popped;
  final today = DateTime(2026, 11, 12);

  setUpAll(registerInvestmentFallbacks);
  setUp(() {
    repository = MockInvestmentRepository();
    popped = [];
    when(() => repository.create(any())).thenAnswer((_) async => hglgBuy);
    when(() => repository.update(any(), any()))
        .thenAnswer((_) async => hglgBuy);
  });

  Future<void> pump(
    WidgetTester tester, [
    InvestmentFormArgs args = const InvestmentFormArgs(),
  ]) async {
    tester.view.physicalSize = const Size(2400, 4800);
    addTearDown(tester.view.resetPhysicalSize);
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
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => InvestmentFormCubit(repository)),
              BlocProvider(create: (_) => AssetSearchCubit(repository)),
            ],
            child: InvestmentFormPage(args: args, today: today),
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

  final quantity = find.byKey(const Key('investment_quantity'));
  final price = find.byKey(const Key('investment_price'));
  final fees = find.byKey(const Key('investment_fees'));
  final save = find.text('Salvar');

  Future<void> chooseKind(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const Key('investment_kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  InvestmentDraft created() =>
      verify(() => repository.create(captureAny())).captured.single
          as InvestmentDraft;

  testWidgets('asks for an asset and a whole number of shares', (tester) async {
    await pump(tester);

    await tester.tap(save);
    await tester.pump();

    expect(find.text('Escolha um papel'), findsOneWidget);
    expect(find.text('Informe um número inteiro de cotas'), findsOneWidget);
    verifyNever(() => repository.create(any()));
  });

  testWidgets('finds the asset, asks its goal and debits the balance', (
    tester,
  ) async {
    when(() => repository.searchAssets('HGLG')).thenAnswer((_) async => [hglg]);
    await pump(tester);

    await tester.enterText(find.byKey(const Key('asset_search')), 'HGLG');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PATRIA LOG FII'));
    await tester.pumpAndSettle();

    expect(find.text('Objetivo deste papel'), findsOneWidget);
    await tester.enterText(quantity, '10');
    await tester.enterText(price, '15000');
    await tester.enterText(fees, '500');
    await tester.pump();
    expect(
      find.text(r'R$ 1.505,00 entra nos lançamentos como despesa'),
      findsOneWidget,
    );

    await tester.tap(find.text('Crescimento'));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      created(),
      InvestmentDraft(
        ticker: 'HGLG11',
        kind: InvestmentKind.buy,
        tradedOn: today,
        quantity: 10,
        priceCents: 15000,
        feesCents: 500,
        goal: InvestmentGoal.growth,
        debitBalance: true,
      ),
    );
    expect(popped, [true]);
  });

  testWidgets('lets the user pick another asset', (tester) async {
    when(() => repository.searchAssets('PE')).thenAnswer((_) async => [petr]);
    await pump(tester);

    await tester.enterText(find.byKey(const Key('asset_search')), 'PE');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PETROBRAS'));
    await tester.pumpAndSettle();
    expect(find.text('PETR4'), findsOneWidget);

    await tester.tap(find.byTooltip('Trocar papel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset_search')), findsOneWidget);
  });

  testWidgets('starts from the broker numbers without touching the balance', (
    tester,
  ) async {
    await pump(tester, InvestmentFormArgs(asset: hglg, existingHoldings: true));

    expect(find.textContaining('preço médio que aparecem'), findsOneWidget);
    expect(find.text('O preço médio da corretora'), findsOneWidget);
    expect(find.byTooltip('Trocar papel'), findsNothing);
    await tester.enterText(quantity, '25');
    await tester.enterText(price, '14250');
    await tester.tap(save);
    await tester.pumpAndSettle();

    final draft = created();
    expect(draft.debitBalance, isFalse);
    expect(draft.goal, InvestmentGoal.income);
    expect(draft.quantity, 25);
    expect(draft.priceCents, 14250);
  });

  testWidgets('skips the goal for an asset already held and credits a sale', (
    tester,
  ) async {
    await pump(
      tester,
      InvestmentFormArgs(asset: hglg, held: const {'HGLG11': 10}),
    );

    expect(find.text('Objetivo deste papel'), findsNothing);
    await chooseKind(tester, 'Venda');
    expect(find.text('Somar ao saldo'), findsOneWidget);
    await tester.enterText(quantity, '4');
    await tester.enterText(price, '16000');
    await tester.pump();
    expect(
      find.text(r'R$ 640,00 entra nos lançamentos como receita'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('investment_debit_balance')));
    await tester.tap(save);
    await tester.pumpAndSettle();

    final draft = created();
    expect(draft.kind, InvestmentKind.sell);
    expect(draft.debitBalance, isFalse);
    expect(draft.goal, isNull);
  });

  testWidgets('turns a split ratio into the shares received', (tester) async {
    await pump(
      tester,
      InvestmentFormArgs(asset: hglg, held: const {'HGLG11': 100}),
    );

    await chooseKind(tester, 'Desdobramento');
    expect(
      find.text('Você tem 100 cotas e passará a ter 200.'),
      findsOneWidget,
    );
    expect(price, findsNothing);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final draft = created();
    expect(draft.kind, InvestmentKind.split);
    expect(draft.quantity, 100);
    expect(draft.priceCents, isNull);
    expect(draft.debitBalance, isFalse);
  });

  testWidgets('turns a reverse split into the shares removed', (tester) async {
    await pump(
      tester,
      InvestmentFormArgs(asset: hglg, held: const {'HGLG11': 100}),
    );

    await chooseKind(tester, 'Grupamento');
    expect(find.text('Você tem 100 cotas e passará a ter 10.'), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final draft = created();
    expect(draft.kind, InvestmentKind.reverseSplit);
    expect(draft.quantity, 90);
  });

  testWidgets('refuses ratios that do not match the kind', (tester) async {
    await pump(
      tester,
      InvestmentFormArgs(asset: hglg, held: const {'HGLG11': 100}),
    );

    await chooseKind(tester, 'Desdobramento');
    await tester.enterText(find.byKey(const Key('investment_ratio_to')), '1');
    await tester.enterText(find.byKey(const Key('investment_ratio_from')), '2');
    await tester.tap(save);
    await tester.pump();

    expect(find.text('Proporção inválida para este tipo'), findsOneWidget);
    verifyNever(() => repository.create(any()));
  });

  testWidgets('needs shares before a split', (tester) async {
    await pump(tester, InvestmentFormArgs(asset: hglg));

    await chooseKind(tester, 'Desdobramento');
    await tester.tap(save);
    await tester.pump();

    expect(find.text('Você ainda não tem cotas deste papel'), findsOneWidget);
  });

  testWidgets('records a bonus by the shares received', (tester) async {
    await pump(
      tester,
      InvestmentFormArgs(asset: hglg, held: const {'HGLG11': 100}),
    );

    await chooseKind(tester, 'Bonificação');
    expect(find.text('Cotas recebidas'), findsOneWidget);
    await tester.enterText(quantity, '5');
    await tester.tap(save);
    await tester.pumpAndSettle();

    final draft = created();
    expect(draft.kind, InvestmentKind.bonus);
    expect(draft.quantity, 5);
    expect(draft.feesCents, 0);
  });

  testWidgets('edits a transaction keeping its kind', (tester) async {
    await pump(
      tester,
      InvestmentFormArgs(existing: hglgBuy, held: const {'HGLG11': 10}),
    );

    expect(find.text('Editar operação'), findsOneWidget);
    expect(find.text('HGLG11'), findsOneWidget);
    expect(find.text('150,00'), findsOneWidget);
    expect(find.text('5,00'), findsOneWidget);
    expect(
      find.text(r'R$ 1.505,00 entra nos lançamentos como despesa'),
      findsOneWidget,
    );
    await tester.enterText(quantity, '12');
    await tester.tap(save);
    await tester.pumpAndSettle();

    final captured = verify(() => repository.update(captureAny(), captureAny()))
        .captured;
    expect(captured.first, hglgBuy);
    expect((captured.last as InvestmentDraft).quantity, 12);
    expect((captured.last as InvestmentDraft).debitBalance, isTrue);
  });

  testWidgets('edits a split by its quantity', (tester) async {
    await pump(tester, InvestmentFormArgs(existing: hglgSplit));

    expect(find.byKey(const Key('investment_ratio_to')), findsNothing);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('translates the API errors by code', (tester) async {
    when(() => repository.create(any())).thenThrow(
      const ApiError(
        code: 'validation_failed',
        details: {
          'quantity': [FieldError(code: 'insufficient_quantity')],
          'ticker': [FieldError(code: 'unknown_asset')],
          'price_cents': [FieldError(code: 'only_for_trades')],
        },
      ),
    );
    await pump(
      tester,
      InvestmentFormArgs(asset: hglg, held: const {'HGLG11': 1}),
    );

    await chooseKind(tester, 'Venda');
    await tester.enterText(quantity, '4');
    await tester.enterText(price, '100');
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      find.text('Cotas: Você não tem cotas suficientes nesta data'),
      findsOneWidget,
    );
    expect(find.text('Papel: Papel não encontrado'), findsOneWidget);
    expect(
      find.text('Preço por cota: Só vale para compra e venda'),
      findsOneWidget,
    );
    expect(popped, isEmpty);
  });
}
