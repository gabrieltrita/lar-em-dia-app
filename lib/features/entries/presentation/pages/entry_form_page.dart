import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/dates/dates.dart';
import 'package:lar_em_dia/core/forms/capitalize_first_formatter.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/money_input_formatter.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/state/load_state.dart';
import 'package:lar_em_dia/core/widgets/date_field.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/balance/domain/balance.dart';
import 'package:lar_em_dia/features/balance/presentation/cubits/balance_cubits.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/cubits/entry_cubits.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_grid.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/nature_label.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class EntryFormPage extends StatefulWidget {
  const new({
    required this.kind,
    this.existing,
    this.scope = EntryScope.one,
    this.today,
    this.simulation = false,
    super.key,
  });

  final EntryKind kind;
  final Entry? existing;
  final EntryScope scope;
  final DateTime? today;
  final bool simulation;

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
  late EntryKind _kind = widget.kind;
  bool _repeat = false;
  int _repeatCount = Recurrence.defaultCount;
  RecurrenceDirection _repeatDirection = RecurrenceDirection.forward;
  RecurrenceInterval _repeatInterval = RecurrenceInterval.monthly;
  bool _installments = false;
  int _installmentsCount = Installments.defaultCount;

  bool get _isExpense => _kind == EntryKind.expense;

  bool get _isNew => widget.existing == null;

  bool get _scoped => widget.scope != EntryScope.one;

  Recurrence get _recurrence => Recurrence(
    count: _repeatCount,
    direction: _repeatDirection,
    interval: _repeatInterval,
  );

  bool get _amountLocked =>
      _scoped && (widget.existing?.isInstallment ?? false);

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final categoryId = _categoryId;
    if (!_formKey.currentState!.validate() || categoryId == null) {
      return;
    }
    final draft = EntryDraft(
      categoryId: categoryId,
      description: _description.text.trim(),
      amountCents: Money.parse(_amount.text)!,
      dueOn: _dueOn,
      status: _settled ? EntryStatus.paid : EntryStatus.pending,
      nature: _isExpense ? _nature : null,
    );
    final recurrence = _repeat ? _recurrence : null;
    final installments = _installments
        ? Installments(count: _installmentsCount)
        : null;
    if (widget.simulation) {
      context.pop(
        EntryPlan(
          kind: _kind,
          draft: draft,
          recurrence: recurrence,
          installments: installments,
        ),
      );
      return;
    }
    unawaited(
      context.read<EntryFormCubit>().save(
        draft,
        existing: widget.existing,
        scope: widget.scope,
        recurrence: recurrence,
        installments: installments,
      ),
    );
  }

  String _title(AppLocalizations l10n) => switch ((widget.simulation, _isNew)) {
    (true, _) => l10n.simulationEntryTitle(_kind.name),
    (false, true) => l10n.entryFormNewTitle(_kind.name),
    (false, false) => l10n.entryFormEditTitle(_kind.name),
  };

  void _switchKind(EntryKind kind) {
    setState(() {
      _kind = kind;
      _categoryId = null;
      _nature = null;
      _installments = false;
    });
    unawaited(context.read<CategoriesCubit>().load(kind));
  }

  Widget _kindField(AppLocalizations l10n) => SegmentedButton<EntryKind>(
    key: const Key('entry_kind'),
    showSelectedIcon: false,
    segments: [
      ButtonSegment(
        value: EntryKind.expense,
        label: Text(l10n.entryKindExpense),
      ),
      ButtonSegment(value: EntryKind.income, label: Text(l10n.entryKindIncome)),
    ],
    selected: {_kind},
    onSelectionChanged: (selection) => _switchKind(selection.single),
  );

  List<String> _failureMessages(AppLocalizations l10n, ApiError error) {
    final labels = {
      'category': l10n.entryCategoryLabel(_kind.name),
      'nature': l10n.entryNatureLabel,
      'description': l10n.entryDescriptionLabel,
      'amount_cents': l10n.amountLabel,
      'total_cents': l10n.entryTotalAmountLabel,
      'kind': l10n.entryInstallmentsLabel,
      'due_on': l10n.entryDueOnLabel,
      'entries_count': l10n.entryRepeatCountLabel,
      'interval_months': l10n.entryRepeatIntervalLabel,
      'direction': l10n.entryRepeatDirectionLabel,
    };
    return [
      error.localized(l10n),
      for (final MapEntry(:key, :value) in labels.entries)
        if (error.localizedField(l10n, key) case final message?)
          '$value: $message',
    ];
  }

  Widget _categoryField(AppLocalizations l10n, List<Category> categories) {
    return FormField<String>(
      key: const Key('entry_category'),
      initialValue: _categoryId,
      validator: (_) => Validators.required(_categoryId)?.localized(l10n),
      builder: (field) => InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.entryCategoryLabel(_kind.name),
          border: InputBorder.none,
          errorText: field.errorText,
        ),
        child: CategoryGrid(
          categories: categories,
          selected: _categoryId,
          onSelected: (category) {
            setState(() {
              _categoryId = category.id;
              _nature = category.defaultNature;
            });
            field.didChange(category.id);
          },
        ),
      ),
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

  List<Widget> _repeatFields(AppLocalizations l10n) {
    return [
      SwitchListTile(
        key: const Key('entry_repeat'),
        title: Text(l10n.entryRepeatLabel),
        value: _repeat,
        contentPadding: EdgeInsets.zero,
        onChanged: (value) => setState(() {
          _repeat = value;
          _installments = _installments && !value;
        }),
      ),
      if (_repeat) ...[
        const SizedBox(height: 8),
        DropdownButtonFormField<RecurrenceInterval>(
          key: const Key('entry_repeat_interval'),
          initialValue: _repeatInterval,
          decoration: InputDecoration(labelText: l10n.entryRepeatIntervalLabel),
          items: [
            for (final interval in RecurrenceInterval.values)
              DropdownMenuItem(
                value: interval,
                child: Text(l10n.entryRepeatInterval(interval.name)),
              ),
          ],
          onChanged: (value) => setState(() => _repeatInterval = value!),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: const Key('entry_repeat_count'),
          initialValue: _repeatCount,
          decoration: InputDecoration(labelText: l10n.entryRepeatCountLabel),
          items: [
            for (
              var count = Recurrence.minCount;
              count <= Recurrence.maxCount;
              count++
            )
              DropdownMenuItem(
                value: count,
                child: Text(l10n.entryRepeatTimes(count)),
              ),
          ],
          onChanged: (value) => setState(() => _repeatCount = value!),
        ),
        const SizedBox(height: 16),
        InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.entryRepeatDirectionLabel,
            border: InputBorder.none,
          ),
          child: SegmentedButton<RecurrenceDirection>(
            key: const Key('entry_repeat_direction'),
            segments: [
              ButtonSegment(
                value: RecurrenceDirection.forward,
                label: Text(l10n.entryRepeatForward),
              ),
              ButtonSegment(
                value: RecurrenceDirection.backward,
                label: Text(l10n.entryRepeatBackward),
              ),
            ],
            selected: {_repeatDirection},
            onSelectionChanged: (selection) =>
                setState(() => _repeatDirection = selection.single),
          ),
        ),
        _RecurrencePreview(dueDates: _recurrence.dueDates(_dueOn)),
      ],
    ];
  }

  List<Widget> _installmentsFields(AppLocalizations l10n) {
    return [
      SwitchListTile(
        key: const Key('entry_installments'),
        title: Text(l10n.entryInstallmentsLabel),
        value: _installments,
        contentPadding: EdgeInsets.zero,
        onChanged: (value) => setState(() {
          _installments = value;
          _repeat = _repeat && !value;
        }),
      ),
      if (_installments) ...[
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: const Key('entry_installments_count'),
          initialValue: _installmentsCount,
          decoration: InputDecoration(
            labelText: l10n.entryInstallmentsCountLabel,
          ),
          items: [
            for (
              var count = Installments.minCount;
              count <= Installments.maxCount;
              count++
            )
              DropdownMenuItem(
                value: count,
                child: Text(l10n.entryInstallmentsCount(count)),
              ),
          ],
          onChanged: (value) => setState(() => _installmentsCount = value!),
        ),
        ValueListenableBuilder(
          valueListenable: _amount,
          builder: (context, value, _) => _InstallmentsPreview(
            totalCents: Money.parse(value.text),
            installments: Installments(count: _installmentsCount),
          ),
        ),
      ],
    ];
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
        appBar: AppBar(title: Text(_title(l10n))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isNew) ...[_kindField(l10n), const SizedBox(height: 16)],
                if (_scoped) ...[
                  InfoMessage(l10n.entryScopeNotice(widget.scope.name)),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  key: const Key('entry_amount'),
                  controller: _amount,
                  enabled: !_amountLocked,
                  autofocus: _isNew,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall,
                  decoration: InputDecoration(
                    labelText: _installments
                        ? l10n.entryTotalAmountLabel
                        : l10n.amountLabel,
                    prefixText: r'R$ ',
                    hintText: '0,00',
                    helperText: _amountLocked ? l10n.entryAmountLocked : null,
                    helperMaxLines: 2,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  validator: validateWith(l10n, Validators.positiveAmount),
                ),
                const SizedBox(height: 16),
                switch (categories) {
                  Loading() => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  LoadFailure(:final error) => RetryMessage(
                    message: error.localized(l10n),
                    onRetry: () =>
                        unawaited(context.read<CategoriesCubit>().load(_kind)),
                  ),
                  Loaded(value: final options) when options.isEmpty =>
                    InfoMessage(l10n.entryNoCategories),
                  Loaded(value: final options) => _categoryField(l10n, options),
                },
                const SizedBox(height: 8),
                if (_isExpense) ...[
                  _natureField(l10n),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  key: const Key('entry_description'),
                  controller: _description,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [CapitalizeFirstFormatter()],
                  decoration: InputDecoration(
                    labelText: l10n.entryDescriptionLabel,
                  ),
                  maxLength: 200,
                  validator: validateWith(l10n, Validators.required),
                ),
                const SizedBox(height: 8),
                DateField(
                  key: const Key('entry_due_on'),
                  label: l10n.entryDueOnLabel,
                  value: _dueOn,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                  onChanged: (value) => setState(() => _dueOn = value),
                ),
                _BeforeBalanceNotice(dueOn: _dueOn),
                const SizedBox(height: 8),
                if (!widget.simulation && !_scoped)
                  SwitchListTile(
                    key: const Key('entry_settled'),
                    title: Text(l10n.entrySettledLabel(_kind.name)),
                    value: _settled,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) => setState(() => _settled = value),
                  ),
                if (_isNew) ..._repeatFields(l10n),
                if (_isNew && _isExpense) ..._installmentsFields(l10n),
                if (state case SubmissionFailure(:final error)) ...[
                  const SizedBox(height: 16),
                  ErrorBanner(_failureMessages(l10n, error)),
                ],
                const SizedBox(height: 24),
                SubmitButton(
                  label: widget.simulation ? l10n.simulationAdd : l10n.save,
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

class _BeforeBalanceNotice extends StatelessWidget {
  const new({required this.dueOn});

  final DateTime dueOn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return BlocBuilder<LatestBalanceCubit, Balance?>(
      builder: (context, balance) => switch (balance) {
        Balance(:final asOf) when !dueOn.isAfter(asOf) => Padding(
          key: const Key('entry_before_balance'),
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.entryBeforeBalanceNotice(Dates.display(asOf)),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _RecurrencePreview extends StatelessWidget {
  const new({required this.dueDates});

  static const shownBeforeLast = 3;

  final List<DateTime> dueDates;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = dueDates.map(Dates.display).toList();
    final shown = labels.length > shownBeforeLast + 1
        ? '${labels.take(shownBeforeLast).join(', ')} … ${labels.last}'
        : labels.join(', ');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        l10n.entryRepeatPreview(shown),
        key: const Key('entry_repeat_preview'),
      ),
    );
  }
}

class _InstallmentsPreview extends StatelessWidget {
  const new({required this.totalCents, required this.installments});

  final int? totalCents;
  final Installments installments;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = totalCents;
    if (total == null || total < installments.count) {
      return const SizedBox.shrink();
    }
    final [first, ...others] = installments.split(total);
    final share = others.first;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        first == share
            ? l10n.entryInstallmentsPreview(
                installments.count,
                Money.format(share),
              )
            : l10n.entryInstallmentsPreviewUneven(
                Money.format(first),
                others.length,
                Money.format(share),
              ),
        key: const Key('entry_installments_preview'),
      ),
    );
  }
}
