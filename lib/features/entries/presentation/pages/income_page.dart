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
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/cubits/entry_cubits.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_label.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class IncomePage extends StatelessWidget {
  const new({super.key});

  Future<void> _open(BuildContext context, [Entry? entry]) async {
    final cubit = context.read<MonthEntriesCubit>();
    final saved = await context.push<bool>(AppRoutes.incomeForm, extra: entry);
    if (saved ?? false) {
      await cubit.load();
    }
  }

  Future<bool> _delete(BuildContext context, Entry entry) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<MonthEntriesCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDeletion(
      context,
      title: l10n.incomeDeleteTitle,
      message: l10n.incomeDeleteMessage(entry.description),
    );
    if (!confirmed) {
      return false;
    }
    final error = await cubit.delete(entry);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error.localized(l10n))));
    }
    return error == null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<MonthEntriesCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.incomeTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.entryFormNewTitle,
        onPressed: () => unawaited(_open(context)),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<MonthEntriesCubit, MonthEntriesState>(
        builder: (context, state) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: l10n.incomePreviousMonth,
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => unawaited(cubit.previous()),
                  ),
                  Expanded(
                    child: Text(
                      MaterialLocalizations.of(context)
                          .formatMonthYear(state.month),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.incomeNextMonth,
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => unawaited(cubit.next()),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (state.data) {
                Loading() => const Center(child: CircularProgressIndicator()),
                LoadFailure(:final error) => RetryMessage(
                  message: error.localized(l10n),
                  onRetry: () => unawaited(cubit.load()),
                ),
                Loaded(:final value) => _EntryList(
                  data: value,
                  onOpen: (entry) => unawaited(_open(context, entry)),
                  onDelete: (entry) => _delete(context, entry),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const new({required this.data, required this.onOpen, required this.onDelete});

  final MonthEntries data;
  final ValueChanged<Entry> onOpen;
  final Future<bool> Function(Entry entry) onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (data.entries.isEmpty) {
      return Center(child: Text(l10n.incomeEmpty));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.incomeTotal(Money.format(data.totalCents)),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: data.entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = data.entries[index];
              return Dismissible(
                key: ValueKey(entry.id),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => onDelete(entry),
                background: Container(
                  color: Theme.of(context).colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: const Icon(Icons.delete_outline),
                ),
                child: ListTile(
                  title: Text(entry.description),
                  subtitle: Text(
                    [
                      categoryLabel(l10n, data.categories[entry.categoryId]),
                      Dates.display(entry.dueOn),
                      if (entry.isPaid)
                        l10n.incomeReceived
                      else
                        l10n.incomePending,
                    ].join(' · '),
                  ),
                  trailing: Text(Money.format(entry.amountCents)),
                  onTap: () => onOpen(entry),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
