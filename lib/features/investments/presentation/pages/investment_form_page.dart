import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/money_input_formatter.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/widgets/date_field.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/investments/domain/asset.dart';
import 'package:lar_em_dia/features/investments/domain/investment_transaction.dart';
import 'package:lar_em_dia/features/investments/domain/split_ratio.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/asset_search_field.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/investment_labels.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class InvestmentFormArgs {
  const new({
    this.existing,
    this.asset,
    this.held = const {},
    this.existingHoldings = false,
  });

  final InvestmentTransaction? existing;
  final Asset? asset;
  final Map<String, int> held;
  final bool existingHoldings;
}

class InvestmentFormPage extends StatefulWidget {
  const new({required this.args, this.today, super.key});

  final InvestmentFormArgs args;
  final DateTime? today;

  @override
  State<InvestmentFormPage> createState() => _InvestmentFormPageState();
}

class _InvestmentFormPageState extends State<InvestmentFormPage> {
  static const maxQuantity = 1000000000;
  static const Set<InvestmentKind> _ratioKinds = {
    InvestmentKind.split,
    InvestmentKind.reverseSplit,
  };

  final _formKey = GlobalKey<FormState>();
  late final DateTime _today = Dates.dateOnly(widget.today ?? DateTime.now());
  late final InvestmentTransaction? _existing = widget.args.existing;
  late Asset? _asset = widget.args.asset;
  late InvestmentKind _kind = _existing?.kind ?? InvestmentKind.buy;
  late DateTime _tradedOn = _existing?.tradedOn ?? _today;
  late final _quantity = TextEditingController(
    text: _existing?.quantity.toString() ?? '',
  );
  late final _price = TextEditingController(
    text: switch (_existing?.priceCents) {
      final cents? => Money.formatAmount(cents),
      null => '',
    },
  );
  late final _fees = TextEditingController(
    text: Money.formatAmount(_existing?.feesCents ?? 0),
  );
  final _ratioFrom = TextEditingController(text: '1');
  final _ratioTo = TextEditingController(text: '2');
  late bool _debitBalance =
      _existing?.changesBalance ?? !widget.args.existingHoldings;
  InvestmentGoal? _goal;
  bool _attempted = false;

  String? get _ticker => _existing?.ticker ?? _asset?.ticker;

  int get _held => widget.args.held[_ticker] ?? 0;

  bool get _usesRatio => _existing == null && _ratioKinds.contains(_kind);

  bool get _asksGoal =>
      _existing == null &&
      _kind == InvestmentKind.buy &&
      _asset != null &&
      !widget.args.held.containsKey(_asset!.ticker);

  SplitRatio get _ratio => SplitRatio(
    from: int.tryParse(_ratioFrom.text) ?? 0,
    to: int.tryParse(_ratioTo.text) ?? 0,
  );

