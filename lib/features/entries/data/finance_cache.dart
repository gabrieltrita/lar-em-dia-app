import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/cache/local_cache.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/balance/domain/balance.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/projection/data/projection_dtos.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';

@lazySingleton
class FinanceCache implements LocalCache {
  static const maxProjectionMonths = 60;

  final categories = <EntryKind, List<Category>>{};
  final _months = <DateTime, List<Entry>>{};
  final _pending = <String, Future<Object?>>{};
  Projection? _projection;
  Balance? _latestBalance;
  bool _latestBalanceKnown = false;
  int _generation = 0;

  int get generation => _generation;

  @override
  void clear() {
    categories.clear();
    _months.clear();
    _pending.clear();
    _projection = null;
    forgetLatestBalance();
    _generation++;
  }

  Future<T> once<T>(String key, Future<T> Function() load) {
    if (_pending[key] case final Future<Object?> pending) {
      return pending.then((value) => value as T);
    }
    final generation = _generation;
    final future = load().whenComplete(() {
      if (generation == _generation) {
        _pending.removeWhere((pendingKey, _) => pendingKey == key);
      }
    });
    _pending[key] = future;
    return future;
  }

  bool hasMonth(DateTime month) => _months.containsKey(month);

  void storeMonths(DateTime first, DateTime last, List<Entry> entries) {
    for (final month in monthsBetween(first, last)) {
      _months[month] = [];
    }
    upsertEntries(entries);
  }

  List<Entry> entriesBetween(DateTime from, DateTime to) => [
    for (final month in monthsBetween(
      Dates.firstOfMonth(from),
      Dates.firstOfMonth(to),
    ))
      for (final entry in _months[month] ?? const <Entry>[])
        if (!entry.dueOn.isBefore(from) && !entry.dueOn.isAfter(to)) entry,
  ];

  (DateTime, DateTime) loadedRun(DateTime first, DateTime last) {
    var start = first;
    var end = last;
    while (hasMonth(Dates.addMonths(start, -1))) {
      start = Dates.addMonths(start, -1);
    }
    while (hasMonth(Dates.addMonths(end, 1))) {
      end = Dates.addMonths(end, 1);
    }
    return (start, end);
  }

  void upsertEntries(Iterable<Entry> entries) {
    removeEntries({for (final entry in entries) entry.id});
    for (final entry in entries) {
      final month = _months[Dates.firstOfMonth(entry.dueOn)];
      if (month != null) {
        month
          ..add(entry)
          ..sort((a, b) => a.dueOn.compareTo(b.dueOn));
      }
    }
  }

  void removeEntries(Set<String> ids) {
    for (final month in _months.values) {
      month.removeWhere((entry) => ids.contains(entry.id));
    }
  }

  void replaceSeries(String seriesId, List<Entry> entries) {
    for (final month in _months.values) {
      month.removeWhere((entry) => entry.seriesId == seriesId);
    }
    upsertEntries(entries);
  }

  Projection? projection(DateTime from, ProjectionPeriod period) {
    final cached = _projection;
    return cached == null ? null : slice(cached, from, period);
  }

  ({DateTime from, int months})? get projectionWindow => switch (_projection) {
    Projection(:final months) when months.isNotEmpty => (
      from: months.first.month,
      months: months.length,
    ),
    _ => null,
  };

  void storeProjection(Projection fetched) {
    final cached = _projection;
    if (cached == null || fetched.months.isEmpty) {
      _projection = fetched;
      return;
    }
    final rows = {
      for (final row in cached.months) row.month: row,
      for (final row in fetched.months) row.month: row,
    };
    final months = rows.keys.toList()..sort();
    final contiguous =
        monthsBetween(months.first, months.last).length == months.length;
    _projection = contiguous && months.length <= maxProjectionMonths
        ? fetched.copyWith(months: [for (final month in months) rows[month]!])
        : fetched;
  }

  String withProjectionWindow(
    String path, {
    Map<String, String> query = const {},
  }) {
    final window = projectionWindow;
    final parameters = {
      ...query,
      if (window != null) ...{
        'projection_from': Dates.toMonth(window.from),
        'projection_months': '${window.months}',
      },
    };
    return parameters.isEmpty
        ? path
        : Uri(path: path, queryParameters: parameters).toString();
  }

  void applyProjectionMeta(Json meta) {
    if (meta['projection'] case final Json projection) {
      _projection = ProjectionDto.fromJson(projection).toDomain();
    }
  }

  bool get latestBalanceKnown => _latestBalanceKnown;

  Balance? get latestBalance => _latestBalance;

  set latestBalance(Balance? balance) {
    _latestBalance = balance;
    _latestBalanceKnown = true;
  }

  void forgetLatestBalance() {
    _latestBalance = null;
    _latestBalanceKnown = false;
  }

  static Projection? slice(
    Projection source,
    DateTime from,
    ProjectionPeriod period,
  ) {
    final rows = source.months;
    if (rows.isEmpty) {
      return null;
    }
    final start = monthsBetween(rows.first.month, from).length - 1;
    final count = period.months ?? _monthsThroughLastEntry(source, from);
    if (start < 0 || start + count > rows.length) {
      return null;
    }
    final months = rows.sublist(start, start + count);
    final base = months.first.openingCents;
    final selected = [
      for (final month in months)
        month.copyWith(savingsCents: month.closingCents - base),
    ];
    final negative = [
      for (final month in selected)
        if (month.isNegative) month.month,
    ];
    return source.copyWith(
      months: selected,
      firstNegativeMonth: negative.firstOrNull,
      negativeMonthsCount: negative.length,
    );
  }

  static int _monthsThroughLastEntry(Projection source, DateTime from) {
    final last = source.lastEntryMonth;
    if (last == null || last.isBefore(from)) {
      return 1;
    }
    final span = monthsBetween(from, last).length;
    return span > maxProjectionMonths ? maxProjectionMonths : span;
  }

  static List<DateTime> monthsBetween(DateTime first, DateTime last) => [
    for (
      var month = first;
      !month.isAfter(last);
      month = Dates.addMonths(month, 1)
    )
      month,
  ];
}
