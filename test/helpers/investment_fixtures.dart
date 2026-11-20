import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/distribution.dart';
import 'package:lar_em_dia/features/investments/domain/investment_repository.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
import 'package:lar_em_dia/features/investments/domain/screener.dart';
import 'package:lar_em_dia/features/investments/domain/simulation.dart';
import 'package:mocktail/mocktail.dart';

class MockInvestmentRepository extends Mock implements InvestmentRepository;

final quoteNov11 = AssetQuote(
  quotedOn: DateTime(2026, 11, 11),
  closeCents: 16000,
);

final hglg = Asset(
  ticker: 'HGLG11',
  name: 'PATRIA LOG FII',
  type: AssetType.fii,
  sector: 'Logística',
  quote: quoteNov11,
);

const petr = Asset(ticker: 'PETR4', name: 'PETROBRAS', type: AssetType.stock);

final hglgPosition = PortfolioPosition(
  ticker: 'HGLG11',
  name: 'PATRIA LOG FII',
  type: AssetType.fii,
  goal: InvestmentGoal.income,
  quantity: 10,
  averagePriceE8: 15050000000,
  costCents: 150500,
  realizedCents: 0,
  marketValueCents: 160000,
  gainCents: 9500,
  quote: quoteNov11,
);

const itsaPosition = PortfolioPosition(
  ticker: 'ITSA4',
  name: 'ITAUSA',
  type: AssetType.stock,
  goal: InvestmentGoal.growth,
  quantity: 100,
  averagePriceE8: 1100000000,
  costCents: 110000,
  realizedCents: 2500,
  marketValueCents: 100000,
  gainCents: -10000,
);

const incomeTotals = PortfolioTotals(
  contributedCents: 150500,
  costCents: 150500,
  marketValueCents: 160000,
  gainCents: 9500,
  realizedCents: 0,
);

const growthTotals = PortfolioTotals(
  contributedCents: 107500,
  costCents: 110000,
  marketValueCents: 100000,
  gainCents: -10000,
  realizedCents: 2500,
);

final portfolio = Portfolio(
  totals: const PortfolioTotals(
    contributedCents: 258000,
    costCents: 260500,
    marketValueCents: 260000,
    gainCents: -500,
    realizedCents: 2500,
  ),
  goals: const {
    InvestmentGoal.income: incomeTotals,
    InvestmentGoal.growth: growthTotals,
  },
  positions: [hglgPosition, itsaPosition],
);

const emptyPortfolio = Portfolio(
  totals: PortfolioTotals.empty,
  goals: {
    InvestmentGoal.income: PortfolioTotals.empty,
    InvestmentGoal.growth: PortfolioTotals.empty,
  },
  positions: [],
);

final List<PortfolioMonth> history = [
  for (var index = 0; index < 14; index++)
    PortfolioMonth(
      month: DateTime(2025, 10 + index),
      contributedCents: 10000 * (index + 1),
      marketValueCents: 10500 * (index + 1),
    ),
];

final hglgBuy = InvestmentTransaction(
  id: 'investment-1',
  ticker: 'HGLG11',
  kind: InvestmentKind.buy,
  tradedOn: DateTime(2026, 10, 5),
  quantity: 10,
  priceCents: 15000,
  feesCents: 500,
  entryId: 'entry-9',
);

final hglgSplit = InvestmentTransaction(
  id: 'investment-2',
  ticker: 'HGLG11',
  kind: InvestmentKind.split,
  tradedOn: DateTime(2026, 11, 2),
  quantity: 10,
  feesCents: 0,
);

final hglgDraft = InvestmentDraft(
  ticker: 'HGLG11',
  kind: InvestmentKind.buy,
  tradedOn: DateTime(2026, 10, 5),
  quantity: 10,
  priceCents: 15000,
  feesCents: 500,
  debitBalance: true,
);

final hglgReport = FundReport(
  referenceMonth: DateTime(2026, 9),
  equityCents: 754601779739,
  bookValuePerShareE8: 16547663017,
  sharesCount: 45601713,
  shareholdersCount: 613837,
);

final hglgIncome = AssetDistribution(
  id: 'distribution-1',
  ticker: 'HGLG11',
  kind: DistributionKind.fiiIncome,
  manual: false,
  recordOn: DateTime(2026, 9, 30),
  amountPerShareE8: 116691920,
  netAmountPerShareE8: 116691920,
);

final itsaJcp = AssetDistribution(
  id: 'distribution-2',
  ticker: 'ITSA4',
  kind: DistributionKind.jcp,
  manual: true,
  recordOn: DateTime(2026, 8, 20),
  paidOn: DateTime(2026, 11, 25),
  amountPerShareE8: 33333333,
  netAmountPerShareE8: 28333333,
);

final itsaJcpDraft = DistributionDraft(
  ticker: 'ITSA4',
  kind: DistributionKind.jcp,
  recordOn: DateTime(2026, 8, 20),
  paidOn: DateTime(2026, 11, 25),
  amountPerShareE8: 33333333,
);

final Asset hglgWithIncome = hglg.copyWith(
  fundReport: hglgReport,
  distributions: [hglgIncome],
);

const itsa = Asset(ticker: 'ITSA4', name: 'ITAUSA', type: AssetType.stock);

