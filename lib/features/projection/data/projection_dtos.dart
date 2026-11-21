import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';

part 'projection_dtos.freezed.dart';
part 'projection_dtos.g.dart';

@freezed
abstract class ProjectionAnchorDto with _$ProjectionAnchorDto {
  const factory({required int amountCents, required String asOf}) =
      _ProjectionAnchorDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$ProjectionAnchorDtoFromJson(json);

  ProjectionAnchor toDomain() =>
      ProjectionAnchor(amountCents: amountCents, asOf: Dates.parseIso(asOf));
}

@freezed
abstract class CategoryAmountDto with _$CategoryAmountDto {
  const factory({
    required String categoryKey,
    required int amountCents,
    String? categoryName,
  }) = _CategoryAmountDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$CategoryAmountDtoFromJson(json);

  CategoryAmount toDomain() => CategoryAmount(
    categoryKey: categoryKey,
    amountCents: amountCents,
    categoryName: categoryName,
  );
}

@freezed
abstract class ProjectionMonthDto with _$ProjectionMonthDto {
  const factory({
    required String month,
    required int openingCents,
    required int incomeCents,
    required int expenseCents,
    required int fixedExpenseCents,
    required int variableExpenseCents,
    required int closingCents,
    required int savingsCents,
    @Default([]) List<CategoryAmountDto> expenseByCategory,
    @Default(0) int reserveCents,
    @Default(0) int investmentIncomeCents,
    @Default(0) int investmentsValueCents,
    @Default(0) int netWorthCents,
  }) = _ProjectionMonthDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$ProjectionMonthDtoFromJson(json);

  ProjectionMonth toDomain() => ProjectionMonth(
    month: Dates.parseMonth(month)!,
    openingCents: openingCents,
    incomeCents: incomeCents,
    expenseCents: expenseCents,
    fixedExpenseCents: fixedExpenseCents,
    variableExpenseCents: variableExpenseCents,
    closingCents: closingCents,
    savingsCents: savingsCents,
    expenseByCategory: [
      for (final amount in expenseByCategory) amount.toDomain(),
    ],
    reserveCents: reserveCents,
    investmentIncomeCents: investmentIncomeCents,
    investmentsValueCents: investmentsValueCents,
    netWorthCents: netWorthCents,
  );
}

@freezed
abstract class ProjectionAlertsDto with _$ProjectionAlertsDto {
  const factory({
    String? firstNegativeMonth,
    @Default(0) int negativeMonthsCount,
  }) = _ProjectionAlertsDto;

  factory fromJson(Map<String, dynamic> json) =>
      _$ProjectionAlertsDtoFromJson(json);
}

@freezed
abstract class ProjectionDto with _$ProjectionDto {
  const factory({
    required List<ProjectionMonthDto> months,
    ProjectionAnchorDto? anchor,
    String? lastEntryMonth,
    @Default(ProjectionAlertsDto()) ProjectionAlertsDto alerts,
  }) = _ProjectionDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$ProjectionDtoFromJson(json);

  Projection toDomain() => Projection(
    anchor: anchor?.toDomain(),
    months: [for (final month in months) month.toDomain()],
    firstNegativeMonth: Dates.parseMonth(alerts.firstNegativeMonth),
    lastEntryMonth: Dates.parseMonth(lastEntryMonth),
    negativeMonthsCount: alerts.negativeMonthsCount,
  );
}

@freezed
abstract class ProjectionComparisonDto with _$ProjectionComparisonDto {
  const factory({
    required ProjectionDto baseline,
    required ProjectionDto simulated,
  }) = _ProjectionComparisonDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$ProjectionComparisonDtoFromJson(json);

  ProjectionComparison toDomain() => ProjectionComparison(
    baseline: baseline.toDomain(),
    simulated: simulated.toDomain(),
  );
}
