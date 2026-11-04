import 'dart:math';

import 'package:lar_em_dia/core/dates/dates.dart';

typedef Row = Map<String, Object?>;
typedef FieldErrors = Map<String, List<String>>;

final class DemoValidationError implements Exception {
  const new(this.details);

  final FieldErrors details;
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
    final count = input['entries_count'];
    final direction = input['direction'];
    final errors = <String, List<String>>{
      if (count is! int)
        'entries_count': ['not_a_number']
      else if (count < minSeriesCount)
        'entries_count': ['greater_than_or_equal_to']
      else if (count > maxSeriesCount)
        'entries_count': ['less_than_or_equal_to'],
      if (direction != 'forward' && direction != 'backward')
        'direction': ['inclusion'],
    };
    final Row base;
    try {
      base = _entryFields(input);
    } on DemoValidationError catch (error) {
      throw DemoValidationError({...errors, ...error.details});
    }
    _raiseIfAny(errors);
    final total = count! as int;
    final row = {
      'id': nextId('series'),
      'kind': 'recurring',
      'entries_count': total,
    };
    series.add(row);
    final baseDueOn = _date(base, 'due_on');
    final step = direction == 'forward' ? 1 : -1;
    final dueDates = [
      for (var offset = 0; offset < total; offset++)
        _shift(baseDueOn, offset * step),
    ]..sort();
    final created = [
      for (final (index, dueOn) in dueDates.indexed)
        _seriesEntry(base, dueOn, row['id']! as String, index + 1),
    ];
    entries.addAll(created);
    return {...row, 'entries': created};
  }

  Row _seriesEntry(Row base, DateTime dueOn, String seriesId, int position) {
    final isBase = dueOn == _date(base, 'due_on');
    final paid = base['status'] == 'paid' && !dueOn.isAfter(today);
    return {
      ...base,
      'id': nextId('entry'),
      'due_on': Dates.toIso(dueOn),
      if (!isBase) 'status': paid ? 'paid' : 'pending',
      if (!isBase) 'paid_on': paid ? Dates.toIso(dueOn) : null,
      'series_id': seriesId,
      'series_position': position,
    };
  }

  static DateTime _shift(DateTime date, int months) {
    final month = Dates.addMonths(Dates.firstOfMonth(date), months);
    return DateTime(
      month.year,
      month.month,
      min(date.day, Dates.lastOfMonth(month).day),
    );
  }

  Row updateEntry(String id, Row input) {
    final entry = findEntry(id);
    final merged = {...entry, ...input};
    if (input.containsKey('category_id') &&
        input['category_id'] != entry['category_id'] &&
        !input.containsKey('nature')) {
      merged['nature'] = entry['nature'];
    }
    return entry..addAll(_entryFields(merged));
  }

  void deleteEntry(String id) => entries.remove(findEntry(id));

  Row? latestBalance() => sortedBalances().firstOrNull;

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
    return {
      'month': Dates.toMonth(month),
      'opening_cents': opening,
      'income_cents': income,
      'expense_cents': fixed + variable,
      'fixed_expense_cents': fixed,
      'variable_expense_cents': variable,
      'closing_cents': opening + income - fixed - variable,
      'savings_cents': opening + income - fixed - variable - start,
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
