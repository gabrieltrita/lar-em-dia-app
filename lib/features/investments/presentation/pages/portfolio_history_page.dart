import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/empty_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/core/widgets/money_text.dart';
import 'package:lar_em_dia/core/widgets/skeleton.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/evolution_chart.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/investments_disclaimer.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class PortfolioHistoryPage extends StatelessWidget {
  const new({super.key});

  static final _month = DateFormat.yMMM('pt_BR');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.investmentsEvolution)),
      bottomNavigationBar: const InvestmentsDisclaimer(),
      body: BlocBuilder<PortfolioHistoryCubit, LoadState<List<PortfolioMonth>>>(
        builder: (context, state) => switch (state) {
          Loading() => SkeletonList(label: l10n.loadingLabel),
          LoadFailure(:final error) => RetryMessage(
            message: error.localized(l10n),
            onRetry: () =>
                unawaited(context.read<PortfolioHistoryCubit>().load()),
          ),
          Loaded(value: final months) when months.isEmpty => EmptyState(
            icon: Icons.show_chart,
            title: l10n.investmentsHistoryEmpty,
            message: l10n.investmentsHistoryEmptyMessage,
          ),
          Loaded(value: final months) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 16,
                children: [
                  for (final (color, label) in [
                    (theme.colorScheme.primary, l10n.investmentsNetWorth),
                    (theme.colorScheme.outline, l10n.investmentsContributed),
                  ])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 10, color: color),
                        const SizedBox(width: 6),
                        Text(label, style: theme.textTheme.bodySmall),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 240,
                child: EvolutionChart(
                  months: months,
                  semanticsLabel: l10n.investmentsEvolutionChart,
                ),
              ),
              const SizedBox(height: 24),
              Table(
                columnWidths: const {0: FlexColumnWidth(1.2)},
                children: [
                  TableRow(
                    children: [
                      for (final label in [
                        l10n.investmentsMonth,
                        l10n.investmentsContributed,
                        l10n.investmentsNetWorth,
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            label,
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                    ],
                  ),
                  for (final month in months.reversed)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(_month.format(month.month)),
                        ),
                        MoneyText(month.contributedCents),
                        MoneyText(month.marketValueCents),
                      ],
                    ),
                ],
              ),
            ],
          ),
        },
      ),
    );
  }
}
