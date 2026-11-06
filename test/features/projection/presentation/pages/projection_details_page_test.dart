import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/pages/projection_details_page.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/monthly_result_chart.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/waterfall_chart.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/finance_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;

  setUp(() => harness = AuthHarness());
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester, Projection value) async {
    tester.view.physicalSize = const Size(1200, 6000);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPage(
      tester,
      ProjectionDetailsPage(projection: value),
      session: harness.session,
    );
  }

  testWidgets('explains the period with charts', (tester) async {
    await pump(tester, projection);

    expect(find.text('Sua economia'), findsOneWidget);
    expect(find.text('Até dezembro de 2026 você vai perder'), findsOneWidget);
    expect(find.text('Ver mais ›'), findsNothing);

    final waterfall = tester.widget<WaterfallChart>(
      find.byType(WaterfallChart),
    );
    expect(
      [for (final step in waterfall.steps) step.toCents],
      [123456, 773456, 373456, -106544, -106544],
    );
    expect(find.byType(MonthlyResultChart), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Como chegamos aqui')), findsOneWidget);

    expect(find.text('45%'), findsOneWidget);
    expect(find.text(r'R$ 2.000,00/mês'), findsOneWidget);
    expect(find.text(r'R$ 2.400,00/mês'), findsOneWidget);
    expect(find.text(r'R$ 8.800,00'), findsOneWidget);
  });

  testWidgets('ranks the categories that weigh the most', (tester) async {
    await pump(tester, projection);

    expect(ProjectionDetailsPage.categoryTotals(projection.months).keys, [
      'housing',
      'travel',
      'groceries',
      'pet_insurance',
    ]);
    expect(find.text('Moradia'), findsOneWidget);
    expect(find.text(Money.compact(400000)), findsOneWidget);
    expect(find.text('pet_insurance'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
  });

  testWidgets('shows the months that spend more than they earn', (
    tester,
  ) async {
    await pump(tester, projection);

    expect(find.text('dezembro de 2026'), findsOneWidget);
    expect(find.text('novembro de 2026'), findsNothing);
    expect(
      find.text(r'Pesaram: Viagens R$ 3.200,00 · Moradia R$ 2.000,00'),
      findsOneWidget,
    );
  });

  testWidgets('handles a period without expenses or negative months', (
    tester,
  ) async {
    final quiet = novemberProjection.copyWith(
      expenseCents: 0,
      fixedExpenseCents: 0,
      variableExpenseCents: 0,
      expenseByCategory: [],
    );
    await pump(tester, projection.copyWith(months: [quiet]));

    expect(find.text('Até novembro de 2026 você vai guardar'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('Nenhuma despesa neste período.'), findsOneWidget);
    expect(
      find.text('Nenhum mês gasta mais do que entra neste período.'),
      findsOneWidget,
    );
  });

  testWidgets('leaves out the reasons of a month without categories', (
    tester,
  ) async {
    await pump(
      tester,
      projection.copyWith(
        months: [decemberProjection.copyWith(expenseByCategory: [])],
      ),
    );

    expect(find.text('dezembro de 2026'), findsOneWidget);
    expect(find.textContaining('Pesaram'), findsNothing);
  });
}
