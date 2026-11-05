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
  static const maxSimulationEntries = 10;

  static const twoFactorSecret = 'JBSWY3DPEHPK3PXP';
  static const backupCodesCount = 10;

  final DemoDatabase database;
  bool signedIn = false;
  bool twoFactorEnabled = false;
  bool _twoFactorPending = false;

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
        ('GET', ['me']) => _data(_user()),
        (_, ['me', 'two_factor', ...final action]) => _twoFactor(
          method,
          action.join('/'),
          body,
        ),
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
        ('POST', ['projection', 'simulation']) => _simulation(body),
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

  Map<String, Object?> _user() => {
    ...DemoSeed.user,
    'two_factor_enabled': twoFactorEnabled,
  };

  DemoResponse _twoFactor(
    String method,
    String action,
    Map<String, Object?> body,
  ) {
    switch ((method, action)) {
      case ('GET', ''):
        return _data({
          'enabled': twoFactorEnabled,
          'required': false,
          'backup_codes_remaining': twoFactorEnabled ? backupCodesCount : 0,
        });
      case ('POST', 'setup'):
        if (twoFactorEnabled) {
          return _error(422, 'two_factor_already_enabled', 'Already enabled');
        }
        return _reauthenticated(body, () {
          _twoFactorPending = true;
          return _data({
            'secret': twoFactorSecret,
            'provisioning_uri':
                'otpauth://totp/Lar%20em%20Dia:${DemoSeed.email}'
                '?secret=$twoFactorSecret&issuer=Lar%20em%20Dia',
          });
        });
      case ('POST', 'enable'):
        if (!_twoFactorPending || !_isCode(body['code'])) {
          return _error(422, 'invalid_two_factor_code', 'Invalid code');
        }
        _twoFactorPending = false;
        twoFactorEnabled = true;
        return _backupCodes();
      case ('POST', 'backup_codes'):
        return _reauthenticated(body, _backupCodes);
      case ('DELETE', ''):
        return _reauthenticated(body, () {
          twoFactorEnabled = false;
          return const DemoResponse(204);
        });
      default:
        throw const DemoNotFound();
    }
  }

  DemoResponse _reauthenticated(
    Map<String, Object?> body,
    DemoResponse Function() action,
  ) {
    if (body['current_password'] != DemoSeed.password) {
      return _error(422, 'invalid_current_password', 'Invalid password');
    }
    if (twoFactorEnabled && !_isCode(body['code'])) {
      return _error(422, 'invalid_two_factor_code', 'Invalid code');
    }
    return action();
  }

  static bool _isCode(Object? code) =>
      code is String && RegExp(r'^\d{6}$').hasMatch(code);

  static DemoResponse _backupCodes() => _data({
    'backup_codes': [
      for (var index = 1; index <= backupCodesCount; index++)
        'demo-${index.toString().padLeft(4, '0')}',
    ],
  });

  DemoResponse _session() => _data({
    'user': _user(),
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
    final (month, months) = _period(query);
    return _data(_projectionBody(month, months));
  }

  DemoResponse _simulation(Map<String, Object?> body) {
    final (month, months) = _period({
      if (body['from'] case final Object from) 'from': '$from',
      if (body['months'] case final Object count) 'months': '$count',
    });
    final inputs = body['entries'];
    final items = inputs is List ? inputs : const <Object?>[];
    if (items.isEmpty || items.length > maxSimulationEntries) {
      throw DemoValidationError({
        'entries': [if (items.isEmpty) 'blank' else 'too_long'],
      });
    }
    final baseline = _projectionBody(month, months);
    final simulated = database.rollback(() {
      final errors = <String, List<String>>{};
      for (final (index, item) in items.indexed) {
        final input = item is Map<String, Object?>
            ? item
            : const <String, Object?>{};
        try {
          input['entries_count'] == null
              ? database.createEntry(input)
              : database.createSeries(input);
        } on DemoValidationError catch (error) {
          for (final MapEntry(:key, :value) in error.details.entries) {
            errors['entries.$index.$key'] = value;
          }
        }
      }
      if (errors.isNotEmpty) {
        throw DemoValidationError(errors);
      }
      return _projectionBody(month, months);
    });
    return _data({'baseline': baseline, 'simulated': simulated});
  }

  (DateTime, int) _period(Map<String, String> query) {
    final from = query['from'];
    final month = from == null ? null : Dates.parseMonth(from);
    if (from != null && month == null) {
      throw const DemoBadRequest('invalid_month');
    }
    final months = int.tryParse(query['months'] ?? '12');
    if (months == null || months < 1 || months > 24) {
      throw const DemoBadRequest('invalid_months');
    }
    return (month ?? Dates.firstOfMonth(database.today), months);
  }

  Map<String, Object?> _projectionBody(DateTime month, int months) {
    final anchor = database.latestBalance();
    final rows = database.projection(from: month, months: months);
    final negative = [
      for (final row in rows)
        if (row['negative'] == true) row['month'],
    ];
    return {
      'anchor': anchor == null
          ? null
          : {'amount_cents': anchor['amount_cents'], 'as_of': anchor['as_of']},
      'months': rows,
      'alerts': {
        'first_negative_month': negative.firstOrNull,
        'negative_months_count': negative.length,
      },
    };
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
