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
import 'package:lar_em_dia/features/investments/domain/distribution.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/investments_disclaimer.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class PassiveIncomePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.incomeTitle)),
      bottomNavigationBar: const InvestmentsDisclaimer(),
      body: BlocBuilder<PassiveIncomeCubit, LoadState<PassiveIncome>>(
        builder: (context, state) => switch (state) {
          Loading() => SkeletonList(label: l10n.loadingLabel),
          LoadFailure(:final error) => RetryMessage(
            message: error.localized(l10n),
            onRetry: () => unawaited(context.read<PassiveIncomeCubit>().load()),
          ),
          Loaded(value: final income) when income.isEmpty => EmptyState(
            icon: Icons.payments_outlined,
            title: l10n.incomeEmptyTitle,
            message: l10n.incomeEmptyMessage,
          ),
          Loaded(value: final income) => _IncomeContent(income: income),
        },
      ),
    );
  }
}

class _IncomeContent extends StatelessWidget {
  const new({required this.income});

  final PassiveIncome income;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget title(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.incomeMonthlyAverage,
                style: theme.textTheme.labelLarge,
              ),
              MoneyText(
                income.monthlyAverageCents,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.incomeReceived12m(
                  MoneyText.format(income.received12mCents),
                ),
              ),
            ],
          ),
        ),
        title(l10n.incomeReceivedTitle),
        _MonthBars(months: income.received.reversed.toList()),
        title(l10n.incomeForecastTitle),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.incomeForecastHint,
            style: theme.textTheme.bodySmall,
          ),
        ),
        _MonthBars(months: income.forecast),
        title(l10n.incomeByAssetTitle),
        for (final position in income.positions)
          ListTile(
            title: Text(position.ticker),
            subtitle: Text(
              l10n.incomeAssetForecast(
                MoneyText.format(position.monthlyForecastCents),
              ),
            ),
            trailing: MoneyText(position.received12mCents),
          ),
      ],
    );
  }
}

class _MonthBars extends StatelessWidget {
  const new({required this.months});

  static final _format = DateFormat.yMMM('pt_BR');

  final List<IncomeMonth> months;

  @override
  Widget build(BuildContext context) {
    final largest = months.fold(
      0,
      (most, month) => month.amountCents > most ? month.amountCents : most,
    );
    return Column(
      children: [
        for (final month in months)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 88, child: Text(_format.format(month.month))),
                Expanded(
                  child: LinearProgressIndicator(
                    value: largest == 0 ? 0 : month.amountCents / largest,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(
                  width: 112,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: MoneyText(month.amountCents),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
