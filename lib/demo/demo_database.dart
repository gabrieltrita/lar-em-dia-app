import 'dart:math';

import 'package:lar_em_dia/core/dates/dates.dart';

typedef Row = Map<String, Object?>;
typedef FieldErrors = Map<String, List<String>>;

final class DemoValidationError implements Exception {
  const new(this.details);

  final FieldErrors details;
}

final class DemoUnprocessable implements Exception {
  const new(this.code);

  final String code;
}

final class DemoNotFound implements Exception {
  const new();
}

class DemoDatabase {
  new({required DateTime today}) : today = Dates.dateOnly(today);

  final DateTime today;
  final List<Row> categories = [];
  final List<Row> balances = [];
  final List<Row> entries = [];
  final List<Row> series = [];
  int _sequence = 0;

  static const minSeriesCount = 2;
  static const maxSeriesCount = 36;
  static const seriesIntervals = [1, 3, 6, 12];
  static const maxInstallmentsCount = 48;

  String nextId(String prefix) => '$prefix-${++_sequence}';

  String addCategory({
    required String kind,
    required String key,
    required String name,
    String? defaultNature,
  }) {
    final category = {
      'id': nextId('category'),
      'kind': kind,
      'key': key,
      'name': name,
      'position': categories.where((row) => row['kind'] == kind).length,
      'default_nature': defaultNature,
    };
    categories.add(category);
    return category['id']! as String;
  }

  List<Row> categoriesOf(String? kind) => [
    for (final category in categories)
      if (kind == null || category['kind'] == kind) category,
  ];

  List<Row> sortedBalances() =>
      [...balances]
        ..sort((a, b) => _date(b, 'as_of').compareTo(_date(a, 'as_of')));

  Row findBalance(String id) => _find(balances, id);

  Row createBalance(Row input) {
    final balance = {'id': nextId('balance'), ..._balanceFields(input, null)};
    balances.add(balance);
    return balance;
  }

  Row updateBalance(String id, Row input) {
    final balance = findBalance(id);
    return balance..addAll(_balanceFields({...balance, ...input}, id));
  }

  void deleteBalance(String id) => balances.remove(findBalance(id));

  List<Row> filteredEntries({
    DateTime? from,
    DateTime? to,
    String? kind,
    String? nature,
  }) {
    final rows = entries.where((entry) {
      final dueOn = _date(entry, 'due_on');
      return (from == null || !dueOn.isBefore(from)) &&
          (to == null || !dueOn.isAfter(to)) &&
          (kind == null || entry['kind'] == kind) &&
          (nature == null || entry['nature'] == nature);
    }).toList();
    return rows
      ..sort((a, b) => _date(a, 'due_on').compareTo(_date(b, 'due_on')));
  }

  Row findEntry(String id) => _find(entries, id);

  Row createEntry(Row input) {
    final entry = {'id': nextId('entry'), ..._entryFields(input)};
    entries.add(entry);
    return entry;
  }

  Row createSeries(Row input) {
    final kind = input['kind'] ?? 'recurring';
    final installments = kind == 'installments';
    final count = input['entries_count'];
    final direction = installments ? 'forward' : input['direction'];
    final interval = installments ? 1 : input['interval_months'] ?? 1;
    final total = input['total_cents'];
    final errors = <String, List<String>>{
      if (kind != 'recurring' && !installments) 'kind': ['inclusion'],
      ..._countErrors(
        count,
        installments ? maxInstallmentsCount : maxSeriesCount,
      ),
      if (direction != 'forward' && direction != 'backward')
        'direction': ['inclusion'],
      if (!seriesIntervals.contains(interval)) 'interval_months': ['inclusion'],
      ..._totalErrors(total, count, installments: installments),
    };
    final amounts = installments && errors.isEmpty
        ? _split(total! as int, count! as int)
        : null;
    final Row base;
    try {
      base = _entryFields({
        ...input,
        if (installments) 'amount_cents': amounts?.first ?? 1,
      });
    } on DemoValidationError catch (error) {
      throw DemoValidationError({...errors, ...error.details});
    }
    if (installments && base['kind'] == 'income') {
      errors['kind'] = ['only_for_expenses'];
    }
    _raiseIfAny(errors);
    final size = count! as int;
    final row = {
      'id': nextId('series'),
      'kind': kind,
      'interval_months': interval,
      'entries_count': size,
      'total_cents': installments ? total : null,
    };
    series.add(row);
    final baseDueOn = _date(base, 'due_on');
    final step = (direction == 'forward' ? 1 : -1) * (interval as int);
    final dueDates = [
      for (var offset = 0; offset < size; offset++)
        Dates.shiftMonths(baseDueOn, offset * step),
    ]..sort();
    final created = [
      for (final (index, dueOn) in dueDates.indexed)
        _seriesEntry(
          {...base, 'amount_cents': amounts?[index] ?? base['amount_cents']},
          dueOn,
          row,
          index + 1,
        ),
    ];
    entries.addAll(created);
    return {...row, 'entries': created};
  }

