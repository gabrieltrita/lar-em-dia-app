import 'package:freezed_annotation/freezed_annotation.dart';

part 'entry.freezed.dart';

enum EntryKind { income, expense }

enum EntryStatus { pending, paid }

enum EntryNature { fixed, variable }

enum RecurrenceDirection { forward, backward }

@freezed
abstract class Recurrence with _$Recurrence {
  const factory({required int count, required RecurrenceDirection direction}) =
      _Recurrence;

  static const minCount = 2;
  static const maxCount = 36;
  static const defaultCount = 12;
}

@freezed
abstract class EntryDraft with _$EntryDraft {
  const factory({
    required String categoryId,
    required String description,
    required int amountCents,
    required DateTime dueOn,
    required EntryStatus status,
    EntryNature? nature,
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
    EntryNature? nature,
    DateTime? paidOn,
    String? seriesId,
    int? seriesPosition,
  }) = _Entry;

  const new _();

  bool get isPaid => status == EntryStatus.paid;

  bool get isRecurring => seriesId != null;

  EntryDraft toDraft() => EntryDraft(
    categoryId: categoryId,
    description: description,
    amountCents: amountCents,
    dueOn: dueOn,
    status: status,
    nature: nature,
  );
}
