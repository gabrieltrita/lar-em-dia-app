import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';

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
  }) = _AssetDto;

  const new _();

  factory fromJson(Map<String, dynamic> json) => _$AssetDtoFromJson(json);

  Asset toDomain() => Asset(
    ticker: ticker,
    name: name,
    type: InvestmentWire.parseType(assetType),
    sector: sector,
    quote: quote?.toDomain(),
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
