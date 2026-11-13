import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/investments/domain/distribution.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/distribution_form_page.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/investment_fixtures.dart';

void main() {
  late MockInvestmentRepository repository;
  late List<Object?> popped;
  final today = DateTime(2026, 11, 12);
  final save = find.text('Salvar');
  final amount = find.byKey(const Key('distribution_amount'));

  setUpAll(registerInvestmentFallbacks);
  setUp(() {
    repository = MockInvestmentRepository();
    popped = [];
    when(() => repository.createDistribution(any()))
        .thenAnswer((_) async => itsaJcp);
    when(() => repository.updateDistribution(any(), any()))
        .thenAnswer((_) async => itsaJcp);
  });

  Future<void> pump(WidgetTester tester, DistributionFormArgs args) async {
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
        GoRoute(
          path: '/form',
          builder: (_, _) => BlocProvider(
            create: (_) => DistributionFormCubit(repository),
            child: DistributionFormPage(args: args, today: today),
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

  Future<void> pickDay(WidgetTester tester, String key, String day) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.text(day));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('records a JCP with its gross value per share', (tester) async {
    await pump(tester, const DistributionFormArgs(ticker: 'ITSA4'));
    expect(find.text('Registrar provento'), findsOneWidget);

    await tester.tap(find.byKey(const Key('distribution_kind')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JCP').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('líquido dos 15%'), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.text('Informe um valor maior que zero, com até 8 casas'),
      findsOneWidget,
    );

    await pickDay(tester, 'distribution_record_on', '3');
    await tester.enterText(amount, '0,33333333');
    await tester.tap(save);
    await tester.pumpAndSettle();

    verify(
      () => repository.createDistribution(
        DistributionDraft(
          ticker: 'ITSA4',
          kind: DistributionKind.jcp,
          recordOn: DateTime(2026, 11, 3),
          paidOn: today,
          amountPerShareE8: 33333333,
        ),
      ),
    ).called(1);
    expect(popped, [true]);
  });

  testWidgets('refuses a payment before the record date', (tester) async {
    await pump(tester, const DistributionFormArgs(ticker: 'ITSA4'));

    await pickDay(tester, 'distribution_paid_on', '3');
    await tester.enterText(amount, '1,00');
    expect(find.byKey(const Key('distribution_dates_error')), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();

    verifyNever(() => repository.createDistribution(any()));
  });

  testWidgets('edits a distribution and explains a refusal', (tester) async {
    when(() => repository.updateDistribution(any(), any())).thenThrow(
      const ApiError(
        code: 'validation_failed',
        details: {
          'ticker': [FieldError(code: 'stock_only')],
          'paid_on': [FieldError(code: 'before_record_on')],
        },
      ),
    );
    await pump(
      tester,
      DistributionFormArgs(ticker: 'ITSA4', existing: itsaJcp),
    );

    expect(find.text('Editar provento'), findsOneWidget);
    expect(find.text('0,33333333'), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();

    verify(() => repository.updateDistribution(itsaJcp, itsaJcpDraft))
        .called(1);
    expect(
      find.text('Papel: Só ações aceitam proventos registrados à mão'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Data de pagamento: O pagamento não pode ser antes da data com',
      ),
      findsOneWidget,
    );
    expect(popped, isEmpty);
  });
}
