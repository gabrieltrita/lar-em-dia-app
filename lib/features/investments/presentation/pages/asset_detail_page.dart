import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/per_share.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/confirm_dialog.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/core/widgets/money_text.dart';
import 'package:lar_em_dia/core/widgets/skeleton.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/investment_form_page.dart';
import 'package:lar_em_dia/features/investments/presentation/pages/investments_page.dart';
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
