import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/money/per_share.dart';
import 'package:lar_em_dia/demo/demo_database.dart';

typedef DemoAsset = ({
  String ticker,
  String name,
  String type,
  String sector,
  int closeCents,
  int monthlyDriftBps,
});

final class DemoLedgerState {
  const new({
    this.quantity = 0,
    this.costCents = 0,
    this.contributedCents = 0,
    this.realizedCents = 0,
  });

  final int quantity;
  final int costCents;
  final int contributedCents;
  final int realizedCents;

  int get averagePriceE8 => quantity == 0
      ? 0
      : PerShare.roundedDivision(costCents * PerShare.centsToE8, quantity);
}

class DemoLedger {
  new(List<Row> transactions)
    : _transactions = [...transactions]..sort(_chronological);

  final List<Row> _transactions;

  static int _chronological(Row a, Row b) {
    final byDate = (a['traded_on']! as String).compareTo(
      b['traded_on']! as String,
    );
    return byDate != 0
        ? byDate
        : (a['created_at']! as String).compareTo(b['created_at']! as String);
  }

  List<DemoLedgerState> get states {
    var current = const DemoLedgerState();
    return [
      for (final transaction in _transactions)
        current = apply(current, transaction),
    ];
  }

  DemoLedgerState get state => states.lastOrNull ?? const DemoLedgerState();

  DemoLedgerState stateOn(String isoDate) {
    var current = const DemoLedgerState();
    for (final (index, state) in states.indexed) {
      if ((_transactions[index]['traded_on']! as String).compareTo(isoDate) >
          0) {
        break;
      }
      current = state;
    }
    return current;
  }

  bool get shortfall => states.any((state) => state.quantity < 0);

  static int amountCents(Row transaction) {
    final gross =
        (transaction['quantity']! as int) *
        (transaction['price_cents']! as int);
    final fees = transaction['fees_cents']! as int;
    return transaction['kind'] == 'buy' ? gross + fees : gross - fees;
  }

  static DemoLedgerState apply(DemoLedgerState state, Row transaction) {
    final quantity = transaction['quantity']! as int;
    return switch (transaction['kind']) {
      'buy' => DemoLedgerState(
        quantity: state.quantity + quantity,
        costCents: state.costCents + amountCents(transaction),
        contributedCents: state.contributedCents + amountCents(transaction),
        realizedCents: state.realizedCents,
      ),
      'sell' => _sell(state, transaction),
      'reverse_split' => _resize(state, -quantity),
      _ => _resize(state, quantity),
    };
  }

  static DemoLedgerState _sell(DemoLedgerState state, Row transaction) {
    final quantity = transaction['quantity']! as int;
    final left = state.quantity - quantity;
    if (left < 0) {
      return DemoLedgerState(
        quantity: left,
        costCents: state.costCents,
        contributedCents: state.contributedCents,
        realizedCents: state.realizedCents,
      );
    }
    final removed = left == 0
        ? state.costCents
        : PerShare.roundedDivision(state.costCents * quantity, state.quantity);
    return DemoLedgerState(
      quantity: left,
      costCents: state.costCents - removed,
      contributedCents: state.contributedCents - amountCents(transaction),
      realizedCents: state.realizedCents + amountCents(transaction) - removed,
    );
  }

  static DemoLedgerState _resize(DemoLedgerState state, int change) {
    final quantity = state.quantity + change;
    return DemoLedgerState(
      quantity: quantity,
      costCents: quantity > 0 ? state.costCents : 0,
      contributedCents: state.contributedCents,
      realizedCents: state.realizedCents,
    );
  }
}

class DemoInvestments {
  new(this.database);

  static const maxQuantity = 1000000000;
  static const maxHistoryMonths = 120;
  static const kinds = {'buy', 'sell', 'split', 'reverse_split', 'bonus'};
  static const trades = {'buy', 'sell'};
  static const goals = {'income', 'growth'};

