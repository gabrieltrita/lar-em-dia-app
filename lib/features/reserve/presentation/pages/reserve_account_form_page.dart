import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/money_input_formatter.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/reserve/presentation/cubits/reserve_cubits.dart';
import 'package:lar_em_dia/features/reserve/presentation/widgets/reserve_labels.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class ReserveAccountFormPage extends StatefulWidget {
  const new({this.existing, this.today, super.key});

  final ReserveAccount? existing;
  final DateTime? today;

  @override
  State<ReserveAccountFormPage> createState() => _ReserveAccountFormPageState();
}

class _ReserveAccountFormPageState extends State<ReserveAccountFormPage> {
  static final _percent = RegExp(r'^\d{1,3}([.,]\d{1,2})?$');

  final _formKey = GlobalKey<FormState>();
  late final ReserveAccount? _existing = widget.existing;
  late final _name = TextEditingController(text: _existing?.name ?? '');
  late ReserveKind _kind = _existing?.kind ?? ReserveKind.selicTreasury;
  late final _cdiPercent = TextEditingController(
    text: _percentText(_existing?.cdiPercentBps) ?? '100',
  );
  late final _annualRate = TextEditingController(
    text: _percentText(_existing?.annualRateBps) ?? '',
  );
  late bool _taxExempt = _existing?.taxExempt ?? false;
  final _anchor = TextEditingController();

  static String? _percentText(int? bps) => switch (bps) {
    null => null,
    final value when value % 100 == 0 => '${value ~/ 100}',
    final value =>
      '${value ~/ 100},${(value % 100).toString().padLeft(2, '0')}',
  };

  static int? _parseBps(String text) {
    final value = text.trim();
    if (!_percent.hasMatch(value)) {
      return null;
    }
    final [whole, ...fraction] = value.replaceAll('.', ',').split(',');
    final cents = fraction.isEmpty
        ? 0
        : int.parse(fraction.first.padRight(2, '0'));
    final bps = int.parse(whole) * 100 + cents;
    return bps > 0 ? bps : null;
  }

  @override
  void dispose() {
    for (final controller in [_name, _cdiPercent, _annualRate, _anchor]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    unawaited(
      context.read<ReserveAccountFormCubit>().save(
        ReserveAccountDraft(
          name: _name.text.trim(),
          kind: _kind,
          cdiPercentBps: _kind.usesCdiPercent
              ? _parseBps(_cdiPercent.text)
              : null,
          annualRateBps: _kind.usesAnnualRate
              ? _parseBps(_annualRate.text)
              : null,
          taxExempt: _kind.canBeExempt && _taxExempt,
        ),
        accountId: _existing?.id,
        anchorCents: _existing == null && _anchor.text.trim().isNotEmpty
            ? Money.parse(_anchor.text)
            : null,
        today: widget.today,
      ),
    );
  }

  List<String> _failureMessages(AppLocalizations l10n, ApiError error) => [
    error.localized(l10n),
    for (final (field, label) in [
      ('name', l10n.reserveAccountName),
      ('cdi_percent_bps', l10n.reserveAccountCdiPercent),
      ('annual_rate_bps', l10n.reserveAccountAnnualRate),
      ('amount_cents', l10n.reserveAccountAnchor),
    ])
      if (error.localizedField(l10n, field) case final message?)
        '$label: $message',
  ];

  Widget _rateField(
    AppLocalizations l10n,
    String key,
    TextEditingController controller,
    String label,
  ) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: TextFormField(
      key: Key(key),
      controller: controller,
      decoration: InputDecoration(labelText: label, suffixText: '%'),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9.,]'))],
      validator: (value) => _parseBps(value ?? '') == null
          ? l10n.reserveAccountRateInvalid
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<ReserveAccountFormCubit, Submission<ReserveAccount>>(
      listener: (context, state) {
        if (state is SubmissionSuccess) {
          context.pop(true);
        }
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(
            _existing == null
                ? l10n.reserveAccountNewTitle
                : l10n.reserveAccountEditTitle,
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
                  key: const Key('reserve_account_name'),
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: l10n.reserveAccountName,
                    helperText: l10n.reserveAccountNameHelper,
                  ),
                  maxLength: 100,
                  validator: validateWith(l10n, Validators.required),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ReserveKind>(
                  key: const Key('reserve_account_kind'),
                  initialValue: _kind,
                  decoration: InputDecoration(
                    labelText: l10n.reserveAccountKind,
                  ),
                  items: [
                    for (final kind in ReserveKind.values)
                      DropdownMenuItem(
                        value: kind,
                        child: Text(kind.label(l10n)),
                      ),
                  ],
                  onChanged: (kind) => setState(() => _kind = kind!),
                ),
                if (_kind.usesCdiPercent)
                  _rateField(
                    l10n,
                    'reserve_account_cdi',
                    _cdiPercent,
                    l10n.reserveAccountCdiPercent,
                  ),
                if (_kind.usesAnnualRate)
                  _rateField(
                    l10n,
                    'reserve_account_rate',
                    _annualRate,
                    l10n.reserveAccountAnnualRate,
                  ),
                if (_kind.canBeExempt)
                  SwitchListTile(
                    key: const Key('reserve_account_exempt'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.reserveAccountExempt),
                    value: _taxExempt,
                    onChanged: (value) => setState(() => _taxExempt = value),
                  ),
                if (_existing == null) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('reserve_account_anchor'),
                    controller: _anchor,
                    decoration: InputDecoration(
                      labelText: l10n.reserveAccountAnchor,
                      helperText: l10n.reserveAccountAnchorHelper,
                      prefixText: r'R$ ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyInputFormatter()],
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? null
                        : validateWith(l10n, Validators.amount)(value),
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
