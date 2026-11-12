import 'package:freezed_annotation/freezed_annotation.dart';

part 'projection.freezed.dart';

@freezed
abstract class ProjectionAnchor with _$ProjectionAnchor {
  const factory({required int amountCents, required DateTime asOf}) =
      _ProjectionAnchor;
}

enum ProjectionPeriod {
  threeMonths(3),
  sixMonths(6),
  year(12),
  all(null);

  new(this.months);

  final int? months;

  String get query => months?.toString() ?? 'all';
}

@freezed
abstract class CategoryAmount with _$CategoryAmount {
  const factory({required String categoryKey, required int amountCents}) =
      _CategoryAmount;
}

@freezed
abstract class ProjectionMonth with _$ProjectionMonth {
  const factory({
    required DateTime month,
    required int openingCents,
    required int incomeCents,
    required int expenseCents,
    required int fixedExpenseCents,
    required int variableExpenseCents,
    required int closingCents,
    required int savingsCents,
    @Default([]) List<CategoryAmount> expenseByCategory,
    @Default(0) int reserveCents,
  }) = _ProjectionMonth;

  const new _();

  bool get isNegative => closingCents < 0;

  int get resultCents => incomeCents - expenseCents;

  bool get isSaving => savingsCents >= 0;

  bool get hasReserve => reserveCents > 0;

  int get closingWithReserveCents => closingCents + reserveCents;
}

@freezed
abstract class Projection with _$Projection {
  const factory({
    required List<ProjectionMonth> months,
    ProjectionAnchor? anchor,
    DateTime? firstNegativeMonth,
    DateTime? lastEntryMonth,
    @Default(0) int negativeMonthsCount,
  }) = _Projection;
}

@freezed
abstract class ProjectionComparison with _$ProjectionComparison {
  const factory({required Projection baseline, required Projection simulated}) =
      _ProjectionComparison;

  const new _();

  int get differenceCents =>
      simulated.months.last.closingCents - baseline.months.last.closingCents;
}
