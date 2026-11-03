import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';

class ProjectionChart extends StatelessWidget {
  const new({required this.months, required this.semanticsLabel, super.key});

  final List<ProjectionMonth> months;
  final String semanticsLabel;

  static final _monthLabel = DateFormat.MMM('pt_BR');
  static final _axisLabel = NumberFormat.compact(locale: 'pt_BR');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelSmall;
    final spots = [
      for (final (index, month) in months.indexed)
        FlSpot(index.toDouble(), month.closingCents / 100),
    ];
    return Semantics(
      label: semanticsLabel,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: colors.primary,
              barWidth: 3,
              dotData: FlDotData(
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 4,
                  color: spot.y < 0 ? colors.error : colors.primary,
                ),
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(y: 0, color: colors.outline, strokeWidth: 1),
            ],
          ),
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    Money.format(months[spot.x.toInt()].closingCents),
                    TextStyle(color: colors.onInverseSurface),
                  ),
              ],
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 48,
                getTitlesWidget: (value, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(_axisLabel.format(value), style: textStyle),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
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
