import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/projection/data/api_projection_repository.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';

import '../../../helpers/fake_adapter.dart';
import '../../../helpers/finance_fixtures.dart';

void main() {
  late FakeAdapter adapter;

  ApiProjectionRepository build(Object? data) {
    adapter = FakeAdapter((_) => FakeAdapter.json(200, {'data': data}));
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    return ApiProjectionRepository(ApiClient(dio));
  }

  Map<String, Object?> monthJson(ProjectionMonth month, String key) => {
    'month': key,
    'opening_cents': month.openingCents,
    'income_cents': month.incomeCents,
    'expense_cents': month.expenseCents,
    'fixed_expense_cents': month.fixedExpenseCents,
    'variable_expense_cents': month.variableExpenseCents,
    'closing_cents': month.closingCents,
    'savings_cents': month.savingsCents,
    'expense_by_category': [
      for (final amount in month.expenseByCategory)
        {
          'category_key': amount.categoryKey,
          'amount_cents': amount.amountCents,
        },
    ],
  };

  test('reads the anchor and the months from the given month', () async {
    final repository = build({
      'anchor': {'amount_cents': 123456, 'as_of': '2026-11-03'},
      'months': [
        monthJson(novemberProjection, '2026-11'),
        monthJson(decemberProjection, '2026-12'),
      ],
      'alerts': {'first_negative_month': '2026-12', 'negative_months_count': 1},
      'last_entry_month': '2027-03',
    });

    final result = await repository.fetch(from: DateTime(2026, 11, 20));

    expect(result, projection);
    expect(adapter.requests.single.path, '/projection');
    expect(adapter.requests.single.queryParameters, {
      'from': '2026-11',
      'months': '12',
    });
  });

  test('reads a projection without an anchor', () async {
    final repository = build({'anchor': null, 'months': <Object?>[]});

    final result = await repository.fetch(
      from: november,
      period: ProjectionPeriod.all,
    );

    expect(result, const Projection(months: []));
    expect(adapter.requests.single.queryParameters['months'], 'all');
  });

  test('simulates plans and reads both projections', () async {
    final body = {
      'months': [monthJson(novemberProjection, '2026-11')],
    };
    final repository = build({'baseline': body, 'simulated': body});

    final result = await repository.simulate(
      [tvPlan, freelancePlan, sofaPlan],
      from: DateTime(2026, 11, 20),
      months: 6,
    );

    expect(result.baseline.months, [novemberProjection]);
    expect(result.differenceCents, 0);
    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/projection/simulation');
    final sent = request.data as Map<String, Object?>;
    expect(sent['from'], '2026-11');
    expect(sent['months'], 6);
    final [tv, freelance, sofa] = (sent['entries']! as List<Object?>)
        .cast<Map<String, Object?>>();
    expect(tv, containsPair('amount_cents', 300000));
    expect(tv.containsKey('entries_count'), isFalse);
    expect(freelance, containsPair('entries_count', 3));
    expect(freelance, containsPair('direction', 'forward'));
    expect(sofa, containsPair('kind', 'installments'));
    expect(sofa, containsPair('total_cents', 300000));
    expect(sofa.containsKey('amount_cents'), isFalse);
  });
}
