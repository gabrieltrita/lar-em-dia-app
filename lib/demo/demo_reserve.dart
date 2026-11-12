import 'dart:math';

import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/demo/demo_database.dart';

typedef DemoReserveValue = ({int gross, int invested, int tax});

final class DemoLot {
  new(this.startedOn, this.principal);

  final DateTime startedOn;
  double principal;
}

class DemoReserve {
  new(this.database);

  static const selicTargetE8 = 13750000;
  static const cdiSpreadE8 = 100000;
  static const savingsMonthlyE8 = 500000;
  static const int cdiEstimateE8 = selicTargetE8 - cdiSpreadE8;
  static const e8 = 100000000;
  static const bps = 10000;
  static const businessDaysPerYear = 252;
  static const closedMonths = 3;
  static const maxGoalMonths = 24;
  static const maxProjectionMonths = 60;
  static const maxCdiPercentBps = 50000;
  static const maxAnnualRateBps = 10000;
  static const maxAmountCents = 100000000000;
  static const kinds = {
    'selic_treasury',
    'cdb',
    'savings',
    'idle',
    'fixed_rate',
  };
  static const movementKinds = {'anchor', 'deposit', 'withdrawal'};
  static const entryCategories = {
    'deposit': 'reserve_deposit',
    'withdrawal': 'reserve_withdrawal',
  };

  final DemoDatabase database;
  final List<Row> accounts = [];
  final List<Row> movements = [];
  int goalMonths = 6;
  int? goalCents;
  int _counter = 0;

  DateTime get ratesAsOf {
    var day = database.today.subtract(const Duration(days: 1));
    while (day.weekday > DateTime.friday) {
      day = day.subtract(const Duration(days: 1));
    }
    return day;
  }

  static int weekdays(DateTime first, DateTime last) {
    if (last.isBefore(first)) {
      return 0;
    }
    final days = last.difference(first).inDays + 1;
    final rest = days % 7;
    var count = days ~/ 7 * 5;
    for (var offset = 0; offset < rest; offset++) {
      if (first.add(Duration(days: offset)).weekday <= DateTime.friday) {
        count++;
      }
    }
    return count;
  }

  static double _dailyFromAnnual(double annual) =>
      pow(1 + annual, 1 / businessDaysPerYear).toDouble();

  static double dailyFactor(Row account) {
    final selic = _dailyFromAnnual(selicTargetE8 / e8);
    final cdi = _dailyFromAnnual(cdiEstimateE8 / e8) - 1;
    return switch (account['kind']) {
      'cdb' => 1 + cdi * (account['cdi_percent_bps']! as int) / bps,
      'fixed_rate' => _dailyFromAnnual(
        (account['annual_rate_bps']! as int) / bps,
      ),
      _ => selic,
    };
  }

  static double factor(Row account, DateTime from, DateTime to) {
    if (!to.isAfter(from) || account['kind'] == 'idle') {
      return 1;
    }
    if (account['kind'] == 'savings') {
      var anniversaries = 0;
      var next = Dates.addMonths(from, 1);
      while (!next.isAfter(to)) {
        anniversaries++;
        next = Dates.addMonths(next, 1);
      }
      return pow(1 + savingsMonthlyE8 / e8, anniversaries).toDouble();
    }
    final days = weekdays(from, to.subtract(const Duration(days: 1)));
    return pow(dailyFactor(account), days).toDouble();
  }

  static double taxRate(int days) => switch (days) {
    <= 180 => 0.225,
    <= 360 => 0.2,
    <= 720 => 0.175,
    _ => 0.15,
  };

  static bool exempt(Row account) =>
      account['tax_exempt'] == true ||
      account['kind'] == 'savings' ||
      account['kind'] == 'idle';

  List<Row> movementsOf(String accountId) =>
      movements.where((row) => row['account_id'] == accountId).toList()
        ..sort(_chronological);

  static int _chronological(Row a, Row b) {
    final byDate = (a['moved_on']! as String).compareTo(
      b['moved_on']! as String,
    );
    return byDate != 0
        ? byDate
        : (a['created_at']! as String).compareTo(b['created_at']! as String);
  }

