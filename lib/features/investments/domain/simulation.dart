import 'package:freezed_annotation/freezed_annotation.dart';

part 'simulation.freezed.dart';

@freezed
abstract class IncomeSimulationInput with _$IncomeSimulationInput {
  const factory({
    required int months,
    @Default(0) int initialCents,
    @Default(0) int monthlyCents,
    String? ticker,
    int? monthlyYieldBps,
    @Default(true) bool reinvest,
    int? targetMonthlyIncomeCents,
  }) = _IncomeSimulationInput;
}

@freezed
abstract class IncomeSimulationMonth with _$IncomeSimulationMonth {
  const factory({
    required int month,
    required int contributedCents,
    required int valueCents,
    required int incomeCents,
    required int receivedCents,
    int? shares,
  }) = _IncomeSimulationMonth;
}

@freezed
abstract class IncomeSimulation with _$IncomeSimulation {
  const factory({
    required List<IncomeSimulationMonth> months,
    required bool reinvest,
    String? ticker,
    int? priceCents,
    int? monthlyIncomePerShareE8,
    int? monthlyYieldBps,
    int? sharesForTarget,
    int? capitalForTargetCents,
    int? monthsToTarget,
    int? targetMonthlyIncomeCents,
  }) = _IncomeSimulation;

  const new _();

  IncomeSimulationMonth get last => months.last;
}

@freezed
abstract class GrowthSimulationInput with _$GrowthSimulationInput {
  const factory({
    required int months,
    required int annualRateBps,
    @Default(0) int initialCents,
    @Default(0) int monthlyCents,
  }) = _GrowthSimulationInput;
}

@freezed
abstract class GrowthSimulationMonth with _$GrowthSimulationMonth {
  const factory({
    required int month,
    required int contributedCents,
    required int valueCents,
    required int earningsCents,
  }) = _GrowthSimulationMonth;
}

@freezed
abstract class GrowthSimulation with _$GrowthSimulation {
  const factory({
    required int annualRateBps,
    required int monthlyRateE8,
    required List<GrowthSimulationMonth> months,
  }) = _GrowthSimulation;

  const new _();

  GrowthSimulationMonth get last => months.last;
}
