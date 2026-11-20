import 'package:flutter/services.dart';

class CapitalizeFirstFormatter extends TextInputFormatter {
  static final _firstVisible = RegExp(r'\S');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    final index = text.indexOf(_firstVisible);
    if (index < 0) return newValue;
    final first = text[index];
    final upper = first.toUpperCase();
    if (upper == first || upper.length != first.length) return newValue;
    return newValue.copyWith(text: text.replaceRange(index, index + 1, upper));
  }
}
