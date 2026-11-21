import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_label.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_visuals.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/monthly_result_chart.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/projection_summary.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/waterfall_chart.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class ProjectionDetailsPage extends StatelessWidget {
  const new({required this.projection, super.key});

  static const topCategories = 5;
  static const reasonsPerMonth = 2;

  final Projection projection;

  List<ProjectionMonth> get months => projection.months;

  static Map<String, int> categoryTotals(Iterable<ProjectionMonth> months) {
    final totals = <String, int>{};
    for (final month in months) {
      for (final amount in month.expenseByCategory) {
        totals.update(
          amount.categoryKey,
          (cents) => cents + amount.amountCents,
          ifAbsent: () => amount.amountCents,
        );
      }
    }
    return Map.fromEntries(
      totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  static Map<String, String> categoryNames(Iterable<ProjectionMonth> months) =>
      {
        for (final month in months)
          for (final amount in month.expenseByCategory)
            amount.categoryKey: ?amount.categoryName,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.projectionDetailsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProjectionHero(months: months),
          const SizedBox(height: 16),
          _Section(
            title: l10n.projectionWaterfallTitle,
            hint: l10n.projectionWaterfallHint,
            child: _Waterfall(months: months),
          ),
          _Section(
            title: l10n.projectionResultsTitle,
            hint: l10n.projectionResultsHint,
            child: MonthlyResultChart(
              months: months,
              semanticsLabel: l10n.projectionResultsTitle,
            ),
          ),
          _Section(
            title: l10n.projectionNatureTitle,
            child: _NatureDonut(months: months),
          ),
          _Section(
            title: l10n.projectionTopTitle,
            child: _TopCategories(
              totals: categoryTotals(months),
              names: categoryNames(months),
            ),
          ),
          _Section(
            title: l10n.projectionAttentionTitle,
            child: _AttentionMonths(months: months),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const new({required this.title, required this.child, this.hint});

  final String title;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: theme.textTheme.labelMedium),
            const SizedBox(height: 12),
            child,
            if (hint case final hint?) ...[
              const SizedBox(height: 12),
              Text(
                hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Waterfall extends StatelessWidget {
  const new({required this.months});

  final List<ProjectionMonth> months;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = FinanceColors.of(context);
    final start = months.first.openingCents;
    final income = months.fold(0, (sum, month) => sum + month.incomeCents);
    final fixed = months.fold(0, (sum, month) => sum + month.fixedExpenseCents);
    final end = months.last.closingCents;
    Color base(int cents) => cents < 0 ? colors.negative : scheme.primary;
    return WaterfallChart(
      semanticsLabel: l10n.projectionWaterfallTitle,
      steps: [
        (
          label: l10n.projectionWaterfallStart,
          fromCents: 0,
          toCents: start,
          color: base(start),
        ),
        (
          label: l10n.projectionWaterfallIncome,
          fromCents: start,
          toCents: start + income,
          color: colors.positive.withValues(alpha: 0.7),
        ),
        (
          label: l10n.projectionWaterfallFixed,
          fromCents: start + income,
          toCents: start + income - fixed,
          color: scheme.primary.withValues(alpha: 0.75),
        ),
        (
          label: l10n.projectionWaterfallVariable,
          fromCents: start + income - fixed,
          toCents: end,
          color: scheme.tertiary,
        ),
        (
          label: l10n.projectionWaterfallEnd,
          fromCents: 0,
          toCents: end,
          color: base(end),
        ),
      ],
    );
  }
}

class _NatureDonut extends StatelessWidget {
  const new({required this.months});

  final List<ProjectionMonth> months;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fixed = months.fold(0, (sum, month) => sum + month.fixedExpenseCents);
    final variable = months.fold(
      0,
      (sum, month) => sum + month.variableExpenseCents,
    );
    final total = fixed + variable;
    final share = total == 0 ? 0 : (fixed * 100 / total).round();
    Widget legend(Color color, String label, int cents) => Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              Text(
                l10n.projectionPerMonth(Money.format(cents ~/ months.length)),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
    return Row(
      children: [
        SizedBox(
          width: 112,
          height: 112,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  centerSpaceRadius: 36,
                  sectionsSpace: 0,
                  startDegreeOffset: -90,
                  sections: [
                    PieChartSectionData(
                      value: total == 0 ? 1 : fixed.toDouble(),
                      color: total == 0
                          ? theme.colorScheme.surfaceContainerHighest
                          : theme.colorScheme.primary,
                      radius: 18,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: variable.toDouble(),
                      color: theme.colorScheme.tertiary,
                      radius: 18,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$share%', style: theme.textTheme.titleMedium),
                  Text(
                    l10n.projectionNatureShare,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              legend(
                theme.colorScheme.primary,
                l10n.projectionWaterfallFixed,
                fixed,
              ),
              const SizedBox(height: 8),
              legend(
                theme.colorScheme.tertiary,
                l10n.projectionWaterfallVariable,
                variable,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.projectionNatureTotal,
                style: theme.textTheme.bodySmall,
              ),
              Text(Money.format(total), style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopCategories extends StatelessWidget {
  const new({required this.totals, required this.names});

  final Map<String, int> totals;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (totals.isEmpty) {
      return Text(l10n.projectionTopEmpty);
    }
    final top = totals.entries.take(ProjectionDetailsPage.topCategories);
    final max = top.first.value;
    return Column(
      children: [
        for (final MapEntry(:key, value: cents) in top)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                CategoryAvatar.forKey(key),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              categoryKeyLabel(
                                l10n,
                                key,
                                fallback: names[key] ?? key,
                              ),
                            ),
                          ),
                          Text(Money.compact(cents)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: cents / max,
                          minHeight: 8,
                          color: FinanceColors.of(context).negative,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AttentionMonths extends StatelessWidget {
  const new({required this.months});

  final List<ProjectionMonth> months;

  static String _reason(AppLocalizations l10n, CategoryAmount amount) {
    final label = categoryKeyLabel(
      l10n,
      amount.categoryKey,
      fallback: amount.categoryName ?? amount.categoryKey,
    );
    return '$label ${Money.format(amount.amountCents)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final negative = months.where((month) => month.resultCents < 0).toList();
    if (negative.isEmpty) {
      return Text(l10n.projectionAttentionEmpty);
    }
    return Column(
      children: [
        for (final month in negative)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.negativeContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        monthName(context, month.month),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    ResultPill(cents: month.resultCents),
                  ],
                ),
                if (month.expenseByCategory.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.projectionAttentionReason(
                      month.expenseByCategory
                          .take(ProjectionDetailsPage.reasonsPerMonth)
                          .map((amount) => _reason(l10n, amount))
                          .join(' · '),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
