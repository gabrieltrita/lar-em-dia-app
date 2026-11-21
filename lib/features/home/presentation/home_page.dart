import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/layout/breakpoints.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/core/widgets/money_text.dart';
import 'package:lar_em_dia/core/widgets/month_switcher.dart';
import 'package:lar_em_dia/core/widgets/skeleton.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_label.dart';
import 'package:lar_em_dia/features/home/presentation/cubits/home_cubit.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/cash_flow_chart.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/negative_months_alert.dart';
import 'package:lar_em_dia/features/reserve/presentation/widgets/reserve_card.dart';
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
            onRefresh: () {
              context.read<FinanceChanges>().refresh();
              return cubit.load(quiet: true);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
              children: [
                MonthSwitcher(
                  month: summary.month,
                  onPrevious: () => unawaited(cubit.previous()),
                  onNext: () => unawaited(cubit.next()),
                ),
                _HomeLayout(summary: summary),
              ],
            ),
          ),
        },
      ),
    );
  }
}

class _HomeLayout extends StatelessWidget {
  const new({required this.summary});

  final HomeSummary summary;

  static const _gap = SizedBox(height: 12, width: 20);

  @override
  Widget build(BuildContext context) {
    final alert = switch (summary) {
      HomeSummary(:final firstNegativeMonth?, :final negativeMonthsCount) =>
        NegativeMonthsAlert(
          firstMonth: firstNegativeMonth,
          count: negativeMonthsCount,
          onTap: () => context.go(AppRoutes.projection),
        ),
      _ => null,
    };
    final main = [
      _MonthHero(summary: summary),
      _gap,
      _Indicators(summary: summary),
      _gap,
      const _AllocationShortcut(),
      const ReserveCardView(padding: EdgeInsets.only(bottom: 12)),
      if (summary.months.isNotEmpty) _ForecastCard(months: summary.months),
    ];
    final side = [
      const _QuickActions(),
      _gap,
      if (alert != null) ...[alert, _gap],
      _WhereMoneyGoes(summary: summary),
      _gap,
      _DueShortcut(summary: summary),
    ];
    if (!Breakpoints.isDesktop(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          main.first,
          _gap,
          ...side.take(2),
          ...main.skip(2).take(4),
          ...side.skip(2),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: main,
          ),
        ),
        _gap,
        SizedBox(
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: side,
          ),
        ),
      ],
    );
  }
}

class _ForecastCard extends StatefulWidget {
  const new({required this.months});

  final List<ProjectionMonth> months;

  @override
  State<_ForecastCard> createState() => _ForecastCardState();
}

class _ForecastCardState extends State<_ForecastCard> {
  var _selected = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selected = _selected.clamp(0, widget.months.length - 1);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.homeForecastTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.projection),
                  child: Text(l10n.homeSeeProjection),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: CashFlowChart(
                months: widget.months,
                selected: selected,
                semanticsLabel: l10n.projectionCashFlowLabel,
                onSelect: (index) => setState(() => _selected = index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    final changes = context.read<FinanceChanges>();
    Future<void> open(String route) async {
      final saved = await context.push<bool>(route);
      if (saved ?? false) {
        changes.notify();
      }
    }

    return Row(
      children: [
        for (final (icon, color, label, route) in [
          (
            Icons.south_east,
            colors.negative,
            l10n.entryKindExpense,
            AppRoutes.entryForm(EntryKind.expense),
          ),
          (
            Icons.north_east,
            colors.positive,
            l10n.entryKindIncome,
            AppRoutes.entryForm(EntryKind.income),
          ),
          (
            Icons.account_balance_wallet_outlined,
            theme.colorScheme.primary,
            l10n.homeActionBalance,
            AppRoutes.balanceForm,
          ),
          (
            Icons.science_outlined,
            theme.colorScheme.primary,
            l10n.simulationTitle,
            AppRoutes.simulation,
          ),
        ])
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => unawaited(open(route)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Icon(icon, color: color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: theme.textTheme.labelMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
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
    const onHero = Colors.white;
    final label = theme.textTheme.bodySmall?.copyWith(
      color: onHero.withValues(alpha: 0.9),
    );
    Widget bar(String text, int cents, double alpha) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(text, style: label)),
              MoneyText(
                cents,
                style: label?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: largest == 0 ? 0 : cents / largest,
              minHeight: 8,
              color: onHero.withValues(alpha: alpha),
              backgroundColor: onHero.withValues(alpha: 0.22),
            ),
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: colors.heroGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.homeMonthResultTitle(month), style: label),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  result < 0 ? Icons.trending_down : Icons.trending_up,
                  color: onHero,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MoneyText(
                    result,
                    signed: true,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: onHero,
                    ),
                  ),
                ),
              ],
            ),
            bar(l10n.projectionWaterfallIncome, income, 1),
            bar(l10n.homeExpensesLabel, expense, 0.6),
            const SizedBox(height: 12),
            Text(
              l10n.homeMonthResultSentence(
                '${result >= 0}',
                Money.format(result.abs()),
                Dates.display(Dates.lastOfMonth(summary.month)),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(color: onHero),
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
    final categories = FinanceColors.of(context).categories;
    final palette = [
      for (final group in CategoryGroup.values)
        if (group != CategoryGroup.income) categories[group]!,
    ];
    final amounts = summary.expenseByCategory;
    final total = summary.expenses.totalCents;
    final shown = [
      for (final amount in amounts.take(slices))
        (
          categoryKeyLabel(
            l10n,
            amount.categoryKey,
            fallback: amount.categoryName ?? amount.categoryKey,
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            centerSpaceRadius: 40,
                            sectionsSpace: 3,
                            startDegreeOffset: -90,
                            sections: [
                              for (final (index, (_, cents)) in shown.indexed)
                                PieChartSectionData(
                                  value: cents.toDouble(),
                                  color: palette[index % palette.length],
                                  radius: 14,
                                  showTitle: false,
                                ),
                            ],
                          ),
                        ),
                        Text(
                          Money.compact(total),
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
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
        onTap: () => unawaited(context.push<void>(AppRoutes.due)),
      ),
    );
  }
}

class _AllocationShortcut extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final changes = context.read<FinanceChanges>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: const Icon(Icons.call_split),
          title: Text(l10n.allocationMoreLink),
          subtitle: Text(l10n.homeAllocationCaption),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await context.push<void>(AppRoutes.allocation);
            changes.notify();
          },
        ),
      ),
    );
  }
}
