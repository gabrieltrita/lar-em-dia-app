import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/domain/projection_repository.dart';

@injectable
class ProjectionCubit extends Cubit<LoadState<Projection>> {
  new(this._repository) : super(const LoadState<Projection>.loading());

  static const months = 12;

  final ProjectionRepository _repository;

  Future<void> load({DateTime? today}) async {
    emit(const LoadState<Projection>.loading());
    try {
      final projection = await _repository.fetch(
        from: Dates.firstOfMonth(today ?? DateTime.now()),
        months: months,
      );
      emit(LoadState.loaded(projection));
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }
}
