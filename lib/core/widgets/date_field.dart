import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lar_em_dia/core/dates/dates.dart';

class DateField extends StatelessWidget {
  const new({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    super.key,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: firstDate,
      lastDate: lastDate,
      barrierDismissible: false,
    );
    if (picked != null) {
      onChanged(Dates.dateOnly(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => unawaited(_pick(context)),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(Dates.display(value)),
      ),
    );
  }
}
