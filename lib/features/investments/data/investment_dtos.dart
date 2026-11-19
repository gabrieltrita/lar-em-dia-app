import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/distribution.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
import 'package:lar_em_dia/features/investments/domain/screener.dart';
import 'package:lar_em_dia/features/investments/domain/simulation.dart';

part 'investment_dtos.freezed.dart';
part 'investment_dtos.g.dart';

abstract final class InvestmentWire {
  static const Map<InvestmentKind, String> kinds = {
    InvestmentKind.buy: 'buy',
    InvestmentKind.sell: 'sell',
    InvestmentKind.split: 'split',
    InvestmentKind.reverseSplit: 'reverse_split',
    InvestmentKind.bonus: 'bonus',
  };

  static String kind(InvestmentKind kind) => kinds[kind]!;

  static InvestmentKind parseKind(String value) =>
      kinds.entries.firstWhere((entry) => entry.value == value).key;

  static AssetType parseType(String value) => AssetType.values.byName(value);

  static InvestmentGoal parseGoal(String value) =>
      InvestmentGoal.values.byName(value);

  static const Map<DistributionKind, String> distributionKinds = {
    DistributionKind.fiiIncome: 'fii_income',
    DistributionKind.dividend: 'dividend',
    DistributionKind.jcp: 'jcp',
  };

  static String distributionKind(DistributionKind kind) =>
      distributionKinds[kind]!;

  static DistributionKind parseDistributionKind(String value) =>
      distributionKinds.entries.firstWhere((entry) => entry.value == value).key;

  static const Map<Indicator, String> indicators = {
    Indicator.dividendYield: 'dy_12m_bps',
    Indicator.priceToBook: 'p_vp_e2',
    Indicator.yearsPaying: 'years_paying',
    Indicator.payout: 'payout_bps',
    Indicator.priceToEarnings: 'p_l_e2',
    Indicator.roe: 'roe_average_bps',
    Indicator.earningsGrowth: 'earnings_cagr_bps',
    Indicator.equityGrowth: 'equity_cagr_bps',
    Indicator.yearsWithProfit: 'years_with_profit',
    Indicator.netMargin: 'net_margin_bps',
    Indicator.netDebtToEquity: 'net_debt_to_equity_bps',
    Indicator.liquidity: 'liquidity_cents',
    Indicator.monthsPaying: 'months_paying_12m',
    Indicator.propertiesCount: 'properties_count',
    Indicator.largestProperty: 'largest_property_bps',
    Indicator.largestTenant: 'largest_tenant_bps',
    Indicator.vacancy: 'vacancy_bps',
    Indicator.delinquency: 'delinquency_bps',
    Indicator.development: 'development_bps',
  };

  static String indicator(Indicator indicator) => indicators[indicator]!;

  static const Map<FundCategory, String> categories = {
    FundCategory.brick: 'brick',
    FundCategory.paper: 'paper',
    FundCategory.fundOfFunds: 'fund_of_funds',
    FundCategory.hybrid: 'hybrid',
  };

  static String category(FundCategory category) => categories[category]!;

  static FundCategory? parseCategory(String? value) => categories.entries
      .where((entry) => entry.value == value)
      .firstOrNull
      ?.key;

  static const Map<FundPropertyKind, String> propertyKinds = {
    FundPropertyKind.rent: 'rent',
    FundPropertyKind.rentConstruction: 'rent_construction',
    FundPropertyKind.sale: 'sale',
    FundPropertyKind.saleConstruction: 'sale_construction',
  };

  static FundPropertyKind parsePropertyKind(String value) =>
      propertyKinds.entries.firstWhere((entry) => entry.value == value).key;
}

@freezed
abstract class AssetIndicatorsDto with _$AssetIndicatorsDto {
  const factory({
    required String computedOn,
    int? priceCents,
    @JsonKey(name: 'dy_12m_bps') int? dy12mBps,
    int? distributionAverageE8,
    int? distributionMedianE8,
    int? yearsPaying,
    int? payoutBps,
    @JsonKey(name: 'p_vp_e2') int? pVpE2,
    @JsonKey(name: 'p_l_e2') int? pLE2,
    int? roeAverageBps,
    int? earningsCagrBps,
    int? equityCagrBps,
    int? yearsWithProfit,
    int? netMarginBps,
    int? netDebtToEquityBps,
    int? liquidityCents,
    int? financialYears,
    String? fundCategory,
    int? developmentBps,
    int? propertiesCount,
    int? largestPropertyBps,
    int? vacancyBps,
    int? delinquencyBps,
    int? largestTenantBps,
    @JsonKey(name: 'months_paying_12m') int? monthsPaying12m,
  }) = _AssetIndicatorsDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$AssetIndicatorsDtoFromJson(json);

