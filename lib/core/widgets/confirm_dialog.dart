import 'package:flutter/material.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

Future<bool> confirmDeletion(
  BuildContext context, {
  required String title,
  required String message,
}) => confirmAction(
  context,
  title: title,
  message: message,
  confirmLabel: AppLocalizations.of(context).delete,
);

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
