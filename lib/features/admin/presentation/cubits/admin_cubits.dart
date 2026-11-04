import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/admin/domain/admin_repository.dart';
import 'package:lar_em_dia/features/admin/domain/admin_user.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';

part 'admin_cubits.freezed.dart';

@freezed
abstract class AdminUsersState with _$AdminUsersState {
  const factory({
    required LoadState<List<AdminUser>> users,
    @Default('') String email,
    AccountStatus? status,
    int? nextPage,
    @Default(false) bool loadingMore,
  }) = _AdminUsersState;
}

@injectable
class AdminUsersCubit extends Cubit<AdminUsersState> {
  new(this._repository)
    : super(const AdminUsersState(users: LoadState<List<AdminUser>>.loading()));

  final AdminRepository _repository;

  Future<void> load() async {
    emit(
      state.copyWith(
        users: const LoadState<List<AdminUser>>.loading(),
        nextPage: null,
      ),
    );
    try {
      final page = await _fetch(1);
      emit(
        state.copyWith(
          users: LoadState.loaded(page.users),
          nextPage: page.nextPage,
        ),
      );
    } on ApiError catch (error) {
      emit(state.copyWith(users: LoadState.failure(error)));
    }
  }

  Future<void> search(String email) {
    emit(state.copyWith(email: email.trim()));
    return load();
  }

  Future<void> filter(AccountStatus? status) {
    emit(state.copyWith(status: status));
    return load();
  }

  Future<ApiError?> loadMore() async {
    final next = state.nextPage;
    final current = state.users;
    if (next == null ||
        state.loadingMore ||
        current is! Loaded<List<AdminUser>>) {
      return null;
    }
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _fetch(next);
      emit(
        state.copyWith(
          users: LoadState.loaded([...current.value, ...page.users]),
          nextPage: page.nextPage,
          loadingMore: false,
        ),
      );
      return null;
    } on ApiError catch (error) {
      emit(state.copyWith(loadingMore: false));
      return error;
    }
  }

  Future<AdminUserPage> _fetch(int page) =>
      _repository.users(page: page, email: state.email, status: state.status);
}

@injectable
class AdminUserCubit extends Cubit<LoadState<AdminUser>> {
  new(this._repository, @factoryParam this.id)
    : super(const LoadState<AdminUser>.loading());

  final String id;

  final AdminRepository _repository;

  Future<void> load() async {
    emit(const LoadState<AdminUser>.loading());
    try {
      emit(LoadState.loaded(await _repository.user(id)));
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }

  Future<ApiError?> unlock() => _apply(() => _repository.unlock(id));

  Future<ApiError?> resetTwoFactor() => _apply(() async {
    await _repository.resetTwoFactor(id);
    return await _repository.user(id);
  });

  Future<ApiError?> deactivate() => _apply(() => _repository.deactivate(id));

  Future<ApiError?> reactivate() => _apply(() => _repository.reactivate(id));

  Future<ApiError?> changeRole(UserRole role) =>
      _apply(() => _repository.changeRole(id, role));

  Future<ApiError?> _apply(Future<AdminUser> Function() action) async {
    try {
      emit(LoadState.loaded(await action()));
      return null;
    } on ApiError catch (error) {
      return error;
    }
  }
}
