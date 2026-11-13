import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/per_share.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/confirm_dialog.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/core/widgets/money_text.dart';
import 'package:lar_em_dia/core/widgets/skeleton.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/distribution.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
import 'package:lar_em_dia/features/investments/domain/screener.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/distribution_form_page.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/investment_form_page.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/investments_page.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/indicator_labels.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/investment_labels.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/investments_disclaimer.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/position_tile.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class AssetDetailPage extends StatelessWidget {
  const new({super.key});

  Future<void> _report(BuildContext context, Future<ApiError?> change) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final changes = context.read<FinanceChanges>();
    final error = await change;
    if (error == null) {
      changes.notify();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(error.localized(l10n))));
    }
  }

  Future<void> _delete(
    BuildContext context,
    InvestmentTransaction transaction,
  ) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AssetDetailCubit>();
    final confirmed = await confirmDeletion(
      context,
      title: l10n.investmentDeleteTitle,
      message: l10n.investmentDeleteMessage(
        transaction.kind.label(l10n),
        Dates.display(transaction.tradedOn),
      ),
    );
    if (confirmed && context.mounted) {
      await _report(context, cubit.delete(transaction));
    }
  }

  Future<void> _openDistribution(
    BuildContext context,
    DistributionFormArgs args,
  ) async {
    final cubit = context.read<AssetDetailCubit>();
    final changes = context.read<FinanceChanges>();
    final saved = await context.push<bool>(
      AppRoutes.distributionForm,
      extra: args,
    );
    if (saved ?? false) {
      changes.notify();
      await cubit.load(quiet: true);
    }
  }

  Future<void> _deleteDistribution(
    BuildContext context,
    AssetDistribution distribution,
  ) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AssetDetailCubit>();
    final confirmed = await confirmDeletion(
      context,
      title: l10n.distributionDeleteTitle,
      message: l10n.distributionDeleteMessage(
        distribution.kind.label(l10n),
        Dates.display(distribution.recordOn),
      ),
    );
    if (confirmed && context.mounted) {
      await _report(context, cubit.deleteDistribution(distribution));
    }
  }

  static InvestmentFormArgs _args(
    AssetDetail detail, [
    InvestmentTransaction? existing,
  ]) => InvestmentFormArgs(
    existing: existing,
    asset: detail.asset,
    held: {
      if (detail.position case final position?)
        position.ticker: position.quantity,
    },
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.watch<AssetDetailCubit>();
    final state = cubit.state;
    return Scaffold(
      appBar: AppBar(title: Text(cubit.ticker)),
      bottomNavigationBar: const InvestmentsDisclaimer(),
      floatingActionButton: switch (state) {
        Loaded(:final value) => FloatingActionButton.extended(
          heroTag: null,
          icon: const Icon(Icons.add),
          label: Text(l10n.investmentsRegister),
          onPressed: () => unawaited(openInvestmentForm(context, _args(value))),
        ),
        _ => null,
      },
      body: switch (state) {
        Loading() => SkeletonList(label: l10n.loadingLabel),
        LoadFailure(:final error) => RetryMessage(
          message: error.localized(l10n),
          onRetry: () => unawaited(cubit.load()),
        ),
        Loaded(value: final detail) => ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            _Header(detail: detail),
            if (detail.position case final position?) ...[
              _PositionFigures(position: position),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SegmentedButton<InvestmentGoal>(
                  key: const Key('asset_goal'),
                  segments: [
                    for (final goal in InvestmentGoal.values)
                      ButtonSegment(value: goal, label: Text(goal.label(l10n))),
                  ],
                  selected: {position.goal},
                  onSelectionChanged: (selection) => unawaited(
                    _report(context, cubit.changeGoal(selection.first)),
                  ),
                ),
              ),
            ],
            if (detail.asset.fundReport case final report?)
              _FundReportFigures(report: report, quote: detail.asset.quote),
            if (detail.asset.indicators case final indicators?)
              _IndicatorsSection(
                indicators: indicators,
                type: detail.asset.type,
              ),
            _DistributionsSection(
              detail: detail,
              onAdd: () => unawaited(
                _openDistribution(
                  context,
                  DistributionFormArgs(ticker: detail.asset.ticker),
                ),
              ),
              onEdit: (distribution) => unawaited(
                _openDistribution(
                  context,
                  DistributionFormArgs(
                    ticker: detail.asset.ticker,
                    existing: distribution,
                  ),
                ),
              ),
              onDelete: (distribution) =>
                  unawaited(_deleteDistribution(context, distribution)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                l10n.investmentTransactionsTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            if (detail.transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.investmentTransactionsEmpty),
              ),
            for (final transaction in detail.transactions)
              _TransactionTile(
                transaction: transaction,
                onTap: () => unawaited(
                  openInvestmentForm(context, _args(detail, transaction)),
                ),
                onDelete: () => unawaited(_delete(context, transaction)),
              ),
          ],
        ),
      },
    );
  }
}

class _Header extends StatelessWidget {
  const new({required this.detail});

  final AssetDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final asset = detail.asset;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(asset.name, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            [asset.type.label(l10n), ?asset.sector].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(quoteLabel(l10n, asset.quote)),
        ],
      ),
    );
  }
}

class _PositionFigures extends StatelessWidget {
  const new({required this.position});

