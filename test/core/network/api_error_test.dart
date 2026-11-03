import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/network/api_error.dart';

void main() {
  final request = RequestOptions(path: '/me');

  group('ApiError.fromDioException', () {
    test('reads the code, message and field details of the API envelope', () {
      final error = ApiError.fromDioException(
        DioException(
          requestOptions: request,
          response: Response(
            requestOptions: request,
            statusCode: 422,
            data: {
              'error': {
                'code': 'validation_failed',
                'message': 'Invalid data',
                'details': {
                  'password': [
                    {'code': 'too_short', 'message': 'Too short'},
                  ],
                },
              },
            },
          ),
        ),
      );

      expect(error.code, 'validation_failed');
      expect(error.message, 'Invalid data');
      expect(error.statusCode, 422);
      expect(error.details['password']!.single.code, 'too_short');
    });

    test('reports a network error when there is no response', () {
      final error = ApiError.fromDioException(
        DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
        ),
      );

      expect(error, const ApiError(code: ApiError.networkErrorCode));
    });

    test('reports an unknown error when the body is not the envelope', () {
      final error = ApiError.fromDioException(
        DioException(
          requestOptions: request,
          response: Response(
            requestOptions: request,
            statusCode: 502,
            data: 'Bad Gateway',
          ),
        ),
      );

      expect(
        error,
        const ApiError(code: ApiError.unknownErrorCode, statusCode: 502),
      );
    });
  });
}
