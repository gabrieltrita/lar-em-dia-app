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
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/cubits/entry_cubits.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_label.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_visuals.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/entry_scope_dialog.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/nature_label.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/paid_checkbox.dart';
import 'package:lar_em_dia/features/shell/presentation/app_shell.dart';
import 'package:lar_em_dia/features/shell/presentation/finance_changes.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class EntriesPage extends StatelessWidget {
  const new({super.key});

  Future<void> _open(BuildContext context, Entry entry) async {
    final l10n = AppLocalizations.of(context);
    final changes = context.read<FinanceChanges>();
    final scope = entry.seriesId == null
        ? EntryScope.one
        : await askEntryScope(
            context,
            title: l10n.entryScopeEditTitle(entry.kind.name),
            entry: entry,
          );
    if (scope == null || !context.mounted) {
      return;
    }
    final saved = await context.push<bool>(
      AppRoutes.entryForm(entry.kind),
      extra: EntryEdit(entry: entry, scope: scope),
    );
    if (saved ?? false) {
      changes.notify();
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
    final changes = context.read<FinanceChanges>();
    final messenger = ScaffoldMessenger.of(context);
    final scope = await _deletionScope(context, entry);
    if (scope == null) {
      return false;
    }
    final error = await cubit.delete(entry, scope: scope);
    _report(messenger, l10n, error, changes);
    return error == null;
  }

  Future<void> _setPaid(
    BuildContext context,
    Entry entry, {
    required bool paid,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final changes = context.read<FinanceChanges>();
    final error = await context.read<MonthEntriesCubit>().setPaid(
      entry,
      paid: paid,
    );
    _report(messenger, l10n, error, changes);
  }

  void _report(
    ScaffoldMessengerState messenger,
    AppLocalizations l10n,
    ApiError? error,
    FinanceChanges changes,
  ) {
    if (error == null) {
      changes.notify();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(error.localized(l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<MonthEntriesCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.shellEntries)),
      body: BlocBuilder<MonthEntriesCubit, MonthEntriesState>(
        builder: (context, state) => Column(
          children: [
            MonthSwitcher(
              month: state.month,
              onPrevious: () => unawaited(cubit.previous()),
              onNext: () => unawaited(cubit.next()),
            ),
            _Filters(
              kind: state.kind,
              nature: state.nature,
              onKind: cubit.filterKind,
              onNature: cubit.filterNature,
            ),
            Expanded(
              child: switch (state.data) {
                Loading() => SkeletonList(label: l10n.loadingLabel),
                LoadFailure(:final error) => RetryMessage(
                  message: error.localized(l10n),
                  onRetry: () => unawaited(cubit.load()),
                ),
                Loaded(:final value) => _EntryList(
                  data: value,
                  kind: state.kind,
                  nature: state.nature,
                  onCreate: () => unawaited(
                    showAddSheet(context, context.read<FinanceChanges>()),
                  ),
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

class _Filters extends StatelessWidget {
  const new({
    required this.kind,
    required this.nature,
    required this.onKind,
    required this.onNature,
  });

  final EntryKind? kind;
  final EntryNature? nature;
  final ValueChanged<EntryKind?> onKind;
  final ValueChanged<EntryNature?> onNature;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kinds = {
      null: l10n.entriesKindAll,
      EntryKind.income: l10n.entriesTitle(EntryKind.income.name),
      EntryKind.expense: l10n.entriesTitle(EntryKind.expense.name),
    };
    final natures = {
      null: l10n.entriesFilterAll,
      EntryNature.fixed: l10n.entriesFilterFixed,
      EntryNature.variable: l10n.entriesFilterVariable,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<EntryKind?>(
              key: const Key('entries_kind'),
              showSelectedIcon: false,
              segments: [
                for (final MapEntry(key: value, value: label) in kinds.entries)
                  ButtonSegment(value: value, label: Text(label)),
              ],
              selected: {kind},
              onSelectionChanged: (selection) => onKind(selection.single),
            ),
          ),
          if (kind == EntryKind.expense) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final MapEntry(key: value, value: label)
                    in natures.entries)
                  ChoiceChip(
                    label: Text(label),
                    selected: nature == value,
                    onSelected: (_) => onNature(value),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const new({
    required this.data,
    required this.kind,
    required this.nature,
    required this.onCreate,
    required this.onOpen,
    required this.onDelete,
    required this.onPaid,
  });

  final MonthEntries data;
  final EntryKind? kind;
  final EntryNature? nature;
  final VoidCallback onCreate;
  final ValueChanged<Entry> onOpen;
  final Future<bool> Function(Entry entry) onDelete;
  final PaidChanged onPaid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (data.entries.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: l10n.entriesEmptyMonth,
        message: l10n.entriesEmptyMonthMessage,
        actionLabel: l10n.shellAdd,
        onAction: onCreate,
      );
    }
    final entries = data.filtered(kind: kind, nature: nature);
    return Column(
      children: [
        _MonthTotals(data: data, kind: kind, nature: nature),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? Center(child: Text(l10n.entriesEmptyFilter))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _EntryTile(
                    entry: entries[index],
                    category: data.categories[entries[index].categoryId],
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

class _MonthTotals extends StatelessWidget {
  const new({required this.data, required this.kind, required this.nature});

  final MonthEntries data;
  final EntryKind? kind;
  final EntryNature? nature;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    Widget figure(String label, Widget value) => Expanded(
      child: Column(
        children: [
          Text(label, style: textTheme.labelSmall),
          const SizedBox(height: 2),
          value,
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: switch (kind) {
        null => Row(
          children: [
            figure(
              l10n.projectionReadoutIncome,
              MoneyText(data.totalCents(kind: EntryKind.income)),
            ),
            figure(
              l10n.projectionReadoutExpense,
              MoneyText(data.totalCents(kind: EntryKind.expense)),
            ),
            figure(
              l10n.entriesResult,
              MoneyText(data.resultCents, signed: true, colored: true),
            ),
          ],
        ),
        EntryKind.income => Text(
          l10n.entriesTotal(Money.format(data.totalCents(kind: kind))),
          style: textTheme.titleMedium,
        ),
        EntryKind.expense => Column(
          children: [
            Text(
              l10n.entriesTotal(
                Money.format(data.totalCents(kind: kind, nature: nature)),
              ),
              style: textTheme.titleMedium,
            ),
            Text(
              l10n.entriesNatureBreakdown(
                Money.format(
                  data.totalCents(kind: kind, nature: EntryNature.fixed),
                ),
                Money.format(
                  data.totalCents(kind: kind, nature: EntryNature.variable),
                ),
              ),
              style: textTheme.bodySmall,
            ),
          ],
        ),
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  const new({
    required this.entry,
    required this.category,
    required this.onOpen,
    required this.onDelete,
    required this.onPaid,
  });

  final Entry entry;
  final Category? category;
  final ValueChanged<Entry> onOpen;
  final Future<bool> Function(Entry entry) onDelete;
  final PaidChanged onPaid;

  String _title(AppLocalizations l10n) => switch (entry) {
    Entry(isInstallment: true, :final seriesPosition?, :final seriesCount?) =>
      '${entry.description} '
          '${l10n.entryInstallmentShort(seriesPosition, seriesCount)}',
    _ => entry.description,
  };

  Widget? _seriesIcon(AppLocalizations l10n) => switch (entry) {
    Entry(isInstallment: true, :final seriesPosition?, :final seriesCount?) =>
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Icon(
          Icons.credit_card,
          size: 16,
          semanticLabel: l10n.entryInstallment(seriesPosition, seriesCount),
        ),
      ),
    Entry(isRecurring: true) => Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Icon(Icons.repeat, size: 16, semanticLabel: l10n.entryRecurring),
    ),
    _ => null,
  };

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
        leading: CategoryAvatar(category: category),
        title: Row(
          children: [
            Flexible(child: Text(_title(l10n))),
            ?_seriesIcon(l10n),
          ],
        ),
        subtitle: Text(
          [
            categoryLabel(l10n, category),
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
            MoneyText(
              entry.kind == EntryKind.expense
                  ? -entry.amountCents
                  : entry.amountCents,
              signed: true,
              colored: true,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            PaidCheckbox(entry: entry, onChanged: onPaid),
          ],
        ),
        onTap: () => onOpen(entry),
      ),
    );
  }
}
