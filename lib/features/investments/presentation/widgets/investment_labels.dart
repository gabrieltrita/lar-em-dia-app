import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

extension InvestmentGoalLabel on InvestmentGoal {
  String label(AppLocalizations l10n) => switch (this) {
    InvestmentGoal.income => l10n.investmentGoalIncome,
    InvestmentGoal.growth => l10n.investmentGoalGrowth,
  };
}

extension InvestmentKindLabel on InvestmentKind {
  String label(AppLocalizations l10n) => switch (this) {
    InvestmentKind.buy => l10n.investmentKindBuy,
    InvestmentKind.sell => l10n.investmentKindSell,
    InvestmentKind.split => l10n.investmentKindSplit,
    InvestmentKind.reverseSplit => l10n.investmentKindReverseSplit,
    InvestmentKind.bonus => l10n.investmentKindBonus,
  };
}

extension AssetTypeLabel on AssetType {
  String label(AppLocalizations l10n) => switch (this) {
    AssetType.stock => l10n.assetTypeStock,
    AssetType.fii => l10n.assetTypeFii,
  };

  InvestmentGoal get defaultGoal => switch (this) {
    AssetType.stock => InvestmentGoal.growth,
    AssetType.fii => InvestmentGoal.income,
  };
}
