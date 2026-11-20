import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/allocation/data/api_allocation_repository.dart';
import 'package:lar_em_dia/features/allocation/domain/allocation.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';

import '../../../helpers/allocation_fixtures.dart';
import '../../../helpers/fake_adapter.dart';
import '../../../helpers/finance_fixtures.dart';

void main() {
  late FakeAdapter adapter;
  late FinanceCache cache;

  final targetJson = {
    'id': 'target-1',
    'name': 'Renda fixa',
    'mode': 'percent',
    'amount_cents': null,
    'percent_bps': 1000,
    'reserve_account_id': null,
    'position': 1,
    'created_at': '2026-11-20T10:00:00Z',
    'updated_at': '2026-11-20T10:00:00Z',
  };
  final planJson = {
    'month': '2026-11',
    'closing_cents': 8400,
    'base_cents': 9400,
    'used_cents': 1000,
    'planned_cents': 9400,
    'unallocated_cents': 0,
    'items': [
      {
        'target_id': 'target-1',
        'name': 'Renda fixa',
        'mode': 'percent',
        'amount_cents': 940,
        'percent_bps': 1000,
        'reserve_account_id': null,
        'used': false,
        'allocation_id': null,
        'used_on': null,
      },
      {
        'target_id': 'target-2',
        'name': 'Caridade',
        'mode': 'fixed',
        'amount_cents': 1000,
        'percent_bps': null,
        'reserve_account_id': null,
        'used': true,
        'allocation_id': 'allocation-1',
        'used_on': '2026-11-20',
      },
      {
        'target_id': 'target-3',
        'name': 'Reserva',
        'mode': 'remainder',
        'amount_cents': 7460,
        'percent_bps': null,
        'reserve_account_id': 'reserve-account-1',
        'used': false,
        'allocation_id': null,
        'used_on': null,
      },
    ],
  };

  ApiAllocationRepository build(FakeHandler handler) {
    adapter = FakeAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    cache = FinanceCache()..latestBalance = balance;
    return ApiAllocationRepository(ApiClient(dio), cache);
  }

  ResponseBody ok(Object? data, [int status = 200]) =>
      FakeAdapter.json(status, {'data': data, 'meta': <String, dynamic>{}});

  test('reads the plan of a month', () async {
    final repository = build((_) => ok(planJson));

    expect(await repository.plan(DateTime(2026, 11, 15)), novemberPlan);
    expect(adapter.requests.single.path, '/allocation_plan');
    expect(adapter.requests.single.queryParameters, {'month': '2026-11'});
  });

  test('lists the targets', () async {
    final repository = build((_) => ok([targetJson]));

    expect(await repository.targets(), [fixedIncome]);
    expect(adapter.requests.single.path, '/allocation_targets');
  });

  test('creates a target with only the value of its mode', () async {
    final repository = build((_) => ok(targetJson, 201));

    expect(
      await repository.createTarget(
        targetDraft.copyWith(amountCents: 500, reserveAccountId: 'account'),
      ),
      fixedIncome,
    );
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.data, {
      'name': 'Renda fixa',
      'mode': 'percent',
      'amount_cents': null,
      'percent_bps': 1000,
      'reserve_account_id': 'account',
    });
  });

  test('updates a target', () async {
    final repository = build((_) => ok(targetJson));

    await repository.updateTarget(
      'target-1',
      const AllocationTargetDraft(
        name: 'Caridade',
        mode: AllocationMode.fixed,
        amountCents: 1000,
        percentBps: 800,
      ),
    );

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/allocation_targets/target-1');
    expect(request.data, {
      'name': 'Caridade',
      'mode': 'fixed',
      'amount_cents': 1000,
      'percent_bps': null,
      'reserve_account_id': null,
    });
  });

  test('deletes a target without touching the balance', () async {
    final repository = build((_) => ok(null));

    await repository.deleteTarget('target-1');

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/allocation_targets/target-1');
    expect(cache.latestBalance, balance);
  });

  test('uses a target and clears the cached balance', () async {
    final repository = build((_) => ok({'id': 'allocation-1'}, 201));

    await repository.use('target-1', DateTime(2026, 11), amountCents: 900);

    final request = adapter.requests.single;
    expect(request.path, '/allocations');
    expect(request.data, {
      'target_id': 'target-1',
      'month': '2026-11',
      'amount_cents': 900,
    });
    expect(cache.latestBalance, isNull);
  });

  test('uses the planned amount when none is given', () async {
    final repository = build((_) => ok({'id': 'allocation-1'}, 201));

    await repository.use('target-1', DateTime(2026, 11));

    expect(adapter.requests.single.data, {
      'target_id': 'target-1',
      'month': '2026-11',
    });
  });

  test('undoes an allocation and clears the cached balance', () async {
    final repository = build((_) => ok(null));

    await repository.undo('allocation-1');

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/allocations/allocation-1');
    expect(cache.latestBalance, isNull);
  });
}