  static const List<DemoAsset> catalog = [
    (
      ticker: 'BBAS3',
      name: 'BANCO DO BRASIL S.A.',
      type: 'stock',
      sector: 'Bancos',
      closeCents: 2745,
      monthlyDriftBps: 60,
    ),
    (
      ticker: 'BTLG11',
      name: 'BTG PACTUAL LOGISTICA FII',
      type: 'fii',
      sector: 'Logística',
      closeCents: 10120,
      monthlyDriftBps: 20,
    ),
    (
      ticker: 'HGLG11',
      name: 'PATRIA LOG FII',
      type: 'fii',
      sector: 'Logística',
      closeCents: 15890,
      monthlyDriftBps: 25,
    ),
    (
      ticker: 'ITSA4',
      name: 'ITAUSA S.A.',
      type: 'stock',
      sector: 'Holdings',
      closeCents: 1062,
      monthlyDriftBps: 90,
    ),
    (
      ticker: 'KNRI11',
      name: 'KINEA RENDA IMOBILIARIA FII',
      type: 'fii',
      sector: 'Híbrido',
      closeCents: 14630,
      monthlyDriftBps: 15,
    ),
    (
      ticker: 'MXRF11',
      name: 'MAXI RENDA FII',
      type: 'fii',
      sector: 'Títulos e Valores Mobiliários',
      closeCents: 958,
      monthlyDriftBps: -10,
    ),
    (
      ticker: 'PETR4',
      name: 'PETROLEO BRASILEIRO S.A. PETROBRAS',
      type: 'stock',
      sector: 'Petróleo e Gás',
      closeCents: 3712,
      monthlyDriftBps: 40,
    ),
    (
      ticker: 'TAEE11',
      name: 'TRANSMISSORA ALIANCA DE ENERGIA ELETRICA S.A.',
      type: 'stock',
      sector: 'Energia Elétrica',
      closeCents: 3584,
      monthlyDriftBps: 30,
    ),
    (
      ticker: 'VALE3',
      name: 'VALE S.A.',
      type: 'stock',
      sector: 'Mineração',
      closeCents: 6178,
      monthlyDriftBps: -20,
    ),
    (
      ticker: 'VISC11',
      name: 'VINCI SHOPPING CENTERS FII',
      type: 'fii',
      sector: 'Shoppings',
      closeCents: 10450,
      monthlyDriftBps: 10,
    ),
    (
      ticker: 'WEGE3',
      name: 'WEG S.A.',
      type: 'stock',
      sector: 'Máquinas e Equipamentos',
      closeCents: 4890,
      monthlyDriftBps: 110,
    ),
    (
      ticker: 'XPML11',
      name: 'XP MALLS FII',
      type: 'fii',
      sector: 'Shoppings',
      closeCents: 10580,
      monthlyDriftBps: 12,
    ),
  ];

  final DemoDatabase database;
  final List<Row> transactions = [];
  final Map<String, String> positionGoals = {};

  DateTime get lastTradingDay {
    var day = database.today.subtract(const Duration(days: 1));
    while (day.weekday > DateTime.friday) {
      day = day.subtract(const Duration(days: 1));
    }
    return day;
  }

  static DemoAsset? findAsset(String? ticker) => catalog
      .where((asset) => asset.ticker == ticker?.toUpperCase())
      .firstOrNull;

  int closeCentsOn(DemoAsset asset, DateTime day) {
    final monthsBack =
        (lastTradingDay.year - day.year) * 12 +
        lastTradingDay.month -
        day.month;
    final wave = ((monthsBack * 7 + asset.ticker.codeUnitAt(0)) % 11 - 5) * 40;
    final factor = 10000 - asset.monthlyDriftBps * monthsBack + wave;
    return monthsBack <= 0
        ? asset.closeCents
        : PerShare.roundedDivision(asset.closeCents * factor, 10000);
  }

  Row quoteOf(DemoAsset asset) => {
    'quoted_on': Dates.toIso(lastTradingDay),
    'close_cents': asset.closeCents,
    'volume_cents': asset.closeCents * 125000,
    'trades_count': 4200,
  };

  static Row assetRow(DemoAsset asset) => {
    'ticker': asset.ticker,
    'name': asset.name,
    'asset_type': asset.type,
    'sector': asset.sector,
  };

  List<Row> searchAssets(String? query) {
    final text = query?.trim().toUpperCase() ?? '';
    return [
      for (final asset in catalog)
        if (text.isEmpty ||
            asset.ticker.startsWith(text) ||
            asset.name.contains(text))
          assetRow(asset),
    ];
  }

  Row assetDetail(String ticker) {
    final asset = findAsset(ticker) ?? (throw const DemoNotFound());
    return {
      ...assetRow(asset),
      'isin': 'BR${asset.ticker.substring(0, 4)}DEMO00',
      'cnpj': null,
      'active': true,
      'quote': quoteOf(asset),
    };
  }

  List<Row> transactionsOf(String ticker) =>
      transactions.where((row) => row['ticker'] == ticker).toList();

