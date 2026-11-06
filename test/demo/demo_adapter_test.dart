import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/demo/demo_adapter.dart';
import 'package:lar_em_dia/demo/demo_database.dart';
import 'package:lar_em_dia/demo/demo_mode.dart';
import 'package:lar_em_dia/demo/demo_seed.dart';

void main() {
  late DemoServer server;
  const bearer = 'Bearer ${DemoServer.accessToken}';

  setUp(() => server = DemoServer(DemoSeed.build(DateTime(2026, 11, 3))));

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

  void signIn() => server.handle(
    'POST',
    '/auth/login',
    body: {'email': DemoSeed.email, 'password': DemoSeed.password},
  );

  Object? data(DemoResponse response) => response.body!['data'];

  String? errorCode(DemoResponse response) =>
      (response.body!['error']! as Map<String, Object?>)['code'] as String?;

  group('auth', () {
    test('logs in only with the demo credentials', () {
      final wrong = server.handle(
        'POST',
        '/auth/login',
        body: {'email': DemoSeed.email, 'password': 'nope'},
      );
      expect(wrong.status, 401);
      expect(errorCode(wrong), 'invalid_credentials');

      final refreshBefore = server.handle('POST', '/auth/refresh');
      expect(refreshBefore.status, 401);

      signIn();
      final refresh = server.handle('POST', '/auth/refresh');
      expect(refresh.status, 200);
      expect(
        (data(refresh)! as Map)['tokens'],
        containsPair('access_token', DemoServer.accessToken),
      );
    });

    test('logs out and rejects requests without the token', () {
      signIn();
      expect(server.handle('GET', '/me').status, 401);
      expect(call('GET', '/me').status, 200);

      expect(server.handle('DELETE', '/auth/logout').status, 204);
      expect(call('GET', '/me').status, 401);
    });

    test('accepts email flows without sending anything', () {
      for (final action in ['register', 'confirm/resend', 'password/forgot']) {
        expect(server.handle('POST', '/auth/$action').status, 200);
      }
      expect(server.handle('POST', '/auth/confirm').status, 401);
    });
  });

  group('resources', () {
    setUp(signIn);

    test('lists categories by kind', () {
      final response = call('GET', '/categories', query: {'kind': 'expense'});
      expect(data(response), hasLength(20));
    });

    test('creates, reads, updates and deletes balances', () {
      final created = call(
        'POST',
        '/balances',
        body: {'amount_cents': 100, 'as_of': '2026-10-01'},
      );
      expect(created.status, 201);
      final id = (data(created)! as Map)['id'] as String;

      expect(call('GET', '/balances/$id').status, 200);
      expect(
        (data(call('PATCH', '/balances/$id', body: {'amount_cents': 5}))!
            as Map)['amount_cents'],
        5,
      );
      final page = call('GET', '/balances', query: {'limit': '1'});
      expect(page.body!['meta'], containsPair('next', 2));
      expect(call('DELETE', '/balances/$id').status, 204);
      expect(call('GET', '/balances/$id').status, 404);
    });

    test('pages and filters entries', () {
      final first = call(
        'GET',
        '/entries',
        query: {
          'from': '2026-11-01',
          'to': '2026-11-30',
          'kind': 'expense',
          'nature': 'fixed',
          'limit': '2',
        },
      );
      expect(data(first), hasLength(2));
      expect(first.body!['meta'], containsPair('total', 5));
      expect(first.body!['meta'], containsPair('prev', null));

      final last = call(
        'GET',
        '/entries',
        query: {'limit': '1000', 'page': '99', 'kind': 'x', 'nature': 'y'},
      );
      expect(last.body!['meta'], containsPair('page', 3));
      expect(last.body!['meta'], containsPair('per_page', 100));

      final second = call(
        'GET',
        '/entries',
        query: {'limit': '2', 'page': '2'},
      );
      expect(second.body!['meta'], containsPair('prev', 1));
    });

    test('passes the scope of a series entry', () {
      signIn();
      final created =
          data(
                call(
                  'POST',
                  '/entry_series',
                  body: {
                    'category_id': server.database
                        .categoriesOf('expense')
                        .first['id'],
                    'description': 'Rent',
                    'amount_cents': 100,
                    'due_on': '2026-11-05',
                    'entries_count': 3,
                    'direction': 'forward',
                  },
                ),
              )!
              as Map<String, Object?>;
      final first =
          (created['entries']! as List<Object?>).first! as Map<String, Object?>;
      final id = first['id']! as String;

      final refused = call(
        'PATCH',
        '/entries/$id',
        query: {'scope': 'all'},
        body: {'status': 'paid'},
      );
      expect(refused.status, 422);
      expect(errorCode(refused), 'only_for_single_entry');

      expect(
        call('DELETE', '/entries/$id', query: {'scope': 'all'}).status,
        204,
      );
      expect(
        server.database.series.where((row) => row['id'] == created['id']),
        isEmpty,
      );
    });

    test('creates, updates and deletes entries with validation errors', () {
      final category = (data(call('GET', '/categories'))! as List).first as Map;
      final created = call(
        'POST',
        '/entries',
        body: {
          'category_id': category['id'],
          'description': 'Bonus',
          'amount_cents': 100,
          'due_on': '2026-11-10',
        },
      );
      final id = (data(created)! as Map)['id'] as String;
      expect(call('GET', '/entries/$id').status, 200);
      expect(
        call('PATCH', '/entries/$id', body: {'description': 'B'}).status,
        200,
      );

      final invalid = call('POST', '/entries', body: {});
      expect(invalid.status, 422);
      final details =
          (invalid.body!['error']! as Map<String, Object?>)['details']! as Map;
      expect(details['amount_cents'], [
        {'code': 'greater_than', 'message': 'greater_than'},
      ]);

      expect(call('DELETE', '/entries/$id').status, 204);
      expect(call('DELETE', '/entries/$id').status, 404);
    });

    test('creates recurring series with validation errors', () {
      final category = (data(call('GET', '/categories'))! as List).first as Map;
      final created = call(
        'POST',
        '/entry_series',
        body: {
          'category_id': category['id'],
          'description': 'Bonus',
          'amount_cents': 100,
          'due_on': '2026-11-10',
          'entries_count': 2,
          'direction': 'forward',
        },
      );
      expect(created.status, 201);
      expect((data(created)! as Map)['entries'], hasLength(2));

      final invalid = call('POST', '/entry_series', body: {});
      expect(invalid.status, 422);
    });

    test('rejects malformed dates and unknown routes', () {
      final response = call('GET', '/entries', query: {'from': '11/2026'});
      expect(response.status, 400);
      expect(errorCode(response), 'invalid_date');
      expect(call('GET', '/entries', query: {'from': ''}).status, 200);
      expect(call('GET', '/unknown').status, 404);
    });

    test('projects from the current month by default', () {
      final response = call('GET', '/projection');
      final body = data(response)! as Map;
      expect(body['anchor'], {'amount_cents': 350000, 'as_of': '2026-11-01'});
      expect(body['months'], hasLength(12));
      expect((body['months'] as List).first, containsPair('month', '2026-11'));
      expect(body['alerts'], {
        'first_negative_month': '2027-01',
        'negative_months_count': 4,
      });
      expect(body['last_entry_month'], '2028-10');
      final november = (body['months'] as List).first as Map;
      final byCategory = november['expense_by_category'] as List;
      expect(
        byCategory.fold<int>(
          0,
          (sum, item) => sum + ((item as Map)['amount_cents'] as int),
        ),
        november['expense_cents'],
      );
      expect((byCategory.first as Map)['category_key'], 'housing');

      final short =
          data(
                call(
                  'GET',
                  '/projection',
                  query: {'from': '2027-01', 'months': '2'},
                ),
              )!
              as Map;
      expect(short['months'], hasLength(2));
    });

    test('projects through the last entry with months=all', () {
      List<Object?> months(String from) =>
          (data(
                    call(
                      'GET',
                      '/projection',
                      query: {'from': from, 'months': 'all'},
                    ),
                  )!
                  as Map)['months']!
              as List;

      expect(months('2026-11'), hasLength(24));
      expect(months('2030-01'), hasLength(1));
      expect(months('2020-01'), hasLength(DemoServer.allMonthsLimit));

      server.database.entries.clear();
      final empty = data(call('GET', '/projection', query: {'months': 'all'}));
      expect((empty! as Map)['months'], hasLength(1));
      expect((empty as Map)['last_entry_month'], isNull);
    });

    test('rejects a bad projection period and works without a balance', () {
      expect(
        errorCode(call('GET', '/projection', query: {'from': '2026-13'})),
        'invalid_month',
      );
      expect(
        errorCode(call('GET', '/projection', query: {'months': '25'})),
        'invalid_months',
      );
      expect(
        errorCode(call('GET', '/projection', query: {'months': 'x'})),
        'invalid_months',
      );

      server.database.balances.clear();
      expect((data(call('GET', '/projection'))! as Map)['anchor'], isNull);
    });

    test('simulates entries and series without keeping them', () {
      final expense =
          (data(call('GET', '/categories', query: {'kind': 'expense'}))!
                      as List)
                  .first
              as Map;
      final entriesBefore = server.database.entries.length;
      final seriesBefore = server.database.series.length;
      final response = call(
        'POST',
        '/projection/simulation',
        body: {
          'from': '2026-11',
          'months': 3,
          'entries': [
            {
              'category_id': expense['id'],
              'description': 'TV',
              'amount_cents': 500000,
              'due_on': '2026-12-01',
            },
            {
              'category_id': expense['id'],
              'description': 'Sofa',
              'due_on': '2026-11-10',
              'kind': 'installments',
              'total_cents': 300000,
              'entries_count': 3,
            },
          ],
        },
      );

      expect(response.status, 200);
      final body = data(response)! as Map;
      List<Object?> closings(String key) => [
        for (final month in (body[key]! as Map)['months']! as List)
          (month as Map)['closing_cents'],
      ];
      final baseline = closings('baseline');
      expect(baseline, hasLength(3));
      expect(closings('simulated'), [
        (baseline[0]! as int) - 100000,
        (baseline[1]! as int) - 700000,
        (baseline[2]! as int) - 800000,
      ]);
      expect(server.database.entries, hasLength(entriesBefore));
      expect(server.database.series, hasLength(seriesBefore));
    });

    test('validates simulated items by position and the period', () {
      final invalid = call(
        'POST',
        '/projection/simulation',
        body: {
          'entries': [
            {'description': 'x'},
            'not an object',
            {'entries_count': 1},
          ],
        },
      );
      expect(invalid.status, 422);
      final details =
          (invalid.body!['error']! as Map<String, Object?>)['details']! as Map;
      expect(
        details.keys,
        containsAll([
          'entries.0.category',
          'entries.1.description',
          'entries.2.entries_count',
        ]),
      );

      Object? entriesError(Object? entries) =>
          ((call(
                    'POST',
                    '/projection/simulation',
                    body: {'entries': entries},
                  ).body!['error']!
                  as Map)['details']!
              as Map)['entries'];
      expect(entriesError(null), [
        {'code': 'blank', 'message': 'blank'},
      ]);
      expect(entriesError(List.filled(11, <String, Object?>{})), [
        {'code': 'too_long', 'message': 'too_long'},
      ]);
      expect(
        errorCode(
          call(
            'POST',
            '/projection/simulation',
            body: {'from': 'x', 'entries': <Object?>[]},
          ),
        ),
        'invalid_month',
      );
    });
  });

  group('account', () {
    setUp(signIn);

    test('keeps the time zone and the notification settings', () {
      expect(
        (data(call('GET', '/me'))! as Map)['time_zone'],
        'America/Sao_Paulo',
      );
      call('PATCH', '/me', body: {'time_zone': 'Europe/Lisbon'});
      call('PATCH', '/me', body: {'first_name': 'Ana'});
      expect((data(call('GET', '/me'))! as Map)['time_zone'], 'Europe/Lisbon');

      expect(data(call('GET', '/me/notification_settings')), {
        'due_alerts_enabled': true,
        'due_alert_days_before': 1,
      });
      final updated = call(
        'PATCH',
        '/me/notification_settings',
        body: {'due_alerts_enabled': false, 'due_alert_days_before': 3},
      );
      expect(data(updated), {
        'due_alerts_enabled': false,
        'due_alert_days_before': 3,
      });
      expect(
        call(
          'PATCH',
          '/me/notification_settings',
          body: {'due_alert_days_before': 8},
        ).status,
        422,
      );
      expect(
        call(
          'PATCH',
          '/me/notification_settings',
          body: {'due_alerts_enabled': 'yes'},
        ).status,
        422,
      );
    });

    test('has no unsubscribe links', () {
      final response = server.handle(
        'POST',
        '/me/notification_settings/unsubscribe',
        body: {'token': 'x'},
      );
      expect(errorCode(response), 'invalid_unsubscribe_token');
    });
  });

  group('two-factor', () {
    setUp(signIn);

    const password = {'current_password': DemoSeed.password};
    const passwordAndCode = {
      'current_password': DemoSeed.password,
      'code': '123456',
    };

    Map<Object?, Object?> status() =>
        data(call('GET', '/me/two_factor'))! as Map;

    bool meTwoFactor() =>
        (data(call('GET', '/me'))! as Map)['two_factor_enabled']! as bool;

    test('enrolls with the password and any six digit code', () {
      expect(status(), {
        'enabled': false,
        'required': false,
        'backup_codes_remaining': 0,
      });
      expect(
        errorCode(call('POST', '/me/two_factor/enable', body: {'code': '1'})),
        'invalid_two_factor_code',
      );
      expect(
        errorCode(
          call(
            'POST',
            '/me/two_factor/setup',
            body: {'current_password': 'nope'},
          ),
        ),
        'invalid_current_password',
      );

      final setup = data(call('POST', '/me/two_factor/setup', body: password));
      expect(setup, containsPair('secret', DemoServer.twoFactorSecret));
      expect(
        (setup! as Map)['provisioning_uri'],
        startsWith('otpauth://totp/'),
      );
      expect(
        call('POST', '/me/two_factor/enable', body: {'code': 'abcdef'}).status,
        422,
      );
      final enabled = call(
        'POST',
        '/me/two_factor/enable',
        body: {'code': '123456'},
      );
      expect((data(enabled)! as Map)['backup_codes'], hasLength(10));
      expect(status()['enabled'], isTrue);
      expect(status()['backup_codes_remaining'], 10);
      expect(meTwoFactor(), isTrue);
      expect(
        errorCode(call('POST', '/me/two_factor/setup', body: password)),
        'two_factor_already_enabled',
      );
    });

    test('asks for a code once enabled, then disables', () {
      call('POST', '/me/two_factor/setup', body: password);
      call('POST', '/me/two_factor/enable', body: {'code': '123456'});

      expect(
        errorCode(call('POST', '/me/two_factor/backup_codes', body: password)),
        'invalid_two_factor_code',
      );
      final codes = call(
        'POST',
        '/me/two_factor/backup_codes',
        body: passwordAndCode,
      );
      expect((data(codes)! as Map)['backup_codes'], contains('demo-0001'));

      expect(
        call('DELETE', '/me/two_factor', body: passwordAndCode).status,
        204,
      );
      expect(meTwoFactor(), isFalse);
      expect(call('PUT', '/me/two_factor').status, 404);
    });
  });

  group('DemoAdapter', () {
    Dio dio() =>
        Dio(BaseOptions(baseUrl: 'http://demo.test/api/v1'))
          ..httpClientAdapter = DemoAdapter(server);

    test('answers Dio requests with JSON and empty bodies', () async {
      final client = dio();
      final login = await client.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': DemoSeed.email, 'password': DemoSeed.password},
      );
      expect(login.data!['data'], containsPair('user', DemoSeed.user));

      final logout = await client.delete<void>('/auth/logout');
      expect(logout.statusCode, 204);

      await expectLater(
        client.get<void>(
          '/me',
          options: Options(headers: {'Authorization': bearer}),
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.response?.statusCode,
            'status',
            401,
          ),
        ),
      );
      client.httpClientAdapter.close();
    });
  });

  test('DemoMode swaps the adapter only when enabled', () {
    final plain = Dio();
    final original = plain.httpClientAdapter;

    expect(DemoMode.apply(plain).httpClientAdapter, original);
    expect(
      DemoMode.apply(Dio(), enabled: true).httpClientAdapter,
      DemoMode.adapter,
    );
  });

  test('exceptions are plain values', () {
    expect(const DemoValidationError({}).details, isEmpty);
    expect(const DemoBadRequest('x').code, 'x');
  });
}
