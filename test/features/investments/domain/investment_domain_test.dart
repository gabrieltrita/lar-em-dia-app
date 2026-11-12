import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
import 'package:lar_em_dia/features/investments/domain/split_ratio.dart';

import '../../../helpers/investment_fixtures.dart';

void main() {
  group('SplitRatio', () {
    test('turns a split ratio into the shares received', () {
      const ratio = SplitRatio(from: 1, to: 2);

      expect(ratio.isValid, isTrue);
      expect(ratio.kind, InvestmentKind.split);
      expect(ratio.sharesAfter(100), 200);
      expect(ratio.change(100), 100);
    });

    test(
      'turns a reverse split into the shares removed, dropping fractions',
      () {
        const ratio = SplitRatio(from: 10, to: 1);

        expect(ratio.kind, InvestmentKind.reverseSplit);
        expect(ratio.sharesAfter(105), 10);
        expect(ratio.change(105), 95);
      },
    );

    test('refuses empty or neutral ratios', () {
      expect(const SplitRatio(from: 0, to: 2).isValid, isFalse);
      expect(const SplitRatio(from: 2, to: 0).isValid, isFalse);
      expect(const SplitRatio(from: 3, to: 3).isValid, isFalse);
    });
  });

  test('computes trade amounts like the API', () {
    expect(hglgBuy.amountCents, 150500);
    expect(hglgBuy.changesBalance, isTrue);
    expect(hglgSplit.amountCents, isNull);
    expect(hglgSplit.changesBalance, isFalse);
    expect(hglgDraft.amountCents, 150500);
    expect(hglgDraft.copyWith(kind: InvestmentKind.sell).amountCents, 149500);
    expect(InvestmentKind.bonus.isTrade, isFalse);
  });

  test('summarizes the portfolio', () {
    expect(portfolio.isEmpty, isFalse);
    expect(emptyPortfolio.isEmpty, isTrue);
    expect(portfolio.position('ITSA4'), itsaPosition);
    expect(portfolio.position('PETR4'), isNull);
    expect(portfolio.totals.gainBps, -19);
    expect(hglgPosition.gainBps, 631);
    expect(PortfolioTotals.empty.gainBps, isNull);
  });
}
