import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/confirm_dialog.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/core/widgets/money_text.dart';
import 'package:lar_em_dia/core/widgets/skeleton.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/reserve/presentation/cubits/reserve_cubits.dart';
import 'package:lar_em_dia/features/reserve/presentation/pages/reserve_movement_form_page.dart';
import 'package:lar_em_dia/features/reserve/presentation/pages/reserve_page.dart';
import 'package:lar_em_dia/features/reserve/presentation/widgets/reserve_disclaimer.dart';
import 'package:lar_em_dia/features/reserve/presentation/widgets/reserve_labels.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

enum _AccountAction { edit, delete }

class ReserveAccountPage extends StatelessWidget {
  const new({super.key});

  Future<void> _deleteMovement(
    BuildContext context,
    ReserveMovement movement,
  ) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ReserveAccountCubit>();
    final confirmed = await confirmDeletion(
      context,
      title: l10n.reserveMovementDeleteTitle,
      message: l10n.reserveMovementDeleteMessage(
        movement.kind.label(l10n),
        Dates.display(movement.movedOn),
      ),
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final error = await cubit.deleteMovement(movement);
    if (context.mounted) {
      reportReserveError(context, error);
    }
  }

  Future<void> _deleteAccount(
    BuildContext context,
    ReserveAccount account,
  ) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ReserveAccountCubit>();
    final changes = context.read<FinanceChanges>();
    final confirmed = await confirmDeletion(
      context,
      title: l10n.reserveAccountDeleteTitle,
      message: l10n.reserveAccountDeleteMessage(account.name),
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final error = await cubit.deleteAccount();
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      reportReserveError(context, error);
      return;
    }
    context.pop();
    changes.notify();
  }

  void _onAction(
    BuildContext context,
    ReserveAccount account,
    _AccountAction action,
  ) => switch (action) {
    _AccountAction.edit => unawaited(
      openReserveForm(context, AppRoutes.reserveAccountForm, extra: account),
    ),
    _AccountAction.delete => unawaited(_deleteAccount(context, account)),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.watch<ReserveAccountCubit>();
    final state = cubit.state;
    final detail = switch (state) {
      Loaded(:final value) => value,
      _ => null,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(detail?.account.name ?? l10n.reserveTitle),
        actions: [
          if (detail != null)
            PopupMenuButton<_AccountAction>(
              key: const Key('reserve_account_menu'),
              onSelected: (action) =>
                  _onAction(context, detail.account, action),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _AccountAction.edit,
                  child: Text(l10n.edit),
                ),
                PopupMenuItem(
                  value: _AccountAction.delete,
                  child: Text(l10n.reserveAccountDelete),
                ),
              ],
            ),
        ],
      ),
      bottomNavigationBar: const ReserveDisclaimer(),
      floatingActionButton: detail == null
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              icon: const Icon(Icons.add),
              label: Text(l10n.reserveRegisterMovement),
              onPressed: () => unawaited(
                openReserveForm(
                  context,
                  AppRoutes.reserveMovementForm,
                  extra: ReserveMovementFormArgs(
                    accounts: [detail.account],
                    accountId: detail.account.id,
                  ),
                ),
              ),
            ),
      body: switch (state) {
        Loading() => SkeletonList(label: l10n.loadingLabel),
        LoadFailure(:final error) => RetryMessage(
          message: error.localized(l10n),
          onRetry: () => unawaited(cubit.load()),
        ),
        Loaded(value: final detail) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
          children: [
            Text(detail.account.description(l10n)),
            const SizedBox(height: 16),
            _AccountFigures(value: detail.account.value),
            const SizedBox(height: 24),
            Text(
              l10n.reserveMovementsTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (detail.movements.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.reserveMovementsEmpty),
              ),
            for (final movement in detail.movements)
              _MovementTile(
                movement: movement,
                onTap: () => unawaited(
                  openReserveForm(
                    context,
                    AppRoutes.reserveMovementForm,
                    extra: ReserveMovementFormArgs(
                      accounts: [detail.account],
                      existing: movement,
                    ),
                  ),
                ),
                onDelete: () => unawaited(_deleteMovement(context, movement)),
              ),
          ],
        ),
      },
    );
  }
}

class _AccountFigures extends StatelessWidget {
  const new({required this.value});

  final ReserveValue value;

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
        MoneyText(value.netCents, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            figure(l10n.reserveGross, value.grossCents),
            figure(l10n.reserveInvested, value.investedCents),
            figure(l10n.reserveYield, value.yieldCents),
            figure(l10n.reserveTax, value.taxCents),
          ],
        ),
      ],
    );
  }
}

class _MovementTile extends StatelessWidget {
  const new({
    required this.movement,
    required this.onTap,
    required this.onDelete,
  });

  final ReserveMovement movement;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signed = movement.kind == ReserveMovementKind.withdrawal
        ? -movement.amountCents
        : movement.amountCents;
    return ListTile(
      key: Key('reserve_movement_${movement.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(movement.kind.label(l10n)),
      subtitle: Text(
        [
          Dates.display(movement.movedOn),
          if (movement.changesBalance) l10n.reserveMovementLinked,
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(Money.format(signed)),
          IconButton(
            tooltip: l10n.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
