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

part 'entry_cubits.freezed.dart';

@freezed
abstract class MonthEntries with _$MonthEntries {
  const factory({
    required List<Entry> entries,
    required Map<String, Category> categories,
  }) = _MonthEntries;

  const new _();

  List<Entry> withNature(EntryNature? nature) => nature == null
      ? entries
      : entries.where((entry) => entry.nature == nature).toList();

  int totalCents([EntryNature? nature]) =>
      withNature(nature).fold(0, (sum, entry) => sum + entry.amountCents);
}

@freezed
abstract class MonthEntriesState with _$MonthEntriesState {
  const factory({
    required DateTime month,
    required LoadState<MonthEntries> data,
    EntryNature? nature,
  }) = _MonthEntriesState;
}

@injectable
class MonthEntriesCubit extends Cubit<MonthEntriesState> {
  new(this._repository, @factoryParam this.kind)
    : super(
        MonthEntriesState(
          month: Dates.firstOfMonth(DateTime.now()),
          data: const LoadState<MonthEntries>.loading(),
        ),
      );

  final EntryKind kind;

  final EntryRepository _repository;

  Future<void> load([DateTime? month]) async {
    final target = Dates.firstOfMonth(month ?? state.month);
    emit(
      state.copyWith(
        month: target,
        data: const LoadState<MonthEntries>.loading(),
      ),
    );
    try {
      final categories = await _repository.categories(kind);
      final entries = await _repository.month(target, kind: kind);
      if (target != state.month) {
        return;
      }
      emit(
        state.copyWith(
          data: LoadState.loaded(
            MonthEntries(
              entries: entries,
              categories: {for (final c in categories) c.id: c},
            ),
          ),
        ),
      );
    } on ApiError catch (error) {
      emit(state.copyWith(data: LoadState.failure(error)));
    }
  }

  void filter(EntryNature? nature) => emit(state.copyWith(nature: nature));

  Future<void> previous() => load(Dates.addMonths(state.month, -1));

  Future<void> next() => load(Dates.addMonths(state.month, 1));

  Future<ApiError?> delete(Entry entry) async {
    try {
      await _repository.delete(entry.id);
      await load();
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
    Recurrence? recurrence,
    Installments? installments,
  }) => run(
    () => switch ((existing, recurrence, installments)) {
      (final entry?, _, _) => _repository.update(entry.id, draft),
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
