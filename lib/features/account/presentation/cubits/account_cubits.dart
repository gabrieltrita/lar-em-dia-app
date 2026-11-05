import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/account/domain/account_repository.dart';
import 'package:lar_em_dia/features/account/domain/notification_settings.dart';

@injectable
class NotificationSettingsCubit extends Cubit<LoadState<NotificationSettings>> {
  new(this._repository)
    : super(const LoadState<NotificationSettings>.loading());

  final AccountRepository _repository;

  Future<void> load() async {
    emit(const LoadState<NotificationSettings>.loading());
    try {
      emit(LoadState.loaded(await _repository.notificationSettings()));
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }

  Future<ApiError?> update(NotificationSettings settings) async {
    try {
      emit(
        LoadState.loaded(
          await _repository.updateNotificationSettings(settings),
        ),
      );
      return null;
    } on ApiError catch (error) {
      return error;
    }
  }
}

@injectable
class UnsubscribeCubit extends Cubit<LoadState<NotificationSettings>> {
  new(this._repository)
    : super(const LoadState<NotificationSettings>.loading());

  final AccountRepository _repository;

  Future<void> unsubscribe(String? token) async {
    emit(const LoadState<NotificationSettings>.loading());
    try {
      emit(LoadState.loaded(await _repository.unsubscribe(token ?? '')));
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }
}
