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
  );
}

@freezed
abstract class ProjectionDto with _$ProjectionDto {
  const factory({
    required List<ProjectionMonthDto> months,
    ProjectionAnchorDto? anchor,
  }) = _ProjectionDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$ProjectionDtoFromJson(json);

  Projection toDomain() => Projection(
    anchor: anchor?.toDomain(),
    months: [for (final month in months) month.toDomain()],
  );
}
