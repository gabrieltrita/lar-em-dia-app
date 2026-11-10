import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/widgets/skeleton.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/cubits/entry_cubits.dart';
import 'package:lar_em_dia/features/entries/presentation/pages/entries_page.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_visuals.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/finance_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;
  late MockEntryRepository repository;
  late MockProjectionRepository projections;
  late FinanceChanges changes;
  late int notified;

  setUpAll(registerFinanceFallbacks);
  setUp(() {
    harness = AuthHarness();
    repository = MockEntryRepository();
    projections = MockProjectionRepository();
    when(
      () => projections.fetch(
        from: any(named: 'from'),
        period: any(named: 'period'),
      ),
    ).thenAnswer((_) async => projection);
    notified = 0;
    changes = FinanceChanges()..addListener(() => notified++);
    when(() => repository.categories(EntryKind.expense))
        .thenAnswer((_) async => [housingCategory, groceriesCategory]);
    when(() => repository.categories(EntryKind.income))
        .thenAnswer((_) async => [salaryCategory, rentCategory]);
    when(() => repository.month(any())).thenAnswer((_) async => [salary, rent]);
  });
  tearDown(() => harness.dispose());

  Future<void> pump(
    WidgetTester tester, {
    EntryKind? kind = EntryKind.income,
  }) => pumpPage(
    tester,
    BlocProvider(
      create: (_) =>
          started(MonthEntriesCubit(repository, projections), (cubit) async {
            await cubit.load(month: november);
            cubit.filterKind(kind);
          }),
      child: const EntriesPage(),
    ),
    session: harness.session,
    changes: changes,
  );

  testWidgets('shows the final balance or the month result in the footer', (
    tester,
  ) async {
    when(() => repository.month(any()))
        .thenAnswer((_) async => [salary, rent, housing, groceries]);
    await pump(tester, kind: EntryKind.expense);
    final footer = find.byKey(const Key('entries_final_balance'));

    expect(
      find.descendant(of: footer, matching: find.text('Saldo final do mês')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: footer, matching: find.text(r'R$ 4.934,56')),
      findsOneWidget,
    );

    await tester.tap(find.text('Incluir saldo acumulado'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: footer, matching: find.text('Resultado do mês')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: footer, matching: find.text(r'+R$ 3.700,00')),
      findsOneWidget,
    );
  });

  testWidgets('shows a dash as the final balance without a balance', (
    tester,
  ) async {
    when(
      () => projections.fetch(
        from: any(named: 'from'),
        period: any(named: 'period'),
      ),
    ).thenAnswer((_) async => Projection(months: [novemberProjection]));
    await pump(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('entries_final_balance')),
        matching: find.text('—'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('opens the add sheet from the button', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Adicionar'));
    await tester.pumpAndSettle();

    expect(find.text('Informar saldo'), findsOneWidget);
  });

  testWidgets('shows income and expenses together with the result', (
    tester,
  ) async {
    when(() => repository.month(any()))
        .thenAnswer((_) async => [salary, rent, housing, groceries]);
    await pump(tester, kind: null);

    expect(find.text('Lançamentos'), findsOneWidget);
    expect(find.text(r'R$ 6.500,00'), findsOneWidget);
    expect(find.text(r'R$ 2.800,00'), findsOneWidget);
    expect(find.text(r'+R$ 3.700,00'), findsOneWidget);
    expect(find.text('Aluguel de casa'), findsOneWidget);
    expect(find.text('Fixas'), findsNothing);

    await tester.tap(find.text('Despesas'));
    await tester.pumpAndSettle();
    expect(find.text('Salário ACME'), findsNothing);
    expect(find.text('Fixas'), findsOneWidget);

    await tester.tap(find.text('Receitas'));
    await tester.pumpAndSettle();
    expect(find.text('Aluguel de casa'), findsNothing);
    expect(find.text(r'Total do mês: R$ 6.500,00'), findsOneWidget);
  });

  testWidgets('lists the month with its total', (tester) async {
    await pump(tester);

    expect(find.text('novembro de 2026'), findsOneWidget);
    expect(find.text(r'Total do mês: R$ 6.500,00'), findsOneWidget);
    expect(find.text('Salário ACME'), findsOneWidget);
    expect(find.text(r'+R$ 5.000,00'), findsOneWidget);
    expect(find.byType(CategoryAvatar), findsNWidgets(2));
    expect(find.text('Salário · 05/11/2026 · Recebida'), findsOneWidget);
    expect(
      find.text('Aluguel recebido · 10/11/2026 · A receber'),
      findsOneWidget,
    );
  });

  testWidgets('marks the entries of a series', (tester) async {
    when(() => repository.month(any())).thenAnswer(
      (_) async => [salary.copyWith(seriesId: 'series-1', seriesPosition: 1)],
    );
    await pump(tester);

    expect(find.byIcon(Icons.repeat), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Lançamento repetido')),
      findsOneWidget,
    );
  });

  testWidgets('labels installments with their position', (tester) async {
    when(() => repository.month(any())).thenAnswer(
      (_) async => [
        salary.copyWith(
          seriesId: 'series-2',
          seriesPosition: 3,
          seriesKind: SeriesKind.installments,
          seriesCount: 10,
        ),
      ],
    );
    await pump(tester);

    expect(find.byIcon(Icons.credit_card), findsOneWidget);
    expect(find.byIcon(Icons.repeat), findsNothing);
    expect(find.text('Salário ACME 3/10'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Parcela 3 de 10')), findsOneWidget);
  });

  group('expenses', () {
    setUp(() {
      when(() => repository.month(any()))
          .thenAnswer((_) async => [housing, groceries]);
    });

    testWidgets('lists expenses with fixed and variable subtotals', (
      tester,
    ) async {
      await pump(tester, kind: EntryKind.expense);

      expect(find.text(r'Total do mês: R$ 2.800,00'), findsOneWidget);
      expect(
        find.text(r'Fixas R$ 2.000,00 · Variáveis R$ 800,00'),
        findsOneWidget,
      );
      expect(
        find.text('Moradia · Fixa · 10/11/2026 · A pagar'),
        findsOneWidget,
      );
      expect(
        find.text('Mercado · Variável · 07/11/2026 · Paga'),
        findsOneWidget,
      );
    });

    testWidgets('filters by nature', (tester) async {
      await pump(tester, kind: EntryKind.expense);

      await tester.tap(find.text('Fixas'));
      await tester.pumpAndSettle();
      expect(find.text(r'Total do mês: R$ 2.000,00'), findsOneWidget);
      expect(find.text('Aluguel de casa'), findsOneWidget);
      expect(find.text('Mercado do mês'), findsNothing);

      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      expect(find.text('Mercado do mês'), findsOneWidget);
    });

    testWidgets('says when no expense has the chosen nature', (tester) async {
      when(() => repository.month(any())).thenAnswer((_) async => [groceries]);
      await pump(tester, kind: EntryKind.expense);

      await tester.tap(find.text('Fixas'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum lançamento com este filtro.'), findsOneWidget);
    });

    testWidgets('confirms the deletion of an expense', (tester) async {
      await pump(tester, kind: EntryKind.expense);

      await tester.drag(find.text('Mercado do mês'), const Offset(-600, 0));
      await tester.pumpAndSettle();

      expect(find.text('Apagar despesa?'), findsOneWidget);
    });
  });

  testWidgets('moves between months', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Mês anterior'));
    await tester.pumpAndSettle();
    expect(find.text('outubro de 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pumpAndSettle();
    expect(find.text('dezembro de 2026'), findsOneWidget);
  });

  testWidgets('says when the month is empty', (tester) async {
    when(() => repository.month(any())).thenAnswer((_) async => []);
    await pump(tester);

    expect(find.text('Nada lançado neste mês'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receita'));
    await tester.pumpAndSettle();

    expect(
      find.text(routeMarker(AppRoutes.entryForm(EntryKind.income))),
      findsOneWidget,
    );
  });

  testWidgets('shows placeholders while loading', (tester) async {
    final pending = Completer<List<Entry>>();
    when(() => repository.month(any())).thenAnswer((_) => pending.future);
    await pumpPage(
      tester,
      BlocProvider(
        create: (_) => started(
          MonthEntriesCubit(repository, projections),
          (cubit) => cubit.load(month: november),
        ),
        child: const EntriesPage(),
      ),
      session: harness.session,
      settle: false,
    );

    expect(find.byType(SkeletonList), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('retries a failed load', (tester) async {
    when(() => repository.month(any()))
        .thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    when(() => repository.month(any())).thenAnswer((_) async => [salary]);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Salário ACME'), findsOneWidget);
  });

  testWidgets('opens an entry and reloads after saving', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Salário ACME'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        routeMarker(
          AppRoutes.entryForm(EntryKind.income),
          EntryEdit(entry: salary),
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(savedAndBack));
    await tester.pumpAndSettle();

    expect(notified, 1);
  });

  testWidgets('does not notify when the form is closed', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Salário ACME'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();

    expect(notified, 0);
  });

  Future<void> swipe(WidgetTester tester, String description) async {
    await tester.drag(find.text(description), const Offset(-600, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('swipes to delete after confirmation', (tester) async {
    when(() => repository.delete('entry-2')).thenAnswer((_) async {});
    await pump(tester);

    when(() => repository.month(any())).thenAnswer((_) async => [salary]);
    await swipe(tester, 'Aluguel apto 12');
    expect(find.text('"Aluguel apto 12" será apagada.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await tester.pumpAndSettle();

    verify(() => repository.delete('entry-2')).called(1);
    expect(find.text('Aluguel apto 12'), findsNothing);
  });

  testWidgets('keeps the entry when the deletion is cancelled', (tester) async {
    await pump(tester);

    await swipe(tester, 'Aluguel apto 12');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Aluguel apto 12'), findsOneWidget);
    verifyNever(() => repository.delete(any()));
  });

  testWidgets('keeps the entry when the deletion fails', (tester) async {
    when(() => repository.delete('entry-2'))
        .thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    await swipe(tester, 'Aluguel apto 12');
    await tester.tap(find.widgetWithText(FilledButton, 'Apagar'));
    await tester.pumpAndSettle();

    expect(find.text('Aluguel apto 12'), findsOneWidget);
    expect(
      find.text('Não foi possível conectar. Verifique sua internet.'),
      findsOneWidget,
    );
  });

  group('a series entry', () {
    final seriesRent = rent.copyWith(seriesId: 'series-1', seriesPosition: 2);

    setUp(
      () =>
          when(() => repository.month(any()))
              .thenAnswer((_) async => [salary, seriesRent]),
    );

    testWidgets('asks which entries to edit before opening the form', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Aluguel apto 12'));
      await tester.pumpAndSettle();
      expect(find.text('Editar receita da série'), findsOneWidget);
      expect(
        find.text('Quais lançamentos de "Aluguel apto 12"?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Este e os seguintes'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          routeMarker(
            AppRoutes.entryForm(EntryKind.income),
            EntryEdit(entry: seriesRent, scope: EntryScope.following),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('stays on the list when the question is cancelled', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Aluguel apto 12'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Aluguel apto 12'), findsOneWidget);
      expect(find.textContaining('route:'), findsNothing);
    });

    testWidgets('deletes the whole series', (tester) async {
      when(() => repository.delete(seriesRent.id, scope: EntryScope.all))
          .thenAnswer((_) async {});
      await pump(tester);

      when(() => repository.month(any())).thenAnswer((_) async => [salary]);
      await swipe(tester, 'Aluguel apto 12');
      expect(find.text('Apagar receita da série'), findsOneWidget);
      await tester.tap(find.text('Todos da série'));
      await tester.pumpAndSettle();

      verify(() => repository.delete(seriesRent.id, scope: EntryScope.all))
          .called(1);
      expect(find.text('Aluguel apto 12'), findsNothing);
    });

    testWidgets('keeps the series when the question is cancelled', (
      tester,
    ) async {
      await pump(tester);

      await swipe(tester, 'Aluguel apto 12');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      verifyNever(() => repository.delete(any(), scope: any(named: 'scope')));
      expect(find.text('Aluguel apto 12'), findsOneWidget);
    });
  });

  group('the paid checkbox', () {
    Finder checkboxOf(String description) => find.descendant(
      of: find.ancestor(
        of: find.text(description),
        matching: find.byType(ListTile),
      ),
      matching: find.byType(Checkbox),
    );

    testWidgets('marks an entry as received', (tester) async {
      when(() => repository.markPaid(rent.id, paidOn: any(named: 'paidOn')))
          .thenAnswer(
            (_) async => rent.copyWith(
              status: EntryStatus.paid,
              paidOn: DateTime(2026, 11, 10),
            ),
          );
      await pump(tester);

      expect(
        tester.widget<Checkbox>(checkboxOf('Aluguel apto 12')).value,
        isFalse,
      );
      expect(find.bySemanticsLabel('Marcar como recebida'), findsNWidgets(2));
      await tester.tap(checkboxOf('Aluguel apto 12'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Checkbox>(checkboxOf('Aluguel apto 12')).value,
        isTrue,
      );
      expect(
        find.text('Aluguel recebido · 10/11/2026 · Recebida'),
        findsOneWidget,
      );
    });

    testWidgets('unmarks a received entry', (tester) async {
      when(
        () => repository.markPaid(salary.id, paidOn: null),
      ).thenAnswer((_) async => salary.copyWith(status: EntryStatus.pending));
      await pump(tester);

      await tester.tap(checkboxOf('Salário ACME'));
      await tester.pumpAndSettle();

      verify(() => repository.markPaid(salary.id, paidOn: null)).called(1);
      expect(find.text('Salário · 05/11/2026 · A receber'), findsOneWidget);
    });

    testWidgets('shows the error of a failed change', (tester) async {
      when(() => repository.markPaid(any(), paidOn: any(named: 'paidOn')))
          .thenThrow(const ApiError(code: ApiError.networkErrorCode));
      await pump(tester);

      await tester.tap(checkboxOf('Aluguel apto 12'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Não foi possível conectar'), findsOneWidget);
    });
  });
}
