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
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/date_field.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/cubits/entry_cubits.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_label.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/nature_label.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class EntryFormPage extends StatefulWidget {
  const new({required this.kind, this.existing, this.today, super.key});

  final EntryKind kind;
  final Entry? existing;
  final DateTime? today;

  @override
  State<EntryFormPage> createState() => _EntryFormPageState();
}

class _EntryFormPageState extends State<EntryFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _description = TextEditingController(
    text: widget.existing?.description,
  );
  late final _amount = TextEditingController(
    text: switch (widget.existing) {
      final entry? => Money.formatAmount(entry.amountCents),
      null => '',
    },
  );
  late String? _categoryId = widget.existing?.categoryId;
  late EntryNature? _nature = widget.existing?.nature;
  late DateTime _dueOn =
      widget.existing?.dueOn ?? Dates.dateOnly(widget.today ?? DateTime.now());
  late bool _settled = widget.existing?.isPaid ?? false;

  bool get _isExpense => widget.kind == EntryKind.expense;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    unawaited(
      context.read<EntryFormCubit>().save(
        EntryDraft(
          categoryId: _categoryId!,
          description: _description.text.trim(),
          amountCents: Money.parse(_amount.text)!,
          dueOn: _dueOn,
          status: _settled ? EntryStatus.paid : EntryStatus.pending,
          nature: _isExpense ? _nature : null,
        ),
        existing: widget.existing,
      ),
    );
  }

  List<String> _failureMessages(AppLocalizations l10n, ApiError error) {
    final labels = {
      'category': l10n.entryCategoryLabel(widget.kind.name),
      'nature': l10n.entryNatureLabel,
      'description': l10n.entryDescriptionLabel,
      'amount_cents': l10n.amountLabel,
      'due_on': l10n.entryDueOnLabel,
    };
    return [
      error.localized(l10n),
      for (final MapEntry(:key, :value) in labels.entries)
        if (error.localizedField(l10n, key) case final message?)
          '$value: $message',
    ];
  }

  Widget _categoryField(AppLocalizations l10n, List<Category> categories) {
    return DropdownButtonFormField<String>(
      key: const Key('entry_category'),
      initialValue: _categoryId,
      decoration: InputDecoration(
        labelText: l10n.entryCategoryLabel(widget.kind.name),
      ),
      items: [
        for (final category in categories)
          DropdownMenuItem(
            value: category.id,
            child: Text(categoryLabel(l10n, category)),
          ),
      ],
      onChanged: (value) => setState(() {
        _categoryId = value;
        _nature = categories
            .firstWhere((category) => category.id == value)
            .defaultNature;
      }),
      validator: (value) => Validators.required(value)?.localized(l10n),
    );
  }

  Widget _natureField(AppLocalizations l10n) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.entryNatureLabel,
        border: InputBorder.none,
      ),
      child: SegmentedButton<EntryNature>(
        key: const Key('entry_nature'),
        segments: [
          for (final nature in EntryNature.values)
            ButtonSegment(
              value: nature,
              label: Text(natureLabel(l10n, nature)),
            ),
        ],
        selected: {?_nature},
        emptySelectionAllowed: true,
        onSelectionChanged: (selection) =>
            setState(() => _nature = selection.firstOrNull ?? _nature),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = context.watch<CategoriesCubit>().state;
    return BlocConsumer<EntryFormCubit, Submission<Entry>>(
      listener: (context, state) {
        if (state is SubmissionSuccess) {
          context.pop(true);
        }
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existing == null
                ? l10n.entryFormNewTitle(widget.kind.name)
                : l10n.entryFormEditTitle(widget.kind.name),
          ),
        ),
        body: switch (categories) {
          Loading() => const Center(child: CircularProgressIndicator()),
          LoadFailure(:final error) => RetryMessage(
            message: error.localized(l10n),
            onRetry: () =>
                unawaited(context.read<CategoriesCubit>().load(widget.kind)),
          ),
          Loaded(value: final options) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _categoryField(l10n, options),
                  const SizedBox(height: 16),
                  if (_isExpense) ...[
                    _natureField(l10n),
                    const SizedBox(height: 8),
                  ],
                  TextFormField(
                    key: const Key('entry_description'),
                    controller: _description,
                    decoration: InputDecoration(
                      labelText: l10n.entryDescriptionLabel,
                    ),
                    maxLength: 200,
                    validator: validateWith(l10n, Validators.required),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const Key('entry_amount'),
                    controller: _amount,
                    decoration: InputDecoration(
                      labelText: l10n.amountLabel,
                      prefixText: r'R$ ',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [MoneyInputFormatter()],
                    validator: validateWith(l10n, Validators.positiveAmount),
                  ),
                  const SizedBox(height: 16),
                  DateField(
                    key: const Key('entry_due_on'),
                    label: l10n.entryDueOnLabel,
                    value: _dueOn,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    onChanged: (value) => setState(() => _dueOn = value),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const Key('entry_settled'),
                    title: Text(l10n.entrySettledLabel(widget.kind.name)),
                    value: _settled,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) => setState(() => _settled = value),
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
        },
      ),
    );
  }
}