  AssetIndicators toDomain() => AssetIndicators(
    computedOn: Dates.parseIso(computedOn),
    priceCents: priceCents,
    dividendYieldBps: dy12mBps,
    distributionAverageE8: distributionAverageE8,
    distributionMedianE8: distributionMedianE8,
    yearsPaying: yearsPaying,
    payoutBps: payoutBps,
    priceToBookE2: pVpE2,
    priceToEarningsE2: pLE2,
    roeAverageBps: roeAverageBps,
    earningsGrowthBps: earningsCagrBps,
    equityGrowthBps: equityCagrBps,
    yearsWithProfit: yearsWithProfit,
    netMarginBps: netMarginBps,
    netDebtToEquityBps: netDebtToEquityBps,
    liquidityCents: liquidityCents,
    financialYears: financialYears,
    fundCategory: InvestmentWire.parseCategory(fundCategory),
    developmentBps: developmentBps,
    propertiesCount: propertiesCount,
    largestPropertyBps: largestPropertyBps,
    vacancyBps: vacancyBps,
    delinquencyBps: delinquencyBps,
    largestTenantBps: largestTenantBps,
    monthsPaying12m: monthsPaying12m,
  );
}

@freezed
abstract class FundPropertyDto with _$FundPropertyDto {
  const factory({
    required String name,
    required String kind,
    @JsonKey(name: 'area_m2') int? areaM2,
    int? vacancyBps,
    int? delinquencyBps,
    int? revenueShareBps,
  }) = _FundPropertyDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$FundPropertyDtoFromJson(json);

  FundProperty toDomain() => FundProperty(
    name: name,
    kind: InvestmentWire.parsePropertyKind(kind),
    areaM2: areaM2,
    vacancyBps: vacancyBps,
    delinquencyBps: delinquencyBps,
    revenueShareBps: revenueShareBps,
  );
}

@freezed
abstract class FundCompositionDto with _$FundCompositionDto {
  const factory({
    required String referenceOn,
    int? largestTenantBps,
    @Default([]) List<FundPropertyDto> properties,
  }) = _FundCompositionDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$FundCompositionDtoFromJson(json);

  FundComposition toDomain() => FundComposition(
    referenceOn: Dates.parseIso(referenceOn),
    largestTenantBps: largestTenantBps,
    properties: [for (final property in properties) property.toDomain()],
  );
}

@freezed
abstract class IncomeSimulationMonthDto with _$IncomeSimulationMonthDto {
  const factory({
    required int month,
    required int contributedCents,
    required int valueCents,
    required int incomeCents,
    required int receivedCents,
    int? shares,
  }) = _IncomeSimulationMonthDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$IncomeSimulationMonthDtoFromJson(json);

  IncomeSimulationMonth toDomain() => IncomeSimulationMonth(
    month: month,
    contributedCents: contributedCents,
    valueCents: valueCents,
    incomeCents: incomeCents,
    receivedCents: receivedCents,
    shares: shares,
  );
}

@freezed
abstract class IncomeSimulationSummaryDto with _$IncomeSimulationSummaryDto {
  const factory({
    int? targetMonthlyIncomeCents,
    int? sharesForTarget,
    int? capitalForTargetCents,
    int? monthsToTarget,
  }) = _IncomeSimulationSummaryDto;

  factory fromJson(Map<String, dynamic> json) =>
      _$IncomeSimulationSummaryDtoFromJson(json);
}

@freezed
abstract class IncomeSimulationDto with _$IncomeSimulationDto {
  const factory({
    required bool reinvest,
    required List<IncomeSimulationMonthDto> months,
    required IncomeSimulationSummaryDto summary,
    String? ticker,
    int? priceCents,
    int? monthlyIncomePerShareE8,
    int? monthlyYieldBps,
  }) = _IncomeSimulationDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$IncomeSimulationDtoFromJson(json);

