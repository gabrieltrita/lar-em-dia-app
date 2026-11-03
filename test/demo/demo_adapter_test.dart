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
      expect(first.body!['meta'], containsPair('total', 4));
      expect(first.body!['meta'], containsPair('prev', null));

      final last = call(
        'GET',
        '/entries',
        query: {'limit': '1000', 'page': '99', 'kind': 'x', 'nature': 'y'},
      );
      expect(last.body!['meta'], containsPair('page', 1));
      expect(last.body!['meta'], containsPair('per_page', 100));

      final second = call(
        'GET',
        '/entries',
        query: {'limit': '2', 'page': '2'},
      );
      expect(second.body!['meta'], containsPair('prev', 1));
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
