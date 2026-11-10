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
      'nature': null,
      'paid_on': '2026-11-05',
    });
  });

  test('creates a recurring series and reads its entries', () async {
    final repository = build(
      (_) => FakeAdapter.json(201, {
        'data': {
          'id': 'series-1',
          'kind': 'recurring',
          'entries_count': 2,
          'entries': [
            {
              ...entryJson('entry-1', paidOn: '2026-11-05'),
              'series_id': 'series-1',
              'series_position': 1,
            },
            {
              ...entryJson('entry-2'),
              'due_on': '2026-12-05',
              'series_id': 'series-1',
              'series_position': 2,
            },
          ],
        },
      }),
    );

    final created = await repository.createSeries(
      salary.toDraft(),
      const Recurrence(count: 2, direction: RecurrenceDirection.backward),
    );

    expect(created.map((entry) => entry.seriesPosition), [1, 2]);
    expect(created.last.seriesId, 'series-1');
    expect(created.last.isRecurring, isTrue);
    expect(adapter.requests.single.path, '/entry_series');
    expect(adapter.requests.single.data, {
      'category_id': 'cat-salary',
      'description': 'Salário ACME',
      'amount_cents': 500000,
      'due_on': '2026-11-05',
      'status': 'paid',
      'nature': null,
      'paid_on': '2026-11-05',
      'entries_count': 2,
      'direction': 'backward',
      'interval_months': 1,
    });
  });

  test('creates installments from the total', () async {
    final repository = build(
      (_) => FakeAdapter.json(201, {
        'data': {
          'id': 'series-2',
          'kind': 'installments',
          'entries_count': 2,
          'total_cents': 500001,
          'entries': [
            {
              ...entryJson('entry-1'),
              'kind': 'expense',
              'nature': 'variable',
              'amount_cents': 250001,
              'series_id': 'series-2',
              'series_position': 1,
              'series_kind': 'installments',
              'series_count': 2,
            },
          ],
        },
      }),
    );

    final created = await repository.createInstallments(
      salary.toDraft(),
      const Installments(count: 2),
    );

    expect(created.single.isInstallment, isTrue);
    expect(created.single.isRecurring, isFalse);
    expect(created.single.seriesCount, 2);
    expect(adapter.requests.single.data, {
      'category_id': 'cat-salary',
      'description': 'Salário ACME',
      'due_on': '2026-11-05',
      'status': 'paid',
      'nature': null,
      'paid_on': '2026-11-05',
      'kind': 'installments',
      'total_cents': 500000,
      'entries_count': 2,
    });
  });

  test('ignores an unknown series kind', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': {
          ...entryJson('entry-1'),
          'series_id': 'series-9',
          'series_kind': 'weekly',
        },
      }),
    );

    final entry = await repository.update('entry-1', salary.toDraft());

    expect(entry.seriesKind, isNull);
    expect(entry.isRecurring, isTrue);
  });

  test('sends and reads the nature of an expense', () async {
    final repository = build(
      (_) => FakeAdapter.json(201, {
        'data': {...entryJson('entry-3'), 'kind': 'expense', 'nature': 'fixed'},
      }),
    );

    final created = await repository.create(housing.toDraft());

    expect(created.nature, EntryNature.fixed);
    expect(adapter.requests.single.data, containsPair('nature', 'fixed'));
  });

  test('reads the default nature of expense categories', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': [
          {
            'id': 'cat-housing',
            'kind': 'expense',
            'key': 'housing',
            'name': 'Housing',
            'position': 0,
            'default_nature': 'fixed',
          },
        ],
      }),
    );

    expect(await repository.categories(EntryKind.expense), [housingCategory]);
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

  test('reads entries between two days', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': [entryJson('entry-1')],
        'meta': {'next': null},
      }),
    );

    final entries = await repository.between(
      DateTime(2026, 11, 28),
      DateTime(2026, 12, 5),
      kind: EntryKind.expense,
    );

    expect(entries, hasLength(1));
    expect(adapter.requests.single.queryParameters, {
      'from': '2026-11-28',
      'to': '2026-12-05',
      'kind': 'expense',
      'limit': ApiEntryRepository.pageSize,
      'page': 1,
    });
  });

  test('updates the following entries without the payment fields', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {'data': entryJson('entry-2')}),
    );

    await repository.update(
      'entry-2',
      rent.toDraft(),
      scope: EntryScope.following,
    );

    final request = adapter.requests.single;
    expect(request.uri.path, '/entries/entry-2');
    expect(request.uri.queryParameters, {'scope': 'following'});
    expect(request.data, {
      'category_id': rent.categoryId,
      'description': rent.description,
      'amount_cents': rent.amountCents,
      'due_on': '2026-11-10',
      'nature': null,
    });
  });

  test('marks an entry as paid on a day and back to pending', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': entryJson('entry-2', paidOn: '2026-11-04'),
      }),
    );

    final paid = await repository.markPaid(
      'entry-2',
      paidOn: DateTime(2026, 11, 4),
    );
    await repository.markPaid('entry-2', paidOn: null);

    expect(paid.isPaid, isTrue);
    expect(adapter.requests.first.method, 'PATCH');
    expect(adapter.requests.first.data, {
      'status': 'paid',
      'paid_on': '2026-11-04',
    });
    expect(adapter.requests.last.data, {'status': 'pending', 'paid_on': null});
  });

  test('deletes the whole series of an entry', () async {
    final repository = build((_) => FakeAdapter.json(204, null));

    await repository.delete('entry-2', scope: EntryScope.all);

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.uri.path, '/entries/entry-2');
    expect(adapter.requests.single.uri.queryParameters, {'scope': 'all'});
  });
}