  static FieldErrors _countErrors(Object? count, int maximum) => {
    if (count is! int)
      'entries_count': ['not_a_number']
    else if (count < minSeriesCount)
      'entries_count': ['greater_than_or_equal_to']
    else if (count > maximum)
      'entries_count': ['less_than_or_equal_to'],
  };

  static FieldErrors _totalErrors(
    Object? total,
    Object? count, {
    required bool installments,
  }) => {
    if (!installments && total != null)
      'total_cents': ['present']
    else if (installments && total is! int)
      'total_cents': ['not_a_number']
    else if (installments && (total! as int) < max(count is int ? count : 1, 1))
      'total_cents': ['greater_than_or_equal_to'],
  };

  static List<int> _split(int total, int count) {
    final share = total ~/ count;
    return [
      share + total - share * count,
      for (var i = 1; i < count; i++) share,
    ];
  }

  Row _seriesEntry(Row base, DateTime dueOn, Row series, int position) {
    final isBase = dueOn == _date(base, 'due_on');
    final paid = base['status'] == 'paid' && !dueOn.isAfter(today);
    return {
      ...base,
      'id': nextId('entry'),
      'due_on': Dates.toIso(dueOn),
      if (!isBase) 'status': paid ? 'paid' : 'pending',
      if (!isBase) 'paid_on': paid ? Dates.toIso(dueOn) : null,
      'series_id': series['id'],
      'series_position': position,
      'series_kind': series['kind'],
      'series_count': series['entries_count'],
    };
  }

  static const sharedFields = [
    'category_id',
    'nature',
    'description',
    'amount_cents',
  ];

  Row updateEntry(String id, Row input, {String? scope}) {
    final entry = findEntry(id);
    final scoped = _scoped(entry, scope);
    if (scoped == null) {
      return _updateOne(entry, input);
    }
    if (_changes(entry, input, 'status') || _changes(entry, input, 'paid_on')) {
      throw const DemoUnprocessable('only_for_single_entry');
    }
    if (entry['series_kind'] == 'installments' &&
        _changes(entry, input, 'amount_cents')) {
      throw const DemoUnprocessable('installment_amount_locked');
    }
    final shared = {
      for (final field in sharedFields)
        if (input.containsKey(field)) field: input[field],
    };
    final dueOn = input.containsKey('due_on')
        ? _parseDate(input['due_on'])
        : null;
    final position = entry['series_position']! as int;
    final interval =
        _find(series, entry['series_id']! as String)['interval_months']! as int;
    final updates = [
      for (final row in scoped)
        (
          row,
          _entryFields({
            ...row,
            ...shared,
            if (input.containsKey('due_on'))
              'due_on': dueOn == null
                  ? null
                  : Dates.toIso(
                      Dates.shiftMonths(
                        dueOn,
                        ((row['series_position']! as int) - position) *
                            interval,
                      ),
                    ),
          }),
        ),
    ];
    for (final (row, fields) in updates) {
      row.addAll(fields);
    }
    return entry;
  }

  Row _updateOne(Row entry, Row input) {
    final merged = {...entry, ...input};
    if (input.containsKey('category_id') &&
        input['category_id'] != entry['category_id'] &&
        !input.containsKey('nature')) {
      merged['nature'] = entry['nature'];
    }
    return entry..addAll(_entryFields(merged));
  }

