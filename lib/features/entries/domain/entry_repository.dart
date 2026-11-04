import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';

abstract interface class EntryRepository {
  Future<List<Category>> categories(EntryKind kind);

  Future<List<Entry>> month(DateTime month, {required EntryKind kind});

  Future<Entry> create(EntryDraft draft);

  Future<List<Entry>> createSeries(EntryDraft draft, Recurrence recurrence);

  Future<Entry> update(String id, EntryDraft draft);

  Future<void> delete(String id);
}