  static (List<DemoLot>, bool) replay(Row account, List<Row> rows) {
    var lots = <DemoLot>[];
    var shortfall = false;
    for (final row in rows) {
      final movedOn = Dates.parseIso(row['moved_on']! as String);
      final amount = (row['amount_cents']! as int).toDouble();
      switch (row['kind']) {
        case 'anchor':
          lots = [DemoLot(movedOn, amount)];
        case 'deposit':
          lots.add(DemoLot(movedOn, amount));
        default:
          shortfall = !_withdraw(account, lots, movedOn, amount) || shortfall;
      }
    }
    return (lots, shortfall);
  }

  static bool _withdraw(
    Row account,
    List<DemoLot> lots,
    DateTime on,
    double amount,
  ) {
    final values = [
      for (final lot in lots)
        lot.principal * factor(account, lot.startedOn, on),
    ];
    if (amount > values.fold<double>(0, (sum, value) => sum + value).round()) {
      return false;
    }
    var remaining = amount;
    while (remaining > 0 && lots.isNotEmpty) {
      final value = values.removeAt(0);
      if (value <= remaining) {
        remaining -= value;
        lots.removeAt(0);
      } else {
        lots.first.principal *= 1 - remaining / value;
        remaining = 0;
      }
    }
    return true;
  }

  DemoReserveValue valueOn(Row account, DateTime date) {
    final iso = Dates.toIso(date);
    final (lots, _) = replay(account, [
      for (final row in movementsOf(account['id']! as String))
        if ((row['moved_on']! as String).compareTo(iso) <= 0) row,
    ]);
    var gross = 0.0;
    var invested = 0.0;
    var tax = 0.0;
    for (final lot in lots) {
      final value = lot.principal * factor(account, lot.startedOn, date);
      gross += value;
      invested += lot.principal;
      final gain = value - lot.principal;
      if (!exempt(account) && gain > 0) {
        tax += gain * taxRate(date.difference(lot.startedOn).inDays);
      }
    }
    return (gross: gross.round(), invested: invested.round(), tax: tax.round());
  }

  static Row valueFields(DemoReserveValue value) => {
    'gross_cents': value.gross,
    'net_cents': value.gross - value.tax,
    'invested_cents': value.invested,
    'yield_cents': value.gross - value.invested,
    'tax_cents': value.tax,
  };

  int netCentsOn(DateTime date) => accounts.fold(0, (total, account) {
    final value = valueOn(account, date);
    return total + value.gross - value.tax;
  });

  Map<String, int> _fixedByMonth() {
    final current = Dates.firstOfMonth(database.today);
    final byMonth = <String, int>{};
    for (final entry in database.filteredEntries(
      from: Dates.addMonths(current, -closedMonths),
      to: current.subtract(const Duration(days: 1)),
    )) {
      if (entry['kind'] == 'expense' && entry['nature'] == 'fixed') {
        final month = (entry['due_on']! as String).substring(0, 7);
        byMonth[month] =
            (byMonth[month] ?? 0) + (entry['amount_cents']! as int);
      }
    }
    return byMonth;
  }

  Row summary() {
    final today = database.today;
    final values = {
      for (final account in accounts)
        account['id']! as String: valueOn(account, today),
    };
    final gross = values.values.fold(0, (sum, value) => sum + value.gross);
    final invested = values.values.fold(
      0,
      (sum, value) => sum + value.invested,
    );
    final tax = values.values.fold(0, (sum, value) => sum + value.tax);
    final net = gross - tax;
    final fixed = _fixedByMonth();
    final average = fixed.isEmpty
        ? null
        : (fixed.values.fold(0, (sum, cents) => sum + cents) / fixed.length)
              .round();
    final suggestion = average == null
        ? null
        : {
            'average_fixed_cents': average,
            'months_counted': fixed.length,
            'goal_months': goalMonths,
            'suggested_cents': average * goalMonths,
            'coverage_months_e2': (net * 100 / average).round(),
          };
    final target = goalCents ?? suggestion?['suggested_cents'];
    return {
      'totals': valueFields((gross: gross, invested: invested, tax: tax)),
      'accounts': [
        for (final account in accounts)
          {...account, ...valueFields(values[account['id']]!)},
      ],
      'suggestion': suggestion,
      'goal': {
        'months': goalMonths,
        'cents': goalCents,
        'target_cents': target,
      },
      'alerts': [
        if (suggestion != null && accounts.isEmpty) 'no_reserve',
        if (accounts.isNotEmpty && target != null && net < target)
          'below_suggestion',
        if (accounts.any(
          (account) =>
              account['kind'] == 'idle' && values[account['id']]!.gross > 0,
        ))
          'idle_money',
      ],
      'rates_as_of': Dates.toIso(ratesAsOf),
    };
  }

