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
}
