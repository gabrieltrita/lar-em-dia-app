import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class ConfirmEmailPage extends StatefulWidget {
  const new({this.token, super.key});

  final String? token;

  @override
  State<ConfirmEmailPage> createState() => _ConfirmEmailPageState();
}

class _ConfirmEmailPageState extends State<ConfirmEmailPage> {
  @override
  void initState() {
    super.initState();
    final token = widget.token;
    if (token != null) {
      unawaited(context.read<ConfirmEmailCubit>().submit(token));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<ConfirmEmailCubit, Submission<AuthUser>>(
      listener: (context, state) {
        if (state case SubmissionSuccess(:final value)) {
          context.read<SessionCubit>().signedIn(value);
        }
      },
      builder: (context, state) {
        final invalid = widget.token == null || state is SubmissionFailure;
        return AuthScaffold(
          title: l10n.confirmEmailTitle,
          children: invalid
              ? [
                  InfoMessage(l10n.confirmEmailInvalid),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(AppRoutes.checkEmail),
                    child: Text(l10n.confirmEmailRequestNew),
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
