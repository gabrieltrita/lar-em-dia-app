import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/cubits/projection_cubit.dart';
import 'package:lar_em_dia/features/projection/presentation/pages/projection_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/finance_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;
  late MockProjectionRepository repository;

  void answer(Projection Function() value) => when(
    () => repository.fetch(
      from: any(named: 'from'),
      months: any(named: 'months'),
    ),
  ).thenAnswer((_) async => value());

  setUpAll(registerFinanceFallbacks);
  setUp(() {
    harness = AuthHarness();
    repository = MockProjectionRepository();
    answer(() => projection);
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3600);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPage(
      tester,
      BlocProvider(
        create: (_) =>
            started(ProjectionCubit(repository), (cubit) => cubit.load()),
        child: const ProjectionPage(),
      ),
      session: harness.session,
    );
  }

  void verifyLoads(int times) => verify(
    () => repository.fetch(
      from: any(named: 'from'),
      months: any(named: 'months'),
    ),
  ).called(times);

  testWidgets('charts and lists the months, negative ones in red', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.text(r'A partir do saldo de R$ 1.234,56 em 03/11/2026'),
      findsOneWidget,
    );
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Gráfico do saldo')), findsOneWidget);
    expect(find.text('novembro de 2026'), findsOneWidget);
    expect(
      find.text(
        'Entradas R\$ 6.500,00 · Saídas R\$ 2.800,00\n'
        'Fixas R\$ 2.000,00 · Variáveis R\$ 800,00\n'
        r'Economia acumulada R$ 3.700,00',
      ),
      findsOneWidget,
    );
    final context = tester.element(find.byType(ProjectionPage));
    final error = Theme.of(context).colorScheme.error;
    expect(tester.widget<Text>(find.text(r'-R$ 1.065,44')).style?.color, error);
    expect(
      tester.widget<Text>(find.text(r'R$ 4.934,56')).style?.color,
      isNot(error),
    );
  });

  testWidgets('shows the savings of the last month, in red when negative', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.text('Economia acumulada até dezembro de 2026'),
      findsOneWidget,
    );
    final context = tester.element(find.byType(ProjectionPage));
    final error = Theme.of(context).colorScheme.error;
    expect(tester.widget<Text>(find.text(r'-R$ 2.300,00')).style?.color, error);

    answer(() => projection.copyWith(months: [novemberProjection]));
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.text(r'R$ 3.700,00')).style?.color,
      isNot(error),
    );
  });

  testWidgets('shows the closing balance when a month is touched', (
    tester,
  ) async {
    await pump(tester);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final tooltip = chart.data.lineTouchData.touchTooltipData;
    final spot = chart.data.lineBarsData.single.spots.last;
    final items = tooltip.getTooltipItems([
      LineBarSpot(chart.data.lineBarsData.single, 0, spot),
    ]);

    expect(items.single!.text, r'-R$ 1.065,44');
  });

  testWidgets('asks for a balance first and reloads after it', (tester) async {
    answer(() => const Projection(months: []));
    await pump(tester);

    expect(find.textContaining('Informe seu saldo'), findsOneWidget);
    answer(() => projection);
    await tester.tap(find.text('Informar saldo'));
    await tester.pumpAndSettle();
    expect(find.text(routeMarker(AppRoutes.balanceForm)), findsOneWidget);
    await tester.tap(find.text(savedAndBack));
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
    verifyLoads(2);
  });

  testWidgets('retries a failed load', (tester) async {
    when(
      () => repository.fetch(
        from: any(named: 'from'),
        months: any(named: 'months'),
      ),
    ).thenThrow(const ApiError(code: 'network_error'));
    await pump(tester);

    answer(() => projection);
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(find.byType(LineChart), findsOneWidget);
  });

  testWidgets('reloads on pull to refresh', (tester) async {
    await pump(tester);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    verifyLoads(2);
  });
}
