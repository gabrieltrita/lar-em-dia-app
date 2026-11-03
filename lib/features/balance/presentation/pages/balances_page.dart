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
import 'package:lar_em_dia/features/balance/domain/balance.dart';
import 'package:lar_em_dia/features/balance/presentation/cubits/balance_cubits.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class BalancesPage extends StatelessWidget {
  const new({super.key});

  Future<void> _open(BuildContext context, [Balance? balance]) async {
    final cubit = context.read<BalancesCubit>();
    final saved = await context.push<bool>(
      AppRoutes.balanceForm,
      extra: balance,
    );
    if (saved ?? false) {
      await cubit.load();
    }
  }

  Future<void> _delete(BuildContext context, Balance balance) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<BalancesCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDeletion(
      context,
      title: l10n.balanceDeleteTitle,
      message: l10n.balanceDeleteMessage(Dates.display(balance.asOf)),
    );
    if (!confirmed) {
      return;
    }
    final error = await cubit.delete(balance);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error.localized(l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.balancesTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.balanceFormNewTitle,
        onPressed: () => unawaited(_open(context)),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<BalancesCubit, LoadState<List<Balance>>>(
        builder: (context, state) => switch (state) {
          Loading() => const Center(child: CircularProgressIndicator()),
          LoadFailure(:final error) => RetryMessage(
            message: error.localized(l10n),
            onRetry: () => unawaited(context.read<BalancesCubit>().load()),
          ),
          Loaded(value: final balances) when balances.isEmpty => Center(
            child: Text(l10n.balancesEmpty),
          ),
          Loaded(value: final balances) => ListView.separated(
            itemCount: balances.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final balance = balances[index];
              return ListTile(
                title: Text(Money.format(balance.amountCents)),
                subtitle: Text(Dates.display(balance.asOf)),
                onTap: () => unawaited(_open(context, balance)),
                trailing: IconButton(
                  tooltip: l10n.delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => unawaited(_delete(context, balance)),
                ),
              );
            },
          ),
        },
      ),
    );
  }
}
