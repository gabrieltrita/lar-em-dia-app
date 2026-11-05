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
    when(() => repository.month(any(), kind: EntryKind.income))
        .thenAnswer((_) async => [salary, rent]);
  });

  MonthEntries loaded() => MonthEntries(
    entries: [salary, rent],
    categories: {
      salaryCategory.id: salaryCategory,
      rentCategory.id: rentCategory,
    },
  );

  test('MonthEntries sums the month', () {
    expect(loaded().totalCents(), 650000);
  });

  test('MonthEntries filters and sums by nature', () {
    final expenses = MonthEntries(
      entries: [housing, groceries],
      categories: const {},
    );

    expect(expenses.withNature(null), [housing, groceries]);
    expect(expenses.withNature(EntryNature.fixed), [housing]);
    expect(expenses.totalCents(EntryNature.variable), 80000);
  });

  blocTest<MonthEntriesCubit, MonthEntriesState>(
    'loads expenses and keeps the nature filter across months',
    setUp: () {
      when(() => repository.categories(EntryKind.expense))
          .thenAnswer((_) async => [housingCategory, groceriesCategory]);
      when(() => repository.month(any(), kind: EntryKind.expense))
          .thenAnswer((_) async => [housing, groceries]);
    },
    build: () => MonthEntriesCubit(repository, EntryKind.expense),
    act: (cubit) async {
      cubit.filter(EntryNature.fixed);
      await cubit.load(november);
    },
    verify: (cubit) {
      expect(cubit.state.nature, EntryNature.fixed);
      expect(
        cubit.state.data,
        LoadState.loaded(
          MonthEntries(
            entries: [housing, groceries],
            categories: {
              housingCategory.id: housingCategory,
              groceriesCategory.id: groceriesCategory,
            },
          ),
        ),
      );
      verify(() => repository.month(november, kind: EntryKind.expense))
          .called(1);
    },
  );

  test('starts on the current month', () {
    final cubit = MonthEntriesCubit(repository, EntryKind.income);
    expect(cubit.state.month.day, 1);
    expect(cubit.state.month.month, DateTime.now().month);
  });

  blocTest<MonthEntriesCubit, MonthEntriesState>(
    'loads a month with its categories',
    build: () => MonthEntriesCubit(repository, EntryKind.income),
    act: (cubit) => cubit.load(DateTime(2026, 11, 20)),
    expect: () => [
      MonthEntriesState(
        month: november,
        data: const LoadState<MonthEntries>.loading(),
      ),
      MonthEntriesState(month: november, data: LoadState.loaded(loaded())),
    ],
  );

  blocTest<MonthEntriesCubit, MonthEntriesState>(
    'moves to the previous and the next month',
    build: () => MonthEntriesCubit(repository, EntryKind.income),
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
      verify(() => repository.month(october, kind: EntryKind.income)).called(1);
      verify(() => repository.month(november, kind: EntryKind.income))
          .called(1);
    },
  );

  blocTest<MonthEntriesCubit, MonthEntriesState>(
    'ignores a month that is no longer selected',
    build: () => MonthEntriesCubit(repository, EntryKind.income),
    act: (cubit) async {
      final first = cubit.load(october);
      await cubit.load(november);
      await first;
    },
    verify: (cubit) {
      expect(cubit.state.month, november);
      expect(cubit.state.data, LoadState.loaded(loaded()));
    },
  );

  blocTest<MonthEntriesCubit, MonthEntriesState>(
    'reports a failed load',
    setUp: () =>
        when(() => repository.month(any(), kind: EntryKind.income))
            .thenThrow(failure),
    build: () => MonthEntriesCubit(repository, EntryKind.income),
    act: (cubit) => cubit.load(november),
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
    final cubit = MonthEntriesCubit(repository, EntryKind.income);
    await cubit.load(november);

    expect(await cubit.delete(salary), isNull);
    verify(() => repository.month(november, kind: EntryKind.income)).called(2);

    when(() => repository.delete('entry-1')).thenThrow(failure);
    expect(await cubit.delete(salary), failure);
    await cubit.close();
  });

  test('delete sends the scope of a series entry', () async {
    when(() => repository.delete('entry-1', scope: EntryScope.following))
        .thenAnswer((_) async {});
    final cubit = MonthEntriesCubit(repository, EntryKind.income);

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
      final cubit = MonthEntriesCubit(repository, EntryKind.income);
      await cubit.load(november);

      expect(await cubit.setPaid(rent, paid: true), isNull);

      final data = cubit.state.data as Loaded<MonthEntries>;
      expect(data.value.entries, [salary, paidRent]);
      verify(() => repository.month(november, kind: EntryKind.income))
          .called(1);
      await cubit.close();
    });

    test('sends pending without a date and keeps an unloaded list', () async {
      when(() => repository.markPaid(salary.id, paidOn: null))
          .thenAnswer((_) async => salary);
      when(() => repository.month(any(), kind: EntryKind.income))
          .thenThrow(failure);
      final cubit = MonthEntriesCubit(repository, EntryKind.income);
      await cubit.load(november);

      expect(await cubit.setPaid(salary, paid: false), isNull);
      expect(cubit.state.data, const LoadState<MonthEntries>.failure(failure));
      await cubit.close();
    });

    test('returns the error', () async {
      when(() => repository.markPaid(any(), paidOn: any(named: 'paidOn')))
          .thenThrow(failure);
      final cubit = MonthEntriesCubit(repository, EntryKind.income);

      expect(await cubit.setPaid(rent, paid: true), failure);
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
