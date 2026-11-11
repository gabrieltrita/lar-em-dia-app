import 'package:flutter/material.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfoFooter extends StatefulWidget {
  const new({super.key});

  @override
  State<AppInfoFooter> createState() => _AppInfoFooterState();
}

class _AppInfoFooterState extends State<AppInfoFooter> {
  final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: FutureBuilder<PackageInfo>(
        future: _info,
        builder: (context, snapshot) => Column(
          children: [
            Text(
              l10n.moreCopyright('${DateTime.now().year}'),
              style: style,
              textAlign: TextAlign.center,
            ),
            if (snapshot.data case final info?)
              Text(
                l10n.moreVersion(info.version, info.buildNumber),
                style: style,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
