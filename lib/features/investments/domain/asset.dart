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
    AssetIndicators? indicators,
    @Default([]) List<AssetDistribution> distributions,
  }) = _Asset;
}
