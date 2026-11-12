import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';

part 'reserve_dtos.freezed.dart';
part 'reserve_dtos.g.dart';

abstract final class ReserveWire {
  static const Map<ReserveKind, String> kinds = {
    ReserveKind.selicTreasury: 'selic_treasury',
    ReserveKind.cdb: 'cdb',
    ReserveKind.savings: 'savings',
    ReserveKind.idle: 'idle',
    ReserveKind.fixedRate: 'fixed_rate',
  };

  static const Map<ReserveAlert, String> alerts = {
    ReserveAlert.noReserve: 'no_reserve',
    ReserveAlert.belowSuggestion: 'below_suggestion',
    ReserveAlert.idleMoney: 'idle_money',
  };

  static String kind(ReserveKind kind) => kinds[kind]!;

  static ReserveKind parseKind(String value) =>
      kinds.entries.firstWhere((entry) => entry.value == value).key;

  static ReserveMovementKind parseMovementKind(String value) =>
      ReserveMovementKind.values.byName(value);

  static List<ReserveAlert> parseAlerts(List<String> values) => [
    for (final MapEntry(:key, :value) in alerts.entries)
      if (values.contains(value)) key,
  ];

  static DateTime? parseDate(String? value) =>
      value == null ? null : Dates.parseIso(value);
}

@freezed
abstract class ReserveAccountDto with _$ReserveAccountDto {
  const factory({
    required String id,
    required String name,
    required String kind,
    int? cdiPercentBps,
    int? annualRateBps,
    @Default(false) bool taxExempt,
    @Default(0) int grossCents,
    @Default(0) int netCents,
    @Default(0) int investedCents,
    @Default(0) int yieldCents,
    @Default(0) int taxCents,
  }) = _ReserveAccountDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$ReserveAccountDtoFromJson(json);

  ReserveAccount toDomain() => ReserveAccount(
    id: id,
    name: name,
    kind: ReserveWire.parseKind(kind),
    cdiPercentBps: cdiPercentBps,
    annualRateBps: annualRateBps,
    taxExempt: taxExempt,
    value: ReserveValue(
      grossCents: grossCents,
      netCents: netCents,
      investedCents: investedCents,
      yieldCents: yieldCents,
      taxCents: taxCents,
    ),
  );
}

@freezed
abstract class ReserveValueDto with _$ReserveValueDto {
  const factory({
    required int grossCents,
    required int netCents,
    required int investedCents,
    required int yieldCents,
    required int taxCents,
  }) = _ReserveValueDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$ReserveValueDtoFromJson(json);

  ReserveValue toDomain() => ReserveValue(
    grossCents: grossCents,
    netCents: netCents,
    investedCents: investedCents,
    yieldCents: yieldCents,
    taxCents: taxCents,
  );
}

@freezed
abstract class ReserveSuggestionDto with _$ReserveSuggestionDto {
  const factory({
    required int averageFixedCents,
    required int monthsCounted,
    required int goalMonths,
    required int suggestedCents,
    required int coverageMonthsE2,
  }) = _ReserveSuggestionDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$ReserveSuggestionDtoFromJson(json);

  ReserveSuggestion toDomain() => ReserveSuggestion(
    averageFixedCents: averageFixedCents,
    monthsCounted: monthsCounted,
    goalMonths: goalMonths,
    suggestedCents: suggestedCents,
    coverageMonthsE2: coverageMonthsE2,
  );
}

@freezed
abstract class ReserveGoalDto with _$ReserveGoalDto {
  const factory({required int months, int? cents, int? targetCents}) =
      _ReserveGoalDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$ReserveGoalDtoFromJson(json);

  ReserveGoal toDomain() =>
      ReserveGoal(months: months, cents: cents, targetCents: targetCents);
}

@freezed
abstract class ReserveSummaryDto with _$ReserveSummaryDto {
  const factory({
    required ReserveValueDto totals,
    required List<ReserveAccountDto> accounts,
    required ReserveGoalDto goal,
    ReserveSuggestionDto? suggestion,
    @Default([]) List<String> alerts,
    String? ratesAsOf,
  }) = _ReserveSummaryDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$ReserveSummaryDtoFromJson(json);

  ReserveSummary toDomain() => ReserveSummary(
    totals: totals.toDomain(),
    accounts: [for (final account in accounts) account.toDomain()],
    goal: goal.toDomain(),
    suggestion: suggestion?.toDomain(),
    alerts: ReserveWire.parseAlerts(alerts),
    ratesAsOf: ReserveWire.parseDate(ratesAsOf),
  );
}

@freezed
abstract class ReserveMovementDto with _$ReserveMovementDto {
  const factory({
    required String id,
    required String accountId,
    required String kind,
    required String movedOn,
    required int amountCents,
    String? entryId,
  }) = _ReserveMovementDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$ReserveMovementDtoFromJson(json);

  ReserveMovement toDomain() => ReserveMovement(
    id: id,
    accountId: accountId,
    kind: ReserveWire.parseMovementKind(kind),
    movedOn: Dates.parseIso(movedOn),
    amountCents: amountCents,
    entryId: entryId,
  );
}

@freezed
abstract class ReserveProjectionMonthDto with _$ReserveProjectionMonthDto {
  const factory({
    required String month,
    required int grossCents,
    required int netCents,
  }) = _ReserveProjectionMonthDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$ReserveProjectionMonthDtoFromJson(json);

  ReserveProjectionMonth toDomain() => ReserveProjectionMonth(
    month: Dates.parseMonth(month)!,
    grossCents: grossCents,
    netCents: netCents,
  );
}

@freezed
abstract class ReserveAssumptionsDto with _$ReserveAssumptionsDto {
  const factory({
    int? selicTargetE8,
    int? cdiEstimateE8,
    int? savingsMonthlyE8,
    String? ratesAsOf,
  }) = _ReserveAssumptionsDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$ReserveAssumptionsDtoFromJson(json);

  ReserveAssumptions toDomain() => ReserveAssumptions(
    selicTargetE8: selicTargetE8,
    cdiEstimateE8: cdiEstimateE8,
    savingsMonthlyE8: savingsMonthlyE8,
    ratesAsOf: ReserveWire.parseDate(ratesAsOf),
  );
}

@freezed
abstract class ReserveProjectionDto with _$ReserveProjectionDto {
  const factory({
    required List<ReserveProjectionMonthDto> months,
    required ReserveAssumptionsDto assumptions,
  }) = _ReserveProjectionDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$ReserveProjectionDtoFromJson(json);

  ReserveProjection toDomain() => ReserveProjection(
    months: [for (final month in months) month.toDomain()],
    assumptions: assumptions.toDomain(),
  );
}
