import 'package:flutter/material.dart';
import 'package:lar_em_dia/features/security/domain/two_factor.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

Future<Reauthentication?> askReauthentication(
  BuildContext context, {
  required String title,
}) => showDialog<Reauthentication>(
  context: context,
  builder: (_) => _ReauthenticationDialog(title: title),
);

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
