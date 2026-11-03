import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/balance/data/balance_dto.dart';
import 'package:lar_em_dia/features/balance/domain/balance.dart';
import 'package:lar_em_dia/features/balance/domain/balance_repository.dart';

@LazySingleton(as: BalanceRepository)
class ApiBalanceRepository implements BalanceRepository {
  new(this._client);

  static const path = '/balances';
  static const pageSize = 100;

  final ApiClient _client;

  @override
  Future<List<Balance>> list() async {
    final response = await _client.get<List<Balance>>(
      path,
      decode: _decodeList,
      query: {'limit': pageSize},
    );
    return response.data;
  }

  @override
  Future<Balance?> latest() async {
    final response = await _client.get<List<Balance>>(
      path,
      decode: _decodeList,
      query: {'limit': 1},
    );
    return response.data.firstOrNull;
  }

  @override
  Future<Balance> create({
    required int amountCents,
    required DateTime asOf,
  }) async {
    final response = await _client.post<Balance>(
      path,
      decode: _decode,
      body: _body(amountCents, asOf),
    );
    return response.data;
  }

  @override
  Future<Balance> update(
    String id, {
    required int amountCents,
    required DateTime asOf,
  }) async {
    final response = await _client.patch<Balance>(
      '$path/$id',
      decode: _decode,
      body: _body(amountCents, asOf),
    );
    return response.data;
  }

  @override
  Future<void> delete(String id) => _client.delete('$path/$id');

  static Json _body(int amountCents, DateTime asOf) => {
    'amount_cents': amountCents,
    'as_of': Dates.toIso(asOf),
  };

  static Balance _decode(Object? data) =>
      BalanceDto.fromJson(data! as Json).toDomain();

  static List<Balance> _decodeList(Object? data) =>
      (data! as List<dynamic>).map(_decode).toList();
}