  List<Row> listTransactions(String? ticker) {
    final rows = ticker == null || ticker.isEmpty
        ? [...transactions]
        : transactionsOf(ticker.toUpperCase());
    return [for (final row in DemoLedger(rows)._transactions) _public(row)];
  }

  Row findTransaction(String id) => _public(_find(id));

  Row _find(String id) =>
      transactions.where((row) => row['id'] == id).firstOrNull ??
      (throw const DemoNotFound());

  static Row _public(Row row) => {
    for (final MapEntry(:key, :value) in row.entries)
      if (key != 'goal' && key != 'debit_balance') key: value,
  };

  Row createTransaction(Row input) {
    final asset = findAsset(input['ticker'] as String?);
    final row = _validated(
      {
        'id': database.nextId('investment'),
        'ticker': asset?.ticker ?? input['ticker'],
        'kind': input['kind'],
        'traded_on': input['traded_on'],
        'quantity': input['quantity'],
        'price_cents': input['price_cents'],
        'fees_cents': input['fees_cents'] ?? 0,
        'entry_id': null,
        'created_at': _now(),
        'updated_at': _now(),
      },
      debitBalance: input['debit_balance'],
      known: asset != null,
    );
    final others = transactionsOf(row['ticker']! as String);
    _checkLedger([...others, row]);
    transactions.add(row);
    final goal = input['goal'];
    positionGoals.putIfAbsent(
      row['ticker']! as String,
      () => goals.contains(goal)
          ? goal! as String
          : asset!.type == 'fii'
          ? 'income'
          : 'growth',
    );
    _syncEntry(row, input['debit_balance'] == true);
    return _public(row);
  }

  Row updateTransaction(String id, Row input) {
    final current = _find(id);
    final merged = {
      ...current,
      for (final field in [
        'kind',
        'traded_on',
        'quantity',
        'price_cents',
        'fees_cents',
      ])
        if (input.containsKey(field)) field: input[field],
    };
    final debit = input.containsKey('debit_balance')
        ? input['debit_balance']
        : current['entry_id'] != null;
    final row = _validated(merged, debitBalance: debit, known: true);
    final others = transactionsOf(current['ticker']! as String)
        .where((other) => other['id'] != id);
    _checkLedger([...others, row]);
    current
      ..addAll(row)
      ..['updated_at'] = _now();
    _syncEntry(current, debit == true);
    return _public(current);
  }

  void deleteTransaction(String id) {
    final row = _find(id);
    final ticker = row['ticker']! as String;
    final others = transactionsOf(ticker)
        .where((other) => other['id'] != id)
        .toList();
    if (DemoLedger(others).shortfall) {
      throw const DemoUnprocessable('insufficient_quantity');
    }
    _syncEntry(row, false);
    transactions.remove(row);
    if (others.isEmpty) {
      positionGoals.remove(ticker);
    }
  }

  Row updateGoal(String ticker, Row input) {
    final key = ticker.toUpperCase();
    if (!positionGoals.containsKey(key)) {
      throw const DemoNotFound();
    }
    final goal = input['goal'];
    if (!goals.contains(goal)) {
      throw const DemoValidationError({
        'goal': ['inclusion'],
      });
    }
    positionGoals[key] = goal! as String;
    return {
      'ticker': key,
      'goal': goal,
      'created_at': _now(),
      'updated_at': _now(),
    };
  }

  Row portfolio({String? goal}) {
    final positions = [
      for (final ticker in positionGoals.keys.toList()..sort())
        if (goal == null ||
            !goals.contains(goal) ||
            positionGoals[ticker] == goal)
          _position(ticker),
    ].where((position) => position['quantity'] != 0).toList();
    return {
      'totals': _summary(positions),
      'goals': {
        for (final name in goals)
          name: _summary(
            positions.where((position) => position['goal'] == name).toList(),
          ),
      },
      'positions': positions,
    };
  }

  Row _position(String ticker) {
    final asset = findAsset(ticker)!;
    final state = DemoLedger(transactionsOf(ticker)).state;
    final value = state.quantity * asset.closeCents;
    return {
      'ticker': ticker,
      'name': asset.name,
      'asset_type': asset.type,
      'goal': positionGoals[ticker],
      'quantity': state.quantity,
      'average_price_e8': state.averagePriceE8,
      'cost_cents': state.costCents,
      'contributed_cents': state.contributedCents,
      'realized_cents': state.realizedCents,
      'quote': quoteOf(asset),
      'market_value_cents': value,
      'gain_cents': value - state.costCents,
    };
  }

