import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/charts/smooth_path.dart';

void main() {
  group('smoothPath', () {
    test('is empty without points', () {
      expect(smoothPath([]).getBounds(), Rect.zero);
    });

    test('only moves to a single point', () {
      expect(
        smoothPath([const Offset(3, 4)]).computeMetrics().toList(),
        isEmpty,
      );
    });

    test('passes through every point without overshooting', () {
      const points = [
        Offset(0, 50),
        Offset(10, 10),
        Offset(20, 90),
        Offset(30, 85),
        Offset(40, 80),
      ];
      final path = smoothPath(points);
      final bounds = path.getBounds();
      expect(bounds.top, closeTo(10, 0.01));
      expect(bounds.bottom, closeTo(90, 0.01));
      for (final point in points) {
        final metric = path.computeMetrics().single;
        final hit = [
          for (var d = 0.0; d <= metric.length; d += 0.05)
            metric.getTangentForOffset(d)!.position,
        ].any((sample) => (sample - point).distance < 0.5);
        expect(hit, isTrue, reason: '$point');
      }
    });
  });

  test('dashedLine splits a line into dashes', () {
    final dashes = dashedLine(
      Offset.zero,
      const Offset(20, 0),
    ).computeMetrics().toList();
    expect(dashes, hasLength(3));
    expect(dashes.last.length, 4);
  });
}
