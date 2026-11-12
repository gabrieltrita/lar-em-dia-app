import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/layout/breakpoints.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class AppShell extends StatelessWidget {
  const new({required this.shell, required this.changes, super.key});

  final StatefulNavigationShell shell;
  final FinanceChanges changes;

  void _select(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final body = RepositoryProvider.value(value: changes, child: shell);
    final destinations = _destinations(AppLocalizations.of(context));
    if (Breakpoints.isDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              selectedIndex: shell.currentIndex,
              destinations: destinations,
              onSelected: _select,
              changes: changes,
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Breakpoints.maxContentWidth,
                  ),
                  child: body,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarTheme.of(context).copyWith(
          labelTextStyle: WidgetStatePropertyAll(
            Theme.of(context).textTheme.labelSmall,
          ),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _select,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.shortLabel,
              ),
          ],
        ),
      ),
    );
  }

  static List<_Destination> _destinations(AppLocalizations l10n) => [
    _Destination(Icons.home_outlined, Icons.home, l10n.shellHome),
    _Destination(
      Icons.receipt_long_outlined,
      Icons.receipt_long,
      l10n.shellEntries,
    ),
    _Destination(
      Icons.savings_outlined,
      Icons.savings,
      l10n.shellInvestments,
      shortLabel: l10n.shellInvestmentsShort,
    ),
    _Destination(Icons.show_chart, Icons.show_chart, l10n.shellProjection),
    _Destination(Icons.menu, Icons.menu, l10n.shellMore),
  ];
}

class _Destination {
  const new(this.icon, this.selectedIcon, this.label, {String? shortLabel})
    : shortLabel = shortLabel ?? label;

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String shortLabel;
}

class _Sidebar extends StatelessWidget {
  const new({
    required this.selectedIndex,
    required this.destinations,
    required this.onSelected,
    required this.changes,
  });

  final int selectedIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelected;
  final FinanceChanges changes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = FinanceColors.of(context);
    return NavigationRail(
      extended: true,
      minExtendedWidth: 232,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
        child: SizedBox(
          width: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: colors.heroGradient,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.home, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      l10n.appTitle,
                      style: theme.textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => unawaited(showAddSheet(context, changes)),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.shellAdd),
                ),
              ),
            ],
          ),
        ),
      ),
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}

class AddButton extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => Breakpoints.isDesktop(context)
      ? const SizedBox.shrink()
      : FloatingActionButton(
          heroTag: null,
          tooltip: AppLocalizations.of(context).shellAdd,
          onPressed: () =>
              unawaited(showAddSheet(context, context.read<FinanceChanges>())),
          child: const Icon(Icons.add),
        );
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
