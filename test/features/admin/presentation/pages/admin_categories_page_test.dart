import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/admin/presentation/cubits/admin_cubits.dart';
import 'package:lar_em_dia/features/admin/presentation/pages/admin_categories_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;
  late MockAdminRepository repository;

  setUp(() {
    harness = AuthHarness()..session.signedIn(rafaelAdmin);
    repository = MockAdminRepository();
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester) => pumpPage(
    tester,
    BlocProvider(
      create: (_) =>
          started(AdminCategoriesCubit(repository), (cubit) => cubit.load()),
      child: const AdminCategoriesPage(),
    ),
    session: harness.session,
  );

  testWidgets('lists the categories by kind with their key and state', (
    tester,
  ) async {
    when(repository.categories)
        .thenAnswer((_) async => [adminSalary, adminPets]);
    await pump(tester);

    expect(find.text('Receitas'), findsOneWidget);
    expect(find.text('Despesas'), findsOneWidget);
    expect(find.text('Salário'), findsOneWidget);
    expect(find.text('salary · posição 0'), findsOneWidget);
    expect(find.text('Pets'), findsOneWidget);
    expect(find.text('pets · posição 16'), findsOneWidget);
    expect(find.text('Inativa'), findsOneWidget);
  });

  testWidgets('hides a kind without categories', (tester) async {
    when(repository.categories).thenAnswer((_) async => [adminPets]);
    await pump(tester);

    expect(find.text('Receitas'), findsNothing);
    expect(find.text('Despesas'), findsOneWidget);
  });

  testWidgets('says when there are no categories', (tester) async {
    when(repository.categories).thenAnswer((_) async => []);
    await pump(tester);

    expect(find.text('Nenhuma categoria cadastrada.'), findsOneWidget);
  });

  testWidgets('retries a failed load', (tester) async {
    when(repository.categories)
        .thenThrow(const ApiError(code: 'two_factor_setup_required'));
    await pump(tester);

    expect(find.textContaining('verificação em duas etapas'), findsOneWidget);

    when(repository.categories).thenAnswer((_) async => [adminSalary]);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Salário'), findsOneWidget);
  });

  testWidgets('opens a category and reloads after saving', (tester) async {
    when(repository.categories).thenAnswer((_) async => [adminPets]);
    await pump(tester);

    await tester.tap(find.text('Pets'));
    await tester.pumpAndSettle();

    expect(
      find.text(routeMarker(AppRoutes.adminCategoryForm, adminPets)),
      findsOneWidget,
    );

    await tester.tap(find.text(savedAndBack));
    await tester.pumpAndSettle();

    verify(repository.categories).called(2);
  });

  testWidgets('opens the new category form and keeps the list when closed', (
    tester,
  ) async {
    when(repository.categories).thenAnswer((_) async => [adminPets]);
    await pump(tester);

    await tester.tap(find.byTooltip('Nova categoria'));
    await tester.pumpAndSettle();

    expect(find.text(routeMarker(AppRoutes.adminCategoryForm)), findsOneWidget);

    await tester.tap(find.text(closedAndBack));
    await tester.pumpAndSettle();

    verify(repository.categories).called(1);
  });
}
