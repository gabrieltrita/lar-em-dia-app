import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/investment_repository.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
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

void registerInvestmentFallbacks() {
  registerFallbackValue(hglgDraft);
  registerFallbackValue(hglgBuy);
  registerFallbackValue(InvestmentGoal.income);
}
