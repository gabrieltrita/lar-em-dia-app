import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/balance/domain/balance.dart';
import 'package:lar_em_dia/features/balance/domain/balance_repository.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/domain/entry_repository.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/domain/projection_repository.dart';

part 'home_cubit.freezed.dart';

@freezed
abstract class MonthTotals with _$MonthTotals {
  const factory({required int settledCents, required int pendingCents}) =
      _MonthTotals;

  factory of(List<Entry> entries) {
    int sum({required bool paid}) => entries
        .where((entry) => entry.isPaid == paid)
        .fold(0, (total, entry) => total + entry.amountCents);
    return MonthTotals(
      settledCents: sum(paid: true),
      pendingCents: sum(paid: false),
    );
  }

  const new _();

  int get totalCents => settledCents + pendingCents;
}

@freezed
abstract class HomeSummary with _$HomeSummary {
  const factory({
    required DateTime month,
    required MonthTotals income,
    required MonthTotals expenses,
    Balance? latestBalance,
    ProjectionMonth? projected,
  }) = _HomeSummary;

  const new _();

  MonthTotals totalsOf(EntryKind kind) => switch (kind) {
    EntryKind.income => income,
    EntryKind.expense => expenses,
  };
}

@injectable
class HomeCubit extends Cubit<LoadState<HomeSummary>> {
  new(this._balances, this._entries, this._projections)
    : super(const LoadState<HomeSummary>.loading());

  final BalanceRepository _balances;
  final EntryRepository _entries;
  final ProjectionRepository _projections;

  Future<void> load({DateTime? today}) async {
    emit(const LoadState<HomeSummary>.loading());
    final month = Dates.firstOfMonth(today ?? DateTime.now());
    try {
      final latest = await _balances.latest();
      final income = await _entries.month(month, kind: EntryKind.income);
      final expenses = await _entries.month(month, kind: EntryKind.expense);
      final projection = latest == null
          ? null
          : await _projections.fetch(from: month, months: 1);
      emit(
        LoadState.loaded(
          HomeSummary(
            month: month,
            latestBalance: latest,
            income: MonthTotals.of(income),
            expenses: MonthTotals.of(expenses),
            projected: projection?.months.first,
          ),
        ),
      );
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }
}
