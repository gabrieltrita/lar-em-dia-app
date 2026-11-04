import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/demo/demo_database.dart';
import 'package:lar_em_dia/demo/demo_seed.dart';

final class DemoBadRequest implements Exception {
  const new(this.code);

  final String code;
}

final class DemoResponse {
  const new(this.status, [this.body]);

  final int status;
  final Map<String, Object?>? body;
}

class DemoServer {
  new(this.database);

  static const accessToken = 'demo-access-token';
  static const refreshToken = 'demo-refresh-token';
  static const pageSize = 25;
  static const maxPageSize = 100;

  final DemoDatabase database;
  bool signedIn = false;

  DemoResponse handle(
    String method,
    String path, {
    Map<String, String> query = const {},
    Map<String, Object?> body = const {},
    String? authorization,
  }) {
    final segments = path.split('/').where((part) => part.isNotEmpty).toList();
    if (segments.firstOrNull == 'auth') {
      return _auth(method, segments.skip(1).join('/'), body);
    }
    if (!signedIn || authorization != 'Bearer $accessToken') {
      return _error(401, 'missing_token', 'Missing or invalid token');
    }
    try {
      return switch ((method, segments)) {
        ('GET', ['me']) => _data(DemoSeed.user),
        ('GET', ['categories']) => _data(database.categoriesOf(query['kind'])),
        ('GET', ['balances']) => _page(database.sortedBalances(), query),
        ('POST', ['balances']) => _data(database.createBalance(body), 201),
        ('GET', ['balances', final id]) => _data(database.findBalance(id)),
        ('PATCH', ['balances', final id]) => _data(
          database.updateBalance(id, body),
        ),
        ('DELETE', ['balances', final id]) => _noContent(
          () => database.deleteBalance(id),
        ),
        ('GET', ['entries']) => _entries(query),
        ('POST', ['entries']) => _data(database.createEntry(body), 201),
        ('POST', ['entry_series']) => _data(database.createSeries(body), 201),
        ('GET', ['entries', final id]) => _data(database.findEntry(id)),
        ('PATCH', ['entries', final id]) => _data(
          database.updateEntry(id, body),
        ),
        ('DELETE', ['entries', final id]) => _noContent(
          () => database.deleteEntry(id),
        ),
        ('GET', ['projection']) => _projection(query),
        _ => throw const DemoNotFound(),
      };
    } on DemoNotFound {
      return _error(404, 'not_found', 'Resource not found');
    } on DemoValidationError catch (error) {
      return DemoResponse(422, {
        'error': {
          'code': 'validation_failed',
          'message': 'Invalid data',
          'details': {
            for (final MapEntry(:key, :value) in error.details.entries)
              key: [
                for (final code in value) {'code': code, 'message': code},
              ],
          },
        },
      });
    } on DemoBadRequest catch (error) {
      return _error(400, error.code, 'Invalid query parameter');
    }
  }

  DemoResponse _auth(String method, String action, Map<String, Object?> body) {
    switch ((method, action)) {
      case ('POST', 'login'):
        if (body['email'] != DemoSeed.email ||
            body['password'] != DemoSeed.password) {
          return _error(401, 'invalid_credentials', 'Invalid credentials');
        }
        signedIn = true;
        return _session();
      case ('POST', 'refresh'):
        return signedIn
            ? _session()
            : _error(401, 'missing_token', 'Missing refresh token');
      case ('DELETE', 'logout'):
        signedIn = false;
        return const DemoResponse(204);
      case ('POST', 'register' || 'confirm/resend' || 'password/forgot'):
        return _data({'message': 'The demo does not send emails'});
      default:
        return _error(401, 'invalid_token', 'Not available in the demo');
    }
  }

  DemoResponse _session() => _data({
    'user': DemoSeed.user,
    'tokens': {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': 'Bearer',
      'expires_in': 900,
    },
  });

  DemoResponse _entries(Map<String, String> query) {
    final kind = query['kind'];
    final nature = query['nature'];
    return _page(
      database.filteredEntries(
        from: _date(query['from']),
        to: _date(query['to']),
        kind: kind == 'income' || kind == 'expense' ? kind : null,
        nature: nature == 'fixed' || nature == 'variable' ? nature : null,
      ),
      query,
    );
  }

  DemoResponse _projection(Map<String, String> query) {
    final from = query['from'];
    final month = from == null
        ? Dates.firstOfMonth(database.today)
        : Dates.parseMonth(from);
    if (month == null) {
      throw const DemoBadRequest('invalid_month');
    }
    final months = int.tryParse(query['months'] ?? '12');
    if (months == null || months < 1 || months > 24) {
      throw const DemoBadRequest('invalid_months');
    }
    final anchor = database.latestBalance();
    return _data({
      'anchor': anchor == null
          ? null
          : {'amount_cents': anchor['amount_cents'], 'as_of': anchor['as_of']},
      'months': database.projection(from: month, months: months),
    });
  }

  static DateTime? _date(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const DemoBadRequest('invalid_date');
    }
    return Dates.parseIso(value);
  }

  static DemoResponse _page(List<Row> rows, Map<String, String> query) {
    final limit = (int.tryParse(query['limit'] ?? '') ?? pageSize).clamp(
      1,
      maxPageSize,
    );
    final pages = rows.isEmpty ? 1 : (rows.length / limit).ceil();
    final page = (int.tryParse(query['page'] ?? '') ?? 1).clamp(1, pages);
    return DemoResponse(200, {
      'data': rows.skip((page - 1) * limit).take(limit).toList(),
      'meta': {
        'page': page,
        'per_page': limit,
        'total': rows.length,
        'pages': pages,
        'next': page < pages ? page + 1 : null,
        'prev': page > 1 ? page - 1 : null,
      },
    });
  }

  static DemoResponse _data(Object? data, [int status = 200]) =>
      DemoResponse(status, {'data': data});

  static DemoResponse _noContent(void Function() action) {
    action();
    return const DemoResponse(204);
  }

  static DemoResponse _error(int status, String code, String message) =>
      DemoResponse(status, {
        'error': {'code': code, 'message': message},
      });
}

class DemoAdapter implements HttpClientAdapter {
  new(this.server);

  final DemoServer server;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = options.data;
    final response = server.handle(
      options.method,
      options.uri.path.replaceFirst(Uri.parse(options.baseUrl).path, ''),
      query: options.uri.queryParameters,
      body: data is Map<String, Object?> ? data : const {},
      authorization: options.headers['Authorization'] as String?,
    );
    final body = response.body;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
