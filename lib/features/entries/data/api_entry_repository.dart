import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/features/entries/data/entry_dtos.dart';
import 'package:lar_em_dia/features/entries/data/finance_cache.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/domain/entry_repository.dart';

@LazySingleton(as: EntryRepository)
class ApiEntryRepository implements EntryRepository {
  new(this._client, this._cache);

  static const path = '/entries';
  static const seriesPath = '/entry_series';
  static const pageSize = 500;
  static const blockMonths = 6;
  static const prefetchMargin = 2;

  final ApiClient _client;
  final FinanceCache _cache;

  @override
  Future<List<Category>> categories(EntryKind kind) async {
    if (_cache.categories[kind] case final List<Category> cached) {
      return cached;
    }
    final generation = _cache.generation;
    final categories = await _cache.once('categories:${kind.name}', () async {
      final response = await _client.get<List<Category>>(
        '/categories',
        decode: (data) => (data! as List<dynamic>)
            .map((item) => CategoryDto.fromJson(item as Json).toDomain())
            .toList(),
        query: {'kind': kind.name},
      );
      return response.data;
    });
    if (generation == _cache.generation) {
      _cache.categories[kind] = categories;
    }
    return categories;
  }

  @override
  Future<Category> createCategory({
    required EntryKind kind,
    required String name,
    EntryNature? defaultNature,
  }) async {
    final response = await _client.post<Category>(
      '/categories',
      body: {
        'kind': kind.name,
        'name': name,
        'default_nature': ?defaultNature?.name,
      },
      decode: (data) => CategoryDto.fromJson(data! as Json).toDomain(),
    );
    final category = response.data;
    if (_cache.categories[kind] case final List<Category> cached) {
      _cache.categories[kind] = [...cached, category];
    }
    return category;
  }

  @override
  Future<void> deleteCategory(Category category) async {
    await _client.delete('/categories/${category.id}');
    if (_cache.categories[category.kind] case final List<Category> cached) {
      _cache.categories[category.kind] = [
        for (final item in cached)
          if (item.id != category.id) item,
      ];
    }
  }

  @override
  Future<List<Entry>> month(DateTime month, {EntryKind? kind}) =>
      between(Dates.firstOfMonth(month), Dates.lastOfMonth(month), kind: kind);

  @override
  Future<List<Entry>> between(
    DateTime from,
    DateTime to, {
    EntryKind? kind,
  }) async {
    final first = Dates.firstOfMonth(from);
    final last = Dates.firstOfMonth(to);
    await _ensureMonths(first, last);
    _prefetchAround(first, last);
    return [
      for (final entry in _cache.entriesBetween(from, to))
        if (kind == null || entry.kind == kind) entry,
    ];
  }

  Future<void> _ensureMonths(DateTime first, DateTime last) async {
    final missing = [
      for (final month in FinanceCache.monthsBetween(first, last))
        if (!_cache.hasMonth(month)) month,
    ];
    if (missing.isEmpty) {
      return;
    }
    var start = Dates.addMonths(missing.first, -blockMonths);
    var end = Dates.addMonths(missing.last, blockMonths);
    while (_cache.hasMonth(start)) {
      start = Dates.addMonths(start, 1);
    }
    while (_cache.hasMonth(end)) {
      end = Dates.addMonths(end, -1);
    }
    await _loadMonths(start, end);
  }

  void _prefetchAround(DateTime first, DateTime last) {
    final (start, end) = _cache.loadedRun(first, last);
    if (FinanceCache.monthsBetween(last, end).length <= prefetchMargin) {
      unawaited(
        _prefetch(Dates.addMonths(end, 1), Dates.addMonths(end, blockMonths)),
      );
    }
    if (FinanceCache.monthsBetween(start, first).length <= prefetchMargin) {
      unawaited(
        _prefetch(
          Dates.addMonths(start, -blockMonths),
          Dates.addMonths(start, -1),
        ),
      );
    }
  }

  Future<void> _prefetch(DateTime first, DateTime last) async {
    try {
      await _loadMonths(first, last);
    } on ApiError {
      return;
    }
  }

  Future<void> _loadMonths(DateTime first, DateTime last) {
    final generation = _cache.generation;
    return _cache.once(
      'entries:${Dates.toMonth(first)}:${Dates.toMonth(last)}',
      () async {
        final entries = <Entry>[];
        int? page = 1;
        while (page != null) {
          final response = await _client.get<List<Entry>>(
            path,
            decode: _decodeList,
            query: {
              'from': Dates.toIso(first),
              'to': Dates.toIso(Dates.lastOfMonth(last)),
              'limit': pageSize,
              'page': page,
            },
          );
          entries.addAll(response.data);
          page = response.meta['next'] as int?;
        }
        if (generation == _cache.generation) {
          _cache.storeMonths(first, last, entries);
        }
      },
    );
  }

