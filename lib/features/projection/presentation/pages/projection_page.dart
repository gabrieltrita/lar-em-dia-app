import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/core/widgets/skeleton.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/cubits/projection_cubit.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/cash_flow_chart.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/negative_months_alert.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/projection_summary.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class ProjectionPage extends StatelessWidget {
  const new({super.key});

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
    final cubit = context.read<ProjectionCubit>();
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.projectionTitle),
        actions: [
          IconButton(
            tooltip: l10n.simulationButton,
            icon: const Icon(Icons.science_outlined),
            onPressed: () => unawaited(_simulate(context)),
          ),
        ],
      ),
      body: BlocBuilder<ProjectionCubit, ProjectionState>(
        builder: (context, state) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: PeriodSelector(
                  selected: state.period,
                  onSelected: (period) => unawaited(cubit.selectPeriod(period)),
                ),
              ),
            ),
            Expanded(
              child: switch (state.data) {
                Loading() => SkeletonList(label: l10n.loadingLabel),
                LoadFailure(:final error) => RetryMessage(
                  message: error.localized(l10n),
                  onRetry: () => unawaited(cubit.load()),
                ),
                Loaded(value: Projection(anchor: null)) => const _NoBalance(),
                Loaded(value: final projection) => _ProjectionView(
                  key: ValueKey(projection),
                  projection: projection,
                ),
              },
            ),
          ],
        ),
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

class _ProjectionView extends StatefulWidget {
  const new({required this.projection, super.key});

  final Projection projection;

  @override
  State<_ProjectionView> createState() => _ProjectionViewState();
}

class _ProjectionViewState extends State<_ProjectionView> {
  bool _showBalance = true;
  bool _showFlow = true;
  late int _selected = widget.projection.months.length - 1;
  int? _expanded;

  List<ProjectionMonth> get _months => widget.projection.months;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final projection = widget.projection;
    return RefreshIndicator(
      onRefresh: () => context.read<ProjectionCubit>().load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          ProjectionHero(
            months: _months,
            onSeeMore: () => unawaited(
              context.push<void>(
                AppRoutes.projectionDetails,
                extra: projection,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SeriesLegend(
            showBalance: _showBalance,
            showFlow: _showFlow,
            onBalance: (value) => setState(() => _showBalance = value),
            onFlow: (value) => setState(() => _showFlow = value),
          ),
          const SizedBox(height: 12),
          MonthReadout(month: _months[_selected]),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: CashFlowChart(
              months: _months,
              selected: _selected,
              showBalance: _showBalance,
              showFlow: _showFlow,
              semanticsLabel: l10n.projectionCashFlowLabel,
              onSelect: (index) => setState(() => _selected = index),
            ),
          ),
          if (projection.firstNegativeMonth case final first?) ...[
            const SizedBox(height: 16),
            NegativeMonthsAlert(
              firstMonth: first,
              count: projection.negativeMonthsCount,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            l10n.projectionMonthsTitle.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          for (final (index, month) in _months.indexed) ...[
            const Divider(height: 1),
            MonthSummaryTile(
              month: month,
              expanded: _expanded == index,
              onTap: () =>
                  setState(() => _expanded = _expanded == index ? null : index),
            ),
          ],
        ],
      ),
    );
  }
}
