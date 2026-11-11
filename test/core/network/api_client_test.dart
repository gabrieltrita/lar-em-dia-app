import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/core/network/api_error.dart';

import '../../helpers/fake_adapter.dart';

void main() {
  late FakeAdapter adapter;
  late ApiClient client;

  ApiClient clientFor(FakeHandler handler) {
    adapter = FakeAdapter(handler);
    return ApiClient(
      Dio(BaseOptions(baseUrl: 'http://api.test'))..httpClientAdapter = adapter,
    );
  }

  String decodeName(Object? data) => (data! as Json)['name'] as String;

  test('get decodes data and meta and sends the query', () async {
    client = clientFor(
      (_) => FakeAdapter.json(200, {
        'data': {'name': 'Carla'},
        'meta': {'page': 2},
      }),
    );

    final response = await client.get(
      '/me',
      decode: decodeName,
      query: {'page': 2},
    );

    expect(response.data, 'Carla');
    expect(response.meta, {'page': 2});
    expect(adapter.requests.single.queryParameters, {'page': 2});
  });

  test('post and patch send the body and default meta to empty', () async {
    client = clientFor(
      (_) => FakeAdapter.json(200, {
        'data': {'name': 'Carla'},
      }),
    );

    final created = await client.post(
      '/me',
      decode: decodeName,
      body: {'a': 1},
    );
    final updated = await client.patch(
      '/me',
      decode: decodeName,
      body: {'b': 2},
    );

    expect(created.data, 'Carla');
    expect(updated.meta, isEmpty);
    expect(adapter.requests.map((r) => r.method), ['POST', 'PATCH']);
    expect(adapter.requests.last.data, {'b': 2});
  });

  test('an empty body decodes null data', () async {
    client = clientFor((_) => ResponseBody.fromString('', 200));

    final response = await client.get<Object?>('/me', decode: (data) => data);

    expect(response.data, isNull);
  });

  test('a response that cannot be decoded becomes an unknown error', () async {
    client = clientFor(
      (_) => FakeAdapter.json(200, {
        'data': {'name': 42},
      }),
    );

    await expectLater(
      client.get('/me', decode: decodeName),
      throwsA(
        isA<ApiError>().having(
          (e) => e.code,
          'code',
          ApiError.unknownErrorCode,
        ),
      ),
    );
  });

  test('errors become ApiError with the API code', () async {
    client = clientFor(
      (_) => FakeAdapter.json(404, {
        'error': {'code': 'not_found', 'message': 'Not found'},
      }),
    );

    await expectLater(
      client.get('/missing', decode: decodeName),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'not_found')),
    );
  });

  test('delete succeeds on 204 and maps errors', () async {
    client = clientFor((options) {
      if (options.path == '/ok') {
        return ResponseBody.fromString('', 204);
      }
      return FakeAdapter.json(403, {
        'error': {'code': 'forbidden'},
      });
    });

    await client.delete('/ok', body: {'code': '123456'});
    expect(adapter.requests.single.data, {'code': '123456'});

    await expectLater(
      client.delete('/denied'),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'forbidden')),
    );
  });

  test('deleteReturning decodes the answer and maps errors', () async {
    client = clientFor((options) {
      if (options.path == '/ok') {
        return FakeAdapter.json(200, {
          'data': {'name': 'gone'},
          'meta': {'page': 1},
        });
      }
      return FakeAdapter.json(404, {
        'error': {'code': 'not_found'},
      });
    });

    final response = await client.deleteReturning('/ok', decode: decodeName);
    expect(response.data, 'gone');
    expect(response.meta, {'page': 1});
    expect(adapter.requests.single.method, 'DELETE');

    await expectLater(
      client.deleteReturning('/missing', decode: decodeName),
      throwsA(isA<ApiError>().having((e) => e.code, 'code', 'not_found')),
    );
  });
}
