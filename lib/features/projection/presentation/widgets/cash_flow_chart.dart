import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lar_em_dia/core/charts/chart_scale.dart';
import 'package:lar_em_dia/core/charts/smooth_path.dart';
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
  static final _tooltipMonth = DateFormat.yMMM('pt_BR');
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
                tooltipMonth: _tooltipMonth.format,
                tooltipStyle: theme.textTheme.labelMedium!.copyWith(
                  color: theme.colorScheme.onInverseSurface,
                ),
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
    required this.tooltipMonth,
    required this.tooltipStyle,
  });

  final List<ProjectionMonth> months;
  final int selected;
  final bool showBalance;
  final bool showFlow;
  final FinanceColors colors;
  final ColorScheme scheme;
  final TextStyle labelStyle;
  final String Function(DateTime month) monthLabel;
  final String Function(DateTime month) tooltipMonth;
  final TextStyle tooltipStyle;

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

    if (values.min < 0) {
      canvas.drawRect(
        Rect.fromLTRB(CashFlowChart.leftAxis, zero, size.width, y(values.min)),
        Paint()..color = colors.negative.withValues(alpha: 0.05),
      );
    }
    for (final tick in values.ticks) {
      final start = Offset(CashFlowChart.leftAxis, y(tick));
      final end = Offset(size.width, y(tick));
      final grid = Paint()
        ..color = scheme.outlineVariant
        ..style = PaintingStyle.stroke
        ..strokeWidth = tick == 0 ? 1.4 : 1;
      if (tick == 0) {
        canvas.drawLine(start, end, grid);
      } else {
        canvas.drawPath(dashedLine(start, end), grid);
      }
      paintLabel(
        canvas,
        Money.compact(tick),
        Offset(CashFlowChart.leftAxis - 6, y(tick)),
        style: labelStyle,
        align: TextAlign.right,
      );
    }

    if (showFlow) {
      final width = (bands.band * 0.3).clamp(3.0, 14.0);
      final radius = Radius.circular(width / 2.5);
      for (final (index, month) in months.indexed) {
        final alpha = index == selected ? 1.0 : 0.45;
        final center = bands.center(index);
        canvas
          ..drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTRB(
                center - width - 1,
                y(month.incomeCents),
                center - 1,
                zero,
              ),
              topLeft: radius,
              topRight: radius,
            ),
            Paint()..color = colors.positive.withValues(alpha: alpha),
          )
          ..drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTRB(
                center + 1,
                zero,
                center + width + 1,
                y(-month.expenseCents),
              ),
              bottomLeft: radius,
              bottomRight: radius,
            ),
            Paint()..color = colors.negative.withValues(alpha: alpha),
          );
      }
    }

    if (showBalance) {
      final points = [
        for (final (index, month) in months.indexed)
          Offset(bands.center(index), y(month.closingCents)),
      ];
      final line = smoothPath(points);
      final area = Path.from(line)
        ..lineTo(points.last.dx, zero)
        ..lineTo(points.first.dx, zero)
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
          ..drawPath(
            area,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: region == above
                    ? [
                        color.withValues(alpha: 0.28),
                        color.withValues(alpha: 0),
                      ]
                    : [
                        color.withValues(alpha: 0),
                        color.withValues(alpha: 0.2),
                      ],
              ).createShader(region),
          )
          ..drawPath(
            line,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round,
          )
          ..restore();
      }
    }

    final x = bands.center(selected);
    canvas.drawPath(
      dashedLine(Offset(x, top), Offset(x, bottom), dash: 3, gap: 3),
      Paint()
        ..color = scheme.onSurface.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke,
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
      _paintTooltip(canvas, size, center, month);
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

  void _paintTooltip(
    Canvas canvas,
    Size size,
    Offset anchor,
    ProjectionMonth month,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        style: tooltipStyle,
        children: [
          TextSpan(text: '${tooltipMonth(month.month)}\n'),
          TextSpan(
            text: Money.format(month.closingCents),
            style: tooltipStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const padding = 8.0;
    final width = painter.width + padding * 2;
    final height = painter.height + padding * 2;
    final left = (anchor.dx - width / 2)
        .clamp(
          CashFlowChart.leftAxis,
          math.max(CashFlowChart.leftAxis, size.width - width),
        )
        .toDouble();
    final above = anchor.dy - height - 12;
    final bubble = Rect.fromLTWH(
      left,
      above < 0 ? anchor.dy + 12 : above,
      width,
      height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bubble, const Radius.circular(10)),
      Paint()..color = scheme.inverseSurface,
    );
    painter
      ..paint(canvas, bubble.topLeft + const Offset(padding, padding))
      ..dispose();
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
