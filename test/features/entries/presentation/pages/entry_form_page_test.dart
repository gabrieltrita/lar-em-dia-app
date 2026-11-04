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
    EntryKind kind = EntryKind.income,
  }) async {
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
              today: DateTime(2026, 11, 3),
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
}
