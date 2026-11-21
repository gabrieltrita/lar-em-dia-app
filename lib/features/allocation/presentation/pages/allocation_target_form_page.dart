import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/capitalize_first_formatter.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/money_input_formatter.dart';
import 'package:lar_em_dia/core/money/rates.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/allocation/domain/allocation.dart';
import 'package:lar_em_dia/features/allocation/presentation/cubits/allocation_cubits.dart';
import 'package:lar_em_dia/features/allocation/presentation/widgets/allocation_labels.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_label.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class AllocationTargetFormPage extends StatefulWidget {
  const new({required this.args, super.key});

  final AllocationTargetFormArgs args;

  @override
  State<AllocationTargetFormPage> createState() =>
      _AllocationTargetFormPageState();
}

class _AllocationTargetFormPageState extends State<AllocationTargetFormPage> {
  static const _maxPercentBps = 10000;
  static const _hiddenCategoryKey = 'surplus_allocation';

  final _formKey = GlobalKey<FormState>();
  late final AllocationTarget? _existing = widget.args.existing;
  late final _name = TextEditingController(text: _existing?.name ?? '');
  late AllocationMode _mode =
      _existing?.mode ??
      (widget.args.remainderTaken
          ? AllocationMode.percent
          : AllocationMode.remainder);
  late final _amount = TextEditingController(
    text: switch (_existing?.amountCents) {
      final cents? => Money.formatAmount(cents),
      null => '',
    },
  );
  late final _percent = TextEditingController(
    text: switch (_existing?.percentBps) {
      final bps? => Rates.hundredths(bps),
      null => '',
    },
  );
  late String? _accountId =
      widget.args.accounts.any(
        (account) => account.id == _existing?.reserveAccountId,
      )
      ? _existing?.reserveAccountId
      : null;
  late final List<Category> _categories = [
    for (final category in widget.args.categories)
      if (category.key != _hiddenCategoryKey) category,
  ];
  late String? _categoryId =
      _categories.any((category) => category.id == _existing?.categoryId)
      ? _existing?.categoryId
      : null;

  static int? _parsePercent(String text) =>
      switch (Rates.parseHundredths(text)) {
        final bps? when bps > 0 && bps <= _maxPercentBps => bps,
        _ => null,
      };

  @override
  void dispose() {
    for (final controller in [_name, _amount, _percent]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    unawaited(
      context.read<AllocationTargetFormCubit>().save(
        AllocationTargetDraft(
          name: _name.text.trim(),
          mode: _mode,
          amountCents: _mode == AllocationMode.fixed
              ? Money.parse(_amount.text)
              : null,
          percentBps: _mode == AllocationMode.percent
              ? _parsePercent(_percent.text)
              : null,
          reserveAccountId: _accountId,
          categoryId: _categoryId,
        ),
        id: _existing?.id,
      ),
    );
  }

  List<String> _failureMessages(AppLocalizations l10n, ApiError error) => [
    error.localized(l10n),
    for (final (field, label) in [
      ('name', l10n.allocationName),
      ('mode', l10n.allocationMode),
      ('amount_cents', l10n.allocationAmount),
      ('percent_bps', l10n.allocationPercent),
      ('reserve_account_id', l10n.allocationReserveAccount),
      ('category_id', l10n.allocationCategory),
    ])
      if (error.localizedField(l10n, field) case final message?)
        '$label: $message',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accounts = widget.args.accounts;
    return BlocConsumer<
      AllocationTargetFormCubit,
      Submission<AllocationTarget>
    >(
      listener: (context, state) {
        if (state is SubmissionSuccess) {
          context.pop(true);
        }
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(
            _existing == null
                ? l10n.allocationNewTitle
                : l10n.allocationEditTitle,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('allocation_name'),
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: l10n.allocationName,
                    helperText: l10n.allocationNameHelper,
                  ),
                  maxLength: 100,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [CapitalizeFirstFormatter()],
                  validator: validateWith(l10n, Validators.required),
                ),
                if (_categories.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    key: const Key('allocation_category'),
                    initialValue: _categoryId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.allocationCategory,
                    ),
                    items: [
                      DropdownMenuItem(
                        child: Text(l10n.allocationCategoryNone),
                      ),
                      for (final category in _categories)
                        DropdownMenuItem(
                          value: category.id,
                          child: Text(categoryLabel(l10n, category)),
                        ),
                    ],
                    onChanged: (id) => setState(() => _categoryId = id),
                  ),
                ],
                const SizedBox(height: 16),
                Text(l10n.allocationMode),
                const SizedBox(height: 8),
                SegmentedButton<AllocationMode>(
                  key: const Key('allocation_mode'),
                  showSelectedIcon: false,
                  segments: [
                    for (final mode in AllocationMode.values)
                      ButtonSegment(
                        value: mode,
                        label: Text(mode.label(l10n)),
                        enabled:
                            mode != AllocationMode.remainder ||
                            !widget.args.remainderTaken,
                      ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (selection) =>
                      setState(() => _mode = selection.single),
                ),
                const SizedBox(height: 16),
                switch (_mode) {
                  AllocationMode.fixed => TextFormField(
                    key: const Key('allocation_amount'),
                    controller: _amount,
                    decoration: InputDecoration(
                      labelText: l10n.allocationAmount,
                      prefixText: r'R$ ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyInputFormatter()],
                    validator: validateWith(l10n, Validators.amount),
                  ),
                  AllocationMode.percent => TextFormField(
                    key: const Key('allocation_percent'),
                    controller: _percent,
                    decoration: InputDecoration(
                      labelText: l10n.allocationPercent,
                      suffixText: '%',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[0-9.,]')),
                    ],
                    validator: (value) => _parsePercent(value ?? '') == null
                        ? l10n.allocationPercentInvalid
                        : null,
                  ),
                  AllocationMode.remainder => Text(
                    widget.args.remainderTaken
                        ? l10n.allocationRemainderTaken
                        : l10n.allocationRemainderHelper,
                  ),
                },
                if (accounts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    key: const Key('allocation_reserve'),
                    initialValue: _accountId,
                    decoration: InputDecoration(
                      labelText: l10n.allocationReserveAccount,
                      helperText: l10n.allocationReserveHelper,
                      helperMaxLines: 2,
                    ),
                    items: [
                      DropdownMenuItem(child: Text(l10n.allocationReserveNone)),
                      for (final account in accounts)
                        DropdownMenuItem(
                          value: account.id,
                          child: Text(account.name),
                        ),
                    ],
                    onChanged: (id) => setState(() => _accountId = id),
                  ),
                ],
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
}
