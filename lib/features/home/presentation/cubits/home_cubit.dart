import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/features/balance/domain/balance.dart';
import 'package:lar_em_dia/features/balance/domain/balance_repository.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/domain/entry_repository.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/domain/projection_repository.dart';

part 'home_cubit.freezed.dart';

@freezed
abstract class MonthTotals with _$MonthTotals {
  const factory({required int settledCents, required int pendingCents}) =
      _MonthTotals;

  factory of(List<Entry> entries) {
    int sum({required bool paid}) => entries
        .where((entry) => entry.isPaid == paid)
        .fold(0, (total, entry) => total + entry.amountCents);
    return MonthTotals(
      settledCents: sum(paid: true),
      pendingCents: sum(paid: false),
    );
  }

  const new _();

  int get totalCents => settledCents + pendingCents;
}

@freezed
abstract class HomeSummary with _$HomeSummary {
  const factory({
    required DateTime month,
    required MonthTotals income,
    required MonthTotals expenses,
    Balance? latestBalance,
    ProjectionMonth? projected,
    DateTime? firstNegativeMonth,
    @Default(0) int negativeMonthsCount,
    @Default([]) List<Entry> upcoming,
    @Default([]) List<CategoryAmount> expenseByCategory,
    @Default(0) int fixedCents,
    @Default(0) int variableCents,
    @Default([]) List<ProjectionMonth> months,
  }) = _HomeSummary;

  const new _();

  int get resultCents => income.totalCents - expenses.totalCents;

  int get upcomingCents =>
      upcoming.fold(0, (sum, entry) => sum + entry.amountCents);
}

@injectable
class HomeCubit extends Cubit<LoadState<HomeSummary>> {
  new(this._balances, this._entries, this._projections)
    : super(const LoadState<HomeSummary>.loading());

  final BalanceRepository _balances;
  final EntryRepository _entries;
  final ProjectionRepository _projections;

  static const upcomingDays = 7;

  DateTime? _month;

  Future<void> load({
    DateTime? month,
    DateTime? today,
    bool quiet = false,
  }) async {
    if (!quiet) {
      emit(const LoadState<HomeSummary>.loading());
    }
    final day = Dates.dateOnly(today ?? DateTime.now());
    final target = Dates.firstOfMonth(month ?? _month ?? day);
    _month = target;
    try {
      final latest = await _balances.latest();
      final entries = await _entries.month(target);
      final categories = await _entries.categories(EntryKind.expense);
      final upcoming = await _entries.between(
        day,
        day.add(const Duration(days: upcomingDays)),
        kind: EntryKind.expense,
      );
      final projection = latest == null
          ? null
          : await _projections.fetch(from: target);
      if (target != _month) {
        return;
      }
      final expenses = [
        for (final entry in entries)
          if (entry.kind == EntryKind.expense) entry,
      ];
      int natureCents(EntryNature nature) => expenses
          .where((entry) => entry.nature == nature)
          .fold(0, (sum, entry) => sum + entry.amountCents);
      emit(
        LoadState.loaded(
          HomeSummary(
            month: target,
            latestBalance: latest,
            income: MonthTotals.of([
              for (final entry in entries)
                if (entry.kind == EntryKind.income) entry,
            ]),
            expenses: MonthTotals.of(expenses),
            projected: projection?.months.first,
            firstNegativeMonth: projection?.firstNegativeMonth,
            negativeMonthsCount: projection?.negativeMonthsCount ?? 0,
            upcoming: [
              for (final entry in upcoming)
                if (!entry.isPaid) entry,
            ],
            expenseByCategory: _byCategory(expenses, {
              for (final category in categories) category.id: category,
            }),
            fixedCents: natureCents(EntryNature.fixed),
            variableCents: natureCents(EntryNature.variable),
            months: projection?.months ?? const [],
          ),
        ),
      );
    } on ApiError catch (error) {
      emit(LoadState.failure(error));
    }
  }

  Future<void> previous() =>
      load(month: Dates.addMonths(_month ?? DateTime.now(), -1));

  Future<void> next() =>
      load(month: Dates.addMonths(_month ?? DateTime.now(), 1));

  static List<CategoryAmount> _byCategory(
    List<Entry> expenses,
    Map<String, Category> categories,
  ) {
    final totals = <String, int>{};
    final names = <String, String>{};
    for (final entry in expenses) {
      final category = categories[entry.categoryId];
      final key = category?.key ?? entry.categoryId;
      totals[key] = (totals[key] ?? 0) + entry.amountCents;
      if (category != null) {
        names[key] = category.name;
      }
    }
    return [
      for (final MapEntry(:key, :value)
          in totals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
        CategoryAmount(
          categoryKey: key,
          amountCents: value,
          categoryName: names[key],
        ),
    ];
  }
}