  static Row _summary(List<Row> positions) {
    int sum(String field) =>
        positions.fold(0, (total, row) => total + (row[field]! as int));
    return {
      'contributed_cents': sum('contributed_cents'),
      'cost_cents': sum('cost_cents'),
      'market_value_cents': sum('market_value_cents'),
      'gain_cents': sum('market_value_cents') - sum('cost_cents'),
      'realized_cents': sum('realized_cents'),
    };
  }

  List<Row> history() {
    if (transactions.isEmpty) {
      return const [];
    }
    final first = Dates.parseIso(
      DemoLedger(transactions)._transactions.first['traded_on']! as String,
    );
    final today = database.today;
    var start = Dates.firstOfMonth(first);
    final earliest = Dates.addMonths(
      Dates.firstOfMonth(today),
      -(maxHistoryMonths - 1),
    );
    if (start.isBefore(earliest)) {
      start = earliest;
    }
    final months = <Row>[];
    for (
      var month = start;
      !month.isAfter(today);
      month = Dates.addMonths(month, 1)
    ) {
      final end = Dates.lastOfMonth(month).isAfter(today)
          ? today
          : Dates.lastOfMonth(month);
      final iso = Dates.toIso(end);
      var contributed = 0;
      var value = 0;
      for (final ticker in positionGoals.keys) {
        final state = DemoLedger(transactionsOf(ticker)).stateOn(iso);
        contributed += state.contributedCents;
        value += state.quantity * closeCentsOn(findAsset(ticker)!, end);
      }
      months.add({
        'month': Dates.toMonth(month),
        'contributed_cents': contributed,
        'market_value_cents': value,
      });
    }
    return months;
  }

  Row _validated(
    Row row, {
    required Object? debitBalance,
    required bool known,
  }) {
    final kind = row['kind'];
    final trade = trades.contains(kind);
    final quantity = row['quantity'];
    final price = row['price_cents'];
    final fees = row['fees_cents'];
    final tradedOn = row['traded_on'] is String
        ? DateTime.tryParse(row['traded_on']! as String)
        : null;
    final errors = <String, List<String>>{
      if (!known) 'ticker': ['unknown_asset'],
      if (!kinds.contains(kind)) 'kind': ['inclusion'],
      if (quantity is! int || quantity < 1 || quantity > maxQuantity)
        'quantity': ['greater_than'],
      if (tradedOn == null)
        'traded_on': ['blank']
      else if (tradedOn.isAfter(database.today))
        'traded_on': ['in_future'],
      if (trade && (price is! int || price < 1))
        'price_cents': ['greater_than']
      else if (!trade && price != null)
        'price_cents': ['only_for_trades'],
      if (fees is! int || fees < 0)
        'fees_cents': ['greater_than_or_equal_to']
      else if (!trade && fees != 0)
        'fees_cents': ['only_for_trades'],
      if (!trade && debitBalance == true) 'debit_balance': ['only_for_trades'],
    };
    if (errors.isNotEmpty) {
      throw DemoValidationError(errors);
    }
    return {...row, 'traded_on': Dates.toIso(Dates.dateOnly(tradedOn!))};
  }

  static void _checkLedger(List<Row> rows) {
    if (DemoLedger(rows).shortfall) {
      throw const DemoValidationError({
        'quantity': ['insufficient_quantity'],
      });
    }
  }

  void _syncEntry(Row row, bool debit) {
    if (row['entry_id'] case final String entryId) {
      database.entries.removeWhere((entry) => entry['id'] == entryId);
      row['entry_id'] = null;
    }
    if (!debit || !trades.contains(row['kind'])) {
      return;
    }
    final key = row['kind'] == 'buy'
        ? 'investment_contribution'
        : 'investment_redemption';
    final category = database.categories
        .where((category) => category['key'] == key)
        .first;
    final entry = database.createEntry({
      'category_id': category['id'],
      'description': '${row['ticker']} × ${row['quantity']}',
      'amount_cents': DemoLedger.amountCents(row),
      'due_on': row['traded_on'],
      'status': 'paid',
      'paid_on': row['traded_on'],
    });
    row['entry_id'] = entry['id'];
  }

  String _now() => DateTime.utc(
    database.today.year,
    database.today.month,
    database.today.day,
    12,
  ).add(Duration(microseconds: ++_counter)).toIso8601String();

  int _counter = 0;
}