  final PortfolioPosition position;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget figure(String label, Widget value) => SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          value,
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          figure(
            l10n.investmentFormQuantity,
            Text(l10n.investmentsShares(position.quantity)),
          ),
          figure(
            l10n.investmentsAveragePriceLabel,
            Text(PerShare.formatE8(position.averagePriceE8)),
          ),
          figure(l10n.investmentsCost, MoneyText(position.costCents)),
          figure(
            l10n.investmentsMarketValue,
            MoneyText(position.marketValueCents),
          ),
          figure(
            l10n.investmentsGain,
            Wrap(
              spacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                MoneyText(position.gainCents, signed: true, colored: true),
                GainText(position.gainBps),
              ],
            ),
          ),
          if (position.realizedCents != 0)
            figure(
              l10n.investmentsRealized,
              MoneyText(position.realizedCents, signed: true, colored: true),
            ),
        ],
      ),
    );
  }
}

class _FundReportFigures extends StatelessWidget {
  const new({required this.report, this.quote});

  static final _month = DateFormat.yMMMM('pt_BR');
  static final _grouping = NumberFormat.decimalPattern('pt_BR');

  static String _ratio(int bps) {
    final hundredths = PerShare.roundedDivision(bps, 100);
    final fraction = (hundredths % 100).toString().padLeft(2, '0');
    return '${hundredths ~/ 100},$fraction';
  }

  final FundReport report;
  final AssetQuote? quote;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final priceToBook = switch (quote) {
      final quote? => PerShare.basisPoints(
        quote.closeCents * PerShare.centsToE8,
        report.bookValuePerShareE8,
      ),
      null => null,
    };
    Widget figure(String label, String value) => SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.fundReportTitle(_month.format(report.referenceMonth)),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              figure(
                l10n.fundReportBookValue,
                PerShare.formatE8(report.bookValuePerShareE8),
              ),
              if (priceToBook case final bps?)
                figure(l10n.fundReportPriceToBook, _ratio(bps)),
              figure(
                l10n.fundReportShareholders,
                _grouping.format(report.shareholdersCount),
              ),
              figure(l10n.fundReportEquity, Money.format(report.equityCents)),
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n.fundReportSource, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _IndicatorsSection extends StatelessWidget {
  const new({required this.indicators, required this.type});

  final AssetIndicators indicators;
  final AssetType type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final figures = [
      for (final indicator in Indicator.forType(type))
        if (indicators.value(indicator) case final value?)
          (indicator.label(l10n), indicator.format(l10n, value)),
      if (indicators.distributionAverageE8 case final average?)
        (l10n.indicatorDistributionAverage, PerShare.formatE8(average)),
      if (indicators.distributionMedianE8 case final median?)
        (l10n.indicatorDistributionMedian, PerShare.formatE8(median)),
    ];
    if (figures.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const Key('asset_indicators'),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.indicatorsTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final (label, value) in figures)
                SizedBox(
                  width: 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: theme.textTheme.labelMedium),
                      const SizedBox(height: 2),
                      Text(value),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.indicatorsComputedOn(Dates.display(indicators.computedOn)),
            style: theme.textTheme.bodySmall,
          ),
          if (type == AssetType.stock)
            Text(l10n.indicatorsStockSource, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DistributionsSection extends StatelessWidget {
  const new({
    required this.detail,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final AssetDetail detail;
  final VoidCallback onAdd;
  final ValueChanged<AssetDistribution> onEdit;
  final ValueChanged<AssetDistribution> onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asset = detail.asset;
    final canAdd = asset.type == AssetType.stock && detail.position != null;
    final distributions = asset.distributions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.distributionsTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (canAdd)
                TextButton.icon(
                  key: const Key('distribution_add'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.distributionAdd),
                  onPressed: onAdd,
                ),
            ],
          ),
        ),
        if (distributions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              asset.type == AssetType.stock
                  ? l10n.distributionsEmptyStock
                  : l10n.distributionsEmptyFii,
            ),
          ),
        for (final distribution in distributions)
          ListTile(
            onTap: distribution.manual ? () => onEdit(distribution) : null,
            title: Text(
              '${distribution.kind.label(l10n)} · '
              '${PerShare.formatE8(distribution.netAmountPerShareE8)}',
            ),
            subtitle: Text(
              [
                l10n.distributionRecordOn(Dates.display(distribution.recordOn)),
                if (distribution.paidOn case final paidOn?)
                  l10n.distributionPaidOn(Dates.display(paidOn))
                else
                  l10n.distributionPaidNextMonth,
              ].join(' · '),
            ),
            trailing: distribution.manual
                ? PopupMenuButton<void>(
                    tooltip: l10n.investmentTransactionMenu,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        onTap: () => onDelete(distribution),
                        child: Text(l10n.delete),
                      ),
                    ],
                  )
                : null,
          ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const new({
    required this.transaction,
    required this.onTap,
    required this.onDelete,
  });

  final InvestmentTransaction transaction;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      onTap: onTap,
      title: Text(
        '${transaction.kind.label(l10n)} · '
        '${l10n.investmentsShares(transaction.quantity)}',
      ),
      subtitle: Text(
        [
          Dates.display(transaction.tradedOn),
          if (transaction.priceCents case final price?)
            l10n.investmentTransactionPrice(Money.format(price)),
          if (transaction.changesBalance) l10n.investmentTransactionInBalance,
        ].join(' · '),
      ),
      trailing: PopupMenuButton<void>(
        tooltip: l10n.investmentTransactionMenu,
        itemBuilder: (context) => [
          PopupMenuItem(onTap: onDelete, child: Text(l10n.delete)),
        ],
      ),
    );
  }
}
