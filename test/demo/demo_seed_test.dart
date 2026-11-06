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

    final salaries = database
        .filteredEntries(kind: 'income')
        .where((entry) => entry['description'] == 'Salário');
    expect(salaries, hasLength(DemoSeed.months));
    expect(salaries.map((entry) => entry['series_id']).toSet(), hasLength(1));
    expect(database.series, hasLength(9));

    final fridge = database
        .filteredEntries(kind: 'expense')
        .where((entry) => entry['description'] == 'Geladeira nova')
        .toList();
    expect(fridge, hasLength(DemoSeed.fridgeInstallments));
    expect(fridge.map((entry) => entry['amount_cents']).toSet(), {
      DemoSeed.fridgeCents ~/ DemoSeed.fridgeInstallments,
    });
    expect(fridge.first, containsPair('series_kind', 'installments'));
    expect(months[2]['negative'], isTrue);
    expect(months[0]['negative'], isFalse);

    final course = database
        .filteredEntries(kind: 'expense')
        .where((entry) => entry['description'] == 'Curso de inglês');
    expect(course, hasLength(DemoSeed.courseInstallments));
    expect(database.lastEntryMonth(), DateTime(2028, 10));
  });

  test('places the 13th salary in December wherever the year starts', () {
    final database = DemoSeed.build(DateTime(2027, 3, 10));

    final thirteenth = database
        .filteredEntries(kind: 'income')
        .where((entry) => entry['description'] == '13º salário');
    expect(thirteenth.map((entry) => entry['due_on']), [
      '2027-12-18',
      '2028-12-18',
    ]);
  });
}
