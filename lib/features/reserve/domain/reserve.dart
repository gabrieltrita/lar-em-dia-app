import 'package:freezed_annotation/freezed_annotation.dart';

part 'reserve.freezed.dart';

enum ReserveKind {
  selicTreasury,
  cdb,
  savings,
  idle,
  fixedRate;

  bool get usesCdiPercent => this == cdb;

  bool get usesAnnualRate => this == fixedRate;

  bool get canBeExempt => this == cdb || this == fixedRate;
}

enum ReserveMovementKind {
  deposit,
  withdrawal,
  anchor;

  bool get changesBalance => this != anchor;
}

enum ReserveAlert { noReserve, belowSuggestion, idleMoney }

@freezed
abstract class ReserveValue with _$ReserveValue {
  const factory({
    required int grossCents,
    required int netCents,
    required int investedCents,
    required int yieldCents,
    required int taxCents,
  }) = _ReserveValue;

  static const empty = ReserveValue(
    grossCents: 0,
    netCents: 0,
    investedCents: 0,
    yieldCents: 0,
    taxCents: 0,
  );
}

@freezed
abstract class ReserveAccount with _$ReserveAccount {
  const factory({
    required String id,
    required String name,
    required ReserveKind kind,
    int? cdiPercentBps,
    int? annualRateBps,
    @Default(false) bool taxExempt,
    @Default(ReserveValue.empty) ReserveValue value,
  }) = _ReserveAccount;
}

@freezed
abstract class ReserveAccountDraft with _$ReserveAccountDraft {
  const factory({
    required String name,
    required ReserveKind kind,
    int? cdiPercentBps,
    int? annualRateBps,
    @Default(false) bool taxExempt,
  }) = _ReserveAccountDraft;
}

@freezed
abstract class ReserveMovement with _$ReserveMovement {
  const factory({
    required String id,
    required String accountId,
    required ReserveMovementKind kind,
    required DateTime movedOn,
    required int amountCents,
    String? entryId,
  }) = _ReserveMovement;

  const new _();

  bool get changesBalance => entryId != null;
}

@freezed
abstract class ReserveMovementDraft with _$ReserveMovementDraft {
  const factory({
    required String accountId,
    required ReserveMovementKind kind,
    required DateTime movedOn,
    required int amountCents,
    @Default(false) bool debitBalance,
  }) = _ReserveMovementDraft;
}

@freezed
abstract class ReserveSuggestion with _$ReserveSuggestion {
  const factory({
    required int averageFixedCents,
    required int monthsCounted,
    required int goalMonths,
    required int suggestedCents,
    required int coverageMonthsE2,
  }) = _ReserveSuggestion;
}

@freezed
abstract class ReserveGoal with _$ReserveGoal {
  const factory({required int months, int? cents, int? targetCents}) =
      _ReserveGoal;
}

@freezed
abstract class ReserveSummary with _$ReserveSummary {
  const factory({
    required ReserveValue totals,
    required List<ReserveAccount> accounts,
    required ReserveGoal goal,
    ReserveSuggestion? suggestion,
    @Default([]) List<ReserveAlert> alerts,
    DateTime? ratesAsOf,
  }) = _ReserveSummary;

  const new _();

  bool get isEmpty => accounts.isEmpty;

  bool has(ReserveAlert alert) => alerts.contains(alert);
}

@freezed
abstract class ReserveProjectionMonth with _$ReserveProjectionMonth {
  const factory({
    required DateTime month,
    required int grossCents,
    required int netCents,
  }) = _ReserveProjectionMonth;
}

@freezed
abstract class ReserveAssumptions with _$ReserveAssumptions {
  const factory({
    int? selicTargetE8,
    int? cdiEstimateE8,
    int? savingsMonthlyE8,
    DateTime? ratesAsOf,
  }) = _ReserveAssumptions;
}

@freezed
abstract class ReserveProjection with _$ReserveProjection {
  const factory({
    required List<ReserveProjectionMonth> months,
    required ReserveAssumptions assumptions,
  }) = _ReserveProjection;
}
