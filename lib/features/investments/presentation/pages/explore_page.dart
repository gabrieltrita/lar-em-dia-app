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
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
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
      appBar: AppBar(
        title: Text(l10n.exploreTitle),
        actions: [
          TextButton.icon(
            key: const Key('explore_filters'),
            icon: const Icon(Icons.tune),
            label: Text(l10n.exploreActiveFilters(_filterCount(query))),
            onPressed: () => unawaited(_openFilters(context, query)),
          ),
        ],
      ),
      bottomNavigationBar: InvestmentsDisclaimer(text: l10n.exploreDisclaimer),
      body: Column(
        children: [
          Padding(
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
          _SortBar(query: query),
          Expanded(
            child: switch (state.results) {
              Loading() => SkeletonList(label: l10n.loadingLabel),
              LoadFailure(:final error) => RetryMessage(
                message: error.localized(l10n),
                onRetry: () => unawaited(cubit.load()),
              ),
              Loaded(value: final assets) when assets.isEmpty => EmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: l10n.exploreEmptyTitle,
                message: l10n.exploreEmptyMessage,
              ),
              Loaded(value: final assets) => ListView(
                children: [
                  for (final asset in assets) _ResultTile(asset: asset),
                  if (state.nextPage != null)
                    Padding(
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
                ],
              ),
            },
          ),
        ],
      ),
    );
  }

  static int _filterCount(ScreenerQuery query) =>
      query.activeRanges.length + (query.payingOnly ? 1 : 0);

  static Future<void> _openFilters(
    BuildContext context,
    ScreenerQuery query,
  ) async {
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
  const new({required this.query});

  final ScreenerQuery query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ExploreCubit>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Text(l10n.exploreSort),
          const SizedBox(width: 12),
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

class _ResultTile extends StatelessWidget {
  const new({required this.asset});

  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final indicators = asset.indicators;
    final figures = [
      for (final indicator in asset.type.highlights)
        if (indicators?.value(indicator) case final value?)
          '${indicator.label(l10n)} ${indicator.format(l10n, value)}',
    ];
    return ListTile(
      title: Text(asset.ticker),
      subtitle: Text(
        [
          [asset.name, ?asset.sector].join(' · '),
          if (figures.isNotEmpty) figures.join(' · '),
        ].join('\n'),
      ),
      isThreeLine: figures.isNotEmpty,
      trailing: const Icon(Icons.chevron_right),
      onTap: () =>
          unawaited(context.push<void>(AppRoutes.assetDetail(asset.ticker))),
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
  final _form = GlobalKey<FormState>();
  late bool _payingOnly = widget.query.payingOnly;
  late final Map<Indicator, (TextEditingController, TextEditingController)>
  _fields = {
    for (final indicator in Indicator.forType(widget.query.type))
      indicator: (
        _controller(indicator, widget.query.ranges[indicator]?.min),
        _controller(indicator, widget.query.ranges[indicator]?.max),
      ),
  };

  static TextEditingController _controller(Indicator indicator, int? value) =>
      TextEditingController(text: value == null ? '' : indicator.input(value));

  @override
  void dispose() {
    for (final (min, max) in _fields.values) {
      min.dispose();
      max.dispose();
    }
    super.dispose();
  }

  void _apply() {
    if (!_form.currentState!.validate()) {
      return;
    }
    int? read(Indicator indicator, TextEditingController field) =>
        field.text.trim().isEmpty ? null : indicator.parse(field.text);
    Navigator.of(context).pop(
      widget.query.copyWith(
        payingOnly: _payingOnly,
        ranges: {
          for (final MapEntry(key: indicator, value: (min, max))
              in _fields.entries)
            indicator: IndicatorRange(
              min: read(indicator, min),
              max: read(indicator, max),
            ),
        },
      ),
    );
  }

  void _clear() {
    setState(() => _payingOnly = false);
    for (final (min, max) in _fields.values) {
      min.clear();
      max.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String? validate(Indicator indicator, String? text) {
      final value = text?.trim() ?? '';
      return value.isEmpty || indicator.parse(value) != null
          ? null
          : l10n.validationInvalid;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              l10n.exploreFilters,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SwitchListTile(
              key: const Key('explore_paying'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.explorePayingOnly),
              subtitle: Text(l10n.explorePayingOnlyHint),
              value: _payingOnly,
              onChanged: (value) => setState(() => _payingOnly = value),
            ),
            for (final MapEntry(key: indicator, value: (min, max))
                in _fields.entries)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(indicator.label(l10n)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: Key('explore_${indicator.name}_min'),
                            controller: min,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.exploreMin,
                              isDense: true,
                            ),
                            validator: (text) => validate(indicator, text),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            key: Key('explore_${indicator.name}_max'),
                            controller: max,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.exploreMax,
                              isDense: true,
                            ),
                            validator: (text) => validate(indicator, text),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: _clear, child: Text(l10n.exploreClear)),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('explore_apply'),
                  onPressed: _apply,
                  child: Text(l10n.exploreApply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
