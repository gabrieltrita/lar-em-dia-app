import 'dart:ui';

Path smoothPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) {
    return path;
  }
  path.moveTo(points.first.dx, points.first.dy);
  if (points.length == 1) {
    return path;
  }
  final slopes = [
    for (var i = 0; i < points.length - 1; i++)
      (points[i + 1].dy - points[i].dy) / (points[i + 1].dx - points[i].dx),
  ];
  final tangents = [
    slopes.first,
    for (var i = 1; i < slopes.length; i++)
      if (slopes[i - 1] * slopes[i] <= 0)
        0.0
      else
        2 * slopes[i - 1] * slopes[i] / (slopes[i - 1] + slopes[i]),
    slopes.last,
  ];
  for (var i = 0; i < points.length - 1; i++) {
    final start = points[i];
    final end = points[i + 1];
    final third = (end.dx - start.dx) / 3;
    path.cubicTo(
      start.dx + third,
      start.dy + tangents[i] * third,
      end.dx - third,
      end.dy - tangents[i + 1] * third,
      end.dx,
      end.dy,
    );
  }
  return path;
}

Path dashedLine(Offset start, Offset end, {double dash = 4, double gap = 4}) {
  final path = Path();
  final length = (end - start).distance;
  final direction = (end - start) / length;
  for (var position = 0.0; position < length; position += dash + gap) {
    final from = start + direction * position;
    final to = start + direction * (position + dash).clamp(0, length);
    path
      ..moveTo(from.dx, from.dy)
      ..lineTo(to.dx, to.dy);
  }
  return path;
}
