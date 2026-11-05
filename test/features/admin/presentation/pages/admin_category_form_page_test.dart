import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/admin/domain/admin_category.dart';
import 'package:lar_em_dia/features/admin/presentation/cubits/admin_cubits.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_category_form_page.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/admin_fixtures.dart';

void main() {
  late MockAdminRepository repository;
  late List<Object?> popped;

  setUpAll(registerAdminFallbacks);
  setUp(() {
    repository = MockAdminRepository();
    popped = [];
  });

  Future<void> pump(WidgetTester tester, {AdminCategory? existing}) async {
    tester.view.physicalSize = const Size(1200, 3000);
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
          builder: (_, _) => BlocProvider(
            create: (_) => AdminCategoryFormCubit(repository),
            child: AdminCategoryFormPage(existing: existing),
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

  final key = find.byKey(const Key('category_key'));
  final name = find.byKey(const Key('category_name'));
  final position = find.byKey(const Key('category_position'));
  final save = find.text('Salvar');

  testWidgets('validates the key, the name and the position', (tester) async {
    await pump(tester);
    await tester.enterText(position, '');

    await tester.tap(save);
    await tester.pump();

    expect(find.text('Campo obrigatório'), findsNWidgets(2));
    expect(
      find.text('Informe um número inteiro a partir de 0'),
      findsOneWidget,
    );

    await tester.enterText(key, 'Pet Shop');
    await tester.tap(save);
    await tester.pump();

    expect(
      find.text('Use letras minúsculas, números e _, começando por uma letra'),
      findsOneWidget,
    );
    verifyNever(() => repository.createCategory(any()));
  });

  testWidgets('creates a fixed expense category and closes', (tester) async {
    const draft = CategoryDraft(
      kind: EntryKind.expense,
      key: 'condo_fee',
      name: 'Condo fee',
      position: 3,
      active: true,
      defaultNature: EntryNature.fixed,
    );
    when(() => repository.createCategory(draft))
        .thenAnswer((_) async => adminPets);
    await pump(tester);

    await tester.enterText(key, ' condo_fee ');
    await tester.enterText(name, 'Condo fee');
    await tester.enterText(position, '3');
    await tester.tap(find.text('Fixa'));
    await tester.tap(save);
    await tester.pumpAndSettle();

    verify(() => repository.createCategory(draft)).called(1);
    expect(popped, [true]);
  });

  testWidgets('creates an income category without a nature', (tester) async {
    const draft = CategoryDraft(
      kind: EntryKind.income,
      key: 'pension',
      name: 'Pension',
      position: 0,
      active: false,
    );
    when(() => repository.createCategory(draft))
        .thenAnswer((_) async => adminSalary);
    await pump(tester);

    await tester.tap(find.text('Receita'));
    await tester.pump();
    expect(find.text('Tipo de despesa'), findsNothing);

    await tester.enterText(key, 'pension');
    await tester.enterText(name, 'Pension');
    await tester.tap(find.text('Ativa'));
    await tester.tap(save);
    await tester.pumpAndSettle();

    verify(() => repository.createCategory(draft)).called(1);
  });

  testWidgets('edits a category without changing its kind and key', (
    tester,
  ) async {
    when(() => repository.updateCategory('cat-2', any()))
        .thenAnswer((_) async => adminPets);
    await pump(tester, existing: adminPets);

    expect(find.text('Editar categoria'), findsOneWidget);
    expect(key, findsNothing);
    expect(find.text('Receita'), findsNothing);

    await tester.enterText(name, 'Pet care');
    await tester.tap(save);
    await tester.pumpAndSettle();

    verify(
      () => repository.updateCategory(
        'cat-2',
        adminPets.toDraft().copyWith(name: 'Pet care'),
      ),
    ).called(1);
    expect(popped, [true]);
  });

  testWidgets('shows the field errors from the API', (tester) async {
    when(() => repository.createCategory(any())).thenThrow(
      const ApiError(
        code: 'validation_failed',
        details: {
          'key': [FieldError(code: 'taken', message: 'taken')],
          'name': [FieldError(code: 'too_long', message: 'too long')],
          'kind': [FieldError(code: 'immutable', message: 'immutable')],
        },
      ),
    );
    await pump(tester);

    await tester.enterText(key, 'pets');
    await tester.enterText(name, 'Pets');
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Confira os campos destacados.'), findsOneWidget);
    expect(find.text('Chave: Já está em uso'), findsOneWidget);
    expect(find.text('Nome: Texto muito longo'), findsOneWidget);
    expect(find.text('Tipo: Não pode ser alterado'), findsOneWidget);
    expect(popped, isEmpty);
  });
}
