import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/domain/entry_repository.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/domain/projection_repository.dart';

part 'entry_cubits.freezed.dart';

@freezed
abstract class MonthEntries with _$MonthEntries {
  const factory({
    required List<Entry> entries,
    required Map<String, Category> categories,
    int? closingCents,
  }) = _MonthEntries;

  const new _();

  List<Entry> filtered({EntryKind? kind, EntryNature? nature}) => [
    for (final entry in entries)
      if ((kind == null || entry.kind == kind) &&
          (nature == null || entry.nature == nature))
        entry,
  ];

  int totalCents({EntryKind? kind, EntryNature? nature}) => filtered(
    kind: kind,
    nature: nature,
  ).fold(0, (sum, entry) => sum + entry.amountCents);

  int get resultCents =>
      totalCents(kind: EntryKind.income) - totalCents(kind: EntryKind.expense);
}

@freezed
abstract class MonthEntriesState with _$MonthEntriesState {
  const factory({
    required DateTime month,
    required LoadState<MonthEntries> data,
    EntryKind? kind,
    EntryNature? nature,
    @Default(true) bool includeAccumulated,
  }) = _MonthEntriesState;
}

@injectable
class MonthEntriesCubit extends Cubit<MonthEntriesState> {
  new(this._repository, this._projections)
    : super(
        MonthEntriesState(
          month: Dates.firstOfMonth(DateTime.now()),
          data: const LoadState<MonthEntries>.loading(),
        ),
      );

  final EntryRepository _repository;
  final ProjectionRepository _projections;

  Future<void> load({DateTime? month, bool quiet = false}) async {
    final target = Dates.firstOfMonth(month ?? state.month);
    emit(
      quiet
          ? state.copyWith(month: target)
          : state.copyWith(
              month: target,
              data: const LoadState<MonthEntries>.loading(),
            ),
    );
    try {
      final categories = [
        for (final kind in EntryKind.values)
          ...await _repository.categories(kind),
      ];
      final entries = await _repository.month(target);
      final projection = await _projections.fetch(
        from: target,
        period: ProjectionPeriod.threeMonths,
      );
      if (target != state.month) {
        return;
      }
      emit(
        state.copyWith(
          data: LoadState.loaded(
            MonthEntries(
              entries: entries,
              categories: {for (final c in categories) c.id: c},
              closingCents: projection.anchor == null
                  ? null
                  : projection.months.first.closingCents,
            ),
          ),
        ),
      );
    } on ApiError catch (error) {
      emit(state.copyWith(data: LoadState.failure(error)));
    }
  }

  void filterKind(EntryKind? kind) => emit(
    state.copyWith(
      kind: kind,
      nature: kind == EntryKind.expense ? state.nature : null,
    ),
  );

  void filterNature(EntryNature? nature) =>
      emit(state.copyWith(nature: nature));

  void includeAccumulated({required bool include}) =>
      emit(state.copyWith(includeAccumulated: include));

  Future<void> previous() => load(month: Dates.addMonths(state.month, -1));

  Future<void> next() => load(month: Dates.addMonths(state.month, 1));

  Future<ApiError?> delete(
    Entry entry, {
    EntryScope scope = EntryScope.one,
  }) async {
    try {
      await _repository.delete(entry.id, scope: scope);
      await load();
      return null;
    } on ApiError catch (error) {
      return error;
    }
  }

  Future<ApiError?> setPaid(Entry entry, {required bool paid}) async {
    try {
      final updated = await _repository.markPaid(
        entry.id,
        paidOn: paid ? Dates.dateOnly(DateTime.now()) : null,
      );
      if (state.data case Loaded(:final value)) {
        emit(
          state.copyWith(
            data: LoadState.loaded(
              value.copyWith(
                entries: [
                  for (final current in value.entries)
                    if (current.id == updated.id) updated else current,
                ],
              ),
            ),
          ),
        );
      }
      return null;
    } on ApiError catch (error) {
      return error;
    }
  }
}

