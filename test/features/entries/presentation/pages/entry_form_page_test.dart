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
  });

  Future<void> pump(WidgetTester tester, {Entry? existing}) async {
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
                  (cubit) => cubit.load(EntryKind.income),
                ),
              ),
            ],
            child: EntryFormPage(
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

  testWidgets('edits an entry as received on another date', (tester) async {
    when(() => repository.update(rent.id, any())).thenAnswer((_) async => rent);
    await pump(tester, existing: rent);
    expect(find.text('Editar receita'), findsOneWidget);
    expect(find.text('Aluguel recebido'), findsOneWidget);

    await tester.tap(find.byKey(const Key('entry_due_on')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('entry_received')));
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

  test('labels every income category in Portuguese', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('pt'));
    const keys = [
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
  });
}
