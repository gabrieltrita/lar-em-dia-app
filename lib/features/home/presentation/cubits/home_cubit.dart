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

part 'home_cubit.freezed.dart';

@freezed
abstract class HomeSummary with _$HomeSummary {
  const factory({
    required DateTime month,
    required int receivedCents,
    required int pendingCents,
    Balance? latestBalance,
  }) = _HomeSummary;

  const new _();

  int get incomeCents => receivedCents + pendingCents;
}

@injectable
class HomeCubit extends Cubit<LoadState<HomeSummary>> {
  new(this._balances, this._entries)
    : super(const LoadState<HomeSummary>.loading());

  final BalanceRepository _balances;
  final EntryRepository _entries;

  Future<void> load({DateTime? today}) async {
    emit(const LoadState<HomeSummary>.loading());
    final month = Dates.firstOfMonth(today ?? DateTime.now());
    try {
      final latest = await _balances.latest();
      final income = await _entries.month(month, kind: EntryKind.income);
      int sum({required bool paid}) => income
          .where((entry) => entry.isPaid == paid)
          .fold(0, (total, entry) => total + entry.amountCents);
      emit(
        LoadState.loaded(
          HomeSummary(
            month: month,
            latestBalance: latest,
            receivedCents: sum(paid: true),
            pendingCents: sum(paid: false),
          ),
        ),
      );
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }
}
