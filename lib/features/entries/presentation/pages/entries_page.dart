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
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/cubits/entry_cubits.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_label.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/entry_scope_dialog.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/nature_label.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/paid_checkbox.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class EntriesPage extends StatelessWidget {
  const new({super.key});

  Future<void> _open(BuildContext context, [Entry? entry]) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<MonthEntriesCubit>();
    final scope = entry?.seriesId == null
        ? EntryScope.one
        : await askEntryScope(
            context,
            title: l10n.entryScopeEditTitle(cubit.kind.name),
            entry: entry!,
          );
    if (scope == null || !context.mounted) {
      return;
    }
    final saved = await context.push<bool>(
      AppRoutes.entryForm(cubit.kind),
      extra: entry == null ? null : EntryEdit(entry: entry, scope: scope),
    );
    if (saved ?? false) {
      await cubit.load();
    }
  }

  Future<EntryScope?> _deletionScope(BuildContext context, Entry entry) async {
    final l10n = AppLocalizations.of(context);
    final kind = entry.kind.name;
    if (entry.seriesId != null) {
      return await askEntryScope(
        context,
        title: l10n.entryScopeDeleteTitle(kind),
        entry: entry,
      );
    }
    final confirmed = await confirmDeletion(
      context,
      title: l10n.entryDeleteTitle(kind),
      message: l10n.entryDeleteMessage(entry.description),
    );
    return confirmed ? EntryScope.one : null;
  }

  Future<bool> _delete(BuildContext context, Entry entry) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<MonthEntriesCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final scope = await _deletionScope(context, entry);
    if (scope == null) {
      return false;
    }
    final error = await cubit.delete(entry, scope: scope);
    _report(messenger, l10n, error);
    return error == null;
  }

  Future<void> _setPaid(
    BuildContext context,
    Entry entry, {
    required bool paid,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<MonthEntriesCubit>().setPaid(
      entry,
      paid: paid,
    );
    _report(messenger, l10n, error);
  }

  void _report(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    ApiError? error,
  ) {
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error.localized(l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<MonthEntriesCubit>();
    final kind = cubit.kind.name;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.entriesTitle(kind))),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.entryFormNewTitle(kind),
        onPressed: () => unawaited(_open(context)),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<MonthEntriesCubit, MonthEntriesState>(
        builder: (context, state) => Column(
          children: [
            _MonthSwitcher(
              month: state.month,
              onPrevious: () => unawaited(cubit.previous()),
              onNext: () => unawaited(cubit.next()),
            ),
            Expanded(
              child: switch (state.data) {
                Loading() => const Center(child: CircularProgressIndicator()),
                LoadFailure(:final error) => RetryMessage(
                  message: error.localized(l10n),
                  onRetry: () => unawaited(cubit.load()),
                ),
                Loaded(:final value) => _EntryList(
                  kind: cubit.kind,
                  data: value,
                  nature: state.nature,
                  onFilter: cubit.filter,
                  onOpen: (entry) => unawaited(_open(context, entry)),
                  onDelete: (entry) => _delete(context, entry),
                  onPaid: (entry, {required paid}) =>
                      unawaited(_setPaid(context, entry, paid: paid)),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  const new({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.previousMonth,
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Expanded(
            child: Text(
              MaterialLocalizations.of(context).formatMonthYear(month),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: l10n.nextMonth,
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _NatureFilter extends StatelessWidget {
  const new({required this.selected, required this.onSelected});

  final EntryNature? selected;
  final ValueChanged<EntryNature?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = {
      null: l10n.entriesFilterAll,
      EntryNature.fixed: l10n.entriesFilterFixed,
      EntryNature.variable: l10n.entriesFilterVariable,
    };
    return Wrap(
      spacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final MapEntry(key: nature, value: label) in options.entries)
          ChoiceChip(
            label: Text(label),
            selected: selected == nature,
            onSelected: (_) => onSelected(nature),
          ),
      ],
    );
  }
}

class _EntryList extends StatelessWidget {
  const new({
    required this.kind,
    required this.data,
    required this.nature,
    required this.onFilter,
    required this.onOpen,
    required this.onDelete,
    required this.onPaid,
  });

  final EntryKind kind;
  final MonthEntries data;
  final EntryNature? nature;
  final ValueChanged<EntryNature?> onFilter;
  final ValueChanged<Entry> onOpen;
  final Future<bool> Function(Entry entry) onDelete;
  final PaidChanged onPaid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    if (data.entries.isEmpty) {
      return Center(child: Text(l10n.entriesEmpty(kind.name)));
    }
    final isExpense = kind == EntryKind.expense;
    final entries = data.withNature(nature);
    return Column(
      children: [
        Text(
          l10n.entriesTotal(Money.format(data.totalCents(nature))),
          style: textTheme.titleLarge,
        ),
        if (isExpense) ...[
          Text(
            l10n.entriesNatureBreakdown(
              Money.format(data.totalCents(EntryNature.fixed)),
              Money.format(data.totalCents(EntryNature.variable)),
            ),
          ),
          const SizedBox(height: 8),
          _NatureFilter(selected: nature, onSelected: onFilter),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: entries.isEmpty
              ? Center(child: Text(l10n.entriesEmptyFilter))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _EntryTile(
                    entry: entries[index],
                    categoryText: categoryLabel(
                      l10n,
                      data.categories[entries[index].categoryId],
                    ),
                    onOpen: onOpen,
                    onDelete: onDelete,
                    onPaid: onPaid,
                  ),
                ),
        ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const new({
    required this.entry,
    required this.categoryText,
    required this.onOpen,
    required this.onDelete,
    required this.onPaid,
  });

  final Entry entry;
  final String categoryText;
  final ValueChanged<Entry> onOpen;
  final Future<bool> Function(Entry entry) onDelete;
  final PaidChanged onPaid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kind = entry.kind.name;
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
        leading: switch (entry) {
          Entry(
            isInstallment: true,
            :final seriesPosition?,
            :final seriesCount?,
          ) =>
            Icon(
              Icons.credit_card,
              semanticLabel: l10n.entryInstallment(seriesPosition, seriesCount),
            ),
          Entry(isRecurring: true) => Icon(
            Icons.repeat,
            semanticLabel: l10n.entryRecurring,
          ),
          _ => const SizedBox(width: 24),
        },
        title: Text(switch (entry) {
          Entry(
            isInstallment: true,
            :final seriesPosition?,
            :final seriesCount?,
          ) =>
            '${entry.description} '
                '${l10n.entryInstallmentShort(seriesPosition, seriesCount)}',
          _ => entry.description,
        }),
        subtitle: Text(
          [
            categoryText,
            if (entry.nature case final nature?) natureLabel(l10n, nature),
            Dates.display(entry.dueOn),
            if (entry.isPaid)
              l10n.entrySettled(kind)
            else
              l10n.entryPending(kind),
          ].join(' · '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Money.format(entry.amountCents)),
            PaidCheckbox(entry: entry, onChanged: onPaid),
          ],
        ),
        onTap: () => onOpen(entry),
      ),
    );
  }
}
