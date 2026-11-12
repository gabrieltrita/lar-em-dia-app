import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/money/rates.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class CoverageBar extends StatelessWidget {
  const new({
    required this.coverageMonthsE2,
    required this.goalMonths,
    super.key,
  });

  final int coverageMonthsE2;
  final int goalMonths;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final goalE2 = goalMonths * 100;
    final filled = coverageMonthsE2.clamp(0, goalE2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (filled > 0)
                  Expanded(
                    flex: filled,
                    child: ColoredBox(color: theme.colorScheme.primary),
                  ),
                if (goalE2 > filled)
                  Expanded(
                    flex: goalE2 - filled,
                    child: ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.reserveCoverage(Rates.months(coverageMonthsE2), goalMonths),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
