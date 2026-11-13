import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/investments/data/investment_dtos.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/distribution.dart';
import 'package:lar_em_dia/features/investments/domain/investment_repository.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
import 'package:lar_em_dia/features/investments/domain/screener.dart';
import 'package:lar_em_dia/features/investments/domain/simulation.dart';

@LazySingleton(as: InvestmentRepository)
class ApiInvestmentRepository implements InvestmentRepository {
  new(this._client, this._cache);

  static const transactionsPath = '/investment_transactions';
  static const distributionsPath = '/asset_distributions';
  static const searchLimit = 20;
  static const transactionsLimit = 100;
  static const screenerLimit = 50;
  static const simulationPath = '/portfolio/simulation';

  final ApiClient _client;
  final FinanceCache _cache;

  @override
  Future<List<Asset>> searchAssets(String query) async {
    final response = await _client.get<List<Asset>>(
      '/assets',
      decode: (data) => [
        for (final item in data! as List<dynamic>) _asset(item),
      ],
      query: {'q': query, 'limit': searchLimit},
    );
    return response.data;
  }

  @override
  Future<Asset> asset(String ticker) async {
    final response = await _client.get<Asset>(
      '/assets/${Uri.encodeComponent(ticker)}',
      decode: _asset,
    );
    return response.data;
  }

  @override
  Future<Portfolio> portfolio() async {
    final response = await _client.get<Portfolio>(
      '/portfolio',
      decode: (data) => PortfolioDto.fromJson(data! as Json).toDomain(),
    );
    return response.data;
  }

  @override
  Future<List<PortfolioMonth>> history() async {
    final response = await _client.get<List<PortfolioMonth>>(
      '/portfolio/history',
      decode: (data) => [
        for (final item in data! as List<dynamic>)
          PortfolioMonthDto.fromJson(item as Json).toDomain(),
      ],
    );
    return response.data;
  }

  @override
  Future<List<InvestmentTransaction>> transactions(String ticker) async {
    final response = await _client.get<List<InvestmentTransaction>>(
      transactionsPath,
      decode: (data) => [
        for (final item in data! as List<dynamic>) _transaction(item),
      ],
      query: {'ticker': ticker, 'limit': transactionsLimit},
    );
    return response.data;
  }

  @override
  Future<InvestmentTransaction> create(InvestmentDraft draft) async {
    final response = await _client.post<InvestmentTransaction>(
      transactionsPath,
      decode: _transaction,
      body: _body(draft),
    );
    _changed(draft.debitBalance);
    return response.data;
  }

  @override
  Future<InvestmentTransaction> update(
    InvestmentTransaction existing,
    InvestmentDraft draft,
  ) async {
    final response = await _client.patch<InvestmentTransaction>(
      '$transactionsPath/${existing.id}',
      decode: _transaction,
      body: _body(draft),
    );
    _changed(existing.changesBalance || draft.debitBalance);
    return response.data;
  }

  @override
  Future<void> delete(InvestmentTransaction transaction) async {
    await _client.delete('$transactionsPath/${transaction.id}');
    _changed(transaction.changesBalance);
  }

  @override
  Future<void> updateGoal(String ticker, InvestmentGoal goal) async {
    await _client.patch<void>(
      '/investment_positions/${Uri.encodeComponent(ticker)}',
      decode: (_) {},
      body: {'goal': goal.name},
    );
  }

  @override
  Future<PassiveIncome> income() async {
    final response = await _client.get<PassiveIncome>(
      '/portfolio/income',
      decode: (data) => PassiveIncomeDto.fromJson(data! as Json).toDomain(),
    );
    return response.data;
  }

  @override
  Future<AssetDistribution> createDistribution(DistributionDraft draft) async {
    final response = await _client.post<AssetDistribution>(
      distributionsPath,
      decode: _distribution,
      body: {'ticker': draft.ticker, ..._distributionBody(draft)},
    );
    _cache.clear();
    return response.data;
  }

