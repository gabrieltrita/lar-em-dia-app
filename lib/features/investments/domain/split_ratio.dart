import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';

final class SplitRatio {
  const new({required this.from, required this.to});

  final int from;
  final int to;

  bool get isValid => from > 0 && to > 0 && from != to;

  InvestmentKind get kind =>
      to > from ? InvestmentKind.split : InvestmentKind.reverseSplit;

  int sharesAfter(int held) => held * to ~/ from;

  int change(int held) => (sharesAfter(held) - held).abs();
}
