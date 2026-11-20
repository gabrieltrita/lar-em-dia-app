import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/routing/app_router.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/empty_state.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/core/widgets/skeleton.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/screener.dart';
import 'package:lar_em_dia/features/investments/domain/screener_presets.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/asset_alert_chips.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/indicator_labels.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/investments_disclaimer.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class ExplorePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ExploreCubit>();
    final state = context.watch<ExploreCubit>().state;
    final query = state.query;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exploreTitle)),
      bottomNavigationBar: InvestmentsDisclaimer(text: l10n.exploreDisclaimer),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SegmentedButton<AssetType>(
                segments: [
                  ButtonSegment(
                    value: AssetType.fii,
                    label: Text(l10n.exploreTypeFii),
                  ),
                  ButtonSegment(
                    value: AssetType.stock,
                    label: Text(l10n.exploreTypeStock),
                  ),
                ],
                selected: {query.type},
                onSelectionChanged: (selection) =>
                    unawaited(cubit.apply(query.withType(selection.single))),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _Strategies(query: query)),
          SliverToBoxAdapter(child: _Criteria(query: query)),
          SliverToBoxAdapter(
            child: _SortBar(query: query, total: state.total),
          ),
          ..._results(context, state),
        ],
      ),
    );
  }

  static List<Widget> _results(BuildContext context, ExploreState state) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ExploreCubit>();
    return switch (state.results) {
      Loading() => [
        SliverFillRemaining(child: SkeletonList(label: l10n.loadingLabel)),
      ],
      LoadFailure(:final error) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: RetryMessage(
            message: error.localized(l10n),
            onRetry: () => unawaited(cubit.load()),
          ),
        ),
      ],
      Loaded(value: final assets) when assets.isEmpty => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: l10n.exploreEmptyTitle,
            message: l10n.exploreEmptyMessage,
          ),
        ),
      ],
      Loaded(value: final assets) => [
        SliverList.list(
          children: [for (final asset in assets) _ResultCard(asset: asset)],
        ),
        if (state.nextPage != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: state.loadingMore
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: () => unawaited(cubit.loadMore()),
                        child: Text(l10n.exploreLoadMore),
                      ),
              ),
            ),
          ),
      ],
    };
  }
}

class _Strategies extends StatelessWidget {
  const new({required this.query});

