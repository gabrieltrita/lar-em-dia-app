import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/core/widgets/money_text.dart';
import 'package:lar_em_dia/core/widgets/skeleton.dart';
import 'package:lar_em_dia/features/investments/domain/distribution.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/investment_form_page.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/evolution_chart.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/goal_split_bar.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/investment_labels.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/investments_disclaimer.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/position_tile.dart';
import 'package:lar_em_dia/features/reserve/presentation/widgets/reserve_card.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

Future<void> openInvestmentForm(
  BuildContext context,
  InvestmentFormArgs args,
) async {
  final changes = context.read<FinanceChanges>();
  final saved = await context.push<bool>(AppRoutes.investmentForm, extra: args);
  if (saved ?? false) {
    changes.notify();
  }
}

class InvestmentsPage extends StatelessWidget {
  const new({super.key});

  static Map<String, int> _held(Portfolio portfolio) => {
    for (final position in portfolio.positions)
      position.ticker: position.quantity,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<PortfolioCubit>().state;
    final loaded = switch (state) {
      Loaded(:final value) when !value.portfolio.isEmpty => value,
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.investmentsTitle),
        actions: [
          IconButton(
            key: const Key('investments_explore'),
            tooltip: l10n.exploreOpen,
            icon: const Icon(Icons.travel_explore),
            onPressed: () => unawaited(context.push<void>(AppRoutes.explore)),
          ),
          IconButton(
            key: const Key('investments_simulator'),
            tooltip: l10n.simulatorOpen,
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () =>
                unawaited(context.push<void>(AppRoutes.investmentSimulator)),
          ),
        ],
      ),
      bottomNavigationBar: const InvestmentsDisclaimer(),
      floatingActionButton: loaded == null
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              icon: const Icon(Icons.add),
              label: Text(l10n.investmentsRegister),
              onPressed: () => unawaited(
                openInvestmentForm(
                  context,
                  InvestmentFormArgs(held: _held(loaded.portfolio)),
                ),
              ),
            ),
      body: switch (state) {
        Loading() => SkeletonList(label: l10n.loadingLabel),
        LoadFailure(:final error) => RetryMessage(
          message: error.localized(l10n),
          onRetry: () => unawaited(context.read<PortfolioCubit>().load()),
        ),
        Loaded(:final value) when value.portfolio.isEmpty =>
          const _EmptyInvestments(),
        Loaded(:final value) => _PortfolioContent(view: value),
      },
    );
  }
}

class _EmptyInvestments extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ReserveCardView(
              alwaysShow: true,
              padding: EdgeInsets.only(bottom: 24),
            ),
            CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              child: Icon(
                Icons.trending_up,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.investmentsEmptyTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.investmentsEmptyMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.investmentsRegisterBuy),
              onPressed: () => unawaited(
                openInvestmentForm(context, const InvestmentFormArgs()),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => unawaited(
                openInvestmentForm(
                  context,
                  const InvestmentFormArgs(existingHoldings: true),
                ),
              ),
              child: Text(l10n.investmentsAlreadyInvested),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioContent extends StatelessWidget {
  const new({required this.view});

  final PortfolioView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final positions = view.visiblePositions;
    return RefreshIndicator(
      onRefresh: () => context.read<PortfolioCubit>().load(quiet: true),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          const ReserveCardView(
            alwaysShow: true,
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
          ),
          _Summary(totals: view.portfolio.totals),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GoalSplitBar(goals: view.portfolio.goals),
          ),
          if (view.income case final income? when !income.isEmpty)
            _IncomeCard(income: income),
          if (view.recentHistory.length > 1) _MiniEvolution(view: view),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SegmentedButton<InvestmentGoal?>(
              segments: [
                ButtonSegment(value: null, label: Text(l10n.investmentsAll)),
                for (final goal in InvestmentGoal.values)
                  ButtonSegment(value: goal, label: Text(goal.label(l10n))),
              ],
              selected: {view.filter},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  context.read<PortfolioCubit>().filter(selection.first),
            ),
          ),
          if (positions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                l10n.investmentsNoPositionsInGoal,
                textAlign: TextAlign.center,
              ),
            ),
          for (final position in positions)
            PositionTile(
              position: position,
              onTap: () => unawaited(
                context.push<void>(AppRoutes.assetDetail(position.ticker)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const new({required this.totals});

  final PortfolioTotals totals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget figure(String label, Widget value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 2),
        value,
      ],
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.investmentsNetWorth, style: theme.textTheme.labelLarge),
          MoneyText(
            totals.marketValueCents,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              figure(
                l10n.investmentsContributed,
                MoneyText(totals.contributedCents),
              ),
              figure(
                l10n.investmentsGain,
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    MoneyText(totals.gainCents, signed: true, colored: true),
                    GainText(totals.gainBps),
                  ],
                ),
              ),
              if (totals.realizedCents != 0)
                figure(
                  l10n.investmentsRealized,
                  MoneyText(totals.realizedCents, signed: true, colored: true),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncomeCard extends StatelessWidget {
  const new({required this.income});

  final PassiveIncome income;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      key: const Key('investments_income'),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(context.push<void>(AppRoutes.passiveIncome)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.incomeTitle, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      l10n.incomeCardAverage(
                        MoneyText.format(income.monthlyAverageCents),
                      ),
                    ),
                    if (income.nextMonthCents case final next?)
                      Text(
                        l10n.incomeCardNext(MoneyText.format(next)),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniEvolution extends StatelessWidget {
  const new({required this.view});

  final PortfolioView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(context.push<void>(AppRoutes.investmentHistory)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.investmentsEvolution,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(l10n.investmentsSeeAll),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 96,
                child: EvolutionChart(
                  months: view.recentHistory,
                  semanticsLabel: l10n.investmentsEvolutionChart,
                  compact: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
