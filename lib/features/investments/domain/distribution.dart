import 'package:freezed_annotation/freezed_annotation.dart';

part 'distribution.freezed.dart';

enum DistributionKind {
  fiiIncome,
  dividend,
  jcp;

  static const List<DistributionKind> manual = [dividend, jcp];
}

@freezed
abstract class AssetDistribution with _$AssetDistribution {
  const factory({
    required String id,
    required String ticker,
    required DistributionKind kind,
    required bool manual,
    required DateTime recordOn,
    required int amountPerShareE8,
    required int netAmountPerShareE8,
    DateTime? paidOn,
  }) = _AssetDistribution;
}

@freezed
abstract class DistributionDraft with _$DistributionDraft {
  const factory({
    required String ticker,
    required DistributionKind kind,
    required DateTime recordOn,
    required DateTime paidOn,
    required int amountPerShareE8,
  }) = _DistributionDraft;
}

@freezed
abstract class FundReport with _$FundReport {
  const factory({
    required DateTime referenceMonth,
    required int equityCents,
    required int bookValuePerShareE8,
    required int sharesCount,
    required int shareholdersCount,
  }) = _FundReport;
}

@freezed
abstract class IncomeMonth with _$IncomeMonth {
  const factory({required DateTime month, required int amountCents}) =
      _IncomeMonth;
}

@freezed
abstract class PositionIncome with _$PositionIncome {
  const factory({
    required String ticker,
    required int quantity,
    required int received12mCents,
    required int monthlyForecastCents,
  }) = _PositionIncome;
}

@freezed
abstract class PassiveIncome with _$PassiveIncome {
  const factory({
    required int monthlyAverageCents,
    required List<IncomeMonth> received,
    required List<IncomeMonth> forecast,
    required List<PositionIncome> positions,
  }) = _PassiveIncome;

  const new _();

  int get received12mCents =>
      received.fold(0, (total, month) => total + month.amountCents);

  int? get nextMonthCents => forecast.firstOrNull?.amountCents;

  bool get isEmpty => received12mCents == 0 && (nextMonthCents ?? 0) == 0;
}
