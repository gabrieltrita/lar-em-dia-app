import 'package:flutter/material.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

Future<EntryScope?> askEntryScope(
  BuildContext context, {
  required String title,
  required Entry entry,
}) {
  final l10n = AppLocalizations.of(context);
  final labels = {
    EntryScope.one: l10n.entryScopeOne,
    EntryScope.following: l10n.entryScopeFollowing,
    EntryScope.all: l10n.entryScopeAll,
  };
  return showDialog<EntryScope>(
    context: context,
    barrierDismissible: false,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(l10n.entryScopeQuestion(entry.description)),
        ),
        for (final MapEntry(key: scope, value: label) in labels.entries)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(scope),
            child: Text(label),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    ),
  );
}
