import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/charts/chart_scale.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/chart_painting.dart';

typedef WaterfallStep = ({
  String label,
  int fromCents,
  int toCents,
  Color color,
});

class WaterfallChart extends StatelessWidget {
  const new({required this.steps, required this.semanticsLabel, super.key});

  final List<WaterfallStep> steps;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticsLabel,
      child: CustomPaint(
        size: const Size(double.infinity, 200),
        painter: WaterfallPainter(
          steps: steps,
          lineColor: theme.colorScheme.outlineVariant,
          valueStyle: theme.textTheme.labelSmall!.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          labelStyle: theme.textTheme.labelSmall!.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class WaterfallPainter extends CustomPainter {
  new({
    required this.steps,
    required this.lineColor,
    required this.valueStyle,
    required this.labelStyle,
  });

  final List<WaterfallStep> steps;
  final Color lineColor;
  final TextStyle valueStyle;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 18.0;
    final bottom = size.height - 28;
    final values = ValueScale.fromValues([
      for (final step in steps) ...[step.fromCents, step.toCents],
    ]);
    final bands = BandScale(count: steps.length, start: 0, end: size.width);
    double y(int cents) => values.position(cents, top: top, bottom: bottom);
    canvas.drawLine(
      Offset(0, y(0)),
      Offset(size.width, y(0)),
      Paint()..color = lineColor,
    );
    final width = bands.band * 0.62;
    for (final (index, step) in steps.indexed) {
      final center = bands.center(index);
      final high = y(
        step.fromCents > step.toCents ? step.fromCents : step.toCents,
      );
      final low = y(
        step.fromCents > step.toCents ? step.toCents : step.fromCents,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            center - width / 2,
            high,
            center + width / 2,
            low - high < 2 ? high + 2 : low,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = step.color,
      );
      paintLabel(
        canvas,
        step.fromCents == 0
            ? Money.compact(step.toCents)
            : Money.compact((step.toCents - step.fromCents).abs()),
        Offset(center, high - 9),
        style: valueStyle,
      );
      paintLabel(
        canvas,
        step.label,
        Offset(center, size.height - 12),
        style: labelStyle,
      );
    }
  }

  @override
  bool shouldRepaint(WaterfallPainter oldDelegate) =>
      oldDelegate.steps != steps || oldDelegate.lineColor != lineColor;
}
