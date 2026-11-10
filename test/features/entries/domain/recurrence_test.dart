import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';

void main() {
  test('repeats monthly by default', () {
    const recurrence = Recurrence(
      count: 3,
      direction: RecurrenceDirection.forward,
    );

    expect(recurrence.interval, RecurrenceInterval.monthly);
    expect(recurrence.dueDates(DateTime(2027, 1, 31)), [
      DateTime(2027, 1, 31),
      DateTime(2027, 2, 28),
      DateTime(2027, 3, 31),
    ]);
  });

  test('lists the due dates of fixed months in date order', () {
    const recurrence = Recurrence(
      count: 3,
      direction: RecurrenceDirection.backward,
      interval: RecurrenceInterval.semiannual,
    );

    expect(recurrence.dueDates(DateTime(2026, 9, 15)), [
      DateTime(2025, 9, 15),
      DateTime(2026, 3, 15),
      DateTime(2026, 9, 15),
    ]);
  });

  test('maps each interval to its months', () {
    expect(
      [for (final interval in RecurrenceInterval.values) interval.months],
      [1, 3, 6, 12],
    );
  });
}