  void deleteEntry(String id, {String? scope}) {
    final entry = findEntry(id);
    final seriesId = entry['series_id'];
    final scoped = _scoped(entry, scope);
    if (scoped == null) {
      entries.remove(entry);
    } else {
      entries.removeWhere(scoped.contains);
    }
    if (seriesId == null) {
      return;
    }
    final row = _find(series, seriesId as String);
    final remaining = entries.where((e) => e['series_id'] == seriesId).toList();
    if (remaining.isEmpty) {
      series.remove(row);
    } else if (scope == 'following') {
      row['entries_count'] = remaining.length;
      if (row['kind'] == 'installments') {
        row['total_cents'] = remaining.fold<int>(
          0,
          (sum, e) => sum + _cents(e),
        );
      }
      for (final e in remaining) {
        e['series_count'] = remaining.length;
      }
    }
  }

  List<Row>? _scoped(Row entry, String? scope) {
    final seriesId = entry['series_id'];
    if (seriesId == null || (scope != 'following' && scope != 'all')) {
      return null;
    }
    final position = entry['series_position']! as int;
    return [
      for (final row in entries)
        if (row['series_id'] == seriesId &&
            (scope == 'all' || (row['series_position']! as int) >= position))
          row,
    ];
  }

  static bool _changes(Row entry, Row input, String field) =>
      input.containsKey(field) && input[field] != entry[field];

  Row? latestBalance() => sortedBalances().firstOrNull;

  T rollback<T>(T Function() action) {
    final savedEntries = [...entries];
    final savedSeries = [...series];
    try {
      return action();
    } finally {
      entries
        ..clear()
        ..addAll(savedEntries);
      series
        ..clear()
        ..addAll(savedSeries);
    }
  }

  DateTime? lastEntryMonth() {
    final dates = [for (final entry in entries) _date(entry, 'due_on')];
    return dates.isEmpty
        ? null
        : Dates.firstOfMonth(dates.reduce((a, b) => a.isAfter(b) ? a : b));
  }

  int monthsThroughLastEntry(DateTime from, {required int limit}) {
    final last = lastEntryMonth();
    if (last == null || last.isBefore(from)) {
      return 1;
    }
    final span = (last.year - from.year) * 12 + last.month - from.month + 1;
    return span > limit ? limit : span;
  }

  List<Row> projection({required DateTime from, required int months}) {
    final first = Dates.firstOfMonth(from);
    final start = _openingBalance(first);
    var opening = start;
    final rows = <Row>[];
    for (var offset = 0; offset < months; offset++) {
      final row = _projectMonth(Dates.addMonths(first, offset), opening, start);
      rows.add(row);
      opening = row['closing_cents']! as int;
    }
    return rows;
  }

  Row _projectMonth(DateTime month, int opening, int start) {
    final rows = filteredEntries(from: month, to: Dates.lastOfMonth(month));
    int sum(bool Function(Row entry) test) =>
        rows.where(test).fold(0, (total, entry) => total + _cents(entry));
    final income = sum((entry) => entry['kind'] == 'income');
    final fixed = sum((entry) => entry['nature'] == 'fixed');
    final variable = sum((entry) => entry['nature'] == 'variable');
    final byCategory = <String, int>{};
    for (final entry in rows.where((entry) => entry['kind'] == 'expense')) {
      final key =
          categories.firstWhere(
                (category) => category['id'] == entry['category_id'],
              )['key']!
              as String;
      byCategory[key] = (byCategory[key] ?? 0) + _cents(entry);
    }
    final sorted = byCategory.entries.toList()
      ..sort(
        (a, b) => a.value == b.value
            ? a.key.compareTo(b.key)
            : b.value.compareTo(a.value),
      );
    return {
      'month': Dates.toMonth(month),
      'opening_cents': opening,
      'income_cents': income,
      'expense_cents': fixed + variable,
      'fixed_expense_cents': fixed,
      'variable_expense_cents': variable,
      'closing_cents': opening + income - fixed - variable,
      'savings_cents': opening + income - fixed - variable - start,
      'negative': opening + income - fixed - variable < 0,
      'expense_by_category': [
        for (final MapEntry(:key, :value) in sorted)
          {'category_key': key, 'amount_cents': value},
      ],
    };
  }

