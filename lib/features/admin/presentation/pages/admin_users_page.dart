import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/admin/domain/admin_user.dart';
import 'package:lar_em_dia/features/admin/presentation/cubits/admin_cubits.dart';
import 'package:lar_em_dia/features/admin/presentation/widgets/admin_badges.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class AdminUsersPage extends StatefulWidget {
  const new({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AdminUsersCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminUsersTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              key: const Key('admin_search_email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: l10n.adminSearchEmail,
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (value) => unawaited(cubit.search(value)),
            ),
          ),
          const _StatusFilter(),
          const Expanded(child: _UsersList()),
        ],
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AdminUsersCubit>();
    final selected = context.select<AdminUsersCubit, AccountStatus?>(
      (cubit) => cubit.state.status,
    );
    final options = <AccountStatus?, String>{
      null: l10n.adminFilterAll,
      AccountStatus.active: l10n.adminFilterActive,
      AccountStatus.deactivated: l10n.adminFilterDeactivated,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        children: [
          for (final MapEntry(key: status, value: label) in options.entries)
            ChoiceChip(
              label: Text(label),
              selected: selected == status,
              onSelected: (_) => unawaited(cubit.filter(status)),
            ),
        ],
      ),
    );
  }
}

class _UsersList extends StatelessWidget {
  const new();

  Future<void> _loadMore(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<AdminUsersCubit>().loadMore();
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error.localized(l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AdminUsersCubit>();
    return BlocBuilder<AdminUsersCubit, AdminUsersState>(
      builder: (context, state) => switch (state.users) {
        Loading() => const Center(child: CircularProgressIndicator()),
        LoadFailure(:final error) => RetryMessage(
          message: error.localized(l10n),
          onRetry: () => unawaited(cubit.load()),
        ),
        Loaded(value: final users) when users.isEmpty => Center(
          child: InfoMessage(l10n.adminUsersEmpty),
        ),
        Loaded(value: final users) => RefreshIndicator(
          onRefresh: cubit.load,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              for (final user in users) _UserTile(user: user),
              if (state.nextPage != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: state.loadingMore
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: () => unawaited(_loadMore(context)),
                            child: Text(l10n.adminLoadMore),
                          ),
                  ),
                ),
            ],
          ),
        ),
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  const new({required this.user});

  final AdminUser user;

  Future<void> _open(BuildContext context) async {
    final cubit = context.read<AdminUsersCubit>();
    await context.push<void>(AppRoutes.adminUser(user.id));
    await cubit.load();
  }

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(user.fullName),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(user.email),
        const SizedBox(height: 4),
        AdminBadges(user: user),
      ],
    ),
    isThreeLine: true,
    trailing: const Icon(Icons.chevron_right),
    onTap: () => unawaited(_open(context)),
  );
}
