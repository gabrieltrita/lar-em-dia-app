import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/network/api_error.dart';

typedef Json = Map<String, dynamic>;

class ApiResponse<T> {
  const new({required this.data, this.meta = const {}});

  final T data;
  final Json meta;
}

@lazySingleton
class ApiClient {
  new(this._dio);

  final Dio _dio;

  Future<ApiResponse<T>> get<T>(
    String path, {
    required T Function(Object? data) decode,
    Json? query,
  }) => _send(() => _dio.get<Json>(path, queryParameters: query), decode);

  Future<ApiResponse<T>> post<T>(
    String path, {
    required T Function(Object? data) decode,
    Object? body,
  }) => _send(() => _dio.post<Json>(path, data: body), decode);

  Future<ApiResponse<T>> patch<T>(
    String path, {
    required T Function(Object? data) decode,
    Object? body,
  }) => _send(() => _dio.patch<Json>(path, data: body), decode);

  Future<void> delete(String path, {Object? body}) async {
    try {
      await _dio.delete<void>(path, data: body);
    } on DioException catch (exception) {
      throw ApiError.fromDioException(exception);
    }
  }

  Future<ApiResponse<T>> deleteReturning<T>(
    String path, {
    required T Function(Object? data) decode,
  }) => _send(() => _dio.delete<Json>(path), decode);

  Future<ApiResponse<T>> _send<T>(
    Future<Response<Json>> Function() request,
    T Function(Object? data) decode,
  ) async {
    try {
      final response = await request();
      final body = response.data ?? const <String, dynamic>{};
      return ApiResponse(
        data: decode(body['data']),
        meta: (body['meta'] as Json?) ?? const {},
      );
    } on DioException catch (exception) {
      throw ApiError.fromDioException(exception);
    } on Object {
      throw const ApiError(code: ApiError.unknownErrorCode);
    }
  }
}
