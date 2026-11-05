import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/cubits/entry_cubits.dart';
import 'package:lar_em_dia/features/entries/presentation/pages/entry_form_page.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_label.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/nature_label.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/finance_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late MockEntryRepository repository;
  late List<Object?> popped;

  setUpAll(registerFinanceFallbacks);
  setUp(() {
    repository = MockEntryRepository();
    popped = [];
    when(() => repository.categories(EntryKind.income))
        .thenAnswer((_) async => [salaryCategory, rentCategory]);
    when(() => repository.categories(EntryKind.expense))
        .thenAnswer((_) async => [housingCategory, groceriesCategory]);
  });

  Future<void> pump(
    WidgetTester tester, {
    Entry? existing,
    EntryScope scope = EntryScope.one,
    EntryKind kind = EntryKind.income,
    bool simulation = false,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => TextButton(
            onPressed: () async =>
                popped.add(await context.push<Object>('/form')),
            child: const Text('open'),
          ),
        ),
        GoRoute(
          path: '/form',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => EntryFormCubit(repository)),
              BlocProvider(
                create: (_) => started(
                  CategoriesCubit(repository),
                  (cubit) => cubit.load(kind),
                ),
              ),
            ],
            child: EntryFormPage(
              kind: kind,
              existing: existing,
              scope: scope,
              today: DateTime(2026, 11, 3),
              simulation: simulation,
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.resetPhysicalSize);
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

  final save = find.text('Salvar');

  Future<void> fillIn(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('entry_category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salário').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('entry_description')),
      ' Salário ACME ',
    );
    await tester.enterText(find.byKey(const Key('entry_amount')), '500000');
  }

  testWidgets('validates the fields', (tester) async {
    await pump(tester);

    await tester.enterText(find.byKey(const Key('entry_amount')), '0');
    await tester.tap(save);
    await tester.pump();

    expect(find.text('Campo obrigatório'), findsNWidgets(2));
    expect(find.text('Informe um valor maior que zero'), findsOneWidget);
    verifyNever(() => repository.create(any()));
  });

  testWidgets('returns a plan instead of saving in a simulation', (
    tester,
  ) async {
    await pump(tester, simulation: true);

    expect(find.text('Simular receita'), findsOneWidget);
    expect(find.byKey(const Key('entry_settled')), findsNothing);
    await fillIn(tester);
    await tester.tap(find.byKey(const Key('entry_repeat')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar à simulação'));
    await tester.pumpAndSettle();

    expect(popped, [
      EntryPlan(
        kind: EntryKind.income,
        draft: EntryDraft(
          categoryId: salaryCategory.id,
          description: 'Salário ACME',
          amountCents: 500000,
          dueOn: DateTime(2026, 11, 3),
          status: EntryStatus.pending,
        ),
        recurrence: const Recurrence(
          count: Recurrence.defaultCount,
          direction: RecurrenceDirection.forward,
        ),
      ),
    ]);
    verifyNever(() => repository.create(any()));
  });

  testWidgets('creates a pending income for today and closes', (tester) async {
    when(() => repository.create(any())).thenAnswer((_) async => salary);
    await pump(tester);

    await fillIn(tester);
    expect(find.text('5.000,00'), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();

    verify(
      () => repository.create(
        EntryDraft(
          categoryId: salaryCategory.id,
          description: 'Salário ACME',
          amountCents: 500000,
          dueOn: DateTime(2026, 11, 3),
          status: EntryStatus.pending,
        ),
      ),
    ).called(1);
    expect(popped, [true]);
  });

  testWidgets('creates a series in the chosen direction', (tester) async {
    when(
      () => repository.createSeries(any(), any()),
    ).thenAnswer((_) async => [salary.copyWith(dueOn: DateTime(2026, 11, 3))]);
    await pump(tester);

    await fillIn(tester);
    expect(find.byKey(const Key('entry_repeat_count')), findsNothing);
    await tester.tap(find.byKey(const Key('entry_repeat')));
    await tester.pumpAndSettle();
    expect(find.text('12 meses'), findsOneWidget);
    await tester.tap(find.byKey(const Key('entry_repeat_count')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6 meses').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meses anteriores'));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    verify(
      () => repository.createSeries(
        any(),
        const Recurrence(count: 6, direction: RecurrenceDirection.backward),
      ),
    ).called(1);
    verifyNever(() => repository.create(any()));
    expect(popped, [true]);
  });

  testWidgets('offers installments only on expenses', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('entry_installments')), findsNothing);
  });

  testWidgets('names the repetition fields in API errors', (tester) async {
    when(() => repository.createSeries(any(), any())).thenThrow(
      const ApiError(
        code: 'validation_failed',
        details: {
          'entries_count': [FieldError(code: 'less_than_or_equal_to')],
          'direction': [FieldError(code: 'inclusion')],
        },
      ),
    );
    await pump(tester);

    await fillIn(tester);
    await tester.tap(find.byKey(const Key('entry_repeat')));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      find.text('Quantidade de meses, contando este: Valor inválido'),
      findsOneWidget,
    );
    expect(find.text('Repetir nos: Valor inválido'), findsOneWidget);
  });

  testWidgets('edits an entry as received on another date', (tester) async {
    when(() => repository.update(rent.id, any())).thenAnswer((_) async => rent);
    await pump(tester, existing: rent);
    expect(find.text('Editar receita'), findsOneWidget);
    expect(find.byKey(const Key('entry_repeat')), findsNothing);
    expect(find.text('Aluguel recebido'), findsOneWidget);

    await tester.tap(find.byKey(const Key('entry_due_on')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('entry_settled')));
    await tester.tap(save);
    await tester.pumpAndSettle();

    verify(
      () => repository.update(
        rent.id,
        rent.toDraft().copyWith(
          dueOn: DateTime(2026, 11, 20),
          status: EntryStatus.paid,
        ),
      ),
    ).called(1);
    expect(popped, [true]);
  });

  group('expenses', () {
    Future<void> pickCategory(WidgetTester tester, String label) async {
      await tester.tap(find.byKey(const Key('entry_category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    bool selected(WidgetTester tester, EntryNature nature) => tester
        .widget<SegmentedButton<EntryNature>>(
          find.byKey(const Key('entry_nature')),
        )
        .selected
        .contains(nature);

    testWidgets('takes the nature from the category and allows changing it', (
      tester,
    ) async {
      when(() => repository.create(any())).thenAnswer((_) async => groceries);
      await pump(tester, kind: EntryKind.expense);
      expect(find.text('Nova despesa'), findsOneWidget);
      expect(find.text('Já paga'), findsOneWidget);

      await pickCategory(tester, 'Moradia');
      expect(selected(tester, EntryNature.fixed), isTrue);
      await pickCategory(tester, 'Mercado');
      expect(selected(tester, EntryNature.variable), isTrue);

      await tester.tap(find.text('Fixa'));
      await tester.pump();
      await tester.tap(find.text('Fixa'));
      await tester.pump();
      expect(selected(tester, EntryNature.fixed), isTrue);

      await tester.enterText(
        find.byKey(const Key('entry_description')),
        'Feira',
      );
      await tester.enterText(find.byKey(const Key('entry_amount')), '12000');
      await tester.tap(save);
      await tester.pumpAndSettle();

      verify(
        () => repository.create(
          EntryDraft(
            categoryId: groceriesCategory.id,
            description: 'Feira',
            amountCents: 12000,
            dueOn: DateTime(2026, 11, 3),
            status: EntryStatus.pending,
            nature: EntryNature.fixed,
          ),
        ),
      ).called(1);
    });

    testWidgets('keeps the nature of an existing expense', (tester) async {
      when(() => repository.update(housing.id, any()))
          .thenAnswer((_) async => housing);
      await pump(tester, kind: EntryKind.expense, existing: housing);
      expect(find.text('Editar despesa'), findsOneWidget);
      expect(selected(tester, EntryNature.fixed), isTrue);

      await tester.tap(save);
      await tester.pumpAndSettle();

      verify(() => repository.update(housing.id, housing.toDraft())).called(1);
    });

    testWidgets('creates installments from the total', (tester) async {
      when(() => repository.createInstallments(any(), any())).thenAnswer(
        (_) async => [groceries.copyWith(dueOn: DateTime(2026, 11, 3))],
      );
      await pump(tester, kind: EntryKind.expense);

      await pickCategory(tester, 'Mercado');
      await tester.enterText(
        find.byKey(const Key('entry_description')),
        'Sofá',
      );
      await tester.enterText(find.byKey(const Key('entry_amount')), '120000');
      await tester.tap(find.byKey(const Key('entry_repeat')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('entry_installments')));
      await tester.tap(find.byKey(const Key('entry_installments')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('entry_repeat_count')), findsNothing);
      expect(find.text('Valor total'), findsOneWidget);
      expect(find.text(r'10x de R$ 120,00'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('entry_amount')), '101');
      await tester.pump();
      expect(find.text(r'1ª de R$ 0,11 e 9x de R$ 0,10'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('entry_amount')), '9');
      await tester.pump();
      expect(find.byKey(const Key('entry_installments_preview')), findsNothing);

      await tester.enterText(find.byKey(const Key('entry_amount')), '120000');
      await tester.ensureVisible(
        find.byKey(const Key('entry_installments_count')),
      );
      await tester.tap(find.byKey(const Key('entry_installments_count')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3x').last);
      await tester.pumpAndSettle();
      expect(find.text(r'3x de R$ 400,00'), findsOneWidget);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      verify(
        () => repository.createInstallments(
          EntryDraft(
            categoryId: groceriesCategory.id,
            description: 'Sofá',
            amountCents: 120000,
            dueOn: DateTime(2026, 11, 3),
            status: EntryStatus.pending,
            nature: EntryNature.variable,
          ),
          const Installments(count: 3),
        ),
      ).called(1);
      verifyNever(() => repository.createSeries(any(), any()));
    });

    testWidgets('turns installments off when repeating', (tester) async {
      await pump(tester, kind: EntryKind.expense);

      await tester.tap(find.byKey(const Key('entry_installments')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('entry_repeat')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('entry_installments_count')), findsNothing);
      expect(find.byKey(const Key('entry_repeat_count')), findsOneWidget);
      expect(find.text('Valor'), findsOneWidget);
    });

    testWidgets('names the installment fields in API errors', (tester) async {
      when(() => repository.createInstallments(any(), any())).thenThrow(
        const ApiError(
          code: 'validation_failed',
          details: {
            'total_cents': [FieldError(code: 'greater_than_or_equal_to')],
            'kind': [FieldError(code: 'only_for_expenses')],
          },
        ),
      );
      await pump(tester, kind: EntryKind.expense);

      await pickCategory(tester, 'Mercado');
      await tester.enterText(
        find.byKey(const Key('entry_description')),
        'Sofá',
      );
      await tester.enterText(find.byKey(const Key('entry_amount')), '120000');
      await tester.tap(find.byKey(const Key('entry_installments')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.textContaining('Valor total: '), findsOneWidget);
      expect(find.textContaining('Compra parcelada: '), findsOneWidget);
    });

    testWidgets('names the nature in API errors', (tester) async {
      when(() => repository.create(any())).thenThrow(
        const ApiError(
          code: 'validation_failed',
          details: {
            'nature': [FieldError(code: 'inclusion')],
          },
        ),
      );
      await pump(tester, kind: EntryKind.expense);

      await pickCategory(tester, 'Mercado');
      await tester.enterText(
        find.byKey(const Key('entry_description')),
        'Feira',
      );
      await tester.enterText(find.byKey(const Key('entry_amount')), '12000');
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('Tipo de despesa: Valor inválido'), findsOneWidget);
    });
  });

  testWidgets('lists the API field errors', (tester) async {
    when(() => repository.create(any())).thenThrow(
      const ApiError(
        code: 'validation_failed',
        details: {
          'category': [FieldError(code: 'inactive')],
        },
      ),
    );
    await pump(tester);

    await fillIn(tester);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      find.text('Tipo de receita: Esta opção não está mais disponível'),
      findsOneWidget,
    );
    expect(popped, isEmpty);
  });

  testWidgets('explains an empty category list', (tester) async {
    when(() => repository.categories(EntryKind.income))
        .thenAnswer((_) async => []);
    await pump(tester);

    expect(
      find.text(
        'Nenhuma categoria disponível agora. Tente de novo mais tarde.',
      ),
      findsOneWidget,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(popped, isEmpty);
  });

  testWidgets('retries loading the categories', (tester) async {
    when(() => repository.categories(EntryKind.income))
        .thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    when(() => repository.categories(EntryKind.income))
        .thenAnswer((_) async => [salaryCategory]);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('entry_category')), findsOneWidget);
  });

  test('labels every default category in Portuguese', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
    const keys = [
      'housing',
      'utilities',
      'internet_phone',
      'subscriptions',
      'education',
      'insurance',
      'health_plan',
      'loans',
      'groceries',
      'restaurants',
      'transport',
      'health',
      'leisure',
      'travel',
      'clothing',
      'personal_care',
      'pets',
      'gifts_donations',
      'taxes_fees',
      'other_expense',
      'salary',
      'thirteenth_salary',
      'vacation_bonus',
      'bonus',
      'extra_income',
      'rent_received',
      'alimony_received',
      'tax_refund',
      'reimbursement',
      'other_income',
    ];
    String label(String key) => categoryLabel(
      l10n,
      Category(id: key, kind: EntryKind.income, key: key, name: key),
    );

    expect(keys.map(label).toSet(), hasLength(keys.length));
    expect(keys.where((key) => label(key) == key), isEmpty);
    expect(label('custom'), 'custom');
    expect(categoryLabel(l10n, null), '');
    expect(EntryNature.values.map((n) => natureLabel(l10n, n)), [
      'Fixa',
      'Variável',
    ]);
  });

  group('a series entry', () {
    final sofa = housing.copyWith(
      description: 'Sofá',
      amountCents: 50000,
      seriesId: 'series-1',
      seriesPosition: 3,
      seriesKind: SeriesKind.installments,
      seriesCount: 10,
    );

    testWidgets('locks the installment amount and the payment outside one', (
      tester,
    ) async {
      when(() => repository.update(sofa.id, any(), scope: EntryScope.following))
          .thenAnswer((_) async => sofa);
      await pump(
        tester,
        existing: sofa,
        scope: EntryScope.following,
        kind: EntryKind.expense,
      );

      expect(
        find.text(
          'As alterações valem para este lançamento e os seguintes da série.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('só muda em "Só este"'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('entry_amount')),
                matching: find.byType(TextField),
              ),
            )
            .enabled,
        isFalse,
      );
      expect(find.byKey(const Key('entry_settled')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('entry_description')),
        'Sofá novo',
      );
      await tester.tap(save);
      await tester.pumpAndSettle();

      verify(
        () => repository.update(
          sofa.id,
          sofa.toDraft().copyWith(description: 'Sofá novo'),
          scope: EntryScope.following,
        ),
      ).called(1);
      expect(popped, [true]);
    });

    testWidgets('keeps a recurring amount editable for the whole series', (
      tester,
    ) async {
      await pump(
        tester,
        existing: rent.copyWith(seriesId: 'series-2', seriesPosition: 1),
        scope: EntryScope.all,
      );

      expect(
        find.text('As alterações valem para todos os lançamentos da série.'),
        findsOneWidget,
      );
      expect(find.textContaining('só muda em "Só este"'), findsNothing);
    });

    testWidgets('shows the API refusal of a payment change', (tester) async {
      when(() => repository.update(any(), any(), scope: EntryScope.all))
          .thenThrow(const ApiError(code: 'only_for_single_entry'));
      await pump(
        tester,
        existing: rent.copyWith(seriesId: 'series-2', seriesPosition: 1),
        scope: EntryScope.all,
      );

      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        find.text('O pagamento só pode ser alterado em um lançamento por vez.'),
        findsOneWidget,
      );
    });
  });
}
