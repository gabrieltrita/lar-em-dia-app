import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/features/allocation/presentation/cubits/allocation_cubits.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_label.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class AllocationSplitChart extends StatelessWidget {
  const new({required this.view, super.key});

  final AllocationView view;

  static List<(String, int)> slices(
    AppLocalizations l10n,
    AllocationView view,
  ) {
    final totals = <String, int>{};
    for (final item in view.plan.items) {
      if (item.amountCents <= 0) {
        continue;
      }
      final category = view.category(item.categoryId);
      final label = category == null
          ? item.name
          : categoryLabel(l10n, category);
      totals[label] = (totals[label] ?? 0) + item.amountCents;
    }
    final unallocated = view.plan.unallocatedCents;
    return [
      for (final MapEntry(:key, :value) in totals.entries) (key, value),
      if (unallocated > 0) (l10n.allocationUnallocated, unallocated),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final shown = slices(l10n, view);
    if (shown.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final categories = FinanceColors.of(context).categories;
    final palette = [
      for (final group in CategoryGroup.values)
        if (group != CategoryGroup.income) categories[group]!,
    ];
    final total = shown.fold(0, (sum, slice) => sum + slice.$2);
    Color color(int index) => palette[index % palette.length];
    return Card(
      key: const Key('allocation_chart'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.allocationChartTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          centerSpaceRadius: 40,
                          sectionsSpace: 3,
                          startDegreeOffset: -90,
                          sections: [
                            for (final (index, (_, cents)) in shown.indexed)
                              PieChartSectionData(
                                value: cents.toDouble(),
                                color: color(index),
                                radius: 14,
                                showTitle: false,
                              ),
                          ],
                        ),
                      ),
                      Text(
                        Money.compact(total),
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      for (final (index, (label, cents)) in shown.indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color(index),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text('${(cents * 100 / total).round()}%'),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
