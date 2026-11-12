import 'package:flutter/material.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class ReserveDisclaimer extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            AppLocalizations.of(context).reserveDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
