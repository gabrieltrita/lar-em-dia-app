import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/entries/data/api_entry_repository.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';

import '../../../helpers/fake_adapter.dart';
import '../../../helpers/finance_fixtures.dart';

void main() {
  late FakeAdapter adapter;
  late FinanceCache cache;

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
    cache = FinanceCache();
    return ApiEntryRepository(ApiClient(dio), cache);
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
    expect(await repository.categories(EntryKind.income), [salaryCategory]);
    expect(adapter.requests.single.path, '/categories');
    expect(adapter.requests.single.queryParameters, {'kind': 'income'});
  });

  Map<String, Object?> petJson() => {
    'id': 'cat-pet',
    'kind': 'expense',
    'key': 'custom_0123456789abcdef',
    'name': 'Pet',
    'position': 1,
    'default_nature': 'variable',
    'custom': true,
  };

  test('creates a category and adds it to the cached list', () async {
    final repository = build(
      (options) => options.method == 'POST'
          ? FakeAdapter.json(201, {'data': petJson()})
          : FakeAdapter.json(200, {
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
    await repository.categories(EntryKind.expense);

    final category = await repository.createCategory(
      kind: EntryKind.expense,
      name: 'Pet',
      defaultNature: EntryNature.variable,
    );

    expect(category, petCategory);
    expect(adapter.requests.last.path, '/categories');
    expect(adapter.requests.last.data, {
      'kind': 'expense',
      'name': 'Pet',
      'default_nature': 'variable',
    });
    expect(await repository.categories(EntryKind.expense), [
      housingCategory,
      petCategory,
    ]);
    expect(adapter.requests, hasLength(2));
  });

  test(
    'creates an income category without a nature or a cached list',
    () async {
      final repository = build(
        (_) => FakeAdapter.json(201, {
          'data': {
            'id': 'cat-freelance',
            'kind': 'income',
            'key': 'custom_ffff',
            'name': 'Freela',
            'position': 1,
            'custom': true,
          },
        }),
      );

      final category = await repository.createCategory(
        kind: EntryKind.income,
        name: 'Freela',
      );

      expect(category.custom, isTrue);
      expect(adapter.requests.single.data, {
        'kind': 'income',
        'name': 'Freela',
      });
      expect(cache.categories, isEmpty);
    },
  );

  test('deletes a category and drops it from the cached list', () async {
    final repository = build(
      (options) => options.method == 'DELETE'
          ? FakeAdapter.json(200, {
              'data': {'deleted_id': 'cat-pet'},
            })
          : FakeAdapter.json(200, {
              'data': [petJson()],
            }),
    );
    await repository.categories(EntryKind.expense);

    await repository.deleteCategory(petCategory);

    expect(adapter.requests.last.method, 'DELETE');
    expect(adapter.requests.last.path, '/categories/cat-pet');
    expect(await repository.categories(EntryKind.expense), isEmpty);
  });

  test('deletes a category that was never listed', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': {'deleted_id': 'cat-pet'},
      }),
    );

    await repository.deleteCategory(petCategory);

    expect(cache.categories, isEmpty);
  });

  test('reads every page of a block of months around the month', () async {
    final repository = build((options) {
      final page = options.queryParameters['page'] as int;
      return FakeAdapter.json(200, {
        'data': [entryJson('entry-$page', paidOn: '2026-11-05')],
        'meta': {'next': page == 1 ? 2 : null},
      });
    });

    final entries = await repository.month(
      DateTime(2026, 11, 14),
      kind: EntryKind.income,
    );

    expect(entries.map((entry) => entry.id), ['entry-1', 'entry-2']);
    expect(entries.first.paidOn, DateTime(2026, 11, 5));
    expect(entries.first.status, EntryStatus.paid);
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.first.queryParameters, {
      'from': '2026-05-01',
      'to': '2027-05-31',
      'limit': 500,
      'page': 1,
    });
    expect(
      await repository.month(DateTime(2026, 11), kind: EntryKind.expense),
      isEmpty,
    );
    expect(await repository.month(DateTime(2027, 2)), isEmpty);
    expect(adapter.requests, hasLength(2));
  });

  test('loads the next block in the background near the edge', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': <Object>[],
        'meta': {'next': null},
      }),
    );

    await repository.month(DateTime(2026, 11));
    await repository.month(DateTime(2027, 4));
    await pumpEventQueue();

    expect(
      [
        for (final request in adapter.requests)
          (request.queryParameters['from'], request.queryParameters['to']),
      ],
      [('2026-05-01', '2027-05-31'), ('2027-06-01', '2027-11-30')],
    );

    await repository.month(DateTime(2026, 6));
    await pumpEventQueue();
    expect(
      (
        adapter.requests.last.queryParameters['from'],
        adapter.requests.last.queryParameters['to'],
      ),
      ('2025-11-01', '2026-04-30'),
    );
  });

  test('loads only the missing months next to a loaded block', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': <Object>[],
        'meta': {'next': null},
      }),
    );

    await repository.month(DateTime(2026, 11));
    await repository.month(DateTime(2027, 8));
    await repository.month(DateTime(2026, 2));

    expect(
      [
        for (final request in adapter.requests)
          (request.queryParameters['from'], request.queryParameters['to']),
      ],
      [
        ('2026-05-01', '2027-05-31'),
        ('2027-06-01', '2028-02-29'),
        ('2025-08-01', '2026-04-30'),
      ],
    );
  });

  test('ignores a failed background load', () async {
    var calls = 0;
    final repository = build(
      (_) => calls++ == 0
          ? FakeAdapter.json(200, {
              'data': <Object>[],
              'meta': {'next': null},
            })
          : FakeAdapter.json(500, {
              'error': {'code': 'internal_error', 'message': 'x'},
            }),
    );

    await repository.month(DateTime(2026, 11));
    await repository.month(DateTime(2027, 5));
    await pumpEventQueue();

    expect(adapter.requests, hasLength(2));
    expect(cache.hasMonth(DateTime(2027, 6)), isFalse);
  });

  test('keeps nothing loaded before the cache was cleared', () async {
    final repository = build(
      (options) => FakeAdapter.json(200, {
        'data': options.path == '/categories'
            ? [
                {
                  'id': 'cat-salary',
                  'kind': 'income',
                  'key': 'salary',
                  'name': 'Salary',
                  'position': 0,
                },
              ]
            : [entryJson('entry-1')],
        'meta': {'next': null},
      }),
    );

    final loading = repository.month(DateTime(2026, 11));
    final categories = repository.categories(EntryKind.income);
    cache.clear();
    await loading;

    expect(await categories, [salaryCategory]);
    expect(cache.hasMonth(DateTime(2026, 11)), isFalse);
    expect(cache.categories, isEmpty);
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
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': {
          'deleted_ids': ['entry-2'],
        },
      }),
    );

    await repository.delete('entry-2');

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/entries/entry-2');
  });

  test('reads entries between two days from the cached months', () async {
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': [
          {...entryJson('entry-1'), 'kind': 'expense', 'due_on': '2026-11-27'},
          {...entryJson('entry-2'), 'kind': 'expense', 'due_on': '2026-11-28'},
          {...entryJson('entry-3'), 'due_on': '2026-12-01'},
          {...entryJson('entry-4'), 'kind': 'expense', 'due_on': '2026-12-06'},
        ],
        'meta': {'next': null},
      }),
    );

    final entries = await repository.between(
      DateTime(2026, 11, 28),
      DateTime(2026, 12, 5),
      kind: EntryKind.expense,
    );

    expect(entries.map((entry) => entry.id), ['entry-2']);
    expect(adapter.requests.single.queryParameters, {
      'from': '2026-05-01',
      'to': '2027-06-30',
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
    final repository = build(
      (_) => FakeAdapter.json(200, {
        'data': {
          'deleted_ids': ['entry-2'],
        },
        'meta': {'entries': <Object>[]},
      }),
    );

    await repository.delete('entry-2', scope: EntryScope.all);

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.uri.path, '/entries/entry-2');
    expect(adapter.requests.single.uri.queryParameters, {'scope': 'all'});
  });

  group('with cached months and projection', () {
    final projectionJson = {
      'anchor': null,
      'months': [
        {
          'month': '2026-11',
          'opening_cents': 0,
          'income_cents': 500000,
          'expense_cents': 0,
          'fixed_expense_cents': 0,
          'variable_expense_cents': 0,
          'closing_cents': 500000,
          'savings_cents': 500000,
        },
      ],
      'alerts': {'first_negative_month': null, 'negative_months_count': 0},
      'last_entry_month': '2026-11',
    };
    late ApiEntryRepository repository;
    late List<ResponseBody Function(RequestOptions)> answers;

    Map<String, Object?> seriesJson(String id, int position, String dueOn) => {
      ...entryJson(id),
      'due_on': dueOn,
      'series_id': 'series-1',
      'series_position': position,
    };

    setUp(() async {
      answers = [];
      repository = build((options) => answers.removeAt(0)(options));
      answers.add(
        (_) => FakeAdapter.json(200, {
          'data': [
            entryJson('entry-1'),
            seriesJson('entry-2', 1, '2026-11-10'),
            seriesJson('entry-3', 2, '2026-12-10'),
          ],
          'meta': {'next': null},
        }),
      );
      await repository.month(DateTime(2026, 11));
      cache.storeProjection(
        Projection(
          months: [
            ProjectionMonth(
              month: DateTime(2026, 11),
              openingCents: 0,
              incomeCents: 0,
              expenseCents: 0,
              fixedExpenseCents: 0,
              variableExpenseCents: 0,
              closingCents: 0,
              savingsCents: 0,
            ),
          ],
        ),
      );
    });

    List<String> ids(DateTime month) => [
      for (final entry in cache.entriesBetween(month, Dates.lastOfMonth(month)))
        entry.id,
    ];

    test('asks for the cached projection and applies the answer', () async {
      answers.add(
        (_) => FakeAdapter.json(201, {
          'data': {...entryJson('entry-9'), 'due_on': '2026-11-01'},
          'meta': {'projection': projectionJson},
        }),
      );

      await repository.create(salary.toDraft());

      expect(adapter.requests.last.uri.queryParameters, {
        'projection_from': '2026-11',
        'projection_months': '1',
      });
      expect(ids(DateTime(2026, 11)), ['entry-9', 'entry-1', 'entry-2']);
      expect(
        cache
            .projection(DateTime(2026, 11), ProjectionPeriod.all)!
            .months
            .single
            .closingCents,
        500000,
      );
    });

    test('replaces the series with the entries it answers', () async {
      answers.add(
        (_) => FakeAdapter.json(200, {
          'data': seriesJson('entry-2', 1, '2026-11-15'),
          'meta': {
            'entries': [
              seriesJson('entry-2', 1, '2026-11-15'),
              seriesJson('entry-3', 2, '2026-12-15'),
            ],
          },
        }),
      );

      await repository.update(
        'entry-2',
        rent.toDraft(),
        scope: EntryScope.following,
      );

      expect(adapter.requests.last.uri.queryParameters, {
        'scope': 'following',
        'projection_from': '2026-11',
        'projection_months': '1',
      });
      expect(
        [
          for (final entry in cache.entriesBetween(
            DateTime(2026, 11),
            DateTime(2026, 12, 31),
          ))
            Dates.toIso(entry.dueOn),
        ],
        ['2026-11-05', '2026-11-15', '2026-12-15'],
      );
    });

    test('drops deleted entries and keeps the rest of the series', () async {
      answers.add(
        (_) => FakeAdapter.json(200, {
          'data': {
            'deleted_ids': ['entry-3'],
          },
          'meta': {
            'entries': [
              {...seriesJson('entry-2', 1, '2026-11-10'), 'series_count': 1},
            ],
          },
        }),
      );

      await repository.delete('entry-3', scope: EntryScope.following);

      expect(ids(DateTime(2026, 11)), ['entry-1', 'entry-2']);
      expect(ids(DateTime(2026, 12)), isEmpty);
      expect(
        cache
            .entriesBetween(DateTime(2026, 11), DateTime(2026, 11, 30))
            .last
            .seriesCount,
        1,
      );
    });

    test('moves a marked entry and skips months not loaded', () async {
      answers
        ..add(
          (_) => FakeAdapter.json(200, {
            'data': entryJson('entry-1', paidOn: '2026-11-05'),
          }),
        )
        ..add(
          (_) => FakeAdapter.json(200, {
            'data': {...entryJson('entry-1'), 'due_on': '2030-01-05'},
          }),
        );

      await repository.markPaid('entry-1', paidOn: DateTime(2026, 11, 5));
      expect(
        cache
            .entriesBetween(DateTime(2026, 11), DateTime(2026, 11, 30))
            .first
            .isPaid,
        isTrue,
      );

      await repository.update('entry-1', salary.toDraft());
      expect(ids(DateTime(2026, 11)), ['entry-2']);
    });
  });
}
