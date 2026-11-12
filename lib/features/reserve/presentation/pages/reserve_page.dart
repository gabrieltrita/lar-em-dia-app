import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/rates.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/core/widgets/money_text.dart';
import 'package:lar_em_dia/core/widgets/skeleton.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/reserve/presentation/cubits/reserve_cubits.dart';
import 'package:lar_em_dia/features/reserve/presentation/pages/reserve_goal_sheet.dart';
import 'package:lar_em_dia/features/reserve/presentation/pages/reserve_movement_form_page.dart';
import 'package:lar_em_dia/features/reserve/presentation/widgets/coverage_bar.dart';
import 'package:lar_em_dia/features/reserve/presentation/widgets/reserve_chart.dart';
import 'package:lar_em_dia/features/reserve/presentation/widgets/reserve_disclaimer.dart';
import 'package:lar_em_dia/features/reserve/presentation/widgets/reserve_labels.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

Future<void> openReserveForm(
  BuildContext context,
  String path, {
  Object? extra,
}) async {
  final changes = context.read<FinanceChanges>();
  final saved = await context.push<bool>(path, extra: extra);
  if (saved ?? false) {
    changes.notify();
  }
}

void reportReserveError(BuildContext context, ApiError? error) {
  if (error == null) {
    context.read<FinanceChanges>().notify();
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(error.localized(AppLocalizations.of(context)))),
  );
}

class ReservePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.watch<ReserveCubit>();
    final state = cubit.state;
    final accounts = switch (state) {
      Loaded(:final value) => value.summary.accounts,
      _ => const <ReserveAccount>[],
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reserveTitle)),
      bottomNavigationBar: const ReserveDisclaimer(),
      floatingActionButton: accounts.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              icon: const Icon(Icons.add),
              label: Text(l10n.reserveRegisterMovement),
              onPressed: () => unawaited(
                openReserveForm(
                  context,
                  AppRoutes.reserveMovementForm,
                  extra: ReserveMovementFormArgs(accounts: accounts),
                ),
              ),
            ),
      body: switch (state) {
        Loading() => SkeletonList(label: l10n.loadingLabel),
        LoadFailure(:final error) => RetryMessage(
          message: error.localized(l10n),
          onRetry: () => unawaited(cubit.load()),
        ),
        Loaded(:final value) when value.summary.isEmpty => _EmptyReserve(
          summary: value.summary,
        ),
        Loaded(:final value) => _ReserveContent(view: value),
      },
    );
  }
}

class _EmptyReserve extends StatelessWidget {
  const new({required this.summary});

  final ReserveSummary summary;

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
            CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              child: Icon(
                Icons.savings_outlined,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.reserveEmptyTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              switch (summary.suggestion) {
                final suggestion? => l10n.reserveEmptyWithSuggestion(
                  Money.format(suggestion.averageFixedCents),
                ),
                null => l10n.reserveEmptyMessage,
              },
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.reserveEmptyAction),
              onPressed: () => unawaited(
                openReserveForm(context, AppRoutes.reserveAccountForm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReserveContent extends StatelessWidget {
  const new({required this.view});

  final ReserveView view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = view.summary;
    return RefreshIndicator(
      onRefresh: () => context.read<ReserveCubit>().load(quiet: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          _Totals(totals: summary.totals),
          const SizedBox(height: 16),
          _Goal(summary: summary),
          if (summary.has(ReserveAlert.belowSuggestion))
            if (summary.goal.targetCents case final target?) ...[
              const SizedBox(height: 12),
              InfoMessage(l10n.reserveBelowTarget(Money.format(target))),
            ],
          if (summary.has(ReserveAlert.idleMoney)) ...[
            const SizedBox(height: 12),
            InfoMessage(l10n.reserveIdleMoney),
          ],
          const SizedBox(height: 24),
          Text(
            l10n.reserveAccountsTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final account in summary.accounts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(account.name),
              subtitle: Text(account.description(l10n)),
              trailing: MoneyText(account.value.netCents),
              onTap: () => unawaited(
                context.push<void>(AppRoutes.reserveAccount(account.id)),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l10n.reserveNewAccount),
              onPressed: () => unawaited(
                openReserveForm(context, AppRoutes.reserveAccountForm),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ProjectionSection(view: view),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const new({required this.totals});

  final ReserveValue totals;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget figure(String label, int cents) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 2),
        MoneyText(cents),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.reserveNetTotal, style: theme.textTheme.labelLarge),
        MoneyText(totals.netCents, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            figure(l10n.reserveGross, totals.grossCents),
            figure(l10n.reserveYield, totals.yieldCents),
            figure(l10n.reserveTax, totals.taxCents),
          ],
        ),
      ],
    );
  }
}

class _Goal extends StatelessWidget {
  const new({required this.summary});

  final ReserveSummary summary;

  Future<void> _adjust(BuildContext context) async {
    final cubit = context.read<ReserveCubit>();
    final choice = await showReserveGoalSheet(context, summary.goal);
    if (choice == null || !context.mounted) {
      return;
    }
    final error = await cubit.updateGoal(
      months: choice.months,
      cents: choice.cents,
    );
    if (context.mounted) {
      reportReserveError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final goal = summary.goal;
    final suggestion = summary.suggestion;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(switch ((goal.cents, suggestion)) {
              (final cents?, _) => l10n.reserveOwnGoal(Money.format(cents)),
              (null, final suggestion?) => l10n.reserveSuggestion(
                Money.format(suggestion.suggestedCents),
                suggestion.goalMonths,
                Money.format(suggestion.averageFixedCents),
              ),
              (null, null) => l10n.reserveNoSuggestion,
            }),
            if (suggestion != null) ...[
              const SizedBox(height: 8),
              CoverageBar(
                coverageMonthsE2: suggestion.coverageMonthsE2,
                goalMonths: goal.months,
              ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => unawaited(_adjust(context)),
                child: Text(l10n.reserveAdjustGoal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectionSection extends StatelessWidget {
  const new({required this.view});

  final ReserveView view;

  static String _assumptions(
    AppLocalizations l10n,
    ReserveAssumptions assumptions,
  ) => switch (assumptions) {
    ReserveAssumptions(
      selicTargetE8: final selic?,
      cdiEstimateE8: final cdi?,
      ratesAsOf: final asOf?,
    ) =>
      l10n.reserveAssumptions(
        Rates.percentFromE8(selic),
        Rates.percentFromE8(cdi),
        Dates.display(asOf),
      ),
    _ => l10n.reserveRatesMissing,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final months = view.projection.months;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.reserveProjectionTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<ReservePeriod>(
          segments: [
            for (final period in ReservePeriod.values)
              ButtonSegment(
                value: period,
                label: Text(l10n.reservePeriodYears(period.months ~/ 12)),
              ),
          ],
          selected: {view.period},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => unawaited(
            context.read<ReserveCubit>().selectPeriod(selection.first),
          ),
        ),
        if (months.length > 1) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ReserveChart(
              months: months,
              semanticsLabel: l10n.reserveProjectionChart,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.reserveProjectionEnd(
              Money.format(months.last.grossCents),
              Money.format(months.last.netCents),
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          _assumptions(l10n, view.projection.assumptions),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