  Row updateGoal(Row body) {
    final months = body.containsKey('goal_months')
        ? body['goal_months']
        : goalMonths;
    final cents = body.containsKey('goal_cents')
        ? body['goal_cents']
        : goalCents;
    final errors = <String, List<String>>{
      if (months is! int || months < 1 || months > maxGoalMonths)
        'goal_months': ['less_than_or_equal_to'],
      if (cents != null &&
          (cents is! int || cents < 1 || cents > maxAmountCents))
        'goal_cents': ['greater_than'],
    };
    if (errors.isNotEmpty) {
      throw DemoValidationError(errors);
    }
    goalMonths = months! as int;
    goalCents = cents as int?;
    return summary();
  }

  Row projection(int months) => {
    'months': [
      for (var offset = 0; offset < months; offset++)
        _projectionMonth(
          Dates.addMonths(Dates.firstOfMonth(database.today), offset),
        ),
    ],
    'assumptions': {
      'selic_target_e8': selicTargetE8,
      'cdi_estimate_e8': cdiEstimateE8,
      'savings_monthly_e8': savingsMonthlyE8,
      'rates_as_of': Dates.toIso(ratesAsOf),
      'holidays_ignored': true,
      'iof_ignored': true,
    },
  };

  Row _projectionMonth(DateTime month) {
    final end = Dates.lastOfMonth(month);
    final values = [
      for (final account in accounts) (account, valueOn(account, end)),
    ];
    final gross = values.fold(0, (sum, item) => sum + item.$2.gross);
    final tax = values.fold(0, (sum, item) => sum + item.$2.tax);
    return {
      'month': Dates.toMonth(month),
      'gross_cents': gross,
      'net_cents': gross - tax,
      'accounts': [
        for (final (account, value) in values)
          {
            'id': account['id'],
            'gross_cents': value.gross,
            'net_cents': value.gross - value.tax,
          },
      ],
    };
  }

  Row findAccount(String id) =>
      accounts.where((row) => row['id'] == id).firstOrNull ??
      (throw const DemoNotFound());

  Row createAccount(Row body) {
    final account = {
      'id': database.nextId('reserve-account'),
      ..._accountFields(body),
      'created_at': _now(),
    };
    accounts.add(account);
    return account;
  }

  Row updateAccount(String id, Row body) {
    final account = findAccount(id);
    final merged = {
      for (final field in [
        'name',
        'kind',
        'cdi_percent_bps',
        'annual_rate_bps',
        'tax_exempt',
      ])
        field: body.containsKey(field) ? body[field] : account[field],
    };
    account.addAll(_accountFields(merged));
    return account;
  }

  void deleteAccount(String id) {
    final account = findAccount(id);
    for (final movement in movementsOf(id)) {
      _removeEntry(movement);
      movements.remove(movement);
    }
    accounts.remove(account);
  }

  Row _accountFields(Row body) {
    final name = (body['name'] as String?)?.trim() ?? '';
    final kind = body['kind'];
    final cdi = body['cdi_percent_bps'];
    final rate = body['annual_rate_bps'];
    final errors = <String, List<String>>{
      if (name.isEmpty)
        'name': ['blank']
      else if (name.length > 100)
        'name': ['too_long'],
      if (!kinds.contains(kind)) 'kind': ['inclusion'],
      ..._rateErrors('cdi_percent_bps', cdi, kind == 'cdb', maxCdiPercentBps),
      ..._rateErrors(
        'annual_rate_bps',
        rate,
        kind == 'fixed_rate',
        maxAnnualRateBps,
      ),
    };
    if (errors.isNotEmpty) {
      throw DemoValidationError(errors);
    }
    return {
      'name': name,
      'kind': kind,
      'cdi_percent_bps': cdi,
      'annual_rate_bps': rate,
      'tax_exempt': body['tax_exempt'] == true,
    };
  }

  static FieldErrors _rateErrors(
    String field,
    Object? value,
    bool used,
    int max,
  ) => {
    if (used && value == null) field: ['rate_required'],
    if (!used && value != null) field: ['rate_not_allowed'],
    if (value != null && (value is! int || value < 1 || value > max))
      field: ['less_than_or_equal_to'],
  };

  List<Row> listMovements(String? accountId) => [
    for (final row in [...movements]..sort(_chronological))
      if (accountId == null || row['account_id'] == accountId) _public(row),
  ];

