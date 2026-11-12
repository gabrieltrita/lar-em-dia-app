import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve_dismissal.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve_repository.dart';

part 'reserve_cubits.freezed.dart';

enum ReservePeriod {
  year(12),
  twoYears(24),
  fiveYears(60);

  new(this.months);

  final int months;
}

@freezed
abstract class ReserveView with _$ReserveView {
  const factory({
    required ReserveSummary summary,
    required ReserveProjection projection,
    @Default(ReservePeriod.year) ReservePeriod period,
  }) = _ReserveView;
}

@injectable
class ReserveCubit extends Cubit<LoadState<ReserveView>> {
  new(this._repository) : super(const LoadState<ReserveView>.loading());

  final ReserveRepository _repository;

  ReservePeriod get _period => switch (state) {
    Loaded(:final value) => value.period,
    _ => ReservePeriod.year,
  };

  Future<void> load({bool quiet = false, ReservePeriod? period}) async {
    final selected = period ?? _period;
    if (!quiet || state is! Loaded<ReserveView>) {
      emit(const LoadState<ReserveView>.loading());
    }
    try {
      final summary = _repository.summary();
      final projection = _repository.projection(selected.months);
      await Future.wait([summary, projection]);
      emit(
        LoadState.loaded(
          ReserveView(
            summary: await summary,
            projection: await projection,
            period: selected,
          ),
        ),
      );
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }

  Future<void> selectPeriod(ReservePeriod period) =>
      load(quiet: true, period: period);

  Future<ApiError?> updateGoal({required int months, int? cents}) async {
    try {
      await _repository.updateGoal(months: months, cents: cents);
      await load(quiet: true);
      return null;
    } on ApiError catch (error) {
      return error;
    }
  }
}

@freezed
abstract class ReserveAccountDetail with _$ReserveAccountDetail {
  const factory({
    required ReserveAccount account,
    required List<ReserveMovement> movements,
  }) = _ReserveAccountDetail;
}

@injectable
class ReserveAccountCubit extends Cubit<LoadState<ReserveAccountDetail>> {
  new(this._repository, @factoryParam this.accountId)
    : super(const LoadState<ReserveAccountDetail>.loading());

  final ReserveRepository _repository;
  final String accountId;

  Future<void> load({bool quiet = false}) async {
    if (!quiet || state is! Loaded<ReserveAccountDetail>) {
      emit(const LoadState<ReserveAccountDetail>.loading());
    }
    try {
      final summary = _repository.summary();
      final movements = _repository.movements(accountId);
      await Future.wait([summary, movements]);
      final account = (await summary).accounts
          .where((account) => account.id == accountId)
          .firstOrNull;
      emit(
        account == null
            ? const LoadState.failure(ApiError(code: 'not_found'))
            : LoadState.loaded(
                ReserveAccountDetail(
                  account: account,
                  movements: (await movements).reversed.toList(),
                ),
              ),
      );
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }

  Future<ApiError?> deleteMovement(ReserveMovement movement) async {
    try {
      await _repository.deleteMovement(movement);
      await load(quiet: true);
      return null;
    } on ApiError catch (error) {
      return error;
    }
  }

  Future<ApiError?> deleteAccount() async {
    try {
      await _repository.deleteAccount(accountId);
      return null;
    } on ApiError catch (error) {
      return error;
    }
  }
}

@freezed
abstract class ReserveCard with _$ReserveCard {
  const factory({required ReserveSummary summary, required bool dismissed}) =
      _ReserveCard;

  const new _();

  bool get visible =>
      !summary.isEmpty || (summary.has(ReserveAlert.noReserve) && !dismissed);
}

@injectable
class ReserveCardCubit extends Cubit<ReserveCard?> {
  new(this._repository, this._dismissal) : super(null);

  final ReserveRepository _repository;
  final ReserveDismissal _dismissal;

  Future<void> load({DateTime? now}) async {
    try {
      final summary = await _repository.summary();
      final until = await _dismissal.dismissedUntil();
      final today = now ?? DateTime.now();
      emit(
        ReserveCard(
          summary: summary,
          dismissed: until != null && until.isAfter(today),
        ),
      );
    } on ApiError {
      emit(null);
    }
  }

  Future<void> dismiss({DateTime? now}) async {
    await _dismissal.dismiss(now ?? DateTime.now());
    if (state case final card?) {
      emit(card.copyWith(dismissed: true));
    }
  }
}

@injectable
class ReserveAccountFormCubit extends SubmissionCubit<ReserveAccount> {
  new(this._repository);

  final ReserveRepository _repository;

  Future<void> save(
    ReserveAccountDraft draft, {
    String? accountId,
    int? anchorCents,
    DateTime? today,
  }) => run(() async {
    if (accountId != null) {
      return await _repository.updateAccount(accountId, draft);
    }
    final account = await _repository.createAccount(draft);
    if (anchorCents != null) {
      await _repository.createMovement(
        ReserveMovementDraft(
          accountId: account.id,
          kind: ReserveMovementKind.anchor,
          movedOn: today ?? DateTime.now(),
          amountCents: anchorCents,
        ),
      );
    }
    return account;
  });
}

@injectable
class ReserveMovementFormCubit extends SubmissionCubit<ReserveMovement> {
  new(this._repository);

  final ReserveRepository _repository;

  Future<void> save(ReserveMovementDraft draft, {ReserveMovement? existing}) =>
      run(
        () => existing == null
            ? _repository.createMovement(draft)
            : _repository.updateMovement(existing, draft),
      );
}
