import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/auth/domain/registration.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class RegisterPage extends StatefulWidget {
  const new({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _email,
      _password,
      _confirmation,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final lastName = _lastName.text.trim();
    unawaited(
      context.read<RegisterCubit>().submit(
        Registration(
          firstName: _firstName.text.trim(),
          lastName: lastName.isEmpty ? null : lastName,
          email: _email.text.trim(),
          password: _password.text,
          acceptTerms: true,
          acceptPrivacy: true,
        ),
      ),
    );
  }

  List<String> _failureMessages(AppLocalizations l10n, ApiError error) {
    final labels = {
      'first_name': l10n.firstNameLabel,
      'last_name': l10n.lastNameLabel,
      'email': l10n.emailLabel,
      'password': l10n.passwordLabel,
    };
    return [
      error.localized(l10n),
      for (final MapEntry(:key, :value) in labels.entries)
        if (error.localizedField(l10n, key) case final message?)
          '$value: $message',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<RegisterCubit, Submission<String>>(
      listener: (context, state) {
        if (state case SubmissionSuccess(:final value)) {
          context.go(AppRoutes.checkEmail, extra: value);
        }
      },
      builder: (context, state) => AuthScaffold(
        title: l10n.registerTitle,
        children: [
          Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('register_first_name'),
                    controller: _firstName,
                    decoration: InputDecoration(labelText: l10n.firstNameLabel),
                    autofillHints: const [AutofillHints.givenName],
                    textInputAction: TextInputAction.next,
                    validator: validateWith(l10n, Validators.required),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('register_last_name'),
                    controller: _lastName,
                    decoration: InputDecoration(labelText: l10n.lastNameLabel),
                    autofillHints: const [AutofillHints.familyName],
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('register_email'),
                    controller: _email,
                    decoration: InputDecoration(labelText: l10n.emailLabel),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: validateWith(l10n, Validators.email),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('register_password'),
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
                    key: const Key('register_password_confirmation'),
                    controller: _confirmation,
                    decoration: InputDecoration(
                      labelText: l10n.passwordConfirmationLabel,
                    ),
                    obscureText: true,
                    validator: validateWith(
                      l10n,
                      (value) => Validators.matches(value, _password.text),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConsentField(
                    key: const Key('register_accept_terms'),
                    label: l10n.registerAcceptTerms,
                    requiredMessage: l10n.validationRequired,
                  ),
                  ConsentField(
                    key: const Key('register_accept_privacy'),
                    label: l10n.registerAcceptPrivacy,
                    requiredMessage: l10n.validationRequired,
                  ),
                ],
              ),
            ),
          ),
          if (state case SubmissionFailure(:final error)) ...[
            const SizedBox(height: 16),
            ErrorBanner(_failureMessages(l10n, error)),
          ],
          const SizedBox(height: 24),
          SubmitButton(
            label: l10n.registerSubmit,
            busy: state is SubmissionInProgress,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: Text(l10n.registerHaveAccount),
          ),
        ],
      ),
    );
  }
}
