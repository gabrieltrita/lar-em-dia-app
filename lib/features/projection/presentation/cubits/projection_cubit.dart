import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/domain/projection_repository.dart';

part 'projection_cubit.freezed.dart';

@freezed
abstract class ProjectionState with _$ProjectionState {
  const factory({
    @Default(ProjectionPeriod.year) ProjectionPeriod period,
    @Default(LoadState<Projection>.loading()) LoadState<Projection> data,
  }) = _ProjectionState;
}

@injectable
class ProjectionCubit extends Cubit<ProjectionState> {
  new(this._repository) : super(const ProjectionState());

  final ProjectionRepository _repository;

  Future<void> load({DateTime? today}) async {
    emit(state.copyWith(data: const LoadState<Projection>.loading()));
    try {
      final projection = await _repository.fetch(
        from: Dates.firstOfMonth(today ?? DateTime.now()),
        period: state.period,
      );
      emit(state.copyWith(data: LoadState.loaded(projection)));
    } on ApiError catch (error) {
      emit(state.copyWith(data: LoadState.failure(error)));
    }
  }

  Future<void> selectPeriod(ProjectionPeriod period, {DateTime? today}) async {
    if (period == state.period) {
      return;
    }
    emit(state.copyWith(period: period));
    await load(today: today);
  }
}
