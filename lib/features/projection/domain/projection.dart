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
    @Default(0) int investmentIncomeCents,
    @Default(0) int investmentsValueCents,
    @Default(0) int netWorthCents,
  }) = _ProjectionMonth;

  const new _();

  bool get isNegative => closingCents < 0;

  int get resultCents => incomeCents - expenseCents;

  bool get isSaving => savingsCents >= 0;

  bool get hasReserve => reserveCents > 0;

  int get closingWithReserveCents => closingCents + reserveCents;

  bool get hasInvestments => investmentsValueCents > 0;

  ProjectionMonth shifted(int forecastBefore) => copyWith(
    openingCents: openingCents - forecastBefore,
    incomeCents: incomeCents - investmentIncomeCents,
    closingCents: closingCents - forecastBefore - investmentIncomeCents,
    savingsCents: savingsCents - forecastBefore - investmentIncomeCents,
    netWorthCents: netWorthCents - forecastBefore - investmentIncomeCents,
    investmentIncomeCents: 0,
  );
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

  const new _();

  bool get hasInvestmentIncome =>
      months.any((month) => month.investmentIncomeCents > 0);

  Projection withoutInvestmentIncome() {
    var forecast = 0;
    final adjusted = <ProjectionMonth>[];
    for (final month in months) {
      adjusted.add(month.shifted(forecast));
      forecast += month.investmentIncomeCents;
    }
    final negative = [
      for (final month in adjusted)
        if (month.isNegative) month.month,
    ];
    return copyWith(
      months: adjusted,
      firstNegativeMonth: negative.firstOrNull,
      negativeMonthsCount: negative.length,
    );
  }
}

@freezed
abstract class ProjectionComparison with _$ProjectionComparison {
  const factory({required Projection baseline, required Projection simulated}) =
      _ProjectionComparison;

  const new _();

  int get differenceCents =>
      simulated.months.last.closingCents - baseline.months.last.closingCents;
}
