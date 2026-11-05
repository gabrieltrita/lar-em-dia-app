import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:lar_em_dia/features/balance/domain/balance.dart';
import 'package:lar_em_dia/features/balance/presentation/cubits/balance_cubits.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class BalanceFormPage extends StatefulWidget {
  const new({this.existing, this.today, super.key});

  final Balance? existing;
  final DateTime? today;

  @override
  State<BalanceFormPage> createState() => _BalanceFormPageState();
}

class _BalanceFormPageState extends State<BalanceFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final DateTime _today = Dates.dateOnly(widget.today ?? DateTime.now());
  late final _amount = TextEditingController(
    text: switch (widget.existing) {
      final balance? => Money.formatAmount(balance.amountCents),
      null => '',
    },
  );
  late DateTime _asOf = widget.existing?.asOf ?? _today;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    unawaited(
      context.read<BalanceFormCubit>().save(
        existing: widget.existing,
        amountCents: Money.parse(_amount.text)!,
        asOf: _asOf,
      ),
    );
  }

  List<String> _failureMessages(AppLocalizations l10n, ApiError error) => [
    error.localized(l10n),
    if (error.localizedField(l10n, 'amount_cents') case final message?)
      '${l10n.amountLabel}: $message',
    if (error.details['as_of']?.firstOrNull?.code == 'taken')
      '${l10n.dateLabel}: ${l10n.validationDateTaken}'
    else if (error.localizedField(l10n, 'as_of') case final message?)
      '${l10n.dateLabel}: $message',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<BalanceFormCubit, Submission<Balance>>(
      listener: (context, state) {
        if (state is SubmissionSuccess) {
          context.pop(true);
        }
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existing == null
                ? l10n.balanceFormNewTitle
                : l10n.balanceFormEditTitle,
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
                  key: const Key('balance_amount'),
                  controller: _amount,
                  decoration: InputDecoration(
                    labelText: l10n.amountLabel,
                    prefixText: r'R$ ',
                    helperText: l10n.balanceAmountHelper,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  inputFormatters: [MoneyInputFormatter(allowNegative: true)],
                  validator: validateWith(l10n, Validators.amount),
                ),
                const SizedBox(height: 16),
                DateField(
                  key: const Key('balance_as_of'),
                  label: l10n.dateLabel,
                  value: _asOf,
                  firstDate: DateTime(2000),
                  lastDate: _today,
                  onChanged: (value) => setState(() => _asOf = value),
                ),
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
