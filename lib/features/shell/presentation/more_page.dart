import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/links/site_pages.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/features/auth/domain/auth_user.dart';
import 'package:lar_em_dia/features/auth/presentation/cubits/session_cubit.dart';
import 'package:lar_em_dia/features/shell/presentation/app_info_footer.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class MorePage extends StatelessWidget {
  const new({super.key, this.showSupport = kIsWeb});

  final bool showSupport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = context.select<SessionCubit, AuthUser?>(
      (cubit) => switch (cubit.state) {
        SessionAuthenticated(:final user) => user,
        _ => null,
      },
    );
    ListTile link(IconData icon, String label, String route) => ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => unawaited(context.push<void>(route)),
    );
    Widget header(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(label.toUpperCase(), style: theme.textTheme.labelMedium),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l10n.shellMore)),
      body: ListView(
        children: [
          if (user != null)
            ListTile(
              leading: CircleAvatar(
                child: Text(user.firstName.characters.first),
              ),
              title: Text(
                [user.firstName, ?user.lastName].join(' '),
                style: theme.textTheme.titleMedium,
              ),
              subtitle: Text(user.email),
            ),
          header(l10n.moreFinances),
          link(
            Icons.account_balance_wallet_outlined,
            l10n.moreBalances,
            AppRoutes.balances,
          ),
          link(Icons.event_outlined, l10n.shellDue, AppRoutes.due),
          link(Icons.call_split, l10n.allocationMoreLink, AppRoutes.allocation),
          header(l10n.moreAccount),
          link(Icons.lock_outline, l10n.moreSecurity, AppRoutes.account),
          link(
            Icons.notifications_outlined,
            l10n.notificationsTitle,
            AppRoutes.notificationSettings,
          ),
          if (user?.isAdmin ?? false) ...[
            header(l10n.adminTitle),
            link(
              Icons.people_outline,
              l10n.adminManageUsers,
              AppRoutes.adminUsers,
            ),
            link(
              Icons.insights_outlined,
              l10n.adminMetrics,
              AppRoutes.adminMetrics,
            ),
            link(
              Icons.category_outlined,
              l10n.adminCategories,
              AppRoutes.adminCategories,
            ),
          ],
          if (showSupport) ...[
            header(l10n.moreAbout),
            ListTile(
              leading: const Icon(Icons.favorite_outline),
              title: Text(l10n.moreSupport),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => unawaited(openSitePage(SitePage.support)),
            ),
          ],
          const Divider(height: 32),
          ListTile(
            leading: Icon(Icons.logout, color: theme.colorScheme.error),
            title: Text(
              l10n.logout,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => unawaited(context.read<SessionCubit>().logout()),
          ),
          const AppInfoFooter(),
        ],
      ),
    );
  }
}
