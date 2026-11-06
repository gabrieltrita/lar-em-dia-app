import 'dart:async';

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
import 'package:lar_em_dia/core/widgets/skeleton.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/cubits/projection_cubit.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/negative_months_alert.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/projection_chart.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class ProjectionPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ProjectionCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.projectionTitle)),
      body: BlocBuilder<ProjectionCubit, LoadState<Projection>>(
        builder: (context, state) => switch (state) {
          Loading() => SkeletonList(label: l10n.loadingLabel),
          LoadFailure(:final error) => RetryMessage(
            message: error.localized(l10n),
            onRetry: () => unawaited(cubit.load()),
          ),
          Loaded(value: Projection(anchor: null)) => const _NoBalance(),
          Loaded(value: final projection) => _ProjectionView(
            projection: projection,
            anchor: projection.anchor!,
          ),
        },
      ),
    );
  }
}

class _NoBalance extends StatelessWidget {
  const new();

  Future<void> _informBalance(BuildContext context) async {
    final cubit = context.read<ProjectionCubit>();
    await context.push<bool>(AppRoutes.balanceForm);
    await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoMessage(l10n.projectionNoBalance),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => unawaited(_informBalance(context)),
              child: Text(l10n.homeInformBalance),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectionView extends StatelessWidget {
  const new({required this.projection, required this.anchor});

  final Projection projection;
  final ProjectionAnchor anchor;

  List<ProjectionMonth> get months => projection.months;

  Future<void> _simulate(BuildContext context) async {
    final cubit = context.read<ProjectionCubit>();
    final committed = await context.push<bool>(AppRoutes.simulation);
    if (committed ?? false) {
      await cubit.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: () => context.read<ProjectionCubit>().load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.projectionAnchor(
              Money.format(anchor.amountCents),
              Dates.display(anchor.asOf),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.science_outlined),
              label: Text(l10n.simulationButton),
              onPressed: () => unawaited(_simulate(context)),
            ),
          ),
          const SizedBox(height: 16),
          if (projection.firstNegativeMonth case final first?) ...[
            NegativeMonthsAlert(
              firstMonth: first,
              count: projection.negativeMonthsCount,
            ),
            const SizedBox(height: 16),
          ],
          _SavingsCard(month: months.last),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: ProjectionChart(
              months: months,
              semanticsLabel: l10n.projectionChartLabel,
            ),
          ),
          const SizedBox(height: 16),
          for (final month in months) _MonthTile(month: month),
        ],
      ),
    );
  }
}

class _SavingsCard extends StatelessWidget {
  const new({required this.month});

  final ProjectionMonth month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.projectionSavingsTitle(
                MaterialLocalizations.of(context).formatMonthYear(month.month),
              ),
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            MoneyText(
              month.savingsCents,
              signed: true,
              colored: true,
              style: textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthTile extends StatelessWidget {
  const new({required this.month});

  final ProjectionMonth month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final finance = FinanceColors.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: month.isNegative
          ? Icon(
              Icons.warning_amber,
              color: finance.negative,
              semanticLabel: l10n.projectionNegativeMonth,
            )
          : const SizedBox(width: 24),
      title: Text(
        MaterialLocalizations.of(context).formatMonthYear(month.month),
      ),
      subtitle: Text(
        [
          l10n.projectionMonthFlow(
            Money.format(month.incomeCents),
            Money.format(month.expenseCents),
          ),
          l10n.entriesNatureBreakdown(
            Money.format(month.fixedExpenseCents),
            Money.format(month.variableExpenseCents),
          ),
          l10n.projectionMonthSavings(Money.format(month.savingsCents)),
        ].join('\n'),
      ),
      trailing: MoneyText(
        month.closingCents,
        colored: true,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
