import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/forms/validators.dart';
import 'package:lar_em_dia/core/money/money.dart';
import 'package:lar_em_dia/core/money/money_input_formatter.dart';
import 'package:lar_em_dia/core/widgets/form_widgets.dart';
import 'package:lar_em_dia/features/reserve/domain/reserve.dart';
import 'package:lar_em_dia/l10n/gen/app_localizations.dart';

typedef ReserveGoalChoice = ({int months, int? cents});

Future<ReserveGoalChoice?> showReserveGoalSheet(
  BuildContext context,
  ReserveGoal goal,
) => showModalBottomSheet<ReserveGoalChoice>(
  context: context,
  isScrollControlled: true,
  builder: (context) => ReserveGoalSheet(goal: goal),
);

class ReserveGoalSheet extends StatefulWidget {
  const new({required this.goal, super.key});

  final ReserveGoal goal;

  @override
  State<ReserveGoalSheet> createState() => _ReserveGoalSheetState();
}

class _ReserveGoalSheetState extends State<ReserveGoalSheet> {
  static const minMonths = 1;
  static const maxMonths = 24;

  final _formKey = GlobalKey<FormState>();
  late int _months = widget.goal.months;
  late bool _ownAmount = widget.goal.cents != null;
  late final _amount = TextEditingController(
    text: switch (widget.goal.cents) {
      final cents? => Money.formatAmount(cents),
      null => '',
    },
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop<ReserveGoalChoice>((
      months: _months,
      cents: _ownAmount ? Money.parse(_amount.text) : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.reserveGoalTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              key: const Key('reserve_goal_mode'),
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(l10n.reserveGoalByMonths),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(l10n.reserveGoalByAmount),
                ),
              ],
              selected: {_ownAmount},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  setState(() => _ownAmount = selection.first),
            ),
            const SizedBox(height: 16),
            if (_ownAmount)
              TextFormField(
                key: const Key('reserve_goal_amount'),
                controller: _amount,
                decoration: InputDecoration(
                  labelText: l10n.reserveGoalAmount,
                  prefixText: r'R$ ',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                validator: validateWith(l10n, Validators.positiveAmount),
              )
            else ...[
              Text(l10n.reserveGoalMonths(_months)),
              Slider(
                key: const Key('reserve_goal_months'),
                value: _months.toDouble(),
                min: minMonths.toDouble(),
                max: maxMonths.toDouble(),
                divisions: maxMonths - minMonths,
                label: '$_months',
                onChanged: (value) => setState(() => _months = value.round()),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text(l10n.save)),
          ],
        ),
      ),
    );
  }
}
