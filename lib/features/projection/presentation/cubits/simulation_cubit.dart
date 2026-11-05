import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/domain/entry_repository.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/domain/projection_repository.dart';

part 'simulation_cubit.freezed.dart';

@freezed
abstract class SimulationState with _$SimulationState {
  const factory({
    @Default(<EntryPlan>[]) List<EntryPlan> plans,
    LoadState<ProjectionComparison>? result,
    @Default(false) bool committing,
    @Default(false) bool committed,
    ApiError? commitError,
  }) = _SimulationState;

  const new _();

  static const maxPlans = 10;

  bool get isFull => plans.length >= maxPlans;
}

@injectable
class SimulationCubit extends Cubit<SimulationState> {
  new(this._projections, this._entries) : super(const SimulationState());

  static const months = 12;

  final ProjectionRepository _projections;
  final EntryRepository _entries;
  int _version = 0;

  void _plans(List<EntryPlan> plans, {ApiError? commitError}) {
    _version++;
    emit(
      state.copyWith(plans: plans, commitError: commitError, committing: false),
    );
  }

  Future<void> add(EntryPlan plan) {
    _plans([...state.plans, plan]);
    return _simulate();
  }

  Future<void> remove(int index) {
    final plans = [...state.plans]..removeAt(index);
    _plans(plans);
    if (plans.isEmpty) {
      emit(state.copyWith(result: null));
      return Future.value();
    }
    return _simulate();
  }

  Future<void> retry() => _simulate();

  Future<void> commit() async {
    emit(state.copyWith(committing: true, commitError: null));
    final remaining = [...state.plans];
    while (remaining.isNotEmpty) {
      try {
        await _save(remaining.first);
        remaining.removeAt(0);
      } on ApiError catch (error) {
        final saved = remaining.length != state.plans.length;
        _plans(remaining, commitError: error);
        if (saved) {
          await _simulate();
        }
        return;
      }
    }
    emit(state.copyWith(plans: const [], committing: false, committed: true));
  }

  Future<void> _simulate() async {
    final plans = state.plans;
    final version = _version;
    emit(
      state.copyWith(result: const LoadState<ProjectionComparison>.loading()),
    );
    try {
      final comparison = await _projections.simulate(
        plans,
        from: Dates.firstOfMonth(DateTime.now()),
        months: months,
      );
      if (version == _version) {
        emit(state.copyWith(result: LoadState.loaded(comparison)));
      }
    } on ApiError catch (error) {
      if (version == _version) {
        emit(state.copyWith(result: LoadState.failure(error)));
      }
    }
  }

  Future<void> _save(EntryPlan plan) => switch (plan) {
    EntryPlan(:final draft, recurrence: final recurrence?) =>
      _entries.createSeries(draft, recurrence),
    EntryPlan(:final draft, installments: final installments?) =>
      _entries.createInstallments(draft, installments),
    EntryPlan(:final draft) => _entries.create(draft),
  };
}