  Row findMovement(String id) =>
      movements.where((row) => row['id'] == id).firstOrNull ??
      (throw const DemoNotFound());

  Row showMovement(String id) => _public(findMovement(id));

  Row createMovement(Row body) {
    final account = accounts
        .where((row) => row['id'] == body['account_id'])
        .firstOrNull;
    if (account == null) {
      throw const DemoValidationError({
        'account': ['required'],
      });
    }
    final row = {
      'id': database.nextId('reserve-movement'),
      'account_id': account['id'],
      ..._movementFields(body, null),
      'entry_id': null,
      'created_at': _now(),
    };
    _checkLedger(account, [...movementsOf(account['id']! as String), row]);
    movements.add(row);
    _syncEntry(row, account, debit: body['debit_balance'] == true);
    return _public(row);
  }

  Row updateMovement(String id, Row body) {
    final row = findMovement(id);
    if (body['account_id'] case final Object accountId
        when accountId != row['account_id']) {
      throw const DemoValidationError({
        'account_id': ['immutable'],
      });
    }
    final account = findAccount(row['account_id']! as String);
    final updated = {...row, ..._movementFields(body, row)};
    _checkLedger(account, [
      for (final other in movementsOf(account['id']! as String))
        if (other['id'] != id) other,
      updated,
    ]);
    row.addAll(updated);
    _syncEntry(
      row,
      account,
      debit: body.containsKey('debit_balance')
          ? body['debit_balance'] == true
          : row['entry_id'] != null,
    );
    return _public(row);
  }

  void deleteMovement(String id) {
    final row = findMovement(id);
    final account = findAccount(row['account_id']! as String);
    final others = [
      for (final other in movementsOf(account['id']! as String))
        if (other['id'] != id) other,
    ];
    if (replay(account, others).$2) {
      throw const DemoUnprocessable('insufficient_reserve');
    }
    _removeEntry(row);
    movements.remove(row);
  }

  Row _movementFields(Row body, Row? existing) {
    Object? field(String name) =>
        body.containsKey(name) ? body[name] : existing?[name];
    final kind = field('kind');
    final amount = field('amount_cents');
    final movedOn = field('moved_on') is String
        ? DateTime.tryParse(field('moved_on')! as String)
        : null;
    final anchor = kind == 'anchor';
    final errors = <String, List<String>>{
      if (!movementKinds.contains(kind)) 'kind': ['inclusion'],
      if (movedOn == null)
        'moved_on': ['blank']
      else if (movedOn.isAfter(database.today))
        'moved_on': ['in_future'],
      if (amount is! int ||
          amount < (anchor ? 0 : 1) ||
          amount > maxAmountCents)
        'amount_cents': ['greater_than'],
      if (anchor && body['debit_balance'] == true)
        'debit_balance': ['anchor_not_allowed'],
    };
    if (errors.isNotEmpty) {
      throw DemoValidationError(errors);
    }
    return {
      'kind': kind,
      'moved_on': Dates.toIso(Dates.dateOnly(movedOn!)),
      'amount_cents': amount,
    };
  }

  static void _checkLedger(Row account, List<Row> rows) {
    if (replay(account, [...rows]..sort(_chronological)).$2) {
      throw const DemoValidationError({
        'amount_cents': ['insufficient_reserve'],
      });
    }
  }

  void _syncEntry(Row row, Row account, {required bool debit}) {
    _removeEntry(row);
    final key = entryCategories[row['kind']];
    if (!debit || key == null) {
      return;
    }
    final category = database.categories
        .where((category) => category['key'] == key)
        .first;
    final entry = database.createEntry({
      'category_id': category['id'],
      'description': account['name'],
      'amount_cents': row['amount_cents'],
      'due_on': row['moved_on'],
      'status': 'paid',
      'paid_on': row['moved_on'],
    });
    row['entry_id'] = entry['id'];
  }

  void _removeEntry(Row row) {
    if (row['entry_id'] case final String entryId) {
      database.entries.removeWhere((entry) => entry['id'] == entryId);
      row['entry_id'] = null;
    }
  }

  static Row _public(Row row) => {
    for (final MapEntry(:key, :value) in row.entries)
      if (key != 'created_at') key: value,
  };

  String _now() => DateTime.utc(
    database.today.year,
    database.today.month,
    database.today.day,
    12,
  ).add(Duration(microseconds: ++_counter)).toIso8601String();
}
