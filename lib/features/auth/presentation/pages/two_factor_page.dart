import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:lar_em_dia/features/auth/presentation/widgets/form_widgets.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class TwoFactorPage extends StatefulWidget {
  const new({required this.challengeToken, super.key});

  final String challengeToken;

  @override
  State<TwoFactorPage> createState() => _TwoFactorPageState();
}

class _TwoFactorPageState extends State<TwoFactorPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    unawaited(
      context.read<TwoFactorCubit>().submit(
        challengeToken: widget.challengeToken,
        code: _code.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<TwoFactorCubit, Submission<AuthUser>>(
      listener: (context, state) {
        if (state case SubmissionSuccess(:final value)) {
          context.read<SessionCubit>().signedIn(value);
        }
      },
      builder: (context, state) => AuthScaffold(
        title: l10n.twoFactorTitle,
        children: [
          InfoMessage(l10n.twoFactorDescription),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: TextFormField(
              key: const Key('two_factor_code'),
              controller: _code,
              decoration: InputDecoration(labelText: l10n.twoFactorCodeLabel),
              autofillHints: const [AutofillHints.oneTimeCode],
              onFieldSubmitted: (_) => _submit(),
              validator: validateWith(l10n, Validators.required),
            ),
          ),
          if (state case SubmissionFailure(:final error)) ...[
            const SizedBox(height: 16),
            ErrorBanner([error.localized(l10n)]),
          ],
          const SizedBox(height: 24),
          SubmitButton(
            label: l10n.twoFactorSubmit,
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
