import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/security/domain/two_factor.dart';
import 'package:lar_em_dia/features/security/presentation/cubits/security_cubits.dart';
import 'package:lar_em_dia/features/security/presentation/widgets/backup_codes_view.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TwoFactorEnrollmentPage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.securityTwoFactorTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: BlocBuilder<TwoFactorEnrollmentCubit, EnrollmentState>(
          builder: (context, state) => switch (state) {
            EnrollmentPassword(:final busy, :final error) => _PasswordStep(
              busy: busy,
              error: error?.localized(l10n),
            ),
            EnrollmentCode(:final setup, :final busy, :final error) =>
              _CodeStep(
                setup: setup,
                busy: busy,
                error: error?.localized(l10n),
              ),
            EnrollmentDone(:final backupCodes) => BackupCodesView(
              codes: backupCodes,
              onDone: () => context.pop(true),
            ),
          },
        ),
      ),
    );
  }
}

class _PasswordStep extends StatefulWidget {
  const new({required this.busy, this.error});

  final bool busy;
  final String? error;

  @override
  State<_PasswordStep> createState() => _PasswordStepState();
}

class _PasswordStepState extends State<_PasswordStep> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.enrollmentPasswordHint),
        const SizedBox(height: 16),
        TextField(
          key: const Key('enrollment_password'),
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(labelText: l10n.passwordLabel),
        ),
        if (widget.error case final error?) ...[
          const SizedBox(height: 16),
          ErrorBanner([error]),
        ],
        const SizedBox(height: 24),
        SubmitButton(
          label: l10n.enrollmentContinue,
          busy: widget.busy,
          onPressed: () => unawaited(
            context.read<TwoFactorEnrollmentCubit>().start(_password.text),
          ),
        ),
      ],
    );
  }
}

class _CodeStep extends StatefulWidget {
  const new({required this.setup, required this.busy, this.error});

  final TwoFactorSetup setup;
  final bool busy;
  final String? error;

  @override
  State<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends State<_CodeStep> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _copySecret() async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = AppLocalizations.of(context).copied;
    await Clipboard.setData(ClipboardData(text: widget.setup.secret));
    messenger.showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.enrollmentScan),
        const SizedBox(height: 16),
        Center(
          child: Semantics(
            label: l10n.enrollmentQrLabel,
            child: ColoredBox(
              color: Colors.white,
              child: QrImageView(data: widget.setup.provisioningUri, size: 220),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.enrollmentSecretLabel),
          subtitle: SelectableText(widget.setup.secret),
          trailing: IconButton(
            tooltip: l10n.enrollmentCopySecret,
            icon: const Icon(Icons.copy),
            onPressed: () => unawaited(_copySecret()),
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.enrollmentCodeHint),
        TextField(
          key: const Key('enrollment_code'),
          controller: _code,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.twoFactorCodeLabel),
        ),
        if (widget.error case final error?) ...[
          const SizedBox(height: 16),
          ErrorBanner([error]),
        ],
        const SizedBox(height: 24),
        SubmitButton(
          label: l10n.enrollmentEnable,
          busy: widget.busy,
          onPressed: () => unawaited(
            context.read<TwoFactorEnrollmentCubit>().confirm(_code.text.trim()),
          ),
        ),
      ],
    );
  }
}
