import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/forms/capitalize_first_formatter.dart';
import 'package:lar_em_dia/core/forms/error_messages.dart';
import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/network/api_error.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/entries/domain/category.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_label.dart';
import 'package:lar_em_dia/features/entries/presentation/widgets/category_visuals.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

typedef CategoryCreator = Future<Category> Function(
  String name,
  EntryNature? defaultNature,
);

typedef CategoryRemover = Future<void> Function(Category category);

class CategoryPickerField extends StatelessWidget {
  const new({
    required this.kind,
    required this.categories,
    required this.selected,
    required this.label,
    required this.onSelected,
    required this.onCreate,
    required this.onDelete,
    this.errorText,
    super.key,
  });

  final EntryKind kind;
  final List<Category> categories;
  final String? selected;
  final String label;
  final String? errorText;
  final ValueChanged<Category> onSelected;
  final CategoryCreator onCreate;
  final CategoryRemover onDelete;

  Category? get _selectedCategory =>
      categories.where((category) => category.id == selected).firstOrNull;

  Future<void> _open(BuildContext context) async {
    final category = await showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => CategoryPickerSheet(
        kind: kind,
        categories: categories,
        selected: selected,
        onCreate: onCreate,
        onDelete: onDelete,
      ),
    );
    if (category != null) {
      onSelected(category);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final category = _selectedCategory;
    return Semantics(
      button: true,
      child: InkWell(
        key: const Key('category_picker'),
        borderRadius: BorderRadius.circular(4),
        onTap: () => unawaited(_open(context)),
        child: InputDecorator(
          isEmpty: category == null,
          decoration: InputDecoration(
            labelText: label,
            hintText: l10n.categoryPickerHint,
            errorText: errorText,
            suffixIcon: const Icon(Icons.expand_more),
          ),
          child: category == null
              ? null
              : Row(
                  children: [
                    Transform.scale(
                      scale: 0.7,
                      child: CategoryAvatar(category: category),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        categoryLabel(l10n, category),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class CategoryPickerSheet extends StatefulWidget {
  const new({
    required this.kind,
    required this.categories,
    required this.selected,
    required this.onCreate,
    required this.onDelete,
    super.key,
  });

  final EntryKind kind;
  final List<Category> categories;
  final String? selected;
  final CategoryCreator onCreate;
  final CategoryRemover onDelete;

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  late List<Category> _categories = widget.categories;
  String _query = '';

  List<Category> _matching(AppLocalizations l10n, {required bool custom}) {
    final query = _normalized(_query);
    return [
      for (final category in _categories)
        if (category.custom == custom &&
            _normalized(categoryLabel(l10n, category)).contains(query))
          category,
    ];
  }

  static String _normalized(String text) {
    const accents = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'ê': 'e',
      'í': 'i',
      'ó': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ç': 'c',
    };
    return text
        .trim()
        .toLowerCase()
        .split('')
        .map((char) => accents[char] ?? char)
        .join();
  }

  Future<void> _create() async {
    final category = await showDialog<Category>(
      context: context,
      builder: (_) => NewCategoryDialog(
        kind: widget.kind,
        initialName: _query.trim(),
        onCreate: widget.onCreate,
      ),
    );
    if (category != null && mounted) {
      Navigator.of(context).pop(category);
    }
  }

  Future<void> _delete(Category category) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.categoryDeleteTitle),
        content: Text(l10n.categoryDeleteMessage(category.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('category_delete_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.onDelete(category);
      if (mounted) {
        setState(() {
          _categories = [
            for (final item in _categories)
              if (item.id != category.id) item,
          ];
        });
      }
    } on ApiError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.localized(l10n))));
    }
  }

  Widget _tile(AppLocalizations l10n, Category category) {
    final selected = category.id == widget.selected;
    return ListTile(
      key: ValueKey('category_${category.key}'),
      leading: CategoryAvatar(category: category),
      title: Text(categoryLabel(l10n, category)),
      selected: selected,
      onTap: () => Navigator.of(context).pop(category),
      trailing: switch ((selected, category.custom)) {
        (_, true) => IconButton(
          key: ValueKey('category_delete_${category.key}'),
          tooltip: l10n.categoryDeleteTooltip(category.name),
          icon: const Icon(Icons.delete_outline),
          onPressed: () => unawaited(_delete(category)),
        ),
        (true, false) => const Icon(Icons.check_circle),
        (false, false) => null,
      },
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mine = _matching(l10n, custom: true);
    final global = _matching(l10n, custom: false);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              key: const Key('category_search'),
              decoration: InputDecoration(
                hintText: l10n.categoryPickerSearch,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              children: [
                ListTile(
                  key: const Key('category_create'),
                  leading: const CircleAvatar(child: Icon(Icons.add)),
                  title: Text(l10n.categoryCreate),
                  onTap: () => unawaited(_create()),
                ),
                if (mine.isNotEmpty) ...[
                  _header(context, l10n.categoryPickerMine),
                  for (final category in mine) _tile(l10n, category),
                ],
                if (global.isNotEmpty) ...[
                  if (mine.isNotEmpty) _header(context, l10n.categoryPickerAll),
                  for (final category in global) _tile(l10n, category),
                ],
                if (mine.isEmpty && global.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: InfoMessage(l10n.categoryPickerEmpty),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NewCategoryDialog extends StatefulWidget {
  const new({
    required this.kind,
    required this.onCreate,
    this.initialName = '',
    super.key,
  });

  final EntryKind kind;
  final String initialName;
  final CategoryCreator onCreate;

  @override
  State<NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<NewCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: CapitalizeFirstFormatter()
        .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: widget.initialName),
        )
        .text,
  );
  EntryNature _nature = EntryNature.variable;
  bool _busy = false;
  ApiError? _error;

  bool get _isExpense => widget.kind == EntryKind.expense;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final category = await widget.onCreate(
        _name.text.trim(),
        _isExpense ? _nature : null,
      );
      if (mounted) {
        Navigator.of(context).pop(category);
      }
    } on ApiError catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error;
        });
      }
    }
  }

  List<String> _messages(AppLocalizations l10n, ApiError error) => [
    error.localized(l10n),
    for (final (field, label) in [
      ('name', l10n.categoryCreateName),
      ('default_nature', l10n.entryNatureLabel),
    ])
      if (error.localizedField(l10n, field) case final message?)
        '$label: $message',
    ?error.localizedField(l10n, 'base'),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = _error;
    return AlertDialog(
      title: Text(l10n.categoryCreateTitle(widget.kind.name)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                ErrorBanner(_messages(l10n, error)),
                const SizedBox(height: 16),
              ],
              TextFormField(
                key: const Key('category_create_name'),
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [CapitalizeFirstFormatter()],
                decoration: InputDecoration(
                  labelText: l10n.categoryCreateName,
                  hintText: l10n.categoryCreateNameHint,
                ),
                maxLength: 100,
                validator: validateWith(l10n, Validators.required),
                onFieldSubmitted: (_) => unawaited(_submit()),
              ),
              if (_isExpense) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.entryNatureLabel,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                SegmentedButton<EntryNature>(
                  key: const Key('category_create_nature'),
                  showSelectedIcon: false,
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
                const SizedBox(height: 4),
                Text(
                  l10n.categoryCreateNatureHelper,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        SubmitButton(
          key: const Key('category_create_submit'),
          label: l10n.categoryCreateSubmit,
          busy: _busy,
          onPressed: () => unawaited(_submit()),
        ),
      ],
    );
  }
}
