import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/charts/chart_scale.dart';

void main() {
  group('ValueScale', () {
    test('rounds the range to nice steps that include zero', () {
      final scale = ValueScale.fromValues([120000, 370000]);

      expect(scale.min, 0);
      expect(scale.max, 400000);
      expect(scale.step, 100000);
      expect(scale.ticks, [0, 100000, 200000, 300000, 400000]);
    });

    test('spans negative and positive values', () {
      final scale = ValueScale.fromValues([-106544, 370000]);

      expect(scale.min, -200000);
      expect(scale.max, 400000);
      expect(scale.ticks.first, -200000);
      expect(scale.fraction(0), closeTo(1 / 3, 1e-9));
      expect(scale.position(0, top: 0, bottom: 300), closeTo(200, 1e-9));
      expect(scale.position(400000, top: 10, bottom: 310), 10);
    });

    test('falls back to a default step without a range', () {
      final scale = ValueScale.fromValues([]);

      expect(scale.min, 0);
      expect(scale.max, ValueScale.fallbackStep);
      expect(ValueScale.niceStep(0), ValueScale.fallbackStep);
    });

    test('keeps a range when every value sits on a step', () {
      final scale = ValueScale.fromValues([0, 0]);

      expect(scale.max, greaterThan(scale.min));
    });

    test('picks steps of one, two, five or ten', () {
      expect(ValueScale.niceStep(400), 100);
      expect(ValueScale.niceStep(800), 200);
      expect(ValueScale.niceStep(1600), 500);
      expect(ValueScale.niceStep(2400), 1000);
      expect(ValueScale.niceStep(30, tickCount: 3), 10);
    });
  });

  group('BandScale', () {
    const scale = BandScale(count: 12, start: 40, end: 280);

    test('splits the width into one band per item', () {
      expect(scale.band, 20);
      expect(scale.center(0), 50);
      expect(scale.center(11), 270);
    });

    test('finds the item under a point, clamped to the ends', () {
      expect(scale.indexAt(65), 1);
      expect(scale.indexAt(0), 0);
      expect(scale.indexAt(1000), 11);
    });

    test('spaces the labels to fit', () {
      expect(scale.labelIndexes(), [0, 2, 4, 6, 8, 10]);
      expect(scale.labelIndexes(maxLabels: 12), hasLength(12));
    });
  });
}
