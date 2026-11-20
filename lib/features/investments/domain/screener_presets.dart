import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/screener.dart';

const _halfMillion = 50000000;
const _oneMillion = 100000000;

enum ScreenerStrategy {
  steadyIncome(AssetType.fii),
  diversifiedBrick(AssetType.fii),
  discounted(AssetType.fii),
  receivables(AssetType.fii),
  steadyDividends(AssetType.stock),
  growth(AssetType.stock),
  value(AssetType.stock);

  new(this.type);

  final AssetType type;

  static List<ScreenerStrategy> forType(AssetType type) => [
    for (final strategy in values)
      if (strategy.type == type) strategy,
  ];

  ScreenerQuery get query => switch (this) {
    steadyIncome => const ScreenerQuery(
      hideDevelopment: true,
      ranges: {
        Indicator.dividendYield: IndicatorRange(min: 800),
        Indicator.monthsPaying: IndicatorRange(min: 10),
        Indicator.liquidity: IndicatorRange(min: _halfMillion),
      },
    ),
    diversifiedBrick => const ScreenerQuery(
      categories: {FundCategory.brick},
      hideSingleProperty: true,
      ranges: {
        Indicator.monthsPaying: IndicatorRange(min: 10),
        Indicator.propertiesCount: IndicatorRange(min: 5),
        Indicator.largestProperty: IndicatorRange(max: 3000),
        Indicator.vacancy: IndicatorRange(max: 1000),
        Indicator.liquidity: IndicatorRange(min: _halfMillion),
      },
    ),
    discounted => const ScreenerQuery(
      hideDevelopment: true,
      sort: Indicator.priceToBook,
      ascending: true,
      ranges: {
        Indicator.priceToBook: IndicatorRange(max: 90),
        Indicator.monthsPaying: IndicatorRange(min: 10),
        Indicator.liquidity: IndicatorRange(min: _halfMillion),
      },
    ),
    receivables => const ScreenerQuery(
      categories: {FundCategory.paper},
      ranges: {
        Indicator.monthsPaying: IndicatorRange(min: 10),
        Indicator.liquidity: IndicatorRange(min: _oneMillion),
      },
    ),
    steadyDividends => const ScreenerQuery(
      type: AssetType.stock,
      ranges: {
        Indicator.dividendYield: IndicatorRange(min: 600),
        Indicator.yearsPaying: IndicatorRange(min: 5),
        Indicator.payout: IndicatorRange(min: 2500, max: 9500),
        Indicator.roe: IndicatorRange(min: 1000),
        Indicator.liquidity: IndicatorRange(min: _oneMillion),
      },
    ),
    growth => const ScreenerQuery(
      type: AssetType.stock,
      sort: Indicator.earningsGrowth,
      ranges: {
        Indicator.earningsGrowth: IndicatorRange(min: 1000),
        Indicator.yearsWithProfit: IndicatorRange(min: 5),
        Indicator.roe: IndicatorRange(min: 1500),
        Indicator.liquidity: IndicatorRange(min: _oneMillion),
      },
    ),
    value => const ScreenerQuery(
      type: AssetType.stock,
      sort: Indicator.priceToEarnings,
      ascending: true,
      ranges: {
        Indicator.priceToEarnings: IndicatorRange(min: 1, max: 1200),
        Indicator.priceToBook: IndicatorRange(max: 150),
        Indicator.yearsWithProfit: IndicatorRange(min: 5),
        Indicator.liquidity: IndicatorRange(min: _oneMillion),
      },
    ),
  };

  bool matches(ScreenerQuery other) =>
      query == other.copyWith(sort: query.sort, ascending: query.ascending);
}

extension IndicatorOptions on Indicator {
  List<IndicatorRange> options(AssetType type) => switch (this) {
    Indicator.dividendYield => _minimums([600, 800, 1000, 1200]),
    Indicator.monthsPaying => _minimums([9, 10, 11]),
    Indicator.yearsPaying => _minimums(
      type == AssetType.fii ? [2, 3, 5] : [3, 5, 10],
    ),
    Indicator.payout => const [
      IndicatorRange(min: 2500, max: 9500),
      IndicatorRange(max: 10000),
    ],
    Indicator.priceToBook => _maximums(
      type == AssetType.fii ? [90, 100, 110] : [100, 150, 300],
    ),
    Indicator.priceToEarnings => const [
      IndicatorRange(min: 1, max: 800),
      IndicatorRange(min: 1, max: 1200),
      IndicatorRange(min: 1, max: 2000),
    ],
    Indicator.roe => _minimums([1000, 1500, 2000]),
    Indicator.earningsGrowth => _minimums([500, 1000, 2000]),
    Indicator.equityGrowth => _minimums([500, 1000]),
    Indicator.yearsWithProfit => _minimums([4, 5]),
    Indicator.netMargin => _minimums([1000, 2000]),
    Indicator.netDebtToEquity => _maximums([5000, 10000, 20000]),
    Indicator.propertiesCount => _minimums([2, 5, 10]),
    Indicator.largestProperty => _maximums([5000, 3000, 2000]),
    Indicator.largestTenant => _maximums([5000, 3000, 2000]),
    Indicator.vacancy => _maximums([500, 1000, 2000]),
    Indicator.delinquency => _maximums([200, 500]),
    Indicator.development => _maximums([1000, 5000]),
    Indicator.liquidity => _minimums([
      10000000,
      _halfMillion,
      _oneMillion,
      500000000,
    ]),
  };

  static List<IndicatorRange> _minimums(List<int> values) => [
    for (final value in values) IndicatorRange(min: value),
  ];

  static List<IndicatorRange> _maximums(List<int> values) => [
    for (final value in values) IndicatorRange(max: value),
  ];
}

enum AssetAlert {
  singleProperty,
  concentratedProperty,
  concentratedTenant,
  highVacancy,
  highDelinquency,
  development,
  irregularIncome,
  lowLiquidity,
  recentLoss,
  highDebt,
  payoutAboveProfit,
}

extension AssetAlerts on AssetIndicators {
  List<AssetAlert> alerts(AssetType type) => [
    if (type == AssetType.fii) ..._fundAlerts,
    if (type == AssetType.stock) ..._companyAlerts,
    if ((liquidityCents ?? _oneMillion) < 10000000) AssetAlert.lowLiquidity,
  ];

  List<AssetAlert> get _fundAlerts => [
    if (propertiesCount == 1) AssetAlert.singleProperty,
    if ((propertiesCount ?? 0) > 1 && (largestPropertyBps ?? 0) >= 5000)
      AssetAlert.concentratedProperty,
    if ((largestTenantBps ?? 0) >= 3000) AssetAlert.concentratedTenant,
    if ((vacancyBps ?? 0) >= 1500) AssetAlert.highVacancy,
    if ((delinquencyBps ?? 0) >= 500) AssetAlert.highDelinquency,
    if ((developmentBps ?? 0) > 5000) AssetAlert.development,
    if ((monthsPaying12m ?? 12) < 9) AssetAlert.irregularIncome,
  ];

  List<AssetAlert> get _companyAlerts => [
    if (yearsWithProfit case final profit?
        when profit < (financialYears ?? profit))
      AssetAlert.recentLoss,
    if ((netDebtToEquityBps ?? 0) >= 20000) AssetAlert.highDebt,
    if ((payoutBps ?? 0) > 10000) AssetAlert.payoutAboveProfit,
  ];
}