  IncomeSimulation toDomain() => IncomeSimulation(
    months: [for (final month in months) month.toDomain()],
    reinvest: reinvest,
    ticker: ticker,
    priceCents: priceCents,
    monthlyIncomePerShareE8: monthlyIncomePerShareE8,
    monthlyYieldBps: monthlyYieldBps,
    sharesForTarget: summary.sharesForTarget,
    capitalForTargetCents: summary.capitalForTargetCents,
    monthsToTarget: summary.monthsToTarget,
    targetMonthlyIncomeCents: summary.targetMonthlyIncomeCents,
  );
}

@freezed
abstract class GrowthSimulationMonthDto with _$GrowthSimulationMonthDto {
  const factory({
    required int month,
    required int contributedCents,
    required int valueCents,
    required int earningsCents,
  }) = _GrowthSimulationMonthDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$GrowthSimulationMonthDtoFromJson(json);

  GrowthSimulationMonth toDomain() => GrowthSimulationMonth(
    month: month,
    contributedCents: contributedCents,
    valueCents: valueCents,
    earningsCents: earningsCents,
  );
}

@freezed
abstract class GrowthSimulationDto with _$GrowthSimulationDto {
  const factory({
    required int annualRateBps,
    required int monthlyRateE8,
    required List<GrowthSimulationMonthDto> months,
  }) = _GrowthSimulationDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$GrowthSimulationDtoFromJson(json);

  GrowthSimulation toDomain() => GrowthSimulation(
    annualRateBps: annualRateBps,
    monthlyRateE8: monthlyRateE8,
    months: [for (final month in months) month.toDomain()],
  );
}

@freezed
abstract class AssetDistributionDto with _$AssetDistributionDto {
  const factory({
    required String id,
    required String ticker,
    required String kind,
    required String source,
    required String recordOn,
    required int amountPerShareE8,
    required int netAmountPerShareE8,
    String? paidOn,
  }) = _AssetDistributionDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$AssetDistributionDtoFromJson(json);

  AssetDistribution toDomain() => AssetDistribution(
    id: id,
    ticker: ticker,
    kind: InvestmentWire.parseDistributionKind(kind),
    manual: source == 'manual',
    recordOn: Dates.parseIso(recordOn),
    paidOn: paidOn == null ? null : Dates.parseIso(paidOn!),
    amountPerShareE8: amountPerShareE8,
    netAmountPerShareE8: netAmountPerShareE8,
  );
}

@freezed
abstract class FundReportDto with _$FundReportDto {
  const factory({
    required String referenceMonth,
    required int equityCents,
    required int bookValuePerShareE8,
    required int sharesCount,
    required int shareholdersCount,
  }) = _FundReportDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$FundReportDtoFromJson(json);

  FundReport toDomain() => FundReport(
    referenceMonth: Dates.parseMonth(referenceMonth)!,
    equityCents: equityCents,
    bookValuePerShareE8: bookValuePerShareE8,
    sharesCount: sharesCount,
    shareholdersCount: shareholdersCount,
  );
}

@freezed
abstract class IncomeMonthDto with _$IncomeMonthDto {
  const factory({required String month, required int amountCents}) =
      _IncomeMonthDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$IncomeMonthDtoFromJson(json);

  IncomeMonth toDomain() =>
      IncomeMonth(month: Dates.parseMonth(month)!, amountCents: amountCents);
}

@freezed
abstract class PositionIncomeDto with _$PositionIncomeDto {
  const factory({
    required String ticker,
    required int quantity,
    @JsonKey(name: 'received_12m_cents') required int received12mCents,
    required int monthlyForecastCents,
  }) = _PositionIncomeDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$PositionIncomeDtoFromJson(json);

  PositionIncome toDomain() => PositionIncome(
    ticker: ticker,
    quantity: quantity,
    received12mCents: received12mCents,
    monthlyForecastCents: monthlyForecastCents,
  );
}

@freezed
abstract class PassiveIncomeDto with _$PassiveIncomeDto {
  const factory({
    required int monthlyAverageCents,
    required List<IncomeMonthDto> received,
    required List<IncomeMonthDto> forecast,
    required List<PositionIncomeDto> positions,
  }) = _PassiveIncomeDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$PassiveIncomeDtoFromJson(json);

  PassiveIncome toDomain() => PassiveIncome(
    monthlyAverageCents: monthlyAverageCents,
    received: [for (final month in received) month.toDomain()],
    forecast: [for (final month in forecast) month.toDomain()],
    positions: [for (final position in positions) position.toDomain()],
  );
}

