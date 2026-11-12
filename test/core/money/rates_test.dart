import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/money/rates.dart';

void main() {
  test('formats basis points without trailing zeros', () {
    expect(Rates.percentFromBps(11000), '110%');
    expect(Rates.percentFromBps(10000), '100%');
    expect(Rates.percentFromBps(1250), '12,5%');
    expect(Rates.percentFromBps(1375), '13,75%');
    expect(Rates.percentFromBps(50), '0,5%');
  });

  test('formats e8 fractions as a percentage', () {
    expect(Rates.percentFromE8(13750000), '13,75%');
    expect(Rates.percentFromE8(13650000), '13,65%');
    expect(Rates.percentFromE8(500000), '0,5%');
  });

  test('formats coverage months with one decimal', () {
    expect(Rates.months(448), '4,5');
    expect(Rates.months(420), '4,2');
    expect(Rates.months(600), '6');
    expect(Rates.months(0), '0');
  });
}
