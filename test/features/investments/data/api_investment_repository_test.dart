import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/investments/data/api_investment_repository.dart';
import 'package:lar_em_dia/features/investments/data/investment_dtos.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/distribution.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
import 'package:lar_em_dia/features/investments/domain/screener.dart';
import 'package:lar_em_dia/features/investments/domain/simulation.dart';

import '../../../helpers/fake_adapter.dart';
import '../../../helpers/finance_fixtures.dart';
import '../../../helpers/investment_fixtures.dart';

void main() {
  late FakeAdapter adapter;
  late FinanceCache cache;

  const quoteJson = {
    'quoted_on': '2026-11-11',
    'close_cents': 16000,
    'volume_cents': 100,
    'trades_count': 3,
  };
  const assetJson = {
    'ticker': 'HGLG11',
    'name': 'PATRIA LOG FII',
    'asset_type': 'fii',
    'sector': 'Logística',
    'isin': 'BRHGLGCTF004',
    'cnpj': '11728688000147',
    'active': true,
    'quote': quoteJson,
  };
  const buyJson = {
    'id': 'investment-1',
    'ticker': 'HGLG11',
    'kind': 'buy',
    'traded_on': '2026-10-05',
    'quantity': 10,
    'price_cents': 15000,
    'fees_cents': 500,
    'entry_id': 'entry-9',
    'created_at': '2026-10-05T10:00:00Z',
    'updated_at': '2026-10-05T10:00:00Z',
  };
  Map<String, Object?> totalsJson(PortfolioTotals totals) => {
    'contributed_cents': totals.contributedCents,
    'cost_cents': totals.costCents,
    'market_value_cents': totals.marketValueCents,
    'gain_cents': totals.gainCents,
    'realized_cents': totals.realizedCents,
  };
  final portfolioJson = {
    'totals': totalsJson(portfolio.totals),
    'goals': {
      'income': totalsJson(incomeTotals),
      'growth': totalsJson(growthTotals),
    },
    'positions': [
      {
        'ticker': 'HGLG11',
        'name': 'PATRIA LOG FII',
        'asset_type': 'fii',
        'goal': 'income',
        'quantity': 10,
        'average_price_e8': 15050000000,
        'cost_cents': 150500,
        'contributed_cents': 150500,
        'realized_cents': 0,
        'quote': quoteJson,
        'market_value_cents': 160000,
        'gain_cents': 9500,
      },
      {
        'ticker': 'ITSA4',
        'name': 'ITAUSA',
        'asset_type': 'stock',
        'goal': 'growth',
        'quantity': 100,
        'average_price_e8': 1100000000,
        'cost_cents': 110000,
        'contributed_cents': 107500,
        'realized_cents': 2500,
        'quote': null,
        'market_value_cents': 100000,
        'gain_cents': -10000,
      },
    ],
  };

  ApiInvestmentRepository build(FakeHandler handler) {
    adapter = FakeAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    cache = FinanceCache()..latestBalance = balance;
    return ApiInvestmentRepository(ApiClient(dio), cache);
  }

  ResponseBody ok(Object? data, [int status = 200]) =>
      FakeAdapter.json(status, {'data': data, 'meta': <String, dynamic>{}});

  test('searches the catalog', () async {
    final repository = build(
      (_) => ok([
        {'ticker': 'PETR4', 'name': 'PETROBRAS', 'asset_type': 'stock'},
      ]),
    );

    expect(await repository.searchAssets('petr'), [petr]);
    expect(adapter.requests.single.path, '/assets');
    expect(adapter.requests.single.queryParameters, {'q': 'petr', 'limit': 20});
  });

  test('reads an asset with its latest quote', () async {
    final repository = build((_) => ok(assetJson));

    expect(await repository.asset('HGLG11'), hglg);
    expect(adapter.requests.single.path, '/assets/HGLG11');
  });

  test('reads an FII with its report and distributions', () async {
    final repository = build(
      (_) => ok({
        ...assetJson,
        'fund_report': {
          'reference_month': '2026-09',
          'equity_cents': 754601779739,
          'book_value_per_share_e8': 16547663017,
          'shares_count': 45601713,
          'shareholders_count': 613837,
        },
        'distributions': [
          {
            'id': 'distribution-1',
            'ticker': 'HGLG11',
            'kind': 'fii_income',
            'source': 'cvm',
            'record_on': '2026-09-30',
            'paid_on': null,
            'amount_per_share_e8': 116691920,
            'net_amount_per_share_e8': 116691920,
          },
        ],
      }),
    );

    expect(await repository.asset('HGLG11'), hglgWithIncome);
  });

  test('reads an FII with the properties of its latest quarter', () async {
    Map<String, Object?> property(String name, String kind) => {
      'name': name,
      'kind': kind,
      'area_m2': null,
      'vacancy_bps': null,
      'delinquency_bps': null,
      'revenue_share_bps': null,
    };
    final repository = build(
      (_) => ok({
        ...assetJson,
        'composition': {
          'reference_on': '2026-09-30',
          'largest_tenant_bps': 466,
          'properties': [
            {
              'name': 'Betim',
              'kind': 'rent',
              'area_m2': 35331,
              'vacancy_bps': 120,
              'delinquency_bps': 0,
              'revenue_share_bps': 543,
            },
            property('Cajamar', 'rent'),
            property('Extrema', 'rent_construction'),
            property('Jundiaí', 'sale'),
            property('Louveira', 'sale_construction'),
            property('Sumaré', 'rent'),
          ],
        },
        'indicators': {
          'computed_on': '2026-11-11',
          'fund_category': 'fund_of_funds',
        },
      }),
    );

    final asset = await repository.asset('HGLG11');

    expect(asset.composition, hglgComposition);
    expect(asset.indicators?.fundCategory, FundCategory.fundOfFunds);
  });

  test('reads the passive income', () async {
    final repository = build(
      (_) => ok({
        'monthly_average_cents': 1250,
        'received': [
          {'month': '2026-10', 'amount_cents': 15000},
          {'month': '2026-11', 'amount_cents': 0},
        ],
        'forecast': [
          {'month': '2026-12', 'amount_cents': 1167},
        ],
        'positions': [
          {
            'ticker': 'HGLG11',
            'goal': 'income',
            'quantity': 10,
            'received_12m_cents': 15000,
            'monthly_forecast_cents': 1167,
          },
        ],
      }),
    );

    expect(await repository.income(), passiveIncome);
    expect(adapter.requests.single.path, '/portfolio/income');
  });

  test(
    'records, edits and deletes a distribution, clearing the cache',
    () async {
      const jcpJson = {
        'id': 'distribution-2',
        'ticker': 'ITSA4',
        'kind': 'jcp',
        'source': 'manual',
        'record_on': '2026-08-20',
        'paid_on': '2026-11-25',
        'amount_per_share_e8': 33333333,
        'net_amount_per_share_e8': 28333333,
      };
      final repository = build((_) => ok(jcpJson));
      final body = {
        'kind': 'jcp',
        'record_on': '2026-08-20',
        'paid_on': '2026-11-25',
        'amount_per_share_e8': 33333333,
      };

      expect(await repository.createDistribution(itsaJcpDraft), itsaJcp);
      expect(adapter.requests.last.method, 'POST');
      expect(adapter.requests.last.path, '/asset_distributions');
      expect(adapter.requests.last.data, {'ticker': 'ITSA4', ...body});
      expect(cache.latestBalanceKnown, isFalse);

      cache.latestBalance = balance;
      expect(
        await repository.updateDistribution(itsaJcp, itsaJcpDraft),
        itsaJcp,
      );
      expect(adapter.requests.last.method, 'PATCH');
      expect(adapter.requests.last.path, '/asset_distributions/distribution-2');
      expect(adapter.requests.last.data, body);
      expect(cache.latestBalanceKnown, isFalse);

      cache.latestBalance = balance;
      await repository.deleteDistribution(itsaJcp);
      expect(adapter.requests.last.method, 'DELETE');
      expect(cache.latestBalanceKnown, isFalse);
    },
  );

  test('reads the portfolio and fills missing goals', () async {
    final repository = build((_) => ok(portfolioJson));

    expect(await repository.portfolio(), portfolio);
    expect(
      PortfolioDto.fromJson({
        'totals': totalsJson(PortfolioTotals.empty),
        'goals': <String, Object?>{},
        'positions': <Object?>[],
      }).toDomain(),
      emptyPortfolio,
    );
  });

  test('reads the monthly history', () async {
    final repository = build(
      (_) => ok([
        {
          'month': '2025-10',
          'contributed_cents': 10000,
          'market_value_cents': 10500,
        },
      ]),
    );

    expect(await repository.history(), [history.first]);
    expect(adapter.requests.single.path, '/portfolio/history');
  });

  test('lists the transactions of a ticker', () async {
    final repository = build(
      (_) => ok([
        buyJson,
        {
          ...buyJson,
          'id': 'investment-2',
          'kind': 'split',
          'traded_on': '2026-11-02',
          'price_cents': null,
          'fees_cents': 0,
          'entry_id': null,
        },
      ]),
    );

    expect(await repository.transactions('HGLG11'), [hglgBuy, hglgSplit]);
    expect(adapter.requests.single.queryParameters, {
      'ticker': 'HGLG11',
      'limit': 100,
    });
  });

  test('creates a trade and clears the finance cache when it debits', () async {
    final repository = build((_) => ok(buyJson, 201));

    expect(
      await repository.create(hglgDraft.copyWith(goal: InvestmentGoal.growth)),
      hglgBuy,
    );
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/investment_transactions');
    expect(request.data, {
      'ticker': 'HGLG11',
      'kind': 'buy',
      'traded_on': '2026-10-05',
      'quantity': 10,
      'price_cents': 15000,
      'fees_cents': 500,
      'debit_balance': true,
      'goal': 'growth',
    });
    expect(cache.latestBalanceKnown, isFalse);
  });

  test(
    'sends only the quantity for corporate events and keeps the cache',
    () async {
      final repository = build(
        (_) => ok({...buyJson, 'kind': 'reverse_split'}),
      );

      final saved = await repository.create(
        InvestmentDraft(
          ticker: 'HGLG11',
          kind: InvestmentKind.reverseSplit,
          tradedOn: DateTime(2026, 11, 2),
          quantity: 9,
        ),
      );

      expect(saved.kind, InvestmentKind.reverseSplit);
      expect(adapter.requests.single.data, {
        'ticker': 'HGLG11',
        'kind': 'reverse_split',
        'traded_on': '2026-11-02',
        'quantity': 9,
      });
      expect(cache.latestBalanceKnown, isTrue);
    },
  );

  test(
    'updates a transaction and clears the cache when it had an entry',
    () async {
      final repository = build((_) => ok(buyJson));

      await repository.update(hglgBuy, hglgDraft.copyWith(debitBalance: false));

      expect(adapter.requests.single.method, 'PATCH');
      expect(
        adapter.requests.single.path,
        '/investment_transactions/investment-1',
      );
      expect(cache.latestBalanceKnown, isFalse);
    },
  );

  test('deletes a transaction', () async {
    final repository = build((_) => ok({'deleted_id': 'investment-2'}));

    await repository.delete(hglgSplit);

    expect(adapter.requests.single.method, 'DELETE');
    expect(
      adapter.requests.single.path,
      '/investment_transactions/investment-2',
    );
    expect(cache.latestBalanceKnown, isTrue);
  });

  test('reports a refused deletion by its code', () async {
    final repository = build(
      (_) => FakeAdapter.json(422, {
        'error': {'code': 'insufficient_quantity', 'message': 'No'},
      }),
    );

    await expectLater(
      repository.delete(hglgBuy),
      throwsA(
        isA<ApiError>().having((e) => e.code, 'code', 'insufficient_quantity'),
      ),
    );
    expect(cache.latestBalanceKnown, isTrue);
  });

  test('changes the goal of a position', () async {
    final repository = build((_) => ok({'ticker': 'HGLG11', 'goal': 'growth'}));

    await repository.updateGoal('HGLG11', InvestmentGoal.growth);

    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.path, '/investment_positions/HGLG11');
    expect(adapter.requests.single.data, {'goal': 'growth'});
  });

  test('maps every kind to its wire name and back', () {
    for (final kind in InvestmentKind.values) {
      expect(InvestmentWire.parseKind(InvestmentWire.kind(kind)), kind);
    }
    expect(InvestmentWire.parseType('stock'), AssetType.stock);
    for (final kind in DistributionKind.values) {
      expect(
        InvestmentWire.parseDistributionKind(
          InvestmentWire.distributionKind(kind),
        ),
        kind,
      );
    }
  });

  group('screener', () {
    const hglgIndicatorsJson = {
      'computed_on': '2026-11-11',
      'price_cents': 16000,
      'dy_12m_bps': 825,
      'distribution_average_e8': 110000000,
      'distribution_median_e8': 108000000,
      'years_paying': 3,
      'payout_bps': null,
      'p_vp_e2': 97,
      'p_l_e2': null,
      'roe_average_bps': null,
      'earnings_cagr_bps': null,
      'equity_cagr_bps': null,
      'years_with_profit': null,
      'net_margin_bps': null,
      'net_debt_to_equity_bps': null,
      'liquidity_cents': 2854943689,
      'financial_years': null,
      'fund_category': 'brick',
      'development_bps': 0,
      'properties_count': 36,
      'largest_property_bps': 543,
      'vacancy_bps': 245,
      'delinquency_bps': 0,
      'largest_tenant_bps': 466,
      'months_paying_12m': 11,
    };
    const petrIndicatorsJson = {
      'computed_on': '2026-11-11',
      'price_cents': 3200,
      'dy_12m_bps': 1095,
      'distribution_average_e8': null,
      'distribution_median_e8': null,
      'years_paying': 5,
      'payout_bps': 4087,
      'p_vp_e2': 99,
      'p_l_e2': 373,
      'roe_average_bps': 2210,
      'earnings_cagr_bps': -350,
      'equity_cagr_bps': 812,
      'years_with_profit': 5,
      'net_margin_bps': 2223,
      'net_debt_to_equity_bps': 7984,
      'liquidity_cents': 150000000000,
      'financial_years': 5,
    };

    test('filters and sorts the catalog by indicator', () async {
      final repository = build(
        (_) => FakeAdapter.json(200, {
          'data': [
            {
              'ticker': 'HGLG11',
              'name': 'PATRIA LOG FII',
              'asset_type': 'fii',
              'sector': 'Logística',
              'indicators': hglgIndicatorsJson,
            },
          ],
          'meta': {'next': 2, 'total': 51},
        }),
      );

      final page = await repository.screen(
        const ScreenerQuery(
          payingOnly: true,
          hideSingleProperty: true,
          hideDevelopment: true,
          categories: {FundCategory.hybrid, FundCategory.brick},
          ranges: {
            Indicator.dividendYield: IndicatorRange(min: 800),
            Indicator.priceToBook: IndicatorRange(max: 100),
            Indicator.priceToEarnings: IndicatorRange(max: 1000),
            Indicator.liquidity: IndicatorRange(),
          },
        ),
      );

      expect(
        page,
        ScreenerPage(assets: [hglgScreened], nextPage: 2, total: 51),
      );
      expect(adapter.requests.single.path, '/assets');
      expect(adapter.requests.single.queryParameters, {
        'asset_type': 'fii',
        'sort': 'dy_12m_bps',
        'direction': 'desc',
        'page': 1,
        'limit': 50,
        'paying': true,
        'hide_single_property': true,
        'hide_development': true,
        'fund_category': 'brick,hybrid',
        'dy_12m_bps_min': 800,
        'p_vp_e2_max': 100,
      });
    });

    test('reads the stock indicators and the last page', () async {
      final repository = build(
        (_) => ok([
          {
            'ticker': 'PETR4',
            'name': 'PETROBRAS',
            'asset_type': 'stock',
            'sector': 'Petróleo e Gás',
            'indicators': petrIndicatorsJson,
          },
        ]),
      );

      final page = await repository.screen(
        const ScreenerQuery(
          type: AssetType.stock,
          sort: Indicator.priceToEarnings,
          ascending: true,
          hideSingleProperty: true,
          hideDevelopment: true,
          categories: {FundCategory.brick},
        ),
        page: 3,
      );

      expect(page, ScreenerPage(assets: [petrScreened]));
      expect(adapter.requests.single.queryParameters, {
        'asset_type': 'stock',
        'sort': 'p_l_e2',
        'direction': 'asc',
        'page': 3,
        'limit': 50,
      });
    });
  });

  group('simulation', () {
    Map<String, Object?> body() =>
        adapter.requests.single.data as Map<String, Object?>;

    test('simulates income from an asset', () async {
      final repository = build(
        (_) => ok({
          'kind': 'income',
          'ticker': 'HGLG11',
          'price_cents': 10000,
          'monthly_income_per_share_e8': 100000000,
          'monthly_yield_bps': null,
          'reinvest': true,
          'months': [
            {
              'month': 12,
              'contributed_cents': 280000,
              'shares': 28,
              'value_cents': 285000,
              'income_cents': 2800,
              'received_cents': 22000,
            },
            {
              'month': 24,
              'contributed_cents': 460000,
              'shares': 48,
              'value_cents': 485000,
              'income_cents': 4800,
              'received_cents': 70000,
            },
          ],
          'summary': {
            'contributed_cents': 460000,
            'value_cents': 485000,
            'monthly_income_cents': 4800,
            'received_cents': 70000,
            'target_monthly_income_cents': 1000,
            'shares_for_target': 10,
            'capital_for_target_cents': 100000,
            'months_to_target': 1,
          },
        }),
      );

      expect(await repository.simulateIncome(incomeInput), incomeSimulation);
      expect(adapter.requests.single.path, '/portfolio/simulation');
      expect(body(), {
        'kind': 'income',
        'months': 24,
        'initial_cents': 100000,
        'monthly_cents': 15000,
        'reinvest': true,
        'ticker': 'HGLG11',
        'target_monthly_income_cents': 1000,
      });
    });

    test('simulates income from a monthly yield', () async {
      final repository = build(
        (_) => ok({
          'kind': 'income',
          'ticker': null,
          'price_cents': null,
          'monthly_income_per_share_e8': null,
          'monthly_yield_bps': 80,
          'reinvest': false,
          'months': [
            {
              'month': 1,
              'contributed_cents': 100000,
              'shares': null,
              'value_cents': 100000,
              'income_cents': 800,
              'received_cents': 800,
            },
          ],
          'summary': <String, Object?>{},
        }),
      );

      final result = await repository.simulateIncome(
        const IncomeSimulationInput(
          months: 1,
          initialCents: 100000,
          monthlyYieldBps: 80,
          reinvest: false,
        ),
      );

      expect(result.monthlyYieldBps, 80);
      expect(result.last.shares, isNull);
      expect(body(), {
        'kind': 'income',
        'months': 1,
        'initial_cents': 100000,
        'monthly_cents': 0,
        'reinvest': false,
        'monthly_yield_bps': 80,
      });
    });

    test('simulates growth at the chosen rate', () async {
      final repository = build(
        (_) => ok({
          'kind': 'growth',
          'annual_rate_bps': 1200,
          'monthly_rate_e8': 948879,
          'months': [
            {
              'month': 12,
              'contributed_cents': 220000,
              'value_cents': 238465,
              'earnings_cents': 18465,
            },
          ],
          'summary': {
            'contributed_cents': 220000,
            'value_cents': 238465,
            'earnings_cents': 18465,
          },
        }),
      );

      expect(await repository.simulateGrowth(growthInput), growthSimulation);
      expect(body(), {
        'kind': 'growth',
        'months': 12,
        'initial_cents': 100000,
        'monthly_cents': 10000,
        'annual_rate_bps': 1200,
      });
    });
  });
}