@freezed
abstract class DueEntries with _$DueEntries {
  const factory({
    required DateTime today,
    required List<Entry> entries,
    required Map<String, Category> categories,
  }) = _DueEntries;

  const new _();

  static const weekDays = 7;

  DateTime get _weekEnd => today.add(const Duration(days: weekDays - 1));

  List<Entry> get overdue => [
    for (final entry in entries)
      if (entry.dueOn.isBefore(today)) entry,
  ];

  List<Entry> get thisWeek => [
    for (final entry in entries)
      if (!entry.dueOn.isBefore(today) && !entry.dueOn.isAfter(_weekEnd)) entry,
  ];

  List<Entry> get later => [
    for (final entry in entries)
      if (entry.dueOn.isAfter(_weekEnd)) entry,
  ];
}

@injectable
class DueCubit extends Cubit<LoadState<DueEntries>> {
  new(this._repository) : super(const LoadState<DueEntries>.loading());

  final EntryRepository _repository;

  static const overdueMonths = 3;

  Future<void> load({DateTime? today, bool quiet = false}) async {
    if (!quiet) {
      emit(const LoadState<DueEntries>.loading());
    }
    final day = Dates.dateOnly(today ?? DateTime.now());
    final weekEnd = day.add(const Duration(days: DueEntries.weekDays - 1));
    final monthEnd = Dates.lastOfMonth(day);
    try {
      final categories = await _repository.categories(EntryKind.expense);
      final entries = await _repository.between(
        Dates.addMonths(Dates.firstOfMonth(day), -overdueMonths),
        weekEnd.isAfter(monthEnd) ? weekEnd : monthEnd,
        kind: EntryKind.expense,
      );
      emit(
        LoadState.loaded(
          DueEntries(
            today: day,
            entries: [
              for (final entry in entries)
                if (!entry.isPaid) entry,
            ],
            categories: {for (final c in categories) c.id: c},
          ),
        ),
      );
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }

  Future<ApiError?> markPaid(Entry entry, {DateTime? today}) async {
    try {
      await _repository.markPaid(
        entry.id,
        paidOn: Dates.dateOnly(today ?? DateTime.now()),
      );
      if (state case Loaded(:final value)) {
        emit(
          LoadState.loaded(
            value.copyWith(
              entries: [
                for (final current in value.entries)
                  if (current.id != entry.id) current,
              ],
            ),
          ),
        );
      }
      return null;
    } on ApiError catch (error) {
      return error;
    }
  }
}

@injectable
class CategoriesCubit extends Cubit<LoadState<List<Category>>> {
  new(this._repository) : super(const LoadState<List<Category>>.loading());

  final EntryRepository _repository;

  Future<void> load(EntryKind kind) async {
    emit(const LoadState<List<Category>>.loading());
    try {
      emit(LoadState.loaded(await _repository.categories(kind)));
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }
}

@injectable
class EntryFormCubit extends SubmissionCubit<Entry> {
  new(this._repository);

  final EntryRepository _repository;

  Future<void> save(
    EntryDraft draft, {
    Entry? existing,
    EntryScope scope = EntryScope.one,
    Recurrence? recurrence,
    Installments? installments,
  }) => run(
    () => switch ((existing, recurrence, installments)) {
      (final entry?, _, _) => _repository.update(entry.id, draft, scope: scope),
      (null, final repeat?, _) => _sent(
        draft,
        _repository.createSeries(draft, repeat),
      ),
      (null, null, final plan?) => _sent(
        draft,
        _repository.createInstallments(draft, plan),
      ),
      (null, null, null) => _repository.create(draft),
    },
  );

  Future<Entry> _sent(EntryDraft draft, Future<List<Entry>> created) async {
    final entries = await created;
    return entries.firstWhere((entry) => entry.dueOn == draft.dueOn);
  }
}
