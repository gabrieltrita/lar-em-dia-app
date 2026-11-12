import 'package:freezed_annotation/freezed_annotation.dart';

part 'investment_transaction.freezed.dart';

enum InvestmentKind {
  buy,
  sell,
  split,
  reverseSplit,
  bonus;

  bool get isTrade => this == buy || this == sell;
}

enum InvestmentGoal { income, growth }

@freezed
abstract class InvestmentTransaction with _$InvestmentTransaction {
  const factory({
    required String id,
    required String ticker,
    required InvestmentKind kind,
    required DateTime tradedOn,
    required int quantity,
    required int feesCents,
    int? priceCents,
    String? entryId,
  }) = _InvestmentTransaction;

  const new _();

  bool get changesBalance => entryId != null;

  int? get amountCents => tradeAmountCents(
    kind: kind,
    quantity: quantity,
    priceCents: priceCents,
    feesCents: feesCents,
  );
}

@freezed
abstract class InvestmentDraft with _$InvestmentDraft {
  const factory({
    required String ticker,
    required InvestmentKind kind,
    required DateTime tradedOn,
    required int quantity,
    int? priceCents,
    @Default(0) int feesCents,
    InvestmentGoal? goal,
    @Default(false) bool debitBalance,
  }) = _InvestmentDraft;

  const new _();

  int? get amountCents => tradeAmountCents(
    kind: kind,
    quantity: quantity,
    priceCents: priceCents,
    feesCents: feesCents,
  );
}

int? tradeAmountCents({
  required InvestmentKind kind,
  required int quantity,
  required int? priceCents,
  required int feesCents,
}) => switch ((kind, priceCents)) {
  (InvestmentKind.buy, final int price) => quantity * price + feesCents,
  (InvestmentKind.sell, final int price) => quantity * price - feesCents,
  _ => null,
};
