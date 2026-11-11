import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/balance/data/balance_dto.dart';
import 'package:lar_em_dia/features/balance/domain/balance.dart';
import 'package:lar_em_dia/features/balance/domain/balance_repository.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';

@LazySingleton(as: BalanceRepository)
class ApiBalanceRepository implements BalanceRepository {
  new(this._client, this._cache);

  static const path = '/balances';
  static const pageSize = 100;

  final ApiClient _client;
  final FinanceCache _cache;

  @override
  Future<List<Balance>> list() async {
    final response = await _client.get<List<Balance>>(
      path,
      decode: _decodeList,
      query: {'limit': pageSize},
    );
    _cache.latestBalance = response.data.firstOrNull;
    return response.data;
  }

  @override
  Future<Balance?> latest() async {
    if (_cache.latestBalanceKnown) {
      return _cache.latestBalance;
    }
    final generation = _cache.generation;
    return await _cache.once('balances:latest', () async {
      final response = await _client.get<List<Balance>>(
        path,
        decode: _decodeList,
        query: {'limit': 1},
      );
      final latest = response.data.firstOrNull;
      if (generation == _cache.generation) {
        _cache.latestBalance = latest;
      }
      return latest;
    });
  }

  @override
  Future<Balance> create({
    required int amountCents,
    required DateTime asOf,
  }) async {
    final response = await _client.post<Balance>(
      _cache.withProjectionWindow(path),
      decode: _decode,
      body: _body(amountCents, asOf),
    );
    _saved(response);
    return response.data;
  }

  @override
  Future<Balance> update(
    String id, {
    required int amountCents,
    required DateTime asOf,
  }) async {
    final response = await _client.patch<Balance>(
      _cache.withProjectionWindow('$path/$id'),
      decode: _decode,
      body: _body(amountCents, asOf),
    );
    _saved(response);
    return response.data;
  }

  @override
  Future<void> delete(String id) async {
    final response = await _client.deleteReturning<void>(
      _cache.withProjectionWindow('$path/$id'),
      decode: (_) {},
    );
    if (_cache.latestBalance?.id == id) {
      _cache.forgetLatestBalance();
    }
    _cache.applyProjectionMeta(response.meta);
  }

  void _saved(ApiResponse<Balance> response) {
    final saved = response.data;
    if (_cache.latestBalanceKnown) {
      final latest = _cache.latestBalance;
      if (latest == null || !saved.asOf.isBefore(latest.asOf)) {
        _cache.latestBalance = saved;
      } else if (latest.id == saved.id) {
        _cache.forgetLatestBalance();
      }
    }
    _cache.applyProjectionMeta(response.meta);
  }

  static Json _body(int amountCents, DateTime asOf) => {
    'amount_cents': amountCents,
    'as_of': Dates.toIso(asOf),
  };

  static Balance _decode(Object? data) =>
      BalanceDto.fromJson(data! as Json).toDomain();

  static List<Balance> _decodeList(Object? data) =>
      (data! as List<dynamic>).map(_decode).toList();
}
