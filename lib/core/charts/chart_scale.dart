import 'dart:math' as math;

class ValueScale {
  factory fromValues(Iterable<int> values, {int tickCount = 4}) {
    final all = [0, ...values];
    final low = all.reduce(math.min);
    final high = all.reduce(math.max);
    final step = niceStep(high - low, tickCount: tickCount);
    final min = (low / step).floor() * step;
    final max = (high / step).ceil() * step;
    return ValueScale._(
      min: min,
      max: max == min ? min + step : max,
      step: step,
    );
  }

  const new _({required this.min, required this.max, required this.step});

  static const fallbackStep = 10000;

  final int min;
  final int max;
  final int step;

  static int niceStep(int range, {int tickCount = 4}) {
    if (range <= 0) {
      return fallbackStep;
    }
    final raw = range / tickCount;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toInt();
    final normalized = raw / magnitude;
    final factor = switch (normalized) {
      <= 1 => 1,
      <= 2 => 2,
      <= 5 => 5,
      _ => 10,
    };
    return factor * magnitude;
  }

  List<int> get ticks => [for (var tick = min; tick <= max; tick += step) tick];

  double fraction(int value) => (value - min) / (max - min);

  double position(int value, {required double top, required double bottom}) =>
      bottom - fraction(value) * (bottom - top);
}

class BandScale {
  const new({required this.count, required this.start, required this.end});

  final int count;
  final double start;
  final double end;

  double get band => (end - start) / count;

  double center(int index) => start + band * index + band / 2;

  int indexAt(double x) => ((x - start) / band).floor().clamp(0, count - 1);

  List<int> labelIndexes({int maxLabels = 8}) {
    final every = (count / maxLabels).ceil();
    return [
      for (var index = 0; index < count; index++)
        if (index % every == 0) index,
    ];
  }
}
