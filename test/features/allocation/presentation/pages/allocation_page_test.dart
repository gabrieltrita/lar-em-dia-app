import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/allocation/domain/allocation.dart';
import 'package:lar_em_dia/features/allocation/presentation/cubits/allocation_cubits.dart';
import 'package:lar_em_dia/features/allocation/presentation/pages/allocation_page.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/allocation_fixtures.dart';
import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/pump_page.dart';
import '../../../../helpers/reserve_fixtures.dart';

void main() {
  late AuthHarness harness;
  late MockAllocationRepository repository;
  late FinanceChanges changes;
  late int notified;
  final november = DateTime(2026, 11);

  setUpAll(registerAllocationFallbacks);
  setUp(() {
    harness = AuthHarness();
    repository = allocationRepositoryWith(novemberPlan);
    changes = FinanceChanges(FinanceCache());
    notified = 0;
    changes.addListener(() => notified++);
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester, {DateTime? today}) {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    return pumpPage(
      tester,
      BlocProvider(
        create: (_) => started(
          AllocationCubit(
            repository,
            reserveRepositoryWith(reserveSummary),
            allocationCategoriesRepository(),
          ),
          (cubit) => cubit.load(month: november),
        ),
        child: AllocationPage(today: today ?? DateTime(2026, 11, 20)),
      ),
      session: harness.session,
      changes: changes,
    );
  }

  testWidgets('shows the month, the totals and every destination', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Distribuir sobra'), findsOneWidget);
    expect(find.text('novembro de 2026'), findsOneWidget);
    expect(find.text(r'R$ 94,00'), findsOneWidget);
    expect(find.text(r'R$ 84,00'), findsOneWidget);
    expect(find.text('Renda fixa'), findsNWidgets(2));
    expect(find.text('10% da sobra'), findsOneWidget);
    expect(
      find.text(
        r'Presentes e doações · Valor fixo de R$ 10,00 · Usado em 20/11/2026',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Fica com o resto · Vai para a reserva: Tesouro Selic'),
      findsOneWidget,
    );
    expect(find.text(r'R$ 74,60'), findsOneWidget);
  });

  testWidgets('marks a destination as used with the amount chosen', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('allocation_use_target-1')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'O valor de Renda fixa sai do saldo final do mês. '
        'Até lá, o saldo continua como está.',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('allocation_use_amount')),
      '900',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Marcar como usado'));
    await tester.pumpAndSettle();

    verify(() => repository.use('target-1', november, amountCents: 900))
        .called(1);
    expect(notified, 1);
  });

  testWidgets('says a reserve destination becomes a deposit', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('allocation_use_target-3')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'O valor de Reserva vira um depósito na reserva e sai do saldo final '
        'do mês.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    verifyNever(
      () =>
          repository.use(any(), any(), amountCents: any(named: 'amountCents')),
    );
  });

  testWidgets('undoes a used destination and reports a refusal', (
    tester,
  ) async {
    when(() => repository.undo(any()))
        .thenThrow(const ApiError(code: 'insufficient_reserve'));
    await pump(tester);

    await tester.tap(find.byKey(const Key('allocation_use_target-2')));
    await tester.pumpAndSettle();
    expect(find.text('Desfazer uso?'), findsOneWidget);
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();

    verify(() => repository.undo('allocation-1')).called(1);
    expect(find.textContaining('resgate depois desta data'), findsOneWidget);
    expect(notified, 0);
  });

  testWidgets('does not let future months be used', (tester) async {
    await pump(tester, today: DateTime(2026, 10, 5));

    expect(
      find.text(
        'Você só pode marcar como usado no mês atual ou em meses passados.',
      ),
      findsOneWidget,
    );
    final checkbox = tester.widget<Checkbox>(
      find.byKey(const Key('allocation_use_target-1')),
    );
    expect(checkbox.onChanged, isNull);
  });

  testWidgets('edits and deletes a destination', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('allocation_menu_target-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('route:${AppRoutes.allocationTargetForm}'),
      findsOneWidget,
    );
    await tester.tap(find.text(savedAndBack));
    await tester.pumpAndSettle();
    expect(notified, 1);

    await tester.tap(find.byKey(const Key('allocation_menu_target-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apagar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await tester.pumpAndSettle();

    verify(() => repository.deleteTarget('target-2')).called(1);
  });

  testWidgets('switches months', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();

    verify(() => repository.plan(DateTime(2026, 10))).called(1);
  });

  testWidgets('invites to create the first destination', (tester) async {
    when(repository.targets).thenAnswer((_) async => []);
    when(() => repository.plan(any())).thenAnswer(
      (_) async => AllocationPlan(
        month: november,
        closingCents: -500,
        baseCents: -500,
        usedCents: 0,
        plannedCents: 0,
        unallocatedCents: -500,
      ),
    );
    await pump(tester);

    expect(find.text('Para onde vai o que sobra?'), findsOneWidget);
    await tester.tap(find.text('Novo destino'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        routeMarker(
          AppRoutes.allocationTargetForm,
          const AllocationTargetFormArgs(
            accounts: [treasury, idle],
            categories: allocationCategories,
          ),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('charts the split by category, destination and what is left', (
    tester,
  ) async {
    when(() => repository.plan(any())).thenAnswer(
      (_) async => novemberPlan.copyWith(
        unallocatedCents: 1000,
        items: [
          ...novemberPlan.items,
          const AllocationItem(
            targetId: 'target-4',
            name: 'Viagem',
            mode: AllocationMode.percent,
            amountCents: 0,
            percentBps: 500,
          ),
        ],
      ),
    );
    await pump(tester);

    final chart = find.byKey(const Key('allocation_chart'));
    expect(find.text('Como a sobra se divide'), findsOneWidget);
    for (final label in [
      'Renda fixa',
      'Presentes e doações',
      'Reserva',
      'Sem destino',
      '9%',
      '10%',
      '72%',
    ]) {
      expect(
        find.descendant(of: chart, matching: find.text(label)),
        findsWidgets,
        reason: label,
      );
    }
    expect(
      find.descendant(of: chart, matching: find.text('Viagem')),
      findsNothing,
    );
  });

  testWidgets('says when the month has nothing to split', (tester) async {
    when(
      () => repository.plan(any()),
    ).thenAnswer((_) async => novemberPlan.copyWith(baseCents: 0, items: []));
    await pump(tester);

    expect(
      find.text('Este mês não tem sobra para distribuir.'),
      findsOneWidget,
    );
  });

  testWidgets('retries after a failure', (tester) async {
    when(repository.targets).thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    expect(find.text('Tentar de novo'), findsOneWidget);
  });
}
