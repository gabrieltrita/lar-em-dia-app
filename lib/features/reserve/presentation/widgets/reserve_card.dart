import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/widgets/money_text.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/reserve/presentation/cubits/reserve_cubits.dart';
import 'package:lar_em_dia/features/reserve/presentation/widgets/coverage_bar.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

Future<void> openReserve(BuildContext context) =>
    context.push<void>(AppRoutes.reserve);

class ReserveCardView extends StatelessWidget {
  const new({
    this.alwaysShow = false,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final bool alwaysShow;
  final EdgeInsetsGeometry padding;

  Widget? _content(ReserveCard? card) => switch (card) {
    null => null,
    ReserveCard(:final summary) when !summary.isEmpty => _Totals(
      summary: summary,
    ),
    _ when alwaysShow => const _Introduction(),
    final card when card.visible => _NoReserve(summary: card.summary),
    _ => null,
  };

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ReserveCardCubit, ReserveCard?>(
        builder: (context, card) => switch (_content(card)) {
          final content? => Padding(padding: padding, child: content),
          null => const SizedBox.shrink(),
        },
      );
}

class _Frame extends StatelessWidget {
  const new({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('reserve_card'),
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

class _Title extends StatelessWidget {
  const new({this.trailing});

  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.savings_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          AppLocalizations.of(context).reserveTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      ?trailing,
    ],
  );
}

class _Totals extends StatelessWidget {
  const new({required this.summary});

  final ReserveSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Frame(
      onTap: () => unawaited(openReserve(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title(trailing: Icon(Icons.chevron_right)),
          const SizedBox(height: 8),
          MoneyText(
            summary.totals.netCents,
            style: theme.textTheme.headlineSmall,
          ),
          if (summary.suggestion case final suggestion?) ...[
            const SizedBox(height: 8),
            CoverageBar(
              coverageMonthsE2: suggestion.coverageMonthsE2,
              goalMonths: summary.goal.months,
            ),
          ],
          const SizedBox(height: 8),
          for (final account in summary.accounts)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      account.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  MoneyText(
                    account.value.netCents,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NoReserve extends StatelessWidget {
  const new({required this.summary});

  final ReserveSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final average = summary.suggestion?.averageFixedCents ?? 0;
    return _Frame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title(),
          const SizedBox(height: 8),
          Text(l10n.reserveNoReserveMessage(Money.format(average))),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton(
                onPressed: () =>
                    unawaited(context.read<ReserveCardCubit>().dismiss()),
                child: Text(l10n.reserveNotNow),
              ),
              FilledButton(
                onPressed: () => unawaited(openReserve(context)),
                child: Text(l10n.reserveInform),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Introduction extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Frame(
      onTap: () => unawaited(openReserve(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title(trailing: Icon(Icons.chevron_right)),
          const SizedBox(height: 8),
          Text(l10n.reserveIntroduction),
        ],
      ),
    );
  }
}
