import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/config/env.dart';
import 'package:lar_em_dia/core/di/injection.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/core/network/auth_interceptor.dart';
import 'package:lar_em_dia/core/storage/token_storage.dart';

void main() {
  setUpAll(configureDependencies);

  test('wires Dio with the API base URL and the auth interceptor', () {
    final dio = getIt<Dio>();

    expect(dio.options.baseUrl, Env.apiBaseUrl);
    expect(dio.interceptors.whereType<AuthInterceptor>(), hasLength(1));
  });

  test('registers the client, the token storage and the router', () {
    expect(getIt<ApiClient>(), isA<ApiClient>());
    expect(getIt<TokenStorage>(), isA<SecureTokenStorage>());
    expect(getIt<GoRouter>(), same(getIt<GoRouter>()));
  });
}
