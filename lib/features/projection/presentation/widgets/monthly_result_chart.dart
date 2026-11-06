import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lar_em_dia/core/charts/chart_scale.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/chart_painting.dart';

class MonthlyResultChart extends StatelessWidget {
  const new({required this.months, required this.semanticsLabel, super.key});

  static final _monthLabel = DateFormat.MMM('pt_BR');

  final List<ProjectionMonth> months;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticsLabel,
      child: CustomPaint(
        size: const Size(double.infinity, 170),
        painter: MonthlyResultPainter(
          months: months,
          colors: FinanceColors.of(context),
          lineColor: theme.colorScheme.outlineVariant,
          savingsColor: theme.colorScheme.onSurface,
          labelStyle: theme.textTheme.labelSmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          monthLabel: _monthLabel.format,
        ),
      ),
    );
  }
}

class MonthlyResultPainter extends CustomPainter {
  new({
    required this.months,
    required this.colors,
    required this.lineColor,
    required this.savingsColor,
    required this.labelStyle,
    required this.monthLabel,
  });

  final List<ProjectionMonth> months;
  final FinanceColors colors;
  final Color lineColor;
  final Color savingsColor;
  final TextStyle labelStyle;
  final String Function(DateTime month) monthLabel;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 8.0;
    final bottom = size.height - 22;
    final values = ValueScale.fromValues([
      for (final month in months) ...[month.resultCents, month.savingsCents],
    ]);
    final bands = BandScale(count: months.length, start: 0, end: size.width);
    double y(int cents) => values.position(cents, top: top, bottom: bottom);
    final zero = y(0);
    canvas.drawLine(
      Offset(0, zero),
      Offset(size.width, zero),
      Paint()..color = lineColor,
    );
    final width = (bands.band * 0.55).clamp(3.0, 18.0);
    for (final (index, month) in months.indexed) {
      final center = bands.center(index);
      final end = y(month.resultCents);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            center - width / 2,
            end < zero ? end : zero,
            center + width / 2,
            (end - zero).abs() < 1.5 ? zero + 1.5 : (end < zero ? zero : end),
          ),
          const Radius.circular(2),
        ),
        Paint()
          ..color = month.resultCents < 0 ? colors.negative : colors.positive,
      );
    }
    final savings = Path()
      ..addPolygon([
        for (final (index, month) in months.indexed)
          Offset(bands.center(index), y(month.savingsCents)),
      ], false);
    canvas.drawPath(
      savings,
      Paint()
        ..color = savingsColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    for (final index in bands.labelIndexes(maxLabels: 6)) {
      paintLabel(
        canvas,
        monthLabel(months[index].month),
        Offset(bands.center(index), size.height - 8),
        style: labelStyle,
      );
    }
  }

  @override
  bool shouldRepaint(MonthlyResultPainter oldDelegate) =>
      oldDelegate.months != months || oldDelegate.colors != colors;
}
