import 'package:lar_em_dia/core/money/rates.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

extension ReserveKindLabel on ReserveKind {
  String label(AppLocalizations l10n) => switch (this) {
    ReserveKind.selicTreasury => l10n.reserveKindSelicTreasury,
    ReserveKind.cdb => l10n.reserveKindCdb,
    ReserveKind.savings => l10n.reserveKindSavings,
    ReserveKind.idle => l10n.reserveKindIdle,
    ReserveKind.fixedRate => l10n.reserveKindFixedRate,
  };
}

extension ReserveMovementKindLabel on ReserveMovementKind {
  String label(AppLocalizations l10n) => switch (this) {
    ReserveMovementKind.deposit => l10n.reserveMovementDeposit,
    ReserveMovementKind.withdrawal => l10n.reserveMovementWithdrawal,
    ReserveMovementKind.anchor => l10n.reserveMovementAnchor,
  };
}

extension ReserveAccountDescription on ReserveAccount {
  String description(AppLocalizations l10n) {
    final rate = switch ((kind, cdiPercentBps, annualRateBps)) {
      (ReserveKind.cdb, final int bps, _) => l10n.reserveRateCdi(
        Rates.percentFromBps(bps),
      ),
      (ReserveKind.fixedRate, _, final int bps) => l10n.reserveRateAnnual(
        Rates.percentFromBps(bps),
      ),
      _ => null,
    };
    return [
      kind.label(l10n),
      ?rate,
      if (taxExempt && kind.canBeExempt) l10n.reserveTaxExempt,
    ].join(' · ');
  }
}
