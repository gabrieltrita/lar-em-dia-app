import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/links/site_pages.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/auth/domain/login_result.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/auth_cubits.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/auth/presentation/widgets/google_account_button.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class GoogleSignInSection extends StatelessWidget {
  const new({super.key});

  Future<void> _onResult(
    BuildContext context,
    Submission<LoginResult> state,
  ) async {
    switch (state) {
      case SubmissionSuccess(value: LoginAuthenticated(:final user)):
        context.read<SessionCubit>().signedIn(user);
      case SubmissionSuccess(
        value: LoginTwoFactorRequired(:final challengeToken),
      ):
        context.go(AppRoutes.twoFactor, extra: challengeToken);
      case SubmissionFailure(:final error)
          when GoogleSignInCubit.needsConsents(error):
        final cubit = context.read<GoogleSignInCubit>();
        if (await _askConsents(context)) {
          await cubit.acceptConsents();
        }
      case _:
        break;
    }
  }

  Future<bool> _askConsents(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.googleConsentsTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.googleConsentsMessage),
            TextButton(
              onPressed: () => unawaited(openSitePage(SitePage.terms)),
              child: Text(l10n.registerReadTerms),
            ),
            TextButton(
              onPressed: () => unawaited(openSitePage(SitePage.privacy)),
              child: Text(l10n.registerReadPrivacy),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.googleConsentsAccept),
          ),
        ],
      ),
    );
    return accepted ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<GoogleSignInCubit>();
    if (!cubit.enabled) {
      return const SizedBox.shrink();
    }
    return BlocConsumer<GoogleSignInCubit, Submission<LoginResult>>(
      listener: (context, state) => unawaited(_onResult(context, state)),
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(l10n.googleOr),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          GoogleAccountButton(
            label: l10n.googleContinue,
            rendersOwnButton: cubit.rendersOwnButton,
            idTokens: cubit.idTokens,
            onPressed: () => unawaited(cubit.start()),
            onIdToken: (token) => unawaited(cubit.submit(token)),
          ),
          if (state is SubmissionInProgress<LoginResult>) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (state case SubmissionFailure(:final error)
              when !GoogleSignInCubit.needsConsents(error)) ...[
            const SizedBox(height: 16),
            ErrorBanner([error.localized(l10n)]),
          ],
        ],
      ),
    );
  }
}
