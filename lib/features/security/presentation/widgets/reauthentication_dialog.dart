import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lar_em_dia/features/auth/presentation/widgets/google_account_button.dart';
import 'package:lar_em_dia/features/security/domain/two_factor.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

Future<Reauthentication?> askReauthentication(
  BuildContext context, {
  required String title,
  GoogleReauthentication? google,
}) => showDialog<Reauthentication>(
  context: context,
  builder: (_) => google == null
      ? _ReauthenticationDialog(title: title)
      : _GoogleReauthenticationDialog(title: title, google: google),
);

class _GoogleReauthenticationDialog extends StatelessWidget {
  const new({required this.title, required this.google});

  final String title;
  final GoogleReauthentication google;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.googleConfirmIdentity),
          const SizedBox(height: 16),
          GoogleAccountButton(
            label: l10n.googleContinue,
            rendersOwnButton: google.rendersOwnButton,
            idTokens: google.idTokens,
            onPressed: () => unawaited(google.start()),
            onIdToken: (token) =>
                Navigator.of(context).pop(Reauthentication(idToken: token)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

class _ReauthenticationDialog extends StatefulWidget {
  const new({required this.title});

  final String title;

  @override
  State<_ReauthenticationDialog> createState() =>
      _ReauthenticationDialogState();
}

class _ReauthenticationDialogState extends State<_ReauthenticationDialog> {
  final _password = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.securityConfirmIdentity),
          TextField(
            key: const Key('reauth_password'),
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.passwordLabel),
          ),
          TextField(
            key: const Key('reauth_code'),
            controller: _code,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l10n.twoFactorCodeLabel),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            Reauthentication(password: _password.text, code: _code.text.trim()),
          ),
          child: Text(l10n.securityConfirm),
        ),
      ],
    );
  }
}
