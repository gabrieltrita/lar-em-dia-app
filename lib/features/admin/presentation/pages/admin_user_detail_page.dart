import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/confirm_dialog.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/admin/domain/admin_user.dart';
import 'package:lar_em_dia/features/admin/presentation/cubits/admin_cubits.dart';
import 'package:lar_em_dia/features/admin/presentation/widgets/admin_badges.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

final _dateTime = DateFormat('dd/MM/yyyy HH:mm');

class AdminUserDetailPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AdminUserCubit>();
    final currentUserId = context.select<SessionCubit, String?>(
      (cubit) => switch (cubit.state) {
        SessionAuthenticated(:final user) => user.id,
        _ => null,
      },
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminUsersTitle)),
      body: BlocBuilder<AdminUserCubit, LoadState<AdminUser>>(
        builder: (context, state) => switch (state) {
          Loading() => const Center(child: CircularProgressIndicator()),
          LoadFailure(:final error) => RetryMessage(
            message: error.localized(l10n),
            onRetry: () => unawaited(cubit.load()),
          ),
          Loaded(value: final user) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(user: user),
              const SizedBox(height: 16),
              _Details(user: user),
              if (user.id != currentUserId) ...[
                const SizedBox(height: 16),
                _Actions(user: user),
              ],
            ],
          ),
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const new({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(user.fullName, style: textTheme.titleLarge),
        Text(user.email),
        const SizedBox(height: 8),
        AdminBadges(user: user),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const new({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String yesNo({required bool value}) => value ? l10n.adminYes : l10n.adminNo;
    final lastSignIn = user.lastSignInAt;
    final rows = [
      (
        l10n.adminUserRole,
        user.isAdmin ? l10n.adminRoleAdmin : l10n.adminRoleUser,
      ),
      (l10n.adminUserEmailConfirmed, yesNo(value: user.emailConfirmed)),
      (l10n.adminUserTwoFactor, yesNo(value: user.twoFactorEnabled)),
      (l10n.adminUserLocked, yesNo(value: user.locked)),
      (l10n.adminUserDeactivated, yesNo(value: user.deactivated)),
      (
        l10n.adminUserLastSignIn,
        lastSignIn == null
            ? l10n.adminNever
            : _dateTime.format(lastSignIn.toLocal()),
      ),
      (l10n.adminUserSignInCount, '${user.signInCount}'),
      (l10n.adminUserCreatedAt, _dateTime.format(user.createdAt.toLocal())),
    ];
    return Card(
      child: Column(
        children: [
          for (final (label, value) in rows)
            ListTile(dense: true, title: Text(label), trailing: Text(value)),
        ],
      ),
    );
  }
}

typedef _Action = ({
  String label,
  String message,
  Future<ApiError?> Function(AdminUserCubit cubit) run,
});

class _Actions extends StatelessWidget {
  const new({required this.user});

  final AdminUser user;

  Future<void> _run(BuildContext context, _Action action) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AdminUserCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmAction(
      context,
      title: action.label,
      message: action.message,
      confirmLabel: l10n.adminConfirm,
    );
    if (!confirmed) {
      return;
    }
    final error = await action.run(cubit);
    messenger.showSnackBar(
      SnackBar(content: Text(error?.localized(l10n) ?? l10n.adminActionDone)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = <_Action>[
      if (user.locked)
        (
          label: l10n.adminUnlock,
          message: l10n.adminUnlockMessage,
          run: (cubit) => cubit.unlock(),
        ),
      if (user.twoFactorEnabled)
        (
          label: l10n.adminResetTwoFactor,
          message: l10n.adminResetTwoFactorMessage,
          run: (cubit) => cubit.resetTwoFactor(),
        ),
      if (user.isAdmin)
        (
          label: l10n.adminRemoveAdmin,
          message: l10n.adminRemoveAdminMessage,
          run: (cubit) => cubit.changeRole(UserRole.user),
        )
      else
        (
          label: l10n.adminMakeAdmin,
          message: l10n.adminMakeAdminMessage,
          run: (cubit) => cubit.changeRole(UserRole.admin),
        ),
      if (user.deactivated)
        (
          label: l10n.adminReactivate,
          message: l10n.adminReactivateMessage,
          run: (cubit) => cubit.reactivate(),
        )
      else
        (
          label: l10n.adminDeactivate,
          message: l10n.adminDeactivateMessage,
          run: (cubit) => cubit.deactivate(),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        for (final action in actions)
          OutlinedButton(
            onPressed: () => unawaited(_run(context, action)),
            child: Text(action.label),
          ),
      ],
    );
  }
}
