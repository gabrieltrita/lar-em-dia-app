import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/distribution.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';

abstract interface class InvestmentRepository {
  Future<List<Asset>> searchAssets(String query);

  Future<Asset> asset(String ticker);

  Future<Portfolio> portfolio();

  Future<List<PortfolioMonth>> history();

  Future<List<InvestmentTransaction>> transactions(String ticker);

  Future<InvestmentTransaction> create(InvestmentDraft draft);

  Future<InvestmentTransaction> update(
    InvestmentTransaction existing,
    InvestmentDraft draft,
  );

  Future<void> delete(InvestmentTransaction transaction);

  Future<void> updateGoal(String ticker, InvestmentGoal goal);

  Future<PassiveIncome> income();

  Future<AssetDistribution> createDistribution(DistributionDraft draft);

  Future<AssetDistribution> updateDistribution(
    AssetDistribution existing,
    DistributionDraft draft,
  );

  Future<void> deleteDistribution(AssetDistribution distribution);
}
