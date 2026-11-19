import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/features/investments/domain/distribution.dart';
import 'package:lar_em_dia/features/investments/domain/screener.dart';

part 'asset.freezed.dart';

enum AssetType { stock, fii }

@freezed
abstract class AssetQuote with _$AssetQuote {
  const factory({required DateTime quotedOn, required int closeCents}) =
      _AssetQuote;
}

@freezed
abstract class Asset with _$Asset {
  const factory({
    required String ticker,
    required String name,
    required AssetType type,
    String? sector,
    AssetQuote? quote,
    FundReport? fundReport,
    FundComposition? composition,
    AssetIndicators? indicators,
    @Default([]) List<AssetDistribution> distributions,
  }) = _Asset;
}

enum FundPropertyKind { rent, rentConstruction, sale, saleConstruction }

@freezed
abstract class FundProperty with _$FundProperty {
  const factory({
    required String name,
    required FundPropertyKind kind,
    int? areaM2,
    int? vacancyBps,
    int? delinquencyBps,
    int? revenueShareBps,
  }) = _FundProperty;
}

@freezed
abstract class FundComposition with _$FundComposition {
  const factory({
    required DateTime referenceOn,
    int? largestTenantBps,
    @Default([]) List<FundProperty> properties,
  }) = _FundComposition;
}
