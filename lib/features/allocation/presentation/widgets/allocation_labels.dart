import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/rates.dart';
import 'package:lar_em_dia/features/allocation/domain/allocation.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

extension AllocationModeLabel on AllocationMode {
  String label(AppLocalizations l10n) => switch (this) {
    AllocationMode.fixed => l10n.allocationModeFixed,
    AllocationMode.percent => l10n.allocationModePercent,
    AllocationMode.remainder => l10n.allocationModeRemainder,
  };
}

extension AllocationItemLabel on AllocationItem {
  String describe(AppLocalizations l10n, AllocationTarget? target) =>
      switch (mode) {
        AllocationMode.fixed => l10n.allocationFixedSummary(
          Money.format(target?.amountCents ?? amountCents),
        ),
        AllocationMode.percent => l10n.allocationPercentSummary(
          Rates.percentFromBps(percentBps ?? 0),
        ),
        AllocationMode.remainder => l10n.allocationRemainderSummary,
      };
}
