import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/auth_interceptor.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/memory_token_storage.dart';

void main() {
  late MemoryTokenStorage storage;
  late List<RequestOptions> apiRequests;
  late List<RequestOptions> refreshRequests;
  late Dio dio;

  void build({required FakeHandler api, required FakeHandler refresh}) {
    apiRequests = [];
    refreshRequests = [];
    final adapter = FakeAdapter((options) {
      if (options.path == AuthInterceptor.refreshPath) {
        refreshRequests.add(options);
        return refresh(options);
      }
      apiRequests.add(options);
      return api(options);
    });
    final client = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter;
    dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(tokenStorage: storage, client: client),
      );
  }

  ResponseBody sessionWith({String? access, String? refresh}) =>
      FakeAdapter.json(200, {
        'data': {
          'tokens': {'access_token': ?access, 'refresh_token': ?refresh},
        },
      });

  ResponseBody okUnless401(RequestOptions options, String validToken) =>
      options.headers['Authorization'] == 'Bearer $validToken'
      ? FakeAdapter.json(200, {'data': 'ok'})
      : FakeAdapter.json(401, {
          'error': {'code': 'unauthorized'},
        });

  setUp(() {
    storage = MemoryTokenStorage(accessToken: 'old', refreshToken: 'r1');
  });

  test('sends the access token as a Bearer header', () async {
    build(
      api: (options) => okUnless401(options, 'old'),
      refresh: (_) => throw StateError('no refresh expected'),
    );

    final response = await dio.get<dynamic>('/me');

    expect(response.data, {'data': 'ok'});
    expect(refreshRequests, isEmpty);
  });

  test('sends no Authorization header without an access token', () async {
    storage = MemoryTokenStorage();
    build(
      api: (_) => FakeAdapter.json(200, {'data': 'public'}),
      refresh: (_) => throw StateError('no refresh expected'),
    );

    await dio.get<dynamic>('/health');

    expect(apiRequests.single.headers, isNot(contains('Authorization')));
  });

  test('refreshes once on 401, stores the new pair and retries', () async {
    build(
      api: (options) => okUnless401(options, 'new'),
      refresh: (_) => sessionWith(access: 'new', refresh: 'r2'),
    );

    final response = await dio.get<dynamic>('/me');

    expect(response.data, {'data': 'ok'});
    expect(storage.accessToken, 'new');
    expect(storage.refreshToken, 'r2');
    expect(refreshRequests.single.path, AuthInterceptor.refreshPath);
    expect(refreshRequests.single.data, {'refresh_token': 'r1'});
  });

  test('keeps the refresh token when the API omits it', () async {
    build(
      api: (options) => okUnless401(options, 'new'),
      refresh: (_) => sessionWith(access: 'new'),
    );

    await dio.get<dynamic>('/me');

    expect(storage.refreshToken, 'r1');
  });

  test('does not refresh errors other than 401', () async {
    build(
      api: (_) => FakeAdapter.json(500, {
        'error': {'code': 'internal_error'},
      }),
      refresh: (_) => throw StateError('no refresh expected'),
    );

    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
    expect(refreshRequests, isEmpty);
  });

  test('gives up without a stored refresh token', () async {
    storage = MemoryTokenStorage(accessToken: 'old');
    build(
      api: (options) => okUnless401(options, 'new'),
      refresh: (_) => throw StateError('no refresh expected'),
    );

    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
  });

  test('clears the tokens when the refresh is rejected', () async {
    build(
      api: (options) => okUnless401(options, 'new'),
      refresh: (_) => FakeAdapter.json(401, {
        'error': {'code': 'invalid_token'},
      }),
    );

    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
    expect(storage.accessToken, isNull);
    expect(storage.refreshToken, isNull);
  });

  test('clears the tokens when the refresh has no access token', () async {
    build(
      api: (options) => okUnless401(options, 'new'),
      refresh: (_) => FakeAdapter.json(200, {'data': <String, dynamic>{}}),
    );

    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
    expect(storage.refreshToken, isNull);
  });

  test('retries only once when the new token is also rejected', () async {
    build(
      api: (options) => okUnless401(options, 'never'),
      refresh: (_) => sessionWith(access: 'new', refresh: 'r2'),
    );

    await expectLater(dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
    expect(apiRequests, hasLength(2));
    expect(refreshRequests, hasLength(1));
  });
}
