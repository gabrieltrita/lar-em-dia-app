import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/cubits/entry_cubits.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/finance_fixtures.dart';

void main() {
  const recurrence = Recurrence(
    count: 2,
    direction: RecurrenceDirection.backward,
  );

  late MockEntryRepository repository;

  const failure = ApiError(code: 'network_error');
  final october = DateTime(2026, 10);

  setUpAll(registerFinanceFallbacks);
  setUp(() {
    repository = MockEntryRepository();
    when(() => repository.categories(EntryKind.income))
        .thenAnswer((_) async => [salaryCategory, rentCategory]);
    when(() => repository.categories(EntryKind.expense))
        .thenAnswer((_) async => [housingCategory, groceriesCategory]);
    when(() => repository.month(any()))
        .thenAnswer((_) async => [salary, rent, housing, groceries]);
  });

  MonthEntries loaded() => MonthEntries(
    entries: [salary, rent, housing, groceries],
    categories: {
      for (final category in [
        salaryCategory,
        rentCategory,
        housingCategory,
        groceriesCategory,
      ])
        category.id: category,
    },
  );

  test('MonthEntries filters and sums by kind and nature', () {
    final month = loaded();

    expect(month.filtered(), month.entries);
    expect(month.filtered(kind: EntryKind.income), [salary, rent]);
    expect(month.filtered(kind: EntryKind.expense, nature: EntryNature.fixed), [
      housing,
    ]);
    expect(month.totalCents(kind: EntryKind.income), 650000);
    expect(month.totalCents(kind: EntryKind.expense), 280000);
    expect(month.resultCents, 370000);
  });

  test('starts on the current month', () {
    final cubit = MonthEntriesCubit(repository);
    expect(cubit.state.month.day, 1);
    expect(cubit.state.month.month, DateTime.now().month);
  });

  blocTest<MonthEntriesCubit, MonthEntriesState>(
    'loads a month with the categories of both kinds',
    build: () => MonthEntriesCubit(repository),
    act: (cubit) => cubit.load(month: DateTime(2026, 11, 20)),
    expect: () => [
      MonthEntriesState(
        month: november,
        data: const LoadState<MonthEntries>.loading(),
      ),
      MonthEntriesState(month: november, data: LoadState.loaded(loaded())),
    ],
  );

  blocTest<MonthEntriesCubit, MonthEntriesState>(
    'reloads quietly without showing the loading state',
    build: () => MonthEntriesCubit(repository),
    seed: () =>
        MonthEntriesState(month: november, data: LoadState.loaded(loaded())),
    act: (cubit) => cubit.load(quiet: true),
    expect: () => <MonthEntriesState>[],
    verify: (_) => verify(() => repository.month(november)).called(1),
  );

  blocTest<MonthEntriesCubit, MonthEntriesState>(
    'filters by kind and keeps the nature only for expenses',
    build: () => MonthEntriesCubit(repository),
    act: (cubit) {
      cubit
        ..filterKind(EntryKind.expense)
        ..filterNature(EntryNature.fixed);
      expect(cubit.state.nature, EntryNature.fixed);
      cubit.filterKind(EntryKind.expense);
      expect(cubit.state.nature, EntryNature.fixed);
      cubit.filterKind(null);
    },
    verify: (cubit) {
      expect(cubit.state.kind, isNull);
      expect(cubit.state.nature, isNull);
    },
  );

  blocTest<MonthEntriesCubit, MonthEntriesState>(
    'moves to the previous and the next month',
    build: () => MonthEntriesCubit(repository),
    seed: () => MonthEntriesState(
      month: november,
      data: const LoadState<MonthEntries>.loading(),
    ),
    act: (cubit) async {
      await cubit.previous();
      await cubit.next();
    },
    verify: (cubit) {
      expect(cubit.state.month, november);
      verify(() => repository.month(october)).called(1);
      verify(() => repository.month(november)).called(1);
    },
  );

  blocTest<MonthEntriesCubit, MonthEntriesState>(
    'ignores a month that is no longer selected',
    build: () => MonthEntriesCubit(repository),
    act: (cubit) async {
      final first = cubit.load(month: october);
      await cubit.load(month: november);
      await first;
    },
    verify: (cubit) {
      expect(cubit.state.month, november);
      expect(cubit.state.data, LoadState.loaded(loaded()));
    },
  );

  blocTest<MonthEntriesCubit, MonthEntriesState>(
    'reports a failed load',
    setUp: () => when(() => repository.month(any())).thenThrow(failure),
    build: () => MonthEntriesCubit(repository),
    act: (cubit) => cubit.load(month: november),
    skip: 1,
    expect: () => [
      MonthEntriesState(
        month: november,
        data: const LoadState<MonthEntries>.failure(failure),
      ),
    ],
  );

  test('delete reloads on success and returns the error otherwise', () async {
    when(() => repository.delete('entry-1')).thenAnswer((_) async {});
    final cubit = MonthEntriesCubit(repository);
    await cubit.load(month: november);

    expect(await cubit.delete(salary), isNull);
    verify(() => repository.month(november)).called(2);

    when(() => repository.delete('entry-1')).thenThrow(failure);
    expect(await cubit.delete(salary), failure);
    await cubit.close();
  });

  test('delete sends the scope of a series entry', () async {
    when(() => repository.delete('entry-1', scope: EntryScope.following))
        .thenAnswer((_) async {});
    final cubit = MonthEntriesCubit(repository);

    expect(await cubit.delete(salary, scope: EntryScope.following), isNull);
    verify(() => repository.delete('entry-1', scope: EntryScope.following))
        .called(1);
    await cubit.close();
  });

  group('setPaid', () {
    final today = Dates.dateOnly(DateTime.now());
    final paidRent = rent.copyWith(status: EntryStatus.paid, paidOn: today);

    test('replaces the entry in the list', () async {
      when(() => repository.markPaid(rent.id, paidOn: today))
          .thenAnswer((_) async => paidRent);
      final cubit = MonthEntriesCubit(repository);
      await cubit.load(month: november);

      expect(await cubit.setPaid(rent, paid: true), isNull);

      final data = cubit.state.data as Loaded<MonthEntries>;
      expect(data.value.entries, [salary, paidRent, housing, groceries]);
      verify(() => repository.month(november)).called(1);
      await cubit.close();
    });

    test('sends pending without a date and keeps an unloaded list', () async {
      when(() => repository.markPaid(salary.id, paidOn: null))
          .thenAnswer((_) async => salary);
      when(() => repository.month(any())).thenThrow(failure);
      final cubit = MonthEntriesCubit(repository);
      await cubit.load(month: november);

      expect(await cubit.setPaid(salary, paid: false), isNull);
      expect(cubit.state.data, const LoadState<MonthEntries>.failure(failure));
      await cubit.close();
    });

    test('returns the error', () async {
      when(() => repository.markPaid(any(), paidOn: any(named: 'paidOn')))
          .thenThrow(failure);
      final cubit = MonthEntriesCubit(repository);

      expect(await cubit.setPaid(rent, paid: true), failure);
      await cubit.close();
    });
  });

  group('DueCubit', () {
    final today = DateTime(2026, 11, 26);
    final overdue = housing.copyWith(id: 'late', dueOn: DateTime(2026, 11, 20));
    final soon = housing.copyWith(id: 'soon', dueOn: DateTime(2026, 11, 28));
    final nextMonth = housing.copyWith(
      id: 'next',
      dueOn: DateTime(2026, 12, 2),
    );
    final paid = groceries.copyWith(dueOn: DateTime(2026, 11, 27));

    setUp(
      () =>
          when(() => repository.between(any(), any(), kind: EntryKind.expense))
              .thenAnswer((_) async => [overdue, soon, nextMonth, paid]),
    );

    blocTest<DueCubit, LoadState<DueEntries>>(
      'groups the pending expenses from three months back',
      build: () => DueCubit(repository),
      act: (cubit) => cubit.load(today: today),
      skip: 1,
      verify: (cubit) {
        final due = (cubit.state as Loaded<DueEntries>).value;
        expect(due.overdue, [overdue]);
        expect(due.thisWeek, [soon, nextMonth]);
        expect(due.later, isEmpty);
        expect(due.categories.keys, [housingCategory.id, groceriesCategory.id]);
        verify(
          () => repository.between(
            DateTime(2026, 8),
            DateTime(2026, 12, 2),
            kind: EntryKind.expense,
          ),
        ).called(1);
      },
    );

    blocTest<DueCubit, LoadState<DueEntries>>(
      'reaches the end of the month when the week ends first',
      build: () => DueCubit(repository),
      act: (cubit) => cubit.load(today: DateTime(2026, 11, 3), quiet: true),
      verify: (cubit) {
        final due = (cubit.state as Loaded<DueEntries>).value;
        expect(due.overdue, isEmpty);
        expect(due.later, [overdue, soon, nextMonth]);
        verify(
          () => repository.between(
            DateTime(2026, 8),
            DateTime(2026, 11, 30),
            kind: EntryKind.expense,
          ),
        ).called(1);
      },
    );

    blocTest<DueCubit, LoadState<DueEntries>>(
      'reports a failed load',
      setUp: () =>
          when(() => repository.between(any(), any(), kind: EntryKind.expense))
              .thenThrow(failure),
      build: () => DueCubit(repository),
      act: (cubit) => cubit.load(today: today),
      expect: () => const [
        LoadState<DueEntries>.loading(),
        LoadState<DueEntries>.failure(failure),
      ],
    );

    test('marks as paid and drops the entry, or returns the error', () async {
      when(() => repository.markPaid(soon.id, paidOn: today))
          .thenAnswer((_) async => soon);
      final cubit = DueCubit(repository);
      expect(await cubit.markPaid(soon, today: today), isNull);
      await cubit.load(today: today);

      expect(await cubit.markPaid(soon, today: today), isNull);
      expect((cubit.state as Loaded<DueEntries>).value.entries, [
        overdue,
        nextMonth,
      ]);

      when(() => repository.markPaid(any(), paidOn: any(named: 'paidOn')))
          .thenThrow(failure);
      expect(await cubit.markPaid(soon), failure);
      await cubit.close();
    });
  });

  blocTest<CategoriesCubit, LoadState<List<Category>>>(
    'loads the categories',
    build: () => CategoriesCubit(repository),
    act: (cubit) => cubit.load(EntryKind.income),
    expect: () => [
      const LoadState<List<Category>>.loading(),
      const LoadState.loaded([salaryCategory, rentCategory]),
    ],
  );

  blocTest<CategoriesCubit, LoadState<List<Category>>>(
    'reports failed categories',
    setUp: () =>
        when(() => repository.categories(EntryKind.income)).thenThrow(failure),
    build: () => CategoriesCubit(repository),
    act: (cubit) => cubit.load(EntryKind.income),
    expect: () => const [
      LoadState<List<Category>>.loading(),
      LoadState<List<Category>>.failure(failure),
    ],
  );

  blocTest<EntryFormCubit, Submission<Entry>>(
    'creates a new entry',
    setUp: () =>
        when(() => repository.create(salary.toDraft()))
            .thenAnswer((_) async => salary),
    build: () => EntryFormCubit(repository),
    act: (cubit) => cubit.save(salary.toDraft()),
    expect: () => [
      const Submission<Entry>.inProgress(),
      Submission.success(salary),
    ],
  );

  blocTest<EntryFormCubit, Submission<Entry>>(
    'creates a series and succeeds with the entry on the chosen date',
    setUp: () =>
        when(() => repository.createSeries(salary.toDraft(), recurrence))
            .thenAnswer(
              (_) async => [
                salary.copyWith(id: 'entry-0', dueOn: DateTime(2026, 10, 5)),
                salary,
              ],
            ),
    build: () => EntryFormCubit(repository),
    act: (cubit) => cubit.save(salary.toDraft(), recurrence: recurrence),
    expect: () => [
      const Submission<Entry>.inProgress(),
      Submission.success(salary),
    ],
  );

  blocTest<EntryFormCubit, Submission<Entry>>(
    'creates installments and succeeds with the first one',
    setUp: () =>
        when(
          () => repository.createInstallments(
            salary.toDraft(),
            const Installments(count: 2),
          ),
        ).thenAnswer(
          (_) async => [
            salary,
            salary.copyWith(id: 'entry-9', dueOn: DateTime(2026, 12, 5)),
          ],
        ),
    build: () => EntryFormCubit(repository),
    act: (cubit) => cubit.save(
      salary.toDraft(),
      installments: const Installments(count: 2),
    ),
    expect: () => [
      const Submission<Entry>.inProgress(),
      Submission.success(salary),
    ],
  );

  blocTest<EntryFormCubit, Submission<Entry>>(
    'updates an existing entry',
    setUp: () =>
        when(() => repository.update('entry-1', salary.toDraft()))
            .thenAnswer((_) async => salary),
    build: () => EntryFormCubit(repository),
    act: (cubit) => cubit.save(salary.toDraft(), existing: salary),
    expect: () => [
      const Submission<Entry>.inProgress(),
      Submission.success(salary),
    ],
  );

  blocTest<EntryFormCubit, Submission<Entry>>(
    'updates the entries of a series in the chosen scope',
    setUp: () => when(
      () =>
          repository.update('entry-1', salary.toDraft(), scope: EntryScope.all),
    ).thenAnswer((_) async => salary),
    build: () => EntryFormCubit(repository),
    act: (cubit) =>
        cubit.save(salary.toDraft(), existing: salary, scope: EntryScope.all),
    expect: () => [
      const Submission<Entry>.inProgress(),
      Submission.success(salary),
    ],
  );
}
