import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/paid_checkbox.dart';
import 'package:lar_em_dia/features/home/presentation/cubits/home_cubit.dart';
import 'package:lar_em_dia/features/projection/domain/projection.dart';
import 'package:lar_em_dia/features/projection/presentation/widgets/negative_months_alert.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class HomePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.select<SessionCubit, AuthUser?>(
      (cubit) => switch (cubit.state) {
        SessionAuthenticated(:final user) => user,
        _ => null,
      },
    );
    final firstName = user?.firstName;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.homeSecurity,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => unawaited(context.push<void>(AppRoutes.account)),
          ),
          IconButton(
            tooltip: l10n.logout,
            icon: const Icon(Icons.logout),
            onPressed: () => unawaited(context.read<SessionCubit>().logout()),
          ),
        ],
      ),
      body: BlocBuilder<HomeCubit, LoadState<HomeSummary>>(
        builder: (context, state) => switch (state) {
          Loading() => const Center(child: CircularProgressIndicator()),
          LoadFailure(:final error) => RetryMessage(
            message: error.localized(l10n),
            onRetry: () => unawaited(context.read<HomeCubit>().load()),
          ),
          Loaded(value: final summary) => RefreshIndicator(
            onRefresh: () => context.read<HomeCubit>().load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (firstName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      l10n.homeGreeting(firstName),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                _BalanceCard(summary: summary),
                const SizedBox(height: 16),
                if (summary case HomeSummary(
                  :final firstNegativeMonth?,
                  :final negativeMonthsCount,
                )) ...[
                  NegativeMonthsAlert(
                    firstMonth: firstNegativeMonth,
                    count: negativeMonthsCount,
                    onTap: () => unawaited(
                      _pushAndReload(context, AppRoutes.projection),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (summary case HomeSummary(
                  :final projected?,
                  :final horizon?,
                )) ...[
                  _ProjectionCard(projected: projected, horizon: horizon),
                  const SizedBox(height: 16),
                ],
                _UpcomingCard(entries: summary.upcoming),
                const SizedBox(height: 16),
                for (final kind in EntryKind.values) ...[
                  _EntriesCard(kind: kind, summary: summary),
                  const SizedBox(height: 16),
                ],
                if (user?.isAdmin ?? false) const _AdminCard(),
              ],
            ),
          ),
        },
      ),
    );
  }
}

Future<void> _pushAndReload(BuildContext context, String location) async {
  final cubit = context.read<HomeCubit>();
  await context.push<bool>(location);
  await cubit.load();
}

class _UpcomingCard extends StatelessWidget {
  const new({required this.entries});

  final List<Entry> entries;

  Future<void> _markPaid(BuildContext context, Entry entry) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<HomeCubit>().markPaid(entry);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error.localized(l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.homeUpcomingTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.homeUpcomingEmpty),
              ),
            for (final entry in entries)
              ListTile(
                title: Text(entry.description),
                subtitle: Text(Dates.display(entry.dueOn)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Money.format(entry.amountCents)),
                    PaidCheckbox(
                      entry: entry,
                      onChanged: (entry, {required paid}) =>
                          unawaited(_markPaid(context, entry)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const new({required this.summary});

  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final balance = summary.latestBalance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.homeBalanceTitle, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            if (balance == null)
              Text(l10n.homeNoBalance)
            else ...[
              Text(
                Money.format(balance.amountCents),
                style: textTheme.headlineMedium,
              ),
              Text(l10n.homeBalanceAsOf(Dates.display(balance.asOf))),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () =>
                      unawaited(_pushAndReload(context, AppRoutes.balanceForm)),
                  child: Text(l10n.homeInformBalance),
                ),
                if (balance != null)
                  OutlinedButton(
                    onPressed: () =>
                        unawaited(_pushAndReload(context, AppRoutes.balances)),
                    child: Text(l10n.homeBalanceHistory),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  const new({required this.projected, required this.horizon});

  final ProjectionMonth projected;
  final ProjectionMonth horizon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final localizations = MaterialLocalizations.of(context);
    final month = localizations.formatMonthYear(projected.month);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.homeProjectionTitle(month), style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              Money.format(projected.closingCents),
              style: textTheme.headlineMedium?.copyWith(
                color: projected.isNegative
                    ? Theme.of(context).colorScheme.error
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.homeProjectionSavings(
                localizations.formatMonthYear(horizon.month),
                Money.format(horizon.savingsCents),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  unawaited(_pushAndReload(context, AppRoutes.projection)),
              child: Text(l10n.homeSeeProjection),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntriesCard extends StatelessWidget {
  const new({required this.kind, required this.summary});

  final EntryKind kind;
  final HomeSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final month = MaterialLocalizations.of(context)
        .formatMonthYear(summary.month);
    final totals = summary.totalsOf(kind);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.homeEntriesTitle(kind.name, month),
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              Money.format(totals.totalCents),
              style: textTheme.headlineMedium,
            ),
            Text(
              l10n.homeEntriesBreakdown(
                kind.name,
                Money.format(totals.settledCents),
                Money.format(totals.pendingCents),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () => unawaited(
                    _pushAndReload(context, AppRoutes.entryForm(kind)),
                  ),
                  child: Text(l10n.entryFormNewTitle(kind.name)),
                ),
                OutlinedButton(
                  onPressed: () => unawaited(
                    _pushAndReload(context, AppRoutes.entries(kind)),
                  ),
                  child: Text(l10n.homeSeeEntries(kind.name)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adminTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, route) in [
                  (l10n.adminManageUsers, AppRoutes.adminUsers),
                  (l10n.adminMetrics, AppRoutes.adminMetrics),
                  (l10n.adminCategories, AppRoutes.adminCategories),
                ])
                  OutlinedButton(
                    onPressed: () => unawaited(context.push<void>(route)),
                    child: Text(label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
