import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/investments/data/investment_dtos.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/investment_repository.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';

@LazySingleton(as: InvestmentRepository)
class ApiInvestmentRepository implements InvestmentRepository {
  new(this._client, this._cache);

  static const transactionsPath = '/investment_transactions';
  static const searchLimit = 20;
  static const transactionsLimit = 100;

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

  static Asset _asset(Object? data) =>
      AssetDto.fromJson(data! as Json).toDomain();

  static InvestmentTransaction _transaction(Object? data) =>
      InvestmentTransactionDto.fromJson(data! as Json).toDomain();
}
