import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/portfolio_history_page.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/evolution_chart.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/investment_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;
  late MockInvestmentRepository repository;

  setUp(() {
    harness = AuthHarness();
    repository = MockInvestmentRepository();
    when(repository.history).thenAnswer((_) async => history);
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 6000);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPage(
      tester,
      BlocProvider(
        create: (_) =>
            started(PortfolioHistoryCubit(repository), (cubit) => cubit.load()),
        child: const PortfolioHistoryPage(),
      ),
      session: harness.session,
    );
  }

  testWidgets('draws every month and lists them newest first', (tester) async {
    await pump(tester);

    expect(find.byType(EvolutionChart), findsOneWidget);
    expect(find.text('nov. de 2026'), findsOneWidget);
    expect(find.text(r'R$ 1.400,00'), findsOneWidget);
    expect(find.text(r'R$ 1.470,00'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('nov. de 2026')).dy,
      lessThan(tester.getTopLeft(find.text('out. de 2025')).dy),
    );
  });

  testWidgets('says when there is no history yet', (tester) async {
    when(repository.history).thenAnswer((_) async => []);
    await pump(tester);

    expect(find.text('Sem evolução ainda'), findsOneWidget);
  });

  testWidgets('retries a failed load', (tester) async {
    when(repository.history).thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    when(repository.history).thenAnswer((_) async => history);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.byType(EvolutionChart), findsOneWidget);
  });
}
