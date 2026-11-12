import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/per_share.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/investment_labels.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class GoalSplitBar extends StatelessWidget {
  const new({required this.goals, super.key});

  final Map<InvestmentGoal, PortfolioTotals> goals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = {
      InvestmentGoal.income: theme.colorScheme.tertiary,
      InvestmentGoal.growth: theme.colorScheme.primary,
    };
    final values = {
      for (final goal in InvestmentGoal.values)
        goal: goals[goal]?.marketValueCents ?? 0,
    };
    final total = values.values.fold(0, (sum, value) => sum + value);
    if (total <= 0) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final MapEntry(key: goal, :value) in values.entries)
                  if (value > 0)
                    Expanded(
                      flex: value,
                      child: ColoredBox(color: colors[goal]!),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final MapEntry(key: goal, :value) in values.entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 10, color: colors[goal]),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.investmentsGoalShare(
                        goal.label(l10n),
                        PerShare.percentFromBps(
                          PerShare.basisPoints(value, total)!,
                        ),
                        Money.format(value),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
