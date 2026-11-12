import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/core/widgets/money_text.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

String monthName(BuildContext context, DateTime month) =>
    MaterialLocalizations.of(context).formatMonthYear(month);

class ProjectionHero extends StatelessWidget {
  const new({required this.months, super.key, this.onSeeMore});

  final List<ProjectionMonth> months;
  final VoidCallback? onSeeMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final last = months.last;
    final month = monthName(context, last.month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.projectionHeroTitle('${last.isSaving}', month),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          MoneyText.format(last.savingsCents.abs()),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w500,
            color: last.isSaving
                ? FinanceColors.of(context).positive
                : FinanceColors.of(context).negative,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.projectionHeroClosing(month, Money.format(last.closingCents)),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (last.hasReserve)
          Text(
            l10n.projectionHeroWithReserve(
              Money.format(last.closingWithReserveCents),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        if (onSeeMore != null)
          TextButton(
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: onSeeMore,
            child: Text('${l10n.projectionSeeMore} ›'),
          ),
      ],
    );
  }
}

class PeriodSelector extends StatelessWidget {
  const new({required this.selected, required this.onSelected, super.key});

  final ProjectionPeriod selected;
  final ValueChanged<ProjectionPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      ProjectionPeriod.threeMonths: l10n.projectionPeriodThreeMonths,
      ProjectionPeriod.sixMonths: l10n.projectionPeriodSixMonths,
      ProjectionPeriod.year: l10n.projectionPeriodYear,
      ProjectionPeriod.all: l10n.projectionPeriodAll,
    };
    return Semantics(
      label: l10n.projectionPeriodLabel,
      child: SegmentedButton<ProjectionPeriod>(
        showSelectedIcon: false,
        segments: [
          for (final MapEntry(key: period, value: label) in labels.entries)
            ButtonSegment(value: period, label: Text(label)),
        ],
        selected: {selected},
        onSelectionChanged: (selection) => onSelected(selection.single),
      ),
    );
  }
}

class SeriesLegend extends StatelessWidget {
  const new({
    required this.showBalance,
    required this.showFlow,
    required this.onBalance,
    required this.onFlow,
    super.key,
  });

  final bool showBalance;
  final bool showFlow;
  final ValueChanged<bool> onBalance;
  final ValueChanged<bool> onFlow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: Text(l10n.projectionSeriesBalance),
          selected: showBalance,
          onSelected: showFlow ? onBalance : null,
        ),
        FilterChip(
          label: Text(l10n.projectionSeriesFlow),
          selected: showFlow,
          onSelected: showBalance ? onFlow : null,
        ),
      ],
    );
  }
}

class MonthReadout extends StatelessWidget {
  const new({required this.month, super.key});

  final ProjectionMonth month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final value = theme.textTheme.titleSmall;
    Widget cell(String title, Widget amount) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: label),
          amount,
        ],
      ),
    );
    final name = monthName(context, month.month);
    return Semantics(
      liveRegion: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name[0].toUpperCase() + name.substring(1),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  cell(
                    l10n.projectionSeriesBalance,
                    MoneyText(
                      month.closingCents,
                      style: value,
                      colored: month.isNegative,
                    ),
                  ),
                  cell(
                    l10n.projectionReadoutIncome,
                    MoneyText(month.incomeCents, style: value),
                  ),
                  cell(
                    l10n.projectionReadoutExpense,
                    MoneyText(month.expenseCents, style: value),
                  ),
                ],
              ),
              if (month.hasReserve) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    cell(
                      l10n.projectionReadoutReserve,
                      MoneyText(month.reserveCents, style: value),
                    ),
                    cell(
                      l10n.projectionReadoutWithReserve,
                      MoneyText(month.closingWithReserveCents, style: value),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ResultPill extends StatelessWidget {
  const new({required this.cents, super.key});

  final int cents;

  @override
  Widget build(BuildContext context) {
    final colors = FinanceColors.of(context);
    final negative = cents < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: negative ? colors.negativeContainer : colors.positiveContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        Money.compact(cents, signed: true),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: negative ? colors.negative : colors.positive,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class MonthSummaryTile extends StatelessWidget {
  const new({
    required this.month,
    required this.expanded,
    required this.onTap,
    super.key,
  });

  final ProjectionMonth month;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final total = month.fixedExpenseCents + month.variableExpenseCents;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(monthName(context, month.month))),
                ResultPill(cents: month.resultCents),
                const SizedBox(width: 12),
                SizedBox(
                  width: 112,
                  child: MoneyText(
                    month.closingCents,
                    colored: month.isNegative,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    l10n.projectionMonthIn(Money.format(month.incomeCents)),
                    style: muted,
                  ),
                  Text(
                    l10n.projectionMonthOut(Money.format(month.expenseCents)),
                    style: muted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (total > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        if (month.fixedExpenseCents > 0)
                          Expanded(
                            flex: month.fixedExpenseCents,
                            child: ColoredBox(color: theme.colorScheme.primary),
                          ),
                        if (month.variableExpenseCents > 0)
                          Expanded(
                            flex: month.variableExpenseCents,
                            child: ColoredBox(
                              color: theme.colorScheme.tertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    l10n.projectionMonthFixed(
                      Money.format(month.fixedExpenseCents),
                    ),
                    style: muted,
                  ),
                  Text(
                    l10n.projectionMonthVariable(
                      Money.format(month.variableExpenseCents),
                    ),
                    style: muted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(l10n.projectionMonthSaved, style: muted),
                  MoneyText(
                    month.savingsCents,
                    signed: true,
                    colored: true,
                    style: muted,
                  ),
                ],
              ),
              if (month.hasReserve) ...[
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(l10n.projectionReadoutReserve, style: muted),
                    MoneyText(month.reserveCents, style: muted),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
