import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/submission.dart';
import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/admin/domain/admin_category.dart';
import 'package:lar_em_dia/features/admin/presentation/cubits/admin_cubits.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

class AdminCategoryFormPage extends StatefulWidget {
  const new({this.existing, super.key});

  final AdminCategory? existing;

  @override
  State<AdminCategoryFormPage> createState() => _AdminCategoryFormPageState();
}

class _AdminCategoryFormPageState extends State<AdminCategoryFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _key = TextEditingController(text: widget.existing?.key);
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _position = TextEditingController(
    text: '${widget.existing?.position ?? 0}',
  );
  late EntryKind _kind = widget.existing?.kind ?? EntryKind.expense;
  late EntryNature _nature =
      widget.existing?.defaultNature ?? EntryNature.variable;
  late bool _active = widget.existing?.active ?? true;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _key.dispose();
    _name.dispose();
    _position.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final draft = CategoryDraft(
      kind: _kind,
      key: _key.text.trim(),
      name: _name.text.trim(),
      position: int.parse(_position.text),
      active: _active,
      defaultNature: _kind == EntryKind.expense ? _nature : null,
    );
    unawaited(
      context.read<AdminCategoryFormCubit>().save(
        draft,
        existing: widget.existing,
      ),
    );
  }

  String? _validateKey(AppLocalizations l10n, String? value) {
    final missing = Validators.required(value);
    if (missing != null) {
      return missing.localized(l10n);
    }
    return CategoryDraft.keyFormat.hasMatch(value!.trim())
        ? null
        : l10n.adminCategoryKeyInvalid;
  }

  String? _validatePosition(AppLocalizations l10n, String? value) =>
      int.tryParse(value ?? '') == null
      ? l10n.adminCategoryPositionInvalid
      : null;

  List<String> _failureMessages(AppLocalizations l10n, ApiError error) => [
    error.localized(l10n),
    for (final (field, label) in [
      ('kind', l10n.adminCategoryKind),
      ('key', l10n.adminCategoryKey),
      ('name', l10n.adminCategoryName),
      ('position', l10n.adminCategoryPosition),
      ('default_nature', l10n.entryNatureLabel),
    ])
      if (error.localizedField(l10n, field) case final message?)
        '$label: $message',
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<AdminCategoryFormCubit, Submission<AdminCategory>>(
      listener: (context, state) {
        if (state is SubmissionSuccess) {
          context.pop(true);
        }
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(
          title: Text(
            _isNew ? l10n.adminCategoryNewTitle : l10n.adminCategoryEditTitle,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isNew) ...[
                  Text(
                    l10n.adminCategoryKind,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<EntryKind>(
                    segments: [
                      for (final kind in EntryKind.values)
                        ButtonSegment(
                          value: kind,
                          label: Text(l10n.adminCategoryKindName(kind.name)),
                        ),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (selection) =>
                        setState(() => _kind = selection.single),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('category_key'),
                    controller: _key,
                    decoration: InputDecoration(
                      labelText: l10n.adminCategoryKey,
                      helperText: l10n.adminCategoryKeyHelper,
                    ),
                    autocorrect: false,
                    maxLength: 50,
                    validator: (value) => _validateKey(l10n, value),
                  ),
                  const SizedBox(height: 8),
                ],
                TextFormField(
                  key: const Key('category_name'),
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: l10n.adminCategoryName,
                    helperText: l10n.adminCategoryNameHelper,
                  ),
                  maxLength: 100,
                  validator: validateWith(l10n, Validators.required),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('category_position'),
                  controller: _position,
                  decoration: InputDecoration(
                    labelText: l10n.adminCategoryPosition,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) => _validatePosition(l10n, value),
                ),
                if (_kind == EntryKind.expense) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.entryNatureLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<EntryNature>(
                    segments: [
                      ButtonSegment(
                        value: EntryNature.fixed,
                        label: Text(l10n.entryNatureFixed),
                      ),
                      ButtonSegment(
                        value: EntryNature.variable,
                        label: Text(l10n.entryNatureVariable),
                      ),
                    ],
                    selected: {_nature},
                    onSelectionChanged: (selection) =>
                        setState(() => _nature = selection.single),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.adminCategoryActive),
                  subtitle: Text(l10n.adminCategoryActiveHelper),
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
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
