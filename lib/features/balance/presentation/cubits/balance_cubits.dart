import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/balance/domain/balance.dart';
import 'package:lar_em_dia/features/balance/domain/balance_repository.dart';

@injectable
class BalancesCubit extends Cubit<LoadState<List<Balance>>> {
  new(this._repository) : super(const LoadState<List<Balance>>.loading());

  final BalanceRepository _repository;

  Future<void> load() async {
    emit(const LoadState<List<Balance>>.loading());
    try {
      emit(LoadState.loaded(await _repository.list()));
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }

  Future<ApiError?> delete(Balance balance) async {
    try {
      await _repository.delete(balance.id);
      await load();
      return null;
    } on ApiError catch (error) {
      return error;
    }
  }
}

@injectable
class LatestBalanceCubit extends Cubit<Balance?> {
  new(this._repository) : super(null);

  final BalanceRepository _repository;

  Future<void> load() async {
    try {
      emit(await _repository.latest());
    } on ApiError {
      emit(null);
    }
  }
}

@injectable
class BalanceFormCubit extends SubmissionCubit<Balance> {
  new(this._repository);

  final BalanceRepository _repository;

  Future<void> save({
    required int amountCents,
    required DateTime asOf,
    Balance? existing,
  }) => run(
    () => existing == null
        ? _repository.create(amountCents: amountCents, asOf: asOf)
        : _repository.update(existing.id, amountCents: amountCents, asOf: asOf),
  );
}
