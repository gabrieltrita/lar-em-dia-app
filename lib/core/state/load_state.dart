import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lar_em_dia/core/network/api_error.dart';

part 'load_state.freezed.dart';

@freezed
sealed class LoadState<T> with _$LoadState<T> {
  const factory loading() = Loading<T>;
  const factory loaded(T value) = Loaded<T>;
  const factory failure(ApiError error) = LoadFailure<T>;
}
