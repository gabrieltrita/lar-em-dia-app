import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/distribution.dart';
import 'package:lar_em_dia/features/investments/domain/investment_repository.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';

part 'investment_cubits.freezed.dart';

@freezed
abstract class PortfolioView with _$PortfolioView {
  const factory({
    required Portfolio portfolio,
    required List<PortfolioMonth> history,
    InvestmentGoal? filter,
    PassiveIncome? income,
  }) = _PortfolioView;

  const new _();

  static const recentMonths = 12;

  List<PortfolioPosition> get visiblePositions => [
    for (final position in portfolio.positions)
      if (filter == null || position.goal == filter) position,
  ];

  List<PortfolioMonth> get recentHistory => history.length > recentMonths
      ? history.sublist(history.length - recentMonths)
      : history;
}

@injectable
class PortfolioCubit extends Cubit<LoadState<PortfolioView>> {
  new(this._repository) : super(const LoadState<PortfolioView>.loading());

  final InvestmentRepository _repository;

  Future<void> load({bool quiet = false}) async {
    final filter = switch (state) {
      Loaded(:final value) => value.filter,
      _ => null,
    };
    if (!quiet || state is! Loaded<PortfolioView>) {
      emit(const LoadState<PortfolioView>.loading());
    }
    try {
      final portfolio = _repository.portfolio();
      final history = _repository.history();
      final income = _income();
      await Future.wait([portfolio, history]);
      emit(
        LoadState.loaded(
          PortfolioView(
            portfolio: await portfolio,
            history: await history,
            filter: filter,
            income: await income,
          ),
        ),
      );
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }

  Future<PassiveIncome?> _income() async {
    try {
      return await _repository.income();
    } on ApiError {
      return null;
    }
  }

  void filter(InvestmentGoal? goal) {
    if (state case Loaded(:final value)) {
      emit(LoadState.loaded(value.copyWith(filter: goal)));
    }
  }
}

@injectable
class PortfolioHistoryCubit extends Cubit<LoadState<List<PortfolioMonth>>> {
  new(this._repository)
    : super(const LoadState<List<PortfolioMonth>>.loading());

  final InvestmentRepository _repository;

  Future<void> load() async {
    emit(const LoadState<List<PortfolioMonth>>.loading());
    try {
      emit(LoadState.loaded(await _repository.history()));
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }
}

@injectable
class PassiveIncomeCubit extends Cubit<LoadState<PassiveIncome>> {
  new(this._repository) : super(const LoadState<PassiveIncome>.loading());

  final InvestmentRepository _repository;

  Future<void> load() async {
    emit(const LoadState<PassiveIncome>.loading());
    try {
      emit(LoadState.loaded(await _repository.income()));
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }
}

@freezed
abstract class AssetDetail with _$AssetDetail {
  const factory({
    required Asset asset,
    required List<InvestmentTransaction> transactions,
    PortfolioPosition? position,
  }) = _AssetDetail;
}

@injectable
class AssetDetailCubit extends Cubit<LoadState<AssetDetail>> {
  new(this._repository, @factoryParam this.ticker)
    : super(const LoadState<AssetDetail>.loading());

  final InvestmentRepository _repository;
  final String ticker;

  Future<void> load({bool quiet = false}) async {
    if (!quiet || state is! Loaded<AssetDetail>) {
      emit(const LoadState<AssetDetail>.loading());
    }
    try {
      final asset = _repository.asset(ticker);
      final portfolio = _repository.portfolio();
      final transactions = _repository.transactions(ticker);
      await Future.wait([asset, portfolio, transactions]);
      emit(
        LoadState.loaded(
          AssetDetail(
            asset: await asset,
            position: (await portfolio).position(ticker),
            transactions: (await transactions).reversed.toList(),
          ),
        ),
      );
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }

  Future<ApiError?> changeGoal(InvestmentGoal goal) =>
      _change(() => _repository.updateGoal(ticker, goal));

  Future<ApiError?> delete(InvestmentTransaction transaction) =>
      _change(() => _repository.delete(transaction));

  Future<ApiError?> deleteDistribution(AssetDistribution distribution) =>
      _change(() => _repository.deleteDistribution(distribution));

  Future<ApiError?> _change(Future<void> Function() action) async {
    try {
      await action();
      await load(quiet: true);
      return null;
    } on ApiError catch (error) {
      return error;
    }
  }
}

@injectable
class AssetSearchCubit extends Cubit<List<Asset>> {
  new(this._repository) : super(const []);

  static const debounce = Duration(milliseconds: 300);
  static const minLength = 2;

  final InvestmentRepository _repository;
  Timer? _timer;
  int _request = 0;

  void search(String text) {
    _timer?.cancel();
    final query = text.trim();
    final request = ++_request;
    if (query.length < minLength) {
      emit(const []);
      return;
    }
    _timer = Timer(debounce, () => unawaited(_run(query, request)));
  }

  Future<void> _run(String query, int request) async {
    List<Asset> found;
    try {
      found = await _repository.searchAssets(query);
    } on ApiError {
      found = const [];
    }
    if (request == _request && !isClosed) {
      emit(found);
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}

@injectable
class InvestmentFormCubit extends SubmissionCubit<InvestmentTransaction> {
  new(this._repository);

  final InvestmentRepository _repository;

  Future<void> save(InvestmentDraft draft, {InvestmentTransaction? existing}) =>
      run(
        () => existing == null
            ? _repository.create(draft)
            : _repository.update(existing, draft),
      );
}

@injectable
class DistributionFormCubit extends SubmissionCubit<AssetDistribution> {
  new(this._repository);

  final InvestmentRepository _repository;

  Future<void> save(DistributionDraft draft, {AssetDistribution? existing}) =>
      run(
        () => existing == null
            ? _repository.createDistribution(draft)
            : _repository.updateDistribution(existing, draft),
      );
}
