import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/core/network/api_error.dart';

part 'submission.freezed.dart';

@freezed
sealed class Submission<T> with _$Submission<T> {
  const factory idle() = SubmissionIdle<T>;
  const factory inProgress() = SubmissionInProgress<T>;
  const factory success(T value) = SubmissionSuccess<T>;
  const factory failure(ApiError error) = SubmissionFailure<T>;
}

abstract class SubmissionCubit<T> extends Cubit<Submission<T>> {
  new() : super(Submission<T>.idle());

  Future<void> run(Future<T> Function() action) async {
    if (state is SubmissionInProgress<T>) {
      return;
    }
    emit(Submission<T>.inProgress());
    try {
      emit(Submission.success(await action()));
    } on ApiError catch (error) {
      emit(Submission.failure(error));
    }
  }
}
