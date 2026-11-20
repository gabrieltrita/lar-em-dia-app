import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/confirm_dialog.dart';
import 'package:lar_em_dia/core/widgets/empty_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/core/widgets/money_text.dart';
import 'package:lar_em_dia/core/widgets/month_switcher.dart';
import 'package:lar_em_dia/core/widgets/skeleton.dart';
import 'package:lar_em_dia/features/allocation/domain/allocation.dart';
import 'package:lar_em_dia/features/allocation/presentation/cubits/allocation_cubits.dart';
import 'package:lar_em_dia/features/allocation/presentation/widgets/allocation_labels.dart';
import 'package:lar_em_dia/features/allocation/presentation/widgets/use_allocation_dialog.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class AllocationPage extends StatelessWidget {
  const new({super.key, this.today});

  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.watch<AllocationCubit>();
    final state = cubit.state;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.allocationTitle)),
      floatingActionButton: switch (state.view) {
        Loaded(:final value) when value.targets.isNotEmpty =>
          FloatingActionButton.extended(
            heroTag: null,
            icon: const Icon(Icons.add),
            label: Text(l10n.allocationNewTarget),
            onPressed: () => unawaited(openTargetForm(context, value)),
          ),
        _ => null,
      },
      body: Column(
        children: [
          MonthSwitcher(
            month: state.month,
            onPrevious: () => unawaited(cubit.previous()),
            onNext: () => unawaited(cubit.next()),
          ),
          Expanded(
            child: switch (state.view) {
              Loading() => SkeletonList(label: l10n.loadingLabel),
              LoadFailure(:final error) => RetryMessage(
                message: error.localized(l10n),
                onRetry: () => unawaited(cubit.load()),
              ),
              Loaded(:final value) when value.targets.isEmpty => EmptyState(
                icon: Icons.call_split,
                title: l10n.allocationEmptyTitle,
                message: l10n.allocationEmptyMessage,
                actionLabel: l10n.allocationNewTarget,
                onAction: () => unawaited(openTargetForm(context, value)),
              ),
              Loaded(:final value) => _AllocationContent(
                view: value,
                canUse: !state.month.isAfter(
                  Dates.firstOfMonth(today ?? DateTime.now()),
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

Future<void> openTargetForm(
  BuildContext context,
  AllocationView view, {
  AllocationTarget? existing,
}) async {
  final changes = context.read<FinanceChanges>();
  final saved = await context.push<bool>(
    AppRoutes.allocationTargetForm,
    extra: AllocationTargetFormArgs(
      accounts: view.accounts,
      existing: existing,
      remainderTaken: view.targets.any(
        (target) =>
            target.mode == AllocationMode.remainder &&
            target.id != existing?.id,
      ),
    ),
  );
  if (saved ?? false) {
    changes.notify();
  }
}

class _AllocationContent extends StatelessWidget {
  const new({required this.view, required this.canUse});

  final AllocationView view;
  final bool canUse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plan = view.plan;
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _Summary(plan: plan),
        if (plan.baseCents <= 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InfoMessage(l10n.allocationNothingToSplit),
          ),
        if (!canUse)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InfoMessage(l10n.allocationFutureMonth),
          ),
        for (final item in plan.items)
          _ItemTile(item: item, view: view, canUse: canUse),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const new({required this.plan});

  final AllocationPlan plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget row(String label, int cents, {bool colored = false}) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          MoneyText(cents, colored: colored),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.allocationBase, style: theme.textTheme.labelLarge),
            MoneyText(
              plan.baseCents,
              colored: true,
              style: theme.textTheme.headlineSmall,
            ),
            Text(
              l10n.allocationBaseHelper,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            row(l10n.allocationUsed, plan.usedCents),
            row(l10n.allocationClosing, plan.closingCents, colored: true),
            row(l10n.allocationUnallocated, plan.unallocatedCents),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const new({required this.item, required this.view, required this.canUse});

  final AllocationItem item;
  final AllocationView view;
  final bool canUse;

  void Function(ApiError?) _reporter(BuildContext context) {
    final changes = context.read<FinanceChanges>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    return (error) {
      if (error == null) {
        changes.notify();
        return;
      }
      messenger.showSnackBar(SnackBar(content: Text(error.localized(l10n))));
    };
  }

  Future<void> _toggle(BuildContext context) async {
    final cubit = context.read<AllocationCubit>();
    final report = _reporter(context);
    final l10n = AppLocalizations.of(context);
    if (item.used) {
      final confirmed = await confirmAction(
        context,
        title: l10n.allocationUndoTitle,
        message: l10n.allocationUndoMessage(item.name),
        confirmLabel: l10n.allocationUndoConfirm,
      );
      if (confirmed) {
        report(await cubit.undo(item));
      }
      return;
    }
    final amount = await showUseAllocationDialog(
      context,
      item: item,
      reserve: item.reserveAccountId != null,
    );
    if (amount != null) {
      report(await cubit.use(item, amountCents: amount));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AllocationCubit>();
    final report = _reporter(context);
    final confirmed = await confirmDeletion(
      context,
      title: l10n.allocationDeleteTitle,
      message: l10n.allocationDeleteMessage,
    );
    if (confirmed) {
      report(await cubit.deleteTarget(item.targetId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = view.accountName(item.reserveAccountId);
    final target = view.target(item.targetId);
    return ListTile(
      leading: Checkbox(
        key: Key('allocation_use_${item.targetId}'),
        value: item.used,
        onChanged: canUse || item.used
            ? (_) => unawaited(_toggle(context))
            : null,
      ),
      title: Text(item.name),
      subtitle: Text(
        [
          item.describe(l10n, target),
          if (account != null) l10n.allocationReserveSummary(account),
          if (item.usedOn case final usedOn?)
            l10n.allocationUsedOn(Dates.display(usedOn)),
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            Money.format(item.amountCents),
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          PopupMenuButton<bool>(
            key: Key('allocation_menu_${item.targetId}'),
            onSelected: (delete) => unawaited(
              delete
                  ? _delete(context)
                  : openTargetForm(context, view, existing: target),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(value: false, child: Text(l10n.allocationEdit)),
              PopupMenuItem(value: true, child: Text(l10n.delete)),
            ],
          ),
        ],
      ),
    );
  }
}