final passiveIncome = PassiveIncome(
  monthlyAverageCents: 1250,
  received: [
    IncomeMonth(month: DateTime(2026, 10), amountCents: 15000),
    IncomeMonth(month: DateTime(2026, 11), amountCents: 0),
  ],
  forecast: [IncomeMonth(month: DateTime(2026, 12), amountCents: 1167)],
  positions: const [
    PositionIncome(
      ticker: 'HGLG11',
      quantity: 10,
      received12mCents: 15000,
      monthlyForecastCents: 1167,
    ),
  ],
);

const noIncome = PassiveIncome(
  monthlyAverageCents: 0,
  received: [],
  forecast: [],
  positions: [],
);

void registerInvestmentFallbacks() {
  registerFallbackValue(itsaJcpDraft);
  registerFallbackValue(itsaJcp);
  registerFallbackValue(hglgDraft);
  registerFallbackValue(hglgBuy);
  registerFallbackValue(InvestmentGoal.income);
  registerFallbackValue(const ScreenerQuery());
  registerFallbackValue(incomeInput);
  registerFallbackValue(growthInput);
}

final hglgIndicators = AssetIndicators(
  computedOn: DateTime(2026, 11, 11),
  priceCents: 16000,
  dividendYieldBps: 825,
  distributionAverageE8: 110000000,
  distributionMedianE8: 108000000,
  yearsPaying: 3,
  priceToBookE2: 97,
  liquidityCents: 2854943689,
  fundCategory: FundCategory.brick,
  developmentBps: 0,
  propertiesCount: 36,
  largestPropertyBps: 543,
  vacancyBps: 245,
  delinquencyBps: 0,
  largestTenantBps: 466,
  monthsPaying12m: 11,
);

final ajfiIndicators = AssetIndicators(
  computedOn: DateTime(2026, 11, 11),
  priceCents: 827,
  dividendYieldBps: 640,
  fundCategory: FundCategory.brick,
  propertiesCount: 1,
  largestTenantBps: 4000,
  vacancyBps: 1800,
  monthsPaying12m: 6,
  liquidityCents: 5000000,
);

final ajfiScreened = Asset(
  ticker: 'AJFI11',
  name: 'AJ MALLS FII',
  type: AssetType.fii,
  sector: 'Shoppings',
  indicators: ajfiIndicators,
);

final hglgComposition = FundComposition(
  referenceOn: DateTime(2026, 9, 30),
  largestTenantBps: 466,
  properties: [
    const FundProperty(
      name: 'Betim',
      kind: FundPropertyKind.rent,
      areaM2: 35331,
      vacancyBps: 120,
      delinquencyBps: 0,
      revenueShareBps: 543,
    ),
    const FundProperty(name: 'Cajamar', kind: FundPropertyKind.rent),
    const FundProperty(
      name: 'Extrema',
      kind: FundPropertyKind.rentConstruction,
    ),
    const FundProperty(name: 'Jundiaí', kind: FundPropertyKind.sale),
    const FundProperty(
      name: 'Louveira',
      kind: FundPropertyKind.saleConstruction,
    ),
    const FundProperty(name: 'Sumaré', kind: FundPropertyKind.rent),
  ],
);

final petrIndicators = AssetIndicators(
  computedOn: DateTime(2026, 11, 11),
  priceCents: 3200,
  dividendYieldBps: 1095,
  yearsPaying: 5,
  payoutBps: 4087,
  priceToBookE2: 99,
  priceToEarningsE2: 373,
  roeAverageBps: 2210,
  earningsGrowthBps: -350,
  equityGrowthBps: 812,
  yearsWithProfit: 5,
  netMarginBps: 2223,
  netDebtToEquityBps: 7984,
  liquidityCents: 150000000000,
  financialYears: 5,
);

final Asset hglgScreened = hglg.copyWith(
  quote: null,
  indicators: hglgIndicators,
);

final Asset petrScreened = petr.copyWith(
  sector: 'Petróleo e Gás',
  indicators: petrIndicators,
);

const btlg = Asset(ticker: 'BTLG11', name: 'BTG LOG', type: AssetType.fii);

const incomeInput = IncomeSimulationInput(
  months: 24,
  initialCents: 100000,
  monthlyCents: 15000,
  ticker: 'HGLG11',
  targetMonthlyIncomeCents: 1000,
);

const incomeSimulation = IncomeSimulation(
  ticker: 'HGLG11',
  priceCents: 10000,
  monthlyIncomePerShareE8: 100000000,
  reinvest: true,
  sharesForTarget: 10,
  capitalForTargetCents: 100000,
  monthsToTarget: 1,
  targetMonthlyIncomeCents: 1000,
  months: [
    IncomeSimulationMonth(
      month: 12,
      contributedCents: 280000,
      shares: 28,
      valueCents: 285000,
      incomeCents: 2800,
      receivedCents: 22000,
    ),
    IncomeSimulationMonth(
      month: 24,
      contributedCents: 460000,
      shares: 48,
      valueCents: 485000,
      incomeCents: 4800,
      receivedCents: 70000,
    ),
  ],
);

const growthInput = GrowthSimulationInput(
  months: 12,
  annualRateBps: 1200,
  initialCents: 100000,
  monthlyCents: 10000,
);

const growthSimulation = GrowthSimulation(
  annualRateBps: 1200,
  monthlyRateE8: 948879,
  months: [
    GrowthSimulationMonth(
      month: 12,
      contributedCents: 220000,
      valueCents: 238465,
      earningsCents: 18465,
    ),
  ],
);
