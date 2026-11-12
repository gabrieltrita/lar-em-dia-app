import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/per_share.dart';
import 'package:lar_em_dia/core/theme/finance_colors.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/portfolio.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

String quoteLabel(AppLocalizations l10n, AssetQuote? quote) => switch (quote) {
  final quote? => l10n.investmentsQuoteOn(
    Money.format(quote.closeCents),
    Dates.display(quote.quotedOn),
  ),
  null => l10n.investmentsNoQuote,
};

class GainText extends StatelessWidget {
  const new(this.bps, {this.style, super.key});

  final int? bps;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = FinanceColors.of(context);
    final value = bps ?? 0;
    return Text(
      PerShare.percentFromBps(value, signed: true),
      style: (style ?? const TextStyle()).copyWith(
        color: switch (value) {
          > 0 => colors.positive,
          < 0 => colors.negative,
          _ => null,
        },
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class PositionTile extends StatelessWidget {
  const new({required this.position, required this.onTap, super.key});

  final PortfolioPosition position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: position.ticker,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: '  ${position.name}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          l10n.investmentsShares(position.quantity),
          l10n.investmentsAveragePrice(
            PerShare.formatE8(position.averagePriceE8),
          ),
          quoteLabel(l10n, position.quote),
        ].join(' · '),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(Money.format(position.marketValueCents)),
          GainText(position.gainBps, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
