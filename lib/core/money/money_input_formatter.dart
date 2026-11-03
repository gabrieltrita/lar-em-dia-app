import 'package:flutter/services.dart';
import 'package:lar_em_dia/core/money/money.dart';

class MoneyInputFormatter extends TextInputFormatter {
  new({this.allowNegative = false});

  final bool allowNegative;

  static final _nonDigits = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final negative = allowNegative && newValue.text.trimLeft().startsWith('-');
    final digits = newValue.text.replaceAll(_nonDigits, '');
    if (digits.isEmpty) {
      final text = negative ? '-' : '';
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    final cents = int.parse(
      digits.length > 15 ? digits.substring(0, 15) : digits,
    );
    final text = Money.formatAmount(negative ? -cents : cents);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
