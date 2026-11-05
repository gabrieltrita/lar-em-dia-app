import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/admin/domain/admin_metrics.dart';
import 'package:lar_em_dia/features/admin/presentation/cubits/admin_cubits.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class AdminMetricsPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AdminMetricsCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminMetrics)),
      body: BlocBuilder<AdminMetricsCubit, LoadState<AdminMetrics>>(
        builder: (context, state) => switch (state) {
          Loading() => const Center(child: CircularProgressIndicator()),
          LoadFailure(:final error) => RetryMessage(
            message: error.localized(l10n),
            onRetry: () => unawaited(cubit.load()),
          ),
          Loaded(value: final metrics) => RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _MetricsCard(
                  title: l10n.adminMetricsUsers,
                  values: [
                    (l10n.adminMetricsTotal, metrics.users.total),
                    (l10n.adminMetricsConfirmed, metrics.users.confirmed),
                    (l10n.adminMetricsActive, metrics.users.active30d),
                    (l10n.adminMetricsNew, metrics.users.new30d),
                    (l10n.adminMetricsDeactivated, metrics.users.deactivated),
                    (l10n.adminMetricsTwoFactor, metrics.users.withTwoFactor),
                  ],
                ),
                const SizedBox(height: 16),
                _MetricsCard(
                  title: l10n.adminMetricsEngagement,
                  values: [
                    (
                      l10n.adminMetricsWithBalance,
                      metrics.engagement.withBalance,
                    ),
                    (
                      l10n.adminMetricsWithEntries,
                      metrics.engagement.withEntries,
                    ),
                    (
                      l10n.adminMetricsWithFiveSeries,
                      metrics.engagement.withFiveSeries,
                    ),
                    (
                      l10n.adminMetricsEntries30d,
                      metrics.engagement.entriesCreated30d,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.adminMetricsSignups,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 220,
                  child: _SignupsChart(
                    weeks: metrics.signupsByWeek,
                    semanticsLabel: l10n.adminMetricsChartLabel,
                  ),
                ),
              ],
            ),
          ),
        },
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const new({required this.title, required this.values});

  final String title;
  final List<(String, int)> values;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                for (final (label, value) in values)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$value', style: textTheme.headlineSmall),
                      Text(label, style: textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignupsChart extends StatelessWidget {
  const new({required this.weeks, required this.semanticsLabel});

  final List<WeeklySignups> weeks;
  final String semanticsLabel;

  static final _weekLabel = DateFormat('dd/MM');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelSmall;
    return Semantics(
      label: semanticsLabel,
      child: BarChart(
        BarChartData(
          barGroups: [
            for (final (index, week) in weeks.indexed)
              BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: week.count.toDouble(),
                    color: colors.primary,
                    width: 12,
                  ),
                ],
              ),
          ],
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) =>
                    Text(meta.formattedValue, style: textStyle),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 2,
                getTitlesWidget: (value, _) => Text(
                  _weekLabel.format(weeks[value.toInt()].week),
                  style: textStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
