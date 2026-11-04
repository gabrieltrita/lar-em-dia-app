import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_client.dart';
import 'package:lar_em_dia/features/entries/data/entry_dtos.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/domain/entry_repository.dart';

@LazySingleton(as: EntryRepository)
class ApiEntryRepository implements EntryRepository {
  new(this._client);

  static const path = '/entries';
  static const seriesPath = '/entry_series';
  static const pageSize = 100;

  final ApiClient _client;

  @override
  Future<List<Category>> categories(EntryKind kind) async {
    final response = await _client.get<List<Category>>(
      '/categories',
      decode: (data) => (data! as List<dynamic>)
          .map((item) => CategoryDto.fromJson(item as Json).toDomain())
          .toList(),
      query: {'kind': kind.name},
    );
    return response.data;
  }

  @override
  Future<List<Entry>> month(DateTime month, {required EntryKind kind}) async {
    final entries = <Entry>[];
    int? page = 1;
    while (page != null) {
      final response = await _client.get<List<Entry>>(
        path,
        decode: _decodeList,
        query: {
          'from': Dates.toIso(Dates.firstOfMonth(month)),
          'to': Dates.toIso(Dates.lastOfMonth(month)),
          'kind': kind.name,
          'limit': pageSize,
          'page': page,
        },
      );
      entries.addAll(response.data);
      page = response.meta['next'] as int?;
    }
    return entries;
  }

  @override
  Future<Entry> create(EntryDraft draft) async {
    final response = await _client.post<Entry>(
      path,
      decode: _decode,
      body: _body(draft),
    );
    return response.data;
  }

  @override
  Future<List<Entry>> createSeries(
    EntryDraft draft,
    Recurrence recurrence,
  ) async {
    final response = await _client.post<List<Entry>>(
      seriesPath,
      decode: (data) => _decodeList((data! as Json)['entries']),
      body: {
        ..._body(draft),
        'entries_count': recurrence.count,
        'direction': recurrence.direction.name,
      },
    );
    return response.data;
  }

  @override
  Future<Entry> update(String id, EntryDraft draft) async {
    final response = await _client.patch<Entry>(
      '$path/$id',
      decode: _decode,
      body: _body(draft),
    );
    return response.data;
  }

  @override
  Future<void> delete(String id) => _client.delete('$path/$id');

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
