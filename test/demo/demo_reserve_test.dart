import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/demo/demo_adapter.dart';
import 'package:lar_em_dia/demo/demo_database.dart';
import 'package:lar_em_dia/demo/demo_reserve.dart';
import 'package:lar_em_dia/demo/demo_seed.dart';

void main() {
  group('DemoReserve follows the API rules', () {
    late DemoDatabase database;
    late DemoReserve reserve;

    setUp(() {
      database = DemoSeed.build(DateTime(2026, 11, 3));
      reserve = database.reserve;
    });

    Row account(String kind, {int? cdi, int? rate, bool exempt = false}) =>
        reserve.createAccount({
          'name': ' Pote ',
          'kind': kind,
          'cdi_percent_bps': cdi,
          'annual_rate_bps': rate,
          'tax_exempt': exempt,
        });

    Row move(
      Row target,
      String kind,
      int cents, {
      String on = '2025-11-03',
      bool debit = false,
    }) => reserve.createMovement({
      'account_id': target['id'],
      'kind': kind,
      'moved_on': on,
      'amount_cents': cents,
      'debit_balance': debit,
    });

    Map<String, Object?> accountIn(Row summary, Row target) =>
        (summary['accounts']! as List<Object?>).cast<Row>().firstWhere(
          (row) => row['id'] == target['id'],
        );

    test('counts weekdays and picks the regressive tax bracket', () {
      expect(
        DemoReserve.weekdays(DateTime(2026, 11, 2), DateTime(2026, 11, 15)),
        10,
      );
      expect(
        DemoReserve.weekdays(DateTime(2026, 11, 7), DateTime(2026, 11, 6)),
        0,
      );
      expect(DemoReserve.taxRate(180), 0.225);
      expect(DemoReserve.taxRate(360), 0.2);
      expect(DemoReserve.taxRate(720), 0.175);
      expect(DemoReserve.taxRate(721), 0.15);
    });

    test('summarizes the seeded accounts with a suggestion', () {
      final summary = reserve.summary();
      final suggestion = summary['suggestion']! as Row;

      expect(summary['accounts'], hasLength(2));
      expect(suggestion['average_fixed_cents'], 380000);
      expect(suggestion['months_counted'], 3);
      expect(suggestion['suggested_cents'], 2280000);
      expect(summary['alerts'], ['below_suggestion', 'idle_money']);
      expect(summary['rates_as_of'], '2026-11-02');
      final totals = summary['totals']! as Row;
      expect(totals['invested_cents'], 1550000);
      expect(totals['gross_cents']! as int, greaterThan(1550000));
      expect(
        totals['net_cents'],
        (totals['gross_cents']! as int) - (totals['tax_cents']! as int),
      );
    });

    test('grows each kind of account from its own rate', () {
      final selic = account('selic_treasury');
      final cdb = account('cdb', cdi: 12000, exempt: true);
      final fixed = account('fixed_rate', rate: 2000);
      final savings = account('savings');
      final idle = account('idle');
      for (final target in [selic, cdb, fixed, savings, idle]) {
        move(target, 'deposit', 100000);
      }
      final summary = reserve.summary();
      int gross(Row target) =>
          accountIn(summary, target)['gross_cents']! as int;
      int tax(Row target) => accountIn(summary, target)['tax_cents']! as int;

      expect(gross(selic), inInclusiveRange(113000, 114500));
      expect(gross(cdb), greaterThan(gross(selic)));
      expect(gross(fixed), inInclusiveRange(119000, 121000));
      expect(gross(savings), 106168);
      expect(gross(idle), 100000);
      expect(tax(selic), ((gross(selic) - 100000) * 0.175).round());
      expect(tax(cdb), 0);
      expect(tax(savings), 0);
    });

    test('restarts the account at an anchor and withdraws FIFO', () {
      final target = account('idle');
      move(target, 'deposit', 50000, on: '2026-01-05');
      move(target, 'anchor', 30000, on: '2026-02-05');
      move(target, 'deposit', 20000, on: '2026-03-05');
      move(target, 'withdrawal', 40000, on: '2026-04-05');

      final value = accountIn(reserve.summary(), target);
      expect(value['gross_cents'], 10000);
      expect(value['invested_cents'], 10000);
    });

    test('refuses a withdrawal above the account and its deletion', () {
      final target = account('idle');
      final deposit = move(target, 'deposit', 10000, on: '2026-01-05');

      expect(
        () => move(target, 'withdrawal', 20000, on: '2026-02-05'),
        throwsA(
          isA<DemoValidationError>().having(
            (error) => error.details,
            'details',
            {
              'amount_cents': ['insufficient_reserve'],
            },
          ),
        ),
      );
      move(target, 'withdrawal', 10000, on: '2026-02-05');
      expect(
        () => reserve.deleteMovement(deposit['id']! as String),
        throwsA(isA<DemoUnprocessable>()),
      );
    });

    test('links debited movements to entries and removes them', () {
      final target = account('selic_treasury');
      final before = database.entries.length;
      final deposit = move(target, 'deposit', 10000, debit: true);
      expect(deposit['entry_id'], isNotNull);
      expect(database.entries, hasLength(before + 1));

      final kept = reserve.updateMovement(deposit['id']! as String, {
        'amount_cents': 12000,
      });
      expect(kept['entry_id'], isNotNull);
      expect(
        database.findEntry(kept['entry_id']! as String)['amount_cents'],
        12000,
      );

      final unlinked = reserve.updateMovement(deposit['id']! as String, {
        'debit_balance': false,
      });
      expect(unlinked['entry_id'], isNull);
      expect(database.entries, hasLength(before));

      move(target, 'withdrawal', 5000, on: '2025-12-03', debit: true);
      expect(database.entries, hasLength(before + 1));
      reserve.deleteAccount(target['id']! as String);
      expect(database.entries, hasLength(before));
      expect(
        () => reserve.findAccount(target['id']! as String),
        throwsA(isA<DemoNotFound>()),
      );
    });

    test('validates accounts like the API', () {
      DemoValidationError? errorOf(void Function() change) {
        try {
          change();
          return null;
        } on DemoValidationError catch (error) {
          return error;
        }
      }

      expect(errorOf(() => reserve.createAccount({'kind': 'cdb'}))!.details, {
        'name': ['blank'],
        'cdi_percent_bps': ['rate_required'],
      });
      expect(
        errorOf(
          () => reserve.createAccount({
            'name': 'x' * 101,
            'kind': 'gold',
            'annual_rate_bps': 0,
          }),
        )!.details,
        {
          'name': ['too_long'],
          'kind': ['inclusion'],
          'annual_rate_bps': ['less_than_or_equal_to'],
        },
      );
      final target = account('cdb', cdi: 10000);
      final updated = reserve.updateAccount(target['id']! as String, {
        'name': 'Renamed',
      });
      expect(updated['name'], 'Renamed');
      expect(updated['cdi_percent_bps'], 10000);
      expect(
        errorOf(
          () => reserve.updateAccount(target['id']! as String, {
            'kind': 'savings',
          }),
        )!.details,
        {
          'cdi_percent_bps': ['rate_not_allowed'],
        },
      );
    });

    test('validates movements like the API', () {
      final target = account('idle');
      Map<String, List<String>> errorsOf(Row body) {
        try {
          reserve.createMovement({'account_id': target['id'], ...body});
          return const {};
        } on DemoValidationError catch (error) {
          return error.details;
        }
      }

      expect(errorsOf({'kind': 'gift', 'amount_cents': 0}), {
        'kind': ['inclusion'],
        'moved_on': ['blank'],
        'amount_cents': ['greater_than'],
      });
      expect(
        errorsOf({
          'kind': 'anchor',
          'moved_on': '2026-12-01',
          'amount_cents': 0,
          'debit_balance': true,
        }),
        {
          'moved_on': ['in_future'],
          'debit_balance': ['anchor_not_allowed'],
        },
      );
      expect(
        () => reserve.createMovement({'account_id': 'nope'}),
        throwsA(isA<DemoValidationError>()),
      );
      final anchor = move(target, 'anchor', 0);
      expect(
        () => reserve.updateMovement(anchor['id']! as String, {
          'account_id': 'other',
        }),
        throwsA(isA<DemoValidationError>()),
      );
      expect(() => reserve.findMovement('nope'), throwsA(isA<DemoNotFound>()));
    });

    test('updates and validates the goal', () {
      final summary = reserve.updateGoal({
        'goal_months': 3,
        'goal_cents': 1000000,
      });
      expect(summary['goal'], {
        'months': 3,
        'cents': 1000000,
        'target_cents': 1000000,
      });
      expect(summary['alerts'], ['idle_money']);
      expect(
        reserve.updateGoal({'goal_cents': null})['goal'],
        containsPair('target_cents', 1140000),
      );
      expect(
        () => reserve.updateGoal({'goal_months': 25, 'goal_cents': 0}),
        throwsA(isA<DemoValidationError>()),
      );
    });

    test('raises no_reserve without accounts and nothing without expenses', () {
      for (final row in [...reserve.accounts]) {
        reserve.deleteAccount(row['id']! as String);
      }
      expect(reserve.summary()['alerts'], ['no_reserve']);

      final empty = DemoDatabase(today: DateTime(2026, 11, 3)).reserve;
      expect(empty.summary()['suggestion'], isNull);
      expect(empty.summary()['alerts'], isEmpty);
    });

    test('projects the net value into the cash-flow projection', () {
      final months = reserve.projection(3)['months']! as List<Object?>;
      final first = months.first! as Row;
      final last = months.last! as Row;

      expect(months, hasLength(3));
      expect(
        last['gross_cents']! as int,
        greaterThan(first['gross_cents']! as int),
      );
      expect(first['accounts'], hasLength(2));
      final cashFlow = database.projection(from: DateTime(2026, 11), months: 1);
      expect(cashFlow.single['reserve_cents'], first['net_cents']);
    });
  });

  group('DemoServer reserve', () {
    late DemoServer server;
    const bearer = 'Bearer ${DemoServer.accessToken}';

    setUp(() {
      server = DemoServer(DemoSeed.build(DateTime(2026, 11, 3)))
        ..handle(
          'POST',
          '/auth/login',
          body: {'email': DemoSeed.email, 'password': DemoSeed.password},
        );
    });

    DemoResponse call(
      String method,
      String path, {
      Map<String, String> query = const {},
      Map<String, Object?> body = const {},
    }) => server.handle(
      method,
      path,
      query: query,
      body: body,
      authorization: bearer,
    );

    Object? data(DemoResponse response) => response.body!['data'];

    test('serves the summary, the goal and the projection', () {
      expect(call('GET', '/reserve').status, 200);
      expect(
        (data(call('PATCH', '/reserve', body: {'goal_months': 12}))!
            as Row)['goal'],
        containsPair('months', 12),
      );
      final projection = call(
        'GET',
        '/reserve/projection',
        query: {'months': '24'},
      );
      expect((data(projection)! as Row)['months'], hasLength(24));
      expect(
        (data(call('GET', '/reserve/projection'))! as Row)['months'],
        hasLength(12),
      );
      expect(
        call('GET', '/reserve/projection', query: {'months': '61'}).status,
        400,
      );
    });

    test('serves the accounts and their movements', () {
      final created = call(
        'POST',
        '/reserve_accounts',
        body: {'name': 'Poupança', 'kind': 'savings'},
      );
      expect(created.status, 201);
      final id = (data(created)! as Row)['id']! as String;
      expect(call('GET', '/reserve_accounts').status, 200);
      expect(call('GET', '/reserve_accounts/$id').status, 200);
      expect(
        call('PATCH', '/reserve_accounts/$id', body: {'name': 'Nova'}).status,
        200,
      );

      final movement = call(
        'POST',
        '/reserve_movements',
        body: {
          'account_id': id,
          'kind': 'deposit',
          'moved_on': '2026-11-03',
          'amount_cents': 1000,
        },
      );
      expect(movement.status, 201);
      final movementId = (data(movement)! as Row)['id']! as String;
      expect(
        data(call('GET', '/reserve_movements', query: {'account_id': id})),
        hasLength(1),
      );
      expect(call('GET', '/reserve_movements/$movementId').status, 200);
      expect(
        call(
          'PATCH',
          '/reserve_movements/$movementId',
          body: {'amount_cents': 2000},
        ).status,
        200,
      );
      expect(data(call('DELETE', '/reserve_movements/$movementId')), {
        'deleted_id': movementId,
      });
      expect(data(call('DELETE', '/reserve_accounts/$id')), {'deleted_id': id});
      expect(call('GET', '/reserve_accounts/$id').status, 404);
    });
  });
}
