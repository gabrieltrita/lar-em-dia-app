import 'package:dio/dio.dart';
import 'package:lar_em_dia/core/network/token_transport.dart';
import 'package:lar_em_dia/core/session/session_events.dart';
import 'package:lar_em_dia/core/storage/token_storage.dart';

class AuthInterceptor extends QueuedInterceptor {
  new({
    required this._tokenStorage,
    required this._client,
    required this._transport,
    required this._sessionEvents,
  });

  static const authPathPrefix = '/auth/';
  static const refreshPath = '/auth/refresh';
  static const retriedFlag = 'auth_retried';

  final TokenStorage _tokenStorage;
  final Dio _client;
  final TokenTransport _transport;
  final SessionEvents _sessionEvents;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenStorage.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    if (_transport.usesCookie) {
      options.headers[TokenTransport.header] = 'cookie';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final unauthorized = err.response?.statusCode == 401;
    final isAuthRequest = request.path.startsWith(authPathPrefix);
    if (!unauthorized || isAuthRequest || request.extra[retriedFlag] == true) {
      return handler.next(err);
    }

    final refreshed = await _refresh();
    if (!refreshed) {
      return handler.next(err);
    }

    request.extra[retriedFlag] = true;
    request.headers['Authorization'] = 'Bearer ${_tokenStorage.accessToken}';
    try {
      handler.resolve(await _client.fetch<dynamic>(request));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  Future<bool> _refresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken == null && !_transport.usesCookie) {
      return await _expire();
    }
    try {
      final response = await _client.post<Map<String, dynamic>>(
        refreshPath,
        data: {'refresh_token': ?refreshToken},
        options: Options(
          headers: {if (_transport.usesCookie) TokenTransport.header: 'cookie'},
        ),
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      final tokens = data?['tokens'] as Map<String, dynamic>?;
      final accessToken = tokens?['access_token'] as String?;
      if (accessToken == null) {
        return await _expire();
      }
      await _tokenStorage.save(
        accessToken: accessToken,
        refreshToken: tokens?['refresh_token'] as String?,
      );
      return true;
    } on DioException {
      return await _expire();
    }
  }

  Future<bool> _expire() async {
    await _tokenStorage.clear();
    _sessionEvents.notifyExpired();
    return false;
  }
}
