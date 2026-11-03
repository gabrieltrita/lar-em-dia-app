import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/entries/data/api_entry_repository.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';

import '../../../helpers/fake_adapter.dart';
import '../../../helpers/finance_fixtures.dart';

void main() {
  late FakeAdapter adapter;

  Map<String, Object?> entryJson(String id, {String? paidOn}) => {
    'id': id,
    'kind': 'income',
    'category_id': 'cat-salary',
    'description': 'Salário ACME',
    'amount_cents': 500000,
    'due_on': '2026-11-05',
    'status': paidOn == null ? 'pending' : 'paid',
    'paid_on': paidOn,
    'created_at': '2026-11-03T10:00:00Z',
    'updated_at': '2026-11-03T10:00:00Z',
  };

  ApiEntryRepository build(FakeHandler handler) {
    adapter = FakeAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return ApiEntryRepository(ApiClient(dio));
  }

  test('lists the categories of a kind', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': [
          {
            'id': 'cat-salary',
            'kind': 'income',
            'key': 'salary',
            'name': 'Salary',
            'position': 0,
          },
        ],
      }),
    );

    expect(await repository.categories(EntryKind.income), [salaryCategory]);
    expect(adapter.requests.single.path, '/categories');
    expect(adapter.requests.single.queryParameters, {'kind': 'income'});
  });

  test('reads every page of the month', () async {
    final repository = build((options) {
      final page = options.queryParameters['page'] as int;
      return FakeAdapter.json(200, {
        'data': [entryJson('entry-$page', paidOn: '2026-11-05')],
        'meta': {'next': page == 1 ? 2 : null},
      });
    });

    final entries = await repository.month(
      DateTime(2026, 2, 14),
      kind: EntryKind.income,
    );

    expect(entries.map((entry) => entry.id), ['entry-1', 'entry-2']);
    expect(entries.first.paidOn, DateTime(2026, 11, 5));
    expect(entries.first.status, EntryStatus.paid);
    expect(adapter.requests.first.queryParameters, {
      'from': '2026-02-01',
      'to': '2026-02-28',
      'kind': 'income',
      'limit': 100,
      'page': 1,
    });
  });

  test('creates a received entry paid on its date', () async {
    final repository = build(
      (_) => FakeAdapter.json(201, {
        'data': entryJson('entry-1', paidOn: '2026-11-05'),
      }),
    );

    final created = await repository.create(salary.toDraft());

    expect(created.id, 'entry-1');
    expect(adapter.requests.single.method, 'POST');
    expect(adapter.requests.single.data, {
      'category_id': 'cat-salary',
      'description': 'Salário ACME',
      'amount_cents': 500000,
      'due_on': '2026-11-05',
      'status': 'paid',
      'paid_on': '2026-11-05',
    });
  });

  test('updates a pending entry clearing the payment date', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {'data': entryJson('entry-2')}),
    );

    final updated = await repository.update('entry-2', rent.toDraft());

    expect(updated.paidOn, isNull);
    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.path, '/entries/entry-2');
    expect(adapter.requests.single.data, containsPair('paid_on', null));
    expect(adapter.requests.single.data, containsPair('status', 'pending'));
  });

  test('deletes an entry', () async {
    final repository = build((_) => FakeAdapter.json(204, null));

    await repository.delete('entry-2');

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/entries/entry-2');
  });
}
