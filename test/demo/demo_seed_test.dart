import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/demo/demo_seed.dart';

void main() {
  test('builds a family with a year of entries and one negative month', () {
    final database = DemoSeed.build(DateTime(2026, 11, 3));

    expect(database.categoriesOf('income'), hasLength(10));
    expect(database.categoriesOf('expense'), hasLength(20));
    expect(database.latestBalance(), containsPair('as_of', '2026-11-01'));

    final months = database.projection(from: DateTime(2026, 11), months: 12);
    final closings = [for (final m in months) m['closing_cents']! as int];
    expect(closings[2], -DemoSeed.tripShortfallCents);
    expect(closings.where((cents) => cents < 0), isNotEmpty);
    expect(
      months[1]['income_cents'],
      greaterThan(months[0]['income_cents']! as int),
    );

    final november = database.filteredEntries(
      from: DateTime(2026, 11),
      to: DateTime(2026, 11, 30),
    );
    expect(
      november
          .where((entry) => entry['status'] == 'paid')
          .map((e) => e['due_on']),
      everyElement(lessThanOrEqualTo('2026-11-03')),
    );
    expect(november.any((entry) => entry['status'] == 'pending'), isTrue);
  });

  test('places the 13th salary in December wherever the year starts', () {
    final database = DemoSeed.build(DateTime(2027, 3, 10));

    final thirteenth = database
        .filteredEntries(kind: 'income')
        .where((entry) => entry['description'] == '13º salário');
    expect(thirteenth.single['due_on'], '2027-12-18');
  });
}
