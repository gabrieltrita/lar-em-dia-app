import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/cubits/entry_cubits.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/finance_fixtures.dart';

void main() {
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
}
