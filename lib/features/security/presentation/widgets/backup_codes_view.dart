import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class BackupCodesView extends StatelessWidget {
  const new({required this.codes, required this.onDone, super.key});

  final List<String> codes;
  final VoidCallback onDone;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = AppLocalizations.of(context).copied;
    await Clipboard.setData(ClipboardData(text: codes.join('\n')));
    messenger.showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.backupCodesTitle, style: textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(l10n.backupCodesHint),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              codes.join('\n'),
              style: textTheme.titleMedium?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy),
          label: Text(l10n.backupCodesCopy),
          onPressed: () => unawaited(_copy(context)),
        ),
        const SizedBox(height: 8),
        FilledButton(onPressed: onDone, child: Text(l10n.backupCodesDone)),
      ],
    );
  }
}
