import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/core/money/per_share.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';

part 'portfolio.freezed.dart';

@freezed
abstract class PortfolioTotals with _$PortfolioTotals {
  const factory({
    required int contributedCents,
    required int costCents,
    required int marketValueCents,
    required int gainCents,
    required int realizedCents,
  }) = _PortfolioTotals;

  const new _();

  static const empty = PortfolioTotals(
    contributedCents: 0,
    costCents: 0,
    marketValueCents: 0,
    gainCents: 0,
    realizedCents: 0,
  );

  int? get gainBps => PerShare.basisPoints(gainCents, costCents);
}

@freezed
abstract class PortfolioPosition with _$PortfolioPosition {
  const factory({
    required String ticker,
    required String name,
    required AssetType type,
    required InvestmentGoal goal,
    required int quantity,
    required int averagePriceE8,
    required int costCents,
    required int realizedCents,
    required int marketValueCents,
    required int gainCents,
    AssetQuote? quote,
  }) = _PortfolioPosition;

  const new _();

  int? get gainBps => PerShare.basisPoints(gainCents, costCents);
}

@freezed
abstract class Portfolio with _$Portfolio {
  const factory({
    required PortfolioTotals totals,
    required Map<InvestmentGoal, PortfolioTotals> goals,
    required List<PortfolioPosition> positions,
  }) = _Portfolio;

  const new _();

  bool get isEmpty => positions.isEmpty && totals.realizedCents == 0;

  PortfolioPosition? position(String ticker) =>
      positions.where((position) => position.ticker == ticker).firstOrNull;
}

@freezed
abstract class PortfolioMonth with _$PortfolioMonth {
  const factory({
    required DateTime month,
    required int contributedCents,
    required int marketValueCents,
  }) = _PortfolioMonth;
}
