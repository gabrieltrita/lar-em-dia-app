import 'package:flutter/material.dart';
import 'package:lar_em_dia/features/admin/domain/admin_user.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class AdminBadges extends StatelessWidget {
  const new({required this.user, super.key});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final badges = [
      if (user.isAdmin) (l10n.adminBadgeAdmin, colors.primaryContainer),
      if (user.deactivated) (l10n.adminBadgeDeactivated, colors.errorContainer),
      if (user.locked) (l10n.adminBadgeLocked, colors.tertiaryContainer),
      if (user.twoFactorEnabled)
        (l10n.adminBadgeTwoFactor, colors.secondaryContainer),
    ];
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final (label, color) in badges)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label, style: Theme.of(context).textTheme.labelSmall),
          ),
      ],
    );
  }
}
