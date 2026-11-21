import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/allocation/domain/allocation.dart';
import 'package:lar_em_dia/features/allocation/domain/allocation_repository.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/domain/entry_repository.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve_repository.dart';

part 'allocation_cubits.freezed.dart';

@freezed
abstract class AllocationView with _$AllocationView {
  const factory({
    required AllocationPlan plan,
    required List<AllocationTarget> targets,
    @Default([]) List<ReserveAccount> accounts,
    @Default([]) List<Category> categories,
  }) = _AllocationView;

  const new _();

  AllocationTarget? target(String id) =>
      targets.where((target) => target.id == id).firstOrNull;

  String? accountName(String? id) =>
      accounts.where((account) => account.id == id).firstOrNull?.name;

  Category? category(String? id) =>
      categories.where((category) => category.id == id).firstOrNull;
}

@freezed
abstract class AllocationState with _$AllocationState {
  const factory({
    required DateTime month,
    @Default(LoadState<AllocationView>.loading())
    LoadState<AllocationView> view,
  }) = _AllocationState;
}

@injectable
class AllocationCubit extends Cubit<AllocationState> {
  new(this._repository, this._reserve, this._entries)
    : super(AllocationState(month: Dates.firstOfMonth(DateTime.now())));

  final AllocationRepository _repository;
  final ReserveRepository _reserve;
  final EntryRepository _entries;

  Future<void> load({bool quiet = false, DateTime? month}) async {
    final selected = month ?? state.month;
    if (!quiet || state.view is! Loaded<AllocationView>) {
      emit(state.copyWith(month: selected, view: const LoadState.loading()));
    }
    try {
      final plan = _repository.plan(selected);
      final targets = _repository.targets();
      final summary = _reserve.summary();
      final categories = _entries.categories(EntryKind.expense);
      await Future.wait([plan, targets, summary, categories]);
      emit(
        AllocationState(
          month: selected,
          view: LoadState.loaded(
            AllocationView(
              plan: await plan,
              targets: await targets,
              accounts: (await summary).accounts,
              categories: await categories,
            ),
          ),
        ),
      );
    } on ApiError catch (error) {
      emit(state.copyWith(month: selected, view: LoadState.failure(error)));
    }
  }

  Future<void> previous() => load(month: Dates.addMonths(state.month, -1));

  Future<void> next() => load(month: Dates.addMonths(state.month, 1));

  Future<ApiError?> use(AllocationItem item, {int? amountCents}) => _act(
    () => _repository.use(item.targetId, state.month, amountCents: amountCents),
  );

  Future<ApiError?> undo(AllocationItem item) =>
      _act(() => _repository.undo(item.allocationId!));

  Future<ApiError?> deleteTarget(String id) =>
      _act(() => _repository.deleteTarget(id));

  Future<ApiError?> _act(Future<void> Function() action) async {
    try {
      await action();
      await load(quiet: true);
      return null;
    } on ApiError catch (error) {
      return error;
    }
  }
}

@freezed
abstract class AllocationTargetFormArgs with _$AllocationTargetFormArgs {
  const factory({
    @Default([]) List<ReserveAccount> accounts,
    @Default([]) List<Category> categories,
    AllocationTarget? existing,
    @Default(false) bool remainderTaken,
  }) = _AllocationTargetFormArgs;
}

@injectable
class AllocationTargetFormCubit extends SubmissionCubit<AllocationTarget> {
  new(this._repository);

  final AllocationRepository _repository;

  Future<void> save(AllocationTargetDraft draft, {String? id}) => run(
    () => id == null
        ? _repository.createTarget(draft)
        : _repository.updateTarget(id, draft),
  );
}
