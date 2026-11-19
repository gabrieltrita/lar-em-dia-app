import 'package:flutter/material.dart';
import 'package:lar_em_dia/features/investments/domain/screener_presets.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/indicator_labels.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class AssetAlertChips extends StatelessWidget {
  const new({required this.alerts, super.key});

  final List<AssetAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final alert in alerts)
          Chip(
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            avatar: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: colors.onErrorContainer,
            ),
            label: Text(alert.label(l10n)),
            labelStyle: TextStyle(color: colors.onErrorContainer),
            backgroundColor: colors.errorContainer,
            side: BorderSide.none,
          ),
      ],
    );
  }
}
