import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/security/domain/two_factor.dart';
import 'package:lar_em_dia/features/security/presentation/cubits/security_cubits.dart';
import 'package:lar_em_dia/features/security/presentation/widgets/backup_codes_view.dart';
import 'package:lar_em_dia/features/security/presentation/widgets/reauthentication_dialog.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class SecurityPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SecurityCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.securityTitle)),
      body: BlocBuilder<SecurityCubit, LoadState<TwoFactorStatus>>(
        builder: (context, state) => switch (state) {
          Loading() => const Center(child: CircularProgressIndicator()),
          LoadFailure(:final error) => RetryMessage(
            message: error.localized(l10n),
            onRetry: () => unawaited(cubit.load()),
          ),
          Loaded(value: final status) => ListView(
            padding: const EdgeInsets.all(16),
            children: [_TwoFactorCard(status: status)],
          ),
        },
      ),
    );
  }
}

class _TwoFactorCard extends StatelessWidget {
  const new({required this.status});

  final TwoFactorStatus status;

  void _signedInWithTwoFactor(BuildContext context, {required bool enabled}) {
    final session = context.read<SessionCubit>();
    if (session.state case SessionAuthenticated(:final user)) {
      session.signedIn(user.copyWith(twoFactorEnabled: enabled));
    }
  }

  Future<void> _enable(BuildContext context) async {
    final cubit = context.read<SecurityCubit>();
    final enabled = await context.push<bool>(AppRoutes.twoFactorEnrollment);
    if (!context.mounted) {
      return;
    }
    if (enabled ?? false) {
      _signedInWithTwoFactor(context, enabled: true);
    }
    await cubit.load();
  }

  Future<void> _disable(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SecurityCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final reauthentication = await askReauthentication(
      context,
      title: l10n.securityDisable,
    );
    if (reauthentication == null || !context.mounted) {
      return;
    }
    final error = await cubit.disable(reauthentication);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error.localized(l10n))));
    } else if (context.mounted) {
      _signedInWithTwoFactor(context, enabled: false);
    }
  }

  Future<void> _newBackupCodes(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SecurityCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final reauthentication = await askReauthentication(
      context,
      title: l10n.securityNewBackupCodes,
    );
    if (reauthentication == null || !context.mounted) {
      return;
    }
    final result = await cubit.regenerateBackupCodes(reauthentication);
    if (result case (codes: final codes?, error: _) when context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: BackupCodesView(
              codes: codes,
              onDone: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        ),
      );
    } else if (result.error case final error?) {
      messenger.showSnackBar(SnackBar(content: Text(error.localized(l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.securityTwoFactorTitle, style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              status.enabled
                  ? l10n.securityTwoFactorOn(status.backupCodesRemaining)
                  : l10n.securityTwoFactorOff,
            ),
            if (status.mandatory) ...[
              const SizedBox(height: 4),
              Text(l10n.securityTwoFactorRequired),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!status.enabled)
                  FilledButton(
                    onPressed: () => unawaited(_enable(context)),
                    child: Text(l10n.securityEnable),
                  ),
                if (status.enabled) ...[
                  OutlinedButton(
                    onPressed: () => unawaited(_newBackupCodes(context)),
                    child: Text(l10n.securityNewBackupCodes),
                  ),
                  if (!status.mandatory)
                    OutlinedButton(
                      onPressed: () => unawaited(_disable(context)),
                      child: Text(l10n.securityDisable),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
