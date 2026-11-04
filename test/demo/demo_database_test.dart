import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/demo/demo_database.dart';

void main() {
  late DemoDatabase database;
  late String salary;
  late String rent;
  late String groceries;

  setUp(() {
    database = DemoDatabase(today: DateTime(2026, 12, 31, 18));
    salary = database.addCategory(kind: 'income', key: 'salary', name: 'S');
    rent = database.addCategory(
      kind: 'expense',
      key: 'housing',
      name: 'H',
      defaultNature: 'fixed',
    );
    groceries = database.addCategory(
      kind: 'expense',
      key: 'groceries',
      name: 'G',
      defaultNature: 'variable',
    );
  });

  Row entry(String category, int cents, String dueOn, [Row extra = const {}]) =>
      database.createEntry({
        'category_id': category,
        'description': 'Entry',
        'amount_cents': cents,
        'due_on': dueOn,
        ...extra,
      });

  FieldErrors errorsOf(void Function() action) {
    try {
      action();
    } on DemoValidationError catch (error) {
      return error.details;
    }
    fail('expected a validation error');
  }

  test('lists categories by kind with their positions', () {
    expect(database.categoriesOf('expense').map((row) => row['position']), [
      0,
      1,
    ]);
    expect(database.categoriesOf(null), hasLength(3));
  });

  group('balances', () {
    test('creates, sorts, updates and deletes', () {
      final older = database.createBalance({
        'amount_cents': 100,
        'as_of': '2026-10-01',
      });
      final newer = database.createBalance({
        'amount_cents': -50,
        'as_of': '2026-11-01',
      });

      expect(database.sortedBalances(), [newer, older]);
      expect(database.latestBalance(), newer);

      database.updateBalance(older['id']! as String, {'amount_cents': 200});
      expect(database.findBalance(older['id']! as String)['amount_cents'], 200);

      database.deleteBalance(newer['id']! as String);
      expect(database.sortedBalances(), [older]);
      expect(
        () => database.findBalance('missing'),
        throwsA(isA<DemoNotFound>()),
      );
    });

    test('validates the amount and the date', () {
      database.createBalance({'amount_cents': 1, 'as_of': '2026-11-01'});

      expect(errorsOf(() => database.createBalance({'as_of': 'x'})), {
        'amount_cents': ['not_an_integer'],
        'as_of': ['blank'],
      });
      expect(
        errorsOf(
          () => database.createBalance({
            'amount_cents': 1,
            'as_of': '2027-01-01',
          }),
        ),
        {
          'as_of': ['in_future'],
        },
      );
      expect(
        errorsOf(
          () => database.createBalance({
            'amount_cents': 1,
            'as_of': '2026-11-01',
          }),
        ),
        {
          'as_of': ['taken'],
        },
      );
    });
  });

  group('entries', () {
    test('take the kind and default nature from the category', () {
      expect(entry(salary, 100, '2026-11-05'), containsPair('kind', 'income'));
      expect(entry(salary, 100, '2026-11-05')['nature'], isNull);
      expect(entry(rent, 100, '2026-11-05')['nature'], 'fixed');
      expect(
        entry(groceries, 100, '2026-11-05', {'nature': 'fixed'})['nature'],
        'fixed',
      );
    });

    test('filter by period, kind and nature, ordered by due date', () {
      final late = entry(rent, 100, '2026-11-20');
      final early = entry(groceries, 100, '2026-11-02');
      final income = entry(salary, 100, '2026-11-05');
      entry(rent, 100, '2026-12-01');

      expect(
        database.filteredEntries(
          from: DateTime(2026, 11),
          to: DateTime(2026, 11, 30),
        ),
        [early, income, late],
      );
      expect(database.filteredEntries(kind: 'income'), [income]);
      expect(database.filteredEntries(nature: 'variable'), [early]);
    });

    test('update keeps the chosen nature when the category changes', () {
      final id =
          entry(groceries, 100, '2026-11-05', {'nature': 'fixed'})['id']!
              as String;

      database.updateEntry(id, {'category_id': rent});
      expect(database.findEntry(id)['nature'], 'fixed');

      database.updateEntry(id, {
        'category_id': groceries,
        'nature': 'variable',
      });
      expect(database.findEntry(id)['nature'], 'variable');

      database.updateEntry(id, {'status': 'paid', 'paid_on': '2026-11-05'});
      expect(database.findEntry(id)['paid_on'], '2026-11-05');

      database.deleteEntry(id);
      expect(() => database.findEntry(id), throwsA(isA<DemoNotFound>()));
    });

    test('validate every field', () {
      expect(errorsOf(() => database.createEntry({'paid_on': '2026-11-01'})), {
        'category': ['required'],
        'description': ['blank'],
        'amount_cents': ['greater_than'],
        'due_on': ['blank'],
        'paid_on': ['only_when_paid'],
      });
      expect(
        errorsOf(
          () => entry(salary, 1, '2026-11-01', {
            'description': 'x' * 201,
            'status': 'late',
            'nature': 'fixed',
          }),
        ),
        {
          'description': ['too_long'],
          'status': ['inclusion'],
          'nature': ['only_for_expenses'],
        },
      );
      expect(
        errorsOf(() => entry(rent, 1, '2026-11-01', {'nature': 'sometimes'})),
        {
          'nature': ['inclusion'],
        },
      );
    });
  });

  group('series', () {
    Row series(
      String dueOn,
      int count,
      String direction, [
      Row extra = const {},
    ]) => database.createSeries({
      'category_id': salary,
      'description': 'Salary',
      'amount_cents': 100,
      'due_on': dueOn,
      'entries_count': count,
      'direction': direction,
      ...extra,
    });

    List<Object?> fieldOf(Row created, String field) => [
      for (final row in created['entries']! as List<Row>) row[field],
    ];

    test('create one entry per month in position order', () {
      final created = series('2026-11-05', 3, 'forward');

      expect(created, containsPair('kind', 'recurring'));
      expect(created, containsPair('entries_count', 3));
      expect(fieldOf(created, 'due_on'), [
        '2026-11-05',
        '2026-12-05',
        '2027-01-05',
      ]);
      expect(fieldOf(created, 'series_position'), [1, 2, 3]);
      expect(fieldOf(created, 'series_id').toSet(), {created['id']});
      expect(database.series, hasLength(1));
      expect(database.entries, hasLength(3));
    });

    test('go backwards and keep the day at the end of short months', () {
      expect(fieldOf(series('2026-03-31', 3, 'backward'), 'due_on'), [
        '2026-01-31',
        '2026-02-28',
        '2026-03-31',
      ]);
    });

    test('pay the copies due up to today and leave the later ones pending', () {
      final created = series('2026-11-05', 3, 'forward', {
        'status': 'paid',
        'paid_on': '2026-11-06',
      });

      expect(fieldOf(created, 'status'), ['paid', 'paid', 'pending']);
      expect(fieldOf(created, 'paid_on'), ['2026-11-06', '2026-12-05', null]);
      expect(fieldOf(series('2026-12-05', 2, 'backward'), 'status'), [
        'pending',
        'pending',
      ]);
    });

    test('validate the count, the direction and the entry together', () {
      expect(
        errorsOf(() => series('2026-11-05', 1, 'up', {'amount_cents': 0})),
        {
          'entries_count': ['greater_than_or_equal_to'],
          'direction': ['inclusion'],
          'amount_cents': ['greater_than'],
        },
      );
      expect(errorsOf(() => series('2026-11-05', 37, 'forward')), {
        'entries_count': ['less_than_or_equal_to'],
      });
      expect(
        errorsOf(
          () => database.createSeries({
            'category_id': salary,
            'description': 'Salary',
            'amount_cents': 100,
            'due_on': '2026-11-05',
            'direction': 'forward',
          }),
        ),
        {
          'entries_count': ['not_a_number'],
        },
      );
      expect(database.entries, isEmpty);
    });
  });

  group('projection', () {
    setUp(() {
      entry(salary, 20000, '2026-10-15');
      entry(salary, 50000, '2026-11-05');
      entry(rent, 30000, '2026-11-20');
      entry(groceries, 10000, '2026-12-05');
    });

    List<List<Object?>> closings(DateTime from, int months) => [
      for (final row in database.projection(from: from, months: months))
        [row['month'], row['opening_cents'], row['closing_cents']],
    ];

    test('starts from zero without a balance', () {
      expect(closings(DateTime(2026, 11), 2), [
        ['2026-11', 0, 20000],
        ['2026-12', 20000, 10000],
      ]);
    });

    test('works backwards before the anchor and forwards after it', () {
      database
        ..createBalance({'amount_cents': 1000, 'as_of': '2026-09-01'})
        ..createBalance({'amount_cents': 100000, 'as_of': '2026-11-10'});

      expect(closings(DateTime(2026, 10), 3), [
        ['2026-10', 30000, 50000],
        ['2026-11', 50000, 70000],
        ['2026-12', 70000, 60000],
      ]);
      expect(closings(DateTime(2026, 12, 20), 2), [
        ['2026-12', 70000, 60000],
        ['2027-01', 60000, 60000],
      ]);
    });

    test('splits income and fixed and variable expenses', () {
      final [november, december] = database.projection(
        from: DateTime(2026, 11),
        months: 2,
      );

      expect(november, containsPair('savings_cents', 20000));
      expect(december, containsPair('savings_cents', 10000));
      expect(november, containsPair('fixed_expense_cents', 30000));
      expect(november, containsPair('income_cents', 50000));
      expect(december, containsPair('variable_expense_cents', 10000));
      expect(december, containsPair('expense_cents', 10000));
    });
  });
}
