import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
import 'package:lar_em_dia/features/investments/domain/screener.dart';
import 'package:lar_em_dia/features/investments/domain/screener_presets.dart';
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

  group('screener', () {
    test('counts only the criteria of the selected type', () {
      const query = ScreenerQuery(
        payingOnly: true,
        hideSingleProperty: true,
        hideDevelopment: true,
        categories: {FundCategory.brick},
        ranges: {
          Indicator.dividendYield: IndicatorRange(min: 800),
          Indicator.roe: IndicatorRange(min: 1000),
          Indicator.vacancy: IndicatorRange(),
        },
      );

      expect(query.criteriaCount, 5);
      final stocks = query.withType(AssetType.stock);
      expect(stocks.criteriaCount, 3);
      expect(stocks.activeCategories, isEmpty);
      expect(stocks.hidesSingleProperty, isFalse);
      expect(stocks.hidesDevelopment, isFalse);
      expect(query.withType(AssetType.stock).sort, Indicator.dividendYield);
      expect(
        query.copyWith(sort: Indicator.vacancy).withType(AssetType.stock).sort,
        Indicator.dividendYield,
      );
    });

    test('replaces or removes one range', () {
      const query = ScreenerQuery(
        ranges: {Indicator.dividendYield: IndicatorRange(min: 800)},
      );

      expect(
        query.withRange(Indicator.vacancy, const IndicatorRange(max: 1000)),
        const ScreenerQuery(
          ranges: {
            Indicator.dividendYield: IndicatorRange(min: 800),
            Indicator.vacancy: IndicatorRange(max: 1000),
          },
        ),
      );
      expect(query.withRange(Indicator.dividendYield, null).ranges, isEmpty);
      expect(
        query.withRange(Indicator.dividendYield, const IndicatorRange()).ranges,
        isEmpty,
      );
    });

    test('offers strategies per type that match their own criteria', () {
      expect(ScreenerStrategy.forType(AssetType.fii), [
        ScreenerStrategy.steadyIncome,
        ScreenerStrategy.diversifiedBrick,
        ScreenerStrategy.discounted,
        ScreenerStrategy.receivables,
      ]);
      for (final strategy in ScreenerStrategy.values) {
        expect(strategy.query.type, strategy.type);
        expect(strategy.matches(strategy.query), isTrue);
        expect(
          strategy.matches(strategy.query.copyWith(ascending: true)),
          isTrue,
        );
        expect(strategy.matches(ScreenerQuery(type: strategy.type)), isFalse);
        for (final MapEntry(key: indicator, value: range)
            in strategy.query.ranges.entries) {
          expect(indicator.options(strategy.type), contains(range));
        }
      }
    });

    test('offers threshold options for every indicator of each type', () {
      for (final type in AssetType.values) {
        for (final indicator in Indicator.forType(type)) {
          expect(indicator.options(type), isNotEmpty);
          expect(indicator.types, contains(type));
        }
      }
      expect(
        Indicator.priceToBook.options(AssetType.stock).first,
        const IndicatorRange(max: 100),
      );
      expect(
        Indicator.yearsPaying.options(AssetType.fii).first,
        const IndicatorRange(min: 2),
      );
    });

    test('raises alerts on concentration, vacancy and irregular income', () {
      expect(ajfiIndicators.alerts(AssetType.fii), [
        AssetAlert.singleProperty,
        AssetAlert.concentratedTenant,
        AssetAlert.highVacancy,
        AssetAlert.irregularIncome,
        AssetAlert.lowLiquidity,
      ]);
      expect(hglgIndicators.alerts(AssetType.fii), isEmpty);
      expect(
        hglgIndicators
            .copyWith(
              propertiesCount: 3,
              largestPropertyBps: 6000,
              delinquencyBps: 500,
              developmentBps: 6000,
            )
            .alerts(AssetType.fii),
        [
          AssetAlert.concentratedProperty,
          AssetAlert.highDelinquency,
          AssetAlert.development,
        ],
      );
      expect(
        AssetIndicators(computedOn: DateTime(2026)).alerts(AssetType.fii),
        isEmpty,
      );
    });

    test('raises alerts on losses, debt and payout for stocks', () {
      expect(petrIndicators.alerts(AssetType.stock), isEmpty);
      expect(
        petrIndicators
            .copyWith(
              yearsWithProfit: 4,
              netDebtToEquityBps: 20000,
              payoutBps: 10001,
            )
            .alerts(AssetType.stock),
        [
          AssetAlert.recentLoss,
          AssetAlert.highDebt,
          AssetAlert.payoutAboveProfit,
        ],
      );
      expect(
        petrIndicators
            .copyWith(financialYears: null, yearsWithProfit: 3)
            .alerts(AssetType.stock),
        isEmpty,
      );
    });
  });
}