@freezed
abstract class AssetQuoteDto with _$AssetQuoteDto {
  const factory({required String quotedOn, required int closeCents}) =
      _AssetQuoteDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$AssetQuoteDtoFromJson(json);

  AssetQuote toDomain() =>
      AssetQuote(quotedOn: Dates.parseIso(quotedOn), closeCents: closeCents);
}

@freezed
abstract class AssetDto with _$AssetDto {
  const factory({
    required String ticker,
    required String name,
    required String assetType,
    String? sector,
    AssetQuoteDto? quote,
    FundReportDto? fundReport,
    FundCompositionDto? composition,
    AssetIndicatorsDto? indicators,
    @Default([]) List<AssetDistributionDto> distributions,
  }) = _AssetDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$AssetDtoFromJson(json);

  Asset toDomain() => Asset(
    ticker: ticker,
    name: name,
    type: InvestmentWire.parseType(assetType),
    sector: sector,
    quote: quote?.toDomain(),
    fundReport: fundReport?.toDomain(),
    composition: composition?.toDomain(),
    indicators: indicators?.toDomain(),
    distributions: [
      for (final distribution in distributions) distribution.toDomain(),
    ],
  );
}

@freezed
abstract class InvestmentTransactionDto with _$InvestmentTransactionDto {
  const factory({
    required String id,
    required String ticker,
    required String kind,
    required String tradedOn,
    required int quantity,
    required int feesCents,
    int? priceCents,
    String? entryId,
  }) = _InvestmentTransactionDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$InvestmentTransactionDtoFromJson(json);

  InvestmentTransaction toDomain() => InvestmentTransaction(
    id: id,
    ticker: ticker,
    kind: InvestmentWire.parseKind(kind),
    tradedOn: Dates.parseIso(tradedOn),
    quantity: quantity,
    feesCents: feesCents,
    priceCents: priceCents,
    entryId: entryId,
  );
}

@freezed
abstract class PortfolioTotalsDto with _$PortfolioTotalsDto {
  const factory({
    required int contributedCents,
    required int costCents,
    required int marketValueCents,
    required int gainCents,
    required int realizedCents,
  }) = _PortfolioTotalsDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$PortfolioTotalsDtoFromJson(json);

  PortfolioTotals toDomain() => PortfolioTotals(
    contributedCents: contributedCents,
    costCents: costCents,
    marketValueCents: marketValueCents,
    gainCents: gainCents,
    realizedCents: realizedCents,
  );
}

@freezed
abstract class PortfolioPositionDto with _$PortfolioPositionDto {
  const factory({
    required String ticker,
    required String name,
    required String assetType,
    required String goal,
    required int quantity,
    required int averagePriceE8,
    required int costCents,
    required int realizedCents,
    required int marketValueCents,
    required int gainCents,
    AssetQuoteDto? quote,
  }) = _PortfolioPositionDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$PortfolioPositionDtoFromJson(json);

  PortfolioPosition toDomain() => PortfolioPosition(
    ticker: ticker,
    name: name,
    type: InvestmentWire.parseType(assetType),
    goal: InvestmentWire.parseGoal(goal),
    quantity: quantity,
    averagePriceE8: averagePriceE8,
    costCents: costCents,
    realizedCents: realizedCents,
    marketValueCents: marketValueCents,
    gainCents: gainCents,
    quote: quote?.toDomain(),
  );
}

@freezed
abstract class PortfolioDto with _$PortfolioDto {
  const factory({
    required PortfolioTotalsDto totals,
    required Map<String, PortfolioTotalsDto> goals,
    required List<PortfolioPositionDto> positions,
  }) = _PortfolioDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$PortfolioDtoFromJson(json);

  Portfolio toDomain() => Portfolio(
    totals: totals.toDomain(),
    goals: {
      for (final goal in InvestmentGoal.values)
        goal: goals[goal.name]?.toDomain() ?? PortfolioTotals.empty,
    },
    positions: [for (final position in positions) position.toDomain()],
  );
}

@freezed
abstract class PortfolioMonthDto with _$PortfolioMonthDto {
  const factory({
    required String month,
    required int contributedCents,
    required int marketValueCents,
  }) = _PortfolioMonthDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) =>
      _$PortfolioMonthDtoFromJson(json);

  PortfolioMonth toDomain() => PortfolioMonth(
    month: Dates.parseMonth(month)!,
    contributedCents: contributedCents,
    marketValueCents: marketValueCents,
  );
}
