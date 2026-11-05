import 'package:flutter/material.dart';
import 'package:lar_em_dia/features/entries/domain/entry.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

typedef PaidChanged = void Function(Entry entry, {required bool paid});

class PaidCheckbox extends StatelessWidget {
  const new({required this.entry, required this.onChanged, super.key});

  final Entry entry;
  final PaidChanged onChanged;

  @override
  Widget build(BuildContext context) => Checkbox(
    value: entry.isPaid,
    semanticLabel: AppLocalizations.of(context)
        .entryMarkSettled(entry.kind.name),
    onChanged: (value) => onChanged(entry, paid: value ?? false),
  );
}
