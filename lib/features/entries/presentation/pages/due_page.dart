import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/core/widgets/empty_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/core/widgets/money_text.dart';
import 'package:lar_em_dia/core/widgets/skeleton.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/cubits/entry_cubits.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_visuals.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/paid_checkbox.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class DuePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DueCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dueTitle)),
      body: BlocBuilder<DueCubit, LoadState<DueEntries>>(
        builder: (context, state) => switch (state) {
          Loading() => SkeletonList(label: l10n.loadingLabel),
          LoadFailure(:final error) => RetryMessage(
            message: error.localized(l10n),
            onRetry: () => unawaited(cubit.load()),
          ),
          Loaded(:final value) => RefreshIndicator(
            onRefresh: () => cubit.load(quiet: true),
            child: value.entries.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: 360,
                        child: EmptyState(
                          icon: Icons.event_available_outlined,
                          title: l10n.dueEmpty,
                          message: l10n.dueEmptyMessage,
                        ),
                      ),
                    ],
                  )
                : _DueList(due: value),
          ),
        },
      ),
    );
  }
}

class _DueList extends StatelessWidget {
  const new({required this.due});

  final DueEntries due;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = [
      (l10n.dueOverdue, due.overdue, true),
      (l10n.dueThisWeek, due.thisWeek, false),
      (l10n.dueLater, due.later, false),
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final (title, entries, overdue) in sections)
          if (entries.isNotEmpty) ...[
            _SectionHeader(
              title: title,
              totalCents: entries.fold(
                0,
                (sum, entry) => sum + entry.amountCents,
              ),
              overdue: overdue,
            ),
            for (final entry in entries)
              _DueTile(entry: entry, due: due, overdue: overdue),
          ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const new({
    required this.title,
    required this.totalCents,
    required this.overdue,
  });

  final String title;
  final int totalCents;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = overdue
        ? FinanceColors.of(context).negative
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
          ),
          Text(
            Money.format(totalCents),
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _DueTile extends StatelessWidget {
  const new({required this.entry, required this.due, required this.overdue});

  final Entry entry;
  final DueEntries due;
  final bool overdue;

  Future<bool> _markPaid(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final changes = context.read<FinanceChanges>();
    final error = await context.read<DueCubit>().markPaid(entry);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error.localized(l10n))));
      return false;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.duePaid(entry.description))),
    );
    changes.notify();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = FinanceColors.of(context);
    final days = entry.dueOn.difference(due.today).inDays;
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) => _markPaid(context),
      background: Container(
        color: colors.positiveContainer,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Icon(Icons.check, color: colors.positive),
      ),
      child: ListTile(
        leading: CategoryAvatar(category: due.categories[entry.categoryId]),
        title: Text(entry.description),
        subtitle: Text(
          overdue
              ? l10n.dueLate(Dates.display(entry.dueOn))
              : l10n.dueWhen(days, Dates.display(entry.dueOn)),
          style: overdue ? TextStyle(color: colors.negative) : null,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MoneyText(
              entry.amountCents,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            PaidCheckbox(
              entry: entry,
              onChanged: (entry, {required paid}) =>
                  unawaited(_markPaid(context)),
            ),
          ],
        ),
      ),
    );
  }
}
