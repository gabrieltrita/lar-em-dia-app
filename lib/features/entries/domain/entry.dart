import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/core/dates/dates.dart';

part 'entry.freezed.dart';

enum EntryKind { income, expense }

enum EntryStatus { pending, paid }

enum EntryNature { fixed, variable }

enum RecurrenceDirection { forward, backward }

enum RecurrenceInterval {
  monthly(1),
  quarterly(3),
  semiannual(6),
  yearly(12);

  new(this.months);

  final int months;
}

enum SeriesKind { recurring, installments }

enum EntryScope { one, following, all }

@freezed
abstract class Recurrence with _$Recurrence {
  const factory({
    required int count,
    required RecurrenceDirection direction,
    @Default(RecurrenceInterval.monthly) RecurrenceInterval interval,
  }) = _Recurrence;

  const new _();

  static const minCount = 2;
  static const maxCount = 36;
  static const defaultCount = 12;

  List<DateTime> dueDates(DateTime first) {
    final step = direction == RecurrenceDirection.forward
        ? interval.months
        : -interval.months;
    return [
      for (var index = 0; index < count; index++)
        Dates.shiftMonths(first, index * step),
    ]..sort();
  }
}

@freezed
abstract class Installments with _$Installments {
  const factory({required int count}) = _Installments;

  const new _();

  static const minCount = 2;
  static const maxCount = 48;
  static const defaultCount = 10;

  List<int> split(int totalCents) {
    final share = totalCents ~/ count;
    final rest = totalCents - share * count;
    return [share + rest, for (var i = 1; i < count; i++) share];
  }
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
abstract class EntryPlan with _$EntryPlan {
  const factory({
    required EntryKind kind,
    required EntryDraft draft,
    Recurrence? recurrence,
    Installments? installments,
  }) = _EntryPlan;
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
    SeriesKind? seriesKind,
    int? seriesCount,
  }) = _Entry;

  const new _();

  bool get isPaid => status == EntryStatus.paid;

  bool get isRecurring => seriesId != null && !isInstallment;

  bool get isInstallment => seriesKind == SeriesKind.installments;

  EntryDraft toDraft() => EntryDraft(
    categoryId: categoryId,
    description: description,
    amountCents: amountCents,
    dueOn: dueOn,
    status: status,
    nature: nature,
  );
}

@freezed
abstract class EntryEdit with _$EntryEdit {
  const factory({
    required Entry entry,
    @Default(EntryScope.one) EntryScope scope,
  }) = _EntryEdit;
}
