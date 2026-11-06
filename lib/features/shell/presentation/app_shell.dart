import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class AppShell extends StatelessWidget {
  const new({required this.shell, required this.changes, super.key});

  static const tabsWithAdd = {0, 1, 2};

  final StatefulNavigationShell shell;
  final FinanceChanges changes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: RepositoryProvider.value(value: changes, child: shell),
      floatingActionButton: tabsWithAdd.contains(shell.currentIndex)
          ? FloatingActionButton(
              tooltip: l10n.shellAdd,
              onPressed: () => unawaited(showAddSheet(context, changes)),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarTheme.of(context).copyWith(
          labelTextStyle: WidgetStatePropertyAll(
            Theme.of(context).textTheme.labelSmall,
          ),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (index) => shell.goBranch(
            index,
            initialLocation: index == shell.currentIndex,
          ),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l10n.shellHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: l10n.shellEntries,
            ),
            NavigationDestination(
              icon: const Icon(Icons.event_outlined),
              selectedIcon: const Icon(Icons.event),
              label: l10n.shellDue,
            ),
            NavigationDestination(
              icon: const Icon(Icons.show_chart),
              label: l10n.shellProjection,
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu),
              label: l10n.shellMore,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showAddSheet(BuildContext context, FinanceChanges changes) async {
  final l10n = AppLocalizations.of(context);
  final colors = FinanceColors.of(context);
  final route = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (icon, color, label, route) in [
              (
                Icons.south_east,
                colors.negative,
                l10n.entryKindExpense,
                AppRoutes.entryForm(EntryKind.expense),
              ),
              (
                Icons.north_east,
                colors.positive,
                l10n.entryKindIncome,
                AppRoutes.entryForm(EntryKind.income),
              ),
              (
                Icons.account_balance_wallet_outlined,
                Theme.of(context).colorScheme.primary,
                l10n.homeInformBalance,
                AppRoutes.balanceForm,
              ),
            ])
              ListTile(
                minTileHeight: 64,
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  foregroundColor: color,
                  child: Icon(icon),
                ),
                title: Text(label),
                onTap: () => Navigator.of(context).pop(route),
              ),
          ],
        ),
      ),
    ),
  );
  if (route == null || !context.mounted) {
    return;
  }
  final saved = await context.push<bool>(route);
  if (saved ?? false) {
    changes.notify();
  }
}
