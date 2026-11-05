import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/cubits/simulation_cubit.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/negative_months_alert.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/projection_chart.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class SimulationPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<SimulationCubit, SimulationState>(
      listenWhen: (previous, current) =>
          current.committed && !previous.committed ||
          current.commitError != null &&
              previous.commitError != current.commitError,
      listener: (context, state) {
        if (state.committed) {
          context.pop(true);
        } else if (state.commitError case final error?) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.localized(l10n))));
        }
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: Text(l10n.simulationTitle)),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.plans.isEmpty) InfoMessage(l10n.simulationEmpty),
            for (final (index, plan) in state.plans.indexed)
              _PlanTile(index: index, plan: plan),
            const SizedBox(height: 8),
            _AddButtons(full: state.isFull),
            if (state.result case final result?) ...[
              const SizedBox(height: 16),
              _Result(result: result),
            ],
          ],
        ),
        bottomNavigationBar: state.plans.isEmpty
            ? null
            : _Actions(committing: state.committing),
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const new({required this.index, required this.plan});

  final int index;
  final EntryPlan plan;

  String _subtitle(AppLocalizations l10n) {
    final draft = plan.draft;
    final base = l10n.simulationItemSubtitle(
      Money.format(draft.amountCents),
      Dates.display(draft.dueOn),
    );
    return switch (plan) {
      EntryPlan(recurrence: final recurrence?) =>
        '$base · ${l10n.entryRepeatMonths(recurrence.count)}',
      EntryPlan(installments: final installments?) =>
        '$base · ${l10n.entryInstallmentsCount(installments.count)}',
      _ => base,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final income = plan.kind == EntryKind.income;
    return Card(
      child: ListTile(
        leading: Icon(income ? Icons.arrow_downward : Icons.arrow_upward),
        title: Text(plan.draft.description),
        subtitle: Text(_subtitle(l10n)),
        trailing: IconButton(
          tooltip: l10n.simulationRemove,
          icon: const Icon(Icons.close),
          onPressed: () =>
              unawaited(context.read<SimulationCubit>().remove(index)),
        ),
      ),
    );
  }
}

class _AddButtons extends StatelessWidget {
  const new({required this.full});

  final bool full;

  Future<void> _add(BuildContext context, EntryKind kind) async {
    final cubit = context.read<SimulationCubit>();
    final plan = await context.push<EntryPlan>(AppRoutes.simulationEntry(kind));
    if (plan != null) {
      await cubit.add(plan);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (full) {
      return InfoMessage(l10n.simulationLimit(SimulationState.maxPlans));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.remove_circle_outline),
          label: Text(l10n.simulationAddExpense),
          onPressed: () => unawaited(_add(context, EntryKind.expense)),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add_circle_outline),
          label: Text(l10n.simulationAddIncome),
          onPressed: () => unawaited(_add(context, EntryKind.income)),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const new({required this.result});

  final LoadState<ProjectionComparison> result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (result) {
      Loading() => const Center(child: CircularProgressIndicator()),
      LoadFailure(:final error) => RetryMessage(
        message: error.localized(l10n),
        onRetry: () => unawaited(context.read<SimulationCubit>().retry()),
      ),
      Loaded(value: final comparison) => _Comparison(comparison: comparison),
    };
  }
}

class _Comparison extends StatelessWidget {
  const new({required this.comparison});

  final ProjectionComparison comparison;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final simulated = comparison.simulated;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final baselineEnd = comparison.baseline.months.last;
    final simulatedEnd = simulated.months.last;
    final difference = comparison.differenceCents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (simulated.firstNegativeMonth case final first?) ...[
          NegativeMonthsAlert(
            firstMonth: first,
            count: simulated.negativeMonthsCount,
          ),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.simulationEnd(
                    MaterialLocalizations.of(context)
                        .formatMonthYear(simulatedEnd.month),
                  ),
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.simulationBaseline(
                    Money.format(baselineEnd.closingCents),
                  ),
                ),
                Text(
                  l10n.simulationSimulated(
                    Money.format(simulatedEnd.closingCents),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.simulationDifference(Money.format(difference)),
                  style: textTheme.titleMedium?.copyWith(
                    color: difference < 0 ? colors.error : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: ProjectionChart(
            months: simulated.months,
            baseline: comparison.baseline.months,
            semanticsLabel: l10n.simulationChartLabel,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            _Legend(
              color: colors.outline,
              label: l10n.simulationLegendBaseline,
            ),
            _Legend(
              color: colors.primary,
              label: l10n.simulationLegendSimulated,
            ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const new({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 16, height: 3, color: color),
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.labelMedium),
    ],
  );
}

class _Actions extends StatelessWidget {
  const new({required this.committing});

  final bool committing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: committing ? null : () => context.pop(false),
                child: Text(l10n.simulationDiscard),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SubmitButton(
                label: l10n.simulationCommit,
                busy: committing,
                onPressed: () =>
                    unawaited(context.read<SimulationCubit>().commit()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
