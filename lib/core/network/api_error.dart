import 'package:dio/dio.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_error.freezed.dart';
part 'api_error.g.dart';

@freezed
abstract class FieldError with _$FieldError {
  const factory({required String code, String? message}) = _FieldError;

  factory fromJson(Map<String, dynamic> json) => _$FieldErrorFromJson(json);
}

@freezed
abstract class ApiError with _$ApiError implements Exception {
  const factory({
    required String code,
    String? message,
    int? statusCode,
    @Default(<String, List<FieldError>>{})
    Map<String, List<FieldError>> details,
  }) = _ApiError;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$ApiErrorFromJson(json);

  factory fromDioException(DioException exception) {
    final response = exception.response;
    final body = response?.data;
    if (body is Map<String, dynamic> && body['error'] is Map<String, dynamic>) {
      return ApiError.fromJson(body['error'] as Map<String, dynamic>)
          .copyWith(statusCode: response?.statusCode);
    }
    if (response == null) {
      return const ApiError(code: networkErrorCode);
    }
    return ApiError(code: unknownErrorCode, statusCode: response.statusCode);
  }

  static const networkErrorCode = 'network_error';
  static const unknownErrorCode = 'unknown_error';
}
