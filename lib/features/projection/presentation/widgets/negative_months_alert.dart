import 'package:flutter/material.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class NegativeMonthsAlert extends StatelessWidget {
  const new({
    required this.firstMonth,
    required this.count,
    this.onTap,
    super.key,
  });

  final DateTime firstMonth;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final month = MaterialLocalizations.of(context).formatMonthYear(firstMonth);
    return Card(
      color: colors.errorContainer,
      child: ListTile(
        leading: Icon(Icons.warning_amber, color: colors.onErrorContainer),
        title: Text(
          l10n.negativeMonthsAlert(count, month),
          style: TextStyle(color: colors.onErrorContainer),
        ),
        trailing: onTap == null
            ? null
            : Icon(Icons.chevron_right, color: colors.onErrorContainer),
        onTap: onTap,
      ),
    );
  }
}
