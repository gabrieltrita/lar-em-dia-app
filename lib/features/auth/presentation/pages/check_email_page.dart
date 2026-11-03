import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:lar_em_dia/features/auth/presentation/widgets/form_widgets.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class CheckEmailPage extends StatefulWidget {
  const new({this.email, super.key});

  final String? email;

  @override
  State<CheckEmailPage> createState() => _CheckEmailPageState();
}

class _CheckEmailPageState extends State<CheckEmailPage> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.email);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    unawaited(
      context.read<ResendConfirmationCubit>().submit(_email.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<ResendConfirmationCubit, Submission<void>>(
      builder: (context, state) => AuthScaffold(
        title: l10n.checkEmailTitle,
        children: [
          InfoMessage(l10n.checkEmailDescription),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: TextFormField(
              key: const Key('check_email_email'),
              controller: _email,
              decoration: InputDecoration(labelText: l10n.emailLabel),
              keyboardType: TextInputType.emailAddress,
              validator: validateWith(l10n, Validators.email),
            ),
          ),
          if (state is SubmissionSuccess) ...[
            const SizedBox(height: 16),
            InfoMessage(l10n.checkEmailResent),
          ],
          if (state case SubmissionFailure(:final error)) ...[
            const SizedBox(height: 16),
            ErrorBanner([error.localized(l10n)]),
          ],
          const SizedBox(height: 24),
          SubmitButton(
            label: l10n.checkEmailResend,
            busy: state is SubmissionInProgress,
            onPressed: _submit,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: Text(l10n.backToLogin),
          ),
        ],
      ),
    );
  }
}
