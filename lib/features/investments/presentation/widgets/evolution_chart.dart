import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';

class EvolutionChart extends StatelessWidget {
  const new({
    required this.months,
    required this.semanticsLabel,
    this.compact = false,
    super.key,
  });

  final List<PortfolioMonth> months;
  final String semanticsLabel;
  final bool compact;

  static final _monthLabel = DateFormat.MMM('pt_BR');
  static final _axisLabel = NumberFormat.compact(locale: 'pt_BR');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelSmall;
    final series = [
      (colors.primary, (PortfolioMonth month) => month.marketValueCents),
      (colors.outline, (PortfolioMonth month) => month.contributedCents),
    ];
    final labelEvery = (months.length / 6).ceil().clamp(1, months.length);
    return Semantics(
      label: semanticsLabel,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            for (final (index, (color, value)) in series.indexed)
              LineChartBarData(
                spots: [
                  for (final (x, month) in months.indexed)
                    FlSpot(x.toDouble(), value(month) / 100),
                ],
                color: color,
                barWidth: index == 0 ? 3 : 2,
                dashArray: index == 0 ? null : const [6, 4],
                dotData: const FlDotData(show: false),
              ),
          ],
          gridData: FlGridData(show: !compact, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            enabled: !compact,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    Money.format(
                      series[spot.barIndex].$2(months[spot.x.toInt()]),
                    ),
                    TextStyle(color: colors.onInverseSurface),
                  ),
              ],
            ),
          ),
          titlesData: FlTitlesData(
            show: !compact,
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                minIncluded: false,
                maxIncluded: false,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(_axisLabel.format(value), style: textStyle),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: labelEvery.toDouble(),
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _monthLabel.format(months[value.toInt()].month),
                    style: textStyle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
