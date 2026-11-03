import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/auth/domain/login_result.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const new({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    unawaited(
      context.read<LoginCubit>().submit(
        email: _email.text.trim(),
        password: _password.text,
      ),
    );
  }

  void _onResult(BuildContext context, Submission<LoginResult> state) {
    if (state case SubmissionSuccess(:final value)) {
      switch (value) {
        case LoginAuthenticated(:final user):
          context.read<SessionCubit>().signedIn(user);
        case LoginTwoFactorRequired(:final challengeToken):
          context.go(AppRoutes.twoFactor, extra: challengeToken);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<LoginCubit, Submission<LoginResult>>(
      listener: _onResult,
      builder: (context, state) => AuthScaffold(
        title: l10n.loginTitle,
        children: [
          Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('login_email'),
                    controller: _email,
                    decoration: InputDecoration(labelText: l10n.emailLabel),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: validateWith(l10n, Validators.email),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('login_password'),
                    controller: _password,
                    decoration: InputDecoration(labelText: l10n.passwordLabel),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    validator: validateWith(l10n, Validators.required),
                  ),
                ],
              ),
            ),
          ),
          if (state case SubmissionFailure(:final error)) ...[
            const SizedBox(height: 16),
            ErrorBanner([error.localized(l10n)]),
            if (error.code == 'email_not_confirmed')
              TextButton(
                onPressed: () =>
                    context.go(AppRoutes.checkEmail, extra: _email.text.trim()),
                child: Text(l10n.loginResendConfirmation),
              ),
          ],
          const SizedBox(height: 24),
          SubmitButton(
            label: l10n.loginSubmit,
            busy: state is SubmissionInProgress,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go(AppRoutes.forgotPassword),
            child: Text(l10n.loginForgotPassword),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.register),
            child: Text(l10n.loginCreateAccount),
          ),
        ],
      ),
    );
  }
}