  @override
  void dispose() {
    for (final controller in [_quantity, _price, _fees, _ratioFrom, _ratioTo]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectKind(InvestmentKind kind) => setState(() {
    _kind = kind;
    if (kind == InvestmentKind.reverseSplit) {
      _ratioFrom.text = '10';
      _ratioTo.text = '1';
    } else if (kind == InvestmentKind.split) {
      _ratioFrom.text = '1';
      _ratioTo.text = '2';
    }
  });

  int? _parseQuantity(String? text) {
    final value = int.tryParse(text?.trim() ?? '');
    return value != null && value > 0 && value <= maxQuantity ? value : null;
  }

  int _draftQuantity() =>
      _usesRatio ? _ratio.change(_held) : _parseQuantity(_quantity.text)!;

  void _submit() {
    final valid = _formKey.currentState!.validate();
    if (_ticker == null || !valid) {
      setState(() => _attempted = true);
      return;
    }
    final kind = _usesRatio ? _ratio.kind : _kind;
    final trade = kind.isTrade;
    unawaited(
      context.read<InvestmentFormCubit>().save(
        InvestmentDraft(
          ticker: _ticker!,
          kind: kind,
          tradedOn: _tradedOn,
          quantity: _draftQuantity(),
          priceCents: trade ? Money.parse(_price.text) : null,
          feesCents: trade ? Money.parse(_fees.text) ?? 0 : 0,
          goal: _asksGoal ? _goal ?? _asset!.type.defaultGoal : null,
          debitBalance: trade && _debitBalance,
        ),
        existing: _existing,
      ),
    );
  }

  List<String> _failureMessages(AppLocalizations l10n, ApiError error) => [
    error.localized(l10n),
    for (final (field, label) in [
      ('ticker', l10n.investmentFormAsset),
      ('quantity', l10n.investmentFormQuantity),
      ('price_cents', l10n.investmentFormPrice),
      ('fees_cents', l10n.investmentFormFees),
      ('traded_on', l10n.dateLabel),
    ])
      if (error.localizedField(l10n, field) case final message?)
        '$label: $message',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<InvestmentFormCubit, Submission<InvestmentTransaction>>(
      listener: (context, state) {
        if (state is SubmissionSuccess) {
          context.pop(true);
        }
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(
            _existing == null
                ? l10n.investmentFormNewTitle
                : l10n.investmentFormEditTitle,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.args.existingHoldings) ...[
                  InfoMessage(l10n.investmentFormExistingHint),
                  const SizedBox(height: 16),
                ],
                ..._assetSection(l10n),
                const SizedBox(height: 16),
                DropdownButtonFormField<InvestmentKind>(
                  key: const Key('investment_kind'),
                  initialValue: _kind,
                  decoration: InputDecoration(
                    labelText: l10n.investmentFormKind,
                  ),
                  items: [
                    for (final kind in InvestmentKind.values)
                      DropdownMenuItem(
                        value: kind,
                        child: Text(kind.label(l10n)),
                      ),
                  ],
                  onChanged: _existing == null
                      ? (kind) => _selectKind(kind!)
                      : null,
                ),
                const SizedBox(height: 16),
                DateField(
                  key: const Key('investment_traded_on'),
                  label: l10n.dateLabel,
                  value: _tradedOn,
                  firstDate: DateTime(2000),
                  lastDate: _today,
                  onChanged: (value) => setState(() => _tradedOn = value),
                ),
                const SizedBox(height: 16),
                if (_usesRatio)
                  ..._ratioSection(l10n)
                else
                  ..._quantitySection(l10n),
                if (_kind.isTrade) ..._tradeSection(l10n),
                if (_asksGoal) ..._goalSection(l10n),
                if (state case SubmissionFailure(:final error)) ...[
                  const SizedBox(height: 16),
                  ErrorBanner(_failureMessages(l10n, error)),
                ],
                const SizedBox(height: 24),
                SubmitButton(
                  label: l10n.save,
                  busy: state is SubmissionInProgress,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _assetSection(AppLocalizations l10n) {
    if (_existing case final existing?) {
      return [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(existing.ticker),
          subtitle: Text(l10n.investmentFormAsset),
        ),
      ];
    }
    if (_asset case final asset?) {
      return [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(asset.ticker),
          subtitle: Text(asset.name),
          trailing: widget.args.asset == null
              ? IconButton(
                  tooltip: l10n.investmentFormChangeAsset,
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _asset = null;
                    _goal = null;
                  }),
                )
              : null,
        ),
      ];
    }
    return [
      AssetSearchField(
        errorText: _attempted ? l10n.investmentFormAssetRequired : null,
        onSelected: (asset) => setState(() => _asset = asset),
      ),
    ];
  }

  List<Widget> _quantitySection(AppLocalizations l10n) => [
    TextFormField(
      key: const Key('investment_quantity'),
      controller: _quantity,
      decoration: InputDecoration(
        labelText: _kind == InvestmentKind.bonus
            ? l10n.investmentFormBonusQuantity
            : l10n.investmentFormQuantity,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (_) => setState(() {}),
      validator: (value) => _parseQuantity(value) == null
          ? l10n.investmentFormQuantityInvalid
          : null,
    ),
    const SizedBox(height: 16),
  ];

  List<Widget> _ratioSection(AppLocalizations l10n) {
    final ratio = _ratio;
    return [
      Row(
        children: [
          for (final (key, controller, label, validated) in [
            (
              'investment_ratio_from',
              _ratioFrom,
              l10n.investmentFormRatioFrom,
              false,
            ),
            ('investment_ratio_to', _ratioTo, l10n.investmentFormRatioTo, true),
          ])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextFormField(
                  key: Key(key),
                  controller: controller,
                  decoration: InputDecoration(labelText: label),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  validator: (_) => validated ? _ratioError(l10n) : null,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (ratio.isValid && _held > 0 && ratio.change(_held) > 0)
        InfoMessage(
          l10n.investmentFormRatioSummary(_held, ratio.sharesAfter(_held)),
        ),
      const SizedBox(height: 16),
    ];
  }

  String? _ratioError(AppLocalizations l10n) {
    final ratio = _ratio;
    if (_held == 0) {
      return l10n.investmentFormRatioNoShares;
    }
    final expected = _kind == InvestmentKind.split
        ? ratio.to > ratio.from
        : ratio.to < ratio.from;
    if (!ratio.isValid || !expected || ratio.change(_held) == 0) {
      return l10n.investmentFormRatioInvalid;
    }
    return null;
  }

  List<Widget> _tradeSection(AppLocalizations l10n) {
    final quantity = _parseQuantity(_quantity.text);
    final amount = tradeAmountCents(
      kind: _kind,
      quantity: quantity ?? 0,
      priceCents: Money.parse(_price.text),
      feesCents: Money.parse(_fees.text) ?? 0,
    );
    return [
      TextFormField(
        key: const Key('investment_price'),
        controller: _price,
        decoration: InputDecoration(
          labelText: l10n.investmentFormPrice,
          prefixText: r'R$ ',
          helperText: widget.args.existingHoldings
              ? l10n.investmentFormAveragePriceHelper
              : null,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [MoneyInputFormatter()],
        onChanged: (_) => setState(() {}),
        validator: validateWith(l10n, Validators.positiveAmount),
      ),
      const SizedBox(height: 16),
      TextFormField(
        key: const Key('investment_fees'),
        controller: _fees,
        decoration: InputDecoration(
          labelText: l10n.investmentFormFees,
          prefixText: r'R$ ',
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [MoneyInputFormatter()],
        onChanged: (_) => setState(() {}),
        validator: validateWith(l10n, Validators.amount),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        key: const Key('investment_debit_balance'),
        contentPadding: EdgeInsets.zero,
        title: Text(
          _kind == InvestmentKind.buy
              ? l10n.investmentFormDebitBalance
              : l10n.investmentFormCreditBalance,
        ),
        subtitle: amount == null || quantity == null
            ? null
            : Text(
                _kind == InvestmentKind.buy
                    ? l10n.investmentFormDebitAmount(Money.format(amount))
                    : l10n.investmentFormCreditAmount(Money.format(amount)),
              ),
        value: _debitBalance,
        onChanged: (value) => setState(() => _debitBalance = value),
      ),
    ];
  }

  List<Widget> _goalSection(AppLocalizations l10n) => [
    const SizedBox(height: 8),
    Text(l10n.investmentFormGoal),
    const SizedBox(height: 8),
    SegmentedButton<InvestmentGoal>(
      key: const Key('investment_goal'),
      segments: [
        for (final goal in InvestmentGoal.values)
          ButtonSegment(value: goal, label: Text(goal.label(l10n))),
      ],
      selected: {_goal ?? _asset!.type.defaultGoal},
      onSelectionChanged: (selection) =>
          setState(() => _goal = selection.first),
    ),
  ];
}
