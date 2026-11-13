import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/screener.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/explore_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/auth_fixtures.dart';
import '../../../../helpers/investment_fixtures.dart';
import '../../../../helpers/pump_page.dart';

void main() {
  late AuthHarness harness;
  late MockInvestmentRepository repository;

  setUpAll(registerInvestmentFallbacks);

  setUp(() {
    harness = AuthHarness();
    repository = MockInvestmentRepository();
    when(() => repository.screen(any())).thenAnswer(
      (_) async => ScreenerPage(assets: [hglgScreened, btlg], nextPage: 2),
    );
    when(() => repository.screen(any(), page: 2))
        .thenAnswer((_) async => ScreenerPage(assets: [petrScreened]));
  });
  tearDown(() => harness.dispose());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    addTearDown(tester.view.resetPhysicalSize);
    await pumpPage(
      tester,
      BlocProvider(
        create: (_) =>
            started(ExploreCubit(repository), (cubit) => cubit.load()),
        child: const ExplorePage(),
      ),
      session: harness.session,
    );
  }

  ScreenerQuery lastQuery() =>
      verify(() => repository.screen(captureAny())).captured.last
          as ScreenerQuery;

  testWidgets('lists FIIs with their key indicators and opens one', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('HGLG11'), findsOneWidget);
    expect(
      find.textContaining(
        'PATRIA LOG FII · Logística\nDY 12 meses 8,25% · P/VP 0,97 · Liquidez',
      ),
      findsOneWidget,
    );
    expect(find.text('BTG LOG'), findsOneWidget);
    expect(find.textContaining('Não é ranking'), findsOneWidget);

    await tester.tap(find.text('Carregar mais'));
    await tester.pumpAndSettle();
    expect(find.text('PETR4'), findsOneWidget);
    expect(find.text('Carregar mais'), findsNothing);

    await tester.tap(find.text('HGLG11'));
    await tester.pumpAndSettle();
    expect(
      find.text(routeMarker('/investments/assets/HGLG11')),
      findsOneWidget,
    );
  });

  testWidgets('switches to stocks, sorts and flips the direction', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Ações'));
    await tester.pumpAndSettle();
    expect(lastQuery().type, AssetType.stock);

    await tester.tap(find.byKey(const Key('explore_sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('P/L').last);
    await tester.pumpAndSettle();
    expect(lastQuery().sort, Indicator.priceToEarnings);

    await tester.tap(find.byKey(const Key('explore_direction')));
    await tester.pumpAndSettle();
    expect(lastQuery().ascending, isTrue);
    expect(find.byTooltip('Menor primeiro'), findsOneWidget);
  });

  testWidgets('applies, validates and clears the indicator filters', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Sem filtros'), findsOneWidget);

    await tester.tap(find.byKey(const Key('explore_filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('explore_paying')));
    await tester.enterText(
      find.byKey(const Key('explore_dividendYield_min')),
      '8,5',
    );
    await tester.enterText(
      find.byKey(const Key('explore_priceToBook_max')),
      'abc',
    );
    await tester.tap(find.byKey(const Key('explore_apply')));
    await tester.pumpAndSettle();
    expect(find.text('Valor inválido'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('explore_priceToBook_max')),
      '1',
    );
    await tester.enterText(
      find.byKey(const Key('explore_liquidity_min')),
      '1.000.000,00',
    );
    await tester.tap(find.byKey(const Key('explore_apply')));
    await tester.pumpAndSettle();

    final query = lastQuery();
    expect(query.payingOnly, isTrue);
    expect(query.activeRanges, {
      Indicator.dividendYield: const IndicatorRange(min: 850),
      Indicator.priceToBook: const IndicatorRange(max: 100),
      Indicator.liquidity: const IndicatorRange(min: 100000000),
    });
    expect(find.text('4 filtros'), findsOneWidget);

    await tester.tap(find.byKey(const Key('explore_filters')));
    await tester.pumpAndSettle();
    expect(find.text('8,5'), findsOneWidget);
    await tester.tap(find.text('Limpar'));
    await tester.tap(find.byKey(const Key('explore_apply')));
    await tester.pumpAndSettle();
    expect(lastQuery().activeRanges, isEmpty);
    expect(find.text('Sem filtros'), findsOneWidget);

    await tester.tap(find.byKey(const Key('explore_filters')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Sem filtros'), findsOneWidget);
  });

  testWidgets('explains an empty result and retries a failure', (tester) async {
    when(() => repository.screen(any()))
        .thenAnswer((_) async => const ScreenerPage(assets: []));
    await pump(tester);
    expect(find.text('Nenhum papel encontrado'), findsOneWidget);

    when(() => repository.screen(any()))
        .thenThrow(const ApiError(code: 'invalid_filter'));
    await tester.tap(find.text('Ações'));
    await tester.pumpAndSettle();
    expect(find.text('Os filtros precisam ser números.'), findsOneWidget);

    when(() => repository.screen(any()))
        .thenAnswer((_) async => ScreenerPage(assets: [petrScreened]));
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('PETR4'), findsOneWidget);
  });
}
