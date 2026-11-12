import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/demo/demo_adapter.dart';
import 'package:lar_em_dia/demo/demo_database.dart';
import 'package:lar_em_dia/demo/demo_investments.dart';
import 'package:lar_em_dia/demo/demo_seed.dart';

void main() {
  group('DemoLedger follows the API rules', () {
    var sequence = 0;
    Row transaction(
      String kind,
      int quantity, {
      int? price,
      int fees = 0,
      String on = '2026-01-10',
    }) => {
      'kind': kind,
      'quantity': quantity,
      'price_cents': price,
      'fees_cents': fees,
      'traded_on': on,
      'created_at':
          '2026-01-01T00:00:00.${(++sequence).toString().padLeft(6, '0')}Z',
    };

    test('averages buys with fees and keeps the average on sales', () {
      final ledger = DemoLedger([
        transaction('buy', 100, price: 1000, fees: 500),
        transaction('buy', 50, price: 1300, fees: 500),
        transaction('sell', 60, price: 1500, fees: 300, on: '2026-02-10'),
      ]);
      final states = ledger.states;

      expect(states[1].quantity, 150);
      expect(states[1].costCents, 166000);
      expect(states[1].averagePriceE8, 1106666667);
      expect(ledger.state.quantity, 90);
      expect(ledger.state.costCents, 99600);
      expect(ledger.state.averagePriceE8, 1106666667);
      expect(ledger.state.realizedCents, 89700 - 66400);
      expect(ledger.state.contributedCents, 166000 - 89700);
    });

    test('changes shares but not cost on corporate events', () {
      final ledger = DemoLedger([
        transaction('buy', 100, price: 1000),
        transaction('split', 100, on: '2026-02-01'),
        transaction('reverse_split', 150, on: '2026-03-01'),
        transaction('bonus', 10, on: '2026-04-01'),
      ]);

      expect(
        [for (final state in ledger.states) state.quantity],
        [100, 200, 50, 60],
      );
      expect(ledger.state.costCents, 100000);
      expect(ledger.stateOn('2026-02-15').quantity, 200);
      expect(ledger.stateOn('2025-12-31').quantity, 0);
    });

    test('orders by date and creation, and zeroes the cost when sold out', () {
      final ledger = DemoLedger([
        transaction('sell', 10, price: 2000, on: '2026-03-01'),
        transaction('buy', 10, price: 1000),
      ]);

      expect(ledger.state.quantity, 0);
      expect(ledger.state.costCents, 0);
      expect(ledger.state.averagePriceE8, 0);
      expect(ledger.state.realizedCents, 10000);
      expect(ledger.shortfall, isFalse);
    });

    test('flags a timeline that goes below zero', () {
      expect(
        DemoLedger([transaction('sell', 1, price: 100)]).shortfall,
        isTrue,
      );
      expect(
        DemoLedger([
          transaction('buy', 10, price: 100),
          transaction('reverse_split', 20),
        ]).state.costCents,
        0,
      );
    });
  });

  group('DemoServer investments', () {
    late DemoServer server;
    late DemoDatabase database;

    setUp(() {
      database = DemoSeed.build(DateTime(2026, 11, 14));
      server = DemoServer(database)
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
      authorization: 'Bearer ${DemoServer.accessToken}',
    );

    Object? data(DemoResponse response) => response.body!['data'];

    Map<String, Object?> error(DemoResponse response) =>
        response.body!['error']! as Map<String, Object?>;

    test('searches the catalog and shows an asset with its quote', () {
      final found = data(call('GET', '/assets', query: {'q': 'log'}))! as List;
      expect(
        [for (final row in found) (row as Map)['ticker']],
        ['BTLG11', 'HGLG11'],
      );
      expect(
        data(call('GET', '/assets', query: {'q': 'pe'}))! as List,
        hasLength(1),
      );
      expect(data(call('GET', '/assets'))! as List, hasLength(12));

      final asset = data(call('GET', '/assets/hglg11'))! as Map;
      expect(asset['ticker'], 'HGLG11');
      expect(asset['quote'], containsPair('quoted_on', '2026-11-13'));
      expect(call('GET', '/assets/NOPE3').status, 404);
    });

    test('quotes the last weekday before today', () {
      final monday = DemoSeed.build(DateTime(2026, 11, 16)).investments;
      expect(monday.lastTradingDay, DateTime(2026, 11, 13));
    });

    test('seeds a family portfolio split between income and growth', () {
      final portfolio = data(call('GET', '/portfolio'))! as Map;
      final positions = portfolio['positions']! as List;
      expect(
        [for (final row in positions) (row as Map)['ticker']],
        ['HGLG11', 'ITSA4', 'KNRI11', 'MXRF11', 'TAEE11', 'WEGE3'],
      );
      final goals = portfolio['goals']! as Map;
      final totals = portfolio['totals']! as Map;
      expect(
        (goals['income']! as Map)['market_value_cents']! as int,
        greaterThan(0),
      );
      expect(
        ((goals['income']! as Map)['market_value_cents']! as int) +
            ((goals['growth']! as Map)['market_value_cents']! as int),
        totals['market_value_cents'],
      );
      expect(totals['realized_cents']! as int, isNot(0));
      final taee = positions.cast<Map<String, Object?>>().firstWhere(
        (row) => row['ticker'] == 'TAEE11',
      );
      expect(taee['goal'], 'income');

      final growth =
          data(call('GET', '/portfolio', query: {'goal': 'growth'}))! as Map;
      expect(growth['positions'], hasLength(2));

      final months = data(call('GET', '/portfolio/history'))! as List;
      expect(months, hasLength(25));
      expect((months.first as Map)['month'], '2024-11');
      expect((months.last as Map)['month'], '2026-11');
      expect(
        (months.last as Map)['contributed_cents'],
        totals['contributed_cents'],
      );
      expect(
        (months.last as Map)['market_value_cents'],
        totals['market_value_cents'],
      );
    });

    test('creates a buy that debits the balance and edits it away', () {
      final created = call(
        'POST',
        '/investment_transactions',
        body: {
          'ticker': 'petr4',
          'kind': 'buy',
          'traded_on': '2026-11-10',
          'quantity': 10,
          'price_cents': 3700,
          'fees_cents': 100,
          'debit_balance': true,
        },
      );
      expect(created.status, 201);
      final row = data(created)! as Map;
      expect(row['ticker'], 'PETR4');
      expect(row.containsKey('debit_balance'), isFalse);
      final entry = database.findEntry(row['entry_id']! as String);
      expect(entry['amount_cents'], 37100);
      expect(entry['description'], 'PETR4 × 10');
      expect(entry['status'], 'paid');
      expect(database.investments.positionGoals['PETR4'], 'growth');

      final id = row['id']! as String;
      expect(data(call('GET', '/investment_transactions/$id')), row);
      final listed =
          data(
                call(
                  'GET',
                  '/investment_transactions',
                  query: {'ticker': 'PETR4'},
                ),
              )!
              as List;
      expect(listed, [row]);

      final updated =
          data(
                call(
                  'PATCH',
                  '/investment_transactions/$id',
                  body: {'quantity': 12, 'debit_balance': false},
                ),
              )!
              as Map;
      expect(updated['quantity'], 12);
      expect(updated['entry_id'], isNull);
      expect(
        database.entries.where((e) => e['id'] == row['entry_id']),
        isEmpty,
      );

      final again =
          data(
                call(
                  'PATCH',
                  '/investment_transactions/$id',
                  body: {'fees_cents': 0},
                ),
              )!
              as Map;
      expect(again['entry_id'], isNull);

      expect(call('DELETE', '/investment_transactions/$id').status, 200);
      expect(database.investments.positionGoals.containsKey('PETR4'), isFalse);
      expect(call('GET', '/investment_transactions/$id').status, 404);
    });

    test('records a sale as income and keeps the entry on edits', () {
      final sold =
          data(
                call(
                  'POST',
                  '/investment_transactions',
                  body: {
                    'ticker': 'HGLG11',
                    'kind': 'sell',
                    'traded_on': '2026-11-12',
                    'quantity': 2,
                    'price_cents': 16000,
                    'debit_balance': true,
                    'goal': 'growth',
                  },
                ),
              )!
              as Map;
      final entry = database.findEntry(sold['entry_id']! as String);
      expect(entry['kind'], 'income');
      expect(entry['amount_cents'], 32000);
      expect(database.investments.positionGoals['HGLG11'], 'income');

      final edited =
          data(
                call(
                  'PATCH',
                  '/investment_transactions/${sold['id']}',
                  body: {'price_cents': 17000},
                ),
              )!
              as Map;
      expect(
        database.findEntry(edited['entry_id']! as String)['amount_cents'],
        34000,
      );
    });

    test('refuses invalid transactions with the API codes', () {
      final invalid = call(
        'POST',
        '/investment_transactions',
        body: {
          'ticker': 'NOPE3',
          'kind': 'split',
          'traded_on': '2026-12-01',
          'quantity': 0,
          'price_cents': 10,
          'fees_cents': 5,
          'debit_balance': true,
        },
      );
      expect(invalid.status, 422);
      expect(error(invalid)['details'], {
        'ticker': [
          {'code': 'unknown_asset', 'message': 'unknown_asset'},
        ],
        'quantity': [
          {'code': 'greater_than', 'message': 'greater_than'},
        ],
        'traded_on': [
          {'code': 'in_future', 'message': 'in_future'},
        ],
        'price_cents': [
          {'code': 'only_for_trades', 'message': 'only_for_trades'},
        ],
        'fees_cents': [
          {'code': 'only_for_trades', 'message': 'only_for_trades'},
        ],
        'debit_balance': [
          {'code': 'only_for_trades', 'message': 'only_for_trades'},
        ],
      });

      final missing =
          error(
                call(
                  'POST',
                  '/investment_transactions',
                  body: {
                    'ticker': 'PETR4',
                    'kind': 'swap',
                    'quantity': 1,
                    'fees_cents': -1,
                  },
                ),
              )['details']!
              as Map;
      expect(missing.keys, ['kind', 'traded_on', 'fees_cents']);

      final unpriced =
          error(
                call(
                  'POST',
                  '/investment_transactions',
                  body: {
                    'ticker': 'PETR4',
                    'kind': 'buy',
                    'traded_on': '2026-11-01',
                    'quantity': 1,
                  },
                ),
              )['details']!
              as Map;
      expect(unpriced.keys, ['price_cents']);

      final oversold = error(
        call(
          'POST',
          '/investment_transactions',
          body: {
            'ticker': 'PETR4',
            'kind': 'sell',
            'traded_on': '2026-11-01',
            'quantity': 1,
            'price_cents': 100,
          },
        ),
      );
      expect(oversold['details'], {
        'quantity': [
          {'code': 'insufficient_quantity', 'message': 'insufficient_quantity'},
        ],
      });
    });

    test('refuses a deletion that leaves a later sale uncovered', () {
      final itsa = database.investments
          .transactionsOf('ITSA4')
          .where((row) => row['kind'] == 'buy')
          .toList();
      for (final row in itsa.skip(3).toList().reversed) {
        expect(
          call('DELETE', '/investment_transactions/${row['id']}').status,
          200,
        );
      }
      final refused = call(
        'DELETE',
        '/investment_transactions/${itsa.first['id']}',
      );
      expect(refused.status, 422);
      expect(error(refused)['code'], 'insufficient_quantity');
    });

    test('changes the goal of a held position only', () {
      final changed = call(
        'PATCH',
        '/investment_positions/hglg11',
        body: {'goal': 'growth'},
      );
      expect(data(changed), containsPair('goal', 'growth'));
      expect(database.investments.positionGoals['HGLG11'], 'growth');
      expect(
        call(
          'PATCH',
          '/investment_positions/HGLG11',
          body: {'goal': 'x'},
        ).status,
        422,
      );
      expect(
        call(
          'PATCH',
          '/investment_positions/PETR4',
          body: {'goal': 'growth'},
        ).status,
        404,
      );
    });

    test('has no history without transactions', () {
      final empty = DemoDatabase(today: DateTime(2026, 11, 14));
      expect(empty.investments.history(), isEmpty);
      expect(empty.investments.portfolio()['positions'], isEmpty);
    });

    test('keeps at most 120 months of history', () {
      final old = DemoSeed.build(DateTime(2026, 11, 14));
      old.investments.createTransaction({
        'ticker': 'PETR4',
        'kind': 'buy',
        'traded_on': '2010-01-04',
        'quantity': 1,
        'price_cents': 100,
      });
      final months = old.investments.history();
      expect(months, hasLength(120));
      expect(months.first['month'], '2016-12');
    });
  });
}
