import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/balance/data/api_balance_repository.dart';
import 'package:lar_em_dia/features/balance/domain/balance.dart';

import '../../../helpers/fake_adapter.dart';

void main() {
  late FakeAdapter adapter;

  const balanceJson = {
    'id': 'balance-1',
    'amount_cents': -2500,
    'as_of': '2026-11-03',
    'created_at': '2026-11-03T10:00:00Z',
    'updated_at': '2026-11-03T10:00:00Z',
  };
  final expected = Balance(
    id: 'balance-1',
    amountCents: -2500,
    asOf: DateTime(2026, 11, 3),
  );

  ApiBalanceRepository build(FakeHandler handler) {
    adapter = FakeAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return ApiBalanceRepository(ApiClient(dio));
  }

  ResponseBody one() => FakeAdapter.json(200, {'data': balanceJson});

  ResponseBody page(List<Object> items) =>
      FakeAdapter.json(200, {'data': items, 'meta': <String, dynamic>{}});

  test('lists the balances', () async {
    final repository = build((_) => page([balanceJson]));

    expect(await repository.list(), [expected]);
    expect(adapter.requests.single.path, '/balances');
    expect(adapter.requests.single.queryParameters, {'limit': 100});
  });

  test('latest returns the most recent balance or null', () async {
    var items = <Object>[balanceJson];
    final repository = build((_) => page(items));

    expect(await repository.latest(), expected);
    expect(adapter.requests.last.queryParameters, {'limit': 1});

    items = [];
    expect(await repository.latest(), isNull);
  });

  test('creates a balance', () async {
    final repository = build((_) => one());

    final created = await repository.create(
      amountCents: -2500,
      asOf: DateTime(2026, 11, 3),
    );

    expect(created, expected);
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.data, {
      'amount_cents': -2500,
      'as_of': '2026-11-03',
    });
  });

  test('updates a balance', () async {
    final repository = build((_) => one());

    await repository.update(
      'balance-1',
      amountCents: -2500,
      asOf: DateTime(2026, 11, 3),
    );

    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.path, '/balances/balance-1');
  });

  test('deletes a balance', () async {
    final repository = build((_) => FakeAdapter.json(204, null));

    await repository.delete('balance-1');

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/balances/balance-1');
  });
}
