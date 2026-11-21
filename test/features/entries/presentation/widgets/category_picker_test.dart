import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_picker.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

import '../../../../helpers/finance_fixtures.dart';

void main() {
  late List<Category> selections;
  late List<(String, EntryNature?)> created;
  late List<Category> deleted;
  late Future<Category> Function(String, EntryNature?) onCreate;
  late Future<void> Function(Category) onDelete;

  setUp(() {
    selections = [];
    created = [];
    deleted = [];
    onCreate = (name, nature) async {
      created.add((name, nature));
      return petCategory.copyWith(name: name);
    };
    onDelete = (category) async => deleted.add(category);
  });

  Future<void> pump(
    WidgetTester tester, {
    EntryKind kind = EntryKind.expense,
    List<Category> categories = const [
      housingCategory,
      groceriesCategory,
      petCategory,
    ],
    String? selected,
    String? errorText,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CategoryPickerField(
            kind: kind,
            categories: categories,
            selected: selected,
            label: 'Categoria',
            errorText: errorText,
            onSelected: selections.add,
            onCreate: (name, nature) => onCreate(name, nature),
            onDelete: (category) => onDelete(category),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('category_picker')));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a compact field with the hint or the selection', (
    tester,
  ) async {
    await pump(tester, errorText: 'Campo obrigatório');

    expect(find.text('Toque para escolher'), findsOneWidget);
    expect(find.text('Campo obrigatório'), findsOneWidget);
    expect(find.text('Moradia'), findsNothing);

    await pump(tester, selected: housingCategory.id);

    expect(find.text('Moradia'), findsOneWidget);
    expect(find.text('Mercado'), findsNothing);
  });

  testWidgets('lists the user categories apart and picks one', (tester) async {
    await pump(tester, selected: housingCategory.id);
    await open(tester);

    expect(find.text('Minhas categorias'), findsOneWidget);
    expect(find.text('Categorias do app'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await pump(tester, selected: petCategory.id);
    await open(tester);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(
      find.byKey(ValueKey('category_delete_${petCategory.key}')),
      findsOneWidget,
    );

    await tester.tap(find.text('Mercado'));
    await tester.pumpAndSettle();

    expect(selections, [groceriesCategory]);
    expect(find.byType(CategoryPickerSheet), findsNothing);
  });

  testWidgets('closes without a selection', (tester) async {
    await pump(tester);
    await open(tester);

    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    expect(selections, isEmpty);
  });

  testWidgets('searches ignoring case and accents', (tester) async {
    await pump(tester, categories: [housingCategory, salaryCategory]);
    await open(tester);

    await tester.enterText(find.byKey(const Key('category_search')), 'SALA');
    await tester.pump();
    expect(find.text('Salário'), findsOneWidget);
    expect(find.text('Moradia'), findsNothing);
    expect(find.text('Minhas categorias'), findsNothing);
    expect(find.text('Categorias do app'), findsNothing);

    await tester.enterText(find.byKey(const Key('category_search')), 'xyz');
    await tester.pump();
    expect(find.text('Nenhuma categoria com esse nome'), findsOneWidget);
  });

  testWidgets('creates an expense category with the searched name', (
    tester,
  ) async {
    await pump(tester);
    await open(tester);
    await tester.enterText(find.byKey(const Key('category_search')), 'gato');
    await tester.pump();

    await tester.tap(find.byKey(const Key('category_create')));
    await tester.pumpAndSettle();

    expect(find.text('Nova categoria de despesa'), findsOneWidget);
    expect(find.text('Gato'), findsOneWidget);
    await tester.tap(find.text('Fixa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category_create_submit')));
    await tester.pumpAndSettle();

    expect(created, [('Gato', EntryNature.fixed)]);
    expect(selections.single.name, 'Gato');
    expect(find.byType(CategoryPickerSheet), findsNothing);
  });

  testWidgets('creates an income category without a nature', (tester) async {
    await pump(tester, kind: EntryKind.income, categories: [salaryCategory]);
    await open(tester);
    await tester.tap(find.byKey(const Key('category_create')));
    await tester.pumpAndSettle();

    expect(find.text('Novo tipo de receita'), findsOneWidget);
    expect(find.byKey(const Key('category_create_nature')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('category_create_name')),
      'freela',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(created, [('Freela', null)]);
  });

  testWidgets('requires a name and can be cancelled', (tester) async {
    await pump(tester);
    await open(tester);
    await tester.tap(find.byKey(const Key('category_create')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('category_create_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Campo obrigatório'), findsOneWidget);
    expect(created, isEmpty);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(NewCategoryDialog), findsNothing);
    expect(find.byType(CategoryPickerSheet), findsOneWidget);
    expect(selections, isEmpty);
  });

  testWidgets('shows the API errors when creating fails', (tester) async {
    final completer = Completer<Category>();
    onCreate = (_, _) => completer.future;
    await pump(tester);
    await open(tester);
    await tester.tap(find.byKey(const Key('category_create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('category_create_name')),
      'Pet',
    );

    await tester.tap(find.byKey(const Key('category_create_submit')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.completeError(
      const ApiError(
        code: 'validation_failed',
        details: {
          'name': [FieldError(code: 'too_long', message: 'is too long')],
          'base': [
            FieldError(code: 'too_many_categories', message: 'at most 50'),
          ],
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nome: Texto muito longo'), findsOneWidget);
    expect(
      find.text('Você chegou ao limite de 50 categorias próprias'),
      findsOneWidget,
    );
    expect(selections, isEmpty);
  });

  testWidgets('deletes a user category after confirming', (tester) async {
    await pump(tester);
    await open(tester);
    final delete = find.byKey(ValueKey('category_delete_${petCategory.key}'));

    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('Apagar categoria?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(deleted, isEmpty);

    await tester.tap(delete);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category_delete_confirm')));
    await tester.pumpAndSettle();

    expect(deleted, [petCategory]);
    expect(find.text('Pet'), findsNothing);
    expect(find.text('Minhas categorias'), findsNothing);
  });

  testWidgets('explains why a category in use cannot be deleted', (
    tester,
  ) async {
    onDelete = (_) async =>
        throw const ApiError(code: 'category_in_use', message: 'in use');
    await pump(tester);
    await open(tester);

    await tester.tap(
      find.byKey(ValueKey('category_delete_${petCategory.key}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('category_delete_confirm')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Esta categoria tem lançamentos. Mude a categoria deles ou apague-os '
        'antes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Pet'), findsOneWidget);
  });
}
