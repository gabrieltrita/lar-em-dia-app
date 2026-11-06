import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';

abstract interface class EntryRepository {
  Future<List<Category>> categories(EntryKind kind);

  Future<List<Entry>> month(DateTime month, {EntryKind? kind});

  Future<List<Entry>> between(DateTime from, DateTime to, {EntryKind? kind});

  Future<Entry> create(EntryDraft draft);

  Future<List<Entry>> createSeries(EntryDraft draft, Recurrence recurrence);

  Future<List<Entry>> createInstallments(
    EntryDraft draft,
    Installments installments,
  );

  Future<Entry> update(
    String id,
    EntryDraft draft, {
    EntryScope scope = EntryScope.one,
  });

  Future<Entry> markPaid(String id, {required DateTime? paidOn});

  Future<void> delete(String id, {EntryScope scope = EntryScope.one});
}
