import 'package:freezed_annotation/freezed_annotation.dart';

part 'projection.freezed.dart';

@freezed
abstract class ProjectionAnchor with _$ProjectionAnchor {
  const factory({required int amountCents, required DateTime asOf}) =
      _ProjectionAnchor;
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
  }) = _ProjectionMonth;

  const new _();

  bool get isNegative => closingCents < 0;

  bool get isSaving => savingsCents >= 0;
}

@freezed
abstract class Projection with _$Projection {
  const factory({
    required List<ProjectionMonth> months,
    ProjectionAnchor? anchor,
    DateTime? firstNegativeMonth,
    @Default(0) int negativeMonthsCount,
  }) = _Projection;
}
