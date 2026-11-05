import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/admin/domain/admin_category.dart';
import 'package:lar_em_dia/features/admin/presentation/cubits/admin_cubits.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_label.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class AdminCategoriesPage extends StatelessWidget {
  const new({super.key});

  Future<void> _open(BuildContext context, [AdminCategory? category]) async {
    final cubit = context.read<AdminCategoriesCubit>();
    final saved = await context.push<bool>(
      AppRoutes.adminCategoryForm,
      extra: category,
    );
    if (saved ?? false) {
      await cubit.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AdminCategoriesCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminCategoriesTitle)),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.adminCategoryNewTitle,
        onPressed: () => unawaited(_open(context)),
        child: const Icon(Icons.add),
      ),
      body: BlocBuilder<AdminCategoriesCubit, LoadState<List<AdminCategory>>>(
        builder: (context, state) => switch (state) {
          Loading() => const Center(child: CircularProgressIndicator()),
          LoadFailure(:final error) => RetryMessage(
            message: error.localized(l10n),
            onRetry: () => unawaited(cubit.load()),
          ),
          Loaded(value: final categories) when categories.isEmpty => Center(
            child: Text(l10n.adminCategoriesEmpty),
          ),
          Loaded(value: final categories) => RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final kind in EntryKind.values)
                  if (categories.where((c) => c.kind == kind).toList()
                      case final group when group.isNotEmpty) ...[
                    _KindHeader(kind: kind),
                    for (final category in group)
                      _CategoryTile(
                        category: category,
                        onTap: () => unawaited(_open(context, category)),
                      ),
                  ],
              ],
            ),
          ),
        },
      ),
    );
  }
}

class _KindHeader extends StatelessWidget {
  const new({required this.kind});

  final EntryKind kind;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      AppLocalizations.of(context).entriesTitle(kind.name),
      style: Theme.of(context).textTheme.titleSmall,
    ),
  );
}

class _CategoryTile extends StatelessWidget {
  const new({required this.category, required this.onTap});

  final AdminCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(categoryLabel(l10n, category.toCategory())),
      subtitle: Text(
        l10n.adminCategorySubtitle(category.key, category.position),
      ),
      trailing: category.active
          ? null
          : Chip(
              label: Text(l10n.adminCategoryInactive),
              labelStyle: TextStyle(color: colors.onSurfaceVariant),
              visualDensity: VisualDensity.compact,
            ),
      onTap: onTap,
    );
  }
}
