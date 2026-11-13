import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';

part 'screener.freezed.dart';

enum IndicatorUnit { percent, ratio, years, money }

enum Indicator {
  dividendYield(IndicatorUnit.percent, {AssetType.fii, AssetType.stock}),
  priceToBook(IndicatorUnit.ratio, {AssetType.fii, AssetType.stock}),
  yearsPaying(IndicatorUnit.years, {AssetType.fii, AssetType.stock}),
  payout(IndicatorUnit.percent, {AssetType.stock}),
  priceToEarnings(IndicatorUnit.ratio, {AssetType.stock}),
  roe(IndicatorUnit.percent, {AssetType.stock}),
  earningsGrowth(IndicatorUnit.percent, {AssetType.stock}),
  equityGrowth(IndicatorUnit.percent, {AssetType.stock}),
  yearsWithProfit(IndicatorUnit.years, {AssetType.stock}),
  netMargin(IndicatorUnit.percent, {AssetType.stock}),
  netDebtToEquity(IndicatorUnit.percent, {AssetType.stock}),
  liquidity(IndicatorUnit.money, {AssetType.fii, AssetType.stock});

  new(this.unit, this.types);

  final IndicatorUnit unit;
  final Set<AssetType> types;

  static List<Indicator> forType(AssetType type) => [
    for (final indicator in values)
      if (indicator.types.contains(type)) indicator,
  ];
}

@freezed
abstract class AssetIndicators with _$AssetIndicators {
  const factory({
    required DateTime computedOn,
    int? priceCents,
    int? dividendYieldBps,
    int? distributionAverageE8,
    int? distributionMedianE8,
    int? yearsPaying,
    int? payoutBps,
    int? priceToBookE2,
    int? priceToEarningsE2,
    int? roeAverageBps,
    int? earningsGrowthBps,
    int? equityGrowthBps,
    int? yearsWithProfit,
    int? netMarginBps,
    int? netDebtToEquityBps,
    int? liquidityCents,
    int? financialYears,
  }) = _AssetIndicators;

  const new _();

  int? value(Indicator indicator) => switch (indicator) {
    Indicator.dividendYield => dividendYieldBps,
    Indicator.priceToBook => priceToBookE2,
    Indicator.yearsPaying => yearsPaying,
    Indicator.payout => payoutBps,
    Indicator.priceToEarnings => priceToEarningsE2,
    Indicator.roe => roeAverageBps,
    Indicator.earningsGrowth => earningsGrowthBps,
    Indicator.equityGrowth => equityGrowthBps,
    Indicator.yearsWithProfit => yearsWithProfit,
    Indicator.netMargin => netMarginBps,
    Indicator.netDebtToEquity => netDebtToEquityBps,
    Indicator.liquidity => liquidityCents,
  };
}

@freezed
abstract class IndicatorRange with _$IndicatorRange {
  const factory({int? min, int? max}) = _IndicatorRange;

  const new _();

  bool get isEmpty => min == null && max == null;
}

@freezed
abstract class ScreenerQuery with _$ScreenerQuery {
  const factory({
    @Default(AssetType.fii) AssetType type,
    @Default(false) bool payingOnly,
    @Default({}) Map<Indicator, IndicatorRange> ranges,
    @Default(Indicator.dividendYield) Indicator sort,
    @Default(false) bool ascending,
  }) = _ScreenerQuery;

  const new _();

  Map<Indicator, IndicatorRange> get activeRanges => {
    for (final MapEntry(key: indicator, value: range) in ranges.entries)
      if (!range.isEmpty && indicator.types.contains(type)) indicator: range,
  };

  ScreenerQuery withType(AssetType type) => copyWith(
    type: type,
    sort: sort.types.contains(type) ? sort : Indicator.dividendYield,
  );
}

@freezed
abstract class ScreenerPage with _$ScreenerPage {
  const factory({required List<Asset> assets, int? nextPage}) = _ScreenerPage;
}
