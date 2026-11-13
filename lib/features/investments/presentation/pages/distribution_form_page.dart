import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/money/per_share.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/widgets/date_field.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/investments/domain/distribution.dart';
import 'package:lar_em_dia/features/investments/presentation/cubits/investment_cubits.dart';
import 'package:lar_em_dia/features/investments/presentation/widgets/investment_labels.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class DistributionFormArgs {
  const new({required this.ticker, this.existing});

  final String ticker;
  final AssetDistribution? existing;
}

class DistributionFormPage extends StatefulWidget {
  const new({required this.args, this.today, super.key});

  final DistributionFormArgs args;
  final DateTime? today;

  @override
  State<DistributionFormPage> createState() => _DistributionFormPageState();
}

class _DistributionFormPageState extends State<DistributionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final DateTime _today = Dates.dateOnly(widget.today ?? DateTime.now());
  late final AssetDistribution? _existing = widget.args.existing;
  late DistributionKind _kind = _existing?.kind ?? DistributionKind.dividend;
  late DateTime _recordOn = _existing?.recordOn ?? _today;
  late DateTime _paidOn = _existing?.paidOn ?? _today;
  late final _amount = TextEditingController(
    text: switch (_existing) {
      final existing? => PerShare.inputE8(existing.amountPerShareE8),
      null => '',
    },
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final valid = _formKey.currentState!.validate();
    if (!valid || _paidOn.isBefore(_recordOn)) {
      return;
    }
    unawaited(
      context.read<DistributionFormCubit>().save(
        DistributionDraft(
          ticker: widget.args.ticker,
          kind: _kind,
          recordOn: _recordOn,
          paidOn: _paidOn,
          amountPerShareE8: PerShare.parseE8(_amount.text)!,
        ),
        existing: _existing,
      ),
    );
  }

  List<String> _failureMessages(AppLocalizations l10n, ApiError error) => [
    error.localized(l10n),
    for (final (field, label) in [
      ('ticker', l10n.investmentFormAsset),
      ('amount_per_share_e8', l10n.distributionFormAmount),
      ('paid_on', l10n.distributionFormPaidOn),
    ])
      if (error.localizedField(l10n, field) case final message?)
        '$label: $message',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<DistributionFormCubit, Submission<AssetDistribution>>(
      listener: (context, state) {
        if (state is SubmissionSuccess) {
          context.pop(true);
        }
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(
            _existing == null
                ? l10n.distributionFormNewTitle
                : l10n.distributionFormEditTitle,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(widget.args.ticker),
                  subtitle: Text(l10n.investmentFormAsset),
                ),
                InfoMessage(l10n.distributionFormHint),
                const SizedBox(height: 16),
                DropdownButtonFormField<DistributionKind>(
                  key: const Key('distribution_kind'),
                  initialValue: _kind,
                  decoration: InputDecoration(
                    labelText: l10n.investmentFormKind,
                  ),
                  items: [
                    for (final kind in DistributionKind.manual)
                      DropdownMenuItem(
                        value: kind,
                        child: Text(kind.label(l10n)),
                      ),
                  ],
                  onChanged: (kind) => setState(() => _kind = kind!),
                ),
                const SizedBox(height: 16),
                DateField(
                  key: const Key('distribution_record_on'),
                  label: l10n.distributionFormRecordOn,
                  value: _recordOn,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(_today.year + 1, 12, 31),
                  onChanged: (value) => setState(() => _recordOn = value),
                ),
                const SizedBox(height: 16),
                DateField(
                  key: const Key('distribution_paid_on'),
                  label: l10n.distributionFormPaidOn,
                  value: _paidOn,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(_today.year + 1, 12, 31),
                  onChanged: (value) => setState(() => _paidOn = value),
                ),
                if (_paidOn.isBefore(_recordOn)) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.validationBeforeRecordOn,
                    key: const Key('distribution_dates_error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('distribution_amount'),
                  controller: _amount,
                  decoration: InputDecoration(
                    labelText: l10n.distributionFormAmount,
                    prefixText: r'R$ ',
                    helperText: _kind == DistributionKind.jcp
                        ? l10n.distributionFormJcpHelper
                        : null,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) => PerShare.parseE8(value ?? '') == null
                      ? l10n.distributionFormAmountInvalid
                      : null,
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