  final ScreenerQuery query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cubit = context.read<ExploreCubit>();
    final strategies = ScreenerStrategy.forType(query.type);
    final selected = strategies.where((s) => s.matches(query)).firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.exploreStrategiesTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final strategy in strategies)
                ChoiceChip(
                  key: Key('strategy_${strategy.name}'),
                  label: Text(strategy.label(l10n)),
                  selected: strategy == selected,
                  onSelected: (on) => unawaited(
                    cubit.apply(
                      on ? strategy.query : ScreenerQuery(type: query.type),
                    ),
                  ),
                ),
            ],
          ),
          if (selected != null) ...[
            const SizedBox(height: 8),
            Text(selected.hint(l10n), style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _Criteria extends StatelessWidget {
  const new({required this.query});

  final ScreenerQuery query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cubit = context.read<ExploreCubit>();
    final chips = [
      for (final category in query.activeCategories)
        (
          category.label(l10n),
          query.copyWith(categories: {...query.categories}..remove(category)),
        ),
      if (query.hidesSingleProperty)
        (
          l10n.exploreHideSingleProperty,
          query.copyWith(hideSingleProperty: false),
        ),
      if (query.hidesDevelopment)
        (l10n.exploreHideDevelopment, query.copyWith(hideDevelopment: false)),
      if (query.payingOnly)
        (l10n.explorePayingOnly, query.copyWith(payingOnly: false)),
      for (final MapEntry(key: indicator, value: range)
          in query.activeRanges.entries)
        (indicator.criterion(l10n, range), query.withRange(indicator, null)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chips.isEmpty)
            Text(l10n.exploreCriteriaEmpty, style: theme.textTheme.bodySmall)
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (label, without) in chips)
                  InputChip(
                    label: Text(label),
                    onDeleted: () => unawaited(cubit.apply(without)),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('explore_filters'),
            icon: const Icon(Icons.tune),
            label: Text(l10n.exploreCustomize),
            onPressed: () => unawaited(_openFilters(context)),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters(BuildContext context) async {
    final cubit = context.read<ExploreCubit>();
    final applied = await showModalBottomSheet<ScreenerQuery>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FiltersSheet(query: query),
    );
    if (applied != null) {
      await cubit.apply(applied);
    }
  }
}

class _SortBar extends StatelessWidget {
  const new({required this.query, required this.total});

  final ScreenerQuery query;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ExploreCubit>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          if (total case final count?)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(l10n.exploreResultsCount(count)),
            ),
          Text(l10n.exploreSort),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<Indicator>(
              key: const Key('explore_sort'),
              isExpanded: true,
              value: query.sort,
              items: [
                for (final indicator in Indicator.forType(query.type))
                  DropdownMenuItem(
                    value: indicator,
                    child: Text(indicator.label(l10n)),
                  ),
              ],
              onChanged: (indicator) =>
                  unawaited(cubit.apply(query.copyWith(sort: indicator!))),
            ),
          ),
          IconButton(
            key: const Key('explore_direction'),
            tooltip: query.ascending
                ? l10n.exploreAscending
                : l10n.exploreDescending,
            icon: Icon(
              query.ascending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
            onPressed: () => unawaited(
              cubit.apply(query.copyWith(ascending: !query.ascending)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const new({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final indicators = asset.indicators;
    final figures = [
      for (final indicator in asset.type.highlights)
        if (indicators?.value(indicator) case final value?)
          (indicator.label(l10n), indicator.format(l10n, value)),
    ];
    final alerts = indicators?.alerts(asset.type) ?? const <AssetAlert>[];
    final subtitle = [
      ?indicators?.fundCategory?.label(l10n),
      ?asset.sector,
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            unawaited(context.push<void>(AppRoutes.assetDetail(asset.ticker))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(asset.ticker, style: theme.textTheme.titleMedium),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      subtitle,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              Text(
                asset.name,
                style: theme.textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
              if (figures.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    for (final (label, value) in figures)
                      SizedBox(
                        width: 130,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: theme.textTheme.labelSmall),
                            Text(value, style: theme.textTheme.titleSmall),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              if (alerts.isNotEmpty) ...[
                const SizedBox(height: 12),
                AssetAlertChips(alerts: alerts),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  const new({required this.query});

  final ScreenerQuery query;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late ScreenerQuery _query = widget.query;

  void _update(ScreenerQuery query) => setState(() => _query = query);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final type = _query.type;
    final groups = <IndicatorGroup, List<Indicator>>{};
    for (final indicator in Indicator.forType(type)) {
      (groups[indicator.group] ??= []).add(indicator);
    }
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.exploreFilters, style: theme.textTheme.titleMedium),
                  if (type == AssetType.fii) ..._fundOptions(l10n, theme),
                  SwitchListTile(
                    key: const Key('explore_paying'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.explorePayingOnly),
                    subtitle: Text(l10n.explorePayingOnlyHint),
                    value: _query.payingOnly,
                    onChanged: (value) =>
                        _update(_query.copyWith(payingOnly: value)),
                  ),
                  for (final MapEntry(key: group, value: indicators)
                      in groups.entries) ...[
                    const SizedBox(height: 16),
                    Text(group.label(l10n), style: theme.textTheme.titleSmall),
                    for (final indicator in indicators)
                      _IndicatorOptions(
                        indicator: indicator,
                        type: type,
                        selected: _query.activeRanges[indicator],
                        onSelected: (range) =>
                            _update(_query.withRange(indicator, range)),
                      ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _update(
                      ScreenerQuery(
                        type: type,
                        sort: _query.sort,
                        ascending: _query.ascending,
                      ),
                    ),
                    child: Text(l10n.exploreClear),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('explore_apply'),
                    onPressed: () => Navigator.of(context).pop(_query),
                    child: Text(l10n.exploreApply),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _fundOptions(AppLocalizations l10n, ThemeData theme) => [
    const SizedBox(height: 16),
    Text(l10n.exploreFundCategories, style: theme.textTheme.titleSmall),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final category in FundCategory.values)
          FilterChip(
            key: Key('category_${category.name}'),
            label: Text(category.label(l10n)),
            selected: _query.categories.contains(category),
            onSelected: (on) => _update(
              _query.copyWith(
                categories: on
                    ? {..._query.categories, category}
                    : ({..._query.categories}..remove(category)),
              ),
            ),
          ),
      ],
    ),
    SwitchListTile(
      key: const Key('explore_single_property'),
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.exploreHideSingleProperty),
      subtitle: Text(l10n.exploreHideSinglePropertyHint),
      value: _query.hideSingleProperty,
      onChanged: (value) => _update(_query.copyWith(hideSingleProperty: value)),
    ),
    SwitchListTile(
      key: const Key('explore_development'),
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.exploreHideDevelopment),
      subtitle: Text(l10n.exploreHideDevelopmentHint),
      value: _query.hideDevelopment,
      onChanged: (value) => _update(_query.copyWith(hideDevelopment: value)),
    ),
  ];
}

class _IndicatorOptions extends StatelessWidget {
  const new({
    required this.indicator,
    required this.type,
    required this.selected,
    required this.onSelected,
  });

  final Indicator indicator;
  final AssetType type;
  final IndicatorRange? selected;
  final ValueChanged<IndicatorRange?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = indicator.options(type);
    final current = selected;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(indicator.label(l10n)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                key: Key('option_${indicator.name}_any'),
                label: Text(l10n.exploreAnyValue),
                selected: current == null,
                onSelected: (_) => onSelected(null),
              ),
              for (final (index, option) in options.indexed)
                ChoiceChip(
                  key: Key('option_${indicator.name}_$index'),
                  label: Text(indicator.range(l10n, option)),
                  selected: option == current,
                  onSelected: (_) => onSelected(option),
                ),
              if (current != null && !options.contains(current))
                ChoiceChip(
                  label: Text(indicator.range(l10n, current)),
                  selected: true,
                  onSelected: (_) {},
                ),
            ],
          ),
        ],
      ),
    );
  }
}
