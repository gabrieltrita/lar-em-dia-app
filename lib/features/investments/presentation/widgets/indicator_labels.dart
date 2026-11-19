import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/rates.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/screener.dart';
import 'package:lar_em_dia/features/investments/domain/screener_presets.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

extension IndicatorLabel on Indicator {
  String label(AppLocalizations l10n) => switch (this) {
    Indicator.dividendYield => l10n.indicatorDividendYield,
    Indicator.priceToBook => l10n.indicatorPriceToBook,
    Indicator.yearsPaying => l10n.indicatorYearsPaying,
    Indicator.payout => l10n.indicatorPayout,
    Indicator.priceToEarnings => l10n.indicatorPriceToEarnings,
    Indicator.roe => l10n.indicatorRoe,
    Indicator.earningsGrowth => l10n.indicatorEarningsGrowth,
    Indicator.equityGrowth => l10n.indicatorEquityGrowth,
    Indicator.yearsWithProfit => l10n.indicatorYearsWithProfit,
    Indicator.netMargin => l10n.indicatorNetMargin,
    Indicator.netDebtToEquity => l10n.indicatorNetDebtToEquity,
    Indicator.liquidity => l10n.indicatorLiquidity,
    Indicator.monthsPaying => l10n.indicatorMonthsPaying,
    Indicator.propertiesCount => l10n.indicatorPropertiesCount,
    Indicator.largestProperty => l10n.indicatorLargestProperty,
    Indicator.largestTenant => l10n.indicatorLargestTenant,
    Indicator.vacancy => l10n.indicatorVacancy,
    Indicator.delinquency => l10n.indicatorDelinquency,
    Indicator.development => l10n.indicatorDevelopment,
  };

  String format(AppLocalizations l10n, int value) => switch (unit) {
    IndicatorUnit.percent => Rates.percentFromBps(value),
    IndicatorUnit.ratio => Rates.hundredths(value),
    IndicatorUnit.years => l10n.indicatorYears(value),
    IndicatorUnit.months => l10n.indicatorMonths(value),
    IndicatorUnit.properties => l10n.indicatorProperties(value),
    IndicatorUnit.money => 'R\$ ${Money.compact(value)}',
  };

  String range(AppLocalizations l10n, IndicatorRange range) =>
      switch ((range.min, range.max)) {
        (final min?, final max?) => l10n.rangeBetween(
          format(l10n, min),
          format(l10n, max),
        ),
        (final min?, null) => l10n.rangeAtLeast(format(l10n, min)),
        (null, final max?) => l10n.rangeAtMost(format(l10n, max)),
        (null, null) => l10n.exploreAnyValue,
      };

  String criterion(AppLocalizations l10n, IndicatorRange value) =>
      '${label(l10n)} ${range(l10n, value)}';
}

extension IndicatorGroupLabel on IndicatorGroup {
  String label(AppLocalizations l10n) => switch (this) {
    IndicatorGroup.income => l10n.exploreGroupIncome,
    IndicatorGroup.valuation => l10n.exploreGroupValuation,
    IndicatorGroup.quality => l10n.exploreGroupQuality,
    IndicatorGroup.diversification => l10n.exploreGroupDiversification,
    IndicatorGroup.liquidity => l10n.exploreGroupLiquidity,
  };
}

extension FundCategoryLabel on FundCategory {
  String label(AppLocalizations l10n) => switch (this) {
    FundCategory.brick => l10n.fundCategoryBrick,
    FundCategory.paper => l10n.fundCategoryPaper,
    FundCategory.fundOfFunds => l10n.fundCategoryFundOfFunds,
    FundCategory.hybrid => l10n.fundCategoryHybrid,
  };
}

extension ScreenerStrategyLabel on ScreenerStrategy {
  String label(AppLocalizations l10n) => switch (this) {
    ScreenerStrategy.steadyIncome => l10n.strategySteadyIncome,
    ScreenerStrategy.diversifiedBrick => l10n.strategyDiversifiedBrick,
    ScreenerStrategy.discounted => l10n.strategyDiscounted,
    ScreenerStrategy.receivables => l10n.strategyReceivables,
    ScreenerStrategy.steadyDividends => l10n.strategySteadyDividends,
    ScreenerStrategy.growth => l10n.strategyGrowth,
    ScreenerStrategy.value => l10n.strategyValue,
  };

  String hint(AppLocalizations l10n) => switch (this) {
    ScreenerStrategy.steadyIncome => l10n.strategySteadyIncomeHint,
    ScreenerStrategy.diversifiedBrick => l10n.strategyDiversifiedBrickHint,
    ScreenerStrategy.discounted => l10n.strategyDiscountedHint,
    ScreenerStrategy.receivables => l10n.strategyReceivablesHint,
    ScreenerStrategy.steadyDividends => l10n.strategySteadyDividendsHint,
    ScreenerStrategy.growth => l10n.strategyGrowthHint,
    ScreenerStrategy.value => l10n.strategyValueHint,
  };
}

extension AssetAlertLabel on AssetAlert {
  String label(AppLocalizations l10n) => switch (this) {
    AssetAlert.singleProperty => l10n.alertSingleProperty,
    AssetAlert.concentratedProperty => l10n.alertConcentratedProperty,
    AssetAlert.concentratedTenant => l10n.alertConcentratedTenant,
    AssetAlert.highVacancy => l10n.alertHighVacancy,
    AssetAlert.highDelinquency => l10n.alertHighDelinquency,
    AssetAlert.development => l10n.alertDevelopment,
    AssetAlert.irregularIncome => l10n.alertIrregularIncome,
    AssetAlert.lowLiquidity => l10n.alertLowLiquidity,
    AssetAlert.recentLoss => l10n.alertRecentLoss,
    AssetAlert.highDebt => l10n.alertHighDebt,
    AssetAlert.payoutAboveProfit => l10n.alertPayoutAboveProfit,
  };
}

extension AssetTypeHighlights on AssetType {
  List<Indicator> get highlights => switch (this) {
    AssetType.fii => const [
      Indicator.dividendYield,
      Indicator.priceToBook,
      Indicator.propertiesCount,
      Indicator.liquidity,
    ],
    AssetType.stock => const [
      Indicator.dividendYield,
      Indicator.priceToEarnings,
      Indicator.roe,
      Indicator.earningsGrowth,
    ],
  };
}
