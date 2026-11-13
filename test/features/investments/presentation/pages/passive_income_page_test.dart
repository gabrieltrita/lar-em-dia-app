import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/passive_income_page.dart';
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
    when(repository.income).thenAnswer((_) async => passiveIncome);
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPage(
      tester,
      BlocProvider(
        create: (_) =>
            started(PassiveIncomeCubit(repository), (cubit) => cubit.load()),
        child: const PassiveIncomePage(),
      ),
      session: harness.session,
    );
  }

  testWidgets('shows the average, the months and each asset', (tester) async {
    await pump(tester);

    expect(find.text(r'R$ 12,50'), findsOneWidget);
    expect(
      find.text(r'R$ 150,00 recebidos nos últimos 12 meses'),
      findsOneWidget,
    );
    expect(find.text('out. de 2026'), findsOneWidget);
    expect(find.text('dez. de 2026'), findsOneWidget);
    expect(find.text(r'Previsão mensal: R$ 11,67'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
  });

  testWidgets('explains where the income comes from when empty', (
    tester,
  ) async {
    when(repository.income).thenAnswer((_) async => noIncome);
    await pump(tester);

    expect(find.text('Sem proventos ainda'), findsOneWidget);
  });

  testWidgets('retries a failed load', (tester) async {
    when(repository.income).thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    when(repository.income).thenAnswer((_) async => passiveIncome);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('Por ativo'), findsOneWidget);
  });
}
