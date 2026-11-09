import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/security/domain/security_repository.dart';
import 'package:lar_em_dia/features/security/domain/two_factor.dart';

part 'security_cubits.freezed.dart';

typedef BackupCodesResult = ({List<String>? codes, ApiError? error});

@injectable
class SecurityCubit extends Cubit<LoadState<TwoFactorStatus>> {
  new(this._repository) : super(const LoadState<TwoFactorStatus>.loading());

  final SecurityRepository _repository;

  Future<void> load() async {
    emit(const LoadState<TwoFactorStatus>.loading());
    try {
      emit(LoadState.loaded(await _repository.twoFactorStatus()));
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }

  Future<ApiError?> disable(Reauthentication reauthentication) async {
    try {
      await _repository.disableTwoFactor(reauthentication);
    } on ApiError catch (error) {
      return error;
    }
    await load();
    return null;
  }

  Future<BackupCodesResult> regenerateBackupCodes(
    Reauthentication reauthentication,
  ) async {
    try {
      final codes = await _repository.regenerateBackupCodes(reauthentication);
      await load();
      return (codes: codes, error: null);
    } on ApiError catch (error) {
      return (codes: null, error: error);
    }
  }

  Future<ApiError?> deleteAccount(Reauthentication reauthentication) async {
    try {
      await _repository.deleteAccount(reauthentication);
      return null;
    } on ApiError catch (error) {
      return error;
    }
  }
}

@freezed
sealed class EnrollmentState with _$EnrollmentState {
  const factory password({@Default(false) bool busy, ApiError? error}) =
      EnrollmentPassword;
  const factory code(
    TwoFactorSetup setup, {
    @Default(false) bool busy,
    ApiError? error,
  }) = EnrollmentCode;
  const factory done(List<String> backupCodes) = EnrollmentDone;
}

@injectable
class TwoFactorEnrollmentCubit extends Cubit<EnrollmentState> {
  new(this._repository) : super(const EnrollmentState.password());

  final SecurityRepository _repository;

  Future<void> start(String password) async {
    emit(const EnrollmentState.password(busy: true));
    try {
      final setup = await _repository.setupTwoFactor(
        Reauthentication(password: password),
      );
      emit(EnrollmentState.code(setup));
    } on ApiError catch (error) {
      emit(EnrollmentState.password(error: error));
    }
  }

  Future<void> confirm(String code) async {
    final current = state;
    if (current is! EnrollmentCode) {
      return;
    }
    emit(EnrollmentState.code(current.setup, busy: true));
    try {
      emit(EnrollmentState.done(await _repository.enableTwoFactor(code)));
    } on ApiError catch (error) {
      emit(EnrollmentState.code(current.setup, error: error));
    }
  }
}
