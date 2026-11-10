import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/auth/domain/login_result.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class UnlockPage extends StatefulWidget {
  const new({this.token, super.key});

  final String? token;

  @override
  State<UnlockPage> createState() => _UnlockPageState();
}

class _UnlockPageState extends State<UnlockPage> {
  @override
  void initState() {
    super.initState();
    final token = widget.token;
    if (token != null) {
      unawaited(context.read<UnlockCubit>().submit(token));
    }
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
    return BlocConsumer<UnlockCubit, Submission<LoginResult>>(
      listener: _onResult,
      builder: (context, state) {
        final invalid = widget.token == null || state is SubmissionFailure;
        return AuthScaffold(
          title: l10n.unlockTitle,
          children: invalid
              ? [
                  InfoMessage(l10n.errorInvalidUnlockToken),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.forgotPassword),
                    child: Text(l10n.unlockForgotPassword),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: Text(l10n.backToLogin),
                  ),
                ]
              : const [Center(child: CircularProgressIndicator())],
        );
      },
    );
  }
}
