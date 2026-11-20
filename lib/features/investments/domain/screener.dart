import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';

part 'screener.freezed.dart';

enum IndicatorUnit { percent, ratio, years, months, properties, money }

enum IndicatorGroup { income, valuation, quality, diversification, liquidity }

enum FundCategory { brick, paper, fundOfFunds, hybrid }

const Set<AssetType> _both = {AssetType.fii, AssetType.stock};
const Set<AssetType> _fii = {AssetType.fii};
const Set<AssetType> _stock = {AssetType.stock};

enum Indicator {
  dividendYield(IndicatorUnit.percent, _both, IndicatorGroup.income),
  monthsPaying(IndicatorUnit.months, _fii, IndicatorGroup.income),
  yearsPaying(IndicatorUnit.years, _both, IndicatorGroup.income),
  payout(IndicatorUnit.percent, _stock, IndicatorGroup.income),
  priceToBook(IndicatorUnit.ratio, _both, IndicatorGroup.valuation),
  priceToEarnings(IndicatorUnit.ratio, _stock, IndicatorGroup.valuation),
  roe(IndicatorUnit.percent, _stock, IndicatorGroup.quality),
  earningsGrowth(IndicatorUnit.percent, _stock, IndicatorGroup.quality),
  equityGrowth(IndicatorUnit.percent, _stock, IndicatorGroup.quality),
  yearsWithProfit(IndicatorUnit.years, _stock, IndicatorGroup.quality),
  netMargin(IndicatorUnit.percent, _stock, IndicatorGroup.quality),
  netDebtToEquity(IndicatorUnit.percent, _stock, IndicatorGroup.quality),
  propertiesCount(
    IndicatorUnit.properties,
    _fii,
    IndicatorGroup.diversification,
  ),
  largestProperty(IndicatorUnit.percent, _fii, IndicatorGroup.diversification),
  largestTenant(IndicatorUnit.percent, _fii, IndicatorGroup.diversification),
  vacancy(IndicatorUnit.percent, _fii, IndicatorGroup.diversification),
  delinquency(IndicatorUnit.percent, _fii, IndicatorGroup.diversification),
  development(IndicatorUnit.percent, _fii, IndicatorGroup.diversification),
  liquidity(IndicatorUnit.money, _both, IndicatorGroup.liquidity);

  new(this.unit, this.types, this.group);

  final IndicatorUnit unit;
  final Set<AssetType> types;
  final IndicatorGroup group;

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
    FundCategory? fundCategory,
    int? developmentBps,
    int? propertiesCount,
    int? largestPropertyBps,
    int? vacancyBps,
    int? delinquencyBps,
    int? largestTenantBps,
    int? monthsPaying12m,
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
    Indicator.monthsPaying => monthsPaying12m,
    Indicator.propertiesCount => propertiesCount,
    Indicator.largestProperty => largestPropertyBps,
    Indicator.largestTenant => largestTenantBps,
    Indicator.vacancy => vacancyBps,
    Indicator.delinquency => delinquencyBps,
    Indicator.development => developmentBps,
  };
}

@freezed
abstract class IndicatorRange with _$IndicatorRange {
  const factory({int? min, int? max}) = _IndicatorRange;

  const new _();

  bool get isEmpty => min == null && max == null;
}

@freezed
abstract class ScreenerPage with _$ScreenerPage {
  const factory({required List<Asset> assets, int? nextPage, int? total}) =
      _ScreenerPage;
}

@freezed
abstract class ScreenerQuery with _$ScreenerQuery {
  const factory({
    @Default(AssetType.fii) AssetType type,
    @Default(false) bool payingOnly,
    @Default(false) bool hideSingleProperty,
    @Default(false) bool hideDevelopment,
    @Default({}) Set<FundCategory> categories,
    @Default({}) Map<Indicator, IndicatorRange> ranges,
    @Default(Indicator.dividendYield) Indicator sort,
    @Default(false) bool ascending,
  }) = _ScreenerQuery;

  const new _();

  Map<Indicator, IndicatorRange> get activeRanges => {
    for (final MapEntry(key: indicator, value: range) in ranges.entries)
      if (!range.isEmpty && indicator.types.contains(type)) indicator: range,
  };

  Set<FundCategory> get activeCategories =>
      type == AssetType.fii ? categories : const {};

  bool get hidesSingleProperty => type == AssetType.fii && hideSingleProperty;

  bool get hidesDevelopment => type == AssetType.fii && hideDevelopment;

  int get criteriaCount =>
      activeRanges.length +
      [
        payingOnly,
        activeCategories.isNotEmpty,
        hidesSingleProperty,
        hidesDevelopment,
      ].where((active) => active).length;

  ScreenerQuery withType(AssetType type) => copyWith(
    type: type,
    sort: sort.types.contains(type) ? sort : Indicator.dividendYield,
  );

  ScreenerQuery withRange(Indicator indicator, IndicatorRange? range) =>
      copyWith(
        ranges: {
          for (final entry in ranges.entries)
            if (entry.key != indicator) entry.key: entry.value,
          if (range != null && !range.isEmpty) indicator: range,
        },
      );
}
