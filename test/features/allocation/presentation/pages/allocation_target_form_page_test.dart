import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/allocation/domain/allocation.dart';
import 'package:lar_em_dia/features/allocation/presentation/cubits/allocation_cubits.dart';
import 'package:lar_em_dia/features/allocation/presentation/pages/allocation_target_form_page.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/allocation_fixtures.dart';
import '../../../../helpers/reserve_fixtures.dart';

void main() {
  late MockAllocationRepository repository;
  late List<Object?> popped;
  final save = find.text('Salvar');

  setUpAll(registerAllocationFallbacks);
  setUp(() {
    repository = allocationRepositoryWith(novemberPlan);
    popped = [];
  });

  Future<void> pumpForm(
    WidgetTester tester,
    AllocationTargetFormArgs args,
  ) async {
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
            create: (_) => AllocationTargetFormCubit(repository),
            child: AllocationTargetFormPage(args: args),
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

  testWidgets('creates the remainder destination linked to the reserve', (
    tester,
  ) async {
    await pumpForm(
      tester,
      const AllocationTargetFormArgs(accounts: [treasury, idle]),
    );

    expect(find.text('Novo destino'), findsOneWidget);
    expect(
      find.text('Fica com o que os outros destinos não usarem.'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('allocation_name')), 'Reserva');
    await tester.tap(find.byKey(const Key('allocation_reserve')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tesouro Selic').last);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    verify(
      () => repository.createTarget(
        const AllocationTargetDraft(
          name: 'Reserva',
          mode: AllocationMode.remainder,
          reserveAccountId: 'reserve-account-1',
        ),
      ),
    ).called(1);
    expect(popped, [true]);
  });

  testWidgets('creates a fixed destination and validates the amount', (
    tester,
  ) async {
    await pumpForm(
      tester,
      const AllocationTargetFormArgs(remainderTaken: true),
    );

    expect(find.byKey(const Key('allocation_percent')), findsOneWidget);
    expect(find.byKey(const Key('allocation_reserve')), findsNothing);
    await tester.tap(find.text('Valor fixo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('allocation_name')),
      'Caridade',
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    verifyNever(() => repository.createTarget(any()));

    await tester.enterText(find.byKey(const Key('allocation_amount')), '1000');
    await tester.tap(save);
    await tester.pumpAndSettle();

    verify(
      () => repository.createTarget(
        const AllocationTargetDraft(
          name: 'Caridade',
          mode: AllocationMode.fixed,
          amountCents: 1000,
        ),
      ),
    ).called(1);
  });

  testWidgets('edits a percentage and rejects more than 100%', (tester) async {
    await pumpForm(
      tester,
      const AllocationTargetFormArgs(
        existing: fixedIncome,
        remainderTaken: true,
      ),
    );

    expect(find.text('Editar destino'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('allocation_percent')), '120');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(
      find.text('Informe uma porcentagem entre 0,01 e 100'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('allocation_percent')), '12,5');
    await tester.tap(save);
    await tester.pumpAndSettle();

    verify(
      () => repository.updateTarget(
        'target-1',
        const AllocationTargetDraft(
          name: 'Renda fixa',
          mode: AllocationMode.percent,
          percentBps: 1250,
        ),
      ),
    ).called(1);
  });

  testWidgets('shows the field errors from the API', (tester) async {
    when(() => repository.updateTarget(any(), any())).thenThrow(
      const ApiError(
        code: 'validation_failed',
        details: {
          'mode': [FieldError(code: 'taken', message: 'taken')],
        },
      ),
    );
    await pumpForm(tester, const AllocationTargetFormArgs(existing: charity));

    expect(find.text('10,00'), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.textContaining('Como dividir:'), findsOneWidget);
    expect(popped, isEmpty);
  });
}
