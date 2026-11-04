import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/cubits/entry_cubits.dart';
import 'package:lar_em_dia/features/entries/presentation/pages/entries_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/finance_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;
  late MockEntryRepository repository;

  setUpAll(registerFinanceFallbacks);
  setUp(() {
    harness = AuthHarness();
    repository = MockEntryRepository();
    when(() => repository.categories(EntryKind.income))
        .thenAnswer((_) async => [salaryCategory, rentCategory]);
    when(() => repository.month(any(), kind: EntryKind.income))
        .thenAnswer((_) async => [salary, rent]);
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester, {EntryKind kind = EntryKind.income}) =>
      pumpPage(
        tester,
        BlocProvider(
          create: (_) => started(
            MonthEntriesCubit(repository, kind),
            (cubit) => cubit.load(november),
          ),
          child: const EntriesPage(),
        ),
        session: harness.session,
      );

  testWidgets('lists the month with its total', (tester) async {
    await pump(tester);

    expect(find.text('novembro de 2026'), findsOneWidget);
    expect(find.text(r'Total do mês: R$ 6.500,00'), findsOneWidget);
    expect(find.text('Salário ACME'), findsOneWidget);
    expect(find.text('Salário · 05/11/2026 · Recebida'), findsOneWidget);
    expect(
      find.text('Aluguel recebido · 10/11/2026 · A receber'),
      findsOneWidget,
    );
  });

  testWidgets('marks the entries of a series', (tester) async {
    when(() => repository.month(any(), kind: EntryKind.income)).thenAnswer(
      (_) async => [salary.copyWith(seriesId: 'series-1', seriesPosition: 1)],
    );
    await pump(tester);

    expect(find.byIcon(Icons.repeat), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Lançamento repetido')),
      findsOneWidget,
    );
  });

  group('expenses', () {
    setUp(() {
      when(() => repository.categories(EntryKind.expense))
          .thenAnswer((_) async => [housingCategory, groceriesCategory]);
      when(() => repository.month(any(), kind: EntryKind.expense))
          .thenAnswer((_) async => [housing, groceries]);
    });

    testWidgets('lists expenses with fixed and variable subtotals', (
      tester,
    ) async {
      await pump(tester, kind: EntryKind.expense);

      expect(find.text('Despesas'), findsOneWidget);
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
      when(() => repository.month(any(), kind: EntryKind.expense))
          .thenAnswer((_) async => [groceries]);
      await pump(tester, kind: EntryKind.expense);

      await tester.tap(find.text('Fixas'));
      await tester.pumpAndSettle();

      expect(
        find.text('Nenhuma despesa deste tipo neste mês.'),
        findsOneWidget,
      );
    });

    testWidgets('opens the expense form', (tester) async {
      await pump(tester, kind: EntryKind.expense);

      await tester.tap(find.byTooltip('Nova despesa'));
      await tester.pumpAndSettle();

      expect(find.text(routeMarker(AppRoutes.expensesForm)), findsOneWidget);
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
    when(() => repository.month(any(), kind: EntryKind.income))
        .thenAnswer((_) async => []);
    await pump(tester);

    expect(find.text('Nenhuma receita neste mês.'), findsOneWidget);
  });

  testWidgets('retries a failed load', (tester) async {
    when(() => repository.month(any(), kind: EntryKind.income))
        .thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    when(() => repository.month(any(), kind: EntryKind.income))
        .thenAnswer((_) async => [salary]);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Salário ACME'), findsOneWidget);
  });

  testWidgets('opens an entry and reloads after saving', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Salário ACME'));
    await tester.pumpAndSettle();
    expect(
      find.text(routeMarker(AppRoutes.incomeForm, salary)),
      findsOneWidget,
    );
    await tester.tap(find.text(savedAndBack));
    await tester.pumpAndSettle();

    verify(() => repository.month(november, kind: EntryKind.income)).called(2);
  });

  testWidgets('does not reload when the form is closed', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Nova receita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();

    verify(() => repository.month(november, kind: EntryKind.income)).called(1);
  });

  Future<void> swipe(WidgetTester tester, String description) async {
    await tester.drag(find.text(description), const Offset(-600, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('swipes to delete after confirmation', (tester) async {
    when(() => repository.delete('entry-2')).thenAnswer((_) async {});
    await pump(tester);

    when(() => repository.month(any(), kind: EntryKind.income))
        .thenAnswer((_) async => [salary]);
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
}