  @override
  Future<AssetDistribution> updateDistribution(
    AssetDistribution existing,
    DistributionDraft draft,
  ) async {
    final response = await _client.patch<AssetDistribution>(
      '$distributionsPath/${existing.id}',
      decode: _distribution,
      body: _distributionBody(draft),
    );
    _cache.clear();
    return response.data;
  }

  @override
  Future<void> deleteDistribution(AssetDistribution distribution) async {
    await _client.delete('$distributionsPath/${distribution.id}');
    _cache.clear();
  }

  @override
  Future<ScreenerPage> screen(ScreenerQuery query, {int page = 1}) async {
    final response = await _client.get<List<Asset>>(
      '/assets',
      decode: (data) => [
        for (final item in data! as List<dynamic>) _asset(item),
      ],
      query: {
        'asset_type': query.type.name,
        'sort': InvestmentWire.indicator(query.sort),
        'direction': query.ascending ? 'asc' : 'desc',
        'page': page,
        'limit': screenerLimit,
        if (query.payingOnly) 'paying': true,
        for (final MapEntry(key: indicator, value: range)
            in query.activeRanges.entries) ...{
          '${InvestmentWire.indicator(indicator)}_min': ?range.min,
          '${InvestmentWire.indicator(indicator)}_max': ?range.max,
        },
      },
    );
    return ScreenerPage(
      assets: response.data,
      nextPage: response.meta['next'] as int?,
    );
  }

  @override
  Future<IncomeSimulation> simulateIncome(IncomeSimulationInput input) async {
    final response = await _client.post<IncomeSimulation>(
      simulationPath,
      decode: (data) => IncomeSimulationDto.fromJson(data! as Json).toDomain(),
      body: {
        'kind': 'income',
        'months': input.months,
        'initial_cents': input.initialCents,
        'monthly_cents': input.monthlyCents,
        'reinvest': input.reinvest,
        'ticker': ?input.ticker,
        'monthly_yield_bps': ?input.monthlyYieldBps,
        'target_monthly_income_cents': ?input.targetMonthlyIncomeCents,
      },
    );
    return response.data;
  }

  @override
  Future<GrowthSimulation> simulateGrowth(GrowthSimulationInput input) async {
    final response = await _client.post<GrowthSimulation>(
      simulationPath,
      decode: (data) => GrowthSimulationDto.fromJson(data! as Json).toDomain(),
      body: {
        'kind': 'growth',
        'months': input.months,
        'initial_cents': input.initialCents,
        'monthly_cents': input.monthlyCents,
        'annual_rate_bps': input.annualRateBps,
      },
    );
    return response.data;
  }

  void _changed(bool balance) {
    if (balance) {
      _cache.clear();
    }
  }

  static Json _body(InvestmentDraft draft) => {
    'ticker': draft.ticker,
    'kind': InvestmentWire.kind(draft.kind),
    'traded_on': Dates.toIso(draft.tradedOn),
    'quantity': draft.quantity,
    if (draft.kind.isTrade) ...{
      'price_cents': draft.priceCents,
      'fees_cents': draft.feesCents,
      'debit_balance': draft.debitBalance,
    },
    if (draft.goal case final goal?) 'goal': goal.name,
  };

  static Json _distributionBody(DistributionDraft draft) => {
    'kind': InvestmentWire.distributionKind(draft.kind),
    'record_on': Dates.toIso(draft.recordOn),
    'paid_on': Dates.toIso(draft.paidOn),
    'amount_per_share_e8': draft.amountPerShareE8,
  };

  static AssetDistribution _distribution(Object? data) =>
      AssetDistributionDto.fromJson(data! as Json).toDomain();

  static Asset _asset(Object? data) =>
      AssetDto.fromJson(data! as Json).toDomain();

  static InvestmentTransaction _transaction(Object? data) =>
      InvestmentTransactionDto.fromJson(data! as Json).toDomain();
}
