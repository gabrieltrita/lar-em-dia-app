import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/rates.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/screener.dart';
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
  };

  String format(AppLocalizations l10n, int value) => switch (unit) {
    IndicatorUnit.percent => Rates.percentFromBps(value),
    IndicatorUnit.ratio => Rates.hundredths(value),
    IndicatorUnit.years => l10n.indicatorYears(value),
    IndicatorUnit.money => 'R\$ ${Money.compact(value)}',
  };

  int? parse(String text) => switch (unit) {
    IndicatorUnit.percent || IndicatorUnit.ratio => Rates.parseHundredths(text),
    IndicatorUnit.years => int.tryParse(text.trim()),
    IndicatorUnit.money => Money.parse(text),
  };

  String input(int value) => switch (unit) {
    IndicatorUnit.percent || IndicatorUnit.ratio => Rates.hundredths(value),
    IndicatorUnit.years => '$value',
    IndicatorUnit.money => Money.formatAmount(value),
  };
}

extension AssetTypeHighlights on AssetType {
  List<Indicator> get highlights => switch (this) {
    AssetType.fii => const [
      Indicator.dividendYield,
      Indicator.priceToBook,
      Indicator.liquidity,
    ],
    AssetType.stock => const [
      Indicator.dividendYield,
      Indicator.priceToEarnings,
      Indicator.roe,
    ],
  };
}
