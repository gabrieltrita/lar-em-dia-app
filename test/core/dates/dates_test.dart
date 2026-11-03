import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/dates/dates.dart';

void main() {
  test('converts dates to and from ISO strings', () {
    expect(Dates.toIso(DateTime(2026, 3, 7, 15, 30)), '2026-03-07');
    expect(Dates.parseIso('2026-03-07'), DateTime(2026, 3, 7));
    expect(Dates.dateOnly(DateTime(2026, 3, 7, 23, 59)), DateTime(2026, 3, 7));
  });

  test('formats dates for display', () {
    expect(Dates.display(DateTime(2026, 3, 7)), '07/03/2026');
  });

  test('computes month boundaries and moves across years', () {
    expect(Dates.firstOfMonth(DateTime(2026, 2, 20)), DateTime(2026, 2));
    expect(Dates.lastOfMonth(DateTime(2028, 2, 3)), DateTime(2028, 2, 29));
    expect(Dates.addMonths(DateTime(2026, 12), 1), DateTime(2027));
    expect(Dates.addMonths(DateTime(2026), -1), DateTime(2025, 12));
  });

  test('reads month parameters', () {
    expect(Dates.parseMonth('2026-04'), DateTime(2026, 4));
    expect(Dates.parseMonth('2026-13'), isNull);
    expect(Dates.parseMonth('2026-00'), isNull);
    expect(Dates.parseMonth('april'), isNull);
    expect(Dates.parseMonth(null), isNull);
  });
}
