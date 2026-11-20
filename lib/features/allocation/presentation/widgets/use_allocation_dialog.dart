import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/money_input_formatter.dart';
import 'package:lar_em_dia/features/allocation/domain/allocation.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

Future<int?> showUseAllocationDialog(
  BuildContext context, {
  required AllocationItem item,
  required bool reserve,
}) => showDialog<int>(
  context: context,
  barrierDismissible: false,
  builder: (context) => _UseAllocationDialog(item: item, reserve: reserve),
);

class _UseAllocationDialog extends StatefulWidget {
  const new({required this.item, required this.reserve});

  final AllocationItem item;
  final bool reserve;

  @override
  State<_UseAllocationDialog> createState() => _UseAllocationDialogState();
}

class _UseAllocationDialogState extends State<_UseAllocationDialog> {
  late final _amount = TextEditingController(
    text: widget.item.amountCents > 0
        ? Money.formatAmount(widget.item.amountCents)
        : '',
  );

  int? get _cents => switch (Money.parse(_amount.text)) {
    final cents? when cents > 0 => cents,
    _ => null,
  };

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cents = _cents;
    return AlertDialog(
      title: Text(l10n.allocationUseTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.reserve
                ? l10n.allocationUseReserveMessage(widget.item.name)
                : l10n.allocationUseMessage(widget.item.name),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('allocation_use_amount'),
            controller: _amount,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.allocationUseAmount,
              prefixText: r'R$ ',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [MoneyInputFormatter()],
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: cents == null
              ? null
              : () => Navigator.of(context).pop(_cents),
          child: Text(l10n.allocationUseConfirm),
        ),
      ],
    );
  }
}
