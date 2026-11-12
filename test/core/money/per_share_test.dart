import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/money/per_share.dart';

void main() {
  test('formats per-share values with two to four decimals', () {
    expect(PerShare.formatE8(15050000000), r'R$ 150,50');
    expect(PerShare.formatE8(1234567890), r'R$ 12,3457');
    expect(PerShare.formatE8(123412000000), r'R$ 1.234,12');
    expect(PerShare.formatE8(98765000), r'R$ 0,9877');
    expect(PerShare.formatE8(10000), r'R$ 0,0001');
    expect(PerShare.formatE8(0), r'R$ 0,00');
    expect(PerShare.formatE8(-250000000), r'-R$ 2,50');
  });

  test('computes basis points rounded half away from zero', () {
    expect(PerShare.basisPoints(9500, 150500), 631);
    expect(PerShare.basisPoints(-500, 260500), -19);
    expect(PerShare.basisPoints(1, 20000), 1);
    expect(PerShare.basisPoints(5, 0), isNull);
  });

  test('formats basis points as a percentage', () {
    expect(PerShare.percentFromBps(631), '6,31%');
    expect(PerShare.percentFromBps(631, signed: true), '+6,31%');
    expect(PerShare.percentFromBps(-1905, signed: true), '−19,05%');
    expect(PerShare.percentFromBps(0, signed: true), '0,00%');
  });

  test('rounds integer divisions half away from zero', () {
    expect(PerShare.roundedDivision(5, 2), 3);
    expect(PerShare.roundedDivision(-5, 2), -3);
    expect(PerShare.roundedDivision(5, -2), -3);
    expect(PerShare.roundedDivision(4, 3), 1);
  });
}
