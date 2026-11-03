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
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/cubits/projection_cubit.dart';
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
          Loading() => const Center(child: CircularProgressIndicator()),
          LoadFailure(:final error) => RetryMessage(
            message: error.localized(l10n),
            onRetry: () => unawaited(cubit.load()),
          ),
          Loaded(value: Projection(anchor: null)) => const _NoBalance(),
          Loaded(value: Projection(:final months, :final anchor?)) =>
            _ProjectionView(anchor: anchor, months: months),
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
  const new({required this.anchor, required this.months});

  final ProjectionAnchor anchor;
  final List<ProjectionMonth> months;

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

class _MonthTile extends StatelessWidget {
  const new({required this.month});

  final ProjectionMonth month;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
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
        ].join('\n'),
      ),
      trailing: Text(
        Money.format(month.closingCents),
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: month.isNegative ? colors.error : null),
      ),
    );
  }
}
