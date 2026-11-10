import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/core/widgets/money_text.dart';
import 'package:lar_em_dia/core/widgets/month_switcher.dart';
import 'package:lar_em_dia/core/widgets/skeleton.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_label.dart';
import 'package:lar_em_dia/features/home/presentation/cubits/home_cubit.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/negative_months_alert.dart';
import 'package:lar_em_dia/features/shell/presentation/app_shell.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class HomePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<HomeCubit>();
    final firstName = context.select<SessionCubit, String?>(
      (cubit) => switch (cubit.state) {
        SessionAuthenticated(:final user) => user.firstName,
        _ => null,
      },
    );
    return Scaffold(
      floatingActionButton: const AddButton(),
      appBar: AppBar(
        title: Text(
          firstName == null ? l10n.appTitle : l10n.homeGreeting(firstName),
        ),
      ),
      body: BlocBuilder<HomeCubit, LoadState<HomeSummary>>(
        builder: (context, state) => switch (state) {
          Loading() => SkeletonList(label: l10n.loadingLabel),
          LoadFailure(:final error) => RetryMessage(
            message: error.localized(l10n),
            onRetry: () => unawaited(cubit.load()),
          ),
          Loaded(value: final summary) => RefreshIndicator(
            onRefresh: () => cubit.load(quiet: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
              children: [
                MonthSwitcher(
                  month: summary.month,
                  onPrevious: () => unawaited(cubit.previous()),
                  onNext: () => unawaited(cubit.next()),
                ),
                _MonthHero(summary: summary),
                const SizedBox(height: 12),
                _Indicators(summary: summary),
                const SizedBox(height: 12),
                if (summary case HomeSummary(
                  :final firstNegativeMonth?,
                  :final negativeMonthsCount,
                )) ...[
                  NegativeMonthsAlert(
                    firstMonth: firstNegativeMonth,
                    count: negativeMonthsCount,
                    onTap: () => context.go(AppRoutes.projection),
                  ),
                  const SizedBox(height: 12),
                ],
                _WhereMoneyGoes(summary: summary),
                const SizedBox(height: 12),
                _DueShortcut(summary: summary),
              ],
            ),
          ),
        },
      ),
    );
  }
}

class _MonthHero extends StatelessWidget {
  const new({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final localizations = MaterialLocalizations.of(context);
    final month = localizations.formatMonthYear(summary.month);
    final income = summary.income.totalCents;
    final expense = summary.expenses.totalCents;
    final result = summary.resultCents;
    final largest = income > expense ? income : expense;
    Widget bar(String label, int cents, Color color) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
              MoneyText(cents, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: largest == 0 ? 0 : cents / largest,
              minHeight: 8,
              color: color,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.homeMonthResultTitle(month),
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  result < 0 ? Icons.trending_down : Icons.trending_up,
                  color: result < 0 ? colors.negative : colors.positive,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MoneyText(
                    result,
                    signed: true,
                    colored: true,
                    style: theme.textTheme.displaySmall,
                  ),
                ),
              ],
            ),
            bar(l10n.projectionWaterfallIncome, income, colors.positive),
            bar(l10n.homeExpensesLabel, expense, colors.negative),
            const SizedBox(height: 12),
            Text(
              l10n.homeMonthResultSentence(
                '${result >= 0}',
                Money.format(result.abs()),
                Dates.display(Dates.lastOfMonth(summary.month)),
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _Indicators extends StatelessWidget {
  const new({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final changes = context.read<FinanceChanges>();
    final balance = summary.latestBalance;
    final projected = summary.projected;
    Widget tile({
      required String label,
      required Widget value,
      required String caption,
      required VoidCallback onTap,
    }) => Expanded(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                value,
                const SizedBox(height: 2),
                Text(caption, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
    Future<void> open(String route) async {
      await context.push<bool>(route);
      changes.notify();
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (balance == null)
            tile(
              label: l10n.homeBalanceTitle,
              value: Text(
                l10n.homeInformBalance,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              caption: l10n.homeNoBalance,
              onTap: () => unawaited(open(AppRoutes.balanceForm)),
            )
          else
            tile(
              label: l10n.homeBalanceTitle,
              value: MoneyText(
                balance.amountCents,
                colored: true,
                style: theme.textTheme.titleLarge,
              ),
              caption: l10n.homeBalanceAsOf(Dates.display(balance.asOf)),
              onTap: () => unawaited(open(AppRoutes.balances)),
            ),
          const SizedBox(width: 8),
          tile(
            label: l10n.homeMonthEnd,
            value: projected == null
                ? Text('—', style: theme.textTheme.titleLarge)
                : MoneyText(
                    projected.closingCents,
                    colored: true,
                    style: theme.textTheme.titleLarge,
                  ),
            caption: l10n.homeMonthEndCaption,
            onTap: () => context.go(AppRoutes.projection),
          ),
        ],
      ),
    );
  }
}

class _WhereMoneyGoes extends StatelessWidget {
  const new({required this.summary});

  static const slices = 5;

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = FinanceColors.of(context).categories.values.toList();
    final amounts = summary.expenseByCategory;
    final total = summary.expenses.totalCents;
    final shown = [
      for (final amount in amounts.take(slices))
        (
          categoryKeyLabel(
            l10n,
            amount.categoryKey,
            fallback: amount.categoryKey,
          ),
          amount.amountCents,
        ),
      if (amounts.length > slices)
        (
          l10n.homeOtherCategories,
          amounts
              .skip(slices)
              .fold(0, (sum, amount) => sum + amount.amountCents),
        ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.homeWhereMoneyGoes, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (total == 0)
              Text(l10n.homeNoExpenses)
            else ...[
              Row(
                children: [
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 34,
                        sectionsSpace: 2,
                        startDegreeOffset: -90,
                        sections: [
                          for (final (index, (_, cents)) in shown.indexed)
                            PieChartSectionData(
                              value: cents.toDouble(),
                              color: palette[index % palette.length],
                              radius: 20,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        for (final (index, (label, cents)) in shown.indexed)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: palette[index % palette.length],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text('${(cents * 100 / total).round()}%'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  Chip(
                    label: Text(
                      l10n.projectionMonthFixed(
                        Money.format(summary.fixedCents),
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      l10n.projectionMonthVariable(
                        Money.format(summary.variableCents),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DueShortcut extends StatelessWidget {
  const new({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = summary.upcoming.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.event_outlined),
        title: Text(l10n.homeDueShortcut(count)),
        subtitle: count == 0 ? null : Text(Money.format(summary.upcomingCents)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(AppRoutes.due),
      ),
    );
  }
}
