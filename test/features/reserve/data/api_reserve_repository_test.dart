import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/reserve/data/api_reserve_repository.dart';
import 'package:lar_em_dia/features/reserve/data/reserve_dtos.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';

import '../../../helpers/fake_adapter.dart';
import '../../../helpers/finance_fixtures.dart';
import '../../../helpers/reserve_fixtures.dart';

void main() {
  late FakeAdapter adapter;
  late FinanceCache cache;

  Map<String, Object?> valueJson(ReserveValue value) => {
    'gross_cents': value.grossCents,
    'net_cents': value.netCents,
    'invested_cents': value.investedCents,
    'yield_cents': value.yieldCents,
    'tax_cents': value.taxCents,
  };
  final treasuryJson = {
    'id': treasury.id,
    'name': 'Tesouro Selic',
    'kind': 'selic_treasury',
    'cdi_percent_bps': null,
    'annual_rate_bps': null,
    'tax_exempt': false,
    'created_at': '2026-01-05T10:00:00Z',
    'updated_at': '2026-01-05T10:00:00Z',
  };
  final idleJson = {
    ...treasuryJson,
    'id': idle.id,
    'name': 'Conta corrente',
    'kind': 'idle',
  };
  final summaryJson = {
    'totals': valueJson(reserveTotals),
    'accounts': [
      {...treasuryJson, ...valueJson(treasuryValue)},
      {...idleJson, ...valueJson(idleValue)},
    ],
    'suggestion': {
      'average_fixed_cents': 310000,
      'months_counted': 3,
      'goal_months': 6,
      'suggested_cents': 1860000,
      'coverage_months_e2': 448,
    },
    'goal': {'months': 6, 'cents': null, 'target_cents': 1860000},
    'alerts': ['below_suggestion', 'idle_money', 'something_new'],
    'rates_as_of': '2026-11-11',
  };
  final depositJson = {
    'id': depositMovement.id,
    'account_id': treasury.id,
    'kind': 'deposit',
    'moved_on': '2026-07-05',
    'amount_cents': 20000,
    'entry_id': 'entry-7',
    'created_at': '2026-07-05T10:00:00Z',
    'updated_at': '2026-07-05T10:00:00Z',
  };
  final anchorJson = {
    ...depositJson,
    'id': anchorMovement.id,
    'kind': 'anchor',
    'moved_on': '2026-01-05',
    'amount_cents': 1200000,
    'entry_id': null,
  };

  ApiReserveRepository build(FakeHandler handler) {
    adapter = FakeAdapter(handler);
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    cache = FinanceCache()..latestBalance = balance;
    return ApiReserveRepository(ApiClient(dio), cache);
  }

  ResponseBody ok(Object? data, [int status = 200]) =>
      FakeAdapter.json(status, {'data': data, 'meta': <String, dynamic>{}});

  test('reads the summary and ignores unknown alerts', () async {
    final repository = build((_) => ok(summaryJson));

    expect(await repository.summary(), reserveSummary);
    expect(adapter.requests.single.path, '/reserve');
  });

  test('reads an empty summary without a suggestion', () async {
    final repository = build(
      (_) => ok({
        'totals': valueJson(ReserveValue.empty),
        'accounts': <Object?>[],
        'suggestion': null,
        'goal': {'months': 6, 'cents': null, 'target_cents': null},
        'alerts': <Object?>[],
        'rates_as_of': null,
      }),
    );

    expect(await repository.summary(), emptyReserve);
  });

  test('updates the goal', () async {
    final repository = build((_) => ok(summaryJson));

    await repository.updateGoal(months: 8, cents: 2000000);

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/reserve');
    expect(request.data, {'goal_months': 8, 'goal_cents': 2000000});
  });

  test('reads the projection for a period', () async {
    final repository = build(
      (_) => ok({
        'months': [
          {
            'month': '2026-11',
            'gross_cents': 1400000,
            'net_cents': 1390000,
            'accounts': <Object?>[],
          },
        ],
        'assumptions': {
          'selic_target_e8': 13750000,
          'cdi_estimate_e8': 13650000,
          'savings_monthly_e8': 500000,
          'rates_as_of': '2026-11-11',
          'holidays_ignored': true,
          'iof_ignored': true,
        },
      }),
    );

    expect(
      await repository.projection(24),
      reserveProjection.copyWith(months: [reserveProjection.months.first]),
    );
    expect(adapter.requests.single.path, '/reserve/projection');
    expect(adapter.requests.single.queryParameters, {'months': 24});
  });

  test('creates an account with only the rate of its kind', () async {
    final repository = build(
      (_) => ok({
        ...treasuryJson,
        'id': cdb.id,
        'name': 'CDB do banco',
        'kind': 'cdb',
        'cdi_percent_bps': 11000,
        'tax_exempt': true,
      }, 201),
    );

    final created = await repository.createAccount(
      const ReserveAccountDraft(
        name: 'CDB do banco',
        kind: ReserveKind.cdb,
        cdiPercentBps: 11000,
        annualRateBps: 1200,
        taxExempt: true,
      ),
    );

    expect(created, cdb);
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/reserve_accounts');
    expect(request.data, {
      'name': 'CDB do banco',
      'kind': 'cdb',
      'cdi_percent_bps': 11000,
      'annual_rate_bps': null,
      'tax_exempt': true,
    });
  });

  test('updates an account and drops the exemption it cannot have', () async {
    final repository = build((_) => ok(treasuryJson));

    await repository.updateAccount(
      treasury.id,
      treasuryDraft.copyWith(cdiPercentBps: 10000, taxExempt: true),
    );

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/reserve_accounts/${treasury.id}');
    expect(request.data, {
      'name': 'Tesouro Selic',
      'kind': 'selic_treasury',
      'cdi_percent_bps': null,
      'annual_rate_bps': null,
      'tax_exempt': false,
    });
  });

  test('deletes an account and clears the finance cache', () async {
    final repository = build((_) => ok({'deleted_id': treasury.id}));

    await repository.deleteAccount(treasury.id);

    expect(adapter.requests.single.method, 'DELETE');
    expect(adapter.requests.single.path, '/reserve_accounts/${treasury.id}');
    expect(cache.latestBalanceKnown, isFalse);
  });

  test('lists the movements of an account', () async {
    final repository = build((_) => ok([anchorJson, depositJson]));

    expect(await repository.movements(treasury.id), [
      anchorMovement,
      depositMovement,
    ]);
    expect(adapter.requests.single.path, '/reserve_movements');
    expect(adapter.requests.single.queryParameters, {
      'account_id': treasury.id,
      'limit': 100,
    });
  });

  test('creates a deposit and clears the cache when it debits', () async {
    final repository = build((_) => ok(depositJson, 201));

    expect(await repository.createMovement(depositDraft), depositMovement);
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/reserve_movements');
    expect(request.data, {
      'account_id': treasury.id,
      'kind': 'deposit',
      'moved_on': '2026-07-05',
      'amount_cents': 20000,
      'debit_balance': true,
    });
    expect(cache.latestBalanceKnown, isFalse);
  });

  test('never debits an anchor and keeps the cache', () async {
    final repository = build((_) => ok(anchorJson, 201));

    await repository.createMovement(
      depositDraft.copyWith(kind: ReserveMovementKind.anchor),
    );

    expect((adapter.requests.single.data as Map)['debit_balance'], isFalse);
    expect(cache.latestBalanceKnown, isTrue);
  });

  test('updates a linked movement and clears the cache', () async {
    final repository = build((_) => ok(depositJson));

    await repository.updateMovement(
      depositMovement,
      depositDraft.copyWith(debitBalance: false),
    );

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/reserve_movements/${depositMovement.id}');
    expect((request.data as Map)['debit_balance'], isFalse);
    expect(cache.latestBalanceKnown, isFalse);
  });

  test('deletes a movement and clears the cache only when linked', () async {
    final repository = build((_) => ok({'deleted_id': 'x'}));

    await repository.deleteMovement(anchorMovement);
    expect(cache.latestBalanceKnown, isTrue);

    await repository.deleteMovement(depositMovement);
    expect(
      adapter.requests.last.path,
      '/reserve_movements/${depositMovement.id}',
    );
    expect(cache.latestBalanceKnown, isFalse);
  });

  test('maps every wire value', () {
    for (final kind in ReserveKind.values) {
      expect(ReserveWire.parseKind(ReserveWire.kind(kind)), kind);
    }
    for (final kind in ReserveMovementKind.values) {
      expect(ReserveWire.parseMovementKind(kind.name), kind);
    }
    expect(ReserveWire.parseAlerts(['no_reserve', 'idle_money']), [
      ReserveAlert.noReserve,
      ReserveAlert.idleMoney,
    ]);
  });
}
