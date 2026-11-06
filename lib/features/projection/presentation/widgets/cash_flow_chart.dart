import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lar_em_dia/core/charts/chart_scale.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/chart_painting.dart';

class CashFlowChart extends StatelessWidget {
  const new({
    required this.months,
    required this.selected,
    required this.onSelect,
    required this.semanticsLabel,
    super.key,
    this.showBalance = true,
    this.showFlow = true,
  });

  static const leftAxis = 44.0;
  static final _monthLabel = DateFormat.MMM('pt_BR');
  static const bottomAxis = 24.0;

  final List<ProjectionMonth> months;
  final int selected;
  final ValueChanged<int> onSelect;
  final String semanticsLabel;
  final bool showBalance;
  final bool showFlow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticsLabel,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bands = BandScale(
            count: months.length,
            start: leftAxis,
            end: constraints.maxWidth,
          );
          void select(Offset position) => onSelect(bands.indexAt(position.dx));
          return GestureDetector(
            onTapDown: (details) => select(details.localPosition),
            onHorizontalDragUpdate: (details) => select(details.localPosition),
            child: CustomPaint(
              size: Size(constraints.maxWidth, 240),
              painter: CashFlowPainter(
                months: months,
                selected: selected,
                showBalance: showBalance,
                showFlow: showFlow,
                colors: FinanceColors.of(context),
                scheme: theme.colorScheme,
                labelStyle: theme.textTheme.labelSmall!.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                monthLabel: _monthLabel.format,
              ),
            ),
          );
        },
      ),
    );
  }
}

class CashFlowPainter extends CustomPainter {
  new({
    required this.months,
    required this.selected,
    required this.showBalance,
    required this.showFlow,
    required this.colors,
    required this.scheme,
    required this.labelStyle,
    required this.monthLabel,
  });

  final List<ProjectionMonth> months;
  final int selected;
  final bool showBalance;
  final bool showFlow;
  final FinanceColors colors;
  final ColorScheme scheme;
  final TextStyle labelStyle;
  final String Function(DateTime month) monthLabel;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 8.0;
    final bottom = size.height - CashFlowChart.bottomAxis;
    final values = ValueScale.fromValues([
      if (showBalance) ...months.map((month) => month.closingCents),
      if (showFlow) ...months.map((month) => month.incomeCents),
      if (showFlow) ...months.map((month) => -month.expenseCents),
    ]);
    final bands = BandScale(
      count: months.length,
      start: CashFlowChart.leftAxis,
      end: size.width,
    );
    double y(int cents) => values.position(cents, top: top, bottom: bottom);
    final zero = y(0);

    for (final tick in values.ticks) {
      canvas.drawLine(
        Offset(CashFlowChart.leftAxis, y(tick)),
        Offset(size.width, y(tick)),
        Paint()
          ..color = scheme.outlineVariant
          ..strokeWidth = tick == 0 ? 1.4 : 0.6,
      );
      paintLabel(
        canvas,
        Money.compact(tick),
        Offset(CashFlowChart.leftAxis - 6, y(tick)),
        style: labelStyle,
        align: TextAlign.right,
      );
    }

    if (showFlow) {
      final width = (bands.band * 0.32).clamp(2.0, 10.0);
      for (final (index, month) in months.indexed) {
        final dim = index == selected ? 1.0 : 0.55;
        final center = bands.center(index);
        canvas
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(
                center - width - 0.5,
                y(month.incomeCents),
                center - 0.5,
                zero,
              ),
              const Radius.circular(2),
            ),
            Paint()..color = colors.positive.withValues(alpha: 0.7 * dim),
          )
          ..drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(
                center + 0.5,
                zero,
                center + width + 0.5,
                y(-month.expenseCents),
              ),
              const Radius.circular(2),
            ),
            Paint()..color = colors.negative.withValues(alpha: 0.6 * dim),
          );
      }
    }

    if (showBalance) {
      final points = [
        for (final (index, month) in months.indexed)
          Offset(bands.center(index), y(month.closingCents)),
      ];
      final line = Path()..addPolygon(points, false);
      final area = Path()..moveTo(points.first.dx, zero);
      for (final point in points) {
        area.lineTo(point.dx, point.dy);
      }
      area
        ..lineTo(points.last.dx, zero)
        ..close();
      final above = Rect.fromLTRB(0, 0, size.width, zero);
      final below = Rect.fromLTRB(0, zero, size.width, size.height);
      for (final (region, color) in [
        (above, scheme.primary),
        (below, colors.negative),
      ]) {
        canvas
          ..save()
          ..clipRect(region)
          ..drawPath(area, Paint()..color = color.withValues(alpha: 0.12))
          ..drawPath(
            line,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..strokeJoin = StrokeJoin.round,
          )
          ..restore();
      }
    }

    final x = bands.center(selected);
    canvas.drawLine(
      Offset(x, top),
      Offset(x, bottom),
      Paint()
        ..color = scheme.onSurface.withValues(alpha: 0.35)
        ..strokeWidth = 1,
    );
    if (showBalance) {
      final month = months[selected];
      final center = Offset(x, y(month.closingCents));
      canvas
        ..drawCircle(center, 6, Paint()..color = scheme.surface)
        ..drawCircle(
          center,
          6,
          Paint()
            ..color = month.isNegative ? colors.negative : scheme.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
    }

    for (final index in bands.labelIndexes()) {
      paintLabel(
        canvas,
        monthLabel(months[index].month),
        Offset(bands.center(index), size.height - CashFlowChart.bottomAxis / 2),
        style: labelStyle,
      );
    }
  }

  @override
  bool shouldRepaint(CashFlowPainter oldDelegate) =>
      oldDelegate.months != months ||
      oldDelegate.selected != selected ||
      oldDelegate.showBalance != showBalance ||
      oldDelegate.showFlow != showFlow ||
      oldDelegate.colors != colors ||
      oldDelegate.scheme != scheme;
}
