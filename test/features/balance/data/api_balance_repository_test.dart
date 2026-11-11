import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/balance/data/api_balance_repository.dart';
import 'package:lar_em_dia/features/balance/domain/balance.dart';

import 'package:lar_em_dia/features/entries/data/finance_cache.dart';

import '../../../helpers/fake_adapter.dart';
import '../../../helpers/finance_fixtures.dart';

void main() {
  late FakeAdapter adapter;
  late FinanceCache cache;

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
    cache = FinanceCache();
    return ApiBalanceRepository(ApiClient(dio), cache);
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

  test('latest returns the most recent balance or null, once', () async {
    var items = <Object>[balanceJson];
    final repository = build((_) => page(items));

    expect(await repository.latest(), expected);
    expect(await repository.latest(), expected);
    expect(adapter.requests.single.queryParameters, {'limit': 1});

    items = [];
    cache.clear();
    expect(await repository.latest(), isNull);
  });

  test('latest keeps nothing fetched before the cache was cleared', () async {
    final repository = build((_) => page([balanceJson]));

    final latest = repository.latest();
    cache.clear();

    expect(await latest, expected);
    expect(cache.latestBalanceKnown, isFalse);
  });

  test('listing remembers the latest balance', () async {
    final repository = build((_) => page([balanceJson]));

    await repository.list();

    expect(await repository.latest(), expected);
    expect(adapter.requests, hasLength(1));
  });

  group('with a known latest balance', () {
    final older = {...balanceJson, 'id': 'balance-0', 'as_of': '2026-10-01'};
    final newer = {...balanceJson, 'id': 'balance-2', 'as_of': '2026-11-10'};
    late ApiBalanceRepository repository;
    late List<Object?> answers;

    setUp(() async {
      answers = [];
      repository = build((_) => FakeAdapter.json(200, answers.removeAt(0)));
      answers.add({
        'data': [balanceJson],
        'meta': <String, dynamic>{},
      });
      await repository.latest();
    });

    test('keeps a newer saved balance and the projection it answers', () async {
      cache.storeProjection(projection);
      answers.add({
        'data': newer,
        'meta': {
          'projection': {
            'anchor': {'amount_cents': -2500, 'as_of': '2026-11-10'},
            'months': <Object>[],
          },
        },
      });

      await repository.create(amountCents: -2500, asOf: DateTime(2026, 11, 10));

      expect(adapter.requests.last.uri.queryParameters, {
        'projection_from': '2026-11',
        'projection_months': '2',
      });
      expect((await repository.latest())!.id, 'balance-2');
      expect(cache.projectionWindow, isNull);
    });

    test('keeps the latest when an older one is saved', () async {
      answers.add({'data': older});

      await repository.create(amountCents: -2500, asOf: DateTime(2026, 10));

      expect(await repository.latest(), expected);
      expect(adapter.requests.last.uri.query, isEmpty);
    });

    test('forgets the latest when it moves back or is deleted', () async {
      answers
        ..add({
          'data': {...older, 'id': 'balance-1'},
        })
        ..add({
          'data': [older],
          'meta': <String, dynamic>{},
        });

      await repository.update(
        'balance-1',
        amountCents: -2500,
        asOf: DateTime(2026, 10),
      );

      expect(cache.latestBalanceKnown, isFalse);
      expect((await repository.latest())!.id, 'balance-0');

      answers.add({
        'data': {
          'deleted_ids': ['balance-0'],
        },
      });
      await repository.delete('balance-0');
      expect(cache.latestBalanceKnown, isFalse);
    });

    test('keeps the latest when another balance is deleted', () async {
      answers.add({
        'data': {
          'deleted_ids': ['balance-7'],
        },
      });

      await repository.delete('balance-7');

      expect(cache.latestBalanceKnown, isTrue);
    });
  });

  test('a saved balance becomes the latest when there was none', () async {
    final answers = <Object?>[
      {'data': <Object>[], 'meta': <String, dynamic>{}},
      {'data': balanceJson},
    ];
    final repository = build((_) => FakeAdapter.json(200, answers.removeAt(0)));
    await repository.latest();

    await repository.create(amountCents: -2500, asOf: DateTime(2026, 11, 3));

    expect(await repository.latest(), expected);
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
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': {
          'deleted_ids': ['balance-1'],
        },
      }),
    );

    await repository.delete('balance-1');

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/balances/balance-1');
  });
}
