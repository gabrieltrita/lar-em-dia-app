import 'package:freezed_annotation/freezed_annotation.dart';

part 'entry.freezed.dart';

enum EntryKind { income, expense }

enum EntryStatus { pending, paid }

@freezed
abstract class EntryDraft with _$EntryDraft {
  const factory({
    required String categoryId,
    required String description,
    required int amountCents,
    required DateTime dueOn,
    required EntryStatus status,
  }) = _EntryDraft;
}

@freezed
abstract class Entry with _$Entry {
  const factory({
    required String id,
    required EntryKind kind,
    required String categoryId,
    required String description,
    required int amountCents,
    required DateTime dueOn,
    required EntryStatus status,
    DateTime? paidOn,
  }) = _Entry;

  const new _();

  bool get isPaid => status == EntryStatus.paid;

  EntryDraft toDraft() => EntryDraft(
    categoryId: categoryId,
    description: description,
    amountCents: amountCents,
    dueOn: dueOn,
    status: status,
  );
}
