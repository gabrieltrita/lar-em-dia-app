import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/cubits/entry_cubits.dart';
import 'package:lar_em_dia/features/entries/presentation/pages/due_page.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/finance_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;
  late MockEntryRepository repository;
  late FinanceChanges changes;
  late int notified;

  final today = DateTime(2026, 11, 9);
  final overdue = housing.copyWith(
    id: 'late',
    description: 'Condomínio',
    dueOn: DateTime(2026, 11, 7),
  );
  final tomorrow = groceries.copyWith(
    id: 'tomorrow',
    status: EntryStatus.pending,
    paidOn: null,
    dueOn: DateTime(2026, 11, 10),
  );
  final todayBill = tomorrow.copyWith(
    id: 'today',
    description: 'Farmácia',
    dueOn: today,
  );
  final later = housing.copyWith(
    id: 'later',
    description: 'Luz',
    dueOn: DateTime(2026, 11, 25),
  );

  setUpAll(registerFinanceFallbacks);
  setUp(() {
    harness = AuthHarness();
    repository = MockEntryRepository();
    notified = 0;
    changes = FinanceChanges(FinanceCache())..addListener(() => notified++);
    when(() => repository.categories(EntryKind.expense))
        .thenAnswer((_) async => [housingCategory, groceriesCategory]);
    when(() => repository.between(any(), any(), kind: EntryKind.expense))
        .thenAnswer((_) async => [overdue, todayBill, tomorrow, later]);
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 4000);
    addTearDown(tester.view.resetPhysicalSize);
    return pumpPage(
      tester,
      BlocProvider(
        create: (_) =>
            started(DueCubit(repository), (cubit) => cubit.load(today: today)),
        child: const DuePage(),
      ),
      session: harness.session,
      changes: changes,
    );
  }

  testWidgets('groups the bills by when they are due', (tester) async {
    await pump(tester);

    expect(find.text('Vencimentos'), findsOneWidget);
    expect(find.text('ATRASADAS'), findsOneWidget);
    expect(find.text('Venceu em 07/11/2026'), findsOneWidget);
    expect(find.text('Condomínio'), findsOneWidget);
    expect(find.text('PRÓXIMOS 7 DIAS'), findsOneWidget);
    expect(find.text('Vence hoje'), findsOneWidget);
    expect(find.text('Vence amanhã'), findsOneWidget);
    expect(find.text('AINDA ESTE MÊS'), findsOneWidget);
    expect(find.text('Vence em 25/11/2026'), findsOneWidget);
    expect(find.text(r'R$ 1.600,00'), findsOneWidget);
  });

  testWidgets('marks a bill as paid with the checkbox', (tester) async {
    when(() => repository.markPaid('tomorrow', paidOn: any(named: 'paidOn')))
        .thenAnswer((_) async => tomorrow);
    await pump(tester);

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Mercado do mês'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mercado do mês'), findsNothing);
    expect(find.text('Mercado do mês marcada como paga.'), findsOneWidget);
    expect(notified, 1);
  });

  testWidgets('marks a bill as paid by swiping', (tester) async {
    when(() => repository.markPaid('later', paidOn: any(named: 'paidOn')))
        .thenAnswer((_) async => later);
    await pump(tester);

    await tester.drag(find.text('Luz'), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Luz'), findsNothing);
    expect(find.text('AINDA ESTE MÊS'), findsNothing);
  });

  testWidgets('keeps the bill when the payment fails', (tester) async {
    when(() => repository.markPaid(any(), paidOn: any(named: 'paidOn')))
        .thenThrow(const ApiError(code: ApiError.networkErrorCode));
    await pump(tester);

    await tester.drag(find.text('Luz'), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Luz'), findsOneWidget);
    expect(find.textContaining('Não foi possível conectar'), findsOneWidget);
    expect(notified, 0);
  });

  testWidgets('says when nothing is due', (tester) async {
    when(() => repository.between(any(), any(), kind: EntryKind.expense))
        .thenAnswer((_) async => [groceries]);
    await pump(tester);

    expect(find.text('Nenhuma conta a pagar'), findsOneWidget);
  });

  testWidgets('retries a failed load and reloads on pull', (tester) async {
    when(() => repository.between(any(), any(), kind: EntryKind.expense))
        .thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    when(() => repository.between(any(), any(), kind: EntryKind.expense))
        .thenAnswer((_) async => [later]);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('Luz'), findsOneWidget);

    await tester.fling(find.byType(ListView), const Offset(0, 3000), 1000);
    await tester.pumpAndSettle();
    verify(() => repository.between(any(), any(), kind: EntryKind.expense))
        .called(3);
  });
}
