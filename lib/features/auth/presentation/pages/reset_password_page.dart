import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class ResetPasswordPage extends StatefulWidget {
  const new({this.token, super.key});

  final String? token;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  static const _invalidTokenCode = 'invalid_reset_token';

  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    unawaited(
      context.read<ResetPasswordCubit>().submit(
        token: widget.token!,
        password: _password.text,
      ),
    );
  }

  List<Widget> _invalidLink(AppLocalizations l10n) => [
    InfoMessage(l10n.resetPasswordInvalid),
    const SizedBox(height: 24),
    FilledButton(
      onPressed: () => context.go(AppRoutes.forgotPassword),
      child: Text(l10n.confirmEmailRequestNew),
    ),
  ];

  List<Widget> _done(AppLocalizations l10n) => [
    InfoMessage(l10n.resetPasswordDone),
    const SizedBox(height: 24),
    FilledButton(
      onPressed: () => context.go(AppRoutes.login),
      child: Text(l10n.loginSubmit),
    ),
  ];

  List<Widget> _form(AppLocalizations l10n, Submission<void> state) => [
    Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const Key('reset_password_password'),
            controller: _password,
            decoration: InputDecoration(
              labelText: l10n.passwordLabel,
              helperText: l10n.passwordHint,
              helperMaxLines: 2,
            ),
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            validator: validateWith(l10n, Validators.password),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('reset_password_confirmation'),
            controller: _confirmation,
            decoration: InputDecoration(
              labelText: l10n.passwordConfirmationLabel,
            ),
            obscureText: true,
            onFieldSubmitted: (_) => _submit(),
            validator: validateWith(
              l10n,
              (value) => Validators.matches(value, _password.text),
            ),
          ),
        ],
      ),
    ),
    if (state case SubmissionFailure(:final error)) ...[
      const SizedBox(height: 16),
      ErrorBanner([
        error.localized(l10n),
        if (error.localizedField(l10n, 'password') case final message?)
          '${l10n.passwordLabel}: $message',
      ]),
    ],
    const SizedBox(height: 24),
    SubmitButton(
      label: l10n.resetPasswordSubmit,
      busy: state is SubmissionInProgress,
      onPressed: _submit,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<ResetPasswordCubit, Submission<void>>(
      builder: (context, state) {
        final invalid =
            widget.token == null ||
            (state is SubmissionFailure<void> &&
                state.error.code == _invalidTokenCode);
        return AuthScaffold(
          title: l10n.resetPasswordTitle,
          children: switch (state) {
            _ when invalid => _invalidLink(l10n),
            SubmissionSuccess() => _done(l10n),
            _ => _form(l10n, state),
          },
        );
      },
    );
  }
}
