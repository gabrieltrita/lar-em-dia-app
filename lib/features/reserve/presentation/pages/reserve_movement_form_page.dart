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
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/features/reserve/presentation/cubits/reserve_cubits.dart';
import 'package:lar_em_dia/features/reserve/presentation/widgets/reserve_labels.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class ReserveMovementFormArgs {
  const new({required this.accounts, this.accountId, this.existing});

  final List<ReserveAccount> accounts;
  final String? accountId;
  final ReserveMovement? existing;
}

class ReserveMovementFormPage extends StatefulWidget {
  const new({required this.args, this.today, super.key});

  final ReserveMovementFormArgs args;
  final DateTime? today;

  @override
  State<ReserveMovementFormPage> createState() =>
      _ReserveMovementFormPageState();
}

class _ReserveMovementFormPageState extends State<ReserveMovementFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final DateTime _today = Dates.dateOnly(widget.today ?? DateTime.now());
  late final ReserveMovement? _existing = widget.args.existing;
  late String? _accountId =
      _existing?.accountId ??
      widget.args.accountId ??
      widget.args.accounts.firstOrNull?.id;
  late ReserveMovementKind _kind =
      _existing?.kind ?? ReserveMovementKind.deposit;
  late DateTime _movedOn = _existing?.movedOn ?? _today;
  late final _amount = TextEditingController(
    text: switch (_existing?.amountCents) {
      final cents? => Money.formatAmount(cents),
      null => '',
    },
  );
  late bool _debitBalance = _existing?.changesBalance ?? true;

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
      context.read<ReserveMovementFormCubit>().save(
        ReserveMovementDraft(
          accountId: _accountId!,
          kind: _kind,
          movedOn: _movedOn,
          amountCents: Money.parse(_amount.text)!,
          debitBalance: _kind.changesBalance && _debitBalance,
        ),
        existing: _existing,
      ),
    );
  }

  List<String> _failureMessages(AppLocalizations l10n, ApiError error) => [
    error.localized(l10n),
    for (final (field, label) in [
      ('account_id', l10n.reserveMovementAccount),
      ('kind', l10n.reserveMovementKind),
      ('moved_on', l10n.dateLabel),
      ('amount_cents', l10n.reserveMovementAmount),
    ])
      if (error.localizedField(l10n, field) case final message?)
        '$label: $message',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<ReserveMovementFormCubit, Submission<ReserveMovement>>(
      listener: (context, state) {
        if (state is SubmissionSuccess) {
          context.pop(true);
        }
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(
            _existing == null
                ? l10n.reserveMovementNewTitle
                : l10n.reserveMovementEditTitle,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: const Key('reserve_movement_account'),
                  initialValue: _accountId,
                  decoration: InputDecoration(
                    labelText: l10n.reserveMovementAccount,
                  ),
                  items: [
                    for (final account in widget.args.accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                  ],
                  onChanged: _existing == null
                      ? (id) => setState(() => _accountId = id)
                      : null,
                  validator: (id) =>
                      id == null ? l10n.reserveMovementAccountRequired : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ReserveMovementKind>(
                  key: const Key('reserve_movement_kind'),
                  initialValue: _kind,
                  decoration: InputDecoration(
                    labelText: l10n.reserveMovementKind,
                  ),
                  items: [
                    for (final kind in ReserveMovementKind.values)
                      DropdownMenuItem(
                        value: kind,
                        child: Text(kind.label(l10n)),
                      ),
                  ],
                  onChanged: (kind) => setState(() => _kind = kind!),
                ),
                if (_kind == ReserveMovementKind.anchor) ...[
                  const SizedBox(height: 8),
                  InfoMessage(l10n.reserveMovementAnchorHint),
                ],
                const SizedBox(height: 16),
                DateField(
                  key: const Key('reserve_movement_moved_on'),
                  label: l10n.dateLabel,
                  value: _movedOn,
                  firstDate: DateTime(2000),
                  lastDate: _today,
                  onChanged: (value) => setState(() => _movedOn = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('reserve_movement_amount'),
                  controller: _amount,
                  decoration: InputDecoration(
                    labelText: l10n.reserveMovementAmount,
                    prefixText: r'R$ ',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  validator: validateWith(
                    l10n,
                    _kind == ReserveMovementKind.anchor
                        ? Validators.amount
                        : Validators.positiveAmount,
                  ),
                ),
                if (_kind.changesBalance) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const Key('reserve_movement_debit_balance'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _kind == ReserveMovementKind.deposit
                          ? l10n.reserveMovementDebitBalance
                          : l10n.reserveMovementCreditBalance,
                    ),
                    value: _debitBalance,
                    onChanged: (value) => setState(() => _debitBalance = value),
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