  int _openingBalance(DateTime firstMonth) {
    final anchor = latestBalance();
    if (anchor == null) {
      return 0;
    }
    final asOf = _date(anchor, 'as_of');
    final lastDay = firstMonth.subtract(const Duration(days: 1));
    final amount = _cents(anchor);
    return lastDay.isBefore(asOf)
        ? amount - _netBetween(lastDay, asOf)
        : amount + _netBetween(asOf, lastDay);
  }

  int _netBetween(DateTime after, DateTime through) => filteredEntries(
    from: after.add(const Duration(days: 1)),
    to: through,
  ).fold(0, (total, entry) => total + _signed(entry));

  Row _balanceFields(Row input, String? id) {
    final errors = <String, List<String>>{};
    final amount = input['amount_cents'];
    final asOf = _parseDate(input['as_of']);
    if (amount is! int) {
      errors['amount_cents'] = ['not_an_integer'];
    }
    if (asOf == null) {
      errors['as_of'] = ['blank'];
    } else if (asOf.isAfter(today)) {
      errors['as_of'] = ['in_future'];
    } else if (balances.any(
      (row) => row['id'] != id && _date(row, 'as_of') == asOf,
    )) {
      errors['as_of'] = ['taken'];
    }
    _raiseIfAny(errors);
    return {'amount_cents': amount, 'as_of': Dates.toIso(asOf!)};
  }

  Row _entryFields(Row input) {
    final errors = <String, List<String>>{};
    final category = categories
        .where((row) => row['id'] == input['category_id'])
        .firstOrNull;
    final description = (input['description'] as String?)?.trim() ?? '';
    final amount = input['amount_cents'];
    final dueOn = _parseDate(input['due_on']);
    final status = input['status'] ?? 'pending';
    final paidOn = _parseDate(input['paid_on']);
    final kind = category?['kind'];
    final nature = kind == 'expense'
        ? input['nature'] ?? category!['default_nature']
        : input['nature'];

    if (category == null) {
      errors['category'] = ['required'];
    }
    if (description.isEmpty) {
      errors['description'] = ['blank'];
    } else if (description.length > 200) {
      errors['description'] = ['too_long'];
    }
    if (amount is! int || amount <= 0) {
      errors['amount_cents'] = ['greater_than'];
    }
    if (dueOn == null) {
      errors['due_on'] = ['blank'];
    }
    if (status != 'pending' && status != 'paid') {
      errors['status'] = ['inclusion'];
    }
    if (paidOn != null && status != 'paid') {
      errors['paid_on'] = ['only_when_paid'];
    }
    if (kind == 'income' && nature != null) {
      errors['nature'] = ['only_for_expenses'];
    } else if (nature != null && nature != 'fixed' && nature != 'variable') {
      errors['nature'] = ['inclusion'];
    }
    _raiseIfAny(errors);
    return {
      'kind': kind,
      'nature': nature,
      'category_id': category!['id'],
      'description': description,
      'amount_cents': amount,
      'due_on': Dates.toIso(dueOn!),
      'status': status,
      'paid_on': paidOn == null ? null : Dates.toIso(paidOn),
    };
  }

  static void _raiseIfAny(FieldErrors errors) {
    if (errors.isNotEmpty) {
      throw DemoValidationError(errors);
    }
  }

  static Row _find(List<Row> rows, String id) =>
      rows.where((row) => row['id'] == id).firstOrNull ??
      (throw const DemoNotFound());

  static DateTime? _parseDate(Object? value) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    return parsed == null ? null : Dates.dateOnly(parsed);
  }

  static DateTime _date(Row row, String field) =>
      Dates.parseIso(row[field]! as String);

  static int _cents(Row row) => row['amount_cents']! as int;

  static int _signed(Row entry) =>
      entry['kind'] == 'income' ? _cents(entry) : -_cents(entry);
}