  @override
  Future<Entry> create(EntryDraft draft) async {
    final response = await _client.post<Entry>(
      _withProjection(path),
      decode: _decode,
      body: _body(draft),
    );
    _applyChange(response, [response.data]);
    return response.data;
  }

  @override
  Future<List<Entry>> createSeries(
    EntryDraft draft,
    Recurrence recurrence,
  ) async {
    final response = await _client.post<List<Entry>>(
      _withProjection(seriesPath),
      decode: (data) => _decodeList((data! as Json)['entries']),
      body: _seriesBody(draft, recurrence),
    );
    _applyChange(response, response.data);
    return response.data;
  }

  @override
  Future<List<Entry>> createInstallments(
    EntryDraft draft,
    Installments installments,
  ) async {
    final response = await _client.post<List<Entry>>(
      _withProjection(seriesPath),
      decode: (data) => _decodeList((data! as Json)['entries']),
      body: _installmentsBody(draft, installments),
    );
    _applyChange(response, response.data);
    return response.data;
  }

  @override
  Future<Entry> update(
    String id,
    EntryDraft draft, {
    EntryScope scope = EntryScope.one,
  }) async {
    final response = await _client.patch<Entry>(
      _withProjection('$path/$id', scope: scope),
      decode: _decode,
      body: scope == EntryScope.one ? _body(draft) : _sharedBody(draft),
    );
    _applyChange(response, [response.data]);
    return response.data;
  }

  @override
  Future<Entry> markPaid(String id, {required DateTime? paidOn}) async {
    final response = await _client.patch<Entry>(
      _withProjection('$path/$id'),
      decode: _decode,
      body: {
        'status':
            (paidOn == null ? EntryStatus.pending : EntryStatus.paid).name,
        'paid_on': paidOn == null ? null : Dates.toIso(paidOn),
      },
    );
    _applyChange(response, [response.data]);
    return response.data;
  }

  @override
  Future<void> delete(String id, {EntryScope scope = EntryScope.one}) async {
    final response = await _client.deleteReturning<List<String>>(
      _withProjection('$path/$id', scope: scope),
      decode: (data) => [
        for (final id in (data! as Json)['deleted_ids'] as List<dynamic>)
          id as String,
      ],
    );
    _cache.removeEntries(response.data.toSet());
    _applyChange(response, const []);
  }

  String _withProjection(String target, {EntryScope scope = EntryScope.one}) =>
      _cache.withProjectionWindow(
        target,
        query: {if (scope != EntryScope.one) 'scope': scope.name},
      );

  void _applyChange(ApiResponse<Object?> response, List<Entry> changed) {
    _cache.upsertEntries(changed);
    if (response.meta['entries'] case [_, ...] && final series) {
      final entries = _decodeList(series);
      _cache.replaceSeries(entries.first.seriesId!, entries);
    }
    _cache.applyProjectionMeta(response.meta);
  }

  static Json _sharedBody(EntryDraft draft) =>
      _body(draft)
        ..removeWhere((key, _) => key == 'status' || key == 'paid_on');

  static Json planBody(EntryPlan plan) => switch (plan) {
    EntryPlan(:final draft, recurrence: final recurrence?) => _seriesBody(
      draft,
      recurrence,
    ),
    EntryPlan(:final draft, installments: final installments?) =>
      _installmentsBody(draft, installments),
    EntryPlan(:final draft) => _body(draft),
  };

  static Json _seriesBody(EntryDraft draft, Recurrence recurrence) => {
    ..._body(draft),
    'entries_count': recurrence.count,
    'direction': recurrence.direction.name,
    'interval_months': recurrence.interval.months,
  };

  static Json _installmentsBody(EntryDraft draft, Installments installments) =>
      {
        ..._body(draft)..remove('amount_cents'),
        'kind': SeriesKind.installments.name,
        'total_cents': draft.amountCents,
        'entries_count': installments.count,
      };

  static Json _body(EntryDraft draft) {
    final dueOn = Dates.toIso(draft.dueOn);
    return {
      'category_id': draft.categoryId,
      'description': draft.description,
      'amount_cents': draft.amountCents,
      'due_on': dueOn,
      'status': draft.status.name,
      'nature': draft.nature?.name,
      'paid_on': draft.status == EntryStatus.paid ? dueOn : null,
    };
  }

  static Entry _decode(Object? data) =>
      EntryDto.fromJson(data! as Json).toDomain();

  static List<Entry> _decodeList(Object? data) =>
      (data! as List<dynamic>).map(_decode).toList();
}
